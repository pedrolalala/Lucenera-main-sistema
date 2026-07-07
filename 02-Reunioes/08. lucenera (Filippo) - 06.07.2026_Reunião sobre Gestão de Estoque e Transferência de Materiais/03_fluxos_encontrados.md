# Fluxos encontrados

- Reunião: 08. Lucenera (Filippo) - 06.07.2026: Gestão de Estoque e Transferência de Materiais
- Data: 2026-07-06
- Duração aproximada: 00:15:19
- Fonte: transcrição local em `00_original/Reunião_Filippo_Vinicius_Pedro.md`

## Observação

Os fluxos abaixo representam o desenho operacional discutido. Pontos ainda não implementados devem ser tratados por SPEC antes de virar código ou migration.

## Fluxo 1 - Estoque total, reservado e disponível

```mermaid
flowchart LR
    TOTAL["Estoque total / físico"] --> DISP["Estoque disponível"]
    TOTAL --> RES["Estoque de cliente / itens reservados"]
    RES --> CLIENTES["Clientes específicos"]
    CLIENTES --> PROJ["Projetos / orçamentos aprovados"]
    DISP_DESC["Disponível = total - reservado"] --> DISP
```

## Fluxo 2 - Venda sem saldo suficiente

```mermaid
flowchart TD
    ORC["Orçamento aprovado"] --> ITEM["Item aprovado"]
    ITEM --> CALC{"Há disponível suficiente?"}
    CALC -- "Sim" --> RES["Reserva para cliente/projeto"]
    CALC -- "Não" --> FUT["Entrega futura"]
    FUT --> NEC["Necessidade de compra por produto"]
    NEC --> COMPRA["Compra sem vínculo fixo ao cliente"]
    COMPRA --> RECEB["Material chega"]
    RECEB --> DEB["Débora decide/re-reserva conforme prioridade atual"]
```

## Fluxo 3 - Transferência de reserva entre clientes

```mermaid
flowchart TD
    SOL["Equipe solicita transferência"] --> VI["Vitória avalia/aprova"]
    VI --> ORIG["Cliente/projeto de origem perde cobertura física"]
    VI --> DEST["Cliente/projeto de destino ganha cobertura física"]
    ORIG --> FUT["Origem volta para entrega futura/necessidade"]
    DEST --> RES["Destino fica reservado"]
    VI --> HIST["Histórico registra produto, quantidade, de/para, solicitante, aprovador e motivo"]
    FUT --> COMPRA["Reposição entra como necessidade de compra agregada por produto"]
```

## Fluxo 4 - Consulta operacional por produto

```mermaid
flowchart TD
    PROD["Abrir produto no estoque"] --> ABAS["Abas/visões"]
    ABAS --> DISP["Disponível"]
    ABAS --> RES["Reservado por cliente"]
    ABAS --> FUT["Entrega futura"]
    ABAS --> TRANSF["Transferências/histórico"]
    ABAS --> NEC["Necessidade de compra"]
```
