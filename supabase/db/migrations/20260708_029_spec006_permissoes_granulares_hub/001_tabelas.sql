-- Migration 20260708_029 - SPEC-006 Parte 1
-- Permissoes Granulares no Hub: tabelas + colunas de suporte em systems.
--
-- Achado durante a implementacao: a SPEC desenha o RPC hub_pode_executar
-- recebendo p_system_slug, mas public.systems nao tem coluna slug
-- (colunas reais: id, name, description, link, icon_name, display_order).
-- Adicionamos slug (unique, populado a partir do name) em vez de redesenhar
-- o contrato do RPC em torno de system_id.

ALTER TABLE public.systems ADD COLUMN IF NOT EXISTS slug text;
ALTER TABLE public.systems ADD COLUMN IF NOT EXISTS visivel_no_hub boolean NOT NULL DEFAULT true;

UPDATE public.systems SET slug = 'financeiro' WHERE name = 'Administração Bancária' AND slug IS NULL;
UPDATE public.systems SET slug = 'cadastro' WHERE name = 'Consultar Produtos' AND slug IS NULL;
UPDATE public.systems SET slug = 'crm' WHERE name = 'CRM Lucenera' AND slug IS NULL;
UPDATE public.systems SET slug = 'orcamentos' WHERE name = 'Orçamentos Lucenera' AND slug IS NULL;
UPDATE public.systems SET slug = 'logistica' WHERE name = 'Sistema de Entregas' AND slug IS NULL;
UPDATE public.systems SET slug = 'ubiqua' WHERE name = 'Fichas Técnicas' AND slug IS NULL;
UPDATE public.systems SET slug = 'rh' WHERE name = 'RH Lucenera' AND slug IS NULL;

UPDATE public.systems
SET slug = lower(
  regexp_replace(
    translate(name, 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç', 'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'),
    '[^a-zA-Z0-9]+',
    '-',
    'g'
  )
)
WHERE slug IS NULL;

ALTER TABLE public.systems ALTER COLUMN slug SET NOT NULL;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'systems_slug_key'
      AND conrelid = 'public.systems'::regclass
  ) THEN
    ALTER TABLE public.systems ADD CONSTRAINT systems_slug_key UNIQUE (slug);
  END IF;
END $$;

COMMENT ON COLUMN public.systems.slug IS 'SPEC-006. Identificador estavel usado por hub_pode_executar/hub_sistemas_permitidos.';
COMMENT ON COLUMN public.systems.visivel_no_hub IS 'SPEC-006. Diferencia sistemas exibidos como card na Central dos regidos apenas por permissao (ex.: o proprio Hub, para auto-governanca). Nao substitui a distincao completa de TI-14.';

-- Linha propria do Hub/Central, necessaria como FK para seu proprio modulo de
-- permissoes (auto-governanca), sem aparecer como card na Central.
INSERT INTO public.systems (name, description, link, icon_name, display_order, slug, visivel_no_hub)
VALUES ('Hub / Central', 'Catalogo de acesso e produtividade pessoal do ecossistema Lucenera.', 'https://central-lucenera.goskip.app/', 'LayoutDashboard', 0, 'hub', false)
ON CONFLICT (slug) DO UPDATE SET visivel_no_hub = false;

CREATE TABLE public.modulos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  system_id uuid NOT NULL REFERENCES public.systems(id),
  chave text NOT NULL,
  nome text NOT NULL,
  descricao text,
  ordem integer DEFAULT 0,
  UNIQUE (system_id, chave)
);

COMMENT ON TABLE public.modulos IS 'SPEC-006. Modulos/abas configuraveis por sistema.';

CREATE TABLE public.modulo_acoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  modulo_id uuid NOT NULL REFERENCES public.modulos(id) ON DELETE CASCADE,
  chave text NOT NULL CHECK (chave IN ('criar','editar','deletar','visualizar')),
  UNIQUE (modulo_id, chave)
);

COMMENT ON TABLE public.modulo_acoes IS 'SPEC-006. Acoes possiveis dentro de um modulo.';

CREATE TABLE public.papeis (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL UNIQUE,
  descricao text,
  criado_em timestamptz DEFAULT now()
);

COMMENT ON TABLE public.papeis IS 'SPEC-006. Papeis configuraveis; convivem com usuarios.role durante a transicao.';

CREATE TABLE public.papel_permissoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  papel_id uuid NOT NULL REFERENCES public.papeis(id) ON DELETE CASCADE,
  system_id uuid NOT NULL REFERENCES public.systems(id),
  modulo_id uuid REFERENCES public.modulos(id),
  acao text CHECK (acao IN ('criar','editar','deletar','visualizar')),
  UNIQUE (papel_id, system_id, modulo_id, acao)
);

COMMENT ON TABLE public.papel_permissoes IS 'SPEC-006. modulo_id NULL = todos os modulos ("ver tudo"); acao NULL = todas as acoes.';

CREATE UNIQUE INDEX IF NOT EXISTS papel_permissoes_uniq_nullable
ON public.papel_permissoes (
  papel_id,
  system_id,
  COALESCE(modulo_id, '00000000-0000-0000-0000-000000000000'::uuid),
  COALESCE(acao, '*')
);

CREATE TABLE public.usuario_papeis (
  usuario_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  papel_id uuid NOT NULL REFERENCES public.papeis(id) ON DELETE CASCADE,
  PRIMARY KEY (usuario_id, papel_id)
);

COMMENT ON TABLE public.usuario_papeis IS 'SPEC-006. Atribuicao de papeis a usuarios (um usuario pode ter mais de um papel).';

CREATE TABLE public.usuario_permissao_excecoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  system_id uuid NOT NULL REFERENCES public.systems(id),
  modulo_id uuid REFERENCES public.modulos(id),
  acao text NOT NULL CHECK (acao IN ('criar','editar','deletar','visualizar')),
  tipo text NOT NULL CHECK (tipo IN ('conceder','negar')),
  justificativa text,
  valido_até timestamptz,
  criado_por uuid REFERENCES public.usuarios(id),
  criado_em timestamptz DEFAULT now()
);

COMMENT ON TABLE public.usuario_permissao_excecoes IS 'SPEC-006. Excecao individual, com precedencia sobre o papel do usuario.';

CREATE TABLE public.auditoria_permissoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  autor_id uuid REFERENCES public.usuarios(id),
  entidade text NOT NULL,
  entidade_id uuid,
  antes jsonb,
  depois jsonb,
  criado_em timestamptz DEFAULT now()
);

COMMENT ON TABLE public.auditoria_permissoes IS 'SPEC-006. Auditoria automatica de alteracoes em papeis/permissoes/atribuicoes/excecoes.';

-- RLS: leitura e escrita restritas a admin (is_admin(), ja existente), nao
-- USING(true) - corrige o padrao permissivo ja sinalizado em auditorias
-- anteriores deste projeto. Consumo operacional (fora da tela de admin) e
-- via RPC SECURITY DEFINER (002_rpcs.sql), nao acesso direto as tabelas.
ALTER TABLE public.modulos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.modulo_acoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.papeis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.papel_permissoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuario_papeis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuario_permissao_excecoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditoria_permissoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY admin_all_modulos ON public.modulos AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY admin_all_modulo_acoes ON public.modulo_acoes AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY admin_all_papeis ON public.papeis AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY admin_all_papel_permissoes ON public.papel_permissoes AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY admin_all_usuario_papeis ON public.usuario_papeis AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY admin_all_usuario_permissao_excecoes ON public.usuario_permissao_excecoes AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY admin_select_auditoria_permissoes ON public.auditoria_permissoes AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.modulos, public.modulo_acoes, public.papeis, public.papel_permissoes, public.usuario_papeis, public.usuario_permissao_excecoes TO authenticated;
GRANT SELECT ON TABLE public.auditoria_permissoes TO authenticated;
