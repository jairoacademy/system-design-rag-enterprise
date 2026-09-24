# Proposal

## Why

O `app/backend` tinha `spring.application.name=demo` em um `application.properties` como única
configuração, mas o `pom.xml` já declara Data JPA, driver PostgreSQL, `spring-ai-starter-vector-store-pgvector` e
`spring-ai-starter-model-openai` — dependências que exigem datasource e credenciais de LLM para o
contexto sequer subir. Na prática, não existe hoje um comando que levante a aplicação localmente.

Ao mesmo tempo, `ARCHITECTURE.md` descreve uma aplicação stateless atrás de um Load Balancer, com
provedor de LLM intercambiável (Bedrock/OpenRouter) e serviços de backing da AWS. Essas duas
exigências — subir na máquina do dev e subir na cloud — precisam ser atendidas pela *mesma*
configuração, parametrizada por ambiente (12-factor, fator III), e não por arquivos divergentes.

## What Changes

- **Ambiente local** (`app/backend/local/`): `docker-compose.yml` com PostgreSQL + pgvector e
  Floci (emulador local de AWS, drop-in do LocalStack Community), ambos com healthcheck.
- **Bootstrap de schema local** (`app/backend/local/init.sql`): `CREATE EXTENSION vector` e o DDL
  das tabelas do ERD de `DOMAIN.md`, montado em `/docker-entrypoint-initdb.d/`.
- **`application.yml` parametrizado**: todo valor como `${VAR:default}`, onde o default é
  exatamente o que o compose local sobe. Cobre datasource, vector store pgvector, provedor de LLM
  compatível com OpenAI, porta HTTP e `ddl-auto`.
- **Endpoint de health**: `spring-boot-starter-actuator` no `pom.xml`, expondo `/actuator/health`
  sem autenticação, para o health check do Load Balancer.
- **Segredos**: `.env` no `.gitignore`. A chave do provedor de LLM passa a ser o único segredo real
  numa máquina de desenvolvimento — credencial de AWS local é `test/test` por construção.

Sem quebra de contrato: não há comportamento de API existente sendo alterado.

## Capabilities

### New Capabilities
- `health`: exposição de um endpoint de verificação de saúde da aplicação, consumido pelo Load
  Balancer para decidir se a instância recebe tráfego. Cobre o acesso sem autenticação e a
  inclusão do estado da conexão com o banco no resultado.

### Modified Capabilities
<!-- Nenhuma. As capabilities existentes (notebooks, sources, conversations, chat) não têm
     requisito alterado: esta change é de configuração e de ambiente de execução. -->

## Impact

**Arquivos**
- novo: `app/backend/local/docker-compose.yml`, `app/backend/local/init.sql`
- alterado: `app/backend/src/main/resources/application.yml`, `app/backend/pom.xml`
- novo/alterado: `.gitignore` (entrada para `.env`)

**Dependências**
- adiciona `spring-boot-starter-actuator`.
- **não** adiciona SDK da AWS, Spring Cloud AWS, Spring Security nem Flyway.

**Fora de escopo, com risco registrado**
- *Quem cria o schema em produção.* O `init.sql` só é executado pela imagem do PostgreSQL na
  primeira subida de um volume vazio, e nunca será executado pelo RDS. A migração de schema na
  cloud fica em aberto e precisa de uma change própria antes de qualquer deploy.
- *`source_chunks` versus a tabela do `PgVectorStore`.* O ERD de `DOMAIN.md` define
  `source_chunks`, mas o `PgVectorStore` do Spring AI cria e usa tabela própria de schema fixo.
  Criar `source_chunks` aqui provavelmente resulta numa tabela vazia e ignorada. A reconciliação
  entre o modelo de domínio e o vector store do Spring AI é decisão de uma change de persistência.
- *S3 em endereçamento path-style.* O Floci sobe no compose, mas nenhuma dependência da aplicação
  fala com ele nesta change. A configuração de path-style access (necessária para que buckets
  resolvam em rede Docker) entra junto com o código que usar o S3.
