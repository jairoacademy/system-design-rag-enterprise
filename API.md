# API

## Visão Geral

Contratos funcionais expostos pelo backend ao frontend, organizados por área de capacidade. Este documento descreve funcionalidades e contratos em alto nível — sem detalhes de implementação.

## Autenticação

- **Login federado**: início do fluxo de autenticação via provedor externo (Google ou GitHub), mediado pelo Cognito. O frontend redireciona o usuário para o fluxo de login do provedor escolhido (Tela 1).
- **Retorno de sessão**: após autenticação bem-sucedida, a aplicação recebe um token que identifica o usuário nas requisições seguintes. Nenhuma sessão é guardada em memória do servidor (aplicação stateless).
- **Perfil do usuário logado**: recuperação dos dados básicos do usuário autenticado (nome, e-mail, avatar) — usado, por exemplo, no ícone de "perfil" presente nas Telas 2 e 3.
- **Logout**: encerramento da sessão do lado do cliente.

## Notebooks

- **Criar notebook**: cria um novo `Notebook` para o usuário autenticado (ação "Criar" na Tela 2).
- **Listar notebooks**: retorna os notebooks pertencentes ao usuário autenticado (lista de `Notebook1`, `Notebook2`, ... na Tela 2).
- **Abrir/detalhar notebook**: retorna os dados de um notebook específico (ação "abrir"), usado para carregar a Tela 3 (sources + chat).

## Sources

- **Upload de source (arquivo)**: registra o envio de um arquivo (PDF, Markdown ou DOCX) para dentro de um notebook, com o conteúdo original armazenado em um bucket S3.
- **Adicionar source via URL**: registra uma página da web como source de um notebook, a partir de uma URL informada pelo usuário.
- Em ambos os casos, o contrato responde de forma imediata (padrão *async request-reply*): o source é criado com status "processando", e a obtenção/extração de conteúdo, chunking e geração de embeddings ocorrem de forma assíncrona em segundo plano.
- **Listar sources de um notebook**: retorna os sources associados a um notebook, incluindo origem, formato e status de processamento (painel "sources" da Tela 3) — usado pelo frontend para acompanhar a transição de status até "pronto".

## Conversations

- **Criar conversa**: inicia uma nova conversa (sessão de chat independente, com histórico próprio) dentro de um notebook.
- **Listar conversas de um notebook**: retorna as conversas já iniciadas naquele notebook.
- **Atualizar sources ativas da conversa**: define quais sources (dentre as que estão "prontas") ficam ativas como contexto de busca para as próximas mensagens da conversa; pode ser chamado a qualquer momento para alterar a seleção ao longo da conversa.

## Chat

- **Enviar mensagem**: envia uma pergunta do usuário para uma conversa específica (`conversation_id`). A resposta é fundamentada nas sources atualmente ativas naquela conversa e entregue via streaming (Server-Sent Events) entre backend e frontend, permitindo exibição incremental do texto gerado enquanto a resposta é produzida.
- **Histórico de mensagens**: recuperação das mensagens já trocadas naquela conversa, para reconstrução do chat ao reabri-la.

## Considerações Transversais

- Todos os contratos autenticados exigem o token emitido no fluxo de login; a aplicação não mantém estado de sessão em memória entre requisições, então qualquer instância do backend deve poder atender qualquer requisição de um usuário autenticado.
- A resposta em streaming do chat é o único contrato com natureza de conexão de longa duração; os demais são requisição/resposta convencionais.
