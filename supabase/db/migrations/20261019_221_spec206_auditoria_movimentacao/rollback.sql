-- Desfaz a SPEC-206. ATENÇÃO: apaga o schema auditoria inteiro, com todos os eventos registrados.
BEGIN;
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'auditoria-retencao-12-meses';

DROP TRIGGER IF EXISTS auditoria_login ON auth.sessions;
DROP TRIGGER IF EXISTS auditoria_senha_alterada ON auth.users;
DROP TRIGGER IF EXISTS auditoria_itens_ins ON public.orcamento_itens;
DROP TRIGGER IF EXISTS auditoria_itens_upd ON public.orcamento_itens;
DROP TRIGGER IF EXISTS auditoria_itens_del ON public.orcamento_itens;
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'orcamentos','vendas','notas_fiscais','boletos','projetos','contatos','projeto_arquitetos','projeto_parcelas',
    'separacoes','estoque_itens','devolucoes_estoque','entregas','cotacoes_compra','pedidos_compra',
    'producao_pedidos','garantia_itens','garantia_protocolos','produtos','fornecedores','funcionarios',
    'usuarios','usuario_papeis','user_system_access']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS auditoria_registrar ON public.%I', t);
  END LOOP;
END $$;

DROP FUNCTION IF EXISTS public.auditoria_listar(timestamptz, timestamptz, text, uuid, text, text, int, int);
DROP FUNCTION IF EXISTS public.auditoria_resumo_usuarios(timestamptz, timestamptz);
DROP SCHEMA IF EXISTS auditoria CASCADE;

NOTIFY pgrst, 'reload schema';
COMMIT;
