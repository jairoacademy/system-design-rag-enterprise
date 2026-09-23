# Tasks

## 1. Atualizar entidades

- [x] 1.1 Reescrever a entidade `User` em `DOMAIN.md`, substituindo o atributo "provedor de origem" pela referência ao identificador externo emitido pelo Cognito (`cognito_sub`) — verificar que a seção `User` referencia essa identidade e não lista mais um campo de provedor separado.
- [x] 1.2 Adicionar descrição opcional e data de atualização à entidade `Notebook` em `DOMAIN.md` — verificar que os dois novos atributos aparecem na lista de `Notebook`.
- [x] 1.3 Adicionar mensagem de erro à entidade `Source` em `DOMAIN.md` — verificar que o atributo aparece e que é referenciado por uma regra de negócio sobre falha de processamento.
- [x] 1.4 Adicionar posição do trecho e modelo de embedding usado à entidade `SourceChunk` em `DOMAIN.md` — verificar que os dois atributos aparecem na lista.
- [x] 1.5 Substituir a entidade `ChatMessage` por `Conversation` (pertence a `Notebook`, 1:N) e `ConversationMessage` (pertence a `Conversation`, 1:N) em `DOMAIN.md` — verificar que `ChatMessage` não aparece mais no documento e que as duas novas entidades estão descritas com seus atributos.

## 2. Atualizar relacionamentos e regras de negócio

- [x] 2.1 Atualizar o diagrama de relacionamentos em `DOMAIN.md`, substituindo `Notebook`-`ChatMessage` por `Notebook`-`Conversation`, `Conversation`-`ConversationMessage` e `Conversation`-`Source` (N:N, sources ativas) — verificar que o diagrama lista essas cinco relações.
- [x] 2.2 Reescrever as regras de negócio de seleção de sources e histórico de chat, refletindo que a seleção de sources ativas é feita por `Conversation` (não por mensagem) e que um `Notebook` pode ter múltiplas `Conversation`s independentes — verificar que nenhuma regra restante menciona seleção por pergunta individual.
- [x] 2.3 Adicionar regra de negócio sobre o uso da mensagem de erro em `Source` quando o processamento falha — verificar que a regra existe e referencia o status "falhou".

## 3. Atualizar API.md

- [x] 3.1 Adicionar seção "Conversations" a `API.md`: criar conversa dentro de um notebook, listar conversas de um notebook — verificar que a seção existe e referencia o notebook ao qual a conversa pertence.
- [x] 3.2 Adicionar contrato para atualizar as sources ativas de uma conversa em `API.md` — verificar que o contrato existe e referencia que apenas sources com status "pronto" podem ser ativadas.
- [x] 3.3 Reescrever "Enviar mensagem" e "Histórico de mensagens" em `API.md` para referenciar `conversation_id` em vez do notebook diretamente, removendo a seleção de sources por mensagem — verificar que os dois contratos referenciam a conversa, não mais o notebook nem uma seleção por pergunta.

## 4. Atualizar ARCHITECTURE.md

- [x] 4.1 Reescrever o parágrafo "Seleção de sources no chat" em `ARCHITECTURE.md` para refletir que a seleção acontece por conversa, não por pergunta — verificar que o texto não menciona mais "naquela interação".

## 5. Validação final

- [x] 5.1 Revisar `DOMAIN.md`, `API.md` e `ARCHITECTURE.md` por completo e confirmar, por busca textual, que não há mais referências a `ChatMessage`, a seleção de sources por mensagem/pergunta, nem a "provedor de origem" como atributo de `User`.

## 6. Correções pós-revisão (auditoria campo a campo com o ERD)

- [x] 6.1 Separar, na entidade `Source` em `DOMAIN.md`, o atributo de nome de exibição da referência de armazenamento (chave do arquivo no S3 ou URL de origem) — verificar que os dois conceitos aparecem como bullets distintos.
- [x] 6.2 Adicionar "data de criação" à entidade `SourceChunk` em `DOMAIN.md` — verificar que o atributo aparece na lista.
- [x] 6.3 Adicionar uma seção "Modelo de Relacionamentos (ERD)" a `DOMAIN.md` com o diagrama de schema (tabelas, PK/FK, tipos de coluna) fornecido pelo usuário, como referência complementar à visão conceitual já existente — verificar que a seção existe e lista as sete tabelas (`users`, `notebooks`, `sources`, `source_chunks`, `conversations`, `conv_active_sources`, `conversation_messages`).
