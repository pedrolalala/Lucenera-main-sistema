-- SPEC-321 — Cancelar venda aprovada com pedido de compra em andamento
-- 1) corrige cancelar_orcamento (status real 'Orçamento Aprovado'), cancela o financeiro e libera o destino dos pedidos
-- 2) previa_cancelamento_orcamento: dados do pop-up (somente leitura)
-- 3) aviso para a Compras (tabela + RLS + marcar como visto)

BEGIN;

-- ───────────────────────── aviso para a Compras ─────────────────────────
CREATE TABLE IF NOT EXISTS public.pedido_compra_aviso_cancelamento (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id          uuid NOT NULL REFERENCES public.pedidos_compra(id) ON DELETE CASCADE,
  orcamento_id       uuid NOT NULL REFERENCES public.orcamentos(id) ON DELETE CASCADE,
  orcamento_numero   text,
  venda_numero       text,
  projeto_codigo     text,
  cliente_nome       text,
  motivo             text,
  itens              jsonb NOT NULL DEFAULT '[]'::jsonb,
  cancelado_por      uuid,
  cancelado_por_nome text,
  cancelado_em       timestamptz NOT NULL DEFAULT now(),
  visto_em           timestamptz,
  visto_por          uuid
);
CREATE INDEX IF NOT EXISTS idx_pc_aviso_cancel_pedido ON public.pedido_compra_aviso_cancelamento(pedido_id);
ALTER TABLE public.pedido_compra_aviso_cancelamento ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pedido_compra_aviso_cancelamento FROM anon, PUBLIC;
GRANT SELECT ON public.pedido_compra_aviso_cancelamento TO authenticated;
DROP POLICY IF EXISTS pc_aviso_cancel_select ON public.pedido_compra_aviso_cancelamento;
CREATE POLICY pc_aviso_cancel_select ON public.pedido_compra_aviso_cancelamento
  FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('necessidade-de-compra')));

CREATE OR REPLACE FUNCTION public.marcar_aviso_cancelamento_visto(p_aviso uuid)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
BEGIN
  IF auth.uid() IS NULL OR NOT (SELECT public.pode_acessar_sistema('necessidade-de-compra')) THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  UPDATE public.pedido_compra_aviso_cancelamento SET visto_em = now(), visto_por = auth.uid()
   WHERE id = p_aviso AND visto_em IS NULL;
END $f$;
REVOKE ALL ON FUNCTION public.marcar_aviso_cancelamento_visto(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.marcar_aviso_cancelamento_visto(uuid) TO authenticated;

-- ───────────────────────── bloqueios (usado pela prévia e pelo cancelamento) ─────────────────────────
CREATE OR REPLACE FUNCTION public._bloqueios_cancelamento_orcamento(p_orcamento_id uuid)
 RETURNS text[] LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE
  o public.orcamentos%ROWTYPE;
  v text[] := '{}';
BEGIN
  SELECT * INTO o FROM public.orcamentos WHERE id = p_orcamento_id;
  IF NOT FOUND THEN RETURN v; END IF;
  IF o.status = 'cancelado' THEN RETURN v || 'Este orçamento já está cancelado.'; END IF;
  IF o.status NOT IN ('aprovado', 'Orçamento Aprovado') THEN RETURN v; END IF;

  IF o.vinculo_connect THEN
    v := v || 'Venda vinculada à Connect: use "Desfazer vínculo" antes de cancelar.';
  END IF;
  IF public.tipo_operacao_regra(o.natureza_operacao, o.subgrupo) = 'baixa_direta' THEN
    v := v || 'Esta operação já baixou o Estoque Geral: a peça volta pela Movimentação de Peças.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.projeto_parcelas pp WHERE pp.orcamento_id = p_orcamento_id AND pp.status::text = 'paga')
     OR EXISTS (SELECT 1 FROM public.financeiro_parcelas fp JOIN public.financeiro_titulos ft ON ft.id = fp.titulo_id
                 WHERE ft.orcamento_id = p_orcamento_id AND coalesce(fp.valor_liquidado, 0) <> 0) THEN
    v := v || 'Há parcela paga: estorne a baixa no financeiro antes de cancelar.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.boletos b WHERE b.orcamento_id = p_orcamento_id
              AND b.status NOT IN ('pendente_registro', 'Pendente', 'pendente', 'Cancelado', 'cancelado')) THEN
    v := v || 'Há boleto já registrado ou pago: cancelar só pelo banco ou pelo TI.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notas_fiscais nf JOIN public.boletos b ON b.id = nf.boleto_id WHERE b.orcamento_id = p_orcamento_id) THEN
    v := v || 'Há nota fiscal emitida sobre a venda.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.estoque_saldos_projeto_item s JOIN public.projeto_itens pi ON pi.id = s.projeto_item_id
              WHERE pi.orcamento_id = p_orcamento_id AND s.status_operacional = 'ativo'
                AND (s.q_ag_separar > 0 OR s.q_separado > 0 OR s.q_entregue > 0)) THEN
    v := v || 'Há peça separada ou entregue: trate pela Devolução antes de cancelar.';
  END IF;
  RETURN v;
END $f$;
REVOKE ALL ON FUNCTION public._bloqueios_cancelamento_orcamento(uuid) FROM PUBLIC, anon, authenticated;

-- ───────────────────────── prévia (pop-up) ─────────────────────────
CREATE OR REPLACE FUNCTION public.previa_cancelamento_orcamento(p_orcamento_id uuid)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $f$
DECLARE
  o public.orcamentos%ROWTYPE;
  v_bloqueios text[];
  v_pedidos jsonb;
  v_quem text;
  v_cliente text;
  v_proj text;
BEGIN
  IF auth.uid() IS NULL OR NOT (SELECT public.pode_acessar_sistema('orcamentos')) THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO o FROM public.orcamentos WHERE id = p_orcamento_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001'; END IF;
  SELECT nome INTO v_quem FROM public.usuarios WHERE id = auth.uid();
  SELECT c.nome INTO v_cliente FROM public.contatos c WHERE c.id = o.cliente_id;
  SELECT pr.codigo::text INTO v_proj FROM public.projetos pr WHERE pr.id = o.projeto_id;
  v_bloqueios := public._bloqueios_cancelamento_orcamento(p_orcamento_id);

  SELECT coalesce(jsonb_agg(q.x ORDER BY q.x->>'numero'), '[]'::jsonb) INTO v_pedidos FROM (
    SELECT jsonb_build_object(
      'pedido_id', pc.id, 'numero', pc.numero, 'status', pc.status,
      'fornecedor', f.nome, 'previsao', pc.data_prevista_entrega,
      'itens', (SELECT jsonb_agg(jsonb_build_object('produto', p.nome, 'codigo', p.codigo_produto,
                                                    'quantidade', t.qtd, 'recebida', t.rec) ORDER BY p.nome)
                  FROM (SELECT i.produto_id, sum(i.quantidade) qtd, sum(coalesce(i.qtd_recebida, 0)) rec
                          FROM public.pedido_compra_itens i WHERE i.pedido_id = pc.id AND i.id = ANY (ids.itens)
                         GROUP BY i.produto_id) t
                  JOIN public.produtos p ON p.id = t.produto_id)
    ) AS x
    FROM (
      SELECT i.pedido_id, array_agg(DISTINCT i.id) AS itens
        FROM public.pedido_compra_itens i
       WHERE i.id IN (SELECT o2.pedido_compra_item_id FROM public.pedido_compra_item_origem o2
                        JOIN public.projeto_itens pi ON pi.id = o2.projeto_item_id WHERE pi.orcamento_id = p_orcamento_id)
          OR i.id IN (SELECT d.pedido_compra_item_id FROM public.pedido_compra_item_destino_projeto d
                       WHERE d.projeto_id = o.projeto_id AND d.liberado_em IS NULL)
       GROUP BY i.pedido_id
    ) ids
    JOIN public.pedidos_compra pc ON pc.id = ids.pedido_id AND pc.status NOT IN ('cancelado', 'recebido')
    LEFT JOIN public.contatos f ON f.id = pc.fornecedor_id
  ) q;

  RETURN jsonb_build_object(
    'orcamento_id', o.id, 'numero', o.numero, 'venda', o.numero_venda, 'status', o.status,
    'cliente', v_cliente, 'projeto_codigo', v_proj,
    'venda_efetivada', (o.status IN ('aprovado', 'Orçamento Aprovado')),
    'cancelando', jsonb_build_object('id', auth.uid(), 'nome', coalesce(v_quem, 'Usuário'), 'em', now()),
    'pedidos', v_pedidos,
    'parcelas_abertas', (SELECT count(*) FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id AND status::text = 'pendente'),
    'bloqueios', to_jsonb(v_bloqueios),
    'pode_cancelar', (cardinality(v_bloqueios) = 0)
  );
END $f$;
REVOKE ALL ON FUNCTION public.previa_cancelamento_orcamento(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.previa_cancelamento_orcamento(uuid) TO authenticated;

-- ───────────────────────── cancelar_orcamento (corrigida) ─────────────────────────
CREATE OR REPLACE FUNCTION public.cancelar_orcamento(p_orcamento_id uuid, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_orcamento           public.orcamentos%ROWTYPE;
    v_status_anterior     text;
    v_numero_orcamento    text;
    v_efetivada           boolean;
    v_bloqueios           text[];
    v_quem                text;
    v_cliente             text;
    v_proj                text;
    v_reservas_revertidas integer := 0;
    v_parcelas_canceladas integer := 0;
    v_boletos_cancelados  integer := 0;
    v_itens_invalidados   integer := 0;
    v_saldos_cancelados   integer := 0;
    v_titulos_cancelados  integer := 0;
    v_destinos_liberados  integer := 0;
    v_avisos              integer := 0;
    v_ped                 record;
BEGIN
    -- 0. Permissão (antes qualquer um — inclusive anon — executava)
    IF auth.uid() IS NOT NULL THEN
        IF NOT (SELECT public.pode_acessar_sistema('orcamentos')) THEN
            RAISE EXCEPTION 'Sem permissão para cancelar orçamento.' USING ERRCODE = '42501';
        END IF;
    ELSIF coalesce(auth.role(), '') <> 'service_role' AND current_user NOT IN ('postgres', 'supabase_admin') THEN
        RAISE EXCEPTION 'Sem permissão para cancelar orçamento.' USING ERRCODE = '42501';
    END IF;

    -- 1. Carregar e travar o orçamento
    SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id USING ERRCODE = 'P0001';
    END IF;

    v_status_anterior  := v_orcamento.status;
    v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));
    v_efetivada        := v_status_anterior IN ('aprovado', 'Orçamento Aprovado');

    -- 2. Idempotência: já cancelado
    IF v_status_anterior = 'cancelado' THEN
        RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero', v_numero_orcamento, 'status', 'cancelado',
            'reservas_revertidas', 0, 'parcelas_canceladas', 0, 'boletos_cancelados', 0, 'itens_invalidados', 0,
            'saldos_cancelados', 0, 'ja_cancelado', true);
    END IF;

    IF v_efetivada THEN
        IF length(btrim(coalesce(p_motivo, ''))) = 0 THEN
            RAISE EXCEPTION 'Informe o motivo do cancelamento da venda.' USING ERRCODE = 'P0001';
        END IF;
        -- 2b. Bloqueios (nada pago, registrado, separado ou entregue; Connect; baixa direta)
        v_bloqueios := public._bloqueios_cancelamento_orcamento(p_orcamento_id);
        IF cardinality(v_bloqueios) > 0 THEN
            RAISE EXCEPTION 'Orçamento % não pode ser cancelado: %', v_numero_orcamento, v_bloqueios[1] USING ERRCODE = 'P0001';
        END IF;
    END IF;

    SELECT nome INTO v_quem FROM public.usuarios WHERE id = auth.uid();
    SELECT c.nome INTO v_cliente FROM public.contatos c WHERE c.id = v_orcamento.cliente_id;
    SELECT pr.codigo::text INTO v_proj FROM public.projetos pr WHERE pr.id = v_orcamento.projeto_id;

    -- 3. Venda efetivada → desfazer todos os efeitos da aprovação
    IF v_efetivada THEN

        -- 3.0 Pedidos de compra em andamento (SPEC-321): grava o aviso para a Compras ANTES de soltar o vínculo
        FOR v_ped IN
            SELECT ids.pedido_id,
                   (SELECT jsonb_agg(jsonb_build_object('produto', p.nome, 'codigo', p.codigo_produto, 'quantidade', t.qtd) ORDER BY p.nome)
                      FROM (SELECT i.produto_id, sum(i.quantidade) qtd FROM public.pedido_compra_itens i
                             WHERE i.pedido_id = ids.pedido_id AND i.id = ANY (ids.itens) GROUP BY i.produto_id) t
                      JOIN public.produtos p ON p.id = t.produto_id) AS itens
              FROM (
                SELECT i.pedido_id, array_agg(DISTINCT i.id) AS itens
                  FROM public.pedido_compra_itens i
                 WHERE i.id IN (SELECT o2.pedido_compra_item_id FROM public.pedido_compra_item_origem o2
                                  JOIN public.projeto_itens pi ON pi.id = o2.projeto_item_id WHERE pi.orcamento_id = p_orcamento_id)
                    OR i.id IN (SELECT d.pedido_compra_item_id FROM public.pedido_compra_item_destino_projeto d
                                 WHERE d.projeto_id = v_orcamento.projeto_id AND d.liberado_em IS NULL)
                 GROUP BY i.pedido_id
              ) ids
              JOIN public.pedidos_compra pc ON pc.id = ids.pedido_id AND pc.status NOT IN ('cancelado', 'recebido')
        LOOP
            INSERT INTO public.pedido_compra_aviso_cancelamento
                (pedido_id, orcamento_id, orcamento_numero, venda_numero, projeto_codigo, cliente_nome, motivo, itens, cancelado_por, cancelado_por_nome)
            VALUES (v_ped.pedido_id, p_orcamento_id, v_numero_orcamento, v_orcamento.numero_venda, v_proj, v_cliente,
                    btrim(p_motivo), coalesce(v_ped.itens, '[]'::jsonb), auth.uid(), coalesce(v_quem, 'Usuário'));
            v_avisos := v_avisos + 1;
        END LOOP;

        -- Reserva de pedido para o projeto: só solta se nenhuma outra venda ativa do mesmo projeto pode usá-la
        IF v_orcamento.projeto_id IS NOT NULL AND NOT EXISTS (
               SELECT 1 FROM public.orcamentos o3
                WHERE o3.projeto_id = v_orcamento.projeto_id AND o3.id <> p_orcamento_id
                  AND o3.status IN ('Orçamento Aprovado', 'Aprovação Financeira', 'Aprovação da Equipe', 'enviado_cliente', 'aprovado')) THEN
            UPDATE public.pedido_compra_item_destino_projeto
               SET liberado_em = now(), liberado_por = auth.uid(),
                   motivo_liberacao = left('Cancelamento da venda ' || coalesce(v_orcamento.numero_venda, v_numero_orcamento)
                                           || ' por ' || coalesce(v_quem, 'usuário') || ': ' || btrim(p_motivo), 500)
             WHERE projeto_id = v_orcamento.projeto_id AND liberado_em IS NULL;
            GET DIAGNOSTICS v_destinos_liberados = ROW_COUNT;
        END IF;
        -- pedido_compra_item_origem é só informativo: o saldo de entrega futura zerado abaixo já tira o item da sugestão da entrada de NF

        -- 3a. Reverter reservas de estoque físico pelo saldo aberto real do item (SPEC-010)
        UPDATE public.estoque_itens ei
        SET quantidade_reservada = GREATEST(0, ei.quantidade_reservada - aberto.qtd_aberta),
            atualizado_em        = NOW()
        FROM (
            SELECT pi.produto_id,
                   SUM(esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_aberta
            FROM public.projeto_itens pi
            JOIN public.estoque_saldos_projeto_item esp ON esp.projeto_item_id = pi.id
            WHERE pi.orcamento_id = p_orcamento_id AND esp.status_operacional = 'ativo'
            GROUP BY pi.produto_id
        ) aberto
        WHERE ei.produto_id = aberto.produto_id
          AND ei.local      = 'Estoque'::public.estoque_local
          AND aberto.qtd_aberta > 0;
        GET DIAGNOSTICS v_reservas_revertidas = ROW_COUNT;

        -- 3b. Cancelar parcelas (o gatilho cancela a transação ligada)
        UPDATE public.projeto_parcelas SET status = 'cancelada'::public.parcela_status
         WHERE orcamento_id = p_orcamento_id AND status = 'pendente'::public.parcela_status;
        GET DIAGNOSTICS v_parcelas_canceladas = ROW_COUNT;

        -- 3c. Cancelar boletos ainda não registrados
        UPDATE public.boletos SET status = 'Cancelado',
               observacao = btrim(coalesce(observacao || E'\n', '') || 'Cancelado em '
                            || to_char(now() AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI')
                            || ' (cancelamento da venda): ' || btrim(p_motivo))
         WHERE orcamento_id = p_orcamento_id AND status IN ('pendente_registro', 'Pendente', 'pendente');
        GET DIAGNOSTICS v_boletos_cancelados = ROW_COUNT;

        -- 3c2. Financeiro novo (SPEC-258): parcelas previstas/firmes e título da venda
        UPDATE public.financeiro_parcelas fp SET situacao = 'cancelada'
          FROM public.financeiro_titulos ft
         WHERE ft.id = fp.titulo_id AND ft.orcamento_id = p_orcamento_id AND ft.cancelado_em IS NULL
           AND fp.situacao IN ('prevista', 'firme');
        UPDATE public.financeiro_titulos
           SET cancelado_em = now(), cancelado_por = auth.uid(),
               motivo_cancelamento = left('Cancelamento da venda ' || coalesce(v_orcamento.numero_venda, v_numero_orcamento)
                                          || ': ' || btrim(p_motivo), 500)
         WHERE orcamento_id = p_orcamento_id AND cancelado_em IS NULL;
        GET DIAGNOSTICS v_titulos_cancelados = ROW_COUNT;

        -- 3d. Invalidar projeto_itens (preserva histórico)
        UPDATE public.projeto_itens SET validado = false WHERE orcamento_id = p_orcamento_id AND validado = true;
        GET DIAGNOSTICS v_itens_invalidados = ROW_COUNT;

        -- 3e. Encerrar o saldo operacional do item (SPEC-010)
        WITH antes AS (
            SELECT esp.projeto_item_id, (esp.q_reserva + esp.q_entrega_futura + esp.q_ag_separar + esp.q_separado) AS qtd_aberta
            FROM public.estoque_saldos_projeto_item esp
            JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
            WHERE pi.orcamento_id = p_orcamento_id AND esp.status_operacional = 'ativo'
        ),
        cancelados AS (
            UPDATE public.estoque_saldos_projeto_item esp
            SET status_operacional = 'cancelado', q_reserva = 0, q_entrega_futura = 0, q_ag_separar = 0, q_separado = 0
            FROM public.projeto_itens pi
            WHERE pi.id = esp.projeto_item_id AND pi.orcamento_id = p_orcamento_id AND esp.status_operacional = 'ativo'
            RETURNING esp.projeto_item_id
        )
        INSERT INTO public.estoque_movimentos_projeto_item (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
        SELECT c.projeto_item_id, 'cancelamento', antes.qtd_aberta, 'cancelar_orcamento', p_orcamento_id,
               coalesce(p_motivo, 'Cancelamento do orçamento ' || v_numero_orcamento), auth.uid()
        FROM cancelados c JOIN antes ON antes.projeto_item_id = c.projeto_item_id
        WHERE antes.qtd_aberta > 0;
        GET DIAGNOSTICS v_saldos_cancelados = ROW_COUNT;
    END IF;

    -- 4. Status
    UPDATE public.orcamentos SET status = 'cancelado' WHERE id = p_orcamento_id;

    -- 5. Histórico (quem, motivo, pedidos avisados)
    INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
    VALUES (p_orcamento_id, v_status_anterior, 'cancelado', auth.uid()::text,
            coalesce(btrim(p_motivo), 'Cancelamento via RPC cancelar_orcamento')
            || CASE WHEN v_avisos > 0
                    THEN format(' | %s pedido(s) de compra em andamento liberado(s): as peças entram no Estoque Geral ao chegar', v_avisos)
                    ELSE '' END
            || ' | Cancelado por ' || coalesce(v_quem, 'usuário'));

    -- 6. Log de atividade (SPEC-318) — nunca derruba o cancelamento
    BEGIN
        PERFORM auditoria.inserir(auth.uid(), 'orcamentos', 'cancelou_venda', 'orcamentos', p_orcamento_id::text,
            coalesce(v_orcamento.numero_venda, v_numero_orcamento),
            jsonb_build_object('motivo', btrim(p_motivo), 'status_anterior', v_status_anterior, 'pedidos_avisados', v_avisos,
                               'titulos_cancelados', v_titulos_cancelados, 'destinos_liberados', v_destinos_liberados));
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id, 'numero', v_numero_orcamento, 'status', 'cancelado', 'status_anterior', v_status_anterior,
        'reservas_revertidas', v_reservas_revertidas, 'parcelas_canceladas', v_parcelas_canceladas,
        'boletos_cancelados', v_boletos_cancelados, 'itens_invalidados', v_itens_invalidados,
        'saldos_cancelados', v_saldos_cancelados, 'titulos_cancelados', v_titulos_cancelados,
        'destinos_liberados', v_destinos_liberados, 'pedidos_avisados', v_avisos, 'ja_cancelado', false);
END;
$function$;
REVOKE ALL ON FUNCTION public.cancelar_orcamento(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancelar_orcamento(uuid, text) TO authenticated, service_role;

COMMIT;
