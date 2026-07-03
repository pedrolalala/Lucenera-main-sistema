# Versão Final — Lucenera

Data de consolidação: 23 de junho de 2026

Atualização incorporada: análise dos sistemas modificados em 23 de junho de 2026, análise da planilha `Vendas 01012025 a 23062026.xlsx` e conferência do Supabase atual via `.env`.

Atualização de portfólio em 24 de junho de 2026: Hub/Central e Sistema de TI passam a ser tratados como sistemas diferentes. Os sistemas prioritários de mapeamento são Central/Hub, Sistema de TI, Administração Bancária, Gestão Financeira, CRM, RH, Logística, PowerPoint e Cadastro. Ubiqua continua ativo, mas em baixa prioridade até definição melhor de abrangência.

Atualização operacional em 24 de junho de 2026: a pasta `Sistema/` deve conter apenas 9 diretórios locais, incluindo Ubiqua e os dois sistemas de Logística. Evidências e anexos da Logística devem ir para OneDrive via API, não Supabase Storage.

## Objetivo

Esta pasta consolida o diagnóstico e o plano de evolução do ecossistema Lucenera. O foco desta versão é substituir as funções ainda dependentes do Connect sem criar complexidade desnecessária.

Os documentos foram escritos para leitura do cliente e do colaborador responsável pelas automações. Cada proposta combina explicação funcional com um campo **Ação a ser realizada**, que pode ser usado como orientação em ferramentas como Codex, Claude Code ou VS Code.

## Documentos

1. [Relatório geral final](01_RELATORIO_GERAL_FINAL.md)
2. [Relatório específico do banco de dados](02_RELATORIO_BANCO_DE_DADOS.md)
3. [Adendo de atualização 23/06/2026](03_ADENDO_ATUALIZACAO_23_06_2026.md)
4. [Adendo de atualização 24/06/2026](04_ADENDO_ATUALIZACAO_24_06_2026.md)
5. [Adendo — Regras operacionais dos Videos Connect](05_ADENDO_REGRAS_VIDEOS_CONNECT.md)
6. [Escopo do Hub / Central](Escopos/01_ESCOPO_HUB_TI.md)
7. [Escopo do sistema de Cadastro](Escopos/02_ESCOPO_CADASTRO.md)
8. [Escopo do CRM](Escopos/03_ESCOPO_CRM.md)
9. [Escopo do sistema de Orçamentos](Escopos/04_ESCOPO_ORCAMENTOS.md)
10. [Escopo do novo sistema de Estoque e Compras](Escopos/05_ESCOPO_ESTOQUE_COMPRAS.md)
11. [Escopo do sistema Financeiro](Escopos/06_ESCOPO_FINANCEIRO.md)
12. [Escopo do sistema de Logística](Escopos/07_ESCOPO_LOGISTICA.md)
13. [Escopo do sistema de RH](Escopos/08_ESCOPO_RH.md)
14. [Escopo do sistema Ubiqua](Escopos/09_ESCOPO_UBIQUA.md)
15. [Escopo do Sistema de TI](Escopos/10_ESCOPO_SISTEMA_TI.md)

## Planos de ação

- [Tasks gerais do ecossistema — checklist consolidado de todas as pendências](Planos%20de%20Ação/00_TASKS_GERAIS_ECOSSISTEMA.md)
- [SPECs — SPEC-001 Aprovação de Orçamento para Administração Bancária](Planos%20de%20Ação/SPECs/SPEC-001_Aprovacao_Orcamento_para_Administracao_Bancaria.md)
- [SPECs — SPEC-002 Prazo para Início da Cobrança no Orçamento](Planos%20de%20Ação/SPECs/SPEC-002_Prazo_Inicio_Cobranca_Orcamento.md)
- [SPECs — SPEC-003 Validação e Coleta de Frete no Orçamento](Planos%20de%20Ação/SPECs/SPEC-003_Validacao_Coleta_Frete_Orcamento.md)
- [SPECs — SPEC-004 Auditoria e Proteção de Parcelas do Orçamento Aprovado](Planos%20de%20Ação/SPECs/SPEC-004_Auditoria_Parcelas_Orcamento_Aprovado.md)

## Decisões consolidadas

- O banco de dados atual em processo de organização é a única fonte de verdade.
- O Supabase atual foi conferido diretamente e passa a ser a referência operacional desta versão dos documentos.
- As migrations espalhadas nos projetos são histórico técnico, não definição do estado correto do banco.
- Será criado um sistema próprio de Estoque e Compras.
- O atual sistema de Administração Bancária evoluirá para o sistema Financeiro.
- Produtos e fornecedores usam cadastros únicos no banco.
- Cadastro edita informações cadastrais; Estoque/Compras consulta esses dados e gerencia informações operacionais.
- Apenas linhas classificadas como `VENDAS` na planilha `Vendas 01012025 a 23062026.xlsx` formam o histórico de itens aprovados.
- Garantias, trocas, devoluções, bonificações, remessas e uso interno são movimentações de estoque relacionadas ao cliente e, quando possível, ao projeto e à venda original.
- O código do projeto deve ser extraído do início de `NomeCliente`, preservando o formato exibido e usando normalização por dígitos para conciliação quando necessário.
- O código de produto da planilha de vendas deve ser conciliado principalmente com `produtos.codigo_legado`, pois no Supabase atual ele não corresponde a `produtos.codigo_produto`.
- O CRM terá um fluxo único por projeto, mas etapas, sub-status, checklists, dependências, responsáveis, bloqueios e SLA serão configuráveis pela interface.
- As configurações do fluxo serão versionadas. Mudanças gerais valem para novos projetos; projetos existentes só mudam por migração manual e auditada.
- Permissões serão configuráveis no Sistema de TI por sistema, módulo e ação, com exceções individuais.
- O Sistema de TI terá verificações automáticas de saúde e atualização manual auditada.
- O Hub/Central consumirá catálogo, permissões e saúde do Sistema de TI, mas não será o sistema administrativo de TI.
- Pedido de compra aprovado gera previsão financeira; recebimento da nota ou material confirma ou ajusta a conta a pagar.
- DocSign e sua automação permanecem mapeadas como prioridade baixa: não serão implementadas nesta versão, mas o gate de assinatura deve continuar registrado como plano futuro (ver Escopo CRM, SPEC-CRM-12).
- Ubiqua permanece ativo, mas em baixa prioridade no mapeamento.
- A Logística deve armazenar fotos, comprovantes e documentos no OneDrive via API, persistindo no banco apenas metadados e vínculos.
- Os processos dos Videos Connect confirmam regras adicionais: item especial sem preço bloqueia aprovação, frete precisa estar definido, vencimentos devem ser calculados a partir de forma de pagamento/prazo e validados pelo Financeiro, boleto só fica efetivamente registrável após remessa enviada ao banco, `Q. Venda` é imutável, devolução segue a ordem `E. Futura → Reserva → Entregue` e separação só deve sair de quantidade reservada/liberada.
