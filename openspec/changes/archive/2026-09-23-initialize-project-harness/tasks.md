# Tasks

## 1. Documentação de domínio, API e arquitetura

- [x] 1.1 Criar `DOMAIN.md` na raiz do repositório com entidades (`User`, `Notebook`, `Source`, `SourceChunk`, `ChatMessage`), relacionamentos e regras de negócio — verificar que o arquivo existe e cobre as cinco entidades e seus relacionamentos.
- [x] 1.2 Criar `API.md` na raiz do repositório com as funcionalidades e contratos de alto nível (autenticação, notebooks, sources, chat) — verificar que os quatro fluxos estão documentados.
- [x] 1.3 Criar `ARCHITECTURE.md` na raiz do repositório com o diagrama de componentes e as decisões/riscos arquiteturais (streaming de chat via SSE/API Gateway, pipeline de ingestão assíncrono via SQS/Lambda, abstração de provedor de LLM) — verificar que as três decisões estão registradas na seção "Decisões e Riscos Arquiteturais".
- [x] 1.4 Criar `CLAUDE.md` na raiz do repositório indexando `DOMAIN.md`, `API.md` e `ARCHITECTURE.md`, com a árvore de arquivos do repositório — verificar que os três links apontam para os arquivos corretos.

## 2. Configuração do OpenSpec

- [x] 2.1 Preencher o campo `context` em `openspec/config.yaml` com o resumo do projeto e do stack (Spring AI, AWS, Cognito, S3, PostgreSQL+pgvector, SQS+Lambda, Bedrock/OpenRouter, OpenSpec) — verificar com `openspec context --json` que o texto é retornado.
