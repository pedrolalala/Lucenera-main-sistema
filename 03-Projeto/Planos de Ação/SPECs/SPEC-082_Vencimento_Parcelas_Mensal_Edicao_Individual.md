# SPEC-082: Vencimento de parcelas mensal por padrão, com edição individual

**Data:** 2026-08-12
**Sistema:** Orçamentos (`gestao-financeira-clone-544cb`, Skip projectId `32554`)
**Status:** Publicado em produção

## Relato do usuário

No fluxo "Novo Orçamento", ao escolher forma de pagamento Boleto/Cartão com múltiplas parcelas, a "Data de Início do Pagamento" gerava um texto informativo "Vencimentos calculados" com as datas de cada parcela, sem opção de editar. No dia anterior, um teste real mostrou vencimentos 14/08, 17/08 e 20/08 — 3 dias de diferença entre cada parcela, quando o esperado é vencimento mensal (a cada 30 dias/1 mês), e cabe à pessoa que negocia com o cliente poder ajustar cada vencimento individualmente se a negociação definiu datas diferentes.

## Causa raiz

`prazo_pagamento_dias[i] = prazoDias * (i + 1)`, onde `prazoDias` = número de dias entre hoje (dia da criação do orçamento) e a "Data de Início do Pagamento" escolhida. Essa fórmula (SPEC-002, antiga) reproduzia o padrão manual do Connect ("prazo de X dias, parcelas em múltiplos de X"), mas resultava em espaçamento **arbitrário** entre parcelas — coincidentemente igual ao número de dias até a 1ª parcela. No caso relatado, a 1ª parcela foi marcada para daqui a 3 dias, então as parcelas seguintes saíram espaçadas em múltiplos de 3 dias (3, 6, 9 dias) em vez de meses. Não havia nenhum campo pra editar os vencimentos calculados — o texto era só informativo.

**Contexto adicional (não alterado nesta SPEC)**: o backend (`aprovar_orcamento_financeiro`) calcula o vencimento real de cada parcela como `current_date` (data da aprovação financeira, não da criação do orçamento) `+ prazo_pagamento_dias[i]`. Ou seja, os offsets em dias sempre foram — e continuam sendo — reinterpretados a partir do dia em que o orçamento é aprovado, não do dia em que foi criado. Essa é uma decisão de arquitetura pré-existente (SPEC-002) que não foi revista aqui; o fix só corrige a fórmula que gera os offsets, preservando o contrato "array de offsets em dias" que o RPC já espera.

## O que mudou

- **Vencimento padrão**: cada parcela a partir da 2ª vence, por padrão, exatamente 1 mês após a parcela anterior (`addMonths`), a partir de "Data de Início do Pagamento" (que continua sendo o vencimento da 1ª parcela).
- **Edição individual**: novo bloco "Vencimentos das demais parcelas" mostra um seletor de data por parcela (2ª em diante), pré-preenchido com o padrão mensal, editável independentemente. Um link "Usar padrão (1 mês)" aparece quando uma parcela foi sobrescrita manualmente, pra voltar ao cálculo automático.
- Cada vencimento calendário escolhido (padrão ou manual) é convertido num offset em dias a partir de hoje antes de submeter — preserva o espaçamento calendário escolhido independente de quando a aprovação financeira de fato ocorrer.
- **Edição de orçamento existente**: os vencimentos calendário de cada parcela são reconstruídos a partir dos offsets salvos (`prazo_pagamento_dias`) e da `data_inicio_pagamento` salva, preenchendo o novo bloco de edição individual corretamente ao reabrir um orçamento com parcelas já customizadas.

## Arquivos modificados

| Arquivo | Mudança |
| --- | --- |
| `src/pages/BudgetFormPage.tsx` | Novo campo `parcelas_datas` no schema (overrides por parcela); cálculo de `prazo_pagamento_dias` reescrito pra usar `addMonths` + overrides em vez da fórmula `prazoDias * i`; novo bloco de UI "Vencimentos das demais parcelas"; reconstrução dos overrides ao editar um orçamento existente |

## Verificação

- `npx tsc --noEmit` + `npx oxlint` + `npm run build` limpos.
- QA do Skip (setup/staticAnalysis/build/integrations/test) passou antes do publish.
- Verificado ao vivo em produção: Boleto, 3 parcelas, Data de Início 14/08/2026 → Parcela 2 = 14/09/2026, Parcela 3 = 14/10/2026 (confirmado via inspeção do DOM, já que a interação por clique/screenshot da automação de navegador estava instável nesta sessão — contornado disparando eventos de ponteiro via JavaScript).

## Sem migration

Nenhuma mudança de schema no banco — `prazo_pagamento_dias`/`condicoes_pagamento`/`data_inicio_pagamento` continuam com o mesmo formato (array de offsets em dias + data), só a fórmula que os gera no frontend mudou.
