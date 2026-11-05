-- Dry-run da 289: aplica e prova (1) SQL direto vira evento com o comando, (2) chave de serviço, cron e app.origem=script NÃO viram, (3) usuário do sistema continua normal. DESFAZ. Termina em ROLLBACK.
BEGIN;

CREATE OR REPLACE FUNCTION auditoria.fn_registrar()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_nome text;
  v_old jsonb;
  v_new jsonb;
  v_r jsonb;
  v_mud jsonb := '{}'::jsonb;
  v_tipo text;
  v_sql text;
  k text;
  v_ign text[] := ARRAY['updated_at','atualizado_em','created_at','criado_em','sync_hash','last_synced_at',
                        'last_sync_source','last_synced_by','alterado_em','ultima_consulta_em','tentativa_atual',
                        'payload_enviado','token_aprovacao_cliente','estoque_total','estoque_disponivel',
                        'estoque_showroom','quantidade_disponivel'];
  v_sens text[] := ARRAY['preco_custo','custo_total','margem_lucro','porc_frete','porc_despesas','porc_bdi','porc_st',
                         'porc_desconto','icms_entrada','ipi_entrada','vl_custo_indireto','percentual_desconto_compra',
                         'banco','agencia','conta','chave_pix'];
BEGIN
  IF v_uid IS NULL THEN
    -- Sem usuário só entra o cliente aprovando/recusando pelo link público (PostgREST como anon).
    -- Importações, scripts e Edge Functions com service role continuam fora.
    IF TG_TABLE_NAME = 'orcamentos'
       AND coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'role', '') = 'anon' THEN
      v_nome := 'Cliente (link de aprovação)';
    ELSIF coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'role', '') = 'service_role'
       OR coalesce(current_setting('app.origem', true), '') = 'script'
       OR coalesce(current_setting('application_name', true), '') LIKE 'pg_cron%' THEN
      -- automações (Edge Functions/importações com chave de serviço), tarefas do cron e scripts que se declaram `app.origem = script` seguem fora do log
      RETURN NULL;
    ELSE
      -- SPEC-246: SQL DIRETO (editor SQL do painel, cliente de banco, qualquer papel sem usuário do sistema) passa a ser registrado, com o comando executado
      v_nome := 'SQL direto (' || session_user || coalesce(' / ' || nullif(current_setting('application_name', true), ''), '') || ')';
      v_sql := left(current_query(), 1000);
    END IF;
  END IF;

  IF TG_OP <> 'INSERT' THEN v_old := to_jsonb(OLD); END IF;
  IF TG_OP <> 'DELETE' THEN v_new := to_jsonb(NEW); END IF;
  v_r := coalesce(v_new, v_old);

  IF TG_OP = 'UPDATE' THEN
    FOR k IN SELECT jsonb_object_keys(v_new) LOOP
      CONTINUE WHEN k = ANY (v_ign);
      IF (v_new->k) IS DISTINCT FROM (v_old->k) THEN
        v_mud := v_mud || jsonb_build_object(k,
          CASE WHEN k = ANY (v_sens) THEN '["***","***"]'::jsonb ELSE jsonb_build_array(v_old->k, v_new->k) END);
      END IF;
    END LOOP;
    IF v_mud = '{}'::jsonb THEN RETURN NULL; END IF;

    v_tipo := 'alterou';
    IF v_mud ? 'status' THEN
      v_tipo := CASE WHEN (v_new->>'status') ILIKE 'aprovad%' THEN 'aprovou' ELSE 'mudou_status' END;
    END IF;
    IF EXISTS (SELECT 1 FROM jsonb_each(v_mud) e
                WHERE e.key IN ('aprovado_em', 'aprovado_cliente_em') AND e.value->>0 IS NULL AND e.value->>1 IS NOT NULL) THEN
      v_tipo := 'aprovou';
    END IF;
  ELSIF TG_OP = 'INSERT' THEN
    v_tipo := 'criou';
    v_mud := auditoria.limpar(v_new);
  ELSE
    v_tipo := 'apagou';
    v_mud := auditoria.limpar(v_old);
  END IF;

  IF v_sql IS NOT NULL THEN
    v_mud := coalesce(v_mud, '{}'::jsonb) || jsonb_build_object('_sql_direto', v_sql, '_ip_origem', coalesce(inet_client_addr()::text, ''));
  END IF;
  PERFORM auditoria.inserir(
    v_uid, auditoria.sistema_atual(), v_tipo, TG_TABLE_NAME,
    coalesce(v_r->>'id', v_r->>'usuario_id', v_r->>'user_id'),
    auditoria.referencia(TG_TABLE_NAME, v_r), v_mud, NULL, NULL, v_nome);
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'auditoria.fn_registrar (%): %', TG_TABLE_NAME, SQLERRM;
  RETURN NULL;
END $function$
;


DO $$
DECLARE tx uuid; u uuid; n0 bigint; n1 bigint; r record;
BEGIN
  SELECT id INTO tx FROM public.transacoes WHERE status_pago = 0 AND tipo::text = 'despesa' ORDER BY dt_vencimento LIMIT 1;
  SELECT id INTO u FROM public.usuarios WHERE nome = 'Filippo' AND role::text = 'admin' LIMIT 1;

  -- 1) SQL direto (sem claims, sem app.origem)
  SELECT count(*) INTO n0 FROM auditoria.eventos;
  PERFORM set_config('app.origem', '', true);
  UPDATE public.transacoes SET vl_desconto = 7.77 WHERE id = tx;
  SELECT count(*) INTO n1 FROM auditoria.eventos;
  RAISE NOTICE '1) SQL direto gerou % evento(s) (esperado 1)', n1 - n0;
  FOR r IN SELECT usuario_nome, tipo, entidade, referencia, mudancas->>'vl_desconto' d, left(mudancas->>'_sql_direto', 90) q FROM auditoria.eventos ORDER BY id DESC LIMIT 1 LOOP
    RAISE NOTICE '   % | % | % | % | desconto % | comando: %', r.usuario_nome, r.tipo, r.entidade, r.referencia, r.d, r.q;
  END LOOP;

  -- 2) script que se declara
  PERFORM set_config('app.origem', 'script', true);
  SELECT count(*) INTO n0 FROM auditoria.eventos;
  UPDATE public.transacoes SET vl_desconto = 8.88 WHERE id = tx;
  SELECT count(*) INTO n1 FROM auditoria.eventos;
  RAISE NOTICE '2) app.origem=script gerou % evento(s) (esperado 0)', n1 - n0;
  PERFORM set_config('app.origem', '', true);

  -- 3) chave de serviço (Edge Functions / importações)
  PERFORM set_config('request.jwt.claims', '{"role":"service_role"}', true);
  SELECT count(*) INTO n0 FROM auditoria.eventos;
  UPDATE public.transacoes SET vl_desconto = 9.99 WHERE id = tx;
  SELECT count(*) INTO n1 FROM auditoria.eventos;
  RAISE NOTICE '3) service_role gerou % evento(s) (esperado 0)', n1 - n0;

  -- 4) usuário do sistema (Filippo logado): comportamento normal, sem marca de SQL direto
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u::text, 'role', 'authenticated')::text, true);
  SELECT count(*) INTO n0 FROM auditoria.eventos;
  SET LOCAL ROLE authenticated;
  UPDATE public.transacoes SET vl_desconto = 1.11 WHERE id = tx;
  RESET ROLE;
  SELECT count(*) INTO n1 FROM auditoria.eventos;
  FOR r IN SELECT usuario_nome, mudancas ? '_sql_direto' AS direto FROM auditoria.eventos ORDER BY id DESC LIMIT 1 LOOP
    RAISE NOTICE '4) usuário do sistema gerou % evento(s) | nome % | marcado como SQL direto: % (esperado 1 | Filippo | false)', n1 - n0, r.usuario_nome, r.direto;
  END LOOP;
END $$;
ROLLBACK;
