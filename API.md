# API

## Visão Geral

Contrato REST entre o frontend e o backend. Este documento é a referência da qual as duas aplicações programam: define rotas, verbos, payloads de request e response, restrições de campo e códigos de erro.

Documentos relacionados: [DOMAIN.md](./DOMAIN.md) — entidades e regras de negócio · [ARCHITECTURE.md](./ARCHITECTURE.md) — componentes e decisões arquiteturais.

As telas referenciadas ao longo do documento são: **Tela 1** (login), **Tela 2** (lista de notebooks) e **Tela 3** (notebook aberto — painel de sources + chat).

---

## Convenções Gerais

### Base URL

```
/api/v1
```

### Autenticação

Todos os endpoints deste documento são protegidos e exigem:

```
Authorization: Bearer <cognito_access_token>
```

**Não existe endpoint de autenticação no backend.** Login federado (Google/GitHub), logout e leitura do perfil do usuário são interação direta entre o frontend e o Cognito (Tela 1). O nome, e-mail e avatar exibidos no ícone de perfil das Telas 2 e 3 vêm do próprio token, não de uma chamada à API.

O usuário é registrado no sistema automaticamente na primeira requisição autenticada em que seu `cognito_sub` ainda não for conhecido — sem etapa de cadastro visível para o cliente.

### Formato de erro

Toda resposta `4xx` ou `5xx` usa o mesmo envelope:

```json
{
  "error": "ERROR_CODE",
  "message": "Descrição legível do problema"
}
```

| HTTP | `error` | Situação |
|------|---------|----------|
| `400` | `VALIDATION_ERROR` | Campo obrigatório ausente ou inválido (inclui `activeSourceIds` vazio ou omitido) |
| `400` | `INVALID_SOURCE_IDS` | Sources informadas não pertencem ao notebook |
| `400` | `SOURCE_NOT_READY` | Source informada existe no notebook, mas não está em `READY` |
| `401` | `UNAUTHORIZED` | Token ausente, expirado ou inválido |
| `404` | `NOTEBOOK_NOT_FOUND` | Notebook inexistente ou de outro usuário |
| `404` | `SOURCE_NOT_FOUND` | Source inexistente ou de outro notebook/usuário |
| `404` | `CONVERSATION_NOT_FOUND` | Conversa inexistente ou de outro usuário |
| `409` | `NO_ACTIVE_SOURCES` | Conversa sem seleção válida de sources ativas |
| `415` | `UNSUPPORTED_FILE_TYPE` | Formato de arquivo não suportado |
| `500` | `INTERNAL_ERROR` | Erro inesperado do servidor |

Recursos de outro usuário retornam `404`, nunca `403` — a existência do recurso não é revelada.

### Status HTTP por operação

| Operação | Status |
|----------|--------|
| `GET` recurso único | `200 OK` |
| `GET` coleção | `200 OK` + array |
| `POST` criação síncrona | `201 Created` |
| `POST` que dispara processo assíncrono | `202 Accepted` |
| `PATCH` atualização | `200 OK` |
| `DELETE` | `204 No Content` |

### Coleções

- Uma coleção **nunca** retorna `null`; quando vazia, retorna `[]`.
- **Não há paginação na v1.**
- Ordenação padrão: `created_at` decrescente. A única exceção é o histórico de mensagens de uma conversa, que é cronológico crescente.

---

## Notebooks

### `GET /api/v1/notebooks`

Lista os notebooks do usuário autenticado. *(Tela 2)*

**Response `200 OK`:**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Projeto Alpha",
    "description": "Documentos do projeto Alpha",
    "createdAt": "2024-01-15T10:30:00Z",
    "updatedAt": "2024-01-15T10:30:00Z"
  }
]
```

---

### `POST /api/v1/notebooks`

Cria um novo notebook para o usuário autenticado. *(ação "Criar" na Tela 2)*

**Request body:**
```json
{
  "name": "Projeto Alpha",
  "description": "Documentos do projeto Alpha"
}
```

| Campo | Tipo | Obrigatório | Restrições |
|-------|------|-------------|-----------|
| `name` | string | sim | 1–256 caracteres |
| `description` | string | não | máx. 2048 caracteres |

**Response `201 Created`:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Projeto Alpha",
  "description": "Documentos do projeto Alpha",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

**Erros:** `400 VALIDATION_ERROR` · `401 UNAUTHORIZED`

---

### `GET /api/v1/notebooks/{notebookId}`

Retorna um notebook com suas sources embutidas. *(ação "abrir" na Tela 2, carrega a Tela 3)*

**Response `200 OK`:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Projeto Alpha",
  "description": "Documentos do projeto Alpha",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z",
  "sources": [
    {
      "id": "661f9511-f30c-42e5-b827-557766551111",
      "name": "contrato.pdf",
      "type": "FILE",
      "status": "READY",
      "createdAt": "2024-01-15T11:00:00Z"
    }
  ]
}
```

Notebook sem sources retorna `"sources": []`.

**Erros:** `404 NOTEBOOK_NOT_FOUND`

---

### `PATCH /api/v1/notebooks/{notebookId}`

Atualiza o notebook. **Apenas os campos presentes no corpo da requisição são modificados**; campos ausentes permanecem com o valor anterior. Enviar `{"description": "..."}` altera só a descrição e preserva o nome. *(Tela 3)*

Valem as mesmas restrições de tamanho da criação.

**Request body:**
```json
{
  "description": "Nova descrição"
}
```

**Response `200 OK`:** o notebook atualizado, no mesmo formato do `GET`, com `updatedAt` refletindo a modificação.

**Erros:** `400 VALIDATION_ERROR` · `404 NOTEBOOK_NOT_FOUND`

---

### `DELETE /api/v1/notebooks/{notebookId}`

Deleta o notebook e **todo o conteúdo derivado dele, em cascata**:

- as **sources** do notebook,
- os **chunks e embeddings** dessas sources no pgvector,
- as **conversas** do notebook,
- as **mensagens** dessas conversas,
- os **arquivos no S3** correspondentes às sources de origem "arquivo".

Nenhum desses dados permanece recuperável após a operação. *(Tela 2 / Tela 3)*

**Response `204 No Content`**

**Erros:** `404 NOTEBOOK_NOT_FOUND`

---

## Sources

Toda source pertence a exatamente um notebook e não pode ser movida ou reaproveitada em outro. O mesmo documento em dois notebooks exige dois envios, cada um com seu próprio processamento e status.

### Status de processamento

O processamento é assíncrono (padrão *async request-reply*): a criação responde imediatamente e o trabalho pesado — obtenção do conteúdo, extração de texto, chunking e geração de embeddings — ocorre em segundo plano.

```
PENDING ----> PROCESSING ----> READY
                    |
                    +--------> FAILED
```

| Status | Significado |
|--------|-------------|
| `PENDING` | Criada e enfileirada; o processamento ainda não começou |
| `PROCESSING` | Conteúdo sendo obtido, dividido em trechos e vetorizado |
| `READY` | Disponível para ser ativada como contexto de busca em uma conversa |
| `FAILED` | Processamento falhou; `errorMessage` traz o diagnóstico |

**Só sources em `READY` podem ser ativadas em uma conversa.**

---

### `POST /api/v1/notebooks/{notebookId}/sources`

Adiciona uma source ao notebook, por arquivo ou por URL. Responde `202 Accepted` imediatamente, com a source em `PENDING`. *(painel "sources" da Tela 3)*

**Opção A — Arquivo (`multipart/form-data`):**

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `file` | binary | sim | PDF, DOCX ou Markdown |
| `name` | string | não | Nome de exibição; padrão: o nome do arquivo enviado |

**Opção B — URL (`application/json`):**
```json
{
  "type": "URL",
  "url": "https://docs.example.com/api",
  "name": "Docs da API"
}
```

A obtenção do conteúdo da página acontece no processamento assíncrono, não nesta requisição.

**Response `202 Accepted`:**
```json
{
  "id": "661f9511-f30c-42e5-b827-557766551111",
  "name": "contrato.pdf",
  "type": "FILE",
  "status": "PENDING",
  "createdAt": "2024-01-15T11:00:00Z"
}
```

**Erros:** `400 VALIDATION_ERROR` (URL ausente ou malformada) · `404 NOTEBOOK_NOT_FOUND` · `415 UNSUPPORTED_FILE_TYPE` (formato fora de PDF/DOCX/Markdown)

---

### `GET /api/v1/notebooks/{notebookId}/sources`

Lista as sources do notebook com seus status. *(painel "sources" da Tela 3)*

**Response `200 OK`:**
```json
[
  {
    "id": "661f9511-f30c-42e5-b827-557766551111",
    "name": "contrato.pdf",
    "type": "FILE",
    "status": "READY",
    "errorMessage": null,
    "createdAt": "2024-01-15T11:00:00Z"
  },
  {
    "id": "772a0622-041d-43f6-c938-668877662222",
    "name": "https://docs.example.com/api",
    "type": "URL",
    "status": "PROCESSING",
    "errorMessage": null,
    "createdAt": "2024-01-15T11:05:00Z"
  }
]
```

O campo `type` indica a **origem** da source (`FILE` ou `URL`). O formato do arquivo (PDF, DOCX, Markdown) não é exposto na v1.

---

### `GET /api/v1/notebooks/{notebookId}/sources/{sourceId}`

Retorna uma source individual. **Este é o contrato de polling**: o frontend o consulta após o envio para acompanhar a transição de status até `READY` ou `FAILED`. *(painel "sources" da Tela 3)*

**Response `200 OK` — exemplo de falha:**
```json
{
  "id": "661f9511-f30c-42e5-b827-557766551111",
  "name": "contrato.pdf",
  "type": "FILE",
  "status": "FAILED",
  "errorMessage": "Arquivo corrompido: não foi possível extrair texto",
  "createdAt": "2024-01-15T11:00:00Z"
}
```

Enquanto o processamento não termina, `errorMessage` é `null`.

**Erros:** `404 SOURCE_NOT_FOUND`

---

### `DELETE /api/v1/notebooks/{notebookId}/sources/{sourceId}`

Deleta a source, **seus chunks e embeddings no pgvector** e, quando a origem é um arquivo, **o arquivo no S3**. *(painel "sources" da Tela 3)*

Se a source estiver ativa em alguma conversa, ela é removida dessa seleção — a conversa e seu histórico são preservados. Ver [Conversations](#conversations).

**Response `204 No Content`**

**Erros:** `404 SOURCE_NOT_FOUND`

---

## Conversations

Um notebook pode ter várias conversas independentes, cada uma com seu próprio histórico e sua própria seleção de sources ativas.

### Seleção de sources ativas

A seleção é **obrigatória e não pode ser vazia**. Não existe default implícito: uma lista omitida ou `[]` é erro de validação, e em nenhuma hipótese o sistema interpreta a ausência de seleção como "todas as sources do notebook".

Consequência: **um notebook sem nenhuma source em `READY` não permite criar conversa.** O frontend deve manter a ação de nova conversa desabilitada até que ao menos uma source fique pronta.

---

### `GET /api/v1/notebooks/{notebookId}/conversations`

Lista as conversas do notebook, ordenadas por data de criação decrescente. *(Tela 3)*

**Response `200 OK`:**
```json
[
  {
    "id": "883b1733-152e-44a7-9049-779988773333",
    "notebookId": "550e8400-e29b-41d4-a716-446655440000",
    "createdAt": "2024-01-15T12:00:00Z",
    "preview": "Qual o prazo de entrega mencionado no contrat..."
  }
]
```

O campo `preview` é **derivado** da primeira mensagem da conversa — não é um atributo persistido nem editável pelo usuário. Conversa criada que ainda não recebeu mensagens vem com `preview` nulo.

---

### `POST /api/v1/notebooks/{notebookId}/conversations`

Cria uma conversa no notebook. *(Tela 3)*

**Request body:**
```json
{
  "activeSourceIds": [
    "661f9511-f30c-42e5-b827-557766551111",
    "772a0622-041d-43f6-c938-668877662222"
  ]
}
```

| Campo | Tipo | Obrigatório | Restrições |
|-------|------|-------------|-----------|
| `activeSourceIds` | array de uuid | **sim** | mínimo 1 item; todas do notebook e em `READY` |

**Response `201 Created`:**
```json
{
  "id": "883b1733-152e-44a7-9049-779988773333",
  "notebookId": "550e8400-e29b-41d4-a716-446655440000",
  "activeSourceIds": [
    "661f9511-f30c-42e5-b827-557766551111",
    "772a0622-041d-43f6-c938-668877662222"
  ],
  "createdAt": "2024-01-15T12:00:00Z"
}
```

**Erros:**
- `400 VALIDATION_ERROR` — `activeSourceIds` omitido ou vazio
- `400 INVALID_SOURCE_IDS` — alguma source não pertence ao notebook
- `400 SOURCE_NOT_READY` — alguma source pertence ao notebook mas está em `PENDING`, `PROCESSING` ou `FAILED`
- `404 NOTEBOOK_NOT_FOUND`

Em qualquer erro, nenhuma conversa é criada e nenhuma source é ativada.

---

### `PATCH /api/v1/conversations/{conversationId}/active-sources`

Altera as sources ativas de uma conversa existente. Pode ser chamado a qualquer momento — a nova seleção vale para as mensagens seguintes e **não altera o histórico já produzido**. *(Tela 3)*

A operação é uma **substituição integral da lista**, não uma adição ou remoção incremental: o corpo enviado passa a ser a seleção completa da conversa.

**Request body:**
```json
{
  "activeSourceIds": [
    "661f9511-f30c-42e5-b827-557766551111",
    "772a0622-041d-43f6-c938-668877662222"
  ]
}
```

| Campo | Tipo | Obrigatório | Restrições |
|-------|------|-------------|-----------|
| `activeSourceIds` | array de uuid | **sim** | mínimo 1 item; todas do notebook da conversa e em `READY` |

**Response `200 OK`:**
```json
{
  "id": "883b1733-152e-44a7-9049-779988773333",
  "activeSourceIds": [
    "661f9511-f30c-42e5-b827-557766551111",
    "772a0622-041d-43f6-c938-668877662222"
  ]
}
```

**Erros:**
- `400 VALIDATION_ERROR` — lista vazia; a seleção **não pode ser esvaziada**, apenas trocada. A seleção anterior permanece em vigor.
- `400 INVALID_SOURCE_IDS` — alguma source não pertence ao notebook da conversa
- `400 SOURCE_NOT_READY` — alguma source não está em `READY`
- `404 CONVERSATION_NOT_FOUND`

---

### Conversa sem seleção válida

Quando a **última** source ativa de uma conversa é deletada, a conversa não é apagada nem bloqueada permanentemente:

```
  conversa   ativas: [contrato.pdf]
                     |
              source deletada
                     v
  conversa   ativas: [ ]        <- historico legivel
                                   POST de mensagem -> 409 NO_ACTIVE_SOURCES
                     |
       PATCH /active-sources com outra source READY
                     v
  conversa   ativas: [norma.pdf]   <- volta a aceitar mensagens
```

O histórico permanece recuperável em qualquer momento desse ciclo.

---

## Chat

### `GET /api/v1/conversations/{conversationId}/messages`

Retorna o histórico completo da conversa, em **ordem cronológica crescente** — a única coleção da API que não segue a ordenação decrescente padrão, porque a leitura do chat é do início para o fim. *(Tela 3)*

**Response `200 OK`:**
```json
[
  {
    "id": "994c2844-263f-45a8-8150-880099884444",
    "role": "user",
    "content": "Qual o prazo de entrega mencionado no contrato?",
    "createdAt": "2024-01-15T12:01:00Z"
  },
  {
    "id": "aa5d3955-374a-46b9-9261-991100995555",
    "role": "assistant",
    "content": "De acordo com a cláusula 5.2 do contrato, o prazo é de 30 dias úteis após a assinatura.",
    "createdAt": "2024-01-15T12:01:05Z"
  }
]
```

O campo `role` indica o autor: `user` ou `assistant`. Conversa recém-criada retorna `[]`.

O histórico é persistido por conversa, não pela sessão ou conexão do cliente — qualquer instância do backend atende a recuperação, inclusive após a queda da conexão de streaming.

**Erros:** `404 CONVERSATION_NOT_FOUND`

---

### `POST /api/v1/conversations/{conversationId}/messages`

Envia uma pergunta e recebe a resposta do assistente como **stream SSE**. A resposta é fundamentada exclusivamente nos trechos das sources ativas **daquela conversa**. *(Tela 3)*

**Request body:**
```json
{
  "content": "Qual o prazo de entrega mencionado no contrato?"
}
```

| Campo | Tipo | Obrigatório | Restrições |
|-------|------|-------------|-----------|
| `content` | string | sim | não vazio |

**Headers da response:**
```
Content-Type: text/event-stream
Cache-Control: no-cache
X-Accel-Buffering: no
```

**Response `200 OK` — formato SSE:**
```
data: {"token": "De "}

data: {"token": "acordo "}

data: {"token": "com "}

data: {"token": "a "}

data: {"token": "cláusula "}

data: {"token": "5.2 "}

data: {"done": true, "messageId": "aa5d3955-374a-46b9-9261-991100995555"}

```

Cada evento é uma linha `data: <json>\n\n`. O evento final `{"done": true}` carrega o `messageId` da mensagem do assistente já persistida.

#### Duas classes de erro

O tratamento depende de o stream já ter começado:

**Antes do início do stream** — erro HTTP convencional, com o envelope de erro padrão, e nenhum evento SSE é emitido:

| Situação | Resposta |
|----------|----------|
| `content` ausente ou vazio | `400 VALIDATION_ERROR` |
| Conversa inexistente ou de outro usuário | `404 CONVERSATION_NOT_FOUND` |
| Conversa sem seleção válida de sources | `409 NO_ACTIVE_SOURCES` |

No caso de `409 NO_ACTIVE_SOURCES`, a conversa perdeu sua última source ativa por deleção. Nenhuma mensagem é persistida e o histórico permanece intacto. A recuperação é ativar outra source em `READY` via `PATCH /api/v1/conversations/{conversationId}/active-sources` — o frontend deve oferecer essa ação em vez de exibir um erro genérico.

**Depois do início do stream** — o status HTTP `200` já foi enviado, então a falha é sinalizada como evento, antes do fechamento:

```
data: {"error": "STREAM_ERROR"}

```

O cliente distingue um encerramento com erro de uma conclusão bem-sucedida pela ausência do evento `{"done": true}`.

---

## Considerações Transversais

- Todos os contratos exigem o token emitido pelo Cognito. A aplicação não mantém estado de sessão em memória entre requisições: qualquer instância do backend atende qualquer requisição de um usuário autenticado.
- A resposta em streaming do chat é o único contrato de conexão de longa duração; os demais são requisição/resposta convencionais. O caminho de streaming através do API Gateway tem um risco arquitetural registrado e **ainda não resolvido** — ver [ARCHITECTURE.md](./ARCHITECTURE.md), seção "Streaming de chat (SSE) através do API Gateway".
- A busca semântica de uma pergunta é escopada às sources ativas da conversa em que ela foi feita. Trechos de sources não ativas, de outro notebook ou de outro usuário nunca participam da busca.
