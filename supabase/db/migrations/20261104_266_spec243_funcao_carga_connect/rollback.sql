-- Rollback da 266 (SPEC-243 função de carga). Remove os orçamentos Connect gerados por qualquer lote (só se ninguém separou/entregou nada)
-- e depois apaga as funções. A 264 (tabelas) fica; o espelho volta a ter orcamento_id/projeto_item_id nulos.
BEGIN;

DO $$
DECLARE l uuid;
BEGIN
  FOR l IN SELECT DISTINCT connect_lote FROM public.orcamentos WHERE origem = 'connect' AND connect_lote IS NOT NULL LOOP
    PERFORM public.remover_connect_lote(l);
  END LOOP;
END $$;

DROP FUNCTION IF EXISTS public.carregar_connect_reserva_ambiente(uuid);
DROP FUNCTION IF EXISTS public.remover_connect_lote(uuid);

COMMIT;
