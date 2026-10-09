-- SPEC-191 (reunião 08/10/2026, Vinícius) — Controle de Produção + Consulta de Produtos.
-- A1: pedido de produção não é apagado, é INATIVADO (some das listas, fica no histórico).
-- A5: todos veem; só o pessoal do estoque altera (Vinícius, Débora, Mateus, Vitória, João).
--     A lista fica numa tabela (producao_editores) — para incluir o João ou um substituto
--     basta inserir o e-mail, sem migration nova.
-- B3: abas Reserva/Separação/Entrega Futura mostram a data da VENDA (aprovação financeira,
--     quando o orçamento vira "Orçamento Aprovado" e ganha numero_venda), não a do orçamento.
-- Sem BEGIN/COMMIT no texto (aplicar com dry-run + rollback antes).

-- A1 ---------------------------------------------------------------------------------------
ALTER TABLE public.producao_pedidos
  ADD COLUMN IF NOT EXISTS inativo boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS inativado_em timestamptz,
  ADD COLUMN IF NOT EXISTS inativado_por uuid REFERENCES public.usuarios(id);

-- A5 ---------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.producao_editores (
  email text PRIMARY KEY,
  nome text NOT NULL,
  observacao text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.producao_editores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS producao_editores_select ON public.producao_editores;
CREATE POLICY producao_editores_select ON public.producao_editores
  FOR SELECT TO authenticated USING (true);
GRANT SELECT ON public.producao_editores TO authenticated;

-- João ainda não tem e-mail da Lucenera (reunião 08/10): entra quando tiver.
-- Pedro e Filippo entram como suporte do sistema (teste/correção), não como operação.
INSERT INTO public.producao_editores (email, nome, observacao) VALUES
  ('vinicius@lucenera.com.br', 'Vinícius', NULL),
  ('debora@lucenera.com.br',   'Débora',   NULL),
  ('matheus@lucenera.com.br',  'Mateus',   NULL),
  ('vitoria@lucenera.com.br',  'Vitória',  NULL),
  ('pedro@lucenera.com.br',    'Pedro',    'suporte do sistema'),
  ('filippo@lucenera.com.br',  'Filippo',  'suporte do sistema')
ON CONFLICT (email) DO NOTHING;

CREATE OR REPLACE FUNCTION public.producao_pode_alterar()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.usuarios u
    JOIN public.producao_editores e ON lower(e.email) = lower(u.email)
    WHERE u.id = auth.uid() AND COALESCE(u.ativo, true)
  );
$$;

REVOKE ALL ON FUNCTION public.producao_pode_alterar() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.producao_pode_alterar() TO authenticated;

-- Escrita nas tabelas da Produção passa a exigir producao_pode_alterar(). Leitura segue livre.
DROP POLICY IF EXISTS producao_pedidos_insert ON public.producao_pedidos;
CREATE POLICY producao_pedidos_insert ON public.producao_pedidos
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.producao_pode_alterar()));
DROP POLICY IF EXISTS producao_pedidos_update ON public.producao_pedidos;
CREATE POLICY producao_pedidos_update ON public.producao_pedidos
  FOR UPDATE TO authenticated USING ((SELECT public.producao_pode_alterar()))
  WITH CHECK ((SELECT public.producao_pode_alterar()));

DROP POLICY IF EXISTS producao_pedido_anexos_insert ON public.producao_pedido_anexos;
CREATE POLICY producao_pedido_anexos_insert ON public.producao_pedido_anexos
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.producao_pode_alterar()));
DROP POLICY IF EXISTS producao_pedido_anexos_delete ON public.producao_pedido_anexos;
CREATE POLICY producao_pedido_anexos_delete ON public.producao_pedido_anexos
  FOR DELETE TO authenticated USING ((SELECT public.producao_pode_alterar()));

DROP POLICY IF EXISTS producao_pedido_edicoes_insert ON public.producao_pedido_edicoes;
CREATE POLICY producao_pedido_edicoes_insert ON public.producao_pedido_edicoes
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.producao_pode_alterar()));

DROP POLICY IF EXISTS producao_pedido_handoffs_insert ON public.producao_pedido_handoffs;
CREATE POLICY producao_pedido_handoffs_insert ON public.producao_pedido_handoffs
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.producao_pode_alterar()));

DROP POLICY IF EXISTS producao_pedido_ocorrencias_insert ON public.producao_pedido_ocorrencias;
CREATE POLICY producao_pedido_ocorrencias_insert ON public.producao_pedido_ocorrencias
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.producao_pode_alterar()));
DROP POLICY IF EXISTS producao_pedido_ocorrencias_update ON public.producao_pedido_ocorrencias;
CREATE POLICY producao_pedido_ocorrencias_update ON public.producao_pedido_ocorrencias
  FOR UPDATE TO authenticated USING ((SELECT public.producao_pode_alterar()))
  WITH CHECK ((SELECT public.producao_pode_alterar()));

DROP POLICY IF EXISTS producao_pedido_prazo_alteracoes_insert ON public.producao_pedido_prazo_alteracoes;
CREATE POLICY producao_pedido_prazo_alteracoes_insert ON public.producao_pedido_prazo_alteracoes
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.producao_pode_alterar()));

-- B3 ---------------------------------------------------------------------------------------
-- Coluna nova no FIM (CREATE OR REPLACE VIEW só aceita acrescentar colunas no final).
-- data_venda = primeira vez que o orçamento virou "Orçamento Aprovado" (é quando
-- aprovar_orcamento_financeiro gera o numero_venda); sem histórico, cai no aceite do cliente.
CREATE OR REPLACE VIEW public.vw_cadastro_produto_movimentos
WITH (security_invoker = true) AS
SELECT
  pi.produto_id,
  esp.projeto_item_id,
  pi.orcamento_id,
  o.numero                         AS orcamento_numero,
  o.numero_venda                   AS venda_numero,
  f.nome                           AS funcionario_nome,
  c.nome                           AS cliente_nome,
  pr.codigo                        AS projeto_codigo,
  pi.l_fixo,
  o.data_emissao                   AS data_orcamento,
  o.previsao_entrega               AS data_entrega,
  o.valor_total                    AS valor_total_orcamento,
  esp.q_reserva,
  esp.q_entrega_futura,
  esp.q_ag_separar + esp.q_separado AS q_separacao,
  esp.q_entregue,
  esp.q_devolvida_entregue,
  esp.status_operacional,
  COALESCE(
    (SELECT min(h.created_at)
       FROM public.historico_status_orcamentos h
      WHERE h.orcamento_id = o.id
        AND h.status_novo ILIKE 'Or_amento Aprovado'),
    o.aprovado_cliente_em
  )                                AS data_venda
FROM public.estoque_saldos_projeto_item esp
JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
LEFT JOIN public.contatos c ON c.id = COALESCE(o.cliente_id, pr.cliente_id)
LEFT JOIN public.funcionarios f ON f.id = o.vendedor_id
WHERE pi.produto_id IS NOT NULL
  AND esp.status_operacional <> 'cancelado'
  AND (esp.q_reserva > 0 OR esp.q_entrega_futura > 0 OR esp.q_ag_separar > 0
       OR esp.q_separado > 0 OR esp.q_entregue > 0);

GRANT SELECT ON public.vw_cadastro_produto_movimentos TO authenticated;
