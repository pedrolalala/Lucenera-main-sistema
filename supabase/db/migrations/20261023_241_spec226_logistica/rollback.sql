-- Rollback SPEC-226 (241). O valor 'recusado' do enum separacao_status NÃO é removido
-- (Postgres não remove valor de enum); antes de rodar, voltar pedidos recusados para 'material_solicitado'.
BEGIN;

UPDATE public.separacoes SET status = 'material_solicitado' WHERE status::text = 'recusado';

DROP FUNCTION IF EXISTS public.logistica_metricas_etapas(date, date);
DROP FUNCTION IF EXISTS public.logistica_log_usuarios(timestamptz);
DROP FUNCTION IF EXISTS public.logistica_listar_log(timestamptz, timestamptz, uuid, text, text, boolean, int, int);
DROP FUNCTION IF EXISTS public.logistica_eh_admin();
DROP FUNCTION IF EXISTS public.logistica_registrar_evento(text, uuid, text);

DROP TRIGGER IF EXISTS auditoria_itens_ins ON public.separacao_itens;
DROP TRIGGER IF EXISTS auditoria_itens_upd ON public.separacao_itens;
DROP TRIGGER IF EXISTS auditoria_itens_del ON public.separacao_itens;
DROP FUNCTION IF EXISTS auditoria.fn_registrar_itens_separacao();
DROP TRIGGER IF EXISTS auditoria_registrar ON public.entregas_finalizadas;
DROP TRIGGER IF EXISTS auditoria_registrar ON public.entregas_pendentes;
DROP TRIGGER IF EXISTS auditoria_registrar ON public.separacao_arquivos;
DROP TRIGGER IF EXISTS auditoria_registrar ON public.user_roles_separacao;
-- auditoria.referencia: os casos novos são inofensivos e ficam (o texto antigo de 'separacoes' só não tinha o LUC-).

-- permissões voltam aos user_id antigos
UPDATE public.user_roles_separacao r SET user_id = b.user_id
  FROM backup._bkp_spec226_user_roles_separacao b WHERE b.id = r.id;

DROP TRIGGER IF EXISTS trg_separacoes_marcar_etapas ON public.separacoes;
DROP FUNCTION IF EXISTS public.separacoes_marcar_etapas();
ALTER TABLE public.separacoes DROP CONSTRAINT IF EXISTS separacoes_recusa_com_motivo;

-- buckets: as policies saem; os buckets ficam (podem ter arquivos de entregas reais)
DROP POLICY IF EXISTS logistica_arquivos_select ON storage.objects;
DROP POLICY IF EXISTS logistica_arquivos_insert ON storage.objects;
DROP POLICY IF EXISTS logistica_arquivos_update ON storage.objects;
DROP POLICY IF EXISTS logistica_arquivos_delete ON storage.objects;

ALTER TABLE public.separacao_arquivos DROP CONSTRAINT IF EXISTS separacao_arquivos_categoria_check;
ALTER TABLE public.separacao_arquivos DROP COLUMN IF EXISTS categoria;
ALTER TABLE public.entregas_finalizadas DROP COLUMN IF EXISTS entregue_por, DROP COLUMN IF EXISTS combinado_com;
ALTER TABLE public.separacoes
  DROP COLUMN IF EXISTS inclui_devolucao, DROP COLUMN IF EXISTS devolucao_detalhes,
  DROP COLUMN IF EXISTS separado_em, DROP COLUMN IF EXISTS recusado_em, DROP COLUMN IF EXISTS recusado_por,
  DROP COLUMN IF EXISTS recusado_por_nome, DROP COLUMN IF EXISTS motivo_recusa;

COMMIT;
