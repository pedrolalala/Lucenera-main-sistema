---
titulo: "SPEC-133 — Revisão Financeira Completa na Confirmação de Aprovação Financeira"
status: "PUBLICADO em produção (Skip 32554 v0.0.363) — card somente leitura, sem edição de parcela"
data_ultima_modificacao: 2026-09-14
sistemas_envolvidos:
  - Orçamentos
---

> **Revisão 2026-09-14 (instrução do usuário, com referência visual)**: a edição de valor de parcela dentro deste diálogo foi **revogada**. O card é agora somente leitura — qualquer ajuste financeiro (valor de entrada, vencimento) é feito antes, na tela de condições de pagamento do orçamento (`BudgetFormPage`), não nesta etapa de confirmação. Como consequência, a migration da RPC (`p_valores_parcelas`) **não é mais necessária** — `approveBudgetFinancial` voltou ao contrato original (só `p_orcamento_id`). O checklist abaixo é o histórico da implementação original (com edição); ver "Revisão — somente leitura" mais abaixo para o estado final.

# SPEC-133 — Revisão Financeira Completa na Confirmação de Aprovação Financeira

> Depende do contrato já fechado pela SPEC-016/SPEC-017 (`enviado_cliente -> Aprovação da Equipe -> Aprovação Financeira -> Orçamento Aprovado`, `FinancialApprovalDialog` como confirmação final, `BudgetFormPage` como editor único). Esta SPEC não reabre esse contrato — decide apenas o que aparece/é editável na etapa final de confirmação.

## Checklist de Ação

- [ ] Confirmar por introspecção direta do Supabase real (não só `supabase/db/current/`, que está desatualizado para `orcamentos` — ver "Achado crítico") que `orcamentos.desconto_tipo` e `orcamentos.valor_sinal` existem com esses nomes/tipos.
- [ ] Adicionar `desconto_tipo` e `valor_sinal` à interface `Budget` (`useBudgetStore.ts`) e ajustar `src/lib/supabase/types.ts` do sistema de Orçamentos para refletir essas colunas.
- [ ] Extrair um helper puro (ex. `src/lib/budget-financial-summary.ts`) reaproduzindo a fórmula de bruto/desconto/líquido já usada em `BudgetFormPage.tsx` (linhas ~735-761), para não duplicar a lógica de cálculo.
- [ ] Extrair/reaproveitar a lógica de `_lucenera_parse_prazo_pagamento` (ou reproduzir seu contrato) para calcular, no frontend, a data de vencimento prevista de cada parcela como `hoje + prazo_pagamento_dias[i]` — já que a RPC usa `current_date` no momento da aprovação como data-base, não a data de salvamento do orçamento.
- [ ] Implementar em `FinancialApprovalDialog.tsx` o resumo financeiro completo: Valor Bruto, Desconto (R$), Valor Líquido, Valor de Sinal (se houver), Número de Parcelas, Valor de cada parcela (com input editável), Data de vencimento prevista de cada parcela, Forma de Pagamento.
- [ ] Alterar a RPC `aprovar_orcamento_financeiro` para aceitar um parâmetro novo de valores de parcela customizados (ex. `p_valores_parcelas numeric[] default null`) — quando informado, usa esses valores linha a linha em vez da divisão igualitária atual; quando `null`/omitido, mantém o comportamento atual (divisão igual, última parcela absorve o resto). Preservar todas as validações e efeitos colaterais existentes (guard `hub_pode_executar(..., 'aprovar')`, reserva de estoque, idempotência, `historico_status_orcamentos`).
- [ ] Validar no frontend, antes de habilitar "Confirmar Aprovação Irreversível", que a soma dos valores de parcela editados é positiva e cada parcela é `> 0` (mesma constraint que já existe em `projeto_parcelas.valor`) — a soma pode divergir do `valor_total` do orçamento (decisão de negócio abaixo), então não travar nesse caso.
- [ ] Garantir que editar valor/data de parcela nesta tela **não** dispara o reset de ciclo de aprovação da SPEC-019 (a chamada segue sendo `aprovar_orcamento_financeiro`, não uma edição de `orcamentos`, então isso já é natural pela forma como a Rota foi decidida — só confirmar que nenhum trigger de `orcamentos` dispara nesse caminho).
- [ ] Atualizar `04-Sistemas/gestao-financeira-clone-544cb (1)/supabase/AI_DB_CONTEXT.md` com o novo parâmetro da RPC e o novo contrato de parcelas customizadas.
- [ ] Atualizar `supabase/db/domains/orcamentos.md` e reextrair `supabase/db/current/` para este domínio (pendência crônica já registrada nesse arquivo, aproveitar esta SPEC para fechar).
- [ ] Rodar `pnpm run lint` e `pnpm run build` no sistema de Orçamentos.

### Passos manuais do usuário

- [ ] Homologar visualmente o novo resumo dentro do `FinancialApprovalDialog` com quem aprova financeiramente.
- [ ] Validar ao vivo: criar orçamento de teste, editar valor de uma parcela na confirmação, aprovar, e conferir via SELECT em `projeto_parcelas`/`boletos` que os valores batem com o que foi digitado.

## Objetivo

Hoje, ao confirmar a aprovação financeira de um orçamento (`FinancialApprovalDialog.tsx`), o usuário só vê Valor Total, Qtd. de Itens, Cond. Pagamento (uma string crua de offsets em dias, tipo `"24"` ou `"0/30/60"`, sem tradução para data ou parcela) e Forma de Pagamento, além de um checkbox e a exigência de digitar "APROVAR". Essa é a última tela antes de uma ação **irreversível** que gera `projeto_itens`, `projeto_parcelas`, boletos e reserva de estoque — e ela não deixa claro quanto é o valor bruto, quanto é desconto, quanto sobra líquido, quantas parcelas serão geradas, qual o valor de cada uma e quando cada uma vence.

O usuário pediu mais clareza nesse ponto — inclusive a possibilidade de ajustar ali mesmo o valor de uma parcela (tipicamente aumentar a entrada), já que hoje só a data de cada parcela pode ser customizada, nunca o valor.

## Decisões aprovadas

Decisões já fechadas em SPECs anteriores, que esta SPEC **não** reabre:

- A fila de "Aprovação Financeira" trabalha por `orcamento_id`, nunca por `projeto_id` (SPEC-016).
- Ver/Editar um orçamento pendente de aprovação financeira reaproveita `BudgetFormPage`; não existe editor paralelo (SPEC-017).
- `FinancialApprovalDialog` é a confirmação final; a edição de dados do orçamento acontece em `BudgetFormPage` (SPEC-017) — **exceção introduzida por esta SPEC**: o valor de cada parcela passa a ser editável dentro do próprio `FinancialApprovalDialog`, ver decisão abaixo.
- `ProjectFinancialReviewDialog.tsx`, `FinancialApprovalEditDialog.tsx`, `ProjectOrcamentoList.tsx`, `projectFinancialApprovalService.ts` e `financialApprovalEditService.ts` estão fora do fluxo principal (confirmado: `FinancialApprovalTab.tsx` não os importa mais) — continuam como código órfão; limpeza fica para uma SPEC de manutenção técnica separada, não faz parte do escopo aqui.
- A aprovação final é sempre via RPC `aprovar_orcamento_financeiro`, nunca por trigger, nunca por `project_id`.
- Editar `valor_total`/`forma_pagamento`/itens etc. de um orçamento já em `Aprovação Financeira` reinicia o ciclo de aprovação (SPEC-019) — **isso não se aplica** ao ajuste de valor de parcela feito nesta tela, por decisão desta SPEC (ver abaixo): a chamada continua sendo `aprovar_orcamento_financeiro` com um parâmetro extra, não uma edição de `orcamentos`.

**Decisões desta SPEC (definidas pelo usuário em 2026-09-11):**

1. **Onde mostrar o resumo completo**: dentro do próprio `FinancialApprovalDialog`, antes do campo "digite APROVAR" — cobre também quem aprova direto da lista, sem passar por "Ver/Editar" antes.
2. **Onde editar o valor da parcela**: diretamente na tela de confirmação (não no formulário de edição do orçamento). Exige novo parâmetro na RPC de aprovação (`p_valores_parcelas`), não uma nova coluna em `orcamentos`.
3. **Recalcular as demais parcelas ao editar uma?** Não. A soma das parcelas editadas pode ficar diferente do `valor_total` do orçamento — `valor_total` continua sendo o valor "de tabela"/negociado originalmente; a divisão em parcelas na confirmação é a execução prática do pagamento e pode divergir (ex.: entrada maior, saldo menor nas demais, sem redistribuição automática).
4. **Reabre o ciclo de aprovação do cliente?** Não. Editar valor/data de parcela nesta etapa é considerado parte da própria aprovação financeira, não uma edição de orçamento sujeita à regra da SPEC-019.

## Definição da SPEC

### Estado atual confirmado (leitura de código)

**`FinancialApprovalDialog.tsx`** recebe um `Budget` inteiro mas só exibe 4 campos: `valor_total`, `itens.length`, `condicoes_pagamento` (string crua) e `forma_pagamento`. Não há cálculo de bruto/desconto/líquido nem visualização de parcelas/vencimentos.

**Cálculo de valores hoje só existe em `BudgetFormPage.tsx`** (linhas ~735-761):

```
valorSubtotal      = Σ (quantidade × preço_unitário × (1 - desconto_item%))
valorAposSinal     = max(0, valorSubtotal - valor_sinal)
descontoValorReais = desconto_tipo == 'valor' ? min(desconto_global, valorAposSinal)
                                               : valorAposSinal × (desconto_global% / 100)
valorComDesconto   = valorAposSinal - descontoValorReais
valorTotal         = valorComDesconto + (frete_tipo == 'com_frete' ? frete_valor : 0)
```

`orcamentos.valor_total` é o único valor persistido — já **líquido** (pós-sinal, pós-desconto, com frete). Não existe coluna "valor bruto" nem "valor do desconto em R$" persistida; ambos são deriváveis a partir de `orcamento_itens`, `desconto_global`/`desconto_tipo` e `valor_sinal`.

**Parcelas e vencimentos**: `orcamentos.condicoes_pagamento` é uma string derivada (join por "/") dos offsets em dias entre "hoje" (momento do salvamento do formulário) e cada vencimento (`BudgetFormPage.tsx`, linhas ~1176-1242). `orcamentos.prazo_pagamento_dias` (`integer[]`) guarda o mesmo dado estruturado. Na RPC real `aprovar_orcamento_financeiro` (`supabase/db/current/03_functions.sql`, linha 389+), a data-base para reconstituir vencimentos é `current_date` **no momento da aprovação** (`v_data_base := current_date`), não a data de salvamento — o espaçamento entre parcelas é preservado, mas a data-base desliza. Por isso o resumo deve recalcular `hoje + prazo_pagamento_dias[i]` no momento em que o dialog é aberto, não confiar em `condicoes_pagamento` como data absoluta.

**Valor por parcela — hoje sempre igualitário.** Na RPC (linhas 655-668):

```sql
v_valor_total := coalesce(v_orcamento.valor_total, 0);
v_valor_base  := round(v_valor_total / v_qtd_parcelas, 2);
FOR v_i IN 1..v_qtd_parcelas LOOP
  IF v_i = v_qtd_parcelas THEN
    v_valor_parcela := v_valor_total - v_valor_acumulado;  -- absorve resto de arredondamento
  ELSE
    v_valor_parcela := v_valor_base;
  END IF;
  INSERT INTO projeto_parcelas (..., valor, ...) VALUES (..., v_valor_parcela, ...);
END LOOP;
```

A RPC recebe apenas `p_orcamento_id`. Nenhum lugar do sistema hoje permite valor de parcela customizado.

**O banco já suporta valor não uniforme por parcela**: `projeto_parcelas.valor` (`numeric(15,2) NOT NULL CHECK (valor > 0)`) é livre por linha, sem constraint de soma ou uniformidade. O gap é de contrato da RPC + UI, não de schema.

**Enum `pagamento_forma`** (`supabase/db/current/01_schema_full.sql`, linha 150): `pix`, `cartao`, `boleto`, `transferencia`, `cheque`, `dinheiro` — já cobre tudo que o usuário pediu, nenhum valor a acrescentar.

### Achado crítico — `supabase/db/current/` está desatualizado para Orçamentos

O snapshot central (`01_schema_full.sql`, tabela `orcamentos`, linha 5335) não lista `desconto_tipo`, `valor_sinal`, `perfil`, `natureza_operacao`, `subgrupo`, `aprovado_cliente_origem` nem `origem_connect_*` — colunas que `BudgetFormPage.tsx` já grava ativamente (linhas 1228-1263) e que SPECs anteriores (050, 064, 068, 071, 077) documentam como aplicadas. `supabase/db/domains/orcamentos.md` já registra essa pendência crônica. O `types.ts` local também não declara `desconto_tipo`/`valor_sinal`, nem a interface manual `Budget` em `useBudgetStore.ts`.

**Implicação**: antes de codar o resumo, confirmar por introspecção direta do Supabase real que essas colunas existem com esse nome/tipo, e aproveitar para reextrair `supabase/db/current/` e regenerar `types.ts`.

### Novo contrato da RPC `aprovar_orcamento_financeiro`

```sql
aprovar_orcamento_financeiro(
  p_orcamento_id uuid,
  p_valores_parcelas numeric[] default null
)
```

- Quando `p_valores_parcelas` é `null` (chamada antiga, compatível): mantém o comportamento atual — divisão igualitária de `valor_total`, última parcela absorve o resto.
- Quando informado: `array_length(p_valores_parcelas, 1)` deve ser igual à quantidade de parcelas calculada a partir de `prazo_pagamento_dias`/`forma_pagamento`; cada elemento vira `projeto_parcelas.valor` na posição correspondente, sem recalcular nem validar contra `valor_total` (a divergência é intencional, por decisão desta SPEC). Validar apenas `valor > 0` em cada posição (a própria CHECK constraint da tabela já barra isso, mas validar antes evita rollback de transação inteira).
- Todas as demais validações/efeitos colaterais da RPC (guard de permissão, reserva de estoque, geração de boletos, `historico_status_orcamentos`, idempotência) permanecem inalterados.

### Tabelas e RPCs afetadas

| Objeto | Tipo | Impacto |
|---|---|---|
| `orcamentos` | tabela | Só leitura nesta SPEC (fonte do resumo); nenhuma coluna nova. |
| `orcamento_itens` | tabela | Fonte do "valor bruto" (leitura). |
| `projeto_parcelas` | tabela | Recebe os valores customizados vindos de `p_valores_parcelas`; nenhuma mudança de schema. |
| `aprovar_orcamento_financeiro` | RPC | Ganha parâmetro opcional `p_valores_parcelas numeric[]`, compatível com chamadas antigas. |
| `Budget` (interface TS) | frontend | Precisa declarar `desconto_tipo`, `valor_sinal`. |
| `FinancialApprovalDialog.tsx` | frontend | Ganha o resumo completo + inputs de valor por parcela. |

### Análise de ecossistema

- Depende de `orcamentos`, `orcamento_itens`, `projeto_parcelas`, `boletos` (indiretamente, pós-aprovação). Não afeta CRM, Financeiro (Admin Bancária), Cadastro, Estoque/Compras, Logística, RH ou Hub — Admin Bancária só consome `projeto_parcelas`/`boletos` já gerados; o contrato de saída (uma parcela = uma linha com `valor` e `data_vencimento`) não muda.
- Nenhum dado duplicado introduzido — bruto/desconto/líquido continuam sendo cálculo, não coluna nova.
- Padrão de acesso a dados do sistema (Zustand + `supabase.from`/`supabase.rpc` direto nos componentes/store) deve ser mantido — o novo cálculo deve ser um helper puro, não uma camada de serviço nova.

## Critérios de aceite (revisados — somente leitura)

- [x] O `FinancialApprovalDialog` mostra: Valor Bruto, Valor de Desconto (R$), Valor Líquido, Valor de Sinal (se houver), Número de Parcelas, Valor de cada parcela, Data de vencimento prevista de cada parcela, Forma de Pagamento — **tudo somente leitura**, nenhum campo editável.
- [x] Confirmar aprovação chama `aprovar_orcamento_financeiro(p_orcamento_id)` sem nenhum parâmetro extra — comportamento idêntico ao de antes desta SPEC (divisão igual, última parcela absorve o resto).
- [x] Nenhuma mudança quebra os critérios já fechados da SPEC-016/017 (fila por `orcamento_id`, aprovação idempotente, reserva de estoque intacta, guard de permissão) — não toca a RPC.
- [x] `pnpm run tsc`/`vite build` passam no sistema de Orçamentos.
- [ ] Teste ao vivo: abrir a confirmação de um orçamento real em "Aprovação Financeira" e conferir que o resumo bate com os dados do orçamento, sem nenhum campo clicável/editável.

~~## Testes obrigatórios~~ (obsoleto — testes de edição de parcela não se aplicam mais; ver critérios acima)

## Realizado

### 2026-09-11

- SPEC criada a partir de pergunta do usuário sobre o significado de "Cond. Pagamento: 24" no dialog de confirmação, que expôs a falta de detalhamento financeiro nessa etapa.
- Investigação de código (frontend `BudgetFormPage.tsx`/`FinancialApprovalDialog.tsx`) e da RPC real `aprovar_orcamento_financeiro` confirmou: divisão de parcelas hoje é sempre igualitária, banco (`projeto_parcelas`) já suporta valores não uniformes, e `supabase/db/current/` está desatualizado para colunas de `orcamentos` (`desconto_tipo`, `valor_sinal`) já usadas em produção.
- Usuário decidiu as 4 questões em aberto: resumo completo dentro do `FinancialApprovalDialog`; edição de valor de parcela direto na tela de confirmação (não no formulário); sem recálculo automático das demais parcelas; sem reabertura do ciclo de aprovação do cliente.
- Ainda não implementado.

## Pendências

- [ ] Homologar visualmente com quem aprova financeiramente.
- [ ] Decidir separadamente (fora desta SPEC) se os arquivos órfãos (`ProjectFinancialReviewDialog.tsx` e afins) devem ser removidos numa limpeza técnica futura.

## Migration da RPC (`20260914_141`) — ABANDONADA, não aplicar

A migration `supabase/db/migrations/20260914_141_spec133_valores_parcela_customizados/001_p_valores_parcelas.sql` foi escrita, testada (dry-run + smoke-test de chamada no formato antigo) e chegou a ser publicada por uma versão intermediária do frontend — mas a revisão de 2026-09-14 (usuário pediu card somente leitura) **eliminou a necessidade dela**: sem edição de parcela, não há nada pra mandar num parâmetro `p_valores_parcelas`. O arquivo fica no repositório como histórico técnico (inclusive o achado sobre `DROP FUNCTION` + overload + re-grant, que pode ser útil se uma SPEC futura reabrir esse caminho), mas **não deve ser aplicado** — a RPC real em produção continua com a assinatura original de 1 argumento, e é isso que o frontend publicado (Skip `32554` v0.0.363) espera.

## Revisão — somente leitura (2026-09-14)

Instrução do usuário, com referência visual (2 imagens: card atual / card desejado): a confirmação de Aprovação Financeira é a etapa final — **não pode ter nenhum campo editável**. Qualquer ajuste em valor de parcela, vencimento etc. é feito antes, na tela de condições de pagamento do próprio orçamento (`BudgetFormPage`), não nesta confirmação.

Mudanças em relação à versão anterior (com edição, nunca publicada):
- `FinancialApprovalDialog.tsx`: removidos os `Input` editáveis por parcela, o estado `parcelaValores`, a validação `parcelasValidas`/`parcelasForamEditadas` e o aviso de "valor editável". Cada parcela agora é uma linha somente leitura (número, data de vencimento, valor), com uma nota explícita "Somente leitura — para ajustar valor de parcela ou vencimento, edite o orçamento antes de aprovar."
- `onConfirm` volta a ser `() => Promise<void>` (sem parâmetro).
- `approveBudgetFinancial` (`budgetApprovalService.ts`) volta ao contrato original: só `p_orcamento_id`, sem `p_valores_parcelas`.
- `handleFinancialApproval` (`BudgetFormPage.tsx`) e `handleConfirmApproval` (`FinancialApprovalTab.tsx`) voltam a ser `async () => {...}`, sem parâmetro.

Todos os outros campos do resumo (Valor Bruto, Sinal, Desconto, Valor Líquido, Frete, Valor Total, Forma de Pagamento, datas de vencimento previstas) continuam exatamente como implementados — só deixaram de ser editáveis.

**Publicado em produção**: `https://gestao-financeira-clone-544cb.goskip.app` (Skip `32554` v0.0.363, QA 100% verde) — sem nenhuma dependência de migration, já que a chamada da RPC voltou ao formato original que a produção já suporta.
