-- SPEC-188 (08/10/2026): controle de férias igual à planilha "CONTROLE DE FÉRIAS" da Lana.
--  * períodos aquisitivos reais (início, fim, vencimento, formalização, direito);
--  * lançamentos SEM data (recesso, venda, residual, casamento…) em tabela própria —
--    `ferias.dias` é GENERATED a partir das datas e não comporta esses casos;
--  * saldo por período = direito − férias aprovadas do período − lançamentos do período;
--  * saldo total = soma dos saldos; negativo de período ANTERIOR não conta (a planilha já
--    o leva como "Residual" no período seguinte), negativo do período mais recente conta;
--  * gerar_periodos_aquisitivos(): cria o próximo período quando o atual se completa
--    (pg_cron diário). Sem BEGIN/COMMIT no texto.

ALTER TABLE public.periodos_aquisitivos
  ADD COLUMN IF NOT EXISTS direito_dias integer NOT NULL DEFAULT 30,
  ADD COLUMN IF NOT EXISTS formalizacao text;

CREATE TABLE IF NOT EXISTS public.ferias_lancamentos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  funcionario_id uuid NOT NULL REFERENCES public.funcionarios(id) ON DELETE CASCADE,
  periodo_aquisitivo_id uuid NOT NULL REFERENCES public.periodos_aquisitivos(id) ON DELETE CASCADE,
  descricao text NOT NULL,
  dias integer NOT NULL,            -- positivo consome saldo; negativo devolve (ex.: "Sobra 2025")
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ferias_lancamentos_periodo ON public.ferias_lancamentos(periodo_aquisitivo_id);
ALTER TABLE public.ferias_lancamentos ENABLE ROW LEVEL SECURITY;
-- mesmas regras de ferias/periodos_aquisitivos: RH (admin/gerente) tudo; funcionário só lê o próprio
CREATE POLICY ferias_lanc_select ON public.ferias_lancamentos FOR SELECT TO authenticated
  USING ((get_user_role() = ANY (ARRAY['admin','gerente'])) OR (funcionario_id = get_my_funcionario_id()));
CREATE POLICY ferias_lanc_insert ON public.ferias_lancamentos FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = ANY (ARRAY['admin','gerente']));
CREATE POLICY ferias_lanc_update ON public.ferias_lancamentos FOR UPDATE TO authenticated
  USING (get_user_role() = ANY (ARRAY['admin','gerente']));
CREATE POLICY ferias_lanc_delete ON public.ferias_lancamentos FOR DELETE TO authenticated
  USING (get_user_role() = ANY (ARRAY['admin','gerente']));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ferias_lancamentos TO authenticated;

CREATE OR REPLACE VIEW public.vw_ferias_periodos AS
SELECT pa.id AS periodo_id,
       pa.funcionario_id,
       pa.data_inicio,
       pa.data_fim,
       pa.data_limite_gozo,
       pa.formalizacao,
       pa.direito_dias,
       (COALESCE((SELECT sum(f.dias) FROM ferias f
                   WHERE f.periodo_aquisitivo_id = pa.id AND f.status = 'Aprovado'), 0)
        + COALESCE((SELECT sum(l.dias) FROM ferias_lancamentos l
                   WHERE l.periodo_aquisitivo_id = pa.id), 0))::integer AS dias_usados,
       (pa.direito_dias
        - COALESCE((SELECT sum(f.dias) FROM ferias f
                     WHERE f.periodo_aquisitivo_id = pa.id AND f.status = 'Aprovado'), 0)
        - COALESCE((SELECT sum(l.dias) FROM ferias_lancamentos l
                     WHERE l.periodo_aquisitivo_id = pa.id), 0))::integer AS saldo,
       row_number() OVER (PARTITION BY pa.funcionario_id ORDER BY pa.data_inicio DESC)::integer AS ordem_recente
  FROM periodos_aquisitivos pa;
GRANT SELECT ON public.vw_ferias_periodos TO authenticated, service_role;

DROP VIEW IF EXISTS public.vw_controle_ferias_clt;
CREATE VIEW public.vw_controle_ferias_clt AS
WITH p AS (
  SELECT v.*, f.nome AS funcionario_nome
    FROM vw_ferias_periodos v
    JOIN funcionarios f ON f.id = v.funcionario_id
   WHERE f.status = 'Ativo'
), alvo AS (   -- período que vence primeiro entre os que ainda têm saldo (para o aviso "a vencer")
  SELECT DISTINCT ON (funcionario_id) funcionario_id, data_inicio, data_fim, data_limite_gozo
    FROM p
   ORDER BY funcionario_id, (saldo > 0) DESC, data_inicio ASC
)
SELECT p.funcionario_id,
       min(p.funcionario_nome) AS funcionario_nome,
       sum(p.direito_dias)::bigint AS direito_total_acumulado,
       sum(p.dias_usados)::bigint AS total_gozado,
       sum(CASE WHEN p.ordem_recente = 1 THEN p.saldo ELSE greatest(p.saldo, 0) END)::bigint AS saldo_disponivel,
       min(a.data_inicio) AS periodo_inicio,
       min(a.data_fim) AS periodo_fim,
       min(a.data_limite_gozo) AS data_limite_gozo
  FROM p
  JOIN alvo a ON a.funcionario_id = p.funcionario_id
 GROUP BY p.funcionario_id;
GRANT ALL ON public.vw_controle_ferias_clt TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.gerar_periodos_aquisitivos()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r record; v_ini date; v_fim date; v_ult date; n int := 0;
begin
  for r in
    select f.id, f.data_admissao,
           (select max(pa.data_fim) from periodos_aquisitivos pa where pa.funcionario_id = f.id) as ult_fim
      from funcionarios f
     where f.status = 'Ativo'
       and coalesce(f.tipo_contratacao, 'CLT') <> 'PJ'
       and f.data_admissao between date '1950-01-01' and current_date
  loop
    if r.ult_fim is null then
      -- sem histórico: só o período completo mais recente (não reconstrói anos sem registro)
      if date_part('year', age(current_date, r.data_admissao)) >= 1 then
        v_ini := (r.data_admissao + make_interval(years => date_part('year', age(current_date, r.data_admissao))::int - 1))::date;
        v_fim := (v_ini + interval '1 year' - interval '1 day')::date;
        insert into periodos_aquisitivos (funcionario_id, data_inicio, data_fim, data_limite_gozo, status, formalizacao)
        values (r.id, v_ini, v_fim, (v_fim + interval '11 months')::date, 'Ativo', 'PENDENTE');
        n := n + 1;
      end if;
    else
      v_ult := r.ult_fim;
      loop
        v_ini := v_ult + 1;
        v_fim := (v_ini + interval '1 year' - interval '1 day')::date;
        exit when v_fim >= current_date;   -- só período já completo
        insert into periodos_aquisitivos (funcionario_id, data_inicio, data_fim, data_limite_gozo, status, formalizacao)
        values (r.id, v_ini, v_fim, (v_fim + interval '11 months')::date, 'Ativo', 'PENDENTE');
        n := n + 1; v_ult := v_fim;
      end loop;
    end if;
  end loop;
  return n;
end;
$function$;
REVOKE ALL ON FUNCTION public.gerar_periodos_aquisitivos() FROM anon, authenticated;

SELECT cron.schedule('ferias-gerar-periodos', '0 6 * * *', $$select public.gerar_periodos_aquisitivos()$$);

NOTIFY pgrst, 'reload schema';
