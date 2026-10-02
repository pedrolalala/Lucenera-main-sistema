-- SPEC-174 N6c (pedido do usuário, 02/10/2026): a peça selecionada em Consultar Produtos
-- mostra sempre 8 setores. Reserva, Separação e Entrega Futura não ficam em estoque_itens,
-- e sim nos saldos por projeto (estoque_saldos_projeto_item, exposto em
-- vw_estoque_por_produto_projeto). Esta view soma esses saldos por peça.
--
-- Separação = a separar + separado (ainda não entregue).
-- Mesma base e mesmo security_invoker de vw_cadastro_produto_reserva_detalhe, então quem já
-- vê a tabela "Reservado por Cliente/Projeto" no Cadastro vê estes totais.
-- Só leitura, sem BEGIN/COMMIT no texto (aplicar com dry-run + rollback antes).

CREATE OR REPLACE VIEW public.vw_cadastro_produto_setores
WITH (security_invoker = true) AS
SELECT
  v.produto_id,
  COALESCE(SUM(v.q_reserva), 0)                              AS q_reserva,
  COALESCE(SUM(v.q_ag_separar), 0) + COALESCE(SUM(v.q_separado), 0) AS q_separacao,
  COALESCE(SUM(v.q_entrega_futura), 0)                       AS q_entrega_futura
FROM public.vw_estoque_por_produto_projeto v
GROUP BY v.produto_id;

GRANT SELECT ON public.vw_cadastro_produto_setores TO authenticated;

NOTIFY pgrst, 'reload schema';

-- Rollback: DROP VIEW IF EXISTS public.vw_cadastro_produto_setores;
