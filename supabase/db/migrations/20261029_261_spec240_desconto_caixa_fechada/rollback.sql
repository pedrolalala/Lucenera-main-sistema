-- Rollback da 261 (SPEC-240 C): volta a view e o gatilho da 260 e tira a coluna (perde os descontos gravados).
BEGIN;

DROP VIEW public.vw_produtos_custo;
CREATE VIEW public.vw_produtos_custo AS
 SELECT id,
    preco_custo,
    porc_desconto,
    percentual_desconto_compra,
    porc_frete,
    porc_st,
    ipi_entrada,
    icms_entrada,
    porc_despesas,
    porc_bdi,
    vl_custo_indireto,
    custo_total,
    margem_lucro,
    round(margem_lucro, 2)::numeric(9,2) AS percentual_lucro
   FROM produtos p
  WHERE ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto);
GRANT ALL ON public.vw_produtos_custo TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.trg_produtos_multiplo_compra_editor()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  IF (TG_OP = 'UPDATE' AND NEW.multiplo_compra IS DISTINCT FROM OLD.multiplo_compra)
     OR (TG_OP = 'INSERT' AND COALESCE(NEW.multiplo_compra, 1) <> 1) THEN
    IF NOT public.pode_editar_caixa_fechada() THEN
      RAISE EXCEPTION 'Só a Débora e a administração podem alterar Itens por caixa.'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_produtos_multiplo_compra_editor ON public.produtos;
CREATE TRIGGER trg_produtos_multiplo_compra_editor
  BEFORE INSERT OR UPDATE OF multiplo_compra ON public.produtos
  FOR EACH ROW EXECUTE FUNCTION public.trg_produtos_multiplo_compra_editor();

ALTER TABLE public.produtos DROP COLUMN IF EXISTS desconto_caixa_fechada;
COMMIT;
