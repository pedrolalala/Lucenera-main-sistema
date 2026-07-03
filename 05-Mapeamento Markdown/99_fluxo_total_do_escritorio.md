# Fluxo Total do Escritório Lucenera

Visão integrada dos processos do board Miro "fluxograma Lucenera" (consolidado). Este é um resumo de alto nível das ligações entre processos — para o detalhe completo de cada caixa (incluindo ramificações, decisões e textos exatos), ver os arquivos `01` a `09`.

```mermaid
flowchart TD
    START["Entrada de demanda"] --> ORIGEM{"Origem"}

    ORIGEM -->|Projeto novo| ENTRADA["ENTRADA DE PROJETO"]
    ORIGEM -->|Venda direta/showroom| DIRETA["VENDA DIRETA"]
    ORIGEM -->|Fechamento com sinal| SINAL["SINAL DE F. VENDA"]
    ORIGEM -->|Troca/garantia| QUEIMOU["LUMINÁRIA QUEIMOU"]
    ORIGEM -->|Rotina interna| ADMIN["Administrativo, RH e financeiro"]

    subgraph SG_PROJETO["Entrada de Projeto (05)"]
        ENTRADA --> CADASTRO["CRIAR CADASTRO"]
        CADASTRO --> SHAREPOINT["PASTA NO SHARE POINT"]
        SHAREPOINT --> BRIEFING["REUNIÃO DE BIEFING"]
        BRIEFING --> DESENV["DESENVOLVER CONTRATO DE PROJETO\nOU CONTRATO DE SINAL"]
        BRIEFING --> VENDA_IMEDIATA["PROJETO PARA VENDA IMEDIATA"]
    end

    subgraph SG_CONTRATO["Ciclo de Contrato e Aprovação de Projeto (05)"]
        DESENV --> CONTRATO_PROJ["CONTRATO PROJETO"]
        CONTRATO_PROJ --> DOCUSIGN["PACOTE DOCUSIGN\nASSINATURA DIGITAL"]
        DOCUSIGN --> APRES1["1ª APRESENTAÇÃO DE PROJETO"]
        APRES1 --> PROJ_APROVADO["PROJETO APROVADO"]
        PROJ_APROVADO --> PRE_EXEC["EMISSÃO PROJETO PRÉ EXECUTIVO"]
        PRE_EXEC --> PRE_APROVADO["PROJETO PRÉ EXECUTIVO APROVADO"]
        PRE_APROVADO --> EXEC["EMISSÃO PROJETO EXECUTIVO"]
        EXEC --> EXEC_APROVADO["PROJETO EXECUTIVO APROVADO"]
        EXEC_APROVADO --> ENVIO_FINAL["ENVIO FINAL"]
    end

    subgraph SG_OBRA["Acompanhamento da Obra e Obra Finalizada (09)"]
        ENVIO_FINAL --> ACOMP["ACOMPANHAMENTO DA OBRA"]
        ACOMP --> VISITAS["VISITAS EM OBRA /\nRECEBIMENTO PROJETO PAISAGISMO/MARCENARIA"]
        VISITAS --> SEPARACAO["NECESSIDADE DE MATERIAL EM OBRA\n→ GERAR LISTA DE SEPARAÇÃO"]
        SEPARACAO --> MARCACAO["VISITA PARA MARCAR POSIÇÃO\nDAS LUMINÁRIAS"]
        MARCACAO --> REVITALIZA["VISITA PARA REVITALIZAÇÃO\nDO PROJETO"]
        REVITALIZA --> FINALIZADA["OBRA \"FINALIZADA\""]
        FINALIZADA --> APOS_TEMPO{"APÓS UM TEMPO"}
        FINALIZADA --> QUEIMOU
    end

    subgraph SG_TROCA["Troca/garantia (09)"]
        QUEIMOU --> LOCAL{"Cliente aparece no\nestoque ou showroom?"}
        LOCAL --> DISP{"Luminária disponível\nem estoque?"}
        DISP -->|Sim| RETIRA["Cliente retira/leva\nluminária nova"]
        DISP -->|Não| EMAIL_FIN["E-MAIL PARA FINANCEIRO\nPROVIDENCIAR NOVA LUMINÁRIA"]
        EMAIL_FIN --> AGUARDAR["AGUARDAR PRAZO DO PEDIDO\nDA NOVA LUMINÁRIA"]
        AGUARDAR --> RETIRA
    end

    subgraph SG_VENDA["Faturamento Lucenera (04, 06, 07)"]
        EXEC_APROVADO --> VENDA_FIN["VENDA FINALIZADA?\nINICIA-SE PROCESSO DE COMPRA"]
        DIRETA --> VENDA_FIN
        SINAL --> VENDA_FIN
        VENDA_FIN --> VP["VENDA PADRÃO - LUCENERA"]
        VENDA_FIN --> VA["VENDA PARA FICAR\nEM ABERTO"]
        VENDA_FIN --> DA["DEVOLUÇÃO PARA FICAR\nEM ABERTO"]
        VENDA_FIN --> AQ["AQUISIÇÃO + DEVOLUÇÃO"]
        VENDA_FIN --> OB["ORÇAMENTO DE BRINDE"]
    end

    subgraph SG_COMPRAS["Compras e estoque (04)"]
        VP --> PECA{"Peça especial ou\npadrão?"}
        PECA -->|Especial| INDUSTRIA["INDUSTRIALIZAÇÃO LUCENERA\n(Cláudio)"]
        PECA -->|Padrão| FORNECEDOR["FORNECEDOR PADRÃO"]
        INDUSTRIA --> ENTRADA_MAT["ENTRADA DO MATERIAL"]
        FORNECEDOR --> ENTRADA_MAT
        ENTRADA_MAT --> VINCULO["VINCULAR MATERIAL COM\nVENDAS DE CLIENTES"]
        VINCULO --> SEPARACAO_FISICA["START SEPARAÇÃO FISICA\nDO PRODUTO NO ESTOQUE"]
    end

    subgraph SG_ADMIN["Administrativo (01, 02, 03)"]
        ADMIN --> LANA["LANA:\nfinanceiro, bancos,\nfolha, contabilidade"]
        ADMIN --> CAROLINE["CAROLINE:\nfinanceiro, contabilidade,\nRH, suprimentos"]
        ADMIN --> DEBORA["DÉBORA:\ncompras, cadastro,\npeças especiais, produção"]
        VP -.-> CAROLINE
        VP -.-> LANA
        FORNECEDOR -.-> DEBORA
    end

    classDef decisao fill:#f2f2f2,stroke:#777777,color:#222222;
    class ORIGEM,APOS_TEMPO,LOCAL,DISP,PECA decisao;
```

> Este diagrama mostra apenas os nós de transição entre processos (não todas as ramificações internas). Para o detalhe completo e fiel de cada etapa — incluindo decisões, textos exatos e observações de ambiguidade — consulte os arquivos individuais listados em `00_indice_e_notas_de_leitura.md`.
