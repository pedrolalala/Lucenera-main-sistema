# Fluxos encontrados

- Reunião: 04. Lucenera (Filippo) - 08.04.2026: CRM Supabase e integração SharePoint
- Data: 2026-04-08
- Horário: 11:30
- Duração aproximada: 01:09:25
- Link tl;dv: https://tldv.io/app/meetings/69d66666a5e8fc0013fa5517
- Fonte: transcrição e metadados retornados pela API do tl;dv.

## Observação

Os fluxos abaixo foram extraídos da transcrição desta reunião. Quando um ponto foi citado como intenção ou desenho futuro, ele está representado como fluxo desejado, não como processo já implementado.

## Fluxo 1 - Fechamento comercial até projeto operacional

```mermaid
flowchart TD
    CRM["CRM / vendas"] --> FECH["Negócio fechado"]
    FECH --> REV["Equipe responsável revisa informações"]
    REV --> SUPA["Registrar projeto no Supabase"]
    SUPA --> SP["Criar/atualizar SharePoint"]
    SP --> PASTA["Pasta do projeto"]
    SP --> PLANNER["Projeto/tarefas no Planner"]
    SUPA --> MOD["Módulos internos conectados"]
```

## Fluxo 2 - Estratégia correta para banco e IA

```mermaid
flowchart LR
    MAP["Mapear dados necessários em documento"] --> MODEL["Definir tabelas, IDs e relações"]
    MODEL --> PROMPT["Gerar prompts/SQL com IA"]
    PROMPT --> SKIP["Skip cria/ajusta código e migrations"]
    SKIP --> SUPA["Supabase mantém estrutura relacional"]
    SUPA --> APP["Interfaces e automações conectadas"]
```
