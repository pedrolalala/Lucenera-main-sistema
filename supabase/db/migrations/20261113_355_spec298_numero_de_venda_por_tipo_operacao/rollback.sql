-- Rollback SPEC-298: remove o gatilho e devolve numero_venda = NULL so dos orcamentos que receberam numero por esta migration
-- (de/para em backup.spec298_numero_venda_por_tipo, que fica como historico). As sequencias seq_numero_venda_* ficam (nao reutilizar numeros).
BEGIN;
DROP TRIGGER IF EXISTS trg_3_numero_venda_por_tipo ON public.orcamentos;
UPDATE public.orcamentos o SET numero_venda = NULL
  FROM backup.spec298_numero_venda_por_tipo b
 WHERE b.orcamento_id = o.id AND o.numero_venda = b.numero_venda_novo;
DROP FUNCTION IF EXISTS public.trg_numero_venda_por_tipo();
DROP FUNCTION IF EXISTS public.proximo_numero_venda_operacao(text);
DROP FUNCTION IF EXISTS public.prefixo_numero_operacao(text, text);
COMMIT;
