# Conversations

## Purpose

Sessões de chat independentes dentro de um notebook, cada uma com seu próprio histórico e sua própria seleção explícita de sources ativas, que define o escopo de busca das perguntas feitas nela.

## Requirements

### Requirement: Seleção de sources ativas é obrigatória e não-vazia

O sistema SHALL exigir uma seleção explícita de pelo menos uma source ativa para criar uma conversa. Lista omitida ou vazia MUST ser recusada. Não existe contexto implícito de "todas as sources do notebook": o escopo de busca é sempre uma lista materializada e persistida na conversa.

#### Scenario: Criação com seleção válida

- **WHEN** um usuário autenticado cria uma conversa informando uma ou mais sources `READY` do notebook
- **THEN** a resposta é `201` com a conversa criada e a lista de sources ativas
- **AND** a conversa passa a pertencer ao notebook informado

#### Scenario: Criação sem informar sources

- **WHEN** um usuário autenticado tenta criar uma conversa sem informar sources ativas, ou informando uma lista vazia
- **THEN** a resposta é `400` com `error` igual a `VALIDATION_ERROR`
- **AND** nenhuma conversa é criada

#### Scenario: Notebook sem nenhuma source pronta

- **WHEN** um usuário autenticado tenta criar uma conversa em um notebook cujas sources estão todas em `PENDING`, `PROCESSING` ou `FAILED`
- **THEN** não há seleção válida possível e a criação é recusada com `400`
- **AND** a criação de conversas nesse notebook só se torna possível quando ao menos uma source atingir `READY`

### Requirement: Só sources prontas do próprio notebook podem ser ativadas

O sistema SHALL recusar a ativação de uma source que não pertença ao notebook da conversa, e SHALL recusar a ativação de uma source cujo status não seja `READY`. As duas recusas MUST ser distinguíveis pelo cliente.

#### Scenario: Source de outro notebook

- **WHEN** um usuário autenticado informa, entre as sources ativas, uma source que pertence a outro notebook
- **THEN** a resposta é `400` com `error` igual a `INVALID_SOURCE_IDS`
- **AND** nenhuma das sources informadas é ativada

#### Scenario: Source ainda em processamento

- **WHEN** um usuário autenticado informa, entre as sources ativas, uma source do notebook cujo status é `PROCESSING`
- **THEN** a resposta é `400` com `error` igual a `SOURCE_NOT_READY`
- **AND** nenhuma das sources informadas é ativada

#### Scenario: Source com processamento falho

- **WHEN** um usuário autenticado informa, entre as sources ativas, uma source do notebook cujo status é `FAILED`
- **THEN** a resposta é `400` com `error` igual a `SOURCE_NOT_READY`

### Requirement: Seleção de sources ativas é alterável ao longo da conversa

O sistema SHALL permitir alterar a seleção de sources ativas de uma conversa existente a qualquer momento. A nova seleção MUST valer para as mensagens seguintes e MUST NOT alterar o histórico já produzido. A seleção MUST NOT poder ser esvaziada: a alteração substitui a lista, sempre por outra com pelo menos uma source.

#### Scenario: Troca de seleção no meio da conversa

- **WHEN** um usuário autenticado altera as sources ativas de uma conversa que já possui mensagens
- **THEN** a resposta é `200` com a nova lista de sources ativas
- **AND** as mensagens já trocadas permanecem inalteradas no histórico
- **AND** as perguntas seguintes passam a ser respondidas com base na nova seleção

#### Scenario: Tentativa de esvaziar a seleção

- **WHEN** um usuário autenticado tenta alterar as sources ativas de uma conversa informando uma lista vazia
- **THEN** a resposta é `400` com `error` igual a `VALIDATION_ERROR`
- **AND** a seleção anterior permanece em vigor

### Requirement: Conversa sobrevive à deleção de uma source ativa

Quando uma source ativa em uma conversa é deletada, o sistema SHALL preservar a conversa e todo o seu histórico, removendo a source da seleção ativa. Se a seleção ficar vazia, a conversa MUST entrar em estado sem seleção válida: o histórico permanece legível, novas mensagens são recusadas, e a conversa volta a ser utilizável assim que o usuário ativar outra source.

#### Scenario: Deleção de uma entre várias sources ativas

- **WHEN** uma source ativa é deletada de uma conversa que tinha outras sources ativas
- **THEN** a conversa permanece utilizável
- **AND** a source deletada deixa de constar na seleção ativa
- **AND** as perguntas seguintes são respondidas com base nas sources ativas restantes

#### Scenario: Deleção da última source ativa

- **WHEN** a única source ativa de uma conversa é deletada
- **THEN** a conversa e seu histórico continuam existindo e legíveis
- **AND** a seleção ativa fica vazia

#### Scenario: Recuperação após perder a última source ativa

- **WHEN** um usuário autenticado ativa uma source `READY` em uma conversa que estava sem seleção válida
- **THEN** a resposta é `200` com a nova seleção
- **AND** a conversa volta a aceitar novas mensagens

### Requirement: Listar conversas de um notebook

O sistema SHALL retornar as conversas de um notebook ordenadas por data de criação decrescente, cada uma com uma prévia textual derivada de sua primeira mensagem. A prévia MUST ser um valor derivado, não um atributo editável pelo usuário. A listagem MUST ser sempre um array.

#### Scenario: Notebook sem conversas

- **WHEN** um usuário autenticado lista as conversas de um notebook seu que ainda não tem conversas
- **THEN** a resposta é `200` com um array vazio

#### Scenario: Prévia de conversa sem mensagens

- **WHEN** um usuário autenticado lista as conversas e uma delas foi criada mas ainda não recebeu mensagens
- **THEN** a conversa consta na listagem com prévia vazia ou ausente

### Requirement: Conversas são isoladas entre si e por usuário

Cada conversa SHALL manter seu próprio histórico e sua própria seleção de sources ativas, independentes das demais conversas do mesmo notebook. Uma conversa de outro usuário MUST resultar em `404 CONVERSATION_NOT_FOUND`.

#### Scenario: Duas conversas no mesmo notebook

- **WHEN** um usuário autenticado cria duas conversas no mesmo notebook com seleções de sources diferentes
- **THEN** cada conversa responde com base apenas na sua própria seleção
- **AND** alterar a seleção de uma não afeta a outra

#### Scenario: Acesso a conversa de outro usuário

- **WHEN** um usuário autenticado acessa uma conversa que pertence a um notebook de outro usuário
- **THEN** a resposta é `404` com `error` igual a `CONVERSATION_NOT_FOUND`
