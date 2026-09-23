# CLAUDE.md

Este arquivo indexa a documentação de fundação do projeto.

## Sobre o Projeto

Notebook LM simplificado: uma plataforma para agrupar fontes de conhecimento (*sources*) dentro de notebooks e conversar com um assistente de IA (RAG) sobre esse conteúdo.

## Documentação de Fundação

```
/
├── CLAUDE.md            <- este arquivo (índice)
├── DOMAIN.md             <- entidades, relacionamentos e regras de negócio
├── API.md                <- funcionalidades e contratos da API
├── ARCHITECTURE.md       <- visão de alto nível da arquitetura e relação entre serviços
└── openspec/
    ├── config.yaml        <- configuração do processo de spec-driven development
    ├── specs/              <- capabilities especificadas (incremental)
    └── changes/            <- mudanças propostas e em andamento (incremental)
```

- [DOMAIN.md](./DOMAIN.md) — entidades do domínio, relacionamentos e regras de negócio.
- [API.md](./API.md) — funcionalidades expostas e contratos entre frontend e backend.
- [ARCHITECTURE.md](./ARCHITECTURE.md) — visão de alto nível da arquitetura, componentes AWS envolvidos e decisões/riscos arquiteturais.

## Estado do Projeto

Fase de fundação: apenas documentação de domínio, API e arquitetura definida. Nenhuma implementação de código foi iniciada ainda. Mudanças incrementais a partir daqui devem ser propostas via OpenSpec (`openspec/`).
