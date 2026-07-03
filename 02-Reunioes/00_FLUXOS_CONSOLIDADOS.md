# Fluxos Consolidados das Reuniões Lucenera

Este arquivo consolida os principais fluxos recorrentes identificados nas 7 reuniões. Para detalhes e fonte, consulte o `03_fluxos_encontrados.md` de cada pasta.

## Mapa macro

```mermaid
flowchart TB
    COM["Comercial / CRM"] --> FECH["Negócio fechado"]
    FECH --> PROJ["Projeto"]
    PROJ --> ORC["Orçamento"]
    ORC --> EST["Estoque / produtos"]
    ORC --> FIN["Financeiro"]
    PROJ --> OBRA["Obra / entrega"]
    OBRA --> LOG["Logística"]
    LOG --> CONF["Confirmação e comprovante"]
    PROJ --> CLIENTE["Portal/status para cliente"]
    COM --> DADOS["Supabase / dados relacionados"]
    PROJ --> DADOS
    ORC --> DADOS
    EST --> DADOS
    FIN --> DADOS
    DADOS --> DASH["Dashboards / views"]
    DADOS --> AUTO["Automações WhatsApp, e-mail, SharePoint, Planner"]
```

## Frentes recorrentes

- Dados e Supabase: normalização, IDs, canônicos, views, validações e relacionamento entre tabelas.
- Logística: separação, roteirização, confirmação de entrega, comprovante e comunicação com projetistas/obra.
- Financeiro: histórico do Connect, contas a pagar/receber, parcelas, dashboards e prevenção de duplicidade.
- Projetos: criação de projeto após venda, fichas técnicas, apresentações, CAD/AutoCAD e portal do cliente.
- Automação: WhatsApp, Teams, SharePoint, Planner, Edge Functions, n8n, Skip, VS Code/IA e Python/Vercel.
