-- SPEC-251: volta connect_item_liberado() à regra de antes (só Reserva sem data ou recebimento pela NF).
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
                        WHERE m.projeto_item_id = pi.id AND m.tipo = 'recebimento_para_reserva')));
$function$;
