-- Rollback da 251 (SPEC-231 G1): tira o registro de movimentação e o relatório. Apaga o histórico gravado.
BEGIN;

DROP FUNCTION IF EXISTS public.relatorio_movimentacao_item(text, date, date, text);

DROP TRIGGER IF EXISTS kardex_estoque_itens ON public.estoque_itens;
DROP TRIGGER IF EXISTS kardex_showroom ON public.produtos;
DROP TRIGGER IF EXISTS kardex_resolver ON public.estoque_kardex;

DROP FUNCTION IF EXISTS public.trg_kardex_estoque_itens();
DROP FUNCTION IF EXISTS public.trg_kardex_showroom();
DROP FUNCTION IF EXISTS public.trg_kardex_resolver();
DROP FUNCTION IF EXISTS public.kardex_anotar(uuid, text, numeric, numeric);
DROP FUNCTION IF EXISTS public._kardex_num(text);

DROP TABLE IF EXISTS public.estoque_kardex;

COMMIT;
