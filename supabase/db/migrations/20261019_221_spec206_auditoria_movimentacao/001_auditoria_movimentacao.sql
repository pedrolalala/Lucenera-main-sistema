-- SPEC-206 (19/10/2026): Movimentação de todos os sistemas na Central (Administração › Movimentação).
-- Registro único em auditoria.eventos. O schema fica fora do public (pedido do usuário: o chefe olha o Supabase).
-- Só grava ação de pessoa logada (auth.uid() preenchido). Importações da Connect, sync do SharePoint e
-- scripts rodam sem usuário e ficam de fora. O sistema de origem vem do cabeçalho Origin da requisição
-- (cruzado com public.systems.link), então os 16 sistemas não precisam mudar.
-- Leitura só por RPC, só admin. Retenção de 12 meses (pg_cron).
BEGIN;

CREATE SCHEMA IF NOT EXISTS auditoria;
REVOKE ALL ON SCHEMA auditoria FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS auditoria.eventos (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  criado_em    timestamptz NOT NULL DEFAULT now(),
  usuario_id   uuid,
  usuario_nome text,
  sistema      text,
  tipo         text NOT NULL,          -- login, senha_alterada, criou, alterou, apagou, aprovou, mudou_status
  entidade     text,                   -- tabela
  registro_id  text,
  referencia   text,                   -- texto legível: "Orçamento ORC-0012", "Projeto 26.319 ..."
  mudancas     jsonb,                  -- UPDATE: {campo: [antes, depois]}; INSERT/DELETE: o registro sem nulos
  ip           text,
  navegador    text
);
CREATE INDEX IF NOT EXISTS eventos_criado_em_idx ON auditoria.eventos (criado_em DESC);
CREATE INDEX IF NOT EXISTS eventos_usuario_idx ON auditoria.eventos (usuario_id, criado_em DESC);
CREATE INDEX IF NOT EXISTS eventos_sistema_idx ON auditoria.eventos (sistema, criado_em DESC);
CREATE INDEX IF NOT EXISTS eventos_tipo_idx ON auditoria.eventos (tipo, criado_em DESC);
REVOKE ALL ON auditoria.eventos FROM PUBLIC, anon, authenticated;

-- Senha padrão das contas novas (SPEC-187). Fica aqui, fora do código das funções (pg_proc é legível
-- por qualquer usuário logado).
CREATE TABLE IF NOT EXISTS auditoria.config (chave text PRIMARY KEY, valor text NOT NULL);
REVOKE ALL ON auditoria.config FROM PUBLIC, anon, authenticated;
INSERT INTO auditoria.config (chave, valor) VALUES ('senha_padrao', 'Lucenera2026!')
ON CONFLICT (chave) DO NOTHING;

-- ---------------------------------------------------------------- utilitários
CREATE OR REPLACE FUNCTION auditoria.cabecalhos()
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path = '' AS $$
BEGIN
  RETURN nullif(current_setting('request.headers', true), '')::jsonb;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION auditoria.sistema_atual()
RETURNS text LANGUAGE plpgsql STABLE SET search_path = '' AS $$
DECLARE
  h jsonb := auditoria.cabecalhos();
  o text;
  host text;
  s text;
BEGIN
  o := coalesce(h->>'origin', h->>'referer');
  IF o IS NULL OR o = '' THEN RETURN 'automacao'; END IF;
  host := lower(substring(o FROM '^[a-zA-Z]+://([^/:]+)'));
  IF host IS NULL THEN RETURN 'automacao'; END IF;
  IF host IN ('localhost', '127.0.0.1') THEN RETURN 'local'; END IF;
  SELECT sy.slug INTO s FROM public.systems sy
   WHERE lower(sy.link) LIKE '%://' || host || '%' ORDER BY sy.display_order LIMIT 1;
  RETURN coalesce(s, regexp_replace(split_part(host, '.', 1), '-lucenera$', ''));
END $$;

CREATE OR REPLACE FUNCTION auditoria.limpar(j jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT coalesce(jsonb_object_agg(e.key,
           CASE WHEN e.key = ANY (ARRAY['preco_custo','custo_total','margem_lucro','porc_frete','porc_despesas',
                  'porc_bdi','porc_st','porc_desconto','icms_entrada','ipi_entrada','vl_custo_indireto',
                  'percentual_desconto_compra','banco','agencia','conta','chave_pix'])
                THEN '"***"'::jsonb ELSE e.value END), '{}'::jsonb)
  FROM jsonb_each(jsonb_strip_nulls(j)) e
  WHERE e.key <> ALL (ARRAY['updated_at','atualizado_em','created_at','criado_em','sync_hash','last_synced_at',
          'last_sync_source','last_synced_by','token_aprovacao_cliente','payload_enviado'])
$$;

CREATE OR REPLACE FUNCTION auditoria.nome_usuario(p_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT coalesce(nullif(u.nome, ''), u.email) FROM public.usuarios u WHERE u.id = p_id
$$;

CREATE OR REPLACE FUNCTION auditoria.referencia(p_tabela text, r jsonb)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_proj text;
BEGIN
  IF r ? 'projeto_id' AND nullif(r->>'projeto_id', '') IS NOT NULL THEN
    SELECT concat_ws(' ', p.codigo, p.nome) INTO v_proj FROM public.projetos p WHERE p.id = (r->>'projeto_id')::uuid;
  END IF;
  RETURN CASE p_tabela
    WHEN 'orcamentos'          THEN concat_ws(' ', 'Orçamento', coalesce(r->>'numero', '(sem número)'))
    WHEN 'projetos'            THEN concat_ws(' ', 'Projeto', r->>'codigo', r->>'nome')
    WHEN 'contatos'            THEN concat_ws(' ', initcap(coalesce(r->>'tipo', 'contato')), r->>'nome')
    WHEN 'vendas'              THEN concat_ws(' ', 'Venda', r->>'cod_venda', r->>'nome_cliente')
    WHEN 'notas_fiscais'       THEN concat_ws(' ', 'NF', coalesce(r->>'numero_nf', '(sem número)'), r->>'nome_destinatario')
    WHEN 'boletos'             THEN concat_ws(' ', 'Boleto', coalesce(r->>'numero_documento', r->>'nosso_numero'), r->>'nome_pagador')
    WHEN 'projeto_arquitetos'  THEN concat_ws(' ', 'Arquiteto do projeto', v_proj,
                                     (SELECT '— ' || c.nome FROM public.contatos c WHERE c.id = (r->>'arquiteto_id')::uuid))
    WHEN 'projeto_parcelas'    THEN concat_ws(' ', 'Parcela', r->>'numero_parcela', 'do projeto', v_proj)
    WHEN 'separacoes'          THEN concat_ws(' ', 'Separação', coalesce(r->>'numero_venda', r->>'codigo_obra'), r->>'cliente')
    WHEN 'estoque_itens'       THEN concat_ws(' ', 'Estoque',
                                     (SELECT concat_ws(' ', pr.codigo_produto, pr.nome) FROM public.produtos pr WHERE pr.id = (r->>'produto_id')::uuid),
                                     '· ' || (r->>'local'))
    WHEN 'devolucoes_estoque'  THEN 'Devolução de estoque'
    WHEN 'entregas'            THEN concat_ws(' ', 'Entrega', v_proj)
    WHEN 'cotacoes_compra'     THEN concat_ws(' ', 'Cotação', r->>'numero')
    WHEN 'pedidos_compra'      THEN concat_ws(' ', 'Pedido de compra', r->>'numero')
    WHEN 'producao_pedidos'    THEN concat_ws(' ', 'Pedido de produção', r->>'numero_pedido', r->>'cliente_nome')
    WHEN 'garantia_itens'      THEN concat_ws(' ', 'Garantia', coalesce(r->>'cliente_nome', r->>'produto_descricao_livre'))
    WHEN 'garantia_protocolos' THEN concat_ws(' ', 'Protocolo de garantia', r->>'responsavel_nome')
    WHEN 'produtos'            THEN concat_ws(' ', 'Peça', r->>'codigo_produto', r->>'nome')
    WHEN 'fornecedores'        THEN concat_ws(' ', 'Fornecedor', r->>'nome')
    WHEN 'funcionarios'        THEN concat_ws(' ', 'Funcionário', r->>'nome')
    WHEN 'usuarios'            THEN concat_ws(' ', 'Usuário', coalesce(r->>'nome', r->>'email'))
    WHEN 'usuario_papeis'      THEN concat_ws(' ', 'Papel', (SELECT pa.nome FROM public.papeis pa WHERE pa.id = (r->>'papel_id')::uuid),
                                     'de', auditoria.nome_usuario((r->>'usuario_id')::uuid))
    WHEN 'user_system_access'  THEN concat_ws(' ', 'Acesso de', auditoria.nome_usuario((r->>'user_id')::uuid), 'ao',
                                     (SELECT sy.name FROM public.systems sy WHERE sy.id = (r->>'system_id')::uuid))
    ELSE p_tabela
  END;
EXCEPTION WHEN OTHERS THEN
  RETURN p_tabela;
END $$;

CREATE OR REPLACE FUNCTION auditoria.inserir(
  p_usuario uuid, p_sistema text, p_tipo text, p_entidade text, p_registro text, p_referencia text, p_mudancas jsonb,
  p_ip text DEFAULT NULL, p_navegador text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  h jsonb := auditoria.cabecalhos();
BEGIN
  INSERT INTO auditoria.eventos (usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, mudancas, ip, navegador)
  VALUES (p_usuario, auditoria.nome_usuario(p_usuario), p_sistema, p_tipo, p_entidade, p_registro, p_referencia, p_mudancas,
          coalesce(p_ip, h->>'cf-connecting-ip', nullif(split_part(h->>'x-forwarded-for', ',', 1), '')),
          coalesce(p_navegador, h->>'user-agent'));
END $$;

-- ---------------------------------------------------------------- trigger genérico (por linha)
CREATE OR REPLACE FUNCTION auditoria.fn_registrar()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid();
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
  -- Só ação de pessoa logada. Importações e scripts (sem usuário) não entram.
  IF v_uid IS NULL THEN RETURN NULL; END IF;

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
    auditoria.referencia(TG_TABLE_NAME, v_r), v_mud);
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  -- O registro nunca pode impedir o salvamento.
  RAISE WARNING 'auditoria.fn_registrar (%): %', TG_TABLE_NAME, SQLERRM;
  RETURN NULL;
END $$;

-- ---------------------------------------------------------------- itens de orçamento (1 evento por orçamento)
-- Salvar um orçamento regrava dezenas de itens; aqui vira "N itens incluídos/alterados/removidos" no orçamento.
CREATE OR REPLACE FUNCTION auditoria.fn_registrar_itens_orcamento()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sis text;
  rec record;
  v_chave text;
BEGIN
  IF v_uid IS NULL THEN RETURN NULL; END IF;
  v_sis := auditoria.sistema_atual();
  v_chave := CASE TG_OP WHEN 'INSERT' THEN 'itens_incluidos' WHEN 'DELETE' THEN 'itens_removidos' ELSE 'itens_alterados' END;

  IF TG_OP = 'INSERT' THEN
    FOR rec IN SELECT n.orcamento_id, count(*) AS qtd FROM novos n GROUP BY 1 LOOP
      PERFORM auditoria.inserir(v_uid, v_sis, 'alterou', 'orcamento_itens', rec.orcamento_id::text,
        (SELECT concat_ws(' ', 'Orçamento', o.numero, '— itens') FROM public.orcamentos o WHERE o.id = rec.orcamento_id),
        jsonb_build_object(v_chave, rec.qtd));
    END LOOP;
  ELSIF TG_OP = 'DELETE' THEN
    FOR rec IN SELECT a.orcamento_id, count(*) AS qtd FROM antigos a GROUP BY 1 LOOP
      PERFORM auditoria.inserir(v_uid, v_sis, 'alterou', 'orcamento_itens', rec.orcamento_id::text,
        (SELECT concat_ws(' ', 'Orçamento', o.numero, '— itens') FROM public.orcamentos o WHERE o.id = rec.orcamento_id),
        jsonb_build_object(v_chave, rec.qtd));
    END LOOP;
  ELSE
    FOR rec IN
      SELECT n.orcamento_id, count(*) AS qtd
        FROM novos n JOIN antigos a ON a.id = n.id
       WHERE (to_jsonb(n) - 'created_at') IS DISTINCT FROM (to_jsonb(a) - 'created_at')
       GROUP BY 1
    LOOP
      PERFORM auditoria.inserir(v_uid, v_sis, 'alterou', 'orcamento_itens', rec.orcamento_id::text,
        (SELECT concat_ws(' ', 'Orçamento', o.numero, '— itens') FROM public.orcamentos o WHERE o.id = rec.orcamento_id),
        jsonb_build_object(v_chave, rec.qtd));
    END LOOP;
  END IF;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'auditoria.fn_registrar_itens_orcamento: %', SQLERRM;
  RETURN NULL;
END $$;

-- ---------------------------------------------------------------- login e senha (auth)
CREATE OR REPLACE FUNCTION auditoria.fn_login()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO auditoria.eventos (usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, ip, navegador)
  VALUES (NEW.user_id, auditoria.nome_usuario(NEW.user_id), NULL, 'login', 'sessions', NEW.id::text, 'Entrou',
          host(NEW.ip), NEW.user_agent);
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'auditoria.fn_login: %', SQLERRM;
  RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION auditoria.usa_senha_padrao(p_hash text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT coalesce(p_hash, '') <> ''
     AND EXISTS (SELECT 1 FROM auditoria.config c
                  WHERE c.chave = 'senha_padrao' AND extensions.crypt(c.valor, p_hash) = p_hash)
$$;

CREATE OR REPLACE FUNCTION auditoria.fn_senha_alterada()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_por uuid := auth.uid();   -- preenchido quando um admin troca a senha de outra pessoa pela Central
BEGIN
  INSERT INTO auditoria.eventos (usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, mudancas)
  VALUES (NEW.id, auditoria.nome_usuario(NEW.id), CASE WHEN v_por IS NULL THEN NULL ELSE auditoria.sistema_atual() END,
          'senha_alterada', 'users', NEW.id::text,
          CASE WHEN v_por IS NOT NULL AND v_por <> NEW.id
               THEN 'Senha trocada por ' || coalesce(auditoria.nome_usuario(v_por), 'admin')
               ELSE 'Trocou a própria senha' END,
          jsonb_build_object('voltou_para_senha_padrao', auditoria.usa_senha_padrao(NEW.encrypted_password)));
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'auditoria.fn_senha_alterada: %', SQLERRM;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS auditoria_login ON auth.sessions;
CREATE TRIGGER auditoria_login AFTER INSERT ON auth.sessions
  FOR EACH ROW EXECUTE FUNCTION auditoria.fn_login();

DROP TRIGGER IF EXISTS auditoria_senha_alterada ON auth.users;
CREATE TRIGGER auditoria_senha_alterada AFTER UPDATE OF encrypted_password ON auth.users
  FOR EACH ROW WHEN (OLD.encrypted_password IS DISTINCT FROM NEW.encrypted_password)
  EXECUTE FUNCTION auditoria.fn_senha_alterada();

-- ---------------------------------------------------------------- triggers nas tabelas de negócio
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'orcamentos','vendas','notas_fiscais','boletos',
    'projetos','contatos','projeto_arquitetos','projeto_parcelas',
    'separacoes','estoque_itens','devolucoes_estoque','entregas',
    'cotacoes_compra','pedidos_compra',
    'producao_pedidos','garantia_itens','garantia_protocolos',
    'produtos','fornecedores','funcionarios',
    'usuarios','usuario_papeis','user_system_access']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS auditoria_registrar ON public.%I', t);
    EXECUTE format('CREATE TRIGGER auditoria_registrar AFTER INSERT OR UPDATE OR DELETE ON public.%I
                    FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar()', t);
  END LOOP;
END $$;

DROP TRIGGER IF EXISTS auditoria_itens_ins ON public.orcamento_itens;
DROP TRIGGER IF EXISTS auditoria_itens_upd ON public.orcamento_itens;
DROP TRIGGER IF EXISTS auditoria_itens_del ON public.orcamento_itens;
CREATE TRIGGER auditoria_itens_ins AFTER INSERT ON public.orcamento_itens
  REFERENCING NEW TABLE AS novos FOR EACH STATEMENT EXECUTE FUNCTION auditoria.fn_registrar_itens_orcamento();
CREATE TRIGGER auditoria_itens_upd AFTER UPDATE ON public.orcamento_itens
  REFERENCING OLD TABLE AS antigos NEW TABLE AS novos FOR EACH STATEMENT EXECUTE FUNCTION auditoria.fn_registrar_itens_orcamento();
CREATE TRIGGER auditoria_itens_del AFTER DELETE ON public.orcamento_itens
  REFERENCING OLD TABLE AS antigos FOR EACH STATEMENT EXECUTE FUNCTION auditoria.fn_registrar_itens_orcamento();

-- ---------------------------------------------------------------- RPCs da tela (só admin)
CREATE OR REPLACE FUNCTION public.auditoria_listar(
  p_de timestamptz DEFAULT now() - interval '7 days',
  p_ate timestamptz DEFAULT now(),
  p_sistema text DEFAULT NULL,
  p_usuario uuid DEFAULT NULL,
  p_tipo text DEFAULT NULL,
  p_busca text DEFAULT NULL,
  p_limite int DEFAULT 100,
  p_offset int DEFAULT 0)
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
     AND (nullif(trim(p_busca), '') IS NULL
          OR e.referencia ILIKE '%' || trim(p_busca) || '%'
          OR e.usuario_nome ILIKE '%' || trim(p_busca) || '%')
   ORDER BY e.criado_em DESC, e.id DESC
   LIMIT least(greatest(coalesce(p_limite, 100), 1), 500) OFFSET greatest(coalesce(p_offset, 0), 0);
END $$;

CREATE OR REPLACE FUNCTION public.auditoria_resumo_usuarios(
  p_de timestamptz DEFAULT now() - interval '7 days',
  p_ate timestamptz DEFAULT now())
RETURNS TABLE (usuario_id uuid, nome text, email text, ativo boolean, papel text,
               ultimo_login timestamptz, logins_hoje bigint, logins_periodo bigint, dias_com_login bigint,
               acoes_periodo bigint, sistemas text[], senha_padrao boolean, ultima_troca_senha timestamptz)
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
         (SELECT count(*) FROM auditoria.eventos e WHERE e.usuario_id = u.id AND e.tipo NOT IN ('login', 'senha_alterada')
             AND e.criado_em BETWEEN p_de AND p_ate),
         (SELECT array_agg(x.sistema ORDER BY x.qtd DESC) FROM (
             SELECT e.sistema, count(*) AS qtd FROM auditoria.eventos e
              WHERE e.usuario_id = u.id AND e.sistema IS NOT NULL AND e.sistema <> 'automacao'
                AND e.criado_em BETWEEN p_de AND p_ate
              GROUP BY 1 ORDER BY 2 DESC LIMIT 3) x),
         auditoria.usa_senha_padrao(au.encrypted_password),
         (SELECT max(e.criado_em) FROM auditoria.eventos e WHERE e.usuario_id = u.id AND e.tipo = 'senha_alterada')
    FROM public.usuarios u
    JOIN auth.users au ON au.id = u.id
   ORDER BY u.ativo DESC NULLS LAST, u.nome;
END $$;

REVOKE ALL ON FUNCTION public.auditoria_listar(timestamptz, timestamptz, text, uuid, text, text, int, int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.auditoria_resumo_usuarios(timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.auditoria_listar(timestamptz, timestamptz, text, uuid, text, text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auditoria_resumo_usuarios(timestamptz, timestamptz) TO authenticated;

-- ---------------------------------------------------------------- retenção de 12 meses
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'auditoria-retencao-12-meses';
SELECT cron.schedule('auditoria-retencao-12-meses', '30 6 * * *',
  $c$DELETE FROM auditoria.eventos WHERE criado_em < now() - interval '12 months'$c$);

NOTIFY pgrst, 'reload schema';
COMMIT;
