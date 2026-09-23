# Design

## Context

Ver proposal.md - Why. O ERD fornecido para o banco de dados já define a estrutura-alvo (`conversations`, `conv_active_sources`, `conversation_messages`); este documento explica as escolhas feitas ao traduzir esse ERD para os termos de domínio já usados em `DOMAIN.md`.

## Goals / Non-Goals

**Goals:**
- Alinhar as entidades, relacionamentos e regras de negócio de `DOMAIN.md` ao ERD fornecido, sem perder nenhuma regra de negócio já registrada que continue válida.
- Preservar a terminologia conceitual já estabelecida em `DOMAIN.md` (entidades em PascalCase, foco em regras de negócio) em vez de copiar nomes literais de tabela/coluna do ERD.
- Manter `API.md` e `ARCHITECTURE.md` consistentes com o novo modelo de domínio, evitando um estado intermediário em que os documentos de fundação se contradizem.

**Non-Goals:**
- Definir o schema físico de banco de dados (tipos de coluna, índices) — isso é escopo de uma change de design técnico quando a implementação começar.
- Especificar detalhes de endpoints REST (verbos HTTP, paths exatos) além do nível de contrato já usado em `API.md`.

## Decisions

1. **`Conversation` como entidade própria, independente de `Notebook`** — um notebook passa a suportar múltiplas sessões de chat independentes (`Notebook` 1:N `Conversation`), cada uma com seu próprio histórico. Alternativa considerada: manter um único fluxo de mensagens por notebook (modelo anterior) — descartada porque o ERD fornecido já define essa estrutura explicitamente como requisito.

2. **Seleção de sources ativas passa de por-mensagem para por-conversa** (`Conversation` N:N `Source`, via `conv_active_sources`) — o usuário define o conjunto de sources ativas para a conversa, podendo alterá-lo ao longo dela; passa a valer para todas as mensagens seguintes até nova alteração. Alternativa considerada: manter a seleção por mensagem (mais granular/auditável) — descartada porque o ERD modela a seleção como associação à conversa, não à mensagem individual.

3. **`User` referencia `cognito_sub` como identidade externa, sem campo separado de provedor** — o Cognito já resolve a federação (Google/GitHub); duplicar essa informação no domínio da aplicação seria redundante. Alternativa considerada: manter "provedor de origem" como atributo — descartada por redundância.

4. **`Source` ganha mensagem de erro explícita** — permite diagnosticar falhas de processamento sem depender de inspeção de logs de infraestrutura.

5. **`SourceChunk` ganha posição do trecho e modelo de embedding usado** — suporta ordenação determinística dos trechos de um source e rastreamento de qual modelo gerou cada embedding, útil se o modelo de embedding mudar no futuro.

6. **Contrato de chat em `API.md` passa a exigir `conversation_id`, com um endpoint dedicado para atualizar as sources ativas de uma conversa** — em vez de reenviar a seleção a cada mensagem, mantendo `API.md` coerente com a seleção por conversa definida no domínio. Alternativa considerada: manter a seleção embutida no contrato de "enviar mensagem" — descartada por duplicar em cada request um estado que agora pertence à conversa, não à mensagem.

## Risks / Trade-offs

- [Risco] Mensagens antigas de uma conversa não retêm qual conjunto de sources estava ativo no momento em que foram respondidas, já que a seleção agora vive na conversa (mutável) e não na mensagem → [Mitigação] aceito como trade-off consciente, consistente com o ERD fornecido; auditoria por mensagem seria um novo requisito de domínio a ser proposto separadamente, se necessário.

## Migration Plan

Não aplicável — não há implementação nem dados existentes; a mudança afeta apenas a documentação de domínio.
