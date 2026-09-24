# Tasks

## 1. Ambiente local

- [x] 1.1 Criar `app/backend/local/init.sql` com `CREATE EXTENSION IF NOT EXISTS vector` e o DDL das
  tabelas do ERD de `DOMAIN.md` (`users`, `notebooks`, `sources`, `source_chunks`, `conversations`,
  `conversation_messages`, `conv_active_sources`), com `vector(1536)` em `source_chunks.embedding`
  conforme o ERD. Incluir comentário no topo avisando que alterações só têm efeito após
  `docker compose down -v` (risco R2 do design)
- [x] 1.2 Criar `app/backend/local/docker-compose.yml` com o serviço `postgres`
  (`pgvector/pgvector:pg18`, banco/usuário/senha batendo com os defaults do application.yml, `init.sql`
  montado em `/docker-entrypoint-initdb.d/`, healthcheck `pg_isready`) e verificar que
  `docker compose up` deixa o serviço `healthy`
- [x] 1.3 Verificar que o schema foi criado: `\dt` no psql do container lista as 7 tabelas e
  `SELECT extname FROM pg_extension` inclui `vector`
- [x] 1.4 Adicionar o serviço `floci` (`floci/floci:2.1.0`, porta 4566, `FLOCI_STORAGE_MODE=memory`,
  `FLOCI_HOSTNAME=floci`, healthcheck em `/_floci/health`) e verificar que
  `curl http://localhost:4566/_floci/health` responde com o serviço no ar

## 2. Configuração parametrizada da aplicação

- [x] 2.1 Reescrever `app/backend/src/main/resources/application.yml` com datasource
  (`SPRING_DATASOURCE_URL`, `_USERNAME`, `_PASSWORD`), `ddl-auto` com default `validate` e
  `SERVER_PORT`, todos no formato `${VAR:default}` com defaults batendo com o compose
- [x] 2.2 Adicionar as propriedades do vector store pgvector (`dimensions` com default `1536`,
  `index-type`, `initialize-schema`) e do provedor de LLM compatível com OpenAI (`base-url`,
  `api-key`, modelo de chat e modelo de embedding), todas parametrizadas
- [x] 2.3 Verificar que `./mvnw spring-boot:run` sobe a aplicação com o compose no ar e apenas a
  chave do provedor de LLM exportada no ambiente
- [x] 2.4 Verificar que a URL do datasource é sobrescrita por variável de ambiente: subir com
  `SPRING_DATASOURCE_URL` apontando para um banco inexistente e confirmar que o boot falha por não
  alcançar esse endereço, e não o default

## 3. Health para o Load Balancer

- [x] 3.1 Adicionar `spring-boot-starter-actuator` ao `pom.xml` e verificar que `./mvnw verify`
  continua passando
- [x] 3.2 Configurar a exposição do actuator limitada ao endpoint de health (decisão D6) e verificar
  que `/actuator/env` e `/actuator/beans` respondem `404`
- [x] 3.3 Verificar o cenário "Instância saudável" da spec `health`: `GET /actuator/health` sem
  header `Authorization` responde `200`
- [x] 3.4 Verificar o cenário "Instância sem acesso ao banco": com o container do postgres parado,
  `GET /actuator/health` responde status diferente de `200`
- [x] 3.5 Verificar o cenário "Ausência de detalhes de infraestrutura": o corpo da resposta de health
  não contém host, porta, usuário, senha, versão do banco nem mensagem de erro da conexão

## 4. Segredos e fechamento

- [x] 4.1 Adicionar `.env` ao `.gitignore` e verificar com `git check-ignore -v app/backend/.env`
- [x] 4.2 Verificar que nenhum segredo real ficou versionado: `git grep` pelos nomes das variáveis de
  chave de LLM nos arquivos rastreados retorna apenas placeholders e defaults de ambiente local
- [x] 4.3 Executar `openspec validate parameterize-backend-configuration --strict` e confirmar que
  passa
