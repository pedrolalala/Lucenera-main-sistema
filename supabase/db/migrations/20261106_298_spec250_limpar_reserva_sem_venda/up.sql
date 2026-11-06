-- SPEC-250: tira do sistema a "reserva sem venda (herança Connect)" que ficou em trânsito (peça que estava em separação na Connect
-- na hora da carga, sem venda, e que a Connect já deu baixa). A quantidade vem das LISTAS DE ENTREGA baixadas pelo Matheus (por peça);
-- nunca "tudo": a mesma conta mistura trânsito com reserva legítima da Connect sem cliente.
-- Efeito por peça (mesma conta do Tratar "entregue, baixa estoque" da SPEC-243): reserva sem venda -q, Estoque Geral -q, reservado -q.
-- O Disponível (Geral - reservado) e a Separação não mudam. Modo teste (p_aplicar = false, padrão) só devolve o que faria.
-- Só Matheus e administração (pode_tratar_heranca_connect). Tudo ou nada: se uma peça não puder, nada é aplicado.
CREATE OR REPLACE FUNCTION public.limpar_reserva_sem_venda_connect(
    p_itens   jsonb,                   -- [{"codigo": 12757, "quantidade": 1}, ...]  (codigo = produtos.codigo_produto)
    p_aplicar boolean DEFAULT false,
    p_motivo  text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_it      jsonb;
    v_cod     integer;
    v_q       numeric;
    v_prod    uuid;
    v_nome    text;
    v_geral   numeric;
    v_reserv  numeric;
    v_sv      numeric;
    v_res     jsonb := '[]'::jsonb;
    v_erros   integer := 0;
    v_msg     text;
    v_motivo  text := nullif(btrim(coalesce(p_motivo, '')), '');
BEGIN
    IF NOT public.pode_tratar_heranca_connect() THEN
        RAISE EXCEPTION 'Só o Matheus ou um administrador pode limpar a reserva sem venda da Connect.' USING ERRCODE = '42501';
    END IF;
    IF p_itens IS NULL OR jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
        RAISE EXCEPTION 'Informe a lista de peças e quantidades.' USING ERRCODE = 'P0001';
    END IF;
    IF p_aplicar AND v_motivo IS NULL THEN
        RAISE EXCEPTION 'Informe o motivo (ex.: listas de entrega de 05/11 baixadas na Connect).' USING ERRCODE = 'P0001';
    END IF;

    FOR v_it IN SELECT * FROM jsonb_array_elements(p_itens) LOOP
        v_msg := NULL;
        v_prod := NULL; v_nome := NULL; v_geral := NULL; v_reserv := NULL; v_sv := NULL;
        v_cod := nullif(v_it->>'codigo', '')::integer;
        v_q   := nullif(v_it->>'quantidade', '')::numeric;

        SELECT p.id, p.nome INTO v_prod, v_nome FROM public.produtos p WHERE p.codigo_produto = v_cod;
        IF v_prod IS NULL THEN
            v_msg := 'peça não encontrada';
        ELSIF v_q IS NULL OR v_q <= 0 THEN
            v_msg := 'quantidade inválida';
        ELSE
            SELECT ei.quantidade, ei.quantidade_reservada INTO v_geral, v_reserv
              FROM public.estoque_itens ei
             WHERE ei.produto_id = v_prod AND ei.local = 'Estoque'::public.estoque_local FOR UPDATE;
            -- mesma conta do Cadastro (estoque-sectors.ts): reservado - (reserva + entrega futura + separação, sistema e Connect)
            SELECT coalesce(v_reserv, 0) - coalesce(s.q_reserva, 0) - coalesce(s.q_entrega_futura, 0) - coalesce(s.q_separacao, 0)
                   - coalesce(s.q_reserva_connect, 0) - coalesce(s.q_entrega_futura_connect, 0)
              INTO v_sv
              FROM (SELECT 1) x LEFT JOIN public.vw_cadastro_produto_setores s ON s.produto_id = v_prod;
            IF v_geral IS NULL THEN
                v_msg := 'peça sem Estoque Geral';
            ELSIF v_q > v_sv THEN
                v_msg := format('quantidade %s maior que a reserva sem venda (%s)', v_q, v_sv);
            ELSIF v_q > v_geral THEN
                v_msg := format('quantidade %s maior que o Estoque Geral (%s)', v_q, v_geral);
            END IF;
        END IF;

        IF v_msg IS NOT NULL THEN v_erros := v_erros + 1; END IF;
        v_res := v_res || jsonb_build_array(jsonb_build_object(
            'codigo', v_cod, 'peca', v_nome, 'quantidade', v_q,
            'reserva_sem_venda_antes', v_sv, 'geral_antes', v_geral,
            'geral_depois', CASE WHEN v_msg IS NULL THEN v_geral - v_q END,
            'reserva_sem_venda_depois', CASE WHEN v_msg IS NULL THEN v_sv - v_q END,
            'erro', v_msg));
    END LOOP;

    IF NOT p_aplicar THEN
        RETURN jsonb_build_object('aplicado', false, 'erros', v_erros, 'itens', v_res);
    END IF;
    IF v_erros > 0 THEN
        RAISE EXCEPTION 'Nada foi aplicado: % peça(s) com problema. %', v_erros, v_res::text USING ERRCODE = 'P0001';
    END IF;

    FOR v_it IN SELECT * FROM jsonb_array_elements(p_itens) LOOP
        v_cod := (v_it->>'codigo')::integer;
        v_q   := (v_it->>'quantidade')::numeric;
        SELECT p.id INTO v_prod FROM public.produtos p WHERE p.codigo_produto = v_cod;
        SELECT quantidade INTO v_geral FROM public.estoque_itens WHERE produto_id = v_prod AND local = 'Estoque'::public.estoque_local;
        UPDATE public.estoque_itens
           SET quantidade = quantidade - v_q,
               quantidade_reservada = GREATEST(quantidade_reservada - v_q, 0),
               atualizado_por = auth.uid(), atualizado_em = now()
         WHERE produto_id = v_prod AND local = 'Estoque'::public.estoque_local;
        INSERT INTO public.movimentacoes_peca
            (produto_id, quantidade, tipo, origem, destino, motivo, saldo_origem_antes, saldo_origem_depois,
             saldo_destino_antes, saldo_destino_depois, criado_por)
        VALUES (v_prod, v_q, 'setor', 'Reserva sem venda (herança Connect)', 'Baixa (entregue na Connect)',
                left(v_motivo, 500), v_geral, v_geral - v_q, NULL, NULL, auth.uid());
    END LOOP;

    RETURN jsonb_build_object('aplicado', true, 'erros', 0, 'itens', v_res);
END;
$function$;

REVOKE ALL ON FUNCTION public.limpar_reserva_sem_venda_connect(jsonb, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.limpar_reserva_sem_venda_connect(jsonb, boolean, text) TO authenticated;
