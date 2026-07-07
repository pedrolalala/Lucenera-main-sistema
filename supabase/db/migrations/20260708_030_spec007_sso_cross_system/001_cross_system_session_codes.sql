-- Migration 20260708_030 - SPEC-007
-- Token de Acesso Compartilhado entre Sistemas (SSO sem novo login).

CREATE TABLE public.cross_system_session_codes (
  code uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  sistema_origem text NOT NULL,
  sistema_destino text,
  contexto jsonb,
  criado_em timestamptz NOT NULL DEFAULT now(),
  expira_em timestamptz NOT NULL DEFAULT (now() + interval '60 seconds'),
  usado_em timestamptz
);

COMMENT ON TABLE public.cross_system_session_codes IS
'SPEC-007. Codigo opaco de curta duracao e uso unico para hidratar sessao Supabase entre apps.';

CREATE INDEX idx_cross_system_codes_expira
ON public.cross_system_session_codes (expira_em);

CREATE INDEX idx_cross_system_codes_usuario
ON public.cross_system_session_codes (usuario_id, criado_em DESC);

ALTER TABLE public.cross_system_session_codes ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.cross_system_session_codes FROM anon, authenticated;

