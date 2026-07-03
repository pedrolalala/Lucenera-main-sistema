# Fluxos encontrados

- Reunião: 02. Lucenera (Filippo) - 28.01.2026: Automação logística de entregas
- Data: 2026-01-28
- Horário: 15:10
- Duração aproximada: 01:19:47
- Link tl;dv: https://tldv.io/app/meetings/697a512613f5310013e3b29e
- Fonte: transcrição e metadados retornados pela API do tl;dv.

## Observação

Os fluxos abaixo foram extraídos da transcrição desta reunião. Quando um ponto foi citado como intenção ou desenho futuro, ele está representado como fluxo desejado, não como processo já implementado.

## Fluxo 1 - Automação logística em três fases

```mermaid
flowchart TD
    PED["Pedido / entrega a preparar"] --> SEP["Fase 1: separação de materiais"]
    SEP --> MATEUS["Mateus / estoque confere separação"]
    MATEUS --> DADOS["Registrar obra, itens, responsável e endereço"]
    DADOS --> ROTA["Fase 2: criação de rota"]
    ROTA --> CRIT["Critérios: horário, urgência, distância e capacidade"]
    CRIT --> MSG["Fase 3: mensagem de confirmação"]
    MSG --> CONF{"Responsável confirma?"}
    CONF -- "Não" --> REAG["Reagendar / ajustar rota"]
    CONF -- "Sim" --> EXEC["Executar entrega"]
    EXEC --> PROVA["Registrar status/evidência"]
    PROVA --> HIST["Salvar no banco / histórico"]
```

## Fluxo 2 - Canais e dados

```mermaid
flowchart LR
    W["WhatsApp"] --> CAP["Captura de mensagens e confirmações"]
    T["Teams"] --> OPS["Centralização operacional desejada"]
    CAP --> DB["Supabase / banco de dados"]
    OPS --> DB
    DB --> PAINEL["Painel por perfil"]
    PAINEL --> SEP["Separador"]
    PAINEL --> GEST["Gerente de logística"]
    PAINEL --> ENT["Entregador"]
```
