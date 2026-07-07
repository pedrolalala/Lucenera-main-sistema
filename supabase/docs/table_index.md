# Índice de tabelas por domínio

Atualizado a partir do Supabase real em: 2026-07-06.

Este índice é operacional: lista os objetos reais encontrados. A classificação por domínio ainda pode ser refinada manualmente.

## Cadastros / base

- categorias_financeiras
- categorias_produto
- contato_origens
- contato_tipos
- contatos
- contatos_revisao
- empresa_ubiqua
- empresas
- fornecedores
- funcionarios
- funcionarios_beneficios_empresas
- funcionarios_detalhes
- funcionarios_financeiro
- funcionarios_novo
- informacoes_cliente_ubiqua
- itens_orcamento_ubiqua
- marcas
- orcamentos_revenda_ubiqua
- produtos
- projeto_produtos
- revenda_ubiqua
- staging_produtos
- usuarios
- usuarios_ubiqua
- vendas_marca
- vw_catalogo_ubiqua
- vw_detalhe_produto_estoque
- vw_estoque_por_marca
- vw_estoque_produtos
- vw_fornecedores_remessas
- vw_fornecedores_resumo
- vw_funcionarios_completo
- vw_produtos_estoque_detalhado
- vw_produtos_estoque_por_local
- vw_projetos_sem_empresa
- vw_vendas_produtos

## Orçamentos / projetos

- historico_status_orcamentos
- historico_status_orcamento
- itens_orcamento_ubiqua
- orcamento_itens
- orcamentos
- orcamentos_revenda_ubiqua
- projeto_itens
- projeto_parcelas
- projeto_parcelas_backup_migration
- projeto_produtos
- projeto_sinal
- projetos
- projetos_fechados
- vw_financeiro_projetos
- vw_projetos_dashboard
- vw_projetos_pipeline
- vw_projetos_por_responsavel
- vw_projetos_por_status
- vw_projetos_resumo
- vw_projetos_sem_empresa
- vw_projetos_sem_responsavel
- vw_projetos_status_enum
- vw_vendas_por_projeto

## Financeiro / administração bancária

- boletos
- categorias_financeiras
- custos_recorrentes
- custos_recorrentes_lancamentos
- funcionarios_financeiro
- notas_fiscais
- remessas
- retornos_processados
- staging_conta_receber
- transacoes
- vw_conferencia_financeira
- vw_custos_pendentes_mes
- vw_financeiro_projetos
- vw_fornecedores_remessas
- vw_remessas_completa
- vw_remessas_resumo_status
- vw_remessas_vencimento
- vw_transacoes_completas

## Estoque / compras

- estoque_itens
- pedido_compra
- solicitacoes_compra
- staging_pedido_compra
- vw_catalogo_ubiqua
- vw_catalogo_unificado
- vw_detalhe_produto_estoque
- vw_estoque_liquido
- vw_estoque_por_marca
- vw_estoque_produtos
- vw_produtos_estoque_detalhado
- vw_produtos_estoque_por_local

## CRM

- historico_status_orcamentos
- historico_status_orcamento
- vw_dashboard_crm_fechamento
- vw_projetos_pipeline
- vw_projetos_por_status
- vw_projetos_status_enum
- vw_remessas_resumo_status

## Logística

- entregas
- entregas_finalizadas
- separacao_arquivos
- separacao_itens
- separacoes
- separacoes_arquivos
- user_roles_separacao
- vw_separacoes_agenda

## RH

- controle_falta
- ferias
- folha_pagamento
- funcionarios
- funcionarios_beneficios_empresas
- funcionarios_detalhes
- funcionarios_financeiro
- funcionarios_novo
- periodos_aquisitivos
- vw_controle_ferias_clt
- vw_funcionarios_completo
- vw_historico_faltas

## Hub/TI / sistemas e acesso

- controle_falta
- logs_auditoria
- logs_operacoes
- systems
- user_roles_separacao
- user_system_access
- vw_catalogo_ubiqua
- vw_catalogo_unificado
- vw_controle_ferias_clt
- vw_logs_auditoria_recentes

## Não classificados automaticamente

- contas_bancarias
- departamentos
- negociacoes
- plano_de_contas
- quote_history
- quotes
- staging_conta_pagar
- staging_import_bruto
- sync_history
- vendas
- v_cash_flow_lucenera
- vw_fluxo_caixa_projetado
- vw_staging_resumo
- vw_vendas_loja

## Próxima ação

Refinar manualmente a classificação por domínio e remover ambiguidades. Este arquivo foi gerado por nomes reais de tabela/view, não por migrations antigas.

Observação: `historico_status_orcamentos` (plural) pertence ao fluxo novo Lucenera e referencia `public.orcamentos(id)`. `historico_status_orcamento` (singular) permanece ligado ao fluxo Ubiqua/revenda.

Observação 2026-07-07: `orcamentos` já possui colunas de aprovação do cliente e RPCs relacionadas no snapshot real. A SPEC-010 foi confirmada no Supabase real com `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item` e views de saldo; aplicar o hardening `20260707_023` e reextrair `db/current/` antes de destravar SPEC-011/012/015 e badges ricos da SPEC-014.
