/ops# Arquitetura

## Visão Geral

Visão de alto nível dos serviços envolvidos e de como eles se relacionam. Este documento cobre topologia de componentes e decisões arquiteturais — não detalhes de implementação.

## Diagrama de Componentes

```
                    +------------------+
                    |   Frontend SPA   |
                    +------------------+
                             |
                             v
                    +------------------+
                    |  AWS API Gateway |
                    +------------------+
                             |
                             v
                    +------------------+
                    |  Load Balancer   |
                    +------------------+
                             |
        +--------------------+--------------------+
        v                    v                     v
 +--------------+     +--------------+      +--------------+
 | App instance |     | App instance |      | App instance |
 |  (stateless) |     |  (stateless) |      |  (stateless) |
 +--------------+     +--------------+      +--------------+
        |                    |                     |
  +-----+------+-------------+-------------+-------+--------+
  |                    |                    |                |
  v                    v                    v                v
+---------+     +----------------+   +------------------+  +---------------+
| Cognito |     |  S3 (sources)  |   | PostgreSQL +     |  | Provedor LLM  |
| (auth)  |     |                |   | pgvector         |  | Bedrock /     |
+---------+     +----------------+   +------------------+  | OpenRouter    |
                                                             | (contrato     |
                                                             | OpenAI-compat)|
                                                             +---------------+
```

## Componentes

### Frontend

Aplicação single-page que consome a API via HTTPS e mantém uma conexão de streaming (SSE) aberta durante o uso do chat.

### AWS API Gateway

Ponto único de exposição pública da aplicação. Concentra a entrada de tráfego e políticas de borda, repassando as requisições ao Load Balancer.

### Load Balancer

Distribui as requisições entre as instâncias da camada de aplicação, permitindo escalar horizontalmente sem afinidade de sessão — consequência direta do requisito de aplicação stateless.

### Camada de Aplicação (stateless)

Camada de backend responsável por orquestrar autenticação, gestão de notebooks/sources, o pipeline de ingestão de conteúdo e a interação com o provedor de LLM. Nenhuma instância guarda estado de sessão ou de conversa em memória — tudo que precisa sobreviver entre requisições (perfil, notebooks, sources, histórico de chat, embeddings) é persistido externamente. Isso permite que qualquer instância atenda qualquer requisição, inclusive uma reconexão de streaming.

### Cognito

Provedor de identidade responsável pelo login federado com Google e GitHub, e pela emissão/validação dos tokens usados para identificar o usuário em cada requisição.

### S3 (armazenamento de sources)

Armazena os arquivos originais enviados como sources dos notebooks.

### PostgreSQL + pgvector

Armazena os dados relacionais da aplicação (usuários, notebooks, sources, mensagens de chat) e os embeddings vetoriais usados na busca semântica (RAG) — no mesmo banco.

### Provedor de LLM (AWS Bedrock / OpenRouter)

A aplicação interage diretamente com um provedor de LLM compatível com o contrato de API da OpenAI, permitindo alternar entre AWS Bedrock e OpenRouter sem mudar a forma como a aplicação consome o modelo.

## Decisões e Riscos Arquiteturais

### Streaming de chat (SSE) através do API Gateway

O AWS API Gateway (REST ou HTTP API) faz *buffering* de resposta e tem um teto de timeout de integração de aproximadamente 29-30 segundos — incompatível com uma conexão SSE de longa duração como a do chat. O Load Balancer, por outro lado, suporta conexões de longa duração nativamente.

**Risco registrado**: o caminho de streaming do chat precisa de tratamento diferenciado dos demais endpoints — seja evitando o *buffering* do API Gateway nesse caminho específico, seja desenhando a resposta do chat para respeitar o teto de tempo imposto pelo gateway (ex.: eventos de *keep-alive*, respostas particionadas). Decisão a ser detalhada quando o desenho técnico avançar.

### Pipeline de ingestão assíncrono (async request-reply)

O processamento de um source (obtenção do conteúdo, chunking, geração de embeddings) segue o padrão *async request-reply*: a requisição de criação do source responde imediatamente com o source em status "processando", e o processamento pesado ocorre em segundo plano através de uma fila (SQS) consumida por uma função assíncrona (Lambda). Isso vale tanto para sources de arquivo (PDF, Markdown, DOCX) quanto para sources de URL — nesse último caso, o processamento inclui uma etapa adicional de obtenção do conteúdo da página antes do chunking.

```
Criação de Source
       |
       v
+--------------+      +-----+      +-----------+      +-------------------+
| App instance | ---> | SQS | ---> |  Lambda   | ---> | PostgreSQL +      |
| (stateless)  |      |     |      | (fetch /  |      | pgvector          |
+--------------+      +-----+      |  extract/ |      | (chunks + status) |
                                    |  chunk /  |      +-------------------+
                                    |  embed)   |
                                    +-----------+
```

O `Source` expõe um status de processamento (`recebido` → `processando` → `pronto`/`falhou`), consultado pelo frontend até ficar disponível para seleção no chat.

### Seleção de sources no chat

A busca semântica (RAG) de cada pergunta é escopada apenas às sources que o usuário selecionou explicitamente naquela interação, dentre as sources com status "pronto" do notebook — não existe um contexto implícito de "todas as sources".

### Abstração de provedor de LLM

Como a aplicação precisa suportar tanto AWS Bedrock quanto OpenRouter através de um contrato compatível com a API da OpenAI, o provedor efetivo é uma configuração da camada de aplicação, não uma escolha exposta ao usuário final nesta fase.

### Stateless por design

Nenhum dado de sessão, de conversa ou de processamento fica retido na memória de uma instância específica. Esse requisito é o que possibilita escalar a camada de aplicação horizontalmente atrás do Load Balancer sem necessidade de afinidade de sessão (*sticky sessions*).

## Stack Tecnológico (alto nível)

- **Cloud**: AWS
- **Orquestração de IA**: Spring AI
- **Persistência relacional e vetorial**: PostgreSQL + pgvector
- **Processamento assíncrono de ingestão**: Amazon SQS + AWS Lambda (padrão async request-reply)
- **Processo de especificação**: OpenSpec (SDD) para mudanças incrementais a partir desta fundação
