# Notebooks

## Purpose

Ciclo de vida do notebook — a unidade de agrupamento de fontes de conhecimento pertencente a um único usuário — desde a criação até a deleção em cascata de todo o conteúdo derivado.

## Requirements

### Requirement: Isolamento por dono

Todo notebook SHALL pertencer a exatamente um usuário, identificado pelo token da requisição. Um notebook de outro usuário MUST ser indistinguível de um notebook inexistente: ambos resultam em `404 NOTEBOOK_NOT_FOUND`, nunca em `403`, para não revelar a existência do recurso.

#### Scenario: Acesso a notebook de outro usuário

- **WHEN** um usuário autenticado requisita um notebook que pertence a outro usuário
- **THEN** a resposta é `404` com `error` igual a `NOTEBOOK_NOT_FOUND`
- **AND** nenhum dado do notebook é exposto na resposta

#### Scenario: Listagem escopada ao dono

- **WHEN** um usuário autenticado lista seus notebooks
- **THEN** a resposta contém apenas notebooks cujo dono é esse usuário

### Requirement: Provisionamento do usuário na primeira requisição

O sistema SHALL criar o registro do usuário a partir do `cognito_sub` presente no token na primeira requisição autenticada em que esse identificador ainda não for conhecido. Não existe contrato de cadastro, login ou logout exposto pelo backend.

#### Scenario: Primeira requisição de um usuário novo

- **WHEN** chega uma requisição autenticada cujo `cognito_sub` não corresponde a nenhum usuário registrado
- **THEN** um usuário é registrado com esse `cognito_sub`, e o e-mail e nome presentes no token
- **AND** a requisição original é atendida normalmente, sem etapa adicional para o cliente

#### Scenario: Requisição sem token válido

- **WHEN** chega uma requisição a um endpoint protegido sem token, ou com token expirado ou inválido
- **THEN** a resposta é `401` com `error` igual a `UNAUTHORIZED`

### Requirement: Criar notebook

O sistema SHALL permitir criar um notebook com nome obrigatório e descrição opcional. O nome MUST ter entre 1 e 256 caracteres; a descrição, quando presente, MUST ter no máximo 2048 caracteres.

#### Scenario: Criação com nome válido

- **WHEN** um usuário autenticado cria um notebook informando um nome válido
- **THEN** a resposta é `201` com o notebook criado, incluindo identificador, nome, descrição, data de criação e data de atualização
- **AND** o notebook passa a pertencer ao usuário autenticado

#### Scenario: Criação sem nome

- **WHEN** um usuário autenticado tenta criar um notebook sem informar o nome, ou com nome vazio
- **THEN** a resposta é `400` com `error` igual a `VALIDATION_ERROR`
- **AND** nenhum notebook é criado

#### Scenario: Criação com nome acima do limite

- **WHEN** um usuário autenticado tenta criar um notebook com nome acima de 256 caracteres
- **THEN** a resposta é `400` com `error` igual a `VALIDATION_ERROR`

### Requirement: Listar notebooks

O sistema SHALL retornar os notebooks do usuário autenticado ordenados por data de criação decrescente. A resposta MUST ser sempre um array, nunca nulo.

#### Scenario: Usuário sem nenhum notebook

- **WHEN** um usuário autenticado sem notebooks lista seus notebooks
- **THEN** a resposta é `200` com um array vazio

#### Scenario: Ordenação da listagem

- **WHEN** um usuário autenticado com vários notebooks lista seus notebooks
- **THEN** os notebooks aparecem do mais recente para o mais antigo por data de criação

### Requirement: Detalhar notebook com suas sources

O sistema SHALL retornar, no detalhe de um notebook, os dados do notebook e a lista de suas sources com o status de processamento de cada uma.

#### Scenario: Detalhe de notebook com sources

- **WHEN** um usuário autenticado requisita o detalhe de um notebook seu que possui sources
- **THEN** a resposta é `200` com os dados do notebook e um array de sources, cada uma com identificador, nome, origem e status

#### Scenario: Detalhe de notebook sem sources

- **WHEN** um usuário autenticado requisita o detalhe de um notebook seu que ainda não tem sources
- **THEN** a resposta é `200` com a lista de sources como array vazio

### Requirement: Atualizar notebook

O sistema SHALL permitir atualizar o nome e a descrição de um notebook. Apenas os campos presentes na requisição MUST ser modificados; campos ausentes permanecem inalterados. As mesmas restrições de tamanho da criação se aplicam.

#### Scenario: Atualização parcial

- **WHEN** um usuário autenticado atualiza apenas a descrição de um notebook seu
- **THEN** a resposta é `200` com o notebook atualizado
- **AND** o nome permanece com o valor anterior
- **AND** a data de atualização passa a refletir a modificação

#### Scenario: Atualização com nome inválido

- **WHEN** um usuário autenticado tenta atualizar um notebook informando nome vazio
- **THEN** a resposta é `400` com `error` igual a `VALIDATION_ERROR`
- **AND** o notebook permanece inalterado

### Requirement: Deletar notebook em cascata

O sistema SHALL deletar, junto com o notebook, todo o conteúdo derivado dele: suas sources, os chunks e embeddings dessas sources, suas conversas, as mensagens dessas conversas e os arquivos correspondentes no armazenamento de objetos. Após a deleção, nenhum desses dados MUST permanecer recuperável.

#### Scenario: Deleção de notebook com conteúdo

- **WHEN** um usuário autenticado deleta um notebook seu que possui sources, chunks, conversas e mensagens
- **THEN** a resposta é `204` sem corpo
- **AND** as sources, chunks, conversas e mensagens do notebook deixam de existir
- **AND** os arquivos das sources são removidos do armazenamento de objetos

#### Scenario: Deleção de notebook inexistente

- **WHEN** um usuário autenticado tenta deletar um notebook que não existe ou pertence a outro usuário
- **THEN** a resposta é `404` com `error` igual a `NOTEBOOK_NOT_FOUND`
