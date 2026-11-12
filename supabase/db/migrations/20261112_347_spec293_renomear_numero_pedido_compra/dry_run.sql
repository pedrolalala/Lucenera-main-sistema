-- Dry-run da 347 (SPEC-293): up.sql + testes; termina em ROLLBACK. Gerado do up.sql; se ele mudar, regerar (tests.sql + up.sql).
BEGIN;
-- sequencias nao voltam com ROLLBACK: guarda o valor de antes e devolve no fim
CREATE TEMP TABLE _seq0 AS SELECT last_value AS v, is_called AS c FROM public.pedidos_compra_numero_seq;
-- SPEC-293 (12/11/2026): Compras - editar o numero do pedido de compra (temporario), com auditoria e financeiro em dia.
-- A) RPC renomear_numero_pedido_compra(p_pedido, p_novo_numero, p_motivo) + pode_editar_numero_pedido_compra() (para a tela).
-- B) permissao em compras_config (tabela de uma linha so: duas colunas novas, nao ha chave/valor):
--    numero_pedido_editavel_por uuid[] (Debora) + administradores (public.usuarios.role); numero_pedido_edicao_ativa (liga/desliga o "temporario").
-- D) de/para em backup.spec293_renumeracao_pedidos_compra (uma linha por troca) + evento em auditoria com o motivo.
-- E) textos do financeiro ligados por id ao pedido: titulo do pedido (documento/descricao), parcelas previstas ("Previsao do pedido N (parcela k)"),
--    titulos de NF do pedido ("NF x (pedido N)"), pagamento_existente_vinculos.pedido_numero, pagamentos_antecipados.observacao (so se citar o numero).
--    financeiro_ponte_pedido monta os textos com pedidos_compra.numero ATUAL e o gatilho trg_fin_ponte_pedido nao reage a UPDATE de numero
--    (so status/cancelado_em/empresa_id/fornecedor_id): nada volta ao numero antigo.
-- H) pedidos_compra_numero_seq passa a continuar do maior numero que comeca por digitos (inclui "NNNN CONNECT"), uma vez, sem retroceder.
-- O indice unico pedidos_compra_numero_uniq (exato) continua; a RPC compara sem diferenciar caixa e sem espacos nas pontas.
-- Numero 347: a 346 e da SPEC-292 (outra sessao).

-- ===== B. configuracao =====
ALTER TABLE public.compras_config
  ADD COLUMN IF NOT EXISTS numero_pedido_editavel_por uuid[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS numero_pedido_edicao_ativa boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.compras_config.numero_pedido_editavel_por IS 'SPEC-293: usuarios (alem dos administradores) que podem editar o numero do pedido de compra.';
COMMENT ON COLUMN public.compras_config.numero_pedido_edicao_ativa IS 'SPEC-293: liga/desliga a edicao do numero do pedido (temporario). Desligada, ninguem edita.';

UPDATE public.compras_config
   SET numero_pedido_editavel_por = (SELECT coalesce(array_agg(u.id), '{}') FROM public.usuarios u WHERE u.email = 'debora@lucenera.com.br'),
       numero_pedido_edicao_ativa = true;

-- ===== D. de/para =====
CREATE SCHEMA IF NOT EXISTS backup;
CREATE TABLE IF NOT EXISTS backup.spec293_renumeracao_pedidos_compra (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  pedido_id     uuid NOT NULL,
  numero_antigo text NOT NULL,
  numero_novo   text NOT NULL,
  motivo        text NOT NULL,
  alterado_por  uuid,
  alterado_em   timestamptz NOT NULL DEFAULT now(),
  seq_antes     bigint
);
ALTER TABLE backup.spec293_renumeracao_pedidos_compra ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON backup.spec293_renumeracao_pedidos_compra FROM PUBLIC, anon, authenticated;

-- ===== H. sequencia (uma vez, nunca retrocede) =====
DO $$
DECLARE v_antes bigint; v_max bigint;
BEGIN
  SELECT last_value INTO v_antes FROM public.pedidos_compra_numero_seq;
  SELECT coalesce(max((substring(numero from '^[0-9]+'))::bigint), 0) INTO v_max
    FROM public.pedidos_compra
   WHERE numero ~ '^[0-9]+' AND numero NOT LIKE 'PC-LEGADO%' AND length(substring(numero from '^[0-9]+')) <= 9;
  IF v_max > v_antes THEN PERFORM setval('public.pedidos_compra_numero_seq', v_max, true); END IF;
  -- guarda o valor de antes para o rollback (linha marcador, sem pedido)
  INSERT INTO backup.spec293_renumeracao_pedidos_compra (pedido_id, numero_antigo, numero_novo, motivo, seq_antes)
  VALUES ('00000000-0000-0000-0000-000000000000', '(sequencia)', '(sequencia)', 'SPEC-293: ajuste da sequencia na migration', v_antes);
END $$;

-- ===== permissao =====
CREATE OR REPLACE FUNCTION public.pode_editar_numero_pedido_compra()
 RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $f$
DECLARE v_uid uuid := auth.uid(); v_cfg public.compras_config; v_role public.usuario_role;
BEGIN
  IF v_uid IS NULL THEN RETURN false; END IF;
  SELECT * INTO v_cfg FROM public.compras_config LIMIT 1;
  IF NOT FOUND OR v_cfg.numero_pedido_edicao_ativa IS DISTINCT FROM true THEN RETURN false; END IF;
  SELECT role INTO v_role FROM public.usuarios WHERE id = v_uid AND ativo IS NOT DISTINCT FROM true;
  IF v_role IS NULL THEN RETURN false; END IF;
  RETURN v_uid = ANY (v_cfg.numero_pedido_editavel_por) OR v_role IS NOT DISTINCT FROM 'admin'::public.usuario_role;
END $f$;
REVOKE ALL ON FUNCTION public.pode_editar_numero_pedido_compra() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_editar_numero_pedido_compra() TO authenticated;

-- ===== nucleo (sem checagem de permissao; so a RPC e o rollback chamam) =====
CREATE OR REPLACE FUNCTION public._pedido_compra_aplicar_numero(p_pedido uuid, p_novo text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $f$
DECLARE
  v_ant text;
BEGIN
  SELECT numero INTO v_ant FROM public.pedidos_compra WHERE id = p_pedido;
  IF v_ant IS NULL OR v_ant IS NOT DISTINCT FROM p_novo THEN RETURN; END IF;

  UPDATE public.pedidos_compra SET numero = p_novo WHERE id = p_pedido;

  -- titulo do pedido (origem pedido_compra): numero no documento e na descricao
  UPDATE public.financeiro_titulos t
     SET documento = CASE WHEN t.documento IS NOT DISTINCT FROM v_ant THEN p_novo ELSE t.documento END,
         descricao = CASE WHEN t.descricao IS NOT DISTINCT FROM ('Pedido de compra ' || v_ant) THEN 'Pedido de compra ' || p_novo ELSE t.descricao END
   WHERE t.pedido_compra_id = p_pedido AND t.origem_tipo = 'pedido_compra'
     AND (t.documento IS NOT DISTINCT FROM v_ant OR t.descricao IS NOT DISTINCT FROM ('Pedido de compra ' || v_ant));

  -- parcelas (previstas, substituidas, canceladas): "Previsao do pedido <n> (parcela k)"
  UPDATE public.financeiro_parcelas p
     SET observacao = 'Previsão do pedido ' || p_novo || substr(p.observacao, length('Previsão do pedido ' || v_ant) + 1)
    FROM public.financeiro_titulos t
   WHERE p.titulo_id = t.id AND t.pedido_compra_id = p_pedido AND t.origem_tipo = 'pedido_compra'
     AND left(p.observacao, length('Previsão do pedido ' || v_ant || ' (')) = 'Previsão do pedido ' || v_ant || ' (';

  -- titulos de NF do pedido: "NF x (pedido <n>)" (a nota aponta o pedido por id)
  UPDATE public.financeiro_titulos t
     SET descricao = replace(t.descricao, '(pedido ' || v_ant || ')', '(pedido ' || p_novo || ')')
    FROM public.notas_fiscais_compra n
   WHERE t.nota_fiscal_compra_id = n.id AND n.pedido_compra_id = p_pedido
     AND position('(pedido ' || v_ant || ')' IN t.descricao) > 0;

  -- rotulo gravado no vinculo de pagamento existente (SPEC-290)
  UPDATE public.pagamento_existente_vinculos v SET pedido_numero = p_novo
   WHERE v.pedido_compra_id = p_pedido AND v.pedido_numero IS DISTINCT FROM p_novo;

  -- adiantamento: so se a observacao citar o numero do pedido
  UPDATE public.pagamentos_antecipados a
     SET observacao = replace(a.observacao, '(pedido ' || v_ant || ')', '(pedido ' || p_novo || ')')
   WHERE a.pedido_compra_id = p_pedido AND position('(pedido ' || v_ant || ')' IN a.observacao) > 0;
END $f$;
REVOKE ALL ON FUNCTION public._pedido_compra_aplicar_numero(uuid, text) FROM PUBLIC, anon, authenticated;

-- ===== A. RPC =====
CREATE OR REPLACE FUNCTION public.renomear_numero_pedido_compra(p_pedido uuid, p_novo_numero text, p_motivo text)
 RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $f$
DECLARE
  v_uid uuid := auth.uid(); v_ant text; v_status text; v_novo text := btrim(coalesce(p_novo_numero, ''));
  v_motivo text := btrim(coalesce(p_motivo, '')); v_seq bigint;
BEGIN
  IF v_uid IS NULL OR NOT public.pode_editar_numero_pedido_compra() THEN
    RAISE EXCEPTION 'Voce nao tem permissao para editar o numero do pedido (ou a edicao esta desligada).' USING ERRCODE = '42501';
  END IF;
  IF v_novo = '' THEN RAISE EXCEPTION 'Informe o novo numero do pedido.' USING ERRCODE = '22023'; END IF;
  IF length(v_novo) > 40 THEN RAISE EXCEPTION 'O numero do pedido pode ter no maximo 40 caracteres.' USING ERRCODE = '22023'; END IF;
  IF v_motivo = '' THEN RAISE EXCEPTION 'Informe o motivo da troca do numero.' USING ERRCODE = '22023'; END IF;
  -- "PC-LEGADO-..." e a marca de pedido legado cancelado (financeiro_ponte_pedido ignora esses numeros): ninguem pode ser renomeado PARA ela
  IF upper(v_novo) LIKE 'PC-LEGADO%' THEN
    RAISE EXCEPTION 'O numero nao pode comecar com "PC-LEGADO": esse prefixo e reservado aos pedidos legados cancelados.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('pedidos_compra_numero'));
  SELECT numero, status::text INTO v_ant, v_status FROM public.pedidos_compra WHERE id = p_pedido FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pedido de compra nao encontrado.' USING ERRCODE = 'P0002'; END IF;
  -- pedido PC-LEGADO que nao esta cancelado: sair do prefixo faria o financeiro passar a trata-lo como pedido normal
  IF upper(v_ant) LIKE 'PC-LEGADO%' AND v_status IS DISTINCT FROM 'cancelado' THEN
    RAISE EXCEPTION 'O pedido % e legado e nao esta cancelado (status %): nao pode ser renomeado.', v_ant, v_status USING ERRCODE = '22023';
  END IF;
  IF v_novo IS NOT DISTINCT FROM v_ant THEN
    RAISE EXCEPTION 'O novo numero e igual ao atual.' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM public.pedidos_compra x WHERE x.id <> p_pedido AND lower(btrim(x.numero)) = lower(v_novo)) THEN
    RAISE EXCEPTION 'Ja existe um pedido com o numero "%".', v_novo USING ERRCODE = '23505';
  END IF;

  PERFORM public._pedido_compra_aplicar_numero(p_pedido, v_novo);

  -- numero puramente numerico (ate 9 digitos) maior que a sequencia: a sequencia acompanha, para o proximo pedido novo nao colidir. Nunca retrocede.
  IF v_novo ~ '^[0-9]{1,9}$' THEN
    SELECT last_value INTO v_seq FROM public.pedidos_compra_numero_seq;
    IF v_novo::bigint > v_seq THEN PERFORM setval('public.pedidos_compra_numero_seq', v_novo::bigint, true); END IF;
  END IF;

  INSERT INTO backup.spec293_renumeracao_pedidos_compra (pedido_id, numero_antigo, numero_novo, motivo, alterado_por)
  VALUES (p_pedido, v_ant, v_novo, v_motivo, v_uid);
  PERFORM auditoria.inserir(v_uid, auditoria.sistema_atual(), 'alterou', 'pedidos_compra', p_pedido::text, 'Pedido ' || v_novo,
         jsonb_build_object('numero', jsonb_build_array(v_ant, v_novo), 'motivo_troca_numero', v_motivo), NULL, NULL, NULL);
  RETURN v_novo;
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'Ja existe um pedido com o numero "%".', v_novo USING ERRCODE = '23505';
END $f$;
REVOKE ALL ON FUNCTION public.renomear_numero_pedido_compra(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renomear_numero_pedido_compra(uuid, text, text) TO authenticated;


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

SELECT setval('public.pedidos_compra_numero_seq', v, c) FROM _seq0;
ROLLBACK;
