# Contexto global para IA — Banco Lucenera

Leia este arquivo antes de alterar qualquer sistema da Lucenera que use Supabase.

## Fonte de verdade

A fonte de verdade é o banco Supabase atual e a documentação central em `/supabase`.

Não trate migrations dispersas em `Sistema/*/supabase/migrations` como verdade final. Elas podem estar desatualizadas, duplicadas ou específicas de uma tentativa anterior.

## Direções arquiteturais

- O ecossistema deve ser simplificado agora para substituir o uso do Connect.
- CRM deve ser configurável pela UI, com etapas, sub-status, checklists, bloqueios, paralelismo, sequência, responsáveis e SLA.
- Estoque/Compras será um sistema próprio.
- Cadastros guarda dados cadastrais; Estoque/Compras guarda dados operacionais.
- Orçamentos aprovados geram `projeto_itens`.
- Financeiro deve usar `orcamento_id` como chave principal de rastreio do fluxo aprovado.
- `projetos.valor_total` é total denormalizado mantido por `public.sync_projeto_valor_total()` a partir de `projeto_itens.subtotal`.
- Não usar `venda_id` no fluxo orçamento -> financeiro.
- Frete do orçamento é estruturado: `frete_tipo = com_frete | sem_frete` e `frete_valor` coerente.
- Prazo de cobrança deve ser interpretável por `prazo_inicio_cobranca_dias` / `prazo_pagamento_dias`.
- Histórico de aprovação do fluxo Lucenera usa `historico_status_orcamentos`; não usar `historico_status_orcamento` para esse fluxo, porque ele pertence à família Ubiqua/revenda.
- A aprovação não deve depender de `public.fn_aprovar_orcamento()` nem de `public.orcamentos.trg_aprovar_orcamento`; ambos foram removidos pela SPEC-005.
- O banco real de 06/07/2026 já tem a normalização da SPEC-016 aplicada. O contrato oficial é `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado`; `aprovado_cliente`, `aprovado` e `aprovado_financeiro` são legados/compatibilidade.
- A SPEC-018 está aplicada no banco pela RPC `public.criar_produto_orcamento(p_payload jsonb)`, que grava no cadastro canônico `produtos` e não cria catálogo paralelo.
- A UI de Orçamentos foi atualizada em 06/07/2026 pelas SPECs 017/018 no projeto Skip `32554`: a aba financeira lista orçamentos em `Aprovação Financeira`, aprova por `orcamento_id` e permite criar produto dentro do fluxo de orçamento.
- A SPEC-010 já está aplicada no banco real em 07/07/2026: `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item` e as views de saldo existem. Antes de liberar consumo amplo em CRM/Estoque/Logística, aplicar o hardening `20260707_023_spec010_hardening`: views com `security_invoker`, ajuste de grants, reconciliação de `quantidade_reservada`, bloqueio de entrega direta de `q_entrega_futura` e reextração de `db/current/`.
- `process-billing-automation` ainda pode existir remotamente como legado, mas não é o fluxo novo.
- Hub/TI deve controlar sistemas, saúde, acesso e permissões pela UI.

## Fluxo orçamento aprovado -> financeiro

1. Cliente aprova orçamento e o status vai para `Aprovação Financeira`.
2. Financeiro/ADM processa aprovação financeira pela RPC transacional oficial da SPEC-016.
3. Função cria/vincula itens aprovados, parcelas, boletos e reserva agregada.
4. Administração Bancária passa a exibir boleto/pendência financeira pelo `orcamento_id`.
5. Projeto e cliente são exibidos por relacionamento, não por duplicação de chave no financeiro.
6. Nota fiscal fica pendente de integração futura com API.

## Pendências globais

- Homologar no preview Skip o fluxo completo de Orçamentos: enviar ao cliente, cliente aprovar, financeiro revisar/editar, criar produto quando necessário e aprovar financeiramente.
- Aplicar o hardening `20260707_023_spec010_hardening` e definir a policy de RLS da SPEC-010 antes de transferência, entrega futura detalhada, devolução automatizada e badges ricos no CRM.
- Consolidar novas migrations centrais sempre que houver alteração real no banco.
- Decidir ferramenta/API de emissão de nota fiscal.
- Migrar armazenamento de boletos/notas fiscais para OneDrive/SharePoint.
- Fazer análise detalhada de segurança/RLS depois da consolidação funcional.
