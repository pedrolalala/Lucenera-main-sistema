-- SPEC-299 (Reuniao 56, 13/11/2026): pedido de compra ADIANTADO para uma venda que ainda nao passou.
-- O item do pedido pode ser RESERVADO para um projeto (codigo do projeto) com quantidade exata. A quantidade reservada:
--  * nao cobre a necessidade de OUTRAS vendas (a venda do meio abre necessidade normal);
--  * quando o projeto vira venda (entrega futura), cobre so os itens daquele projeto;
--  * na entrada da NF vem sugerida para o projeto (frontend), com opcao de retirar o vinculo.
-- Sem a reserva tudo se comporta como antes. Nao mexe em dado existente; so tabela nova, RPCs novas e 2 views recriadas
-- (mesmas colunas). Rollback: rollback.sql.
BEGIN;

-- 1) Tabela --------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pedido_compra_item_destino_projeto (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_compra_item_id uuid NOT NULL REFERENCES public.pedido_compra_itens(id) ON DELETE CASCADE,
  projeto_id            uuid NOT NULL REFERENCES public.projetos(id) ON DELETE RESTRICT,
  quantidade            numeric(12,3) NOT NULL CHECK (quantidade > 0),
  criado_por            uuid REFERENCES auth.users(id),
  criado_em             timestamptz NOT NULL DEFAULT now(),
  liberado_em           timestamptz,
  liberado_por          uuid REFERENCES auth.users(id),
  motivo_liberacao      text
);
COMMENT ON TABLE public.pedido_compra_item_destino_projeto IS
'SPEC-299. Quantidade de um item de pedido de compra RESERVADA para um projeto (compra adiantada de venda ainda nao passada). Reserva ativa = liberado_em IS NULL. Nao cobre outras vendas; escrita so por RPC.';
CREATE UNIQUE INDEX IF NOT EXISTS uq_pcidp_item_projeto_ativo ON public.pedido_compra_item_destino_projeto (pedido_compra_item_id, projeto_id) WHERE liberado_em IS NULL;
CREATE INDEX IF NOT EXISTS idx_pcidp_projeto ON public.pedido_compra_item_destino_projeto (projeto_id) WHERE liberado_em IS NULL;
CREATE INDEX IF NOT EXISTS idx_pcidp_item    ON public.pedido_compra_item_destino_projeto (pedido_compra_item_id);

ALTER TABLE public.pedido_compra_item_destino_projeto ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pedido_compra_item_destino_projeto FROM PUBLIC, anon;
GRANT SELECT ON public.pedido_compra_item_destino_projeto TO authenticated;
DROP POLICY IF EXISTS pcidp_select ON public.pedido_compra_item_destino_projeto;
CREATE POLICY pcidp_select ON public.pedido_compra_item_destino_projeto
  FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('necessidade-de-compra')));

-- 2) RPCs ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reservar_pedido_item_para_projeto(p_pedido_item uuid, p_projeto uuid, p_quantidade numeric)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE v_item public.pedido_compra_itens; v_status text; v_pend numeric; v_outras numeric; v_id uuid;
BEGIN
  IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para reservar pedido de compra.' USING ERRCODE = '42501';
  END IF;
  IF p_quantidade IS NULL OR p_quantidade <= 0 THEN RAISE EXCEPTION 'Informe a quantidade a reservar.' USING ERRCODE = 'P0001'; END IF;
  SELECT * INTO v_item FROM public.pedido_compra_itens WHERE id = p_pedido_item FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Item do pedido nao encontrado.' USING ERRCODE = 'P0001'; END IF;
  SELECT status INTO v_status FROM public.pedidos_compra WHERE id = v_item.pedido_id;
  IF v_status IN ('recebido','cancelado') THEN RAISE EXCEPTION 'Pedido % nao aceita reserva.', v_status USING ERRCODE = 'P0001'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.projetos WHERE id = p_projeto) THEN RAISE EXCEPTION 'Projeto nao encontrado.' USING ERRCODE = 'P0001'; END IF;
  v_pend := GREATEST(v_item.quantidade - coalesce(v_item.qtd_recebida, 0), 0);
  SELECT coalesce(sum(quantidade), 0) INTO v_outras FROM public.pedido_compra_item_destino_projeto
   WHERE pedido_compra_item_id = p_pedido_item AND liberado_em IS NULL AND projeto_id <> p_projeto;
  IF v_outras + p_quantidade > v_pend THEN
    RAISE EXCEPTION 'A soma das reservas (%) passa do que falta chegar neste item (%).', v_outras + p_quantidade, v_pend USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO public.pedido_compra_item_destino_projeto (pedido_compra_item_id, projeto_id, quantidade, criado_por)
  VALUES (p_pedido_item, p_projeto, p_quantidade, auth.uid())
  ON CONFLICT (pedido_compra_item_id, projeto_id) WHERE liberado_em IS NULL DO UPDATE SET quantidade = EXCLUDED.quantidade
  RETURNING id INTO v_id;
  RETURN v_id;
END $f$;

CREATE OR REPLACE FUNCTION public.liberar_destino_projeto_pedido_item(p_destino uuid, p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
BEGIN
  IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para liberar reserva.' USING ERRCODE = '42501';
  END IF;
  IF length(btrim(coalesce(p_motivo, ''))) = 0 THEN RAISE EXCEPTION 'Informe o motivo da liberacao.' USING ERRCODE = 'P0001'; END IF;
  UPDATE public.pedido_compra_item_destino_projeto
     SET liberado_em = now(), liberado_por = auth.uid(), motivo_liberacao = btrim(p_motivo)
   WHERE id = p_destino AND liberado_em IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Reserva nao encontrada ou ja liberada.' USING ERRCODE = 'P0001'; END IF;
END $f$;

-- Reservas (ativas e liberadas) dos itens de um pedido, com projeto e cliente
CREATE OR REPLACE FUNCTION public.destinos_projeto_do_pedido(p_pedido_id uuid)
RETURNS TABLE(id uuid, pedido_compra_item_id uuid, produto_id uuid, projeto_id uuid, projeto_codigo text, projeto_nome text,
              cliente_nome text, quantidade numeric, liberado_em timestamptz, motivo_liberacao text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $f$
BEGIN
  IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, NULL) THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT d.id, d.pedido_compra_item_id, pci.produto_id, d.projeto_id, pr.codigo::text, pr.nome::text,
         coalesce(c.nome, '-')::text, d.quantidade, d.liberado_em, d.motivo_liberacao
    FROM public.pedido_compra_item_destino_projeto d
    JOIN public.pedido_compra_itens pci ON pci.id = d.pedido_compra_item_id
    JOIN public.projetos pr ON pr.id = d.projeto_id
    LEFT JOIN public.contatos c ON c.id = pr.cliente_id
   WHERE pci.pedido_id = p_pedido_id
   ORDER BY d.criado_em;
END $f$;

-- Busca de projeto para reservar (codigo, nome do projeto ou cliente). Com produto, marca quem tem a peca num
-- orcamento ainda nao aprovado (rascunho / enviado ao cliente / aprovacao financeira) e traz esses primeiro.
CREATE OR REPLACE FUNCTION public.buscar_projetos_para_reserva(p_busca text DEFAULT NULL, p_produto_id uuid DEFAULT NULL)
RETURNS TABLE(projeto_id uuid, projeto_codigo text, projeto_nome text, cliente_nome text, orcamento_numero text,
              orcamento_status text, tem_a_peca boolean, qtd_da_peca numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $f$
DECLARE v_busca text := '%' || btrim(coalesce(p_busca, '')) || '%';
BEGIN
  IF NOT hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, NULL) THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT x.projeto_id, x.projeto_codigo, x.projeto_nome, x.cliente_nome, x.orcamento_numero, x.orcamento_status, x.tem_a_peca, x.qtd_da_peca
  FROM (
    SELECT DISTINCT ON (pr.id) pr.id AS projeto_id, pr.codigo::text AS projeto_codigo, pr.nome::text AS projeto_nome,
           coalesce(c.nome, '-')::text AS cliente_nome, o.numero::text AS orcamento_numero, o.status::text AS orcamento_status,
           (p_produto_id IS NOT NULL AND coalesce(q.qtd, 0) > 0) AS tem_a_peca, coalesce(q.qtd, 0) AS qtd_da_peca, o.created_at AS o_criado
      FROM public.orcamentos o
      JOIN public.projetos pr ON pr.id = o.projeto_id
      LEFT JOIN public.contatos c ON c.id = coalesce(o.cliente_id, pr.cliente_id)
      LEFT JOIN LATERAL (SELECT sum(oi.quantidade) AS qtd FROM public.orcamento_itens oi
                          WHERE oi.orcamento_id = o.id AND oi.produto_id = p_produto_id) q ON true
     WHERE coalesce(pr.arquivado, false) = false
       AND o.status IN ('rascunho', 'enviado_cliente', 'Aprovação Financeira')
       AND (btrim(coalesce(p_busca, '')) = '' OR pr.codigo ILIKE v_busca OR pr.nome ILIKE v_busca OR c.nome ILIKE v_busca)
     ORDER BY pr.id, (coalesce(q.qtd, 0) > 0) DESC, o.created_at DESC
  ) x
  ORDER BY x.tem_a_peca DESC, x.o_criado DESC
  LIMIT 25;
END $f$;

REVOKE ALL ON FUNCTION public.reservar_pedido_item_para_projeto(uuid, uuid, numeric) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.liberar_destino_projeto_pedido_item(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.destinos_projeto_do_pedido(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.buscar_projetos_para_reserva(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reservar_pedido_item_para_projeto(uuid, uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.liberar_destino_projeto_pedido_item(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.destinos_projeto_do_pedido(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.buscar_projetos_para_reserva(text, uuid) TO authenticated;

-- 3) Necessidade por peca: reserva de projeto nao cobre outras vendas -----------------------------------------------
CREATE OR REPLACE VIEW public.vw_necessidade_compra_pedidos_abertos
WITH (security_invoker = true) AS
 WITH pedidos_abertos AS (
         SELECT pci.produto_id, pc.id AS pedido_id, pc.status, pc.data_prevista_entrega,
                (pci.quantidade - pci.qtd_recebida) AS qtd_pendente_item
           FROM pedido_compra_itens pci
           JOIN pedidos_compra pc ON pc.id = pci.pedido_id
          WHERE pc.status <> ALL (ARRAY['recebido'::text, 'cancelado'::text])
        ), pedido_mais_urgente AS (
         SELECT DISTINCT ON (pedidos_abertos.produto_id) pedidos_abertos.produto_id, pedidos_abertos.status AS status_mais_critico
           FROM pedidos_abertos
          ORDER BY pedidos_abertos.produto_id, pedidos_abertos.data_prevista_entrega, pedidos_abertos.pedido_id
        ), reservas AS (
         -- SPEC-299: reservado para projeto (ativo), limitado ao que ainda falta chegar no item
         SELECT pci.produto_id, d.projeto_id,
                sum(LEAST(d.quantidade, GREATEST(pci.quantidade - pci.qtd_recebida, 0))) AS qtd
           FROM pedido_compra_item_destino_projeto d
           JOIN pedido_compra_itens pci ON pci.id = d.pedido_compra_item_id
           JOIN pedidos_compra pc ON pc.id = pci.pedido_id
          WHERE d.liberado_em IS NULL AND pc.status <> ALL (ARRAY['recebido'::text, 'cancelado'::text])
          GROUP BY pci.produto_id, d.projeto_id
        ), ef_projeto AS (
         SELECT pi.produto_id, pi.projeto_id, sum(esp.q_entrega_futura) AS qtd
           FROM estoque_saldos_projeto_item esp
           JOIN projeto_itens pi ON pi.id = esp.projeto_item_id
          WHERE esp.status_operacional = 'ativo'::text AND esp.q_entrega_futura > 0
          GROUP BY pi.produto_id, pi.projeto_id
        ), reserva_produto AS (
         SELECT r.produto_id, sum(r.qtd) AS reservado, sum(LEAST(r.qtd, coalesce(ef.qtd, 0))) AS cobre_projeto
           FROM reservas r
           LEFT JOIN ef_projeto ef ON ef.produto_id = r.produto_id AND ef.projeto_id = r.projeto_id
          GROUP BY r.produto_id
        )
 SELECT pa.produto_id,
    count(DISTINCT pa.pedido_id) AS qtd_pedidos_abertos,
    GREATEST(sum(pa.qtd_pendente_item) - coalesce(rp.reservado, 0) + coalesce(rp.cobre_projeto, 0), 0::numeric) AS qtd_em_pedidos_abertos,
    min(pa.data_prevista_entrega) AS proxima_data_prevista_entrega,
    pmu.status_mais_critico
   FROM pedidos_abertos pa
   JOIN pedido_mais_urgente pmu ON pmu.produto_id = pa.produto_id
   LEFT JOIN reserva_produto rp ON rp.produto_id = pa.produto_id
  GROUP BY pa.produto_id, pmu.status_mais_critico, rp.reservado, rp.cobre_projeto;

-- 4) Necessidade por item de orcamento (L): a reserva do projeto cobre os L do proprio projeto -----------------------
CREATE OR REPLACE VIEW public.vw_necessidade_compra_item_orcamento AS
 WITH cobertura_pedidos AS (
         SELECT pcio.projeto_item_id, sum(pcio.quantidade_atendida) AS qtd_coberta_por_pedido_aberto
           FROM pedido_compra_item_origem pcio
           JOIN pedido_compra_itens pci ON pci.id = pcio.pedido_compra_item_id
           JOIN pedidos_compra pc ON pc.id = pci.pedido_id
          WHERE (pc.status <> ALL (ARRAY['recebido'::text, 'cancelado'::text])) AND pcio.quantidade_atendida IS NOT NULL
          GROUP BY pcio.projeto_item_id
        ), reserva_projeto AS (
         SELECT pci.produto_id, d.projeto_id,
                sum(LEAST(d.quantidade, GREATEST(pci.quantidade - pci.qtd_recebida, 0))) AS qtd
           FROM pedido_compra_item_destino_projeto d
           JOIN pedido_compra_itens pci ON pci.id = d.pedido_compra_item_id
           JOIN pedidos_compra pc ON pc.id = pci.pedido_id
          WHERE d.liberado_em IS NULL AND pc.status <> ALL (ARRAY['recebido'::text, 'cancelado'::text])
          GROUP BY pci.produto_id, d.projeto_id
        ), base0 AS (
         SELECT pi.id AS projeto_item_id, pi.produto_id, p.nome AS produto, p.codigo_produto AS produto_codigo,
            pi.orcamento_id, o.numero AS orcamento_numero, pi.orcamento_item_id, pi.l_fixo, p.preco_custo,
            p.percentual_desconto_compra, mk.id AS marca_id, mk.nome AS marca_nome, forn.id AS fornecedor_id,
            forn.nome AS fornecedor_nome, esp.q_entrega_futura,
            coalesce(cob.qtd_coberta_por_pedido_aberto, 0::numeric) AS cob_origem,
            coalesce(rp.qtd, 0::numeric) AS reserva_do_projeto,
            coalesce(sum(esp.q_entrega_futura) OVER (PARTITION BY pi.projeto_id, pi.produto_id ORDER BY pi.l_fixo, pi.id
                       ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0::numeric) AS ef_anterior,
            o.empresa_id, emp.nome AS empresa_nome
           FROM projeto_itens pi
           JOIN vw_produtos_custo_restrito p ON p.id = pi.produto_id AND p.ativo = true
           JOIN estoque_saldos_projeto_item esp ON esp.projeto_item_id = pi.id AND esp.status_operacional = 'ativo'::text
           LEFT JOIN orcamentos o ON o.id = pi.orcamento_id
           LEFT JOIN marcas mk ON mk.id = p.marca_id
           LEFT JOIN contatos forn ON forn.id = COALESCE(p.fornecedor_principal_id, mk.fornecedor_id)
           LEFT JOIN cobertura_pedidos cob ON cob.projeto_item_id = pi.id
           LEFT JOIN reserva_projeto rp ON rp.produto_id = pi.produto_id AND rp.projeto_id = pi.projeto_id
           LEFT JOIN empresas emp ON emp.id = o.empresa_id
          WHERE pi.orcamento_item_id IS NOT NULL
        ), base AS (
         SELECT b.*, (b.cob_origem + LEAST(b.q_entrega_futura, GREATEST(b.reserva_do_projeto - b.ef_anterior, 0::numeric))) AS qtd_coberta
           FROM base0 b
        )
 SELECT projeto_item_id, produto_id, produto, produto_codigo, orcamento_id, orcamento_numero, orcamento_item_id, l_fixo,
    preco_custo, percentual_desconto_compra, marca_id, marca_nome, fornecedor_id, fornecedor_nome, q_entrega_futura,
    qtd_coberta AS qtd_coberta_por_pedido_aberto,
    GREATEST(0::numeric, q_entrega_futura - qtd_coberta) AS pendente_item,
    empresa_id, empresa_nome
   FROM base
  WHERE GREATEST(0::numeric, q_entrega_futura - qtd_coberta) > 0::numeric
  ORDER BY orcamento_numero, l_fixo, produto;

COMMIT;
