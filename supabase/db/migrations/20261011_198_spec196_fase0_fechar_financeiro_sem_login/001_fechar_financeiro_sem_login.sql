-- SPEC-196 Fase 0 (11/10/2026, aprovada pelo usuário): fechar o financeiro que estava legível SEM LOGIN
-- (chave anon, que vai dentro de todo site). Medido antes: staging_conta_pagar 13.863, staging_conta_receber
-- 4.357, stg_duplicatas_vigentes 9.946, vw_transacoes_completas/vw_conferencia_financeira 22.649,
-- vw_financeiro_projetos 4.119, vw_funcionarios_completo 27, vw_comissao_mensal 11 — tudo sem login.
-- Nenhuma tela lê os objetos de "FECHAR_TUDO" (só scripts com conexão direta e Edge Functions com
-- service_role, que não passam por grant/RLS). Quem tem login continua igual nos demais até a Fase 1.

-- 1) staging da Connect: RLS ligado SEM política (só postgres/service_role)
ALTER TABLE public.staging_conta_pagar ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staging_conta_receber ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stg_duplicatas_vigentes ENABLE ROW LEVEL SECURITY;

-- 2) nenhuma tela usa: fecha para sem login e para logado
REVOKE ALL ON public.staging_conta_pagar FROM anon, authenticated;
REVOKE ALL ON public.staging_conta_receber FROM anon, authenticated;
REVOKE ALL ON public.stg_duplicatas_vigentes FROM anon, authenticated;
REVOKE ALL ON public.vw_transacoes_completas FROM anon, authenticated;
REVOKE ALL ON public.vw_conferencia_financeira FROM anon, authenticated;
REVOKE ALL ON public.vw_financeiro_projetos FROM anon, authenticated;
REVOKE ALL ON public.vw_staging_resumo FROM anon, authenticated;
REVOKE ALL ON public.projeto_parcelas_backup_migration FROM anon, authenticated;

-- 3) financeiro em geral: fecha só para sem login
REVOKE ALL ON public.transacoes FROM anon;
REVOKE ALL ON public.negociacoes FROM anon;
REVOKE ALL ON public.boletos FROM anon;
REVOKE ALL ON public.projeto_parcelas FROM anon;
REVOKE ALL ON public.contas_bancarias FROM anon;
REVOKE ALL ON public.plano_de_contas FROM anon;
REVOKE ALL ON public.folha_pagamento FROM anon;
REVOKE ALL ON public.funcionarios_financeiro FROM anon;
REVOKE ALL ON public.notas_fiscais FROM anon;
REVOKE ALL ON public.notas_fiscais_itens FROM anon;
REVOKE ALL ON public.notas_fiscais_erros FROM anon;
REVOKE ALL ON public.notas_fiscais_compra FROM anon;
REVOKE ALL ON public.remessas FROM anon;
REVOKE ALL ON public.retornos_processados FROM anon;
REVOKE ALL ON public.retorno_bancario_arquivos FROM anon;
REVOKE ALL ON public.retorno_bancario_registros FROM anon;
REVOKE ALL ON public.pedido_compra_parcelas FROM anon;
REVOKE ALL ON public.categorias_financeiras FROM anon;
REVOKE ALL ON public.recebimentos_compra FROM anon;
REVOKE ALL ON public.recebimento_itens FROM anon;
REVOKE ALL ON public.vw_fluxo_caixa_projetado FROM anon;
REVOKE ALL ON public.vw_remessas_completa FROM anon;
REVOKE ALL ON public.vw_remessas_resumo_status FROM anon;
REVOKE ALL ON public.vw_remessas_vencimento FROM anon;
REVOKE ALL ON public.vw_fornecedores_remessas FROM anon;
REVOKE ALL ON public.vw_orcamentos_aprovacao_financeira_auditoria FROM anon;
REVOKE ALL ON public.vw_devolucoes_aguardando_recebimento FROM anon;
REVOKE ALL ON public.vw_comissao_mensal FROM anon;
REVOKE ALL ON public.vw_funcionarios_completo FROM anon;
REVOKE ALL ON public.vw_custos_pendentes_mes FROM anon;
