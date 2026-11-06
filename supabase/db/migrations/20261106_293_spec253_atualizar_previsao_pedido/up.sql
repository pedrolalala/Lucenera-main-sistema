-- SPEC-253 C: a compradora atualiza a data prevista de entrega de um pedido JÁ APROVADO (fornecedor avisou atraso)
-- sem "voltar para edição" (que tira o pedido do Contas a Pagar). O histórico das datas fica no log de auditoria
-- (gatilho auditoria_registrar de pedidos_compra) e numa linha na observação do pedido.
CREATE OR REPLACE FUNCTION public.atualizar_previsao_pedido_compra(
    p_pedido_id uuid,
    p_data_prevista date,
    p_motivo text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_ped    record;
    v_motivo text := NULLIF(trim(coalesce(p_motivo, '')), '');
BEGIN
    IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
        RAISE EXCEPTION 'Sem permissao para editar pedido de compra.' USING ERRCODE = '42501';
    END IF;
    IF p_data_prevista IS NULL THEN
        RAISE EXCEPTION 'Informe a nova data prevista.' USING ERRCODE = 'P0001';
    END IF;
    IF v_motivo IS NULL THEN
        RAISE EXCEPTION 'Informe o motivo (ex.: fornecedor avisou atraso).' USING ERRCODE = 'P0001';
    END IF;

    SELECT id, numero, status, data_prevista_entrega INTO v_ped
    FROM public.pedidos_compra WHERE id = p_pedido_id FOR UPDATE;
    IF v_ped.id IS NULL THEN
        RAISE EXCEPTION 'Pedido de compra nao encontrado.' USING ERRCODE = 'P0001';
    END IF;
    IF v_ped.status NOT IN ('aprovado', 'parcialmente_recebido') THEN
        RAISE EXCEPTION 'So pedido aprovado ou parcialmente recebido tem a previsao atualizada aqui (pedido % esta em %).',
            v_ped.numero, v_ped.status USING ERRCODE = 'P0001';
    END IF;
    IF v_ped.data_prevista_entrega IS NOT DISTINCT FROM p_data_prevista THEN
        RAISE EXCEPTION 'A data prevista ja e %.', to_char(p_data_prevista, 'DD/MM/YYYY') USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.pedidos_compra
       SET data_prevista_entrega = p_data_prevista,
           atualizado_em = now(),
           observacao = concat_ws(E'\n', NULLIF(observacao, ''),
               format('Previsao de entrega alterada de %s para %s em %s: %s',
                      coalesce(to_char(v_ped.data_prevista_entrega, 'DD/MM/YYYY'), 'sem data'),
                      to_char(p_data_prevista, 'DD/MM/YYYY'),
                      to_char(now() AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI'),
                      v_motivo))
     WHERE id = p_pedido_id;

    RETURN jsonb_build_object('pedido_id', p_pedido_id, 'numero', v_ped.numero,
                              'data_anterior', v_ped.data_prevista_entrega, 'data_nova', p_data_prevista);
END;
$function$;

REVOKE ALL ON FUNCTION public.atualizar_previsao_pedido_compra(uuid, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_previsao_pedido_compra(uuid, date, text) TO authenticated;
