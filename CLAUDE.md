# CLAUDE.md

Este arquivo indexa a documentação de fundação do projeto.

## Sobre o Projeto

Notebook LM simplificado: uma plataforma para agrupar fontes de conhecimento (*sources*) dentro de notebooks e conversar com um assistente de IA (RAG) sobre esse conteúdo.

## Documentação de Fundação

```
/
├── CLAUDE.md            <- este arquivo (índice)
├── .claude/
│   ├── settings.json     <- configuração do Claude Code compartilhada pelo time
│   ├── commands/         <- slash commands do projeto
│   └── skills/           <- skills versionadas no repositório
├── DOMAIN.md             <- entidades, relacionamentos e regras de negócio
├── API.md                <- funcionalidades e contratos da API
├── ARCHITECTURE.md       <- visão de alto nível da arquitetura e relação entre serviços
├── app/
│   ├── backend/          <- aplicação backend (Spring AI, PostgreSQL + pgvector)
│   └── frontend/         <- aplicação frontend
├── infra/                <- infraestrutura como código
└── openspec/
    ├── config.yaml        <- configuração do processo de spec-driven development
    ├── specs/              <- capabilities especificadas (incremental)
    └── changes/            <- mudanças propostas e em andamento (incremental)
```

- [DOMAIN.md](./DOMAIN.md) — entidades do domínio, relacionamentos e regras de negócio.
- [API.md](./API.md) — funcionalidades expostas e contratos entre frontend e backend.
- [ARCHITECTURE.md](./ARCHITECTURE.md) — visão de alto nível da arquitetura, componentes AWS envolvidos e decisões/riscos arquiteturais.

## Ambiente de Desenvolvimento

O repositório versiona sua própria configuração do Claude Code, para que qualquer pessoa que clone o
projeto trabalhe com o mesmo setup.

### Plugins

Declarados em `.claude/settings.json`, que traz tanto o marketplace de origem quanto a ativação — o
arquivo se basta, sem precisar de `/plugin marketplace add` manual antes.

- **ponytail** (`ponytail@ponytail`) — força a solução mais simples que funciona: YAGNI, biblioteca
  padrão antes de dependência nova, uma linha antes de cinquenta.

### Skills

`.claude/skills/` é a **única** origem de skills do projeto, sempre como arquivo real — nunca
symlink, nunca `.agents/`.

- `openspec-*` — fluxo de spec-driven development deste projeto.
- `java-quality-gate` — gate de cobertura (JaCoCo 100% linha) e mutação (pitest 100%) do backend.
- `postgresql-optimization`, `java-springboot` — vindas do `github/awesome-copilot`.

**Ao instalar uma skill de terceiro** (por exemplo `npx skills add <repo> --skill <nome>`), seguir
sempre este procedimento:

1. Rodar o instalador.
2. Materializar o conteúdo em `.claude/skills/<nome>/` como arquivo real; se o instalador criou um
   symlink, substituí-lo pelo arquivo.
3. Apagar `.agents/` e `skills-lock.json`, que o instalador cria na raiz.
4. Limpar resíduos do formato de origem: placeholders de outras ferramentas (`${selection}`) e
   caracteres corrompidos em headings.
5. Conferir que a skill carregou antes de apagar a origem.

Por que arquivo real e não o symlink que o instalador cria: git versiona symlink como modo `120000`,
e em clone no Windows sem permissão de link simbólico ele vira um arquivo de texto com o caminho
dentro — a skill quebra em silêncio. Como este repositório é material de curso e será clonado por
outras pessoas, a previsibilidade vale mais que a comodidade.

Custo aceito: sem atualização automática pelo CLI. Essas skills passam a ser nossas, e atualizar
significa reinstalar num diretório temporário e comparar.

A regra geral que separa as duas formas: skill que descreve *este* repositório mora em
`.claude/skills/`; ferramenta de terceiro com manutenção ativa entra como plugin, para continuar
recebendo as correções do autor.

## Estado do Projeto

Fundação (domínio, API e arquitetura) definida, e a implementação começou: `app/backend` já tem o scaffold inicial do backend (Spring Boot + Spring AI, dependências de PostgreSQL/pgvector já configuradas), sem lógica de negócio ainda. `app/frontend` e `infra/` ainda são placeholders vazios. Mudanças incrementais a partir daqui devem ser propostas via OpenSpec (`openspec/`), incluindo specs de comportamento (não mais dispensáveis via `skip_specs`, já que agora há um sistema em construção).
