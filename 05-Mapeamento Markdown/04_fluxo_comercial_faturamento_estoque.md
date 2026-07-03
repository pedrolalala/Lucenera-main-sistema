# Fluxo Comercial - Venda, Faturamento, Devolução e Aquisição

Fonte: board Miro "fluxograma Lucenera" (consolidado), widget "Faturamento Lucenera" (5 sub-processos lado a lado). Texto fiel ao board, incluindo erros de digitação originais (ex.: "ASSINTURA", "FORNCEDOR", "ASQUISIÇÃO", "FINANCERIO").

## 1. Venda Padrão - Lucenera

Fluxo principal: conferência de informações, faturamento e o sub-fluxo de compras (compartilhado/análogo nos demais processos desta página).

```mermaid
flowchart TD
    A["VENDA PADRÃO - LUCENERA"] --> B["EQUIPE DE PROJETOS ENVIA"]
    B --> C["ENVELOPE COM DOCS DE ORÇAMENTO APROVADO PARA ASSINATURA"]
    C --> D["ASSINTURA FEITA"]
    D --> E["RECEBIMENTO DO ORÇAMENTO APROVADO E CONTRATO"]
    E --> F{"TODAS INF. PRECISAM ESTAR CORRETAS"}
    F -.-> CH["CHECAGEM DE INFORMAÇÕES:"]

    F --> G1["PRODUTO S/ CADASTRO"]
    G1 --> G2["CONSULTA DE DADOS COM FORNECEDOR"]
    G2 --> G3["SEM INFORMAÇÃO?"]
    G2 --> G4["COM INFORMAÇÃO?"]
    G3 --> G5["SOLICITA INFORMAÇÃO PROJETOS"]
    G4 --> G6["SOLICITA CADASTRO COMPRAS"]
    G6 --> G7["APÓS CADASTRO, SEGUE"]

    F --> H1["COND. PAGAMENTO"]
    H1 --> H2["CERTO?"]
    H1 --> H3["ERRADO/FALTANDO"]
    H2 --> H4["SEGUE"]
    H3 --> H5["SOLICITA INFORMAÇÃO"]

    F --> I1["ARQUIT. EXT."]
    I1 --> I2["CERTO?"]
    I1 --> I3["ERRADO OU SEM"]
    I2 --> I4["SEGUE"]
    I3 --> I5["SOLICITA CORREÇÃO OU INCLUSÃO"]

    F --> J1["EMPRESA FAT."]
    J1 --> J2["CERTO?"]
    J1 --> J3["ERRADO"]
    J2 --> J4["SEGUE"]
    J3 --> J5["SOLICITA CORREÇÃO OU CORRIGE"]

    G7 --> K["TUDO REVISADO, INFORMAÇÕES CORRETAS E PRODUTOS CADASTRADOS - INICIA-SE O PROCESSO DE FATURAMENTO:"]
    H4 --> K
    I4 --> K
    J4 --> K
    G5 -.-> K
    H5 -.-> K
    I5 -.-> K
    J5 -.-> K

    K --> L["ALIMENTAR VENCIMENTOS"]
    L --> M["FECHAR ORÇAMENTO"]
    M --> N["APROVAR ORÇAMENTO"]
    N --> N2["ENVIAR SEPARAÇÃO P/ ESTOQUE (TEAMS)"]
    N --> O["EMITIR NOTA"]
    O --> O2["IMPRIMIR C/ MEMÓRIA DE CÁLCULO"]
    O --> O3["ENVIAR POR EMAIL CLIENTE E ENVOLVIDOS"]
    O --> P["EMITIR BOLETO"]
    P --> P2["PONTUAR CLUBE MAIS (PLANILHA E SITE)"]
    P --> Q["GERAR REMESSA BANCÁRIA"]
    Q --> R["ENVIAR AO BANCO"]

    R --> S["VENDA FINALIZADA? INICIA-SE PROCESSO DE COMPRA, QUE PODE SER DE IMEDIATO OU AGUARDAR ALGUNS DIAS"]
```

### Sub-fluxo de compras (a partir de "VENDA FINALIZADA?")

```mermaid
flowchart TD
    S["VENDA FINALIZADA? INICIA-SE PROCESSO DE COMPRA..."] --> T1["SE PEÇA ESPECIAL?"]
    T1 --> T2["AGUARDAR DESENHO"]
    S --> T3["PEÇA PADRÃO LUCENERA"]
    S --> T4["PEÇA PADRÃO FORNCEDOR"]

    T3 --> U1["IMPRIMIR"]
    T4 --> U1
    U1 --> U2["MONTAR PEDIDO"]
    U2 --> U3{"É COMUM QUE MONTA PEDIDOS MESMO FORNECEDOR VAI DE ACORDO COM O CNPJ VENDEDOR"}
    U3 --> U4["SALVAR NA PASTA DO FORNECEDOR"]
    U4 --> U5["ENVIAR PARA O FORNECEDOR"]
    U5 --> U6["AGUARDAR CÓPIA DO PEDIDO"]
    U6 --> U7["SOLICITAR CORREÇÃO"]
    U7 -.-> U6
    U6 --> U8["CONFERIR"]
    U8 --> U9["APROVAR"]
    U9 --> U10{"AGUARDAR CHEGAR MATERIAL NO ESTOQUE"}

    T2 --> V1["RECEBEU DESENHO?"]
    V1 --> V2["CONFERIR COM A VENDA"]
    V2 --> V3["MONTAR PEDIDO"]
    V3 --> V4["INDUSTRIALIZAÇÃO LUCENERA:"]
    V4 --> V5["ENVIA PARA CLAUDIO - PEDIDO E DESENHO"]
    V4 --> V6["IMPRIMIR"]
    V4 --> V7["ALIMENTA PLANILHA CONTROLE DE PRODUÇÃO"]
    V5 --> V8{"AGUARDAR PRODUÇÃO LUCENERA"}
    V8 --> V9["CLAUDIO ENVIA PEDIDO FINALIZADO PARA ENTRADA"]
    V9 --> V10["ENTRADA DO MATERIAL"]

    U10 --> W1["FORNECEDOR PADRÃO:"]
    W1 --> W2["SALVAR PEDIDO NA PASTA"]
    W2 --> W3["ENVIAR PARA FORNECEDOR PEDIDO E DESENHO"]
    W3 --> W4["IMPRIMIR"]
    W3 --> W5["AGUARDAR CÓPIA DO FORNECEDOR"]
    W5 --> W6["SOLICITAR CORREÇÃO"]
    W6 -.-> W5
    W5 --> W7["CONFERIR"]
    W7 --> W8["APROVAR"]
    W8 --> X1{"AGUARDAR CHEGAR MATERIAL NO ESTOQUE"}

    X1 --> Y1["MATERIAL CHEGA NO ESTOQUE"]
    V10 --> Y1
    Y1 --> Y2["CONFERÊNCIA DE NOTA E VOLUME"]
    Y2 --> Y3["SE, PEÇA DECORATIVA TEM A CONFEÊNCIA MINUCIOSA ITEM A ITEM"]

    V10 --> Z1["PASSAR DOCUMENTO DE ENTRADA PARA DEP. C. A PAGAR"]
    Z1 --> Z2["LANÇAMENTO FINANCEIRO"]
    Z2 --> Z3["ENTRADA DO MATERIAL"]
    Z3 --> Z4["CONFERIR VALORES"]
    Z4 --> Z5["CONFERIR NOTA COM PEDIDO"]
    Z5 --> Z6{"NOTA FISICA VAI PARA ESCRITÓRIO"}

    Z3 --> AA1["VINCULAR MATERIAL COM VENDAS DE CLIENTES"]
    Z3 --> AA2["PASSAR RELAÇÃO DE VINCULO AO ESTOQUE"]
    AA1 --> AA3["START SEPARAÇÃO FISICA DO PRODUTO NO ESTOQUE"]
    AA2 --> AA3
```

> O diamante cinza próximo a "CONFERIR/APROVAR" do ramo fornecedor padrão ficou parcialmente cortado na captura original — texto reconstruído por analogia ao diamante equivalente do outro ramo; vale confirmar no board se precisão exata for necessária.

## 2. Venda para Ficar em Aberto - Lucenera

```mermaid
flowchart TD
    A[VENDA PARA FICAR EM ABERTO - LUCENERA] --> B[RECEBIMENTO DO ORÇAMENTO PARA VENDA SEM COBRANÇA IMEDIATA PENDENCIAS]
    B --> C((REPETE TODO ESSE CICLO))
    C --> D{{EXCEÇÃO:}}
    D --> E[ALIMENTA PLANILHA DE PENDENCIA]
    D --> F[NÃO TEM EMISSÃO DE NF E BOLETO]
```

## 3. Devolução para Ficar em Aberto - Lucenera

```mermaid
flowchart TD
    A[DEVOLUÇÃO PARA FICAR EM ABERTO - LUCENERA] --> B[RECEBIMENTO DO ORÇAMENTO DE DEVOLUÇÃO PARA FICAR EM ABERTO PENDENCIAS AQUISIÇÃO]
    B --> C((REPETE TODO ESSE CICLO))
    C --> D{{EXCEÇÃO:}}
    D --> E[NÃO TEM EMISSÃO DE NF E BOLETO]
    D --> F[ALIMENTA PLANILHA DE PENDENCIA]
    D --> G[NÃO TEM PROCESSO DE COMPRA]
```

## 4. Aquisição + Devolução - Lucenera

```mermaid
flowchart TD
    A[AQUISIÇÃO + DEVOLUÇÃO - LUCENERA] --> B[RECEBIMENTO DOS ORÇAMENTOS DE DEVOLUÇÃO E AQUISIÇÃO]
    B --> C((REPETE TODO ESSE CICLO))
    C --> D{{SITUAÇÕES}}
    D --> E((FICAR TUDO EM ABERTO:))
    E --> E1[NÃO TEM EMISSÃO DE NF E BOLETO]
    E --> E2["TEM PROCESSO DE COMPRA DA ASQUISIÇÃO: (SE NÃO TIVER ESTOQUE)"]
    E --> E3[ALIMENTA PLANILHA DE PENDÊNCIA]
    D --> F((ELAS POR ELAS))
    F --> F1[NA MAIORIA DAS VEZES NÃO TEM EMISSÃO DE]
    F --> F2[FAZER ACORDO E BAIXAR FINANCEIRO]
    F --> F3["TEM PROCESSO DE COMPRA DA ASQUISIÇÃO: (SE NÃO TIVER ESTOQUE)"]
    D --> G((COBRAR DIFERENÇA))
    G --> G1[REPETE O PROCESSO DE EMISSÃO DE NOTA E BOLETO]
    G --> G2["TEM PROCESSO DE COMPRA DA ASQUISIÇÃO: (SE NÃO TIVER ESTOQUE)"]
```

## 5. Orçamento de Brinde - Lucenera

```mermaid
flowchart TD
    A[ORÇAMENTO DE BRINDE - LUCENERA] --> B[RECEBIMENTO DO ORÇAMENTO DE BRINDE]
    B --> C((REPETE PROCESSO DE VERIFICAÇÃO DE DADOS))
    C --> D[NÃO GERA FINANCERIO]
    C --> E[EMITE BRINDE]
    E --> F["TEM PROCESSO DE COMPRA DA ASQUISIÇÃO: (SE NÃO TIVER ESTOQUE)"]
```
