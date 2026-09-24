# Design

## Context

Ver `proposal.md` — Why. Restam as restrições que moldam a abordagem:

- `ARCHITECTURE.md` exige aplicação **stateless** atrás de Load Balancer e provedor de LLM
  intercambiável (Bedrock/OpenRouter) via contrato compatível com a API da OpenAI.
- O `pom.xml` já traz Data JPA, driver PostgreSQL e os starters do Spring AI (pgvector e OpenAI).
  Não traz SDK da AWS, Spring Security nem Flyway.
- `DOMAIN.md` traz um ERD completo (6 tabelas + associativa), mas **não existe nenhuma entidade
  JPA no código**.
- O compose fica em `app/backend/local/`, por decisão do projeto.

## Goals / Non-Goals

**Goals:**
- Uma única configuração que sirva laptop e cloud, variando apenas por variável de ambiente.
- `docker compose up` seguido de `./mvnw spring-boot:run` levanta a aplicação sem que o
  desenvolvedor precise exportar nada além da chave do provedor de LLM.
- Trocar Bedrock por OpenRouter sem alterar código.

**Non-Goals:**
- Infraestrutura como código (`infra/` continua vazio) e pipeline de deploy.
- Qualquer código de aplicação que use S3, SQS ou Cognito.
- Migração de schema em produção.

## Decisions

### D1. Um `application.yml`, sem profiles

Todo valor escrito como `${VAR:default}`, onde o default é exatamente o que o compose local sobe.

Alternativas descartadas: `application-local.properties` + `application-prod.properties` duplica o
conjunto de chaves e permite que os dois divirjam sem aviso; Spring Cloud Config introduz um
serviço a operar para um problema que uma variável de ambiente resolve. Profile passa a valer
quando o *comportamento* divergir entre ambientes, não o valor.

### D2. `AWS_ENDPOINT_URL` ausente em produção

O SDK da AWS v2 honra `AWS_ENDPOINT_URL` nativamente. O ambiente local aponta para o Floci; a
produção simplesmente **não define a variável** e o SDK resolve o endpoint real.

Consequência: nenhum `endpoint-override` em código, nenhum `if (isLocal)`, nenhum profile de AWS.
A diferença entre os ambientes é a ausência de uma variável. Credencial local é `test/test` por
construção, então a chave do provedor de LLM passa a ser o único segredo real numa máquina de
desenvolvimento.

### D3. Floci em vez de LocalStack

`ARCHITECTURE.md` põe o Cognito no caminho crítico de toda requisição autenticada. O Floci inclui
Cognito com user pools e endpoint JWKS sem edição paga; no LocalStack, Cognito é recurso Pro. Como
o Floci é drop-in do LocalStack Community (mesma porta 4566, mesmo padrão de endpoint e
credenciais), trocar depois é mudar o nome da imagem.

O Floci emula o *control plane* do RDS (`CreateDBInstance`), não um engine PostgreSQL — muito menos
pgvector. Por isso o PostgreSQL continua sendo um container próprio, real.

### D4. `init.sql` é o dono do schema local; `ddl-auto=validate`

O DDL do ERD de `DOMAIN.md` vive em `app/backend/local/init.sql`, montado em
`/docker-entrypoint-initdb.d/`. O JPA não cria nem altera schema: `ddl-auto` fica parametrizado com
default `validate`, então a divergência entre entidade e tabela falha no boot, barulhenta, em vez
de o Hibernate alterar a tabela silenciosamente.

**Alternativa considerada e recusada por ora: Flyway.** Tecnicamente superior — o mesmo arquivo
roda no compose e no RDS, aplica incremental sem destruir o volume, e elimina a duplicação de DDL
entre ambientes. Foi recusada porque este repositório acompanha um curso em andamento, e divergir
do material no meio do percurso custa mais atrito de acompanhamento do que a dívida gerada. A
migração de `init.sql` para `V1__schema.sql` é essencialmente copiar um arquivo, e está prevista na
change que endereçar o schema de produção (ver R1).

`CREATE EXTENSION IF NOT EXISTS vector` entra no `init.sql` por clareza, embora o
`initialize-schema` do Spring AI também o execute.

### D5. Sem `spring-boot-docker-compose`

O módulo levantaria o compose e injetaria a datasource automaticamente — menos configuração ainda,
mas esconde do desenvolvedor qual URL a aplicação está usando, que é exatamente o que o fator III
quer explícito. O compose também precisa ser utilizável isoladamente (frontend, CI, inspeção via
CLI), não apenas como efeito colateral do boot da aplicação.

### D6. Actuator apenas para health

Entra `spring-boot-starter-actuator`, mas só o endpoint de health é exposto. Os demais endpoints do
actuator (`env`, `configprops`, `beans`, `heapdump`) revelam configuração e estado interno, e o
requisito de acesso sem autenticação torna a exposição completa um vazamento direto.

## Risks / Trade-offs

**R1. O `init.sql` não existe em produção.** A imagem do PostgreSQL só executa
`/docker-entrypoint-initdb.d/` quando o diretório de dados está vazio, e o RDS nunca o executará.
→ Mitigação: registrado como bloqueador explícito de deploy. Nenhum ambiente de cloud pode ser
provisionado antes de uma change que defina a migração de schema. Sem isso, o schema de produção
não tem dono.

**R2. Alterar o `init.sql` não tem efeito em um volume já inicializado.** O desenvolvedor edita o
DDL, sobe o compose e não vê mudança — sem erro.
→ Mitigação: comentário no topo do `init.sql` e no `docker-compose.yml` indicando que alterações
exigem `docker compose down -v`, com a perda de dados local que isso implica.

**R3. `source_chunks` provavelmente nasce vazia.** O `PgVectorStore` do Spring AI cria e usa tabela
própria, de schema fixo (`id`, `content`, `metadata jsonb`, `embedding`), e não a `source_chunks`
do ERD. O RAG gravaria em uma tabela enquanto o modelo de domínio descreve outra.
→ Mitigação: nenhuma nesta change — não há código de persistência ainda. Fica registrado como a
decisão a resolver na primeira change de persistência: usar a tabela do Spring AI com `source_id`
em `metadata` (perdendo FK e cascade da regra 10 de `DOMAIN.md`), ou implementar um vector store
próprio sobre `source_chunks`.

**R4. O Floci sobe sem nada que o exercite.** Nenhuma dependência da aplicação fala com ele nesta
change, então uma regressão no serviço local não é detectada pelo build.
→ Mitigação: aceito deliberadamente. A validação é manual, via `aws --endpoint-url`, até a change
que trouxer o S3. O custo do Floci no compose é um bloco de serviço.

**R5. Endereçamento de S3 virtual-host não resolve em rede Docker.** `meu-bucket.floci:4566` não
tem DNS, e essa é a falha mais comum ao usar emulador de AWS.
→ Mitigação: fora de escopo aqui; anotado para entrar junto com a configuração de S3, que precisará
de path-style access no ambiente local.

## Migration Plan

Não há estado anterior a migrar: o `application.properties` que existia tinha uma linha, foi
substituído por `application.yml` e nenhum ambiente está provisionado. Rollback é reverter o commit.

## Open Questions

- Qual modelo de embedding e, por consequência, qual dimensão do vetor
  (`spring.ai.vectorstore.pgvector.dimensions`) usar como default local. Parametrizado desde o
  início, então a escolha do valor não altera specs, abordagem nem tarefas.
