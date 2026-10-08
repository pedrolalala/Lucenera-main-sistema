-- SPEC-188 (ajuste 08/10/2026):
-- 1) Férias gravada sem período aquisitivo não entrava no saldo (3 da Vitória, 08/10). Agora o
--    banco liga sozinho ao período mais antigo que ainda tem saldo (mesmo critério da planilha);
--    se nenhum tiver saldo, ao mais recente. Vale para qualquer tela/caminho de gravação.
-- 2) vw_ferias_periodos / vw_controle_ferias_clt ignoravam o RLS (dono postgres) — qualquer
--    usuário logado (e anon, na de saldo) lia o saldo de todos. Passam a security_invoker:
--    RH (admin/gerente) vê todos, funcionário vê só o próprio. Sem BEGIN/COMMIT no texto.

CREATE OR REPLACE FUNCTION public.ferias_definir_periodo()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.periodo_aquisitivo_id is null then
    select v.periodo_id into new.periodo_aquisitivo_id
      from vw_ferias_periodos v
     where v.funcionario_id = new.funcionario_id
     order by (v.saldo > 0) desc, v.data_inicio asc
     limit 1;
  end if;
  return new;
end;
$function$;

DROP TRIGGER IF EXISTS trg_ferias_definir_periodo ON public.ferias;
CREATE TRIGGER trg_ferias_definir_periodo
  BEFORE INSERT OR UPDATE ON public.ferias
  FOR EACH ROW EXECUTE FUNCTION public.ferias_definir_periodo();

-- liga as que já estão sem período (dispara o trigger acima)
UPDATE public.ferias SET periodo_aquisitivo_id = NULL WHERE periodo_aquisitivo_id IS NULL;

ALTER VIEW public.vw_ferias_periodos SET (security_invoker = true);
ALTER VIEW public.vw_controle_ferias_clt SET (security_invoker = true);
REVOKE ALL ON public.vw_controle_ferias_clt FROM anon;

NOTIFY pgrst, 'reload schema';
