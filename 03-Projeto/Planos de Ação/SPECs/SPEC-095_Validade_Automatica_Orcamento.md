---
titulo: "SPEC-095 — Validade do orçamento calculada automaticamente (10 dias) com renovação em rascunho"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - Orçamentos
dependencias:
  - 03-Projeto/Planos de Ação/SPECs/SPEC-086_Analise_Reunioes_Vinicius_11_08_2026.md (item 2.7)
---

# SPEC-095 — Validade do orçamento calculada automaticamente

> Origem: reunião com Vinícius, 11/08/2026 (`02-Reunioes/17. Lucenera
> (vinicius) - 11.08.2026_ estruturas falhas do sistema/Reunião.03`,
> [30:47]-[31:25]). Catalogado como item 2.7 na SPEC-086.

## Checklist de Ação

- [ ] `BudgetFormPage.tsx`: campo `validade` deixa de ser só manual — passa a
      ser calculado como `data_emissao + 10 dias` por padrão, recalculado
      toda vez que `data_emissao` mudar, mas **continua editável
      manualmente** (usuário pode sobrescrever)
- [ ] "Renovação" ao reeditar rascunho: enquanto o orçamento estiver em
      status "Rascunho" (nunca enviado ao cliente), reabrir/editar e salvar
      atualiza `data_emissao` pra hoje (reaproveitando a lógica que já existe
      em outro fluxo, linha ~884: `form.setValue('data_emissao', new
      Date(), ...)`) — e por consequência `validade` recalcula junto
- [ ] Confirmar que orçamentos já enviados/aprovados **não** têm a validade
      renovada silenciosamente ao editar (ver decisão pendente)

### Passos manuais do usuário

- [ ] Nenhuma migration — mudança de comportamento só no frontend

## Objetivo

Hoje o campo "Validade" em `BudgetFormPage.tsx` é um date-picker manual e
opcional, sem nenhum vínculo com a data de emissão. O Vinícius pediu uma
regra fixa: validade = 10 dias a partir da emissão, com uma nuance
importante — se a pessoa começar o orçamento hoje, não terminar, e voltar
amanhã pra continuar editando (sem nunca ter mandado pro cliente), a
validade tem que se ajustar (renovar) a partir do novo "hoje", não ficar
travada na data em que começou a digitar.

## Decisões aprovadas

- Validade padrão = data de emissão + 10 dias corridos.
- Enquanto o orçamento está em rascunho (nunca enviado), reabrir e editar
  deve "renovar" — atualizar a data de emissão pra hoje, e a validade junto.

## Decisões pendentes

- O campo continua editável manualmente por cima do valor calculado (ex.:
  vendedor quer dar 15 dias em vez de 10 pra um cliente específico), ou
  passa a ser sempre derivado, sem edição manual? A reunião não fecha isso
  — a versão anterior do campo era "Validade (Opcional)", manual; a leitura
  mais segura é manter editável, só mudando o **valor padrão/automático**.
- "Renovar ao reeditar" deve valer só pra rascunhos, ou também pra
  orçamentos que já foram enviados ao cliente mas ainda não aprovados?
  Renovar depois de enviado pode confundir o cliente (a validade que ele
  recebeu muda sem aviso) — recomendo restringir a rascunho, mas precisa
  confirmar.

## Definição da SPEC

- `useEffect` (ou watch do `react-hook-form`) em `data_emissao`: sempre que
  mudar e `validade` ainda não tiver sido editada manualmente nesta sessão
  de edição, recalcula `validade = addDays(data_emissao, 10)`.
- No carregamento de um orçamento existente com `status === 'Rascunho'`,
  reaproveitar a atribuição de `data_emissao = new Date()` já usada em
  outro ponto do arquivo (linha ~884), disparando o recálculo acima.

## Decisões finais (implementação, 2026-08-13)

- Campo continua editável manualmente por cima do valor calculado — decisão
  já recomendada, seguida.
- "Renovar ao reeditar" **não** foi implementado como comportamento
  automático amplo (reabrir qualquer rascunho não força reset de
  `data_emissao`) — escopo reduzido ao núcleo do pedido (validade =
  emissão + 10 dias, recalculada toda vez que a emissão mudar). O reset de
  `data_emissao` ao selecionar/trocar projeto (já existente) continua
  disparando o recálculo automaticamente por consequência.

## Realizado

### 2026-08-13

- `BudgetFormPage.tsx`: `useEffect` observa `data_emissao` via
  `form.watch` e recalcula `validade = addDays(data_emissao, 10)`, a menos
  que o usuário já tenha editado a validade manualmente nesta sessão
  (`validadeEditadaManualmenteRef`). Botão "Usar padrão (10 dias)" reseta a
  trava e recalcula.
- Publicado Skip 32554, v0.0.328 (junto com SPEC-094), QA limpo.

## Pendências

Nenhuma. Se no futuro o usuário quiser a renovação automática de
`data_emissao` também ao simplesmente reabrir um rascunho (sem trocar de
projeto), é um incremento pequeno sobre o que já existe.
