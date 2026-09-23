# Proposal

## Why

O ERD fornecido para o banco de dados introduz uma estrutura de conversas mais rica do que a atualmente descrita em `DOMAIN.md`: um notebook passa a suportar múltiplas sessões de chat (`conversations`), cada uma com seu próprio histórico de mensagens e sua própria seleção de sources ativas — em vez de um único fluxo de mensagens por notebook com seleção de sources por pergunta. `DOMAIN.md` precisa ser atualizado para refletir esse modelo antes que outras changes (API, design técnico) sejam construídas sobre uma descrição de domínio desatualizada.

## What Changes

- **BREAKING** (em relação ao domínio documentado, não a código — nenhum código existe ainda): `ChatMessage` é substituída por duas entidades: `Conversation` (sessão de chat dentro de um notebook) e `ConversationMessage` (mensagem dentro de uma conversa).
- Um `Notebook` passa a ter `1:N` com `Conversation` — múltiplas conversas independentes por notebook, cada uma com seu próprio histórico.
- A seleção de sources ativas deixa de ser por pergunta/mensagem e passa a ser por `Conversation` (relação `N:N` entre `Conversation` e `Source`, mutável ao longo da conversa).
- `Notebook` ganha um atributo de descrição opcional, além do nome e das datas de criação/atualização.
- `Source` ganha um atributo de mensagem de erro, para diagnóstico quando o processamento assíncrono falha.
- `SourceChunk` ganha atributos de posição do trecho dentro do source e do modelo de embedding usado para gerá-lo, suportando reprocessamento com modelos diferentes.
- `User` passa a referenciar explicitamente o identificador emitido pelo Cognito (`cognito_sub`) como sua identidade externa, em vez de registrar o provedor de origem (Google/GitHub) como atributo separado — a distinção de provedor é responsabilidade do Cognito, não do domínio da aplicação.
- `API.md` ganha Conversations como recurso próprio: criar conversa dentro de um notebook, listar conversas de um notebook, e um contrato dedicado para atualizar as sources ativas de uma conversa.
- `API.md`: "Enviar mensagem" e "Histórico de mensagens" passam a referenciar uma `conversation_id`, não mais o notebook diretamente, e deixam de carregar a seleção de sources a cada mensagem.
- `ARCHITECTURE.md`: o parágrafo "Seleção de sources no chat" é ajustado para refletir que a seleção acontece por conversa, não por pergunta individual — sem mudança estrutural ou de componentes.

## Capabilities

Esta change não altera nem introduz comportamento de um sistema em execução — o projeto ainda não tem implementação. Ela revisa a documentação de domínio (`DOMAIN.md`) para alinhá-la ao ERD de banco de dados fornecido. Por isso, não há capabilities novas ou modificadas; `skip_specs: true` foi declarado em `.openspec.yaml`.

## Impact

- `DOMAIN.md`: entidades, relacionamentos e regras de negócio reescritos para refletir `Conversation`/`ConversationMessage` e a seleção de sources por conversa.
- `API.md`: seção de Notebooks/Chat reestruturada para incluir Conversations como recurso próprio (criar, listar, atualizar sources ativas); "Enviar mensagem" e "Histórico de mensagens" passam a ser escopados por conversa.
- `ARCHITECTURE.md`: parágrafo "Seleção de sources no chat" ajustado para refletir a seleção por conversa; nenhuma mudança estrutural ou de componentes.
- `CLAUDE.md` não precisa de alterações — o índice continua válido.
- Nenhum código ou infraestrutura é afetado.
