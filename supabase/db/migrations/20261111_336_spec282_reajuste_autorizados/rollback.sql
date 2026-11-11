BEGIN;
CREATE OR REPLACE FUNCTION public.pode_reajustar_precos()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT COALESCE(auth.role(), '') = 'service_role'
      OR EXISTS (SELECT 1 FROM public.usuarios u
                 WHERE u.id = auth.uid() AND u.role::text = 'admin' AND COALESCE(u.ativo, true));
$$;
DROP TABLE IF EXISTS public.produto_reajuste_autorizados;
COMMIT;
