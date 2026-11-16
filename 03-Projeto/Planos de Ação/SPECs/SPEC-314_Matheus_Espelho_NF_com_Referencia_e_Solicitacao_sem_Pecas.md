---
titulo: "SPEC-314 — Matheus: espelho da entrada de NF com referência e solicitação de separação sem peças"
status: concluida
data_ultima_modificacao: 2026-11-16
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee)
  - Logística (lucenera-logistics-b7cd1)
  - Banco (função espelho_entrada_nota_compra)
---

# SPEC-314 — Matheus: espelho da entrada de NF com referência e solicitação de separação sem peças

## Checklist de Ação

- [x] Pedido do Matheus (16/11): o espelho da entrada de NF (que a Débora lança e é entregue aos meninos da separação) precisa da **referência** para localizar a peça; ordem: código interno, referência, produto, quantidade. O valor não importa para ele.
- [x] Migration 375 APLICADA (função `espelho_entrada_nota_compra` devolve `referencia` por item; rollback.sql pronto).
- [x] Compras: PDF e janela do espelho mostram a referência; valor unitário saiu da linha dos itens (Financeiro continua no PDF). Commit efcca23, publicado em compras-lucenera.
- [x] Logística: solicitação de separação impressa não lista mais as peças. Commit 3ed0d74, publicado em logistica-lucenera.
- [ ] Teste do Matheus.
- [ ] Futuro (ele disse "depois"): resumo da entrada — quanto veio, quanto vinculou a clientes, quanto sobrou para estoque (hoje ele faz à mão).

## Regra

`referencia` = código do fornecedor (`produtos.referencia`). Agrupa por produto como antes.

## Rollback

`supabase/db/migrations/20261116_375_spec314_espelho_entrada_referencia/rollback.sql` e reverter os commits efcca23 (Compras) e 3ed0d74 (Logística).
