-- SPEC-206 fase 2 (19/10/2026):
--  1) public.auditoria_registrar_tela: cada sistema avisa a tela aberta (src/lib/registro-tela.ts nos 17
--     sistemas). Ignora a mesma tela da mesma pessoa em menos de 1 minuto. A primeira tela depois de um
--     login preenche o sistema do login, que o Auth do Supabase não informa.
--  2) public.auditoria_registrar_acao: para gravações feitas por Edge Function com service role, que não têm
--     usuário (ex.: criar projeto pelo CRM via salvar-projeto). A tela chama depois de salvar.
--  3) Aprovação pelo cliente no link público (anon, sem usuário) passa a ser registrada em orcamentos como
--     "Cliente (link de aprovação)".
--  4) Listagem pode esconder as telas abertas; resumo por pessoa ganha "telas abertas".
BEGIN;

-- inserir() ganha o nome explícito (para o cliente do link). DROP antes: CREATE OR REPLACE com parâmetro
-- novo criaria uma segunda versão da função.
DROP FUNCTION IF EXISTS auditoria.inserir(uuid, text, text, text, text, text, jsonb, text, text);
CREATE FUNCTION auditoria.inserir(
  p_usuario uuid, p_sistema text, p_tipo text, p_entidade text, p_registro text, p_referencia text, p_mudancas jsonb,
  p_ip text DEFAULT NULL, p_navegador text DEFAULT NULL, p_nome text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  h jsonb := auditoria.cabecalhos();
BEGIN
  INSERT INTO auditoria.eventos (usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, mudancas, ip, navegador)
  VALUES (p_usuario, coalesce(p_nome, auditoria.nome_usuario(p_usuario)), p_sistema, p_tipo, p_entidade, p_registro,
          p_referencia, p_mudancas,
          coalesce(p_ip, h->>'cf-connecting-ip', nullif(split_part(h->>'x-forwarded-for', ',', 1), '')),
          coalesce(p_navegador, h->>'user-agent'));
END $$;

CREATE OR REPLACE FUNCTION auditoria.fn_registrar()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_nome text;
  v_old jsonb;
  v_new jsonb;
  v_r jsonb;
  v_mud jsonb := '{}'::jsonb;
  v_tipo text;
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
    ELSE
      RETURN NULL;
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

  PERFORM auditoria.inserir(
    v_uid, auditoria.sistema_atual(), v_tipo, TG_TABLE_NAME,
    coalesce(v_r->>'id', v_r->>'usuario_id', v_r->>'user_id'),
    auditoria.referencia(TG_TABLE_NAME, v_r), v_mud, NULL, NULL, v_nome);
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'auditoria.fn_registrar (%): %', TG_TABLE_NAME, SQLERRM;
  RETURN NULL;
END $$;

-- ---------------------------------------------------------------- telas abertas
CREATE OR REPLACE FUNCTION public.auditoria_registrar_tela(p_rota text, p_titulo text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sis text;
  v_rota text := left(coalesce(nullif(trim(p_rota), ''), '/'), 300);
BEGIN
  IF v_uid IS NULL THEN RETURN; END IF;
  v_sis := auditoria.sistema_atual();

  -- O login não sabe de qual sistema veio: a primeira tela aberta logo depois dele diz.
  UPDATE auditoria.eventos e SET sistema = v_sis
   WHERE e.id = (SELECT l.id FROM auditoria.eventos l
                  WHERE l.usuario_id = v_uid AND l.tipo = 'login' AND l.sistema IS NULL
                    AND l.criado_em > now() - interval '5 minutes'
                  ORDER BY l.id DESC LIMIT 1);

  IF EXISTS (SELECT 1 FROM auditoria.eventos e
              WHERE e.usuario_id = v_uid AND e.tipo = 'abriu_tela' AND e.sistema IS NOT DISTINCT FROM v_sis
                AND e.referencia = v_rota AND e.criado_em > now() - interval '1 minute') THEN
    RETURN;
  END IF;

  PERFORM auditoria.inserir(v_uid, v_sis, 'abriu_tela', 'tela', NULL, v_rota,
    CASE WHEN nullif(trim(p_titulo), '') IS NULL THEN NULL ELSE jsonb_build_object('titulo', left(p_titulo, 200)) END);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'auditoria_registrar_tela: %', SQLERRM;
END $$;

-- ---------------------------------------------------------------- ação feita por Edge Function
CREATE OR REPLACE FUNCTION public.auditoria_registrar_acao(p_tipo text, p_entidade text, p_registro_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_r jsonb;
BEGIN
  IF v_uid IS NULL OR p_registro_id IS NULL THEN RETURN; END IF;
  IF p_tipo NOT IN ('criou', 'alterou', 'aprovou', 'mudou_status') THEN RETURN; END IF;
  IF p_entidade NOT IN ('orcamentos','vendas','notas_fiscais','boletos','projetos','contatos','separacoes',
                        'entregas','cotacoes_compra','pedidos_compra','producao_pedidos','garantia_itens',
                        'garantia_protocolos','produtos','fornecedores','funcionarios') THEN
    RETURN;
  END IF;
  EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE t.id = $1', p_entidade) INTO v_r USING p_registro_id;
  IF v_r IS NULL THEN RETURN; END IF;
  PERFORM auditoria.inserir(v_uid, auditoria.sistema_atual(), p_tipo, p_entidade, p_registro_id::text,
    auditoria.referencia(p_entidade, v_r), CASE WHEN p_tipo = 'criou' THEN auditoria.limpar(v_r) END);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'auditoria_registrar_acao: %', SQLERRM;
END $$;

REVOKE ALL ON FUNCTION public.auditoria_registrar_tela(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.auditoria_registrar_acao(text, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.auditoria_registrar_tela(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auditoria_registrar_acao(text, text, uuid) TO authenticated;

-- ---------------------------------------------------------------- leitura: esconder telas / contar telas
DROP FUNCTION IF EXISTS public.auditoria_listar(timestamptz, timestamptz, text, uuid, text, text, int, int);
CREATE FUNCTION public.auditoria_listar(
  p_de timestamptz DEFAULT now() - interval '7 days',
  p_ate timestamptz DEFAULT now(),
  p_sistema text DEFAULT NULL,
  p_usuario uuid DEFAULT NULL,
  p_tipo text DEFAULT NULL,
  p_busca text DEFAULT NULL,
  p_limite int DEFAULT 100,
  p_offset int DEFAULT 0,
  p_incluir_telas boolean DEFAULT true)
RETURNS TABLE (id bigint, criado_em timestamptz, usuario_id uuid, usuario_nome text, sistema text, tipo text,
               entidade text, registro_id text, referencia text, mudancas jsonb, ip text, navegador text, total bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT coalesce(public.is_admin(), false) THEN
    RAISE EXCEPTION 'Apenas administradores veem a movimentação.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT e.id, e.criado_em, e.usuario_id, e.usuario_nome, e.sistema, e.tipo, e.entidade, e.registro_id,
         e.referencia, e.mudancas, e.ip, e.navegador, count(*) OVER () AS total
    FROM auditoria.eventos e
   WHERE e.criado_em >= p_de AND e.criado_em <= p_ate
     AND (p_sistema IS NULL OR e.sistema = p_sistema)
     AND (p_usuario IS NULL OR e.usuario_id = p_usuario)
     AND (p_tipo IS NULL OR e.tipo = p_tipo)
     AND (coalesce(p_incluir_telas, true) OR p_tipo = 'abriu_tela' OR e.tipo <> 'abriu_tela')
     AND (nullif(trim(p_busca), '') IS NULL
          OR e.referencia ILIKE '%' || trim(p_busca) || '%'
          OR e.usuario_nome ILIKE '%' || trim(p_busca) || '%')
   ORDER BY e.criado_em DESC, e.id DESC
   LIMIT least(greatest(coalesce(p_limite, 100), 1), 500) OFFSET greatest(coalesce(p_offset, 0), 0);
END $$;

DROP FUNCTION IF EXISTS public.auditoria_resumo_usuarios(timestamptz, timestamptz);
CREATE FUNCTION public.auditoria_resumo_usuarios(
  p_de timestamptz DEFAULT now() - interval '7 days',
  p_ate timestamptz DEFAULT now())
RETURNS TABLE (usuario_id uuid, nome text, email text, ativo boolean, papel text,
               ultimo_login timestamptz, logins_hoje bigint, logins_periodo bigint, dias_com_login bigint,
               acoes_periodo bigint, telas_periodo bigint, sistemas text[], senha_padrao boolean,
               ultima_troca_senha timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_hoje timestamptz := date_trunc('day', now() AT TIME ZONE 'America/Sao_Paulo') AT TIME ZONE 'America/Sao_Paulo';
BEGIN
  IF NOT coalesce(public.is_admin(), false) THEN
    RAISE EXCEPTION 'Apenas administradores veem a movimentação.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT u.id, u.nome, u.email, u.ativo, u.role::text,
         greatest(au.last_sign_in_at, (SELECT max(e.criado_em) FROM auditoria.eventos e WHERE e.usuario_id = u.id AND e.tipo = 'login')),
         (SELECT count(*) FROM auditoria.eventos e WHERE e.usuario_id = u.id AND e.tipo = 'login' AND e.criado_em >= v_hoje),
         (SELECT count(*) FROM auditoria.eventos e WHERE e.usuario_id = u.id AND e.tipo = 'login' AND e.criado_em BETWEEN p_de AND p_ate),
         (SELECT count(DISTINCT (e.criado_em AT TIME ZONE 'America/Sao_Paulo')::date) FROM auditoria.eventos e
           WHERE e.usuario_id = u.id AND e.tipo = 'login' AND e.criado_em BETWEEN p_de AND p_ate),
         (SELECT count(*) FROM auditoria.eventos e WHERE e.usuario_id = u.id
             AND e.tipo NOT IN ('login', 'senha_alterada', 'abriu_tela') AND e.criado_em BETWEEN p_de AND p_ate),
         (SELECT count(*) FROM auditoria.eventos e WHERE e.usuario_id = u.id AND e.tipo = 'abriu_tela'
             AND e.criado_em BETWEEN p_de AND p_ate),
         (SELECT array_agg(x.sistema ORDER BY x.qtd DESC) FROM (
             SELECT e.sistema, count(*) AS qtd FROM auditoria.eventos e
              WHERE e.usuario_id = u.id AND e.sistema IS NOT NULL AND e.sistema NOT IN ('automacao', 'local')
                AND e.criado_em BETWEEN p_de AND p_ate
              GROUP BY 1 ORDER BY 2 DESC LIMIT 3) x),
         auditoria.usa_senha_padrao(au.encrypted_password),
         (SELECT max(e.criado_em) FROM auditoria.eventos e WHERE e.usuario_id = u.id AND e.tipo = 'senha_alterada')
    FROM public.usuarios u
    JOIN auth.users au ON au.id = u.id
   ORDER BY u.ativo DESC NULLS LAST, u.nome;
END $$;

REVOKE ALL ON FUNCTION public.auditoria_listar(timestamptz, timestamptz, text, uuid, text, text, int, int, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.auditoria_resumo_usuarios(timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.auditoria_listar(timestamptz, timestamptz, text, uuid, text, text, int, int, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auditoria_resumo_usuarios(timestamptz, timestamptz) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
