# Domínio

## Visão Geral

Plataforma para agrupar fontes de conhecimento (*sources*) dentro de *notebooks* e conversar, via chat, com um assistente de IA fundamentado (RAG) nesse conteúdo — um NotebookLM simplificado.

## Entidades

### User

Usuário autenticado da aplicação, com identidade federada via AWS Cognito (login por Google ou GitHub) — não existe cadastro com senha própria. O identificador emitido pelo Cognito (`cognito_sub`) é a referência de identidade externa do usuário; distinguir qual provedor foi usado na federação é responsabilidade do Cognito, não do domínio da aplicação.

- identificador
- identificador do usuário no Cognito (`cognito_sub`)
- e-mail
- nome
- data de criação

### Notebook

Unidade lógica de agrupamento de *sources*. Pertence a exatamente um `User` (dono).

- identificador
- nome
- descrição (opcional)
- dono (`User`)
- data de criação
- data de atualização

### Source

Fonte de conhecimento dentro de um `Notebook`, originada de um arquivo enviado (armazenado em um bucket S3) ou de uma URL da web (conteúdo obtido por busca). Em ambos os casos, passa pelo mesmo pipeline assíncrono de processamento (obtenção do conteúdo, divisão em trechos, geração de embeddings) antes de poder ser usada pelo chat.

- identificador
- notebook ao qual pertence
- nome (de exibição, definido pelo usuário ou derivado do arquivo/URL)
- origem (arquivo enviado ou URL da web)
- formato (PDF, Markdown, DOCX ou página web)
- referência de armazenamento: chave do arquivo no S3 (quando a origem é um arquivo) ou a URL de origem (quando a origem é uma URL da web)
- status de processamento (recebido → processando → pronto → falhou)
- mensagem de erro (preenchida quando o status é "falhou")
- data de envio

### SourceChunk (embedding)

Trecho de texto extraído de um `Source`, junto com sua representação vetorial, persistido com pgvector. É a unidade usada na busca semântica (*retrieval*) que alimenta o chat.

- identificador
- source ao qual pertence
- texto do trecho
- posição do trecho dentro do source
- vetor de embedding
- modelo de embedding utilizado para gerar o vetor
- data de criação

### Conversation

Sessão de chat dentro de um `Notebook`. Um notebook pode ter múltiplas conversas independentes, cada uma com seu próprio histórico de mensagens e sua própria seleção de sources ativas.

- identificador
- notebook ao qual pertence
- data de criação

### ConversationMessage

Mensagem trocada dentro de uma `Conversation` — tanto a pergunta do usuário quanto a resposta gerada. Persistida por conversa, e não pela sessão/conexão do usuário, porque a aplicação é stateless e qualquer instância precisa poder atender uma reconexão.

- identificador
- conversa à qual pertence
- autor (usuário ou assistente)
- conteúdo
- data/hora

## Relacionamentos

```
User (1) ----- (N) Notebook
Notebook (1) ----- (N) Source
Notebook (1) ----- (N) Conversation
Source (1) ----- (N) SourceChunk
Conversation (1) ----- (N) ConversationMessage
Conversation (N) ----- (N) Source   [sources ativas na conversa]
```

## Modelo de Relacionamentos (ERD)

Visão de schema (tabelas, chaves e colunas), complementar à visão conceitual acima — referência para quando a implementação de persistência começar.

```
┌──────────────┐  1    N  ┌──────────────────┐  1    N  ┌──────────────────────────┐
│    users     │──────────│    notebooks     │──────────│         sources          │
├──────────────┤          ├──────────────────┤          ├──────────────────────────┤
│ id (PK)      │          │ id (PK)          │          │ id (PK)                  │
│ cognito_sub  │          │ owner_id (FK)    │          │ notebook_id (FK)         │
│ email        │          │ name             │          │ name                     │
│ name         │          │ description      │          │ type                     │
│ created_at   │          │ created_at       │          │ s3_key                   │
└──────────────┘          │ updated_at       │          │ url                      │
                          └──────────────────┘          │ status                   │
                                    │                    │ error_message            │
                                    │ 1                  │ created_at               │
                                    │                    └──────────────────────────┘
                                    │                               │ 1
                                    │                               │ N
                                    │                    ┌──────────────────────────┐
                                    │                    │      source_chunks       │
                                    │                    ├──────────────────────────┤
                                    │                    │ id (PK)                  │
                                    │                    │ source_id (FK)           │
                                    │                    │ content                  │
                                    │                    │ embedding vector(1536)   │
                                    │                    │ chunk_index              │
                                    │                    │ embedding_model          │
                                    │                    │ created_at               │
                                    │                    └──────────────────────────┘
                                    │ 1
                                    │ N
                          ┌──────────────────┐
                          │  conversations   │
                          ├──────────────────┤
                          │ id (PK)          │
                          │ notebook_id (FK) │
                          │ created_at       │
                          └──────────────────┘
                                    │
                    ┌───────────────┴────────────────┐
                    │ N                               │ 1
                    │                                 │ N
       ┌──────────────────────────┐    ┌──────────────────────────────┐
       │   conv_active_sources    │    │    conversation_messages     │
       ├──────────────────────────┤    ├──────────────────────────────┤
       │ conversation_id (FK)     │    │ id (PK)                      │
       │ source_id (FK)           │    │ conversation_id (FK)         │
       │ PK (conversation_id,     │    │ role (user|assistant)        │
       │      source_id)          │    │ content                      │
       └──────────────────────────┘    │ created_at                   │
                                        └──────────────────────────────┘

  conv_active_sources é a tabela associativa (M:N) entre conversations e sources.
```

## Regras de Negócio

1. Um `Notebook` pertence a um único dono; apenas o dono pode visualizar, gerenciar e conversar sobre ele. Não há compartilhamento entre usuários nesta fase do produto.
2. Um `Source` só existe no contexto de um `Notebook` e não pode ser movido ou reaproveitado em outro notebook.
3. Uma source pode se originar de um arquivo enviado (PDF, Markdown ou DOCX) ou de uma URL da web; a origem determina como o conteúdo bruto é obtido, mas ambas seguem o mesmo pipeline de processamento antes de ficarem disponíveis para ativação em uma conversa.
4. O processamento de um `Source` (obtenção do conteúdo, chunking, geração de embeddings) é assíncrono: a criação do source é confirmada antes do processamento terminar, e o `Source` expõe um status até ficar pronto para uso; quando o processamento falha, uma mensagem de erro é registrada para diagnóstico.
5. Um `Notebook` pode ter múltiplas `Conversation`s independentes; cada uma mantém seu próprio histórico de `ConversationMessage` e sua própria seleção de sources ativas.
6. O usuário seleciona, para cada `Conversation`, quais sources (dentre as que estão com status "pronto") ficam ativas como contexto de busca; a seleção vale para a conversa como um todo — não é redefinida a cada mensagem — e pode ser alterada pelo usuário ao longo da conversa. Sources fora do status "pronto" não podem ser ativadas.
7. O chat de uma `Conversation` só pode ser fundamentado (RAG) em `SourceChunk`s das sources ativas naquela conversa — nunca em sources de outro notebook.
8. O histórico de `ConversationMessage` é persistido por `Conversation`, não pela sessão/conexão do usuário.
