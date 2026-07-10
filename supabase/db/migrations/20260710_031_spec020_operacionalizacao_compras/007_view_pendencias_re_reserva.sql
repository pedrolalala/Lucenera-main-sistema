-- Migration 20260710_031 - SPEC-020 Parte 7
-- View vw_pendencias_re_reserva: painel de Debora.
-- Mostra itens com q_entrega_futura > 0 E produto com estoque disponivel para cobrir.
-- Filtro: apenas onde qtd_pode_re_reservar > 0 (ha algo a fazer).
-- Correcao aplicada: p.codigo_produto (nao p.codigo), coalesce(o.cliente_id,...) (nao o.contato_id).

CREATE OR REPLACE VIEW public.vw_pendencias_re_reserva
WITH (security_invoker = true)
AS
SELECT
    espi.projeto_item_id,
    pi.produto_id,
    p.nome                                                                AS produto,
    p.codigo_produto                                                      AS produto_codigo,
    pi.projeto_id,
    pr.codigo                                                             AS projeto_codigo,
    pi.orcamento_id,
    o.numero                                                              AS orcamento_numero,
    coalesce(o.cliente_id, pr.cliente_id, pr.client_id)                  AS cliente_id,
    c.nome                                                                AS cliente,
    espi.q_entrega_futura,
    espi.q_reserva,
    COALESCE(ei.quantidade, 0)                                            AS qtd_fisica,
    COALESCE(ei.quantidade_reservada, 0)                                  AS qtd_comprometida,
    GREATEST(COALESCE(ei.quantidade, 0) - COALESCE(ei.quantidade_reservada, 0), 0)
                                                                          AS qtd_disponivel,
    LEAST(
        espi.q_entrega_futura,
        GREATEST(COALESCE(ei.quantidade, 0) - COALESCE(ei.quantidade_reservada, 0), 0)
    )                                                                     AS qtd_pode_re_reservar,
    espi.atualizado_em
FROM public.estoque_saldos_projeto_item espi
JOIN public.projeto_itens pi
  ON pi.id = espi.projeto_item_id
LEFT JOIN public.produtos p
  ON p.id = pi.produto_id
LEFT JOIN public.projetos pr
  ON pr.id = pi.projeto_id
LEFT JOIN public.orcamentos o
  ON o.id = pi.orcamento_id
LEFT JOIN public.contatos c
  ON c.id = coalesce(o.cliente_id, pr.cliente_id, pr.client_id)
LEFT JOIN public.estoque_itens ei
  ON ei.produto_id = pi.produto_id
 AND ei.local = 'Estoque'::public.estoque_local
WHERE espi.status_operacional = 'ativo'
  AND espi.q_entrega_futura > 0
  AND GREATEST(COALESCE(ei.quantidade, 0) - COALESCE(ei.quantidade_reservada, 0), 0) > 0;

COMMENT ON VIEW public.vw_pendencias_re_reserva IS
'SPEC-020. Painel de Debora: projeto_itens com q_entrega_futura > 0 e produto com estoque disponivel. qtd_pode_re_reservar indica o maximo transferivel de entrega_futura para reserva sem ultrapassar o disponivel.';

GRANT SELECT ON public.vw_pendencias_re_reserva TO authenticated;
