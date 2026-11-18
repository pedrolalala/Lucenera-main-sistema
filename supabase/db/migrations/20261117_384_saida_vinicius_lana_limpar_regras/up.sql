-- 17/11/2026: Vinicius e Lana sairam da empresa. Tira o nome deles das regras de funcionamento do sistema.
-- O historico (autoria de registros, logs, eventos, vendas, movimentacoes) NAO e tocado: fica como registro.
-- Cada alteracao guarda a copia da linha original no schema backup (volta pelo rollback.sql).
BEGIN;

-- 1) Comissao: Vinicius 1,00% e Lana 0,15% passam a 0 (a view vw_comissao_mensal le este campo)
CREATE TABLE IF NOT EXISTS backup._bkp_saida_vinicius_lana_funcionarios_financeiro AS
SELECT now() AS salvo_em, ff.* FROM public.funcionarios_financeiro ff
 WHERE ff.id IN ('aba67a73-39f4-4ff7-a357-191ce0db042d','cbe111c1-c19f-4d1c-a5db-b6809e03eae7');
UPDATE public.funcionarios_financeiro SET comissao_percentual = 0
 WHERE id IN ('aba67a73-39f4-4ff7-a357-191ce0db042d','cbe111c1-c19f-4d1c-a5db-b6809e03eae7');

-- 2) Copia automatica de pedido de compra da Debora para o e-mail do Vinicius
CREATE TABLE IF NOT EXISTS backup._bkp_saida_vinicius_lana_usuarios_copias AS
SELECT now() AS salvo_em, u.id, u.email, u.copias_pedido_compra FROM public.usuarios u
 WHERE u.copias_pedido_compra ILIKE '%vinicius@lucenera.com.br%';
UPDATE public.usuarios
   SET copias_pedido_compra = nullif(btrim(regexp_replace(regexp_replace(copias_pedido_compra, '\s*vinicius@lucenera\.com\.br\s*', '', 'gi'), '^[,;\s]+|[,;\s]+$', '', 'g')), '')
 WHERE copias_pedido_compra ILIKE '%vinicius@lucenera.com.br%';

-- 3) Quem ve a distribuicao de lucro: tira o e-mail do Vinicius da lista
CREATE OR REPLACE FUNCTION public.pode_ver_distribuicao_lucro()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT coalesce(nullif(current_setting('request.jwt.claims', true), ''), '') = ''
      OR coalesce(auth.role(), '') = 'service_role'
      OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('filippo@lucenera.com.br', 'pedro@lucenera.com.br')
$function$;

COMMIT;
