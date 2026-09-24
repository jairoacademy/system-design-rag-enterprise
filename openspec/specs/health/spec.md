# Health

## Purpose

Verificação de saúde da instância de aplicação, consumida pelo Load Balancer para decidir se a
instância entra ou sai da rotação de tráfego, sem depender do fluxo de autenticação do produto.

## Requirements

### Requirement: Endpoint de health acessível sem autenticação

O sistema SHALL expor um endpoint de verificação de saúde acessível sem o header `Authorization`.
O Load Balancer não possui identidade no Cognito e não pode apresentar um token; exigir
autenticação nesse caminho faria toda instância saudável ser marcada como indisponível.

Esse endpoint é a única exceção à regra de autenticação obrigatória descrita em `API.md`, e MUST
ficar fora do prefixo `/api/v1` para não ser confundido com contrato de produto consumido pelo
frontend.

#### Scenario: Requisição de health sem token

- **WHEN** chega uma requisição ao endpoint de health sem header `Authorization`
- **THEN** a resposta é `200` com o estado de saúde da instância
- **AND** a resposta não é `401`

#### Scenario: Endpoint de health fora do contrato de produto

- **WHEN** o frontend lista os endpoints sob `/api/v1`
- **THEN** o endpoint de health não está entre eles

### Requirement: Estado da instância reflete a conexão com o banco

O resultado do health SHALL refletir a capacidade da instância de atender requisições, incluindo o
estado da conexão com o PostgreSQL. Uma instância que subiu mas não alcança o banco não consegue
atender nenhuma operação do produto — todas dependem de persistência — e MUST ser reportada como
indisponível para que o Load Balancer a retire da rotação.

O resultado MUST NOT expor detalhes de infraestrutura — host, porta, credenciais, versão ou
mensagem de erro do banco — a um chamador não autenticado.

#### Scenario: Instância sem acesso ao banco

- **WHEN** a instância não consegue estabelecer conexão com o PostgreSQL
- **AND** chega uma requisição ao endpoint de health
- **THEN** a resposta indica estado não saudável com status HTTP diferente de `200`

#### Scenario: Instância saudável

- **WHEN** a instância alcança o PostgreSQL normalmente
- **AND** chega uma requisição ao endpoint de health
- **THEN** a resposta é `200` indicando estado saudável

#### Scenario: Ausência de detalhes de infraestrutura na resposta

- **WHEN** um chamador não autenticado requisita o endpoint de health
- **THEN** a resposta não contém host, porta, usuário, senha, versão do banco nem mensagem de erro
  originada da conexão
