# Fluxos encontrados

- Reunião: 03. Lucenera (Filippo) - 24.03.2026: Estratégia Adapta Pass e portal do cliente
- Data: 2026-03-24
- Horário: 15:00
- Duração aproximada: 53:52
- Link tl;dv: https://tldv.io/app/meetings/69c2d126c5ff72001346956a
- Fonte: transcrição e metadados retornados pela API do tl;dv.

## Observação

Os fluxos abaixo foram extraídos da transcrição desta reunião. Quando um ponto foi citado como intenção ou desenho futuro, ele está representado como fluxo desejado, não como processo já implementado.

## Fluxo 1 - Da venda ao portal do cliente

```mermaid
flowchart TD
    CRM["CRM / comercial"] --> FECH["Negócio fechado"]
    FECH --> PROJ["Criar projeto"]
    PROJ --> DADOS["Registrar dados no Supabase"]
    DADOS --> MOD["Módulos internos por área"]
    DADOS --> PORTAL["Portal do cliente"]
    PORTAL --> STATUS["Fase do projeto"]
    PORTAL --> PEND["Pendências"]
    PORTAL --> PAG["Pagamentos realizados/a pagar"]
    MOD --> NOTIF["Notificações WhatsApp / e-mail / Slack"]
```

## Fluxo 2 - Estratégia de automação

```mermaid
flowchart LR
    PESSOAS["Amplificar pessoas"] --> PROC["Sistematizar processos"]
    PROC --> DADOS["Organizar dados no Supabase"]
    DADOS --> AUTO["Criar automações"]
    AUTO --> DASH["Dashboards e interfaces"]
    DASH --> GOV["Permissões e governança"]
```
