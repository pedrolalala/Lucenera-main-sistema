-- Rollback SPEC-224 (migration 236). Sem BEGIN/COMMIT.
-- Os saldos movidos NAO voltam sozinhos: use movimentacoes_peca (antes de apagar) para desfazer movimento a movimento.

DELETE FROM public.systems WHERE slug = 'movimentacao-pecas';
DROP FUNCTION IF EXISTS public.movimentar_peca_setor(uuid, text, text, numeric, text);
DROP FUNCTION IF EXISTS public.movimentar_peca_venda(uuid, text, numeric, text);
DROP FUNCTION IF EXISTS public.movimentacao_buscar_pecas(text);
DROP FUNCTION IF EXISTS public.movimentacao_peca_setores(uuid);
DROP FUNCTION IF EXISTS public.movimentacao_listar(uuid, uuid, text, text, date, date, integer);
DROP FUNCTION IF EXISTS public.movimentacao_usuarios();
DROP FUNCTION IF EXISTS public._mov_saldo(uuid, text);
DROP FUNCTION IF EXISTS public._mov_livre_estoque_geral(uuid);
DROP FUNCTION IF EXISTS public._mov_local(text);
DROP FUNCTION IF EXISTS public._mov_pode();
DROP TABLE IF EXISTS public.movimentacoes_peca;

CREATE OR REPLACE FUNCTION public.fn_atualizar_preco_venda()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_valor_liquido    NUMERIC;
    v_valor_st         NUMERIC;
    v_valor_ipi        NUMERIC;
    v_valor_despesas   NUMERIC;
    v_bdi_total        NUMERIC;
    v_custo_total      NUMERIC;
BEGIN
    -- 1. Valor Líquido = preço de custo menos desconto percentual
    v_valor_liquido := NEW.preco_custo - (NEW.preco_custo * (COALESCE(NEW.porc_desconto, 0) / 100));

    -- 2. Valor ST sobre Valor Líquido
    v_valor_st := v_valor_liquido * (COALESCE(NEW.icms_entrada, 0) / 100);

    -- 3. Valor IPI sobre Valor Líquido
    v_valor_ipi := v_valor_liquido * (COALESCE(NEW.ipi_entrada, 0) / 100);

    -- 4. Valor Despesas sobre Valor Líquido (porc_frete é propositalmente ignorado)
    v_valor_despesas := v_valor_liquido * (COALESCE(NEW.porc_despesas, 0) / 100);

    -- 5. BDI Total
    v_bdi_total := v_valor_st + v_valor_ipi + v_valor_despesas;

    -- 6. Custo Total
    v_custo_total := v_valor_liquido + v_bdi_total;

    -- 7. Preço de Venda com margem de 150% (multiplica por 2.5)
    NEW.preco_venda := v_custo_total * 2.5;

    RETURN NEW;
END;
$function$
;
