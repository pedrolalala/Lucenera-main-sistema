-- SPEC-249 chamado 1: dry-run (ROLLBACK). Uso: psql "$SUPABASE_DB_URL" -X -f dry_run.sql (de dentro da pasta)
\set ON_ERROR_STOP on
BEGIN;
SELECT (SELECT count(*) FROM orcamentos) orc, (SELECT sum(quantidade) FROM estoque_itens) estoque, (SELECT count(*) FROM transacoes) trans, (SELECT count(*) FROM estoque_saldos_projeto_item) saldos \gset antes_
\ir up.sql
SELECT 'equipe da Moara' k, (SELECT equipes FROM equipes_projetos WHERE id = f.equipe_id) v FROM funcionarios f WHERE nm_connect = 'MOARA'
UNION ALL SELECT 'orcamentos da Moara por equipe: ' || coalesce(eq.equipes, '(sem)'), count(*)::text FROM orcamentos o LEFT JOIN equipes_projetos eq ON eq.id = o.equipe_id WHERE o.origem = 'connect' AND o.vendedor_id = (SELECT id FROM funcionarios WHERE nm_connect = 'MOARA') GROUP BY eq.equipes;
\echo '--- Marina enxerga? (nao) / Thairine enxerga? (sim)'
SELECT set_config('request.jwt.claims', json_build_object('sub', (SELECT usuario_id FROM funcionarios WHERE nome ilike 'Thairine%' LIMIT 1), 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
SELECT count(*) AS thairine_ve_vendas_da_moara FROM vw_venda_parcial_lista WHERE origem = 'connect' AND vendedor_nome ilike 'Moara%';
RESET ROLE;
SELECT (SELECT count(*) FROM orcamentos) = :antes_orc AS orcamentos_iguais, (SELECT sum(quantidade) FROM estoque_itens) = :antes_estoque AS estoque_igual, (SELECT count(*) FROM transacoes) = :antes_trans AS financeiro_igual, (SELECT count(*) FROM estoque_saldos_projeto_item) = :antes_saldos AS saldos_iguais;
ROLLBACK;
