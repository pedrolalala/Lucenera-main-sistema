# Projeto Luminotécnico - Entrada, Contrato, Aprovação e Faturamento

Fonte: board Miro "fluxograma Lucenera" (consolidado), widgets do "Quadro 1" (Entrada de Projeto + ciclo de Contrato/Apresentação/Aprovação) e widget "Projeto Luminotécnico" (versão de faturamento). Texto fiel ao board.

## 1. Entrada de Projeto

```mermaid
flowchart TD
    A[ENTRADA DE PROJETO] --> B[CRIAR CADASTRO]
    B --> C[PASTA NO SHARE POINT]
    C --> D[REUNIÃO DE BIEFING]
    D --> E[DESENVOLVER CONTRATO DE\nPROJETO OU CONTRATO DE\nSINAL]
    D --> F[AGENDAR COM ARQ]
    D --> G[AGENDAR COM\nCLIENTES]
    D --> H[IMPRIMIR PROJETOS]
    D --> I[GRAVAR ÁUDIO\nREUNIÃO]
    D --> J[GERAR RELATÓRIO\nREUNIÃO]
    D --> K[PROJETO PARA\nVENDA IMEDIATA]
```

> "REUNIÃO DE BIEFING" é o texto literal do board (erro de digitação de "BRIEFING"). "CRIAR CADASTRO" é destacado em vermelho no board. `E` conecta diretamente ao ciclo abaixo.

## 2. Ciclo de Contrato e Aprovação de Projeto

Continuação direta de "DESENVOLVER CONTRATO DE PROJETO OU CONTRATO DE SINAL". É o maior fluxo do board: assinatura de contrato, 1ª/2ª/3ª apresentações (preliminar, pré-executivo, executivo) e cobranças de parcela, terminando em "ENVIO FINAL".

```mermaid
flowchart TD
    A[CONTRATO PROJETO] --> B1[REUNIÃO PARA\nAPRESENTAR\nCONTRATO]
    A --> B2[ENVIO POR E-MAIL]
    B1 --> C[CONTRATO\nAPROVADO]
    B2 --> C
    C --> D[PACOTE DOCUSIGN\nASSINATURA DIGITAL]
    D --> D1[ASSINATURA\nLUCENERA]
    D --> D2[ASSINATURA CLIENTE]
    D --> D3[CROQUI DE PROJETO]
    D --> E1[EMISSÃO NF ISLIGHT]
    D --> E2[COBRANÇA 1ª\nPARCELA CONTRATO]
    D --> F[1ª APRESENTAÇÃO DE\nPROJETO]

    F --> F1[CROQUI DE PROJETO]
    F --> F2[REVISÃO PROJETO]
    F --> F3[PROJETO DIALUX]
    F --> F4[COBRANÇA 1ª\nPARCELA CONTRATO]

    F1 --> G1[PROJETO AUTOCAD]
    G1 --> G2[APRESENTAÇÃO]
    G2 --> G3[AGENDAR COM ARQ]
    G2 --> G4[AGENDAR COM\nCLIENTES]
    G2 --> G5[IMPRIMIR PROJETOS]
    G2 --> G6[GRAVAR ÁUDIO\nREUNIÃO]
    G2 --> G7[GERAR RELATÓRIO\nREUNIÃO]
    G1 --> G8[ORÇAMENTO DE\nMATERIAIS]

    G2 --> IMG1[IMAGENS ACERVO]
    G2 --> IMG2[IMAGENS INTERNET]
    G2 --> IMG3[IMAGENS IA]
    G2 --> IMG4[IMAGENS\nARQUITETURA]
    G2 --> IMG5[IMAGENS DIALUX]

    F3 --> IMG1
    F3 --> IMG2
    F3 --> IMG3
    F3 --> IMG4
    F3 --> IMG5

    F2 --> H1[VISITA EM OBRA]
    H1 --> H2[RELATÓRIO DE VISITA]

    G2 --> APR1[REVISÃO DE\nORÇAMENTO]
    APR1 --> AOR[APROVAÇÃO DO\nPROJETO E\nORÇAMENTO]
    F2 --> AOR

    AOR --> I[PROJETO APROVADO]
    I --> J[EMISSÃO PROJETO\nPRÉ EXECUTIVO]
    J --> J1[COMPATIBILIZAÇÃO DE\nPROJETO COM OUTRAS\nDISCIPLINAS]
    J --> J2[PROJETO AUTOCAD]
    J --> K[REUNIÃO PARA\nAPRESENTAR\nPROJETO PRÉ-\nEXECUTIVO]
    K --> K1[REVISAR\nAPRESENTAÇÃO]
    K --> K2[AGENDAR COM ARQ]
    K --> K3[AGENDAR COM\nCLIENTES]
    K --> K4[IMPRIMIR PROJETOS]
    K --> K5[GRAVAR ÁUDIO\nREUNIÃO]
    K --> K6[GERAR RELATÓRIO\nREUNIÃO]
    K --> L[ENVIO PARA ANÁLISE\nPOR E-MAIL]
    L --> M[PROJETO PRÉ\nEXECUTIVO APROVADO]

    M --> N1[VISITA EM OBRA]
    N1 --> N2[RELATÓRIO DE VISITA]
    M --> N3[COBRANÇA 2ª\nPARCELA CONTRATO]
    M --> N4[COMPATIBILIZAÇÃO DE\nPROJETO COM OUTRAS\nDISCIPLINAS]

    N4 --> O[EMISSÃO PROJETO\nEXECUTIVO]
    O --> O1[DETALHAMENTO\nPROJETO]
    O --> O2[EMISSÃO MEMORIAL\nDESCRITIVO]
    O --> O3[ORÇAMENTO]
    O --> O4[FICHAS TÉCNICAS]

    O --> P[REUNIÃO PARA\nAPRESENTAÇÃO\nPROJETO EXECUTIVO]
    P --> P1[APRESENTAÇÃO]
    P --> P2[AGENDAR COM ARQ]
    P --> P3[AGENDAR COM\nCLIENTES]
    P --> P4[IMPRIMIR PROJETOS]
    P --> P5[GRAVAR ÁUDIO\nREUNIÃO]
    P --> P6[GERAR RELATÓRIO\nREUNIÃO]

    P --> Q[REVISÃO PARA\nREDUZIR ORÇAMENTO]
    Q --> Q1[REVISÃO PROJETO\nDIALUX]
    Q --> Q2[REVISÃO PROJETO\nAUTOCAD]
    Q --> Q3[REVISÃO DE\nMATERIAIS NO\nORÇAMENTO]

    Q --> R[NOVA REUNIÃO PARA\nAPRESENTAÇÃO PROJETO\nEXECUTIVO]
    R --> R1[ENVIO POR E-MAIL]
    R --> S[PROJETO EXECUTIVO\nAPROVADO]
    R1 --> S

    S --> S1[COBRANÇA 3ª\nPARCELA DO\nCONTRATO]
    S --> T1[REVISÃO MEMORIAL\nDESCRITIVO]
    S --> T2[REVISÃO FICHAS\nTÉCNICAS]
    S --> T3[VISITA EM OBRA]
    T3 --> T4[RELATÓRIO DE VISITA]

    T1 --> U[ENVIO FINAL]
    T2 --> U
    T3 --> U
```

> Não foi possível confirmar com 100% de certeza a direção de algumas conexões na junção entre "APRESENTAÇÃO"/"PROJETO DIALUX" e o cluster de imagens (ACERVO/INTERNET/IA/ARQUITETURA/DIALUX) — ambos parecem alimentar o mesmo cluster.

## 3. Projeto Luminotécnico (faturamento)

Versão de faturamento/contrato — aparece como widget próprio no board, com nome igual ao processo acima mas fluxo bem mais curto (foco em nota/boleto/cobrança, não em elaboração de projeto). Aparece duplicada em duas áreas do board com conteúdo idêntico; documentada uma única vez aqui.

```mermaid
flowchart TD
    A[PROJETO LUMINOTECNICO] --> B["EQUIPE DE PROJETOS ENVIA:"]
    B --> C["CONTRATO DE PROJETO PARA ASSINATURA - DOCUSIGN"]
    C --> D["ASSINTURA FEITA"]
    D --> E["RECEBIMENTO CONTRATO APROVADO E ASSINADO"]
    E --> F["EMISSÃO DE NOTA DE SERVIÇO"]
    F --> G["FORMA DE PAGAMENTO:"]
    G --> G1["PAGAMENTO POR PIX"]
    G --> G2["EMISSÃO DE BOLETO"]
    G1 --> H["ENVIAR NOTA E BOLETO/PIX AOS CLIENTES E ENVOLVIDOS"]
    G2 --> H
    H --> I["IMPRESSÃO DE NOTA E BOLETO"]
    I --> J["ARQUIVAR DOCS"]
    J --> K1["BAIXA CONTAS A RECEBER"]
    J --> K2["LANÇAMENTO FINANCEIRO"]
    K1 --> L1["ETAPA ÚNICA?"]
    K2 --> L2["MAIS ETAPAS PARA RECEBER?"]
    L1 --> M1["PROCESSO FINALIZADO"]
    L2 --> M2["AGUARDAR ENTREGA DA PROXIMA ETAPA"]
    M2 --> M3["REPETIR PROCESSO"]
```
