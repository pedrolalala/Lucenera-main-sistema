-- Rollback da 264 (SPEC-243 base). Remove só o que a 264 criou. Se a 265 (carga) já tiver rodado, aplicar o rollback da 265 ANTES.
BEGIN;

DROP VIEW IF EXISTS public.vw_connect_reserva_ambiente_valor;
DROP VIEW IF EXISTS public.vw_connect_reserva_ambiente;

DROP TABLE IF EXISTS public.connect_reserva_tratamento;
DROP TABLE IF EXISTS public.connect_reserva_ambiente;

DROP FUNCTION IF EXISTS public.pode_tratar_heranca_connect();
DELETE FROM public.usuario_permissao_excecoes
 WHERE modulo_id IN (SELECT m.id FROM public.modulos m JOIN public.systems s ON s.id = m.system_id
                      WHERE s.slug = 'separacao-parcial' AND m.chave = 'tratar_heranca_connect');
DELETE FROM public.modulos
 WHERE chave = 'tratar_heranca_connect'
   AND system_id = (SELECT id FROM public.systems WHERE slug = 'separacao-parcial');

DROP INDEX IF EXISTS public.idx_orcamentos_vendas_vinculadas_connect;
DROP INDEX IF EXISTS public.idx_orcamentos_origem_connect;
ALTER TABLE public.orcamentos DROP CONSTRAINT IF EXISTS orcamentos_origem_check;
ALTER TABLE public.orcamentos
  DROP COLUMN IF EXISTS vendas_vinculadas_connect,
  DROP COLUMN IF EXISTS connect_lote,
  DROP COLUMN IF EXISTS origem;

COMMIT;
