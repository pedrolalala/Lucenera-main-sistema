-- SPEC-251 (pendência "destino da Connect com data de entrega"): item de venda da Connect que RECEBE peça por transferência
-- (Transferir da Venda Parcial) passa a contar como liberado para separar, igual ao item que recebeu a peça pela nota fiscal.
-- Motivo: a regra da SPEC-244 só libera item da Connect com Reserva "sem data" ou que já recebeu da NF (recebimento_para_reserva). Uma venda da
-- Connect só com Entrega Futura que recebia a peça por transferência ficava com a Reserva travada ("tem data de entrega na Connect"), e a
-- equipe não conseguia separar o que acabou de pegar. A peça que chega por transferência é estoque físico do sistema, não herança com data.
-- Aproximação igual à da SPEC-244: se o item é liberado, toda a Reserva dele fica liberada.
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
