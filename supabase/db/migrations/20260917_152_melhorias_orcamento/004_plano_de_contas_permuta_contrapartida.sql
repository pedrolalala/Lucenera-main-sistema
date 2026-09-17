-- SPEC-152 (item 6) — decisão do usuário (2026-09-17): "Contrapartida de
-- Permuta: cria categoria nova no plano de contas do Financeiro,
-- 'Permuta/Contrapartida', usada em todo lançamento automático desse tipo."
--
-- Segue exatamente o mesmo padrão da reconciliação anterior
-- (20260811_096_reconciliacao_plano_contas_apropriacao/001_reconciliacao.sql):
-- nivel 3 (folha/Apropriação), codigo_connect na faixa 90.000.001+
-- (reservada para itens criados manualmente, que não vêm do Connect -- o
-- último usado até agora foi 90000034), parent_id = "Com Vendas"
-- (ce518e98-8324-459a-a9ab-dd728393cd6d, nível 2 -- mesmo grupo de
-- DESCONTOS/OBRA/MERCADORIA DANIFICADA/TRIBUTOS, todas contrapartidas
-- ligadas à venda), tipo = 'despesa' (é uma obrigação de Contas a Pagar).
--
-- A obrigação automática (ver 005_aprovar_orcamento_financeiro.sql) busca
-- esta linha por nome (não por id fixo), porque o id real só existe depois
-- que este INSERT roda no banco de verdade -- não dá pra hardcodar um uuid
-- aqui.

BEGIN;

INSERT INTO public.plano_de_contas (codigo_connect, nome, nivel, parent_id, tipo, ativo)
SELECT 90000035, 'PERMUTA/CONTRAPARTIDA', 3, 'ce518e98-8324-459a-a9ab-dd728393cd6d', 'despesa', true
WHERE NOT EXISTS (
  SELECT 1 FROM public.plano_de_contas WHERE nome = 'PERMUTA/CONTRAPARTIDA' AND nivel = 3
);

COMMIT;
