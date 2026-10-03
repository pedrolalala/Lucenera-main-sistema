-- 03/10/2026 — análise de lentidão (pedido do usuário). As 51 políticas de RLS que
-- usam hub_pode_executar(auth.uid(), ...) chamavam a função (VOLATILE, plpgsql) para
-- CADA LINHA: em `produtos` (4.886 linhas) eram até 3 chamadas por linha, cada uma
-- lendo usuario_permissao_excecoes/usuario_papeis/papel_permissoes/systems — milhões de
-- seq scans nessas tabelas e 0,3–1 s por página de produtos.
--
-- Correção (padrão recomendado pela Supabase para RLS): a função passa a STABLE (só lê)
-- e cada chamada nas políticas vira (SELECT hub_pode_executar((SELECT auth.uid()), ...)),
-- avaliada UMA vez por consulta (InitPlan). Os argumentos são todos constantes — mesmo
-- resultado, sem depender da linha.
--
-- Dry-run (ROLLBACK) 03/10 como usuário real: 3 páginas de produtos 1.099 ms -> 26 ms,
-- boletos 19 ms -> 1 ms, mesmas linhas (1000/26); usuário sem permissão continua com 0.
-- rollback.sql nesta pasta restaura a função e o texto original das 51 políticas.
-- Sem BEGIN/COMMIT no texto.

ALTER FUNCTION public.hub_pode_executar(uuid, text, text, text) STABLE;

DO $$
DECLARE
  pol record;
  v_pat text := 'hub_pode_executar\(auth\.uid\(\), (''[^'']*''::text), (NULL::text|''[^'']*''::text), (''[^'']*''::text)\)';
  v_rep text := '(SELECT hub_pode_executar((SELECT auth.uid()), \1, \2, \3))';
BEGIN
  FOR pol IN
    SELECT p.polname, n.nspname, c.relname,
           pg_get_expr(p.polqual, p.polrelid) AS q,
           pg_get_expr(p.polwithcheck, p.polrelid) AS w
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE coalesce(pg_get_expr(p.polqual, p.polrelid), '') || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '')
          ~ 'hub_pode_executar\(auth\.uid\(\)'
  LOOP
    EXECUTE format('ALTER POLICY %I ON %I.%I', pol.polname, pol.nspname, pol.relname)
      || CASE WHEN pol.q IS NOT NULL THEN format(' USING (%s)', regexp_replace(pol.q, v_pat, v_rep, 'g')) ELSE '' END
      || CASE WHEN pol.w IS NOT NULL THEN format(' WITH CHECK (%s)', regexp_replace(pol.w, v_pat, v_rep, 'g')) ELSE '' END;
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
