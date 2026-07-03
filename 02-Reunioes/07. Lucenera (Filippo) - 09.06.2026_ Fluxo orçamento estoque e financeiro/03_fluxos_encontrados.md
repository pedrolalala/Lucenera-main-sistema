# Fluxos encontrados

- Reunião: 07. Lucenera (Filippo) - 09.06.2026: Fluxo orçamento estoque e financeiro
- Data: 2026-06-09
- Horário: 14:00
- Duração aproximada: 01:19:29
- Link tl;dv: https://tldv.io/app/meetings/6a2846baebc00200127220aa
- Fonte: transcrição e metadados retornados pela API do tl;dv.

## Observação

Os fluxos abaixo foram extraídos da transcrição desta reunião. Quando um ponto foi citado como intenção ou desenho futuro, ele está representado como fluxo desejado, não como processo já implementado.

## Fluxo 1 - Orçamento aprovado até compra/estoque

```mermaid
flowchart TD
    ORC["Orçamento criado"] --> APR{"Orçamento aprovado?"}
    APR -- "Não" --> NEG["Negociação / ajuste"]
    NEG --> ORC
    APR -- "Sim" --> ITENS["Ler itens do orçamento"]
    ITENS --> EST{"Há estoque disponível?"}
    EST -- "Sim" --> RES["Reservar / baixar estoque"]
    EST -- "Não" --> NEC["Gerar necessidade de compra"]
    NEC --> FIN["Avisar financeiro/compras"]
    FIN --> COMPRA["Comprar peça/material"]
    COMPRA --> ENTRADA["Entrada no estoque"]
    ENTRADA --> RES
    RES --> PROJ["Atualizar projeto e financeiro"]
```

## Fluxo 2 - Modelo de dados necessário

```mermaid
flowchart LR
    CLIENTE["Cliente"] --> PROJ["Projeto"]
    PROJ --> ORC["Orçamento"]
    ORC --> ITEM["Itens do orçamento"]
    ITEM --> PROD["Produto"]
    PROD --> EST["Estoque: quantidade/disponibilidade"]
    ITEM --> NEC["Necessidade de compra"]
    ORC --> FIN["Financeiro: receber/pagar"]
    FIN --> DASH["Dashboard / views"]
```

## Fluxo 3 - Trabalho com Skip sem bagunçar banco

```mermaid
flowchart TD
    SUPA["Supabase normalizado"] --> DOC["Documentar tabelas e relações"]
    DOC --> PROMPT["Prompt explícito para Skip"]
    PROMPT --> REGRA["Não criar tabelas novas; usar existentes"]
    REGRA --> APP["Interface/dashboard"]
    APP --> TESTE["Validar dados puxados"]
    TESTE --> AJUSTE["Corrigir view/relação se necessário"]
```
