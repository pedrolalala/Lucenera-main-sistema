BEGIN;

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

    -- 7. Preço de Venda com margem de 150% (multiplica por 2.5)
    NEW.preco_venda := v_custo_total * 2.5;

    RETURN NEW;
END;
$function$;

-- volta o preco_venda de antes (o trigger recalcula no UPDATE; por isso desliga só durante a restauração)
ALTER TABLE public.produtos DISABLE TRIGGER trg_calculo_preco_venda;
ALTER TABLE public.produtos DISABLE TRIGGER trg_atualizar_preco_venda;
UPDATE public.produtos p SET preco_venda = b.preco_venda
  FROM backup._bkp_spec230_produtos_preco_venda b
 WHERE b.id = p.id AND p.preco_venda IS DISTINCT FROM b.preco_venda;
ALTER TABLE public.produtos ENABLE TRIGGER trg_calculo_preco_venda;
ALTER TABLE public.produtos ENABLE TRIGGER trg_atualizar_preco_venda;

COMMIT;
