-- SPEC-254 A/B: anexos do orçamento (comprovante de Pix/depósito) enviados na aprovação da equipe e vistos na revisão financeira.
-- Bucket PRIVADO (o bucket "orcamentos" é público; comprovante é dado financeiro, AGENTS.md regra 10): abre só por URL assinada.
-- Quem vê/anexa é quem enxerga o orçamento (RLS de orcamentos: equipe restrita ou acesso amplo da Administração/Financeiro).

CREATE TABLE IF NOT EXISTS public.orcamento_anexos (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    orcamento_id  uuid NOT NULL REFERENCES public.orcamentos(id) ON DELETE CASCADE,
    categoria     text NOT NULL DEFAULT 'comprovante' CHECK (categoria IN ('comprovante', 'outro')),
    nome_arquivo  text NOT NULL,
    caminho       text NOT NULL UNIQUE,
    tipo_mime     text,
    tamanho_bytes bigint,
    criado_por    uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
    criado_em     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS orcamento_anexos_orcamento_idx ON public.orcamento_anexos (orcamento_id);

ALTER TABLE public.orcamento_anexos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.orcamento_anexos FROM PUBLIC, anon;
GRANT SELECT, INSERT, DELETE ON public.orcamento_anexos TO authenticated;

-- ler: quem enxerga o orçamento (a subconsulta passa pelo RLS de orcamentos)
CREATE POLICY spec254_orc_anexos_select ON public.orcamento_anexos FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.orcamentos o WHERE o.id = orcamento_id));
-- anexar: quem enxerga o orçamento E pode editar orçamentos
CREATE POLICY spec254_orc_anexos_insert ON public.orcamento_anexos FOR INSERT TO authenticated
    WITH CHECK (
        criado_por = (SELECT auth.uid())
        AND (SELECT public.hub_pode_executar((SELECT auth.uid()), 'orcamentos', NULL, 'editar'))
        AND EXISTS (SELECT 1 FROM public.orcamentos o WHERE o.id = orcamento_id)
    );
-- apagar: só quem anexou (engano)
CREATE POLICY spec254_orc_anexos_delete ON public.orcamento_anexos FOR DELETE TO authenticated
    USING (criado_por = (SELECT auth.uid()));

-- Bucket privado, 10 MB, PDF e imagens
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('orcamento-anexos', 'orcamento-anexos', false, 10485760,
        ARRAY['application/pdf', 'image/png', 'image/jpeg', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Caminho do arquivo: <orcamento_id>/<arquivo>; só mexe quem enxerga aquele orçamento
CREATE OR REPLACE FUNCTION public.orcamento_anexo_pode_acessar(p_nome text, p_escrever boolean)
RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO 'public'
AS $$
    SELECT CASE
        WHEN split_part(p_nome, '/', 1) !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN false
        WHEN p_escrever AND NOT (SELECT public.hub_pode_executar((SELECT auth.uid()), 'orcamentos', NULL, 'editar')) THEN false
        ELSE EXISTS (SELECT 1 FROM public.orcamentos o WHERE o.id = split_part(p_nome, '/', 1)::uuid)
    END;
$$;
REVOKE ALL ON FUNCTION public.orcamento_anexo_pode_acessar(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.orcamento_anexo_pode_acessar(text, boolean) TO authenticated;

CREATE POLICY spec254_orc_anexos_storage_select ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'orcamento-anexos' AND public.orcamento_anexo_pode_acessar(name, false));
CREATE POLICY spec254_orc_anexos_storage_insert ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'orcamento-anexos' AND public.orcamento_anexo_pode_acessar(name, true));
CREATE POLICY spec254_orc_anexos_storage_delete ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'orcamento-anexos' AND owner = (SELECT auth.uid()));
