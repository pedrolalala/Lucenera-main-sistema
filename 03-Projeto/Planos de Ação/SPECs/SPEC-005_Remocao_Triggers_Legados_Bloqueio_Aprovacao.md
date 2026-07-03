---
titulo: "SPEC-005 — Remoção de Triggers Legados que Bloqueiam Aprovação de Orçamento"
status: parcial
data_ultima_modificacao: 2026-06-26
sistemas_envolvidos:
  - Orçamentos
  - Administração Bancária / Financeiro
  - Supabase / Banco
---

# SPEC-005 — Remoção de Triggers Legados que Bloqueiam Aprovação de Orçamento

## Checklist de Ação

- [x] Mapear todos os triggers ativos em `orcamentos`, `projetos`, `projeto_itens`, `projeto_parcelas`, `boletos`, `orcamento_itens`.
- [x] Confirmar, com dados reais, que os triggers legados bloqueiam 100% das aprovações possíveis hoje.
- [x] Remover `trg_aprovar_orcamento` e `fn_aprovar_orcamento()`.
- [x] Ajustar `trigger_proteger_parcelas()` para não bloquear parcelas com `orcamento_id IS NOT NULL`.
- [x] Corrigir `aprovar_orcamento_financeiro_base_spec001` para não inserir valor explícito em `projeto_itens.subtotal` (coluna passou a ser `GENERATED ALWAYS`).
- [x] Aplicar as migrations no banco remoto.
- [x] Testar a aprovação de um orçamento real ponta a ponta após a correção (transação com `ROLLBACK`, sem alterar dados de produção).

### Passos manuais do usuário

- [ ] Reextrair `supabase/db/current/01_schema_full.sql` após aplicar a migration.
- [ ] Revisar os demais triggers de `projetos` (`trg_fechar_projeto`, `trg_gerenciar_fluxo_projeto`, `trg_reserva_estoque`, `trg_proteger_fechamento`) — não bloqueiam a aprovação hoje, mas pressupõem um fluxo de status de projeto (`Proposta Sinal`, `Entrega materiais` etc.) que pode estar desatualizado frente ao modelo atual de orçamento → projeto já existente.

## Objetivo

Desde a SPEC-001, toda tentativa de aprovar um orçamento pela RPC correta (`aprovar_orcamento_financeiro` → `_base_spec001`) falhava com erros pouco relacionados ao código da RPC em si (ex.: "column orcamento_id of relation projetos does not exist"). A causa raiz não estava na RPC, e sim em dois triggers legados, criados antes da SPEC-001, que pressupõem um modelo de negócio diferente:

- um trigger tentava criar um projeto novo a partir do orçamento (modelo antigo: orçamento gera projeto);
- outro trigger só permitia criar parcela quando o projeto já estivesse em fase final (modelo antigo: parcela só nasce perto da entrega).

No modelo atual (SPEC-001 em diante), o orçamento já aponta para um projeto existente (`orcamentos.projeto_id`) e a parcela nasce no momento da aprovação, independente da fase do projeto. Os dois triggers nunca foram atualizados para esse modelo e bloqueavam qualquer aprovação real.

## Decisões aprovadas

- `trg_aprovar_orcamento` / `fn_aprovar_orcamento()` são removidos por completo (trigger e função), não apenas desabilitados — não há dado nem fluxo atual que dependa de criar projeto a partir de orçamento.
- `trigger_proteger_parcelas()` continua protegendo o fluxo legado de criação manual de parcela (`orcamento_id IS NULL`), mas passa a permitir sempre a criação de parcela vinculada a orçamento aprovado (`orcamento_id IS NOT NULL`), porque essa criação já é validada inteiramente dentro da RPC de aprovação.
- Não se altera o comportamento de nenhum outro trigger de `projetos` nesta SPEC — eles tratam de fases de obra/estoque e não bloqueiam a aprovação hoje; ficam como pendência de revisão futura.

## Definição da SPEC

### Estado atual verificado (2026-06-26)

| Trigger | Tabela | Quando | Função | Problema |
|---|---|---|---|---|
| `trg_aprovar_orcamento` | `orcamentos` | BEFORE UPDATE, `WHEN status -> 'aprovado'` | `fn_aprovar_orcamento` | Faz `INSERT INTO projetos (id, orcamento_id, ...)`; `projetos` não tem coluna `orcamento_id`. Dispara na mesma condição usada pela RPC de aprovação, então sempre quebra a transação. |
| `trg_proteger_parcelas` | `projeto_parcelas` | BEFORE INSERT | `trigger_proteger_parcelas` | Bloqueia `INSERT` se `projetos.status` não for `Ajustes finais` ou `Finalizado`. Nenhum dos 4 orçamentos existentes tem o projeto nesses status; bloquearia 100% das aprovações mesmo depois de corrigir o trigger acima. |

Evidência de impacto real:

- `SELECT count(*) FILTER (WHERE orcamento_id IS NOT NULL), count(*) FILTER (WHERE orcamento_id IS NULL) FROM projeto_parcelas` → `0` parcelas geradas por orçamento, `709` parcelas legadas. Nenhuma aprovação pela RPC correta jamais chegou a criar uma parcela.
- Status dos projetos vinculados aos 4 orçamentos existentes: `Obra Finalizada`, `Proposta Sinal`, `Estudo Inicial`, `Obra Finalizada` — nenhum em `Ajustes finais`/`Finalizado`.

### Migration

- `DROP TRIGGER trg_aprovar_orcamento ON public.orcamentos;`
- `DROP FUNCTION public.fn_aprovar_orcamento();`
- `CREATE OR REPLACE FUNCTION public.trigger_proteger_parcelas()` — adiciona `IF NEW.orcamento_id IS NOT NULL THEN RETURN NEW; END IF;` antes da verificação de status, preservando o restante da função para o fluxo legado.

### Critérios de aceite

- Aprovar um orçamento real (com `projeto_id`, frete, prazo e itens válidos) completa com sucesso e cria itens, parcelas (com `orcamento_id` preenchido) e boletos, independente do status atual do projeto vinculado.
- Criar parcela manual sem `orcamento_id` continua bloqueada se o projeto não estiver em `Ajustes finais`/`Finalizado` (comportamento legado preservado).
- Nenhum outro trigger de `projetos` é alterado.

## Realizado

### 2026-06-26

- Mapeados todos os 15 triggers ativos em `orcamentos`, `projetos`, `projeto_itens`, `projeto_parcelas`.
- Confirmado com dados reais que `trg_aprovar_orcamento` e `trg_proteger_parcelas` bloqueavam toda e qualquer aprovação possível no estado atual do banco (0 parcelas com `orcamento_id`, nenhum projeto nos status liberados pelo segundo trigger).
- Migration aplicada no banco remoto: `trg_aprovar_orcamento`/`fn_aprovar_orcamento` removidos; `trigger_proteger_parcelas` ajustado para liberar parcelas de orçamento aprovado.
- Aprovação testada ponta a ponta em orçamento real após a correção.
- Migrations espelhadas no repositório central em `supabase/db/migrations/20260626_009_spec005_remocao_triggers_legados_aprovacao/`.
- Tentativa de reextração do snapshot central falhou localmente sem Docker/`pg_dump`; até a nova extração, a migration central é a fonte da SPEC-005.

## Pendências

- [ ] Reextrair `supabase/db/current/01_schema_full.sql` para refletir a remoção do trigger/função e a alteração em `trigger_proteger_parcelas`.
- [ ] Revisar os demais triggers de `projetos` (`trg_fechar_projeto`, `trg_gerenciar_fluxo_projeto`, `trg_reserva_estoque`, `trg_proteger_fechamento`) em uma SPEC futura — não bloqueiam a aprovação hoje, mas dependem de um fluxo de status de projeto (`Proposta Sinal`, `Entrega materiais` etc.) que pode estar desalinhado com o modelo atual de orçamento → projeto já existente.
