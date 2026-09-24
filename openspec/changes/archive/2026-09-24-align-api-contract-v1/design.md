# Design

## Context

Ver `proposal.md` — Why. O que molda o desenho aqui:

- A fundação (`API.md`, `DOMAIN.md`, `ARCHITECTURE.md`) foi escrita em nível de capacidades, deliberadamente sem detalhes de implementação. Um contrato REST concreto de referência (`diario/dia-01`) chegou depois e cobre o mesmo escopo com rotas e payloads.
- Os dois documentos divergem em pontos de comportamento, não só de formato. Onde divergem, a fundação do projeto é a autoridade: ela carrega decisões tomadas de propósito e registradas em changes anteriores (notadamente `2026-09-23-revise-domain-model-conversations`, que estabeleceu a seleção de sources por conversa e mutável).
- `openspec/specs/` estava vazio. Esta change cria as quatro primeiras capabilities do projeto, que as changes de implementação vão referenciar.
- Nenhuma implementação existe ainda, então não há compatibilidade retroativa a preservar — apenas coerência documental.

## Goals / Non-Goals

**Goals:**

- Produzir um `API.md` do qual seja possível programar sem adivinhar nomes de campo, códigos de erro ou formato de resposta.
- Resolver as divergências de comportamento entre fundação e contrato de referência de forma explícita e justificada, em vez de deixá-las para a implementação decidir.
- Manter os três documentos de fundação coerentes entre si após a reescrita.

**Non-Goals:**

- Especificar a implementação Spring Boot (controllers, DTOs, camadas). O contrato é agnóstico à tecnologia.
- Resolver o risco de streaming através do API Gateway. Ele permanece aberto e registrado.
- Introduzir paginação, versionamento além de `/api/v1`, ou compartilhamento de notebooks entre usuários.
- Expor o formato do arquivo (PDF/DOCX/Markdown) no contrato da v1.

## Decisions

### 1. Seleção de sources ativas obrigatória, mínima de 1, sem default implícito

O contrato de referência trata lista omitida ou vazia como "todas as sources `READY` do notebook". Adotamos o oposto: a seleção é obrigatória e não pode ser vazia.

**Por quê:** o `ARCHITECTURE.md` já afirma que "não existe um contexto implícito de todas as sources" — o retrieval sempre consulta uma lista materializada e persistida. Um default implícito cria duas fontes de verdade para o escopo de busca: uma lista explícita quando o usuário escolhe, e uma regra dinâmica quando não escolhe. A regra dinâmica é a pior das duas, porque muda de significado sozinha: uma source que termina o processamento depois da criação da conversa entraria no escopo sem nenhuma ação do usuário, alterando silenciosamente o resultado de perguntas futuras.

**Alternativa considerada:** aceitar o default por conveniência de primeiro uso, materializando a lista no momento da criação (congelando quais sources estavam `READY` naquele instante). Rejeitada: resolve a ambiguidade técnica mas mantém o usuário sem saber o que foi selecionado por ele. O custo real do default é uma tela a mais no frontend, não uma limitação do produto.

**Consequência aceita:** um notebook sem nenhuma source `READY` não permite criar conversa. O frontend deve desabilitar a ação até o primeiro processamento concluir.

### 2. Seleção permanece mutável, via contrato dedicado

O contrato de referência não tem endpoint para alterar a seleção — nele, a escolha feita na criação é definitiva.

**Por quê:** a mutabilidade é decisão registrada em change anterior, e a ausência no documento de referência parece omissão (é o dia 01 de um diário incremental), não escolha. O caso de uso é concreto: o usuário discute dois artigos e, no meio da conversa, precisa consultar um terceiro documento. Sem mutabilidade, ele perde o histórico ao abrir conversa nova.

**Alternativa considerada:** seguir a referência e tornar a seleção imutável. Rejeitada por reverter decisão deliberada com base em omissão de terceiro.

A alteração é uma **substituição** da lista inteira, não uma operação incremental de adicionar/remover. Substituição é idempotente, tem uma única validação e evita o estado ambíguo de uma remoção que esvazia a lista.

### 3. Deletar source ativa degrada a conversa, não a bloqueia nem a apaga

Quando a última source ativa de uma conversa é deletada, a conversa entra em estado sem seleção válida: histórico legível, novas mensagens recusadas com `409 NO_ACTIVE_SOURCES`, recuperável ao ativar outra source.

**Por quê:** preserva as duas coisas que importam — o histórico do usuário e a simplicidade de apagar um arquivo.

**Alternativas consideradas:**

- *Bloquear a exclusão enquanto a source estiver em uso*: obriga o usuário a caçar e editar conversas antes de limpar um arquivo, e acopla uma operação de gerenciamento de arquivos ao estado do chat.
- *Apagar em cascata as conversas que ficariam vazias*: destrói histórico como efeito colateral não anunciado de uma ação sobre outro recurso. Inaceitável.

O estado degradado é derivado, não persistido: é simplesmente a consequência de a lista de sources ativas estar vazia. Não há flag de estado a manter sincronizada.

### 4. `409` para conversa sem seleção válida, em vez de `400`

`400` significa "sua requisição está malformada". A mensagem enviada está perfeitamente bem formada; o que impede a operação é o estado do recurso. `409 Conflict` é a semântica correta, e a distinção importa para o frontend: um `400` manda corrigir o campo, um `409 NO_ACTIVE_SOURCES` manda abrir o seletor de sources.

Isso adiciona uma classe de status que o contrato de referência não usa. Adição deliberada.

### 5. Backend sem endpoints de autenticação; `User` provisionado just-in-time

Login e logout são interação direta frontend↔Cognito. Nome, e-mail e avatar saem do próprio token, sem endpoint de perfil.

**Por quê:** um endpoint que só repassa claims do token não acrescenta nada e cria um caminho de leitura redundante. O `API.md` atual documenta quatro contratos de autenticação que o backend não precisa oferecer.

**Consequência que precisava de decisão:** sem endpoint de cadastro, não havia momento definido para a linha em `users` nascer. O provisionamento passa a acontecer na primeira requisição autenticada em que o `cognito_sub` é desconhecido. O cliente não percebe uma etapa extra. A alternativa — exigir uma chamada de registro após o login — devolveria ao backend justamente o acoplamento de autenticação que estamos removendo.

### 6. `type` no contrato é a origem; o formato do arquivo fica interno

O contrato expõe `type: FILE | URL`. O formato (PDF, DOCX, Markdown, página web) não aparece na v1 — o frontend pode derivar um ícone da extensão no nome.

**Por quê:** é um atributo que hoje não tem consumidor no contrato. Expor campo sem consumidor é dívida.

Isso revela uma inconsistência interna preexistente no `DOMAIN.md`: o texto lista "formato" como atributo de `Source`, mas o ERD do mesmo documento só tem a coluna `type`. A change corrige o ERD, mantendo o formato como atributo de domínio marcado como não exposto na API v1.

### 7. Rotas: conversas aninhadas em notebook, mensagens na raiz

Mantemos o aninhamento do contrato de referência: `/notebooks/{id}/conversations` mas `/conversations/{id}/messages`.

É aparentemente inconsistente, e é uma escolha, não um acidente herdado: uma conversa só faz sentido no contexto de um notebook (criar e listar precisam desse escopo), enquanto o `conversationId` já é suficiente para localizar mensagens — repetir o notebook na rota seria redundância que o servidor teria de validar por coerência. O mesmo raciocínio se aplica à alteração de sources ativas, que fica em `/conversations/{id}/active-sources`.

### 8. Reescrita do `API.md` preserva a rastreabilidade de telas

O documento passa a ser contrato REST, mas cada grupo de endpoints mantém a anotação de qual tela o consome (Telas 1/2/3). O contrato de referência não tem isso, e é informação que o projeto não deveria perder ao ganhar detalhe técnico.

### 9. O que não se copia do contrato de referência

- **UUIDs de exemplo inválidos**: o documento de referência usa valores como `772a0622-g41d-63f6-c938-668877662222`, com caracteres não hexadecimais. Os exemplos do `API.md` usam UUIDs válidos.
- **`X-Accel-Buffering: no` como solução de streaming**: esse header instrui o nginx a não bufferizar. Ele não endereça o buffering e o teto de timeout de ~29s do API Gateway, que é o risco registrado no `ARCHITECTURE.md`. O header pode constar do contrato como parte dos headers de response, mas o `ARCHITECTURE.md` ganha nota explícita de que o risco continua aberto e sem mitigação decidida.

## Risks / Trade-offs

- **Seleção obrigatória adiciona atrito no primeiro uso** → o frontend desabilita "nova conversa" até a primeira source atingir `READY`, com indicação visível do motivo, em vez de deixar o usuário descobrir por um `400`.
- **Conversa em estado degradado pode confundir** → o `409 NO_ACTIVE_SOURCES` é um código distinto justamente para o frontend poder dizer o que aconteceu e oferecer a ação de correção, em vez de exibir um erro genérico.
- **O risco de streaming via API Gateway permanece aberto** → detalhar o contrato SSE dá a impressão de que o caminho está resolvido. A nota explícita no `ARCHITECTURE.md` existe para impedir essa leitura; a decisão de mitigação continua pendente para quando o desenho de infraestrutura avançar.
- **Contrato detalhado envelhece mais rápido que prosa** → cada change de implementação que altere comportamento passa a ter de atualizar `API.md` junto. É o custo de ter um contrato do qual se programa, e é o motivo de as specs em `openspec/specs/` serem a fonte de verdade de comportamento: elas descrevem o observável, enquanto o `API.md` descreve a superfície HTTP.
- **As quatro capabilities foram derivadas do contrato, não de código em produção** → nenhuma implementação as validou ainda. Divergências descobertas na implementação devem voltar como changes que modificam estas specs, não como ajustes silenciosos no código.

## Migration Plan

Não aplicável — nenhum código, dado ou cliente em produção. A change é inteiramente documental: os três `.md` de fundação são atualizados em um único passo, e as quatro capabilities passam a existir em `openspec/specs/` no arquivamento.

## Open Questions

- O limite de tamanho de arquivo aceito no upload de source não está definido em nenhum documento. Pode ser resolvido na change de implementação de ingestão sem alterar estas specs — afeta um valor de configuração e uma mensagem de erro, não o contrato.
- A prévia da conversa (`preview`) tem comprimento de truncamento não especificado. Detalhe de apresentação, resolvível depois.
