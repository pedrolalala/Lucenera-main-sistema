---
titulo: "SPEC-135 — Aprovação Financeira: reset falso-positivo do ciclo de aprovação + bloqueio de peça sem cadastro"
status: "APLICADO em produção (2026-09-14) — código e migration"
data_ultima_modificacao: 2026-09-14
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — `FinancialApprovalDialog.tsx`, RPCs `replace_orcamento_itens` e `aprovar_orcamento_financeiro`
dependencias:
  - SPEC-111 (confirmou como correto o reset de ciclo quando item/valor REALMENTE muda — esta SPEC não reabre essa regra, só corrige um falso positivo)
  - SPEC-019 (origem do mecanismo de reset)
  - SPEC-017 (achado colateral: RPC `financeiro_editar_orcamento`/`FinancialApprovalEditDialog.tsx` está órfã desde então)
---

# SPEC-135 — Aprovação Financeira: reset falso-positivo + bloqueio de peça sem cadastro

> Origem: teste ao vivo do Vinícius em 2026-09-11, direto na etapa de Aprovação Financeira (a etapa de faturar).

## Checklist de Ação

- [x] Investigar via `pg_get_functiondef`/`pg_get_triggerdef` direto no Supabase real qual é o mecanismo de reset de fato em produção (não confiar nas migrations locais do submodule).
- [x] Corrigir `replace_orcamento_itens` para não reescrever `orcamento_itens` quando o conjunto de itens recebido é idêntico ao já salvo.
- [x] Corrigir `aprovar_orcamento_financeiro` para bloquear aprovação (ramo venda) quando existe item sem produto cadastrado.
- [x] Corrigir `FinancialApprovalDialog.tsx`: aviso proativo + bloqueio de UI quando há item sem cadastro; parar de engolir silenciosamente o erro da RPC no `catch`.
- [x] Escrever migration em `supabase/db/migrations/20260911_135_orcamento_aprovacao_financeira_fixes/` e copiar para `04-Sistemas/gestao-financeira-clone-544cb (1)/supabase/migrations/`.
- [x] Atualizar `AI_DB_CONTEXT.md` do sistema (inclusive corrigir a documentação desatualizada sobre `financeiro_editar_orcamento` estar em uso).
- [x] **Aplicar a migration no Supabase real** — aplicada em 2026-09-14 em duas partes: `aprovar_orcamento_financeiro` (bloqueio de peça sem cadastro) via migration da SPEC-136 (superset); `replace_orcamento_itens` (no-op de itens iguais) via `supabase/db/migrations/20260914_139_fix_replace_orcamento_itens_pos_136/001_replace_orcamento_itens_no_op.sql` (a 136 nunca tocava essa função — achado só depois de aplicar a 136, ver nota abaixo). Ambas testadas com dry-run (transação com `ROLLBACK`) antes do `COMMIT` real; confirmado via `pg_get_functiondef` que as duas funções em produção têm os fixes.
- [ ] Rodar `pnpm run lint`/`pnpm run build` no sistema de Orçamentos após aplicar.
- [ ] Testar ao vivo: editar só forma de pagamento/data num orçamento em "Aprovação Financeira" e confirmar que NÃO volta para "Enviado ao Cliente"; tentar aprovar um orçamento com item sem cadastro e confirmar que é bloqueado com mensagem clara.

## Objetivo

Durante um teste ao vivo na etapa de Aprovação Financeira (a etapa de faturamento), o Vinícius reportou dois problemas distintos:

1. Simulou uma mudança de data de pagamento (algo que acontece com frequência no dia a dia) e o orçamento voltou para "Enviado ao Cliente", exigindo nova aprovação do cliente — o que não faz sentido para um ajuste puramente financeiro/operacional nessa etapa.
2. Simulou um orçamento com uma peça sem cadastro (sem código interno) e conseguiu levar o fluxo até o fim ("finalizou", aprovou financeiramente) — o que geraria uma venda sem nenhum controle de estoque associado, uma "peça fantasma".

Ambos foram investigados por leitura direta do banco real (`pg_get_functiondef`), não das migrations locais do submodule (que, confirmado nesta investigação, não refletem o que está de fato em produção para esse domínio).

## Decisões aprovadas

- **Não mexer na regra do SPEC-111**: quando um item de orçamento (produto, quantidade, preço, desconto) muda de verdade num orçamento já em "Aprovação Financeira"/"Orçamento Aprovado", o ciclo de aprovação do cliente continua reiniciando — isso já foi validado como correto pelo próprio Vinícius em agosto/2026.
- Mudanças em campos que não são item (forma de pagamento, data de vencimento, desconto, frete) **não devem** reiniciar o ciclo de aprovação — eram tratadas como "mudança de item" só por acidente de implementação (ver Causa raiz).
- Orçamento com item sem produto cadastrado (`produto_id IS NULL`) não pode ser aprovado financeiramente (ramo venda) — precisa ser cadastrado e vinculado antes.

## Investigação — estado real confirmado no Supabase (não nas migrations do submodule)

### Achado 1 — o reset é sempre via `orcamento_itens`, nunca por campo direto em `orcamentos`

Consulta a `pg_get_triggerdef`/`pg_get_functiondef` no banco real mostrou:

- `trg_orcamento_workflow` (`BEFORE INSERT OR UPDATE ON orcamentos`, função `handle_orcamento_workflow()`) **não tem nenhuma lógica de reset por campo** — só gera token ao entrar em `enviado_cliente` e seta `requer_revisao_financeira`/`aprovado_cliente_em` na transição `enviado_cliente -> Aprovação Financeira`.
- `trg_orcamento_item_change_reset` (`AFTER INSERT OR DELETE OR UPDATE ON orcamento_itens`, função `handle_orcamento_item_change_reset()`) é o único gatilho de reset real: dispara em **qualquer** escrita na tabela `orcamento_itens` quando `orcamentos.status IN ('Aprovação Financeira','Orçamento Aprovado')` — sem comparar se o valor do item mudou de fato — e reseta para `enviado_cliente`.

Isso contradiz o que está escrito nas migrations locais do submodule (`04-Sistemas/gestao-financeira-clone-544cb (1)/supabase/migrations/20260707160000...sql` e `20260707170000...sql`), que definem um `handle_orcamento_workflow()` com reset por campo (`valor_total`/`forma_pagamento`/`frete_tipo`/etc.) e um mecanismo de bypass via `financeiro_editar_orcamento`. **Essa versão nunca correspondeu ao que está de fato em produção** para este domínio — reforça o alerta do `AGENTS.md` de não tratar migrations locais de submodule como fonte final do banco.

### Achado 2 — causa raiz do "voltar pra trás" ao editar campo não-item

`useBudgetStore.updateBudget` (`src/stores/useBudgetStore.ts`) chama a RPC `replace_orcamento_itens` em **todo** salvamento do formulário (`BudgetFormPage.tsx`) que não seja "Orçamento Aprovado" (que usa `skipItens=true` por outro motivo, achado de 2026-08-14: evitar violação de FK). `replace_orcamento_itens` fazia sempre `DELETE FROM orcamento_itens` + `INSERT` de tudo de novo — **mesmo quando os itens enviados são idênticos aos já salvos**. Esse delete+insert "vazio" já bastava para disparar `trg_orcamento_item_change_reset`, mesmo numa edição que só mudou forma de pagamento, data ou desconto — campos que ficam inteiramente em `orcamentos`, nunca em `orcamento_itens`.

Ou seja: o teste do Vinícius nunca deveria ter voltado o status — é um efeito colateral técnico da forma como os itens são resalvos, não a regra de negócio em si.

### Achado 3 — `aprovar_orcamento_financeiro` não bloqueava peça sem cadastro

A RPC valida `quantidade > 0` e `preco_unitario > 0` por item, mas nunca validou `produto_id IS NOT NULL`. No loop que gera `projeto_itens`/reserva de estoque, item com `produto_id IS NULL` só pula a reserva (`CONTINUE WHEN v_item.produto_id IS NULL`) — mas o `projeto_itens`, a parcela e o boleto já tinham sido gerados normalmente antes desse ponto. Ou seja: o orçamento "finalizava" (virava `Orçamento Aprovado`, com boleto emitido) mesmo com item sem nenhum controle de estoque — a "venda fantasma" reportada.

Verificado no banco real: **nenhum orçamento em `Aprovação Financeira` hoje tem item sem produto cadastrado** — só 1 orçamento já `Orçamento Aprovado` (`ORC-0032`, provavelmente o próprio teste do Vinícius) tem essa característica. Aplicar o bloqueio agora não impede nenhuma aprovação pendente legítima.

## Fix aplicado

### 1) `replace_orcamento_itens` — no-op quando itens não mudam

Antes do `DELETE`, compara o conjunto de itens recebido (`p_items`) com o que já está salvo em `orcamento_itens`, usando `EXCEPT ALL` nos dois sentidos sobre todas as colunas persistidas (produto_id, descrição, quantidade, preço, desconto, custom_id, ordem, sub_ordem, item_pai_id, peça_nova, projeto_item_origem_id). Se forem idênticos (multiset), retorna sem tocar na tabela — o trigger de reset não dispara porque não há escrita. Se houver qualquer diferença real, o comportamento é o mesmo de antes (delete+insert, reset dispara conforme SPEC-111).

### 2) `aprovar_orcamento_financeiro` — bloqueio de peça sem cadastro

Adicionado, no início do ramo venda (depois do ramo devolução, que já tem sua própria validação e não é afetado):

```sql
IF EXISTS (
  SELECT 1 FROM public.orcamento_itens oi
  WHERE oi.orcamento_id = p_orcamento_id AND oi.produto_id IS NULL
) THEN
  RAISE EXCEPTION 'Orçamento % possui item sem produto cadastrado (peça sem código interno) — cadastre o produto antes de aprovar financeiramente.', v_numero_orcamento
    USING ERRCODE = 'P0001';
END IF;
```

### 3) `FinancialApprovalDialog.tsx`

- `canConfirm` agora também exige que nenhum item do orçamento esteja sem `produto_id`.
- Banner vermelho explícito quando há item sem cadastro, com o checkbox e o campo de confirmação desabilitados.
- **Achado colateral corrigido**: o `catch` do `handleConfirm` engolia silenciosamente qualquer erro da RPC (só resetava `isApproving`, sem nenhum toast/mensagem) — corrigido para mostrar `toast.error` com a mensagem real do erro. Sem esse fix, o bloqueio do item 2 (e qualquer outro erro futuro de aprovação) falharia sem o usuário entender por quê.

## Decisão deliberada: não mexer no aviso (`window.confirm`) de `BudgetFormPage.tsx`

O aviso "Esta alteração vai reiniciar o ciclo de aprovação..." (SPEC-111, `BudgetFormPage.tsx` linha ~1280) continua disparando sempre que se salva um orçamento em "Aprovação Financeira", independente de o reset realmente ir ocorrer depois do fix acima. Optei por **não** tentar prever no frontend, antes de salvar, se o reset vai ou não acontecer (isso exigiria replicar em TypeScript exatamente a mesma comparação multiset feita agora em SQL, com risco real de divergência de arredondamento/normalização entre os dois lados). Superestimar o aviso é seguro (o pior caso é um clique de confirmação a mais quando nada vai resetar); subestimar seria repetir o problema original que o SPEC-111 corrigiu (reset silencioso e inesperado). Se isso incomodar no dia a dia, é um ajuste de UX separado, não desta SPEC.

## Como aplicar

A migration foi escrita mas **não aplicada** — o classificador de modo automático do Claude Code bloqueou a execução direta por ser uma alteração de RPC compartilhada em produção. Rodar manualmente (usuário, ou aprovação explícita numa sessão futura):

```
psql "$SUPABASE_DB_URL" -f "supabase/db/migrations/20260911_135_orcamento_aprovacao_financeira_fixes/001_fix_reset_falso_positivo_e_bloqueio_peca_sem_cadastro.sql"
```

O arquivo já está dentro de `BEGIN;`/`COMMIT;` e termina com `NOTIFY pgrst, 'reload schema';`.

## Critérios de aceite

- [ ] Editar forma de pagamento, data de vencimento ou desconto de um orçamento em "Aprovação Financeira" sem tocar em itens **não** reinicia o ciclo de aprovação do cliente.
- [ ] Editar produto/quantidade/preço/desconto de um item de orçamento em "Aprovação Financeira"/"Orçamento Aprovado" **continua** reiniciando o ciclo (regressão do SPEC-111).
- [ ] Tentar aprovar financeiramente um orçamento com item sem produto cadastrado é bloqueado, com mensagem clara tanto na RPC quanto na UI.
- [ ] Erros da RPC de aprovação aparecem como toast visível no `FinancialApprovalDialog`, não somem silenciosamente.
- [ ] `pnpm run lint` e `pnpm run build` passam no sistema de Orçamentos.

## Realizado

### 2026-09-11

- Investigação completa via introspecção direta do Supabase real (`pg_get_functiondef`/`pg_get_triggerdef`), não das migrations locais do submodule — achado de que essas migrations locais não refletem o estado real de produção para este domínio (reforça `AGENTS.md`).
- Fix escrito e testado por leitura para ambas as RPCs; frontend do `FinancialApprovalDialog.tsx` ajustado (banner + fix do erro engolido silenciosamente).
- Migration registrada no repositório central e copiada para o submodule; `AI_DB_CONTEXT.md` do sistema atualizado (incluindo correção de uma seção desatualizada sobre `financeiro_editar_orcamento`).
- **Não aplicado no Supabase real** — bloqueado pelo classificador de modo automático.

## Pendências

- [ ] Rodar a migration no Supabase real (comando na seção "Como aplicar").
- [ ] `pnpm run lint`/`pnpm run build` após aplicar.
- [ ] Teste ao vivo dos dois cenários (edição de campo não-item; aprovação com peça sem cadastro).

## Nota (2026-09-14) — aplicação real, em 2 partes

A migration da **SPEC-136** (`20260911_136_orcamento_numero_venda/001_numero_venda.sql`) é superset desta **só na função `aprovar_orcamento_financeiro`** (bloqueio de peça sem cadastro + numero_venda) — foi aplicada primeiro. **Achado só depois de aplicar**: a 136 nunca tocava `replace_orcamento_itens` (o fix #1 desta SPEC, o "reset falso-positivo"), então esse fix ficou pendente mesmo com a 136 já em produção. Corrigido com uma migration extra, `supabase/db/migrations/20260914_139_fix_replace_orcamento_itens_pos_136/001_replace_orcamento_itens_no_op.sql` — aplica só `replace_orcamento_itens`, sem tocar `aprovar_orcamento_financeiro` (reaplicar a versão original da 135 nela teria revertido o `numero_venda` recém-aplicado). As duas migrations foram testadas com dry-run (`BEGIN; ...; ROLLBACK;`) contra o Supabase real antes do `COMMIT` de verdade — ambas aplicadas com sucesso em 2026-09-14, confirmadas via `pg_get_functiondef`.

## Nota (2026-09-14) — teste ao vivo do usuário revelou 3 problemas novos

Depois do banco corrigido, o usuário testou ao vivo (criou orçamento com peça sem cadastro, tentou aprovar) e reportou dois problemas — investigação achou um terceiro escondido:

1. **"Travou, mas não apareceu um Card com o motivo"**: achado a causa raiz — o frontend do Skip (produção, projeto `32554`) estava rodando uma versão de `FinancialApprovalDialog.tsx` **anterior à SPEC-135 inteira** (sem banner de peça sem cadastro, sem tratamento de erro nenhum — `catch { setIsApproving(false) }` vazio). O código desta SPEC nunca tinha sido publicado no Skip, só existia no git local (mesmo padrão do `feedback_skip_deploy_separate_tree`: editar o arquivo local não basta). Corrigido: publicado o `FinancialApprovalDialog.tsx` completo (banner de peça sem cadastro + agora também um Card vermelho persistente com a mensagem de erro da RPC, que antes só aparecia como toast).
2. **Causa adicional de risco (achada durante a investigação, não reportada pelo usuário)**: mesmo com o banner publicado, `budgetToEdit.itens`/`selectedBudget.itens` só é carregado uma vez quando a página/lista abre — um item sem cadastro adicionado na mesma sessão de edição podia não ser pego pelo banner (dado desatualizado em tela, embora já salvo no banco). Corrigido: `BudgetFormPage.tsx` e `FinancialApprovalTab.tsx` agora buscam os itens direto do banco antes de abrir o diálogo de aprovação.
3. **"Não deve voltar para a aprovação do cliente quando só edito Pagamento e Totais"**: o `window.confirm()` de aviso de reset (em `BudgetFormPage.tsx`) disparava incondicionalmente em qualquer salvamento com status "Aprovação Financeira", mesmo que o fix desta SPEC já garantisse que o reset em si não ocorreria (campos como forma de pagamento, parcelas, frete, perfil, desconto, sinal e observações nunca tocam `orcamento_itens`). Corrigido: nova função `itensRealmenteMudaram()` compara os itens atuais do formulário contra os itens originais carregados (mesmas colunas usadas na comparação SQL) — o aviso e o toast "ciclo reiniciado" só aparecem quando os itens realmente mudam.

Publicado em produção: `https://gestao-financeira-clone-544cb.goskip.app` (Skip `32554`, versão `0.0.360`, QA 100% verde). Commit `363aa5e` (só `FinancialApprovalDialog.tsx`) pushado ao GitHub — os outros dois arquivos tocados (`BudgetFormPage.tsx`, `FinancialApprovalTab.tsx`) têm o fix aplicado em produção via `skip_file_patch`, mas **não foram commitados no git** porque têm trabalho de outra sessão ainda não commitado misturado no mesmo arquivo; não é seguro varrer isso junto sem o usuário revisar.
