-- SPEC-230: Orçamento mostrava preco_venda (custo × 2,5, legado) diferente do valor_venda da Connect (Consulta).
-- preco_venda passa a seguir valor_venda. Backup no schema backup.
BEGIN;

CREATE TABLE IF NOT EXISTS backup._bkp_spec230_produtos_preco_venda AS
  SELECT id, codigo_produto, preco_venda, valor_venda, now() AS copiado_em FROM public.produtos;

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
    -- SPEC-224: UPDATE que só mexe em estoque (movimentação de setor, entrada de nota) não recalcula o preço.
    -- tem_st/sku são colunas geradas: no BEFORE ainda vêm nulas no NEW, por isso ficam fora da comparação.
    IF TG_OP = 'UPDATE'
       AND (to_jsonb(NEW) - ARRAY['estoque_showroom', 'estoque_total', 'estoque_disponivel', 'updated_at', 'tem_st', 'sku'])
         = (to_jsonb(OLD) - ARRAY['estoque_showroom', 'estoque_total', 'estoque_disponivel', 'updated_at', 'tem_st', 'sku']) THEN
        RETURN NEW;
    END IF;

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

    -- 7. SPEC-230: o preço de venda é o da Connect (valor_venda, regra da SPEC-190). Sem valor_venda, fica a conta
    --    antiga (custo total × 2,5).
    IF coalesce(NEW.valor_venda, 0) > 0 THEN
        NEW.preco_venda := NEW.valor_venda;
    ELSE
        NEW.preco_venda := v_custo_total * 2.5;
    END IF;

    RETURN NEW;
END;
$function$;

UPDATE public.produtos
   SET preco_venda = valor_venda
 WHERE coalesce(valor_venda, 0) > 0
   AND preco_venda IS DISTINCT FROM valor_venda;

COMMIT;
