# Fluxos encontrados

- Reunião: 06. Lucenera (Filippo) - 13.05.2026: Limpeza de dados e relacionamentos no Supabase
- Data: 2026-05-13
- Horário: 09:00
- Duração aproximada: 02:09:29
- Link tl;dv: https://tldv.io/app/meetings/6a0467ef097a350013b62060
- Fonte: transcrição e metadados retornados pela API do tl;dv.

## Observação

Os fluxos abaixo foram extraídos da transcrição desta reunião. Quando um ponto foi citado como intenção ou desenho futuro, ele está representado como fluxo desejado, não como processo já implementado.

## Fluxo 1 - Deduplicação de contatos e projetos

```mermaid
flowchart TD
    DUP["Contato duplicado: arquiteto/cliente"] --> CAN["Escolher registro canônico"]
    CAN --> SUB["Linkar ou remover subsidiários"]
    SUB --> BUSCA["Buscar projetos por nome/código"]
    BUSCA --> VINC["Vincular projeto ao contato correto"]
    VINC --> VAL["Validar contagem antes/depois"]
    VAL --> REGRA["Criar regra para não duplicar novamente"]
```

## Fluxo 2 - Relacionamento financeiro-projeto

```mermaid
flowchart LR
    PROJ["Projetos"] --> IDP["Código / ID do projeto"]
    CR["Contas a receber"] --> LINK["Linkagem por projeto/nome fantasia"]
    CP["Contas a pagar"] --> LINK
    IDP --> LINK
    LINK --> VIEW["Views financeiras por projeto"]
    VIEW --> DASH["Visão integrada: projeto, cliente, receita e custo"]
```
