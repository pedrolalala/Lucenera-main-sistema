---
titulo: "SPEC-111 — Orçamento \"retrocede\" status ao editar item pós-aprovação: comportamento confirmado como esperado, falta avisar o usuário"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — `BudgetFormPage.tsx`
  - Supabase (banco central) — trigger `handle_orcamento_item_change_reset`
dependencias:
  - SPEC-112 (observação destacada visualmente ao trocar empresa faturada — mesmo bloco da reunião, [43:19]-[44:52])
---

# SPEC-111 — Reset de aprovação ao editar item pós-aprovação: comportamento confirmado como esperado, falta avisar o usuário

> Origem: reunião Vinícius 14/08/2026 ([39:58]-[41:10], [42:20]-[43:12]).

## Objetivo

Investigar a reclamação inicial de que o orçamento "retrocede" de status (`Aprovação Financeira`/`Orçamento Aprovado` → volta pra aprovação do cliente) ao editar um item depois de já aprovado — e decidir se é bug ou comportamento correto sem aviso.

## O que a reunião realmente mostra

A reação do Vinícius muda ao longo da própria reunião, e isso é importante pra não tratar isso como bug:

1. **[39:58]-[41:10]**: primeira reação é de estranheza/suspeita de bug — *"Ah, ele voltou aqui... Tem que entender se quando a gente tirar e inserir a outra peça, se ele vai voltar pra cá. Que ele retrocedeu, entendeu?"* / *"Eu preciso entender o porquê que ele retrocedeu"*. Chega a cogitar que peças sem cadastro (que só ajustam centavos) não deveriam resetar: *"se teve alguma diferencinha de centavos, também vai mudar e vai ajustar no desconto... Acho que não deveria voltar mesmo não."* Nesse momento, conclui (errado) que foi só um erro: *"Eu acho que isso foi só um erro ele ter voltado."*
2. **[42:20]-[43:12]**: refaz o teste de propósito (*"quero fazer mais um teste, que pode acontecer. Ele volta tudo de novo."*) e aí sim entende e **confirma que o comportamento faz sentido**: *"toda vez que a revisão financeira faz alguma alteração, ele volta até a aprovação do cliente... teoricamente, no modo normal, acho que faria sentido... Porque se alterou, o cliente tem que aprovar, mas tudo bem. Vamos seguir a prova aí."*

Ou seja: **não é bug**. É o comportamento correto — se o financeiro mexe em item/valor de um orçamento já aprovado, o ciclo de aprovação do cliente reinicia, porque o cliente aprovou um valor que pode ter mudado. A confusão inicial veio de o sistema fazer isso **silenciosamente**, sem nenhum aviso na tela.

## Estado atual confirmado no código

Trigger `public.handle_orcamento_item_change_reset()` (confirmado via `pg_get_functiondef` no Supabase real):

- Dispara em alteração de item do orçamento (`orcamento_itens`/`projeto_itens`, a trigger recebe `NEW`/`OLD` com `orcamento_id`).
- Se `orcamentos.status` está em `'Aprovação Financeira'` OU `'Orçamento Aprovado'`, e a sessão não setou `app.skip_approval_reset = true`:
  - Reseta `status = 'enviado_cliente'`, limpa `aprovado_cliente_em`/`aprovado_cliente_origem`, zera `requer_revisao_financeira`, gera novo `token_aprovacao_cliente`, atualiza `enviado_cliente_em`/`enviado_cliente_por`.
  - Grava em `historico_status_orcamentos` com observação fixa: `'Itens do orçamento alterados após aprovação — ciclo de aprovação reiniciado'`.
- O `app.skip_approval_reset` é um escape hatch (existe pra algum fluxo interno que precisa editar item sem resetar aprovação — não investigado nesta SPEC qual fluxo usa isso).

**Achado**: a lógica de banco já está correta e documentada (o comentário de auditoria em `historico_status_orcamentos` já explica o motivo). O que falta é só **UX**: `BudgetFormPage.tsx` não avisa o usuário, no momento de salvar a edição, que essa alteração vai reiniciar o ciclo de aprovação do cliente — ele só descobre depois, ao ver o status mudado, e reage como se fosse bug (igual aconteceu na reunião).

## Proposta (não implementar sem aprovação)

1. **Não mexer na lógica do trigger** — está correta e já validada pelo próprio Vinícius ao vivo.
2. No frontend, ao editar item/valor de um orçamento cujo status já é `Aprovação Financeira` ou `Orçamento Aprovado`, mostrar um aviso/confirmação **antes** de salvar: algo como *"Esta alteração vai reiniciar o ciclo de aprovação — o cliente precisará aprovar novamente. Confirmar?"*.
3. Depois de salvar, se o reset ocorreu, deixar isso visível no feedback de sucesso (toast), não só implícito na mudança de status.
4. Verificar (pendência) o que usa `app.skip_approval_reset` hoje — se for um caminho legítimo (ex.: RPC administrativa que já avisa por outro lugar), documentar; se for um bypass esquecido, reportar como achado à parte.

## Análise de ecossistema

- **Depende de**: `orcamentos.status`, `historico_status_orcamentos`, trigger `handle_orcamento_item_change_reset`.
- **Afeta**: só a experiência de edição pós-aprovação no formulário de orçamento — nenhuma mudança de regra de negócio, só de comunicação.
- **Relacionado**: o mesmo bloco da reunião ([43:19]-[44:52]) levanta um problema parecido de comunicação (troca de empresa faturada sem aviso visível) — coberto pela SPEC-112.

## Realizado

### 2026-08-15

- **P-1 resolvida**: `app.skip_approval_reset` é usado só por `financeiro_editar_orcamento` (RPC de um fluxo administrativo separado, `FinancialApprovalEditDialog.tsx` — "Editar Validação Financeira"), que já tem seu próprio `AlertDialog` completo com escolha explícita "Manter aprovação" vs. "Reiniciar aprovação". Esse fluxo não foi tocado — já está correto e não é o caminho que o Vinícius usou na reunião.
- **Achado real durante a implementação**: o caminho que o Vinícius usava (edição normal via `BudgetFormPage.tsx`) tem dois comportamentos diferentes por status — `'Orçamento Aprovado'` já pula os itens inteiramente (`skipItens=true`, achado anterior de 2026-08-14, edição de campo não relacionado a item nunca tocava `orcamento_itens`), então o trigger nunca dispara nesse status por aqui. **`'Aprovação Financeira'` é o único status onde o trigger realmente dispara** por essa tela — exatamente o status em que Vinícius estava testando na reunião.
- **P-2 resolvida sem precisar perguntar**: implementado como confirmação bloqueante (`window.confirm`) antes de salvar, igual à proposta original item 2 — texto explica que o ciclo de aprovação vai reiniciar. Depois de salvar, o toast de sucesso também menciona o reinício (não fica mais implícito só na mudança de status).
- Publicado Skip 32554 v0.0.339 — QA limpo (typecheck+build confirmam a integração do gate). **Não testado clicando de verdade no navegador**: a automação de browser desta sessão tem regra explícita de nunca disparar `window.confirm`/`alert`/`prompt` nativo (trava a extensão pra comandos futuros) — verificação ficou restrita à leitura do código aplicado + build/typecheck bem-sucedidos no pipeline do Skip.

## Pendências

Nenhuma.
