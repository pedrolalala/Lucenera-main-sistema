BEGIN;
UPDATE public.funcionarios_financeiro ff SET comissao_percentual = b.comissao_percentual
  FROM backup._bkp_saida_vinicius_lana_funcionarios_financeiro b WHERE b.id = ff.id;
UPDATE public.usuarios u SET copias_pedido_compra = b.copias_pedido_compra
  FROM backup._bkp_saida_vinicius_lana_usuarios_copias b WHERE b.id = u.id;
CREATE OR REPLACE FUNCTION public.pode_ver_distribuicao_lucro()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT coalesce(nullif(current_setting('request.jwt.claims', true), ''), '') = ''
      OR coalesce(auth.role(), '') = 'service_role'
      OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('filippo@lucenera.com.br', 'pedro@lucenera.com.br', 'vinicius@lucenera.com.br')
$function$;
COMMIT;
