# Arquitetura

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

**Status: aberto, sem mitigação decidida.** O contrato do chat em `API.md` inclui o header `X-Accel-Buffering: no` na resposta de streaming. Esse header instrui o *nginx* a não bufferizar e **não endereça este risco**: o buffering e o teto de timeout do API Gateway são independentes dele. Detalhar o contrato SSE não resolveu o problema arquitetural — a decisão continua pendente.

### Pipeline de ingestão assíncrono (async request-reply)

O processamento de um source (obtenção do conteúdo, chunking, geração de embeddings) segue o padrão *async request-reply*: a requisição de criação do source responde imediatamente com o source em status "recebido" (`PENDING`), e o processamento pesado ocorre em segundo plano através de uma fila (SQS) consumida por uma função assíncrona (Lambda). Isso vale tanto para sources de arquivo (PDF, Markdown, DOCX) quanto para sources de URL — nesse último caso, o processamento inclui uma etapa adicional de obtenção do conteúdo da página antes do chunking.

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

O `Source` expõe um status de processamento — recebido (`PENDING`) → processando (`PROCESSING`) → pronto (`READY`) / falhou (`FAILED`) — consultado pelo frontend até ficar disponível para seleção no chat.

### Seleção de sources no chat

A busca semântica (RAG) de cada pergunta é escopada às sources que o usuário selecionou como ativas na conversa em que a pergunta foi feita, dentre as sources com status "pronto" do notebook — não existe um contexto implícito de "todas as sources". Essa seleção é definida por conversa (não redefinida a cada pergunta) e pode ser alterada pelo usuário ao longo dela, valendo para as mensagens seguintes.

A seleção é **obrigatória e não pode ser vazia**: uma conversa nasce com pelo menos uma source ativa, e alterá-la substitui a lista sem nunca esvaziá-la. A ausência de default implícito é deliberada. Um default do tipo "todas as sources prontas" criaria uma segunda fonte de verdade para o escopo de busca — e a pior das duas, porque mudaria de significado sozinha: uma source que terminasse o processamento depois da criação da conversa entraria no escopo sem nenhuma ação do usuário, alterando silenciosamente o resultado de perguntas futuras. Com seleção explícita, o escopo é sempre uma lista materializada e persistida na conversa.

Decorre daí que um notebook sem nenhuma source em status "pronto" não permite criar conversas.

Quando uma source ativa é deletada, ela sai da seleção e a conversa é preservada com seu histórico. Se a seleção ficar vazia, a conversa passa a recusar novas mensagens até que outra source seja ativada. Esse estado é derivado da lista vazia, não um estado persistido a ser mantido em sincronia.

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
