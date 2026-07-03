# Fluxos encontrados

- Reunião: 01. Lucenera (Filippo) - 03.12.2025: Mapeamento inicial de áreas e dores de automação
- Data: 2025-12-03
- Horário: 15:30
- Duração aproximada: 01:20:13
- Link tl;dv: https://tldv.io/app/meetings/6930819fceb9ed00139eb6b5
- Fonte: transcrição e metadados retornados pela API do tl;dv.

## Observação

Os fluxos abaixo foram extraídos da transcrição desta reunião. Quando um ponto foi citado como intenção ou desenho futuro, ele está representado como fluxo desejado, não como processo já implementado.

## Fluxo 1 - Estrutura interna mapeada na reunião

```mermaid
flowchart TB
    EMP["Lucenera / Atelier da Luz"] --> PROJ["Projetos: 3 equipes"]
    EMP --> ADM["Administrativo"]
    EMP --> LOG["Logística"]
    EMP --> EST["Estoque"]
    EMP --> VEN["Loja / Vendas"]
    EMP --> OBRA["Obra"]
    EMP --> MKT["Marketing"]
    EMP --> IA["Pedro: IA e automações"]
    PROJ --> P1["Atende clientes"]
    PROJ --> P2["Dá suporte à obra"]
    PROJ --> P3["Desenhos / CAD 2D"]
    PROJ --> P4["Fichas técnicas"]
    P4 --> P41["Foto, descrição, fonte de luz e acessórios"]
    ADM --> S["Sistema interno"]
    LOG --> ENT["Entregas e rotas"]
    VEN --> S
    EST --> S
```

## Fluxo 2 - Dados e relatórios desejados

```mermaid
flowchart LR
    S["Sistema interno"] --> V["Vendas"]
    S --> R["Recebíveis"]
    S --> C["Comissões"]
    S --> CP["Compras / entradas"]
    S --> PROD["Cadastro de produtos"]
    S --> DOR["Dor: difícil extrair e visualizar"]
    DOR --> ATUAL["Atual: relatório por banco + planilha tratada + Julius"]
    DOR --> FUT["Desejado: API + interface IA"]
    FUT --> CHAT["Perguntar em caixa de mensagem"]
    CHAT --> BASE["Consulta ao banco/sistema"]
    BASE --> OUT["Resposta, relatório ou gráfico"]
```

## Fluxo 3 - Entrega desejada

```mermaid
flowchart TD
    PROJ["Projetos marca data de entrega"] --> LOG["Logística recebe informação"]
    LOG --> RESP["Identifica responsável por receber"]
    RESP --> MSG["Mensagem de confirmação um dia antes"]
    MSG --> OK{"Confirmou?"}
    OK -- "Não" --> REAG["Reagendar"]
    OK -- "Sim" --> ROTA["Gerar rota / usar Maps ou agente"]
    ROTA --> CARRO["Carregar carro pela manhã"]
    CARRO --> ENTREGA["Entregar na obra"]
    ENTREGA --> ASS["Lista assinada + foto"]
    ASS --> CONF["Conferência com lista de materiais"]
    CONF --> AVISO["Aviso para projetista/equipe responsável"]
```
