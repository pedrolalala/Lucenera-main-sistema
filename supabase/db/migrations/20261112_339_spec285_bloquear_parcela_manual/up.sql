-- SPEC-285: parcela de venda só nasce do orçamento aprovado. Pelas telas (usuário logado) fica proibido criar,
-- alterar ou excluir parcela SEM orçamento em projeto_parcelas (editor manual do CRM). Parcela manual ia só para
-- o financeiro antigo (a ponte para o novo exige orcamento_id): não aparecia em Contas a Receber/Fluxo Futuro nem
-- gerava RT. Não afeta parcelas com orçamento, service_role nem o administrador no banco.
BEGIN;

CREATE OR REPLACE FUNCTION public.bloquear_parcela_manual()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public' AS $$
BEGIN
  IF COALESCE(auth.role(), '') <> 'authenticated' THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  IF (TG_OP = 'INSERT' AND NEW.orcamento_id IS NULL)
     OR (TG_OP IN ('UPDATE', 'DELETE') AND OLD.orcamento_id IS NULL) THEN
    RAISE EXCEPTION 'Parcelas de venda nascem do orçamento aprovado (SPEC-285). Para registrar uma venda, use o Orçamentos.'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

REVOKE ALL ON FUNCTION public.bloquear_parcela_manual() FROM PUBLIC, anon;

DROP TRIGGER IF EXISTS trg_bloquear_parcela_manual ON public.projeto_parcelas;
CREATE TRIGGER trg_bloquear_parcela_manual
  BEFORE INSERT OR UPDATE OR DELETE ON public.projeto_parcelas
  FOR EACH ROW EXECUTE FUNCTION public.bloquear_parcela_manual();

COMMENT ON TRIGGER trg_bloquear_parcela_manual ON public.projeto_parcelas IS
  'SPEC-285 (12/11/2026): pelas telas, parcela sem orçamento não pode ser criada, alterada nem excluída.';

COMMIT;
