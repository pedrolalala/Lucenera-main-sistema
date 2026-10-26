-- SPEC-225 (pedido do usuário 26/10): Central de Solicitações.
--   1. O autor edita o próprio pedido só enquanto está "Aberto" (título, descrição, tipo, sistema) pela RPC
--      editar_minha_solicitacao. Sai a policy solicitacoes_update_autor_aberto, que deixava o autor mudar qualquer
--      coluna (status, classificação da IA...).
--   2. Fotos no pedido: tabela solicitacao_anexos + bucket privado solicitacoes-anexos. Anexa o autor (pedido
--      Aberto) e quem atende (hub_pode_executar ... 'aprovar'); todos que veem o pedido veem as fotos.
-- Sem BEGIN/COMMIT: o aplicador envolve em transação.

-- 1. Edição pelo autor -------------------------------------------------------------------------------------------
DROP POLICY IF EXISTS solicitacoes_update_autor_aberto ON public.solicitacoes;

CREATE OR REPLACE FUNCTION public.editar_minha_solicitacao(p_id uuid, p_titulo text, p_descricao text, p_tipo text,
                                                           p_sistema_relacionado_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_sol record;
BEGIN
  SELECT id, usuario_id, status INTO v_sol FROM public.solicitacoes WHERE id = p_id FOR UPDATE;
  IF v_sol.id IS NULL THEN
    RAISE EXCEPTION 'Pedido nao encontrado.' USING ERRCODE = 'P0001';
  END IF;
  IF v_sol.usuario_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'So quem abriu o pedido pode editar.' USING ERRCODE = '42501';
  END IF;
  IF v_sol.status <> 'aberto' THEN
    RAISE EXCEPTION 'O pedido ja esta sendo atendido: so da para editar enquanto esta Aberto.' USING ERRCODE = 'P0001';
  END IF;
  IF NULLIF(btrim(coalesce(p_titulo, '')), '') IS NULL OR NULLIF(btrim(coalesce(p_descricao, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Preencha titulo e descricao.' USING ERRCODE = 'P0001';
  END IF;
  IF p_tipo NOT IN ('bug', 'pedido_alteracao') THEN
    RAISE EXCEPTION 'Tipo invalido.' USING ERRCODE = 'P0001';
  END IF;

  -- A classificação da IA é refeita pela tela depois de salvar (Edge Function classificar_solicitacao).
  UPDATE public.solicitacoes
     SET titulo = btrim(p_titulo), descricao = btrim(p_descricao), tipo = p_tipo,
         sistema_relacionado_id = p_sistema_relacionado_id,
         classificacao_ia = NULL, justificativa_ia = NULL, confianca_ia = NULL
   WHERE id = p_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.editar_minha_solicitacao(uuid, text, text, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.editar_minha_solicitacao(uuid, text, text, text, uuid) TO authenticated;

-- 2. Quem pode anexar/remover foto de um pedido -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.solicitacao_pode_anexar(p_solicitacao_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT auth.uid() IS NOT NULL AND (
           EXISTS (SELECT 1 FROM public.solicitacoes s
                    WHERE s.id = p_solicitacao_id AND s.usuario_id = auth.uid() AND s.status = 'aberto')
           OR (EXISTS (SELECT 1 FROM public.solicitacoes s WHERE s.id = p_solicitacao_id)
               AND public.hub_pode_executar(auth.uid(), 'solicitacoes', NULL, 'aprovar')))
$function$;
REVOKE ALL ON FUNCTION public.solicitacao_pode_anexar(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.solicitacao_pode_anexar(uuid) TO authenticated;

-- Para o storage: a 1ª pasta do arquivo tem de ser o id do pedido (nome fora do padrão = não pode, sem erro).
CREATE OR REPLACE FUNCTION public.solicitacao_pode_anexar_arquivo(p_nome text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pasta text := split_part(coalesce(p_nome, ''), '/', 1);
BEGIN
  IF v_pasta !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    RETURN false;
  END IF;
  RETURN public.solicitacao_pode_anexar(v_pasta::uuid);
END;
$function$;
REVOKE ALL ON FUNCTION public.solicitacao_pode_anexar_arquivo(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.solicitacao_pode_anexar_arquivo(text) TO authenticated;

-- 3. Fotos ------------------------------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('solicitacoes-anexos', 'solicitacoes-anexos', false, 10485760,
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO NOTHING;

CREATE TABLE public.solicitacao_anexos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitacao_id  uuid NOT NULL REFERENCES public.solicitacoes(id) ON DELETE CASCADE,
  path            text NOT NULL UNIQUE,
  nome_arquivo    text,
  tipo_mime       text,
  tamanho         bigint,
  criado_por      uuid NOT NULL DEFAULT auth.uid() REFERENCES public.usuarios(id),
  criado_em       timestamptz NOT NULL DEFAULT now(),
  -- o arquivo fica na pasta do pedido: <solicitacao_id>/<arquivo>
  CHECK (split_part(path, '/', 1) = solicitacao_id::text)
);
CREATE INDEX solicitacao_anexos_solicitacao_idx ON public.solicitacao_anexos (solicitacao_id, criado_em);
COMMENT ON TABLE public.solicitacao_anexos IS
  'SPEC-225: fotos anexadas a um pedido da Central de Solicitações (arquivo no bucket privado solicitacoes-anexos).';

ALTER TABLE public.solicitacao_anexos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.solicitacao_anexos FROM anon;
REVOKE ALL ON public.solicitacao_anexos FROM authenticated;
GRANT SELECT, INSERT, DELETE ON public.solicitacao_anexos TO authenticated;

-- mesmo alcance de leitura da tabela solicitacoes (todo usuário logado)
CREATE POLICY solicitacao_anexos_select ON public.solicitacao_anexos
  FOR SELECT TO authenticated USING (true);
CREATE POLICY solicitacao_anexos_insert ON public.solicitacao_anexos
  FOR INSERT TO authenticated
  WITH CHECK (criado_por = (SELECT auth.uid()) AND public.solicitacao_pode_anexar(solicitacao_id));
CREATE POLICY solicitacao_anexos_delete ON public.solicitacao_anexos
  FOR DELETE TO authenticated
  USING (public.solicitacao_pode_anexar(solicitacao_id)
         AND (criado_por = (SELECT auth.uid())
              OR (SELECT public.hub_pode_executar((SELECT auth.uid()), 'solicitacoes', NULL, 'aprovar'))));

-- storage: pasta = id do pedido
CREATE POLICY solicitacoes_anexos_storage_select ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'solicitacoes-anexos');
CREATE POLICY solicitacoes_anexos_storage_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'solicitacoes-anexos'
              AND public.solicitacao_pode_anexar_arquivo(name));
CREATE POLICY solicitacoes_anexos_storage_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'solicitacoes-anexos'
         AND public.solicitacao_pode_anexar_arquivo(name));
