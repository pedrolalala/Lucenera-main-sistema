-- SPEC-267: desfaz a liberação manual. connect_item_liberado volta à regra da migration 300.
BEGIN;
CREATE OR REPLACE FUNCTION public.connect_item_liberado(p_projeto_item_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id AND o.origem = 'connect'
     WHERE pi.id = p_projeto_item_id
       AND (EXISTS (SELECT 1 FROM public.connect_reserva_ambiente r
                     WHERE r.projeto_item_id = pi.id AND r.tipo = 'reserva' AND r.aviso_data)
            OR EXISTS (SELECT 1 FROM public.estoque_movimentos_projeto_item m
                        WHERE m.projeto_item_id = pi.id AND m.tipo IN ('recebimento_para_reserva', 'transferencia_entrada'))));
$function$;
DROP FUNCTION IF EXISTS public.liberar_vendas_connect(integer[], text, boolean);
DROP TABLE IF EXISTS public.connect_item_liberacao_manual;
COMMIT;
