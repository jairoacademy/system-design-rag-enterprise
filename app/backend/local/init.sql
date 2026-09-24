-- Schema local do system-design-rag-enterprise.
--
-- ATENCAO: a imagem oficial do PostgreSQL so executa /docker-entrypoint-initdb.d/
-- quando o diretorio de dados esta vazio. Editar este arquivo NAO tem efeito em um
-- volume ja inicializado: e preciso rodar `docker compose down -v` (o que apaga os
-- dados locais) para que ele rode de novo.
--
-- Este arquivo nao roda em producao. O RDS nunca executa initdb scripts; a migracao
-- de schema na cloud ainda nao tem dono. Ver design.md, risco R1.

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE users (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cognito_sub  text        NOT NULL UNIQUE,
    email        text        NOT NULL,
    name         text        NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE notebooks (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id    uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name        text        NOT NULL,
    description text,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_notebooks_owner ON notebooks (owner_id, created_at DESC);

CREATE TABLE sources (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    notebook_id   uuid        NOT NULL REFERENCES notebooks (id) ON DELETE CASCADE,
    name          text        NOT NULL,
    type          text        NOT NULL CHECK (type IN ('FILE', 'URL')),
    format        text        NOT NULL CHECK (format IN ('PDF', 'MARKDOWN', 'DOCX', 'WEB_PAGE')),
    s3_key        text,
    url           text,
    status        text        NOT NULL CHECK (status IN ('PENDING', 'PROCESSING', 'READY', 'FAILED')),
    error_message text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    -- a origem determina qual referencia de armazenamento existe (DOMAIN.md, regra 3)
    CONSTRAINT sources_storage_reference CHECK (
        (type = 'FILE' AND s3_key IS NOT NULL AND url IS NULL)
        OR (type = 'URL' AND url IS NOT NULL AND s3_key IS NULL)
    )
);

CREATE INDEX idx_sources_notebook ON sources (notebook_id, created_at DESC);

CREATE TABLE source_chunks (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id       uuid        NOT NULL REFERENCES sources (id) ON DELETE CASCADE,
    content         text        NOT NULL,
    embedding       vector(1536) NOT NULL,
    chunk_index     integer     NOT NULL,
    embedding_model text        NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (source_id, chunk_index)
);

CREATE TABLE conversations (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    notebook_id uuid        NOT NULL REFERENCES notebooks (id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_conversations_notebook ON conversations (notebook_id, created_at DESC);

-- Tabela associativa (M:N): sources ativas como contexto de busca da conversa.
-- Deletar uma source a remove da selecao sem apagar a conversa (DOMAIN.md, regra 8).
CREATE TABLE conv_active_sources (
    conversation_id uuid NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
    source_id       uuid NOT NULL REFERENCES sources (id) ON DELETE CASCADE,
    PRIMARY KEY (conversation_id, source_id)
);

CREATE TABLE conversation_messages (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id uuid        NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
    role            text        NOT NULL CHECK (role IN ('user', 'assistant')),
    content         text        NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- historico de uma conversa e cronologico crescente (API.md, Colecoes)
CREATE INDEX idx_messages_conversation ON conversation_messages (conversation_id, created_at);
