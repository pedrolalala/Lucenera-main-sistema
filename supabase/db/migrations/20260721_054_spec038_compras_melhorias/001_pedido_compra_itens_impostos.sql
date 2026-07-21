-- Migration 20260721_054 - SPEC-038 Item 1
-- Custo e impostos separados por item de pedido de compra.
--
-- Decisao do usuario (P-01, 2026-07-21): ICMS + IPI + ST, Alternativa C
-- (hibrida) -- pre-preenche a partir de produtos.icms_entrada/ipi_entrada/
-- porc_st (via produto_fornecedores se existir override de custo, senao
-- produtos), mas grava o VALOR EFETIVO (editavel) por compra em
-- pedido_compra_itens, sem sincronizar de volta para produtos.
--
-- Nomenclatura por analogia com produtos.icms_entrada/ipi_entrada/porc_st
-- (01_schema_full.sql:5579-5593) e com a tabela legada
-- staging_conta_pagar.vl_ipi/vl_st (sem vl_icms).
--
-- Conferido contra supabase/db/migrations/20260710_031_spec020_operacionalizacao_compras/
-- 004_pedidos_compra.sql:58-68 (definicao real e atual de pedido_compra_itens)
-- antes de escrever este ALTER -- nenhuma coluna de imposto existe hoje.

ALTER TABLE public.pedido_compra_itens
  ADD COLUMN IF NOT EXISTS custo_liquido   numeric(12,4),  -- custo unitario antes de impostos
  ADD COLUMN IF NOT EXISTS valor_icms      numeric(12,4),  -- ICMS por unidade, efetivo da compra
  ADD COLUMN IF NOT EXISTS valor_ipi       numeric(12,4),  -- IPI por unidade, efetivo da compra
  ADD COLUMN IF NOT EXISTS valor_st        numeric(12,4);  -- ST por unidade, efetivo da compra

COMMENT ON COLUMN public.pedido_compra_itens.custo_liquido IS
'SPEC-038 (P-01). Custo unitario ANTES de impostos, efetivo desta compra
(editavel, pre-preenchido a partir de produtos.icms_entrada/ipi_entrada/
porc_st ou produto_fornecedores no frontend). custo_unitario (coluna ja
existente, NOT NULL) continua representando o custo TOTAL por unidade
(liquido + icms + ipi + st) -- convencao mantida para nao quebrar leitores
existentes de custo_unitario (ex: valor_total dos pedidos, recebimento).';

COMMENT ON COLUMN public.pedido_compra_itens.valor_icms IS
'SPEC-038 (P-01). Valor de ICMS por unidade, efetivo desta compra. Snapshot
da transacao -- nao sincroniza de volta para produtos.icms_entrada.';

COMMENT ON COLUMN public.pedido_compra_itens.valor_ipi IS
'SPEC-038 (P-01). Valor de IPI por unidade, efetivo desta compra. Snapshot
da transacao -- nao sincroniza de volta para produtos.ipi_entrada.';

COMMENT ON COLUMN public.pedido_compra_itens.valor_st IS
'SPEC-038 (P-01). Valor de substituicao tributaria (ST) por unidade, efetivo
desta compra. Snapshot da transacao -- nao sincroniza de volta para
produtos.porc_st.';

-- Nenhum GRANT/RLS novo necessario -- pedido_compra_itens ja tem policy de
-- SELECT authenticated; escrita segue via RPC SECURITY DEFINER (ver 002,
-- que recria criar_pedido_compra_de_necessidade/criar_pedido_compra_lote
-- com parametros novos para gravar estas 4 colunas).
