
-- ================= TESTES (dentro da transacao; ROLLBACK no fim) =================
CREATE TEMP TABLE _t (k text, v text);
GRANT ALL ON _t TO authenticated, anon;

-- helper: executa como usuario (null = anon) e devolve a mensagem de erro (ou 'OK')
CREATE FUNCTION pg_temp.como(p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v_msg text;
BEGIN
  PERFORM set_config('request.jwt.claims', CASE WHEN p_uid IS NULL THEN '{"role":"anon"}' ELSE json_build_object('sub', p_uid, 'role', 'authenticated')::text END, true);
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  EXECUTE CASE WHEN p_uid IS NULL THEN 'SET LOCAL ROLE anon' ELSE 'SET LOCAL ROLE authenticated' END;
  BEGIN
    EXECUTE p_sql;
    v_msg := 'OK';
  EXCEPTION WHEN OTHERS THEN v_msg := 'ERRO: ' || SQLERRM;
  END;
  RESET ROLE;
  RETURN v_msg;
END $$;
GRANT EXECUTE ON FUNCTION pg_temp.como(uuid, text) TO PUBLIC;

DO $$
DECLARE
  deb uuid := '78c716d7-9ca2-4449-8ac6-50c1905d21ef';
  isa uuid := 'effab110-94ed-4278-b2b3-74f217e70805';
  adm uuid := (SELECT id FROM public.usuarios WHERE role = 'admin' AND ativo ORDER BY id LIMIT 1);
  p1930 uuid := '17c9cbbf-e825-4d1c-990c-bd5684477603';
  pleg uuid := '57fda4fa-5a42-4d99-8468-1ad2cff5959a';
  pnat uuid := (SELECT id FROM public.pedidos_compra WHERE numero = '1803');
  r text; n int; v_seq0 bigint; v_seq1 bigint; v_prox text; v_novo text; v_ped uuid;
BEGIN
  RAISE NOTICE 'config: %', (SELECT row(numero_pedido_editavel_por, numero_pedido_edicao_ativa) FROM public.compras_config);

  -- 1) sequencia ajustada, nao retrocede
  SELECT last_value INTO v_seq1 FROM public.pedidos_compra_numero_seq;
  SELECT seq_antes INTO v_seq0 FROM backup.spec293_renumeracao_pedidos_compra WHERE pedido_id = '00000000-0000-0000-0000-000000000000';
  RAISE NOTICE 'SEQ antes=% depois=%', v_seq0, v_seq1;
  IF v_seq1 < v_seq0 THEN RAISE EXCEPTION 'FALHA: sequencia retrocedeu'; END IF;
  IF v_seq1 < 1993 THEN RAISE EXCEPTION 'FALHA: sequencia nao cobre os numeros da Connect'; END IF;

  -- 2) permissao
  r := pg_temp.como(isa, format('SELECT public.renomear_numero_pedido_compra(%L, ''T-1'', ''teste'')', p1930));
  RAISE NOTICE 'sem permissao (Isabella): %', r; IF r NOT LIKE 'ERRO: Voce nao tem permissao%' THEN RAISE EXCEPTION 'FALHA'; END IF;
  r := pg_temp.como(NULL, format('SELECT public.renomear_numero_pedido_compra(%L, ''T-1'', ''teste'')', p1930));
  RAISE NOTICE 'anon: %', r; IF r NOT LIKE 'ERRO: permission denied%' THEN RAISE EXCEPTION 'FALHA'; END IF;
  r := pg_temp.como(NULL, 'SELECT public.pode_editar_numero_pedido_compra()');
  RAISE NOTICE 'anon pode_editar: %', r; IF r NOT LIKE 'ERRO: permission denied%' THEN RAISE EXCEPTION 'FALHA'; END IF;

  -- 3) validacoes (como Debora)
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, ''   '', ''m'')', p1930));
  RAISE NOTICE 'vazio: %', r; IF r NOT LIKE '%Informe o novo numero%' THEN RAISE EXCEPTION 'FALHA'; END IF;
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, NULL, ''m'')', p1930));
  IF r NOT LIKE '%Informe o novo numero%' THEN RAISE EXCEPTION 'FALHA null'; END IF;
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, ''T-1'', ''  '')', p1930));
  RAISE NOTICE 'sem motivo: %', r; IF r NOT LIKE '%Informe o motivo%' THEN RAISE EXCEPTION 'FALHA'; END IF;
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, ''T-1'', ''m'')', gen_random_uuid()));
  RAISE NOTICE 'inexistente: %', r; IF r NOT LIKE '%nao encontrado%' THEN RAISE EXCEPTION 'FALHA'; END IF;
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, ''  1803 '', ''m'')', p1930));
  RAISE NOTICE 'duplicado (espacos): %', r; IF r NOT LIKE '%Ja existe um pedido com o numero "1803"%' THEN RAISE EXCEPTION 'FALHA'; END IF;
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, ''1930 connect'', ''m'')', pnat));
  RAISE NOTICE 'duplicado (caixa): %', r; IF r NOT LIKE '%Ja existe%' THEN RAISE EXCEPTION 'FALHA'; END IF;

  -- 4) troca em pedido com NF e financeiro (1930 CONNECT), como Debora
  RAISE NOTICE 'ANTES titulos: %', (SELECT jsonb_agg(jsonb_build_array(documento, descricao)) FROM public.financeiro_titulos WHERE pedido_compra_id = p1930 OR nota_fiscal_compra_id IN (SELECT id FROM public.notas_fiscais_compra WHERE pedido_compra_id = p1930));
  r := pg_temp.como(deb, format('INSERT INTO _t SELECT ''novo'', public.renomear_numero_pedido_compra(%L, ''  1930-TESTE  '', ''Acerto da Debora'')', p1930));
  RAISE NOTICE 'troca 1930: %', r; IF r <> 'OK' THEN RAISE EXCEPTION 'FALHA troca'; END IF;
  IF (SELECT numero FROM public.pedidos_compra WHERE id = p1930) <> '1930-TESTE' THEN RAISE EXCEPTION 'FALHA: numero nao trocou/aparou'; END IF;
  SELECT count(*) INTO n FROM public.financeiro_titulos WHERE pedido_compra_id = p1930 AND documento <> '1930-TESTE';
  IF n > 0 THEN RAISE EXCEPTION 'FALHA: titulo com documento antigo'; END IF;
  SELECT count(*) INTO n FROM public.financeiro_titulos WHERE (pedido_compra_id = p1930 OR nota_fiscal_compra_id IN (SELECT id FROM public.notas_fiscais_compra WHERE pedido_compra_id = p1930)) AND descricao LIKE '%1930 CONNECT%';
  IF n > 0 THEN RAISE EXCEPTION 'FALHA: descricao antiga restante (%)', n; END IF;
  SELECT count(*) INTO n FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id WHERE t.pedido_compra_id = p1930 AND p.observacao LIKE '%1930 CONNECT%';
  IF n > 0 THEN RAISE EXCEPTION 'FALHA: parcela com observacao antiga'; END IF;
  RAISE NOTICE 'DEPOIS titulos: %', (SELECT jsonb_agg(jsonb_build_array(documento, descricao)) FROM public.financeiro_titulos WHERE pedido_compra_id = p1930 OR nota_fiscal_compra_id IN (SELECT id FROM public.notas_fiscais_compra WHERE pedido_compra_id = p1930));
  RAISE NOTICE 'DEPOIS parcelas: %', (SELECT jsonb_agg(DISTINCT p.observacao) FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id WHERE t.pedido_compra_id = p1930);
  IF (SELECT count(*) FROM backup.spec293_renumeracao_pedidos_compra WHERE pedido_id = p1930 AND numero_antigo = '1930 CONNECT' AND numero_novo = '1930-TESTE' AND motivo = 'Acerto da Debora' AND alterado_por = deb) <> 1 THEN
    RAISE EXCEPTION 'FALHA: de/para nao gravado'; END IF;
  RAISE NOTICE 'auditoria (eventos com motivo): %', (SELECT count(*) FROM auditoria.eventos WHERE entidade = 'pedidos_compra' AND registro_id = p1930::text AND mudancas ? 'motivo_troca_numero');

  -- 4b) a ponte do financeiro roda depois e nao reverte o texto
  PERFORM public.financeiro_ponte_pedido(p1930);
  UPDATE public.pedidos_compra SET status = status WHERE id = p1930;
  PERFORM public.financeiro_ponte_pedido(p1930);
  SELECT count(*) INTO n FROM public.financeiro_titulos WHERE pedido_compra_id = p1930 AND (documento LIKE '%1930 CONNECT%' OR descricao LIKE '%1930 CONNECT%');
  IF n > 0 THEN RAISE EXCEPTION 'FALHA: ponte reverteu o texto'; END IF;
  SELECT count(*) INTO n FROM public.financeiro_parcelas p JOIN public.financeiro_titulos t ON t.id = p.titulo_id WHERE t.pedido_compra_id = p1930 AND p.observacao LIKE '%1930 CONNECT%';
  IF n > 0 THEN RAISE EXCEPTION 'FALHA: ponte reverteu parcelas'; END IF;
  RAISE NOTICE 'ponte ok (nenhum texto antigo)';

  -- 5) PC-LEGADO (cancelado, sem financeiro)
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, ''1448'', ''Legado'')', pleg));
  RAISE NOTICE 'PC-LEGADO -> 1448: %', r; IF r <> 'OK' THEN RAISE EXCEPTION 'FALHA legado'; END IF;
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, ''1448'', ''Legado'')', pleg));
  IF r NOT LIKE '%igual ao atual%' THEN RAISE EXCEPTION 'FALHA igual'; END IF;

  -- 6) administrador (fora da lista) passa; chave desligada recusa a todos
  r := pg_temp.como(adm, format('SELECT public.renomear_numero_pedido_compra(%L, ''1448-A'', ''admin'')', pleg));
  RAISE NOTICE 'admin: %', r; IF r <> 'OK' THEN RAISE EXCEPTION 'FALHA admin'; END IF;
  UPDATE public.compras_config SET numero_pedido_edicao_ativa = false;
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, ''X-9'', ''m'')', pleg));
  RAISE NOTICE 'chave desligada (Debora): %', r; IF r NOT LIKE 'ERRO: Voce nao tem permissao%' THEN RAISE EXCEPTION 'FALHA'; END IF;
  r := pg_temp.como(adm, format('SELECT public.renomear_numero_pedido_compra(%L, ''X-9'', ''m'')', pleg));
  IF r NOT LIKE 'ERRO: Voce nao tem permissao%' THEN RAISE EXCEPTION 'FALHA admin desligado'; END IF;
  UPDATE public.compras_config SET numero_pedido_edicao_ativa = true;
  DELETE FROM _t; r := pg_temp.como(deb, 'INSERT INTO _t SELECT ''pode'', public.pode_editar_numero_pedido_compra()::text');
  RAISE NOTICE 'pode_editar (Debora, ligada): %', (SELECT v FROM _t WHERE k = 'pode');
  DELETE FROM _t; r := pg_temp.como(isa, 'INSERT INTO _t SELECT ''pode'', public.pode_editar_numero_pedido_compra()::text');
  RAISE NOTICE 'pode_editar (Isabella): %', (SELECT v FROM _t WHERE k = 'pode');

  -- 7) proximo pedido novo nao repete numero
  INSERT INTO public.pedidos_compra (status, empresa_id, fornecedor_id)
  SELECT 'aguardando_aprovar', empresa_id, fornecedor_id FROM public.pedidos_compra WHERE id = pnat
  RETURNING id, numero INTO v_ped, v_prox;
  RAISE NOTICE 'proximo numero gerado: % (seq=%)', v_prox, (SELECT last_value FROM public.pedidos_compra_numero_seq);
  IF v_prox !~ '^[0-9]+$' OR v_prox::bigint <= 1993 THEN RAISE EXCEPTION 'FALHA: numero gerado repete/abaixo da Connect'; END IF;

  -- 9) PC-LEGADO: destino reservado, legado nao cancelado, setval pela RPC
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, ''Pc-Legado-9'', ''m'')', pnat));
  RAISE NOTICE 'destino PC-LEGADO: %', r; IF r NOT LIKE '%reservado%' THEN RAISE EXCEPTION 'FALHA destino legado'; END IF;
  UPDATE public.pedidos_compra SET status = 'aprovado' WHERE id = pleg;
  UPDATE public.pedidos_compra SET numero = 'PC-LEGADO-1448' WHERE id = pleg;
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, ''1448-B'', ''m'')', pleg));
  RAISE NOTICE 'legado nao cancelado: %', r; IF r NOT LIKE '%legado e nao esta cancelado%' THEN RAISE EXCEPTION 'FALHA legado nao cancelado'; END IF;
  UPDATE public.pedidos_compra SET status = 'cancelado' WHERE id = pleg;
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, ''7000'', ''maior que a sequencia'')', pleg));
  IF r <> 'OK' THEN RAISE EXCEPTION 'FALHA 7000: %', r; END IF;
  SELECT last_value INTO v_seq1 FROM public.pedidos_compra_numero_seq;
  RAISE NOTICE 'seq apos renomear para 7000: %', v_seq1; IF v_seq1 < 7000 THEN RAISE EXCEPTION 'FALHA: sequencia nao acompanhou'; END IF;
  r := pg_temp.como(deb, format('SELECT public.renomear_numero_pedido_compra(%L, ''1500'', ''menor que a sequencia'')', pleg));
  IF r <> 'OK' THEN RAISE EXCEPTION 'FALHA 1500: %', r; END IF;
  IF (SELECT last_value FROM public.pedidos_compra_numero_seq) < 7000 THEN RAISE EXCEPTION 'FALHA: sequencia retrocedeu'; END IF;
  INSERT INTO public.pedidos_compra (status, empresa_id, fornecedor_id)
  SELECT 'aguardando_aprovar', empresa_id, fornecedor_id FROM public.pedidos_compra WHERE id = pnat
  RETURNING numero INTO v_prox;
  RAISE NOTICE 'pedido novo apos 7000: %', v_prox; IF v_prox <> '7001' THEN RAISE EXCEPTION 'FALHA: pedido novo %', v_prox; END IF;
  RAISE NOTICE 'eventos de auditoria por troca (1930): %', (SELECT count(*) FROM auditoria.eventos WHERE entidade = 'pedidos_compra' AND registro_id = p1930::text AND mudancas ? 'numero');

  RAISE NOTICE 'TODOS OS TESTES PASSARAM';
END $$;
