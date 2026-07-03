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
- `process-billing-automation` ainda pode existir remotamente como legado, mas não é o fluxo novo.
- Hub/TI deve controlar sistemas, saúde, acesso e permissões pela UI.

## Fluxo orçamento aprovado -> financeiro

1. Pessoa aprova orçamento.
2. Sistema chama `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)`.
3. Função cria/vincula itens aprovados, parcelas e boletos.
4. Administração Bancária passa a exibir boleto/pendência financeira pelo `orcamento_id`.
5. Projeto e cliente são exibidos por relacionamento, não por duplicação de chave no financeiro.
6. Nota fiscal fica pendente de integração futura com API.

## Pendências globais

- Reextrair `supabase/db/current` após a SPEC-005; a tentativa de 2026-06-26 falhou sem Docker/`pg_dump`.
- Consolidar novas migrations centrais sempre que houver alteração real no banco.
- Decidir ferramenta/API de emissão de nota fiscal.
- Migrar armazenamento de boletos/notas fiscais para OneDrive/SharePoint.
- Fazer análise detalhada de segurança/RLS depois da consolidação funcional.
