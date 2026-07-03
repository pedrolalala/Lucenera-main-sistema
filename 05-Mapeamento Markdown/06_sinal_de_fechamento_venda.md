# Sinal de F. Venda

Fonte: board Miro "fluxograma Lucenera" (consolidado), widget "Sinal de F. Venda". Texto fiel ao board.

```mermaid
flowchart TD
    A1[SINAL DE F. VENDA] --> B1["EQUIPE DE PROJETOS\nENVIA:"]
    B1 --> C1["CONTRATO DE SINAL\nPARA ASSINATURA -\nDOCUSIGN"]
    C1 --> D1[ASSINATURA FEITA]
    D1 --> E1["RECEBIMENTO DO\nCONTRATO DE SINAL\nAPROVADO E\nASSINADO"]
    E1 --> F1[REGRA]
    F1 --> G1["AGUARDAR\nPAGAMENTO"]
    G1 --> H1["PAGAMENTO OK"]

    H1 --> I1["ENVIAR NOTA E\nBOLETO/PIX AOS\nCLIENTES E\nENVOLVIDOS"]
    I1 --> J1["IMPRESSÃO DE\nNOTA E BOLETO"]
    J1 --> K1["ARQUIVAR DOCS"]
    K1 --> L1["BAIXA CONTAS A\nRECEBER"]
    K1 --> L2["LANÇAMENTO\nFINANCEIRO"]
    L1 --> M1["ETAPA ÚNICA?"]
    L2 --> M2["MAIS ETAPAS PARA\nRECEBER?"]
    M1 --> N1["PROCESSO\nFINALIZADO"]
    M2 --> N2["AGUARDAR ENTREGA\nDA PROXIMA ETAPA"]
    N2 --> N3["REPETIR PROCESSO"]

    H1 --> O1["LANÇAR\nFINANCEIRO"]
    H1 --> O2["BAIXA CONTAS A\nRECEBER"]
    O1 --> P1["IMPRIMIR DOCS"]
    O2 --> P2["ARQUIVAR"]
    P1 --> Q1["PLANILHA CONTROLE\nINTERNO"]
    P2 --> Q1
    Q1 --> R1["PONTUAR CLUBE\nMAIS"]
    R1 --> S1["SITE CLUBE ATÉ\nDIA 05"]
    S1 --> T1["PARCELA UNICA"]
    T1 -->|SIM| U1["FINALIZADO"]
    T1 -->|NÃO| U2["REPETE"]
```

> Observações: há um nó parcialmente cortado nas capturas originais, ao lado de "AGUARDAR PAGAMENTO" (texto terminando em "...PIX/DADOS"), possivelmente um terceiro ramo de pagamento — não incluído por falta de confirmação visual completa. A ramificação exata entre "PAGAMENTO OK" e as duas colunas seguintes (envio direto de nota/boleto vs. lançamento financeiro/clube mais) pode ter um nó condicional intermediário não capturado (por analogia ao processo de Projeto Luminotécnico, que tem um nó explícito "FORMA DE PAGAMENTO:" nesse ponto).
