# Fluxos Consolidados das Reuniões Lucenera

Este arquivo consolida os principais fluxos recorrentes identificados nas 8 reuniões. Para detalhes e fonte, consulte o `03_fluxos_encontrados.md` de cada pasta.

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
- Estoque/Compras: saldos por item de projeto, reserva por projeto/cliente como visualização, entrega futura, transferência de reserva, necessidade de compra agregada por produto e re-reserva quando material chega.

## Fluxo consolidado de estoque, reserva e compra

```mermaid
flowchart TD
    ORC["Orçamento aprovado"] --> ITEM["Item aprovado do projeto"]
    ITEM --> RES["Reserva por item de projeto (estoque de cliente na tela)"]
    RES --> DISP["Disponível = estoque físico - reservado"]
    DISP --> FUT{"Disponível negativo?"}
    FUT -- "Não" --> OK["Atendimento coberto por estoque"]
    FUT -- "Sim" --> EF["Entrega futura"]
    EF --> NEC["Necessidade de compra por produto"]
    NEC --> COMPRA["Compra sem vínculo fixo com cliente"]
    COMPRA --> RECEB["Recebimento do material"]
    RECEB --> DECISAO["Débora re-reserva conforme prioridade atual"]
```

## Fluxo consolidado de transferência de reserva

```mermaid
flowchart TD
    PROD["Produto com saldos por projeto_item_id"] --> SOL["Equipe solicita transferência"]
    SOL --> APROV["Vitória aprova"]
    APROV --> DEST["Destino ganha cobertura/reserva"]
    APROV --> ORIG["Origem perde cobertura e volta para entrega futura"]
    APROV --> HIST["Histórico audita produto, quantidade, de/para, solicitante e aprovador"]
    ORIG --> NEC["Necessidade de compra continua agregada por produto"]
```
