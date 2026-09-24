# Proposal

## Why

O `API.md` atual descreve *capacidades* em prosa ("Criar notebook", "Enviar mensagem") sem rotas, payloads ou códigos de erro — suficiente enquanto o projeto era só fundação, insuficiente agora que `app/backend` saiu do scaffold e precisa de um contrato do qual programar. Um contrato REST concreto de referência foi disponibilizado (`diario/dia-01`), e ao compará-lo com a fundação atual aparecem quatro decisões de comportamento em aberto, dois endpoints de ciclo de vida que nunca foram documentados (`PATCH`/`DELETE`) e regras de negócio ausentes (o que acontece ao deletar um notebook ou uma source). Esta change resolve essas decisões e eleva `API.md` a contrato executável antes que a implementação as decida por acidente.

## What Changes

### Decisões de comportamento

- **Seleção de sources ativas é obrigatória e mínima de 1**: criar uma conversa sem `activeSourceIds`, ou com lista vazia, é erro de validação. Não existe default implícito de "todas as sources prontas" — decisão contrária ao contrato de referência, que trata lista omitida como "todas as READY".
- **Seleção de sources ativas permanece mutável** ao longo da conversa, via contrato dedicado que o contrato de referência não possui. A troca é permitida; esvaziar a seleção não é.
- **Deletar uma source ativa não bloqueia nem apaga a conversa**: a conversa preserva o histórico e entra em estado "sem seleção válida", recusando novas mensagens até que o usuário ative outra source. Alternativas rejeitadas: bloquear a exclusão, ou apagar em cascata as conversas afetadas.
- **Não há endpoints de autenticação no backend**: login, logout e perfil são interação direta entre frontend e Cognito. O `User` é provisionado *just-in-time* na primeira requisição autenticada, a partir do `cognito_sub` do token. **BREAKING** em relação ao `API.md` atual, que documenta quatro contratos de autenticação (login federado, retorno de sessão, perfil, logout) — todos removidos.

### Contrato

- `API.md` passa de descrição de capacidades a contrato REST concreto: base `/api/v1`, rotas e verbos, payloads de request/response, restrições de campo, envelope de erro `{error, message}`, tabela de códigos de erro e mapa de status HTTP por operação. As referências às Telas 1/2/3 são preservadas como anotação de rastreabilidade em cada endpoint.
- Quatro endpoints novos, ausentes da fundação: `PATCH /notebooks/{id}`, `DELETE /notebooks/{id}`, `GET /notebooks/{id}/sources/{sourceId}` (polling de status) e `DELETE /notebooks/{id}/sources/{sourceId}`.
- Status de processamento de `Source` ganham valores canônicos no contrato: `PENDING`, `PROCESSING`, `READY`, `FAILED`. O `202` da criação de source retorna `PENDING` (a fundação dizia "processando").
- Convenções transversais: coleções nunca retornam `null` (`[]` quando vazias), sem paginação na v1, ordenação padrão `created_at DESC`.
- Contrato de streaming do chat detalhado: headers da response, formato `data: {"token": "..."}`, evento final `{"done": true, "messageId": "..."}` e sinalização de erro de stream.

### Regras de negócio novas

- Deletar um `Notebook` apaga em cascata suas sources, chunks, conversas, mensagens e os arquivos correspondentes no S3.
- Deletar um `Source` apaga seus chunks do pgvector e seu arquivo no S3.
- Só sources com status `READY` podem ser ativadas em uma conversa; tentar ativar uma source em outro status é erro de validação — regra que existe no `DOMAIN.md` mas não tinha código de erro correspondente.
- Um notebook sem nenhuma source `READY` não permite criar conversa.

### Não adotado do contrato de referência

- O default "lista vazia significa todas as sources READY", substituído por seleção obrigatória.
- Os UUIDs de exemplo do documento de referência, que não são hexadecimais válidos.
- A sugestão implícita de que `X-Accel-Buffering: no` resolve o buffering de streaming: esse header é do nginx e não endereça o teto de ~29s do API Gateway, risco que permanece registrado e aberto no `ARCHITECTURE.md`.

## Capabilities

### New Capabilities

- `notebooks`: ciclo de vida do notebook (criar, listar, detalhar com sources embutidas, atualizar, deletar em cascata) e a regra de que só o dono enxerga e opera o notebook.
- `sources`: ingestão de sources por arquivo ou URL, o contrato assíncrono `202`/polling, a máquina de estados de processamento (`PENDING` → `PROCESSING` → `READY`/`FAILED`) e a deleção com limpeza de chunks e S3.
- `conversations`: criação de conversa com seleção obrigatória e não-vazia de sources ativas, listagem por notebook, alteração da seleção ao longo da conversa, e o estado "sem seleção válida" após a deleção de uma source ativa.
- `chat`: envio de mensagem com resposta via streaming SSE, escopo do retrieval às sources ativas da conversa, persistência da mensagem do assistente e recuperação do histórico.

### Modified Capabilities

Nenhuma — `openspec/specs/` está vazio; estas são as primeiras capabilities do projeto.

## Impact

- `API.md`: reescrita substancial. Seção "Autenticação" removida e substituída por convenções de header; seções de Notebooks, Sources, Conversations e Chat reescritas como contrato REST; convenções gerais e tabela de erros adicionadas.
- `DOMAIN.md`: regras de negócio de cascata na deleção, provisionamento *just-in-time* do `User`, valores canônicos de status, regra do notebook sem source `READY`, e o estado da conversa após perder sua última source ativa. O ERD é corrigido: hoje o texto lista "formato" como atributo de `Source` mas o ERD não tem coluna correspondente.
- `ARCHITECTURE.md`: a seção "Seleção de sources no chat" é reforçada com a obrigatoriedade da seleção; o risco de streaming via API Gateway ganha nota explícita de que continua aberto; o título do documento é corrigido (hoje lê `/ops# Arquitetura`).
- `CLAUDE.md`: sem alteração — o índice continua válido.
- Nenhum código ou infraestrutura é afetado. `app/backend` permanece sem lógica de negócio; esta change estabelece o contrato do qual as changes de implementação partirão.
