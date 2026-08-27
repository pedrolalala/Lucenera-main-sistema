# SPEC-076: Voltar em Todos os Status do Funil de Orçamentos

**Data:** 2026-08-11
**Sistema:** Orçamentos (`gestao-financeira-clone-544cb`, Skip projectId `32554`)
**Status:** Publicado em produção (v0.0.312, hash `3d9816f`)

## Pedido do usuário

> "eu preciso que no orçamento tenha a opção de voltar em todas os status! Assim seguindo a logica de aprovar ou não podendo voltar para revisão daquela instancia anterior."

Contexto imediato: o usuário tinha acabado de reportar o erro "Falha ao aprovar manualmente" (corrigido separadamente — CHECK constraint `orcamentos_status_check` faltando o valor `'Aprovação da Equipe'`, ver changelog "2026-08-11 (9)") e pediu, na sequência, que o "voltar" existisse em todo o funil.

## Funil de status

```
rascunho -> enviado_cliente -> Aprovação da Equipe -> Aprovação Financeira -> Orçamento Aprovado
```

(`recusado_cliente` é um ramo de `enviado_cliente`, tratado igual para efeito de "voltar".)

### Estado antes da SPEC-076

| Transição | Existia? | Mecanismo |
| --- | --- | --- |
| enviado_cliente/recusado_cliente → rascunho | Sim | RPC `voltar_orcamento_rascunho` (SPEC-070) — reconectado nesta mesma sessão, ver changelog "2026-08-11 (7)" |
| Aprovação da Equipe → enviado_cliente | Sim | RPC `equipe_devolver_orcamento_cliente` (SPEC-031) |
| **Aprovação Financeira → Aprovação da Equipe** | **Não** | — |
| **Orçamento Aprovado → Aprovação Financeira** | **Não** | — |

Só faltavam os dois últimos degraus.

## Decisões tomadas (com o usuário)

1. **Aprovação Financeira → Aprovação da Equipe**: seguro, é só um flip de status — nenhum `projeto_itens`/parcela/boleto foi criado ainda nesse ponto do funil (só nasce na aprovação financeira em si). Implementado direto, sem necessidade de confirmação adicional de design.

2. **Orçamento Aprovado → Aprovação Financeira**: a aprovação financeira (`aprovar_orcamento_financeiro`) já cria `projeto_itens`, `projeto_parcelas`, `boletos` e reserva estoque real (`estoque_itens.quantidade_reservada`, `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item`). Perguntado ao usuário como o "voltar" deveria se comportar aqui — 3 opções: (a) apagar tudo que foi criado, bloqueando se algo já foi consumido a jusante; (b) só mudar o status sem apagar nada; (c) não implementar agora. **Escolhido: (a)**.

## Implementação

### RPC `financeiro_devolver_orcamento_equipe(p_orcamento_id uuid, p_motivo text)`

Migration `supabase/db/migrations/20260811_099_orcamento_voltar_todos_status/001_financeiro_devolver_orcamento_equipe.sql`.

- Guard: `service_role`, ou `admin`/`gerente`, ou `hub_pode_executar('orcamentos', NULL, 'aprovar')` — mesma permissão exigida para aprovar financeiramente.
- Exige `status = 'Aprovação Financeira'`.
- `UPDATE orcamentos SET status = 'Aprovação da Equipe', requer_revisao_financeira = false`.
- Grava em `historico_status_orcamentos` com o motivo (obrigatório).

### RPC `desfazer_aprovacao_financeira(p_orcamento_id uuid, p_motivo text)`

Migration `supabase/db/migrations/20260811_099_orcamento_voltar_todos_status/002_desfazer_aprovacao_financeira.sql`.

- Guard: só `admin`/`gerente` (mais restrito que aprovar financeiramente, já que aqui apaga dado real).
- Exige `status = 'Orçamento Aprovado'`.
- **Bloqueia** (não apaga nada) se natureza_operacao = `'devolucao'` (fora de escopo, ver "Pendências" abaixo).
- **Bloqueia** se qualquer um destes existir:
  - `boletos.status <> 'pendente_registro'` (já remessado/pago)
  - `notas_fiscais` referenciando um dos boletos
  - `retorno_bancario_registros` referenciando boleto ou parcela
  - `projeto_parcelas.status <> 'pendente'`
  - `transacoes` referenciando parcela
  - `devolucoes_estoque`/`separacao_itens`/`transferencias_estoque` referenciando um `projeto_item`
  - `pedido_compra_item_origem` referenciando um `projeto_item`
  - `orcamento_itens.projeto_item_origem_id` de outro orçamento (de devolução) apontando pra um desses itens
- Se nada bloquear: estorna `estoque_itens.quantidade_reservada` item a item, registra movimento de estorno em `estoque_movimentos_projeto_item`, apaga `estoque_saldos_projeto_item`/`boletos`/`projeto_parcelas`/`projeto_itens`, volta `orcamentos.status = 'Aprovação Financeira'` com `requer_revisao_financeira = true`.
- Grava em `historico_status_orcamentos` com o motivo (obrigatório).

### Frontend

- `src/stores/useBudgetStore.ts`: métodos novos `financeiroDevolverOrcamentoEquipe(budget, motivo)` e `desfazerAprovacaoFinanceira(budget, motivo)`.
- `src/components/budgets/FinancialApprovalTab.tsx`: botão "Devolver para Equipe" (mesma permissão de quem aprova financeiramente) + dialog de motivo obrigatório.
- `src/components/budgets/BudgetTableRow.tsx`: botão "Desfazer Aprovação Financeira" (só admin/gerente) para status `Orçamento Aprovado`, com dialog explicando exatamente o que será apagado/estornado e que a ação é bloqueada se algo já foi consumido. Esse componente é usado tanto pela aba "Aprovados" quanto pela aba "Todos".

## Verificação

- Build local limpo (`npm run build`).
- Ambas as RPCs testadas com UUID inexistente (retornam "Orçamento não encontrado", confirmando que compilam e executam).
- QA do Skip (setup/staticAnalysis/build/integrations/test) limpo antes do publish.
- Não foi feito teste end-to-end com dado real de produção (criar/reverter uma aprovação financeira de verdade) — os guards foram verificados por leitura de código e schema, não por execução real, para não arriscar mexer nos 12 orçamentos reais já aprovados.

## Pendências / fora de escopo

- **Reversão de aprovação financeira de orçamentos de devolução** (`natureza_operacao = 'devolucao'`): o ramo de devolução de `aprovar_orcamento_financeiro` não cria `projeto_itens` novos — ele chama `registrar_devolucao_projeto_item` sobre o item de origem de uma venda anterior. Desfazer isso exigiria reverter aquele registro separadamente (lógica própria, não coberta por `desfazer_aprovacao_financeira`). `desfazer_aprovacao_financeira` bloqueia explicitamente esse caso.
- Nenhum teste de UI ao vivo (browser) foi feito — instabilidade de automação de navegador já documentada em sessões anteriores.
