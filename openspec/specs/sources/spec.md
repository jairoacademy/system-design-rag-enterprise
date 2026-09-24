# Sources

## Purpose

Ingestão de fontes de conhecimento em um notebook, a partir de arquivo enviado ou de URL da web, e o acompanhamento do processamento assíncrono que as torna utilizáveis pelo chat.

## Requirements

### Requirement: Adicionar source por arquivo

O sistema SHALL aceitar o envio de um arquivo PDF, DOCX ou Markdown como source de um notebook. Formatos fora dessa lista MUST ser recusados. O nome de exibição é opcional; quando ausente, o nome do arquivo enviado MUST ser usado.

#### Scenario: Envio de arquivo em formato suportado

- **WHEN** um usuário autenticado envia um arquivo PDF para um notebook seu
- **THEN** a resposta é `202` com a source criada em status `PENDING`
- **AND** a resposta inclui o identificador da source, para consulta posterior de status

#### Scenario: Envio de arquivo em formato não suportado

- **WHEN** um usuário autenticado envia um arquivo de formato fora da lista suportada
- **THEN** a resposta é `415` com `error` igual a `UNSUPPORTED_FILE_TYPE`
- **AND** nenhuma source é criada

#### Scenario: Nome de exibição omitido

- **WHEN** um usuário autenticado envia um arquivo sem informar nome de exibição
- **THEN** a source é criada com o nome do arquivo enviado como nome de exibição

### Requirement: Adicionar source por URL

O sistema SHALL aceitar uma URL da web como source de um notebook. A obtenção do conteúdo da página MUST acontecer no processamento assíncrono, não na requisição de criação.

#### Scenario: Criação de source por URL

- **WHEN** um usuário autenticado informa uma URL para um notebook seu
- **THEN** a resposta é `202` com a source criada em status `PENDING`
- **AND** a resposta retorna sem aguardar a obtenção do conteúdo da página

#### Scenario: URL ausente ou malformada

- **WHEN** um usuário autenticado tenta criar uma source por URL sem informar a URL, ou informando uma URL malformada
- **THEN** a resposta é `400` com `error` igual a `VALIDATION_ERROR`
- **AND** nenhuma source é criada

### Requirement: Processamento assíncrono com status observável

O sistema SHALL processar cada source de forma assíncrona e expor seu progresso através de um status com os valores `PENDING`, `PROCESSING`, `READY` e `FAILED`. A resposta de criação MUST retornar antes do processamento terminar. Uma source MUST atingir o status `READY` antes de poder ser usada como contexto de busca.

#### Scenario: Progressão até pronto

- **WHEN** o processamento de uma source recém-criada é executado com sucesso
- **THEN** o status da source progride de `PENDING` para `PROCESSING` e então para `READY`
- **AND** os trechos e embeddings da source passam a existir

#### Scenario: Falha no processamento

- **WHEN** o processamento de uma source falha, por exemplo por não ser possível extrair texto do arquivo
- **THEN** o status da source passa a `FAILED`
- **AND** uma mensagem de erro legível fica disponível na consulta da source

#### Scenario: Consulta de status durante o processamento

- **WHEN** um usuário autenticado consulta uma source cujo processamento ainda não terminou
- **THEN** a resposta é `200` com o status atual da source
- **AND** a mensagem de erro está ausente

### Requirement: Listar e consultar sources de um notebook

O sistema SHALL permitir listar as sources de um notebook e consultar uma source individualmente, em ambos os casos incluindo o status de processamento e, quando houver, a mensagem de erro. A listagem MUST ser ordenada por data de criação decrescente e MUST ser sempre um array.

#### Scenario: Listagem de notebook sem sources

- **WHEN** um usuário autenticado lista as sources de um notebook seu que ainda não tem sources
- **THEN** a resposta é `200` com um array vazio

#### Scenario: Consulta de source de outro notebook

- **WHEN** um usuário autenticado consulta uma source informando um notebook ao qual ela não pertence
- **THEN** a resposta é `404` com `error` igual a `SOURCE_NOT_FOUND`

### Requirement: Deletar source com limpeza de dados derivados

O sistema SHALL deletar, junto com a source, seus chunks e embeddings e, quando a origem for um arquivo, o arquivo correspondente no armazenamento de objetos.

#### Scenario: Deleção de source de arquivo

- **WHEN** um usuário autenticado deleta uma source de arquivo de um notebook seu
- **THEN** a resposta é `204` sem corpo
- **AND** os chunks e embeddings dessa source deixam de existir
- **AND** o arquivo é removido do armazenamento de objetos

#### Scenario: Deleção de source inexistente

- **WHEN** um usuário autenticado tenta deletar uma source que não existe ou pertence a outro notebook ou usuário
- **THEN** a resposta é `404` com `error` igual a `SOURCE_NOT_FOUND`

### Requirement: Source pertence a um único notebook

Uma source SHALL existir apenas no contexto do notebook em que foi criada e MUST NOT ser movida ou reaproveitada em outro notebook.

#### Scenario: Ausência de contrato de movimentação

- **WHEN** um usuário deseja usar o mesmo documento em dois notebooks
- **THEN** o documento precisa ser adicionado separadamente em cada notebook
- **AND** cada notebook possui sua própria source, com seu próprio processamento e status
