-- SPEC-226: Logística (reunião 08/10 + registro de log no Admin).
--  B  pedido combinado: devolução junto com entrega/garantia + anexo "orçamento de devolução"
--  C  recusa com motivo
--  E  baixa guarda quem entregou e com quem foi combinado
--  G  hora de cada etapa (métrica): início da separação, separado, recusado
--  I  registro de log: triggers nas tabelas que faltavam + leitura só para admin do Logística
--  +  user_roles_separacao apontava para contas do banco antigo (nenhum user_id existe em auth.users):
--     religa pelo e-mail. Sem isso ninguém além do fallback do Pedro é admin no sistema novo.
BEGIN;

-- ---------------------------------------------------------------- colunas
ALTER TABLE public.separacoes
  ADD COLUMN IF NOT EXISTS inclui_devolucao boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS devolucao_detalhes text,
  ADD COLUMN IF NOT EXISTS separado_em timestamptz,
  ADD COLUMN IF NOT EXISTS recusado_em timestamptz,
  ADD COLUMN IF NOT EXISTS recusado_por uuid,
  ADD COLUMN IF NOT EXISTS recusado_por_nome text,
  ADD COLUMN IF NOT EXISTS motivo_recusa text;

ALTER TABLE public.entregas_finalizadas
  ADD COLUMN IF NOT EXISTS entregue_por text,
  ADD COLUMN IF NOT EXISTS combinado_com text;

ALTER TABLE public.separacao_arquivos
  ADD COLUMN IF NOT EXISTS categoria text NOT NULL DEFAULT 'geral';
ALTER TABLE public.separacao_arquivos DROP CONSTRAINT IF EXISTS separacao_arquivos_categoria_check;
ALTER TABLE public.separacao_arquivos
  ADD CONSTRAINT separacao_arquivos_categoria_check CHECK (categoria IN ('geral', 'orcamento_devolucao'));

-- ---------------------------------------------------------------- arquivos (buckets que não vieram na virada SP)
-- materiais-separacao = anexos da solicitação; entregas-fotos = fotos/documento assinado da baixa.
-- Privados; qualquer conta logada lê e envia (mesmo público do sistema), só o próprio sistema apaga.
INSERT INTO storage.buckets (id, name, public)
VALUES ('materiais-separacao', 'materiais-separacao', false),
       ('entregas-fotos', 'entregas-fotos', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS logistica_arquivos_select ON storage.objects;
DROP POLICY IF EXISTS logistica_arquivos_insert ON storage.objects;
DROP POLICY IF EXISTS logistica_arquivos_update ON storage.objects;
DROP POLICY IF EXISTS logistica_arquivos_delete ON storage.objects;
CREATE POLICY logistica_arquivos_select ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id IN ('materiais-separacao', 'entregas-fotos'));
CREATE POLICY logistica_arquivos_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN ('materiais-separacao', 'entregas-fotos'));
CREATE POLICY logistica_arquivos_update ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id IN ('materiais-separacao', 'entregas-fotos'));
CREATE POLICY logistica_arquivos_delete ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'materiais-separacao');

-- ---------------------------------------------------------------- hora de cada etapa
-- O banco carimba a hora (o front não manda mais data_inicio_separacao). Voltar uma etapa limpa
-- as horas das etapas seguintes, para a métrica medir sempre a última passagem.
CREATE OR REPLACE FUNCTION public.separacoes_marcar_etapas()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_novo text := NEW.status::text;
  v_velho text := OLD.status::text;
BEGIN
  IF v_novo IS NOT DISTINCT FROM v_velho THEN RETURN NEW; END IF;

  IF v_novo = 'Em separação' THEN
    IF v_velho NOT IN ('separado', 'Pronto') OR NEW.data_inicio_separacao IS NULL THEN
      NEW.data_inicio_separacao := now();
    END IF;
    NEW.separado_em := NULL;
  ELSIF v_novo IN ('separado', 'Pronto') THEN
    NEW.separado_em := now();
    NEW.data_inicio_separacao := coalesce(NEW.data_inicio_separacao, now());
  ELSIF v_novo = 'material_solicitado' THEN
    NEW.data_inicio_separacao := NULL;
    NEW.separado_em := NULL;
    IF v_velho = 'recusado' THEN
      -- reenviado depois de corrigido: o histórico da recusa fica no registro de log
      NEW.recusado_em := NULL;
      NEW.recusado_por := NULL;
      NEW.recusado_por_nome := NULL;
      NEW.motivo_recusa := NULL;
    END IF;
  ELSIF v_novo = 'recusado' THEN
    NEW.recusado_em := now();
    NEW.recusado_por := auth.uid();
    NEW.recusado_por_nome := (SELECT coalesce(nullif(u.nome, ''), u.email) FROM public.usuarios u WHERE u.id = auth.uid());
    NEW.data_inicio_separacao := NULL;
    NEW.separado_em := NULL;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_separacoes_marcar_etapas ON public.separacoes;
CREATE TRIGGER trg_separacoes_marcar_etapas
  BEFORE UPDATE OF status ON public.separacoes
  FOR EACH ROW EXECUTE FUNCTION public.separacoes_marcar_etapas();

-- Recusar exige motivo
ALTER TABLE public.separacoes DROP CONSTRAINT IF EXISTS separacoes_recusa_com_motivo;
ALTER TABLE public.separacoes ADD CONSTRAINT separacoes_recusa_com_motivo
  CHECK (status::text <> 'recusado' OR nullif(trim(motivo_recusa), '') IS NOT NULL) NOT VALID;

-- ---------------------------------------------------------------- permissões do Logística (religar pelo e-mail)
CREATE SCHEMA IF NOT EXISTS backup;
CREATE TABLE IF NOT EXISTS backup._bkp_spec226_user_roles_separacao AS
  SELECT * FROM public.user_roles_separacao;

UPDATE public.user_roles_separacao r
   SET user_id = u.id
  FROM auth.users u
 WHERE lower(u.email) = lower(r.email)
   AND r.user_id IS DISTINCT FROM u.id;

-- ---------------------------------------------------------------- registro de log: textos legíveis
CREATE OR REPLACE FUNCTION auditoria.referencia(p_tabela text, r jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    -- SPEC-226: número da entrega (LUC-0001) junto, é o que o estoque usa
    WHEN 'separacoes'          THEN concat_ws(' ', 'Separação', r->>'numero_entrega',
                                     coalesce(r->>'numero_venda', r->>'codigo_obra'), r->>'cliente')
    WHEN 'entregas_finalizadas' THEN concat_ws(' ', 'Entrega', r->>'numero_entrega', r->>'codigo_obra', r->>'cliente')
    WHEN 'entregas_pendentes'  THEN concat_ws(' ', 'Problema na entrega', r->>'codigo_obra', r->>'cliente')
    WHEN 'separacao_arquivos'  THEN concat_ws(' ', 'Anexo', r->>'nome_arquivo', '—',
                                     (SELECT concat_ws(' ', 'Separação', s.numero_entrega, s.cliente)
                                        FROM public.separacoes s WHERE s.id = (r->>'separacao_id')::uuid))
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
END $function$;

-- ---------------------------------------------------------------- registro de log: tabelas que faltavam
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['entregas_finalizadas', 'entregas_pendentes', 'separacao_arquivos', 'user_roles_separacao']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS auditoria_registrar ON public.%I', t);
    EXECUTE format('CREATE TRIGGER auditoria_registrar AFTER INSERT OR UPDATE OR DELETE ON public.%I
                    FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar()', t);
  END LOOP;
END $$;

-- Itens da separação: 1 evento por separação (não 1 por peça), como orcamento_itens
CREATE OR REPLACE FUNCTION auditoria.fn_registrar_itens_separacao()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    FOR rec IN SELECT n.separacao_id, count(*) AS qtd FROM novos n GROUP BY 1 LOOP
      PERFORM auditoria.inserir(v_uid, v_sis, 'alterou', 'separacao_itens', rec.separacao_id::text,
        (SELECT concat_ws(' ', 'Separação', s.numero_entrega, s.cliente, '— peças') FROM public.separacoes s WHERE s.id = rec.separacao_id),
        jsonb_build_object(v_chave, rec.qtd));
    END LOOP;
  ELSIF TG_OP = 'DELETE' THEN
    FOR rec IN SELECT a.separacao_id, count(*) AS qtd FROM antigos a GROUP BY 1 LOOP
      PERFORM auditoria.inserir(v_uid, v_sis, 'alterou', 'separacao_itens', rec.separacao_id::text,
        (SELECT concat_ws(' ', 'Separação', s.numero_entrega, s.cliente, '— peças') FROM public.separacoes s WHERE s.id = rec.separacao_id),
        jsonb_build_object(v_chave, rec.qtd));
    END LOOP;
  ELSE
    FOR rec IN
      SELECT n.separacao_id, count(*) AS qtd
        FROM novos n JOIN antigos a ON a.id = n.id
       WHERE (to_jsonb(n) - 'created_at') IS DISTINCT FROM (to_jsonb(a) - 'created_at')
       GROUP BY 1
    LOOP
      PERFORM auditoria.inserir(v_uid, v_sis, 'alterou', 'separacao_itens', rec.separacao_id::text,
        (SELECT concat_ws(' ', 'Separação', s.numero_entrega, s.cliente, '— peças') FROM public.separacoes s WHERE s.id = rec.separacao_id),
        jsonb_build_object(v_chave, rec.qtd));
    END LOOP;
  END IF;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'auditoria.fn_registrar_itens_separacao: %', SQLERRM;
  RETURN NULL;
END $function$;

DROP TRIGGER IF EXISTS auditoria_itens_ins ON public.separacao_itens;
DROP TRIGGER IF EXISTS auditoria_itens_upd ON public.separacao_itens;
DROP TRIGGER IF EXISTS auditoria_itens_del ON public.separacao_itens;
CREATE TRIGGER auditoria_itens_ins AFTER INSERT ON public.separacao_itens
  REFERENCING NEW TABLE AS novos FOR EACH STATEMENT EXECUTE FUNCTION auditoria.fn_registrar_itens_separacao();
CREATE TRIGGER auditoria_itens_upd AFTER UPDATE ON public.separacao_itens
  REFERENCING OLD TABLE AS antigos NEW TABLE AS novos FOR EACH STATEMENT EXECUTE FUNCTION auditoria.fn_registrar_itens_separacao();
CREATE TRIGGER auditoria_itens_del AFTER DELETE ON public.separacao_itens
  REFERENCING OLD TABLE AS antigos FOR EACH STATEMENT EXECUTE FUNCTION auditoria.fn_registrar_itens_separacao();

-- ---------------------------------------------------------------- registro de log: ações sem mudança no banco
-- Nome próprio (não muda a assinatura de auditoria_registrar_acao, que os outros sistemas usam).
CREATE OR REPLACE FUNCTION public.logistica_registrar_evento(p_tipo text, p_separacao_id uuid, p_detalhe text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_ref text;
BEGIN
  IF v_uid IS NULL THEN RETURN; END IF;
  IF p_tipo NOT IN ('imprimiu', 'enviou_email', 'abriu_documento', 'exportou') THEN RETURN; END IF;
  IF p_separacao_id IS NOT NULL THEN
    SELECT concat_ws(' ', 'Separação', s.numero_entrega, s.cliente) INTO v_ref
      FROM public.separacoes s WHERE s.id = p_separacao_id;
  END IF;
  PERFORM auditoria.inserir(v_uid, auditoria.sistema_atual(), p_tipo, 'separacoes', p_separacao_id::text,
    coalesce(v_ref, left(p_detalhe, 200), 'Logística'),
    CASE WHEN nullif(trim(p_detalhe), '') IS NULL THEN NULL ELSE jsonb_build_object('detalhe', left(p_detalhe, 500)) END);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'logistica_registrar_evento: %', SQLERRM;
END $$;

REVOKE ALL ON FUNCTION public.logistica_registrar_evento(text, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.logistica_registrar_evento(text, uuid, text) TO authenticated;

-- ---------------------------------------------------------------- registro de log: leitura (só admin do Logística)
CREATE OR REPLACE FUNCTION public.logistica_eh_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT coalesce(public.is_admin(), false)
      OR EXISTS (SELECT 1 FROM public.user_roles_separacao r
                  WHERE r.user_id = auth.uid() AND r.role = 'admin' AND r.sistema = 'Separação e Entregas');
$$;
REVOKE ALL ON FUNCTION public.logistica_eh_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.logistica_eh_admin() TO authenticated;

CREATE OR REPLACE FUNCTION public.logistica_listar_log(
  p_de timestamptz DEFAULT now() - interval '7 days',
  p_ate timestamptz DEFAULT now(),
  p_usuario uuid DEFAULT NULL,
  p_tipo text DEFAULT NULL,
  p_busca text DEFAULT NULL,
  p_incluir_telas boolean DEFAULT false,
  p_limite int DEFAULT 100,
  p_offset int DEFAULT 0)
RETURNS TABLE (id bigint, criado_em timestamptz, usuario_id uuid, usuario_nome text, usuario_email text,
               tipo text, entidade text, registro_id text, referencia text, mudancas jsonb, total bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.logistica_eh_admin() THEN
    RAISE EXCEPTION 'Apenas administradores do Logística veem o registro.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT e.id, e.criado_em, e.usuario_id, e.usuario_nome, u.email::text, e.tipo, e.entidade, e.registro_id,
         e.referencia, e.mudancas, count(*) OVER () AS total
    FROM auditoria.eventos e
    LEFT JOIN public.usuarios u ON u.id = e.usuario_id
   WHERE e.sistema = 'logistica'
     AND e.criado_em >= p_de AND e.criado_em <= p_ate
     AND (p_usuario IS NULL OR e.usuario_id = p_usuario)
     AND (p_tipo IS NULL OR e.tipo = p_tipo)
     AND (coalesce(p_incluir_telas, false) OR p_tipo = 'abriu_tela' OR e.tipo <> 'abriu_tela')
     AND (nullif(trim(p_busca), '') IS NULL
          OR e.referencia ILIKE '%' || trim(p_busca) || '%'
          OR e.usuario_nome ILIKE '%' || trim(p_busca) || '%'
          OR u.email ILIKE '%' || trim(p_busca) || '%')
   ORDER BY e.criado_em DESC, e.id DESC
   LIMIT least(greatest(coalesce(p_limite, 100), 1), 1000) OFFSET greatest(coalesce(p_offset, 0), 0);
END $$;

REVOKE ALL ON FUNCTION public.logistica_listar_log(timestamptz, timestamptz, uuid, text, text, boolean, int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.logistica_listar_log(timestamptz, timestamptz, uuid, text, text, boolean, int, int) TO authenticated;

-- Pessoas que aparecem no registro (para o filtro)
CREATE OR REPLACE FUNCTION public.logistica_log_usuarios(p_de timestamptz DEFAULT now() - interval '90 days')
RETURNS TABLE (usuario_id uuid, usuario_nome text, usuario_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.logistica_eh_admin() THEN
    RAISE EXCEPTION 'Apenas administradores do Logística veem o registro.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT DISTINCT e.usuario_id, e.usuario_nome, u.email::text
    FROM auditoria.eventos e LEFT JOIN public.usuarios u ON u.id = e.usuario_id
   WHERE e.sistema = 'logistica' AND e.criado_em >= p_de AND e.usuario_id IS NOT NULL
   ORDER BY 2;
END $$;
REVOKE ALL ON FUNCTION public.logistica_log_usuarios(timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.logistica_log_usuarios(timestamptz) TO authenticated;

-- ---------------------------------------------------------------- métrica de tempo por etapa (Admin)
CREATE OR REPLACE FUNCTION public.logistica_metricas_etapas(p_de date DEFAULT (current_date - 90), p_ate date DEFAULT current_date)
RETURNS TABLE (id uuid, numero_entrega text, cliente text, nivel_complexidade text, qtd_itens bigint,
               pedido_em timestamptz, data_entrega date, inicio_separacao timestamptz, separado_em timestamptz,
               entregue_em date, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.logistica_eh_admin() THEN
    RAISE EXCEPTION 'Apenas administradores do Logística veem as métricas.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT s.id, s.numero_entrega, s.cliente, s.nivel_complexidade,
         (SELECT count(*) FROM public.separacao_itens i WHERE i.separacao_id = s.id),
         s.created_at, s.data_entrega::date, s.data_inicio_separacao, s.separado_em,
         (SELECT max(f.data_entrega_real)::date FROM public.entregas_finalizadas f WHERE f.separacao_id = s.id),
         s.status::text
    FROM public.separacoes s
   WHERE s.created_at::date BETWEEN p_de AND p_ate
   ORDER BY s.created_at DESC;
END $$;
REVOKE ALL ON FUNCTION public.logistica_metricas_etapas(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.logistica_metricas_etapas(date, date) TO authenticated;

COMMIT;
