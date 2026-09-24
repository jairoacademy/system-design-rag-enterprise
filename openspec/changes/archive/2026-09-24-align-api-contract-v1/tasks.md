# Tasks

## 1. Convenções gerais do API.md

- [x] 1.1 Reescrever a "Visão Geral" de `API.md` removendo a afirmação de que o documento não traz detalhes de implementação, e declarando que ele é o contrato REST do qual o backend e o frontend programam — verificar por busca textual que a frase "sem detalhes de implementação" não aparece mais no documento.
- [x] 1.2 Adicionar seção "Convenções Gerais" com a base `/api/v1` e o header `Authorization: Bearer <cognito_access_token>` exigido em todos os endpoints protegidos — verificar que a seção existe e precede as seções de recursos.
- [x] 1.3 Documentar o envelope de erro padrão `{error, message}` e a tabela de códigos de erro, incluindo `VALIDATION_ERROR`, `INVALID_SOURCE_IDS`, `SOURCE_NOT_READY`, `UNAUTHORIZED`, `NOTEBOOK_NOT_FOUND`, `SOURCE_NOT_FOUND`, `CONVERSATION_NOT_FOUND`, `NO_ACTIVE_SOURCES`, `UNSUPPORTED_FILE_TYPE` e `INTERNAL_ERROR` — verificar que os dez códigos constam na tabela com HTTP e situação, e que `SOURCE_NOT_READY` (400) e `NO_ACTIVE_SOURCES` (409) estão entre eles (decisões 1 e 4 do `design.md`).
- [x] 1.4 Documentar o mapa de status HTTP por operação (GET recurso/coleção `200`, POST síncrono `201`, POST assíncrono `202`, PATCH `200`, DELETE `204`), a regra de coleções nunca retornarem nulo, a ausência de paginação na v1 e a ordenação padrão por data de criação decrescente — verificar que as quatro convenções estão escritas.
- [x] 1.5 Remover a seção "Autenticação" de `API.md`, substituindo-a por uma nota nas convenções de que login, logout e perfil são interação direta entre frontend e Cognito, sem endpoint no backend — verificar por busca textual que não restam contratos de "login federado", "retorno de sessão", "perfil do usuário logado" ou "logout" no documento (decisão 5 do `design.md`).

## 2. Endpoints de Notebooks no API.md

- [x] 2.1 Documentar `GET /api/v1/notebooks` e `POST /api/v1/notebooks` com payloads de exemplo, tabela de restrições de campo (`name` 1–256 obrigatório, `description` máx. 2048 opcional) e erros aplicáveis — verificar que os dois endpoints têm exemplo de response e que os UUIDs de exemplo são hexadecimais válidos (decisão 9 do `design.md`).
- [x] 2.2 Documentar `GET /api/v1/notebooks/{notebookId}` incluindo o array de sources embutido na resposta — verificar que o exemplo mostra a lista de sources com identificador, nome, `type` e `status`.
- [x] 2.3 Documentar `PATCH /api/v1/notebooks/{notebookId}`, explicitando que apenas os campos enviados são modificados — verificar que o comportamento de atualização parcial está escrito, não apenas implícito no exemplo.
- [x] 2.4 Documentar `DELETE /api/v1/notebooks/{notebookId}` com a cascata completa (sources, chunks, conversas, mensagens e arquivos no S3) — verificar que os cinco tipos de dado derivado estão nomeados na descrição.
- [x] 2.5 Anotar em cada endpoint de Notebooks a tela que o consome (Tela 2 para listar/criar, Tela 3 para detalhar) — verificar que as anotações de tela sobreviveram à reescrita (decisão 8 do `design.md`).

## 3. Endpoints de Sources no API.md

- [x] 3.1 Documentar `POST /api/v1/notebooks/{notebookId}/sources` nas duas variantes, arquivo via `multipart/form-data` e URL via JSON, com resposta `202` e status inicial `PENDING` — verificar que o documento não descreve mais o source nascendo em status "processando".
- [x] 3.2 Documentar `GET /api/v1/notebooks/{notebookId}/sources` e `GET /api/v1/notebooks/{notebookId}/sources/{sourceId}`, indicando o segundo como o contrato de polling de status e mostrando um exemplo com `status: FAILED` e `errorMessage` preenchida — verificar que os dois endpoints existem e que o exemplo de falha está presente.
- [x] 3.3 Documentar `DELETE /api/v1/notebooks/{notebookId}/sources/{sourceId}` com a limpeza de chunks no pgvector e do arquivo no S3 — verificar que ambos os efeitos estão nomeados.
- [x] 3.4 Documentar os valores canônicos de status (`PENDING`, `PROCESSING`, `READY`, `FAILED`) e a transição entre eles na seção de Sources — verificar que os quatro valores aparecem e que `UNSUPPORTED_FILE_TYPE` está associado ao envio de formato não suportado.
- [x] 3.5 Anotar os endpoints de Sources com a tela que os consome (painel "sources" da Tela 3) — verificar que a anotação existe.

## 4. Endpoints de Conversations e Chat no API.md

- [x] 4.1 Documentar `POST /api/v1/notebooks/{notebookId}/conversations` com `activeSourceIds` **obrigatório e não-vazio**, explicitando que lista omitida ou vazia resulta em `400 VALIDATION_ERROR` e que não existe default de "todas as sources prontas" — verificar por busca textual que o documento não afirma em nenhum ponto que a lista vazia ativa todas as sources (decisão 1 do `design.md`).
- [x] 4.2 Documentar `GET /api/v1/notebooks/{notebookId}/conversations` incluindo o campo `preview` e registrando que ele é derivado da primeira mensagem, não editável — verificar que a natureza derivada do campo está escrita.
- [x] 4.3 Documentar `PATCH /api/v1/conversations/{conversationId}/active-sources` como substituição integral da lista, válida a qualquer momento da conversa, recusando lista vazia — verificar que o endpoint existe, que descreve substituição (não adição/remoção incremental) e que cita `SOURCE_NOT_READY` para sources fora de `READY` (decisões 2 e 4 do `design.md`).
- [x] 4.4 Documentar `GET /api/v1/conversations/{conversationId}/messages` com o histórico em ordem cronológica crescente e o autor de cada mensagem — verificar que a ordenação está explícita e difere da ordenação padrão decrescente das demais coleções.
- [x] 4.5 Documentar `POST /api/v1/conversations/{conversationId}/messages` com o contrato SSE completo: headers da response, formato `data: {"token": "..."}`, evento final `{"done": true, "messageId": "..."}`, evento de erro de stream, e a distinção entre erros antes do início do stream (HTTP convencional) e depois (evento SSE) — verificar que as duas classes de erro estão descritas separadamente.
- [x] 4.6 Documentar o erro `409 NO_ACTIVE_SOURCES` no envio de mensagem, para a conversa cuja seleção ativa ficou vazia após a deleção de uma source — verificar que o endpoint de envio lista esse erro e explica a ação de recuperação (ativar outra source via `PATCH`) (decisão 3 do `design.md`).
- [x] 4.7 Anotar os endpoints de Conversations e Chat com a tela que os consome (área de chat da Tela 3) — verificar que a anotação existe.

## 5. Atualizar DOMAIN.md

- [x] 5.1 Adicionar regra de negócio de provisionamento just-in-time do `User` na primeira requisição autenticada a partir do `cognito_sub`, registrando que não há cadastro nem endpoint de autenticação — verificar que a regra existe e referencia o `cognito_sub` como gatilho (decisão 5 do `design.md`).
- [x] 5.2 Adicionar regras de negócio de deleção em cascata: notebook apaga sources, chunks, conversas, mensagens e arquivos no S3; source apaga seus chunks e seu arquivo no S3 — verificar que as duas regras existem e nomeiam os arquivos no S3 entre os dados removidos.
- [x] 5.3 Adicionar regra de negócio de que a seleção de sources ativas de uma conversa é obrigatória e não pode ser esvaziada, e de que um notebook sem source em status "pronto" não permite criar conversa — verificar que a regra 6 existente foi ajustada ou complementada, e que nenhuma regra restante sugere seleção opcional.
- [x] 5.4 Adicionar regra de negócio do estado da conversa após a deleção de sua última source ativa: histórico preservado, novas mensagens recusadas, recuperável ao ativar outra source — verificar que a regra existe e que descreve o estado como consequência da lista vazia, não como atributo persistido (decisão 3 do `design.md`).
- [x] 5.5 Registrar na entidade `Source` os valores canônicos de status (`PENDING`, `PROCESSING`, `READY`, `FAILED`) ao lado da descrição em português — verificar que os quatro valores canônicos aparecem no documento.
- [x] 5.6 Corrigir a inconsistência entre o texto e o ERD quanto ao atributo "formato" de `Source`: acrescentar a coluna correspondente ao ERD e anotar que o formato não é exposto na API v1 — verificar que o ERD passou a ter a coluna e que a anotação de não exposição está escrita (decisão 6 do `design.md`).

## 6. Atualizar ARCHITECTURE.md

- [x] 6.1 Corrigir o título do documento, hoje escrito como `/ops# Arquitetura` — verificar que a primeira linha do arquivo é exatamente `# Arquitetura`.
- [x] 6.2 Reforçar a seção "Seleção de sources no chat" com a obrigatoriedade da seleção (mínimo uma source) e com o comportamento após a deleção da última source ativa — verificar que a seção continua afirmando a ausência de contexto implícito e agora também a obrigatoriedade.
- [x] 6.3 Acrescentar à seção de risco de streaming via API Gateway a nota de que `X-Accel-Buffering: no` presente no contrato é um header de nginx e não mitiga o buffering nem o teto de ~29s do gateway, permanecendo o risco aberto — verificar que a nota existe e que o risco continua marcado como não resolvido (decisão 9 do `design.md`).

## 7. Validação final

- [x] 7.1 Executar `openspec validate align-api-contract-v1 --strict` e confirmar que a change passa sem erros.
- [x] 7.2 Revisar os três documentos por busca textual e confirmar que não restam: contratos de autenticação no `API.md`, qualquer afirmação de que lista vazia de sources ativas significa "todas", o título quebrado no `ARCHITECTURE.md`, nem UUIDs de exemplo com caracteres não hexadecimais.
- [x] 7.3 Conferir que cada requisito das quatro specs (`notebooks`, `sources`, `conversations`, `chat`) tem contrapartida observável no `API.md` ou regra correspondente no `DOMAIN.md` — verificar percorrendo os requisitos de cada spec e localizando onde o comportamento está documentado.
