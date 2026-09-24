# Spec Delta

## Purpose

Troca de mensagens dentro de uma conversa: a pergunta do usuário, a resposta do assistente fundamentada nas sources ativas e entregue incrementalmente por streaming, e o histórico persistido que permite reabrir a conversa.

## ADDED Requirements

### Requirement: Resposta fundamentada nas sources ativas da conversa

O sistema SHALL escopar a busca semântica de cada pergunta aos trechos das sources ativas da conversa em que a pergunta foi feita. Trechos de sources não ativas, de sources de outro notebook ou de notebooks de outro usuário MUST NOT participar da busca.

#### Scenario: Pergunta respondida com as sources ativas

- **WHEN** um usuário autenticado envia uma pergunta em uma conversa com sources ativas
- **THEN** a resposta é gerada a partir dos trechos recuperados apenas dessas sources

#### Scenario: Informação presente apenas em source não ativa

- **WHEN** um usuário autenticado pergunta sobre um conteúdo que existe apenas em uma source do notebook que não está ativa na conversa
- **THEN** esse conteúdo não é recuperado na busca
- **AND** a resposta não se fundamenta nele

#### Scenario: Conversa sem seleção válida

- **WHEN** um usuário autenticado tenta enviar uma mensagem em uma conversa cuja seleção de sources ativas ficou vazia
- **THEN** a resposta é `409` com `error` igual a `NO_ACTIVE_SOURCES`
- **AND** nenhuma mensagem é persistida
- **AND** o histórico existente permanece inalterado

### Requirement: Resposta entregue por streaming incremental

O sistema SHALL entregar a resposta do assistente como um fluxo de eventos, permitindo que o cliente exiba o texto conforme ele é gerado. O fluxo MUST terminar com um evento final que identifica a mensagem persistida. Erros ocorridos após o início do fluxo MUST ser sinalizados como um evento de erro, não como código de status HTTP.

#### Scenario: Resposta completa

- **WHEN** um usuário autenticado envia uma pergunta válida em uma conversa utilizável
- **THEN** a resposta é um fluxo de eventos com os trechos de texto da resposta em ordem
- **AND** o fluxo termina com um evento final de conclusão contendo o identificador da mensagem do assistente

#### Scenario: Falha durante a geração

- **WHEN** a geração da resposta falha depois que o fluxo já começou a ser enviado
- **THEN** um evento de erro é enviado ao cliente antes do fechamento do fluxo
- **AND** o cliente consegue distinguir esse encerramento de uma conclusão bem-sucedida

#### Scenario: Erro antes do início do fluxo

- **WHEN** a requisição é inválida ou a conversa não existe
- **THEN** a resposta é um erro HTTP convencional, com o envelope de erro padrão
- **AND** nenhum fluxo de eventos é iniciado

### Requirement: Validação da mensagem enviada

O sistema SHALL recusar o envio de mensagem sem conteúdo. Uma conversa inexistente, ou pertencente a outro usuário, MUST resultar em `404 CONVERSATION_NOT_FOUND`.

#### Scenario: Mensagem sem conteúdo

- **WHEN** um usuário autenticado envia uma mensagem sem conteúdo, ou com conteúdo vazio
- **THEN** a resposta é `400` com `error` igual a `VALIDATION_ERROR`
- **AND** nenhuma mensagem é persistida

#### Scenario: Conversa inexistente

- **WHEN** um usuário autenticado envia uma mensagem para uma conversa que não existe ou pertence a outro usuário
- **THEN** a resposta é `404` com `error` igual a `CONVERSATION_NOT_FOUND`

### Requirement: Histórico persistido por conversa

O sistema SHALL persistir tanto a pergunta do usuário quanto a resposta do assistente vinculadas à conversa, e não à sessão ou conexão do cliente. O histórico MUST permanecer recuperável em ordem cronológica após o encerramento do fluxo de streaming, inclusive em uma instância diferente da que atendeu o envio.

#### Scenario: Reabertura da conversa

- **WHEN** um usuário autenticado recupera o histórico de uma conversa que já teve mensagens
- **THEN** a resposta é `200` com as mensagens em ordem cronológica crescente
- **AND** cada mensagem indica se seu autor é o usuário ou o assistente

#### Scenario: Persistência independente da conexão

- **WHEN** o cliente perde a conexão de streaming depois que a resposta foi concluída e persistida
- **THEN** a resposta do assistente consta no histórico ao recuperá-lo novamente
- **AND** a recuperação funciona independentemente de qual instância do backend a atende

#### Scenario: Conversa ainda sem mensagens

- **WHEN** um usuário autenticado recupera o histórico de uma conversa recém-criada
- **THEN** a resposta é `200` com um array vazio
