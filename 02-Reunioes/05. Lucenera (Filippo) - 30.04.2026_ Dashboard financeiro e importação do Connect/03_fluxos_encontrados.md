# Fluxos encontrados

- Reunião: 05. Lucenera (Filippo) - 30.04.2026: Dashboard financeiro e importação do Connect
- Data: 2026-04-30
- Horário: 11:07
- Duração aproximada: 51:22
- Link tl;dv: https://tldv.io/app/meetings/69f3623f9ec3c90013df386c
- Fonte: transcrição e metadados retornados pela API do tl;dv.

## Observação

Os fluxos abaixo foram extraídos da transcrição desta reunião. Quando um ponto foi citado como intenção ou desenho futuro, ele está representado como fluxo desejado, não como processo já implementado.

## Fluxo 1 - Importação e dashboard financeiro

```mermaid
flowchart TD
    CONNECT["Connect / sistema legado"] --> EXP["Exportar planilhas"]
    DRIVE["Google Drive com planilhas"] --> TRAT["Tratar/normalizar dados"]
    EXP --> TRAT
    TRAT --> FILTRO["Excluir dados que já serão gerados por regras internas"]
    FILTRO --> SUPA["Importar para tabelas Supabase"]
    SUPA --> VIEWS["Criar views consolidadas"]
    VIEWS --> DASH["Dashboard financeiro para Felipe"]
```

## Fluxo 2 - Histórico x regras futuras

```mermaid
flowchart LR
    HIST["Dados históricos do Connect"] --> IMP["Importação controlada"]
    FUT["Operações futuras"] --> REGRAS["Regras dos sistemas internos"]
    RH["RH: salários/bonificações"] --> REGRAS
    CRM["CRM: projeto fechado"] --> REGRAS
    EST["Estoque/produtos"] --> REGRAS
    IMP --> FIN["Financeiro"]
    REGRAS --> FIN
    FIN --> ALERTA["Evitar duplicidade de valores"]
```
