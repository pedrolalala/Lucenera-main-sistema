-- SPEC-282: alem do admin, uma lista de pessoas autorizadas a reajustar precos de pecas (Debora).
-- pode_reajustar_precos() passa a ser: admin OU e-mail na lista. Nada mais muda (tela e funcoes ja usam essa funcao).
BEGIN;

CREATE TABLE IF NOT EXISTS public.produto_reajuste_autorizados (
  email       text PRIMARY KEY,
  nome        text,
  observacao  text,
  criado_em   timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.produto_reajuste_autorizados ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.produto_reajuste_autorizados FROM anon, authenticated;
GRANT SELECT ON public.produto_reajuste_autorizados TO authenticated;
-- so admin enxerga a lista (gerenciada por SQL/admin; a checagem de quem pode usar roda dentro da funcao)
CREATE POLICY produto_reajuste_autorizados_select ON public.produto_reajuste_autorizados
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.usuarios u WHERE u.id = (SELECT auth.uid()) AND u.role::text = 'admin' AND COALESCE(u.ativo, true)));

INSERT INTO public.produto_reajuste_autorizados (email, nome, observacao)
VALUES ('debora@lucenera.com.br', 'Débora', 'Pedido do usuário em 11/11/2026: Débora também reajusta preços de peças')
ON CONFLICT (email) DO NOTHING;

CREATE OR REPLACE FUNCTION public.pode_reajustar_precos()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT COALESCE(auth.role(), '') = 'service_role'
      OR EXISTS (SELECT 1 FROM public.usuarios u
                 WHERE u.id = auth.uid() AND COALESCE(u.ativo, true)
                   AND (u.role::text = 'admin'
                        OR lower(u.email) IN (SELECT lower(a.email) FROM public.produto_reajuste_autorizados a)));
$$;
REVOKE ALL ON FUNCTION public.pode_reajustar_precos() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_reajustar_precos() TO authenticated, service_role;

COMMIT;
