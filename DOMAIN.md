# Domínio

## Visão Geral

Plataforma para agrupar fontes de conhecimento (*sources*) dentro de *notebooks* e conversar, via chat, com um assistente de IA fundamentado (RAG) nesse conteúdo — um NotebookLM simplificado.

## Entidades

### User

Usuário autenticado da aplicação. A identidade é sempre federada por um provedor externo (Google ou GitHub) — não existe cadastro com senha própria.

- identificador
- e-mail
- nome
- provedor de origem (Google / GitHub)

### Notebook

Unidade lógica de agrupamento de *sources*. Pertence a exatamente um `User` (dono).

- identificador
- título
- dono (`User`)
- data de criação

### Source

Fonte de conhecimento dentro de um `Notebook`, originada de um arquivo enviado (armazenado em um bucket S3) ou de uma URL da web (conteúdo obtido por busca). Em ambos os casos, passa pelo mesmo pipeline assíncrono de processamento (obtenção do conteúdo, divisão em trechos, geração de embeddings) antes de poder ser usada pelo chat.

- identificador
- notebook ao qual pertence
- origem (arquivo enviado ou URL da web)
- formato (PDF, Markdown, DOCX ou página web)
- nome do arquivo ou URL de origem
- status de processamento (recebido → processando → pronto → falhou)
- data de envio

### SourceChunk (embedding)

Trecho de texto extraído de um `Source`, junto com sua representação vetorial, persistido com pgvector. É a unidade usada na busca semântica (*retrieval*) que alimenta o chat.

- identificador
- source ao qual pertence
- texto do trecho
- vetor de embedding

### ChatMessage

Mensagem trocada dentro do chat de um `Notebook` — tanto a pergunta do usuário quanto a resposta gerada. Persistida por notebook, e não pela sessão/conexão do usuário, porque a aplicação é stateless e qualquer instância precisa poder atender uma reconexão.

- identificador
- notebook ao qual pertence
- autor (usuário ou assistente)
- conteúdo
- sources selecionadas como contexto (definidas pelo usuário; aplicável às perguntas)
- data/hora

## Relacionamentos

```
User (1) ----- (N) Notebook
Notebook (1) ----- (N) Source
Notebook (1) ----- (N) ChatMessage
Source (1) ----- (N) SourceChunk
ChatMessage (N) ----- (N) Source   [sources selecionadas como contexto]
```

## Regras de Negócio

1. Um `Notebook` pertence a um único dono; apenas o dono pode visualizar, gerenciar e conversar sobre ele. Não há compartilhamento entre usuários nesta fase do produto.
2. Um `Source` só existe no contexto de um `Notebook` e não pode ser movido ou reaproveitado em outro notebook.
3. O processamento de um `Source` (extração, chunking, embedding) é assíncrono: o upload é confirmado antes do processamento terminar, e o `Source` expõe um status até ficar pronto para uso.
4. O chat de um `Notebook` só pode ser fundamentado (RAG) em `SourceChunk`s de `Source`s com status "pronto" pertencentes àquele mesmo notebook — nunca em sources de outro notebook.
5. O usuário seleciona, a cada pergunta, quais sources (dentre as que estão com status "pronto") devem ser ativadas como contexto de busca; a seleção é registrada junto à `ChatMessage` correspondente. Sources fora do status "pronto" não podem ser selecionadas.
6. O histórico de `ChatMessage` de um notebook é persistido e associado ao notebook, não à sessão/conexão do usuário.
7. Uma source pode se originar de um arquivo enviado (PDF, Markdown ou DOCX) ou de uma URL da web; a origem determina como o conteúdo bruto é obtido, mas ambas seguem o mesmo pipeline de processamento antes de ficarem disponíveis para seleção no chat.
