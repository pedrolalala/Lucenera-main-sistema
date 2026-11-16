-- SPEC-295 (13/11/2026): quem lanca Garantia / Uso e Consumo / Descarte (Matheus) efetiva sem esperar o financeiro.
-- Mantem a passagem por "Aprovacao Financeira" (SPEC-279): so troca QUEM pode clicar a aprovacao, e SO nos tipos sem cobranca
-- (natureza outros/sac, exceto EMPRESTIMO — que ja e barrado dentro da funcao). Venda normal continua exigindo 'orcamentos' aprovar.
-- Chave propria (acesso sem card, igual a financeiro-rt-comissao da SPEC-269): papel por sistema vale para todos com Orcamentos 'editar'.
BEGIN;

INSERT INTO public.systems (name, description, link, icon_name, display_order, slug, visivel_no_hub)
SELECT 'Orcamentos - Efetivar sem cobranca',
       'SPEC-295: pode aprovar na Revisao Financeira Garantia, Uso e Consumo, Descarte e demais Outros/SAC sem cobranca. Chave de permissao, sem card no Hub.',
       'https://financeiro-lucenera.pages.dev/', 'Lock', 99, 'orcamentos-efetivar-sem-cobranca', false
WHERE NOT EXISTS (SELECT 1 FROM public.systems WHERE slug = 'orcamentos-efetivar-sem-cobranca');

INSERT INTO public.user_system_access (user_id, system_id)
SELECT u.id, s.id FROM public.usuarios u JOIN public.systems s ON s.slug = 'orcamentos-efetivar-sem-cobranca'
 WHERE lower(u.email) = 'matheus@lucenera.com.br'
ON CONFLICT (user_id, system_id) DO NOTHING;

DO $$
DECLARE v_def text; v_novo text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'aprovar_orcamento_financeiro';
  v_novo := replace(v_def,
    $a$AND NOT public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'aprovar') THEN$a$,
    $b$AND NOT public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'aprovar')
     AND NOT (public.pode_acessar_sistema('orcamentos-efetivar-sem-cobranca')
              AND EXISTS (SELECT 1 FROM public.orcamentos o0 WHERE o0.id = p_orcamento_id
                           AND o0.natureza_operacao IN ('outros', 'sac') AND coalesce(o0.subgrupo, '') <> 'EMPRESTIMO')) THEN$b$);
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-295: trava de aprovar nao encontrada em aprovar_orcamento_financeiro'; END IF;
  EXECUTE v_novo;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
