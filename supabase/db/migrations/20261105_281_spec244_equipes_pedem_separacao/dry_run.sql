-- Dry-run da 281: reproduz o erro da tela como Marina (funcionario), aplica a correção, repete o fluxo de criar separação e DESFAZ. Termina em ROLLBACK.
BEGIN;

CREATE TEMP TABLE _ctx (k text PRIMARY KEY, v text);
GRANT SELECT, INSERT, UPDATE ON _ctx TO authenticated;
INSERT INTO _ctx SELECT 'A', s.projeto_item_id::text FROM public.estoque_saldos_projeto_item s
  WHERE s.q_reserva >= 2 AND public.connect_item_liberado(s.projeto_item_id) ORDER BY s.projeto_item_id LIMIT 1;
INSERT INTO _ctx SELECT 'prod', produto_id::text FROM public.projeto_itens WHERE id = (SELECT v::uuid FROM _ctx WHERE k='A');
CREATE FUNCTION pg_temp.saldo(p uuid) RETURNS text LANGUAGE sql SECURITY DEFINER AS $f$
  SELECT 'res ' || q_reserva || ' ag ' || q_ag_separar FROM public.estoque_saldos_projeto_item WHERE projeto_item_id = p $f$;
GRANT EXECUTE ON FUNCTION pg_temp.saldo(uuid) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"438d37e0-ae72-4226-83c7-15d501a49dd4"}', true);

-- ANTES da correção: reproduz o erro da tela
DO $$
DECLARE sid uuid;
BEGIN
  INSERT INTO public.separacoes (numero_venda, cliente, responsavel_id, status) VALUES ('ENSAIO-1', 'ensaio', '438d37e0-ae72-4226-83c7-15d501a49dd4', 'Pendente') RETURNING id INTO sid;
  BEGIN
    INSERT INTO public.separacao_itens (separacao_id, projeto_item_id, produto_id, descricao, quantidade)
    VALUES (sid, (SELECT v::uuid FROM _ctx WHERE k='A'), (SELECT v::uuid FROM _ctx WHERE k='prod'), 'ensaio', 1);
    RAISE NOTICE 'ANTES: o insert em separacao_itens PASSOU (erro não reproduzido)';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ANTES: erro reproduzido: %', SQLERRM; END;
  BEGIN
    DELETE FROM public.separacoes WHERE id = sid;
    IF EXISTS (SELECT 1 FROM public.separacoes WHERE id = sid) THEN RAISE NOTICE 'ANTES: a limpeza não apagou (separação vazia fica na Logística)'; ELSE RAISE NOTICE 'ANTES: limpeza apagou'; END IF;
  END;
END $$;

RESET ROLE;
-- SPEC-244 (05/11): as equipes de projetos pedem a separação no sistema novo (Venda Parcial -> "Criar Separação").
-- ERRO ENCONTRADO: ao criar a separação a tela insere em `separacoes` (liberado por permissão do Hub: criar em separacao-parcial/logistica) e depois em
-- `separacao_itens`, cuja política de INSERT só aceitava usuario.role = admin/gerente/operador. Todas as equipes de projetos têm role `funcionario`
-- (não existe nenhum `operador`), então a segunda inserção falhava com "new row violates row-level security policy for table separacao_itens" e a
-- limpeza (`DELETE` em `separacoes`, que exige o 'deletar' do Hub) também falhava: ficavam separações vazias "material_solicitado" na Logística.
-- CORREÇÃO: a mesma regra de `separacoes` (permissão do Hub) passa a valer em `separacao_itens` (criar/editar), e quem criou uma separação VAZIA pode
-- desfazê-la (só a própria e só sem itens). Não mexe em quantidade, estoque nem saldo.

DROP POLICY IF EXISTS sep_itens_insert_hub ON public.separacao_itens;
CREATE POLICY sep_itens_insert_hub ON public.separacao_itens
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.hub_pode_executar((SELECT auth.uid()), 'separacao-parcial'::text, NULL::text, 'criar'::text))
              OR (SELECT public.hub_pode_executar((SELECT auth.uid()), 'logistica'::text, NULL::text, 'criar'::text)));

DROP POLICY IF EXISTS sep_itens_update_hub ON public.separacao_itens;
CREATE POLICY sep_itens_update_hub ON public.separacao_itens
  FOR UPDATE TO authenticated
  USING ((SELECT public.hub_pode_executar((SELECT auth.uid()), 'separacao-parcial'::text, NULL::text, 'editar'::text))
         OR (SELECT public.hub_pode_executar((SELECT auth.uid()), 'logistica'::text, NULL::text, 'editar'::text)))
  WITH CHECK ((SELECT public.hub_pode_executar((SELECT auth.uid()), 'separacao-parcial'::text, NULL::text, 'editar'::text))
              OR (SELECT public.hub_pode_executar((SELECT auth.uid()), 'logistica'::text, NULL::text, 'editar'::text)));

DROP POLICY IF EXISTS separacoes_delete_vazia_propria ON public.separacoes;
CREATE POLICY separacoes_delete_vazia_propria ON public.separacoes
  FOR DELETE TO authenticated
  USING (responsavel_id = (SELECT auth.uid())
         AND NOT EXISTS (SELECT 1 FROM public.separacao_itens i WHERE i.separacao_id = separacoes.id));

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"438d37e0-ae72-4226-83c7-15d501a49dd4"}', true);

DO $$
DECLARE sid uuid; a uuid := (SELECT v::uuid FROM _ctx WHERE k='A'); r jsonb; sid2 uuid;
BEGIN
  INSERT INTO public.separacoes (numero_venda, cliente, responsavel_id, status) VALUES ('ENSAIO-2', 'ensaio', '438d37e0-ae72-4226-83c7-15d501a49dd4', 'Pendente') RETURNING id INTO sid;
  INSERT INTO public.separacao_itens (separacao_id, projeto_item_id, produto_id, descricao, quantidade)
  VALUES (sid, a, (SELECT v::uuid FROM _ctx WHERE k='prod'), 'ensaio', 1);
  RAISE NOTICE 'DEPOIS: item inserido pela Marina (funcionario)';
  RAISE NOTICE 'saldo antes do RPC: %', pg_temp.saldo(a);
  r := public.registrar_separacao_setor(a, 1, sid, NULL);
  RAISE NOTICE 'DEPOIS: RPC ok, saldo %: %', pg_temp.saldo(a), r;
  -- separação com itens não pode ser apagada pela criadora
  DELETE FROM public.separacoes WHERE id = sid;
  RAISE NOTICE 'separação COM itens continua existindo após DELETE da Marina: %', EXISTS (SELECT 1 FROM public.separacoes WHERE id = sid);
  -- separação vazia própria pode ser desfeita
  INSERT INTO public.separacoes (numero_venda, cliente, responsavel_id, status) VALUES ('ENSAIO-3', 'ensaio', '438d37e0-ae72-4226-83c7-15d501a49dd4', 'Pendente') RETURNING id INTO sid2;
  DELETE FROM public.separacoes WHERE id = sid2;
  RAISE NOTICE 'separação vazia própria apagada: %', NOT EXISTS (SELECT 1 FROM public.separacoes WHERE id = sid2);
END $$;
RESET ROLE;
DO $$ BEGIN RAISE NOTICE 'estoque total: %', (SELECT sum(quantidade)::text || '/' || sum(quantidade_reservada)::text FROM public.estoque_itens); END $$;
ROLLBACK;
