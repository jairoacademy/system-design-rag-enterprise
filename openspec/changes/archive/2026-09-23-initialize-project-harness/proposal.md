# Proposal

## Why

O projeto é greenfield: antes de especificar qualquer capability (auth, notebooks, sources, chat), é preciso uma fundação comum — domínio, contratos de API e arquitetura de alto nível — para que mudanças futuras tenham um ponto de partida consistente e não precisem re-derivar decisões básicas a cada proposta.

## What Changes

- Criação de `DOMAIN.md` na raiz do repositório: entidades (`User`, `Notebook`, `Source`, `SourceChunk`, `ChatMessage`), relacionamentos e regras de negócio.
- Criação de `API.md` na raiz do repositório: funcionalidades e contratos de alto nível entre frontend e backend (auth, notebooks, sources, chat).
- Criação de `ARCHITECTURE.md` na raiz do repositório: visão de componentes, decisões e riscos arquiteturais (streaming de chat via SSE, pipeline de ingestão assíncrono, abstração de provedor de LLM).
- Criação de `CLAUDE.md` na raiz do repositório: índice da documentação de fundação, com a árvore de arquivos do repositório.
- Preenchimento do campo `context` em `openspec/config.yaml` com o resumo do projeto e do stack, para que futuras propostas OpenSpec já partam desse contexto.

## Capabilities

Esta change não altera nem introduz comportamento do sistema — não há sistema em execução ainda. Ela apenas estabelece a documentação de fundação (domínio/API/arquitetura) e a configuração do processo de especificação. Por isso, não há capabilities novas ou modificadas; `skip_specs: true` foi declarado em `.openspec.yaml`.

## Impact

- Novos arquivos na raiz do repositório: `DOMAIN.md`, `API.md`, `ARCHITECTURE.md`, `CLAUDE.md`.
- `openspec/config.yaml` atualizado (campo `context`).
- Nenhum código, API em execução ou dependência é afetado — esta change é puramente documental/organizacional e serve de base para as próximas changes (ex.: autenticação via Cognito, gestão de notebooks, upload/ingestão de sources, chat).
