-- SPEC-240 C: desconto (%) que o fornecedor dá quando a compra fecha caixa (algumas peças só).
-- Campo de custo (SPEC-193): authenticated não lê direto de produtos; sai pela vw_produtos_custo (Administração).
-- Mesma trava de quem altera que Itens por caixa (Débora + administração, migration 260).
BEGIN;

ALTER TABLE public.produtos ADD COLUMN IF NOT EXISTS desconto_caixa_fechada numeric(5,2) NOT NULL DEFAULT 0;
ALTER TABLE public.produtos DROP CONSTRAINT IF EXISTS produtos_desconto_caixa_fechada_faixa;
ALTER TABLE public.produtos ADD CONSTRAINT produtos_desconto_caixa_fechada_faixa
  CHECK (desconto_caixa_fechada >= 0 AND desconto_caixa_fechada < 100);
COMMENT ON COLUMN public.produtos.desconto_caixa_fechada IS
  'SPEC-240: desconto % do fornecedor quando o pedido de compra fecha caixa (quantidade múltipla de multiplo_compra). '
  '0 = sem desconto. Campo de custo: ler pela vw_produtos_custo. Só a Débora e a administração alteram.';

-- Mesma lista de colunas da view atual + a nova no fim.
CREATE OR REPLACE VIEW public.vw_produtos_custo AS
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
    round(margem_lucro, 2)::numeric(9,2) AS percentual_lucro,
    desconto_caixa_fechada
   FROM produtos p
  WHERE ( SELECT pode_ver_custo_produto() AS pode_ver_custo_produto);

CREATE OR REPLACE FUNCTION public.trg_produtos_multiplo_compra_editor()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  IF (TG_OP = 'UPDATE' AND (NEW.multiplo_compra IS DISTINCT FROM OLD.multiplo_compra
                            OR NEW.desconto_caixa_fechada IS DISTINCT FROM OLD.desconto_caixa_fechada))
     OR (TG_OP = 'INSERT' AND (COALESCE(NEW.multiplo_compra, 1) <> 1 OR COALESCE(NEW.desconto_caixa_fechada, 0) <> 0)) THEN
    IF NOT public.pode_editar_caixa_fechada() THEN
      RAISE EXCEPTION 'Só a Débora e a administração podem alterar Itens por caixa e o desconto da caixa fechada.'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_produtos_multiplo_compra_editor ON public.produtos;
CREATE TRIGGER trg_produtos_multiplo_compra_editor
  BEFORE INSERT OR UPDATE OF multiplo_compra, desconto_caixa_fechada ON public.produtos
  FOR EACH ROW EXECUTE FUNCTION public.trg_produtos_multiplo_compra_editor();

COMMIT;
