# Domínio: Financeiro / Administração Bancária

## Papel no ecossistema

O financeiro recebe obrigações geradas por orçamento aprovado e permite operar boletos, notas fiscais, remessa e retorno bancário.

## Decisão atual

O financeiro deve usar `orcamento_id` como vínculo principal.

O `projeto_id` não deve ser exigido como chave principal nas telas do financeiro, porque projeto e cliente podem ser derivados do orçamento.

## Fluxo esperado

1. Orçamento é aprovado.
2. A função de aprovação cria ou vincula itens/parcelas/boletos.
3. Administração Bancária lista boletos pendentes.
4. Financeiro valida vencimento, valor e dados do pagador.
5. Pessoa responsável gera boleto/remessa manualmente quando necessário.
6. Nota fiscal fica pendente de emissão até integração futura com API.

## Pontos importantes

- Vencimentos não devem ser presumidos manualmente.
- O sistema deve calcular/exibir vencimentos com base em `_lucenera_parse_prazo_pagamento(...)`, `orcamentos.prazo_inicio_cobranca_dias` e `orcamentos.prazo_pagamento_dias`.
- O financeiro valida, ajusta quando autorizado e executa a parte bancária/fiscal.
- O botão de fila/batch de remessa é manual.
- A geração de nota fiscal deve evoluir, mas depende da decisão de ferramenta/API.
- Parcelas geradas por orçamento têm `projeto_parcelas.orcamento_id` preenchido e unicidade por `(orcamento_id, numero_parcela)`.
- Parcelas legadas sem orçamento mantêm unicidade por `(projeto_id, numero_parcela)`.

## Pendências conhecidas

- Decidir API/ferramenta de emissão de notas fiscais.
- Implementar função de geração/envio de nota fiscal.
- Transferir uploads de boletos/notas fiscais para OneDrive/SharePoint para reduzir custo de storage no Supabase.

## Automações atuais

Automatizações identificadas no Supabase real relacionadas ao Financeiro/Administração Bancária:

- `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)`: cria/vincula parcelas e boletos a partir de orçamento aprovado.
- `public._lucenera_parse_prazo_pagamento(...)`: apoia cálculo de vencimentos com base em forma/prazo do orçamento.
- `public.trigger_proteger_parcelas()`: protege alterações indevidas em parcelas.
- `public.get_latest_transaction_id()`: consulta transação mais recente.
- `public.limpar_staging_processados()`: limpeza de staging processado.

Triggers relacionadas:

- `public.contas_bancarias.contas_updated_at`
- `public.custos_recorrentes.custos_rec_updated_at`
- `public.projeto_parcelas.trg_proteger_parcelas`
- `public.projeto_parcelas.update_parcelas_updated_at`
- `public.remessas.trg_remessas_auditoria`
- `public.remessas.trg_remessas_updated_at`
- `public.vendas.update_vendas_updated_at`
- `storage.objects.update_objects_updated_at`

Edge Functions relacionadas:

- `process-remittance`: apoio ao fluxo de remessa, com acionamento manual/autorizado.
- `sync-sharepoint`: integração SharePoint/OneDrive/Microsoft; relevante para migração futura de anexos/boletos/NFs.
- `generate-report`: relatórios/exportações.

Observação: `process-billing-automation` ainda aparece remotamente como Edge Function legada, mas não deve ser usada no fluxo novo. O financeiro deve operar a partir do vínculo por `orcamento_id` e da RPC `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)`.

Regra importante para boletos:

- boletos criados a partir de orçamento aprovado devem ficar vinculados por `boletos.orcamento_id`;
- o projeto deve ser derivado por `boletos.orcamento_id -> orcamentos.id -> orcamentos.projeto_id`;
- `boletos.projeto_id` foi removido para evitar redundância e divergência entre boleto e orçamento.

### SPEC-152 (2026-09-17) — Contrapartida automática de permuta

Quando uma parcela do orçamento é paga por permuta (`projeto_parcelas.forma_pagamento = 'permuta'`, com `projeto_parcelas.permuta_fornecedor_id` obrigatório), `aprovar_orcamento_financeiro` gera automaticamente uma obrigação de Contas a Pagar reaproveitando o padrão manual já existente de "Cadastrar Duplicatas" (SPEC-073): um `boletos` com `tipo_operacao = 'CP'` + `apropriacao_id` (categoria `plano_de_contas.nome = 'PERMUTA/CONTRAPARTIDA'`), rastreado pela mesma `boletos.orcamento_id` — sem FK nova. `'carteira'` e `'permuta'` também não geram o boleto normal de cobrança ao cliente (só `projeto_parcelas`, sem `boletos` do tipo padrão).

## Ação a ser realizada

Consolidar tabelas e funções relacionadas a `boletos`, `notas_fiscais`, `projeto_parcelas`, retorno/remessa bancária e storage. Garantir que novas consultas do financeiro filtrem por `orcamento_id` e mostrem projeto/cliente por join.
