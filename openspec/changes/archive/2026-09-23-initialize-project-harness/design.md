# Design

## Context

Ver proposal.md - Why. As decisões abaixo já estão registradas em detalhe em `ARCHITECTURE.md`, `DOMAIN.md` e `API.md`; este documento resume as escolhas de design que levaram a esses três documentos e o raciocínio por trás delas.

## Goals / Non-Goals

**Goals:**
- Definir um modelo de domínio, contratos de API e arquitetura de alto nível coerentes entre si, antes de qualquer implementação.
- Registrar riscos arquiteturais já identificados (ex.: SSE através do API Gateway) para que sejam endereçados pelas changes que os tocarem.

**Non-Goals:**
- Detalhar o desenho técnico de qualquer capability específica (auth, notebooks, sources, chat) — escopo de changes futuras.
- Especificar tecnologias de implementação além do que já é pré-requisito declarado do projeto.

## Decisions

1. **Notebook é privado, dono único** (sem compartilhamento entre usuários) — os wireframes (Tela 2/3) não mostram UI de compartilhamento. Alternativa considerada: notebooks com múltiplos membros — descartada por aumentar o escopo do domínio sem necessidade de produto validada.

2. **Processamento de sources é assíncrono**, padrão *async request-reply* com fila (SQS) consumida por uma função assíncrona (Lambda) — evita bloquear a resposta de upload/URL e independe do tamanho do conteúdo. Alternativa considerada: processamento síncrono no próprio request — descartada por não escalar para arquivos grandes e degradar a experiência de upload.

3. **Seleção de sources no chat é explícita por pergunta** (o usuário escolhe quais sources ativar), não implícita sobre todas as sources do notebook — molda o contrato de "enviar mensagem" (`API.md`) e o relacionamento `ChatMessage` ↔ `Source` (`DOMAIN.md`). Alternativa considerada: contexto sempre igual a todas as sources prontas — mais simples, porém menos fiel ao comportamento do NotebookLM que o mockup reproduz.

4. **Provedor de LLM (Bedrock/OpenRouter) é configuração de sistema**, não exposto ao usuário — simplifica o MVP e evita expor decisões de custo/infraestrutura ao usuário final. Alternativa considerada: seleção de provedor por notebook/usuário — descartada por falta de necessidade de produto identificada.

5. **Streaming de chat via SSE precisa de tratamento diferenciado no caminho do API Gateway** — risco arquitetural registrado (ver `ARCHITECTURE.md` § "Streaming de chat via API Gateway"); a decisão final de roteamento fica para a change que implementar o chat.

## Risks / Trade-offs

- [Risco] API Gateway faz *buffering* de resposta e tem timeout de integração de ~29-30s, incompatível com uma conexão SSE de longa duração → [Mitigação] decisão de roteamento (ex.: caminho de chat contornando o buffering do API Gateway, ou eventos de *keep-alive*) fica para a change que implementar o chat; o risco já está documentado em `ARCHITECTURE.md` para não ser esquecido.
- [Risco] O pipeline de ingestão assíncrono introduz consistência eventual — um `Source` pode não estar "pronto" imediatamente após o upload/URL → [Mitigação] o status do `Source` é exposto explicitamente e consultável pelo frontend; a UX já contempla esse estado (painel "sources" da Tela 3).
- [Trade-off] Não especificar tecnologias de implementação nesta change adia decisões técnicas de baixo nível para quando cada capability for de fato desenhada — aceito propositalmente, já que o projeto ainda não está pronto para essas decisões.
