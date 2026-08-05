-- Migration 20260805_077 - SPEC-064
--
-- Lucenera esta abrindo uma filial em Sao Paulo. Toda a operacao financeira e
-- de projetos continua sendo resolvida em Ribeirao Preto (nao e uma empresa/
-- CNPJ nova, nao muda nenhuma regra de negocio) -- o usuario so precisa
-- conseguir visualizar separadamente o que e relacionado a Sao Paulo.
--
-- "perfil" e puramente informativo (decisao explicita do usuario): nao
-- influencia nenhuma logica de negocio, calculo, permissao ou fluxo
-- existente. Cada entidade tem seu proprio campo, preenchido manualmente,
-- sem heranca/derivacao automatica entre elas (cliente, projeto, orcamento,
-- pedido de compra, boleto e transacao podem ter perfis diferentes entre si).
--
-- Campo fixo com 2 valores (mesmo padrao ja usado em tipo_cliente/
-- regime_apuracao: texto + CHECK, sem enum novo, sem tabela de filiais).

ALTER TABLE public.contatos
  ADD COLUMN IF NOT EXISTS perfil text CHECK (perfil IN ('ribeirao', 'sao_paulo'));

ALTER TABLE public.projetos
  ADD COLUMN IF NOT EXISTS perfil text CHECK (perfil IN ('ribeirao', 'sao_paulo'));

ALTER TABLE public.funcionarios
  ADD COLUMN IF NOT EXISTS perfil text CHECK (perfil IN ('ribeirao', 'sao_paulo'));

ALTER TABLE public.orcamentos
  ADD COLUMN IF NOT EXISTS perfil text CHECK (perfil IN ('ribeirao', 'sao_paulo'));

ALTER TABLE public.pedidos_compra
  ADD COLUMN IF NOT EXISTS perfil text CHECK (perfil IN ('ribeirao', 'sao_paulo'));

ALTER TABLE public.boletos
  ADD COLUMN IF NOT EXISTS perfil text CHECK (perfil IN ('ribeirao', 'sao_paulo'));

-- transacoes: fonte real do Dashboard Financeiro (v_financeiro_realizado),
-- livro-caixa importado do Connect, desconectado de orcamentos/boletos/
-- pedidos_compra -- precisa do proprio campo, classificado manualmente numa
-- tela nova (sem forma de derivar automaticamente de outra tabela).
ALTER TABLE public.transacoes
  ADD COLUMN IF NOT EXISTS perfil text CHECK (perfil IN ('ribeirao', 'sao_paulo'));
