---
titulo: "SPEC-152 — Melhorias no fluxo de Orçamento (reunião Vinícius 16/09)"
status: não iniciado
data_ultima_modificacao: 2026-09-17
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb)
  - CRM (lucenera-crm-3bd29) — apenas verificação/possível paridade
  - Financeiro / Administração Bancária (retorno-bancario-bradesco-5392a) — só no item de Permuta (contrapartida em Contas a Pagar)
---

# SPEC-152 — Melhorias no fluxo de Orçamento (reunião Vinícius 16/09)

> Origem: primeira metade da reunião "24. Lucenera (Vinicius) - 16.09.2026_novo sistema de vendas" (`02-Reunioes/.../Reunião 01`), antes de entrar no assunto de Vendas/Fiscal (coberto pela SPEC-153).

## Checklist de Ação

- [ ] `ProjectCreateModal.tsx` (Orçamentos): permitir cadastrar um cliente novo sem fechar o fluxo de "Criar Projeto" — adicionar ação "Novo Cliente" no campo Cliente (reaproveitando `ClientCreateModal.tsx`, já existente desde a SPEC-061), no mesmo padrão já usado em `lucenera-crm-3bd29 (1)/src/pages/ProjectNew.tsx` (Popover + Command + item "Novo Cliente" abrindo modal empilhado).
- [ ] `ProjectCreateModal.tsx` (Orçamentos): campo "Responsável Obra" (`responsavel_obra_id`) passa a listar apenas contatos com `contato_tipos.tipo = 'engenheiro'`, em vez de todos os `contatos`. Campo "Arquiteto" (`arquiteto_id`) é mantido como está — a reunião concluiu por manter os dois campos, distintos por papel, não eliminar um deles.
- [ ] Adicionar `'carteira'` ao enum `public.pagamento_forma` (`ALTER TYPE ... ADD VALUE`) e ao seletor de forma de pagamento em `BudgetFormPage.tsx`. Comportamento na aprovação (`aprovar_orcamento_financeiro`): quando a forma de pagamento é `carteira`, a parcela correspondente **não gera boleto** (fica em aberto, sem cobrança formal). *(Pendência de regra de negócio — ver seção Pendências: se ainda assim deve gerar `projeto_parcelas` para controle interno de saldo, ou ficar totalmente fora do sistema de parcelas.)*
- [ ] Adicionar `'permuta'` ao enum `public.pagamento_forma` (o rótulo `'Permuta'` já existe em `FORMA_PAGAMENTO_LABELS`/`budget-financial-summary.ts`, mas sem valor de enum correspondente no banco — hoje selecionar essa opção falharia).
- [ ] Corrigir bug: campo "Quantidade de Parcelas" (`BudgetFormPage.tsx`, `parcelas` — schema `z.coerce.number()`) não permite apagar o valor anterior ao editar (fica "cravado"); ajustar para aceitar estado local vazio/temporário antes da coerção final.
- [ ] Corrigir bug: ao editar campos do plano de pagamento (quantidade de parcelas, datas), a tela não reflete a mudança até salvar — investigar sincronismo entre estado local do formulário e o estado pós-`updateBudget`.
- [ ] Nova granularidade de parcelas: permitir valor **customizado por parcela** (hoje o sistema só divide `valor_total`/N igualmente — `budget-financial-summary.ts`, `calcularResumoFinanceiro`). Decisão de schema proposta (duas opções, escolher antes de implementar — ver "Definição da SPEC"):
  - **Opção A** (array paralelo, mínima): `orcamentos.valores_parcelas_customizados numeric(12,2)[]` nullable, alinhado por índice a `prazo_pagamento_dias`; quando nulo, mantém divisão igual (comportamento atual).
  - **Opção B** (mais robusta, mas maior escopo): unificar em `orcamentos.plano_parcelas jsonb` (array de `{numero, dias_offset, valor, forma_pagamento, permuta_fornecedor_id}`), substituindo gradualmente `prazo_pagamento_dias` e abrindo caminho natural para a permuta por parcela (item abaixo) sem precisar de mais um array paralelo.
- [ ] UI em `BudgetFormPage.tsx`: exibir campo de valor editável por parcela (pré-preenchido com a divisão igual), validando ao vivo que a soma bate com o valor a pagar (`valorAposSinal`/`valor_total`, já calculado em `budget-financial-summary.ts`); bloquear salvar/enviar se a soma não bater.
- [ ] `aprovar_orcamento_financeiro`: usar os valores customizados por parcela (se presentes) em vez da divisão igual ao gerar `projeto_parcelas`.
- [ ] Suporte a parcela paga por **permuta**: quando uma parcela tem `forma_pagamento = 'permuta'`, a aprovação deve (a) marcar a parcela como recebida sem gerar `boletos`, e (b) lançar automaticamente uma obrigação de contrapartida (Contas a Pagar) para o fornecedor da permuta, no domínio Financeiro/Administração Bancária. Requer:
  - Nova coluna `projeto_parcelas.permuta_fornecedor_id uuid REFERENCES contatos(id)` nullable (obrigatória quando `forma_pagamento = 'permuta'`).
  - Uma forma de rastrear a obrigação gerada no Financeiro até a venda de origem (hoje `negociacoes`/`transacoes` não têm nenhum vínculo com `orcamentos` — precisa de uma coluna nova, ex. `negociacoes.orcamento_id_origem uuid REFERENCES orcamentos(id)` nullable, seguindo o mesmo padrão já usado em `boletos.orcamento_id`).
  - Qual `plano_de_contas`/`categorias_financeiras` usar para essa despesa de contrapartida é decisão de negócio — deixado em Pendências.
- [ ] PDF do orçamento (`supabase/functions/generate-report/index.ts`, `reportType === 'orcamento'`): parar de mostrar "condição de pagamento" como contagem de dias (`orcamentos.condicoes_pagamento`, hoje gerado em `BudgetFormPage.tsx:1287` como `(prazoPagamentoDias ?? []).join('/')`, ex. "14/44/75"). Substituir por uma pequena tabela de parcelas com **data de vencimento absoluta + valor** de cada uma (a mesma estrutura que `budget-financial-summary.ts`/`calcularResumoFinanceiro` já calcula como `ParcelaPrevista[]`) — igual um boleto: 30/09 — R$X, 30/10 — R$Y, 30/11 — R$Z.
- [ ] Atualizar `AI_DB_CONTEXT.md` de Orçamentos: a seção "SPEC-019" descreve reset do ciclo de aprovação por edição de `valor_total`/`forma_pagamento`/etc. como se estivesse ativo, mas a investigação da SPEC-135 (mais recente, checada direto no banco real) já confirmou que o único mecanismo de reset em produção hoje é o trigger em `orcamento_itens` — a doc ficou contraditória dentro do próprio arquivo e deve ser corrigida/anotada como superada.

### Passos manuais do usuário

- [ ] Confirmar, ao vivo no Skip publicado (não só no código local — risco conhecido de "Skip drift"), que a regra "pagamento/total não reinicia aprovação do cliente, só item reinicia" está de fato assim hoje (a investigação de código aponta que sim, mas o usuário testou ao vivo na reunião e não fechou o teste).
- [ ] Decidir a regra de negócio da forma de pagamento "Carteira" (ver Pendências).
- [ ] Decidir o `plano_de_contas`/categoria financeira usados no lançamento automático de contrapartida da permuta.
- [ ] Escolher Opção A ou B para o schema de parcelas customizadas (ver Checklist).
- [ ] Aplicar as migrations (`ALTER TYPE ... ADD VALUE` não pode rodar dentro de uma transação com outros comandos no mesmo `BEGIN`, atenção ao aplicar).
- [ ] Homologar visualmente o novo PDF do orçamento com Vinícius (ele reagiu especificamente ao "14 dias de quando?" — validar que a tabela de parcelas resolve a confusão).

## Objetivo

Consolidar as melhorias e correções pontuais no sistema de Orçamentos discutidas na primeira metade da reunião de 16/09 — antes de qualquer coisa relacionada a Vendas/Nota Fiscal (SPEC-153) — cobrindo: cadastro de cliente sem sair do fluxo de criar projeto, campo Responsável de Obra restrito a engenheiros, nova forma de pagamento "Carteira", correção de dois bugs de UI no plano de pagamento, parcelas com valor customizável (não só divisão igual), forma de pagamento "Permuta" com lançamento automático de contrapartida no Financeiro, e PDF do orçamento mostrando datas/valores reais de vencimento em vez de contagem de dias.

## Decisões aprovadas

- Manter os dois campos "Arquiteto" e "Responsável da Obra" no projeto — não eliminar nenhum dos dois. "Responsável da Obra" passa a ser conceitualmente um Engenheiro (lista filtrada), não mais qualquer contato.
- Campo "Código do Projeto" fica fora de escopo por decisão explícita do usuário — não implementar agora (mencionado na reunião só como bug de validação incidental durante um teste, não como pedido de mudança).
- "Sinal" continua sendo um conceito diferente de "parcela 1 customizada" — o sinal é abatido antes da divisão em parcelas e não muda de comportamento nesta SPEC; a novidade é permitir editar o valor de cada parcela gerada depois do sinal/desconto/frete já aplicados.
- Regra de negócio "não emitir nota fiscal nem boleto direto na aprovação do orçamento" pertence à SPEC-153, não a esta.
- A impressão do orçamento (PDF) deve sempre dizer "Orçamento", nunca "Venda" — investigação confirmou que o gerador atual (`generate-report`) já respeita isso; não é necessário mudar esse rótulo, só o formato de condição de pagamento.

## Definição da SPEC

### 1. Cliente sem fechar "Criar Projeto"

- **Estado atual**: `ProjectCreateModal.tsx` (Orçamentos) tem o campo Cliente como `SearchableSelect` simples, sem ação de criar. Usuário precisa fechar o modal de projeto, ir em Clientes, cadastrar, voltar e reabrir "Criar Projeto".
- **CRM**: investigado `lucenera-crm-3bd29 (1)/src/pages/ProjectNew.tsx` — já tem um item "Novo Cliente" no combobox de cliente que abre um modal empilhado (`setModalType('cliente')`) sem fechar o formulário do projeto. **Não encontrei o mesmo bug no CRM** nesta tela. Se o usuário tiver visto o problema em outra tela do CRM (ex. um modal rápido de criar projeto usado em outro lugar, que não localizei), é necessário apontar a tela exata — ver Pendências.
- **Ação**: replicar em `ProjectCreateModal.tsx` (Orçamentos) o mesmo padrão já usado no CRM: item "Novo Cliente" no `SearchableSelect`/Command, abrindo `ClientCreateModal.tsx` (já existe desde SPEC-061) empilhado, preenchendo `cliente_id` ao concluir sem perder o restante do formulário do projeto.

### 2. Responsável da Obra → Engenheiro

- **Estado atual**: `responsavel_obra_id` em `ProjectCreateModal.tsx` usa `options={contatos.map(...)}` — todos os contatos, sem filtro de tipo.
- **Ação**: filtrar por `contato_tipos.tipo = 'engenheiro'` (constraint já existe: `contato_tipos_tipo_check` inclui `'engenheiro'`). Repetir a mesma checagem em qualquer outro formulário de projeto que reaproveite essa lista (verificar CRM/`ProjectNew.tsx`/`ProjectDetail.tsx`, que também referenciam `responsavel_obra_id`).

### 3. Forma de pagamento "Carteira"

- Hoje não existe (nem como valor de enum, nem como opção de UI, nem como rótulo morto). Enum real (`src/lib/supabase/types.ts`, gerado do banco): `pix | cartao | boleto | transferencia | cheque | dinheiro`.
- Adicionar `'carteira'` ao enum e à UI. Semântica pedida pelo usuário: "fica em aberto, sem gerar cobrança" — mas não ficou claro se isso significa (a) ainda criar `projeto_parcelas` (só sem `boletos`), útil para acompanhar saldo em aberto, ou (b) não criar registro financeiro nenhum, só uma anotação no orçamento. **Deixado como pendência de decisão de negócio.**

### 4. Bugs de UI no plano de pagamento

- Bug 1 (input "cravado"): campo `parcelas` usa `z.coerce.number()` — ao apagar o conteúdo do input, o valor não some porque a coerção reverte para o número anterior antes do usuário conseguir digitar o novo. Corrigir permitindo string vazia como estado transitório, coagindo só no blur/submit.
- Bug 2 (tela não reflete até salvar): reportado ao vivo na reunião ao editar quantidade de parcelas — precisa investigar se `BudgetFormPage.tsx` está re-renderizando a partir do estado do form (`react-hook-form`) corretamente ou se há um componente derivado (ex. pré-visualização de parcelas) lendo de um estado desatualizado (`budget` original em vez de `form.watch(...)`).

### 5. Parcelas com valor customizado

- Ver Checklist para as duas opções de schema (A: array paralelo `valores_parcelas_customizados`; B: `plano_parcelas jsonb` unificado).
- Recomendo a Opção B tecnicamente (evita um terceiro array paralelo quando entra a Permuta por parcela), mas é uma decisão de arquitetura do usuário/implementador — ambas são tecnicamente viáveis e não violam nenhuma invariante do ecossistema.
- Regra dura, conforme pedido do usuário: soma das parcelas deve ser **exatamente** igual ao valor a pagar (`valor_total`, já líquido de sinal/desconto/frete) — bloquear salvamento/aprovação se não bater, nunca arredondar silenciosamente sobre o usuário.

### 6. Permuta com contrapartida automática

- Caso de uso real, não hipotético (ex. "Rod Parrilha", "Florença" citados na reunião).
- Fluxo: parcela marcada `forma_pagamento = 'permuta'` + `permuta_fornecedor_id` (fornecedor real, `contatos.tipo = 'fornecedor'`) → na aprovação financeira, a parcela nasce com `status = 'paga'`/sem boleto, e o sistema cria uma obrigação de Contas a Pagar espelhada no Financeiro (mesmo valor, fornecedor da permuta) — cruza para o domínio Financeiro (`transacoes`/`negociacoes`), que precisa de uma FK nova de rastreio (`orcamento_id_origem`) para não ficar uma obrigação financeira "solta" sem origem.
- Categoria/plano de contas da despesa de contrapartida: decisão de negócio, não decidida aqui.

### 7. PDF do orçamento — datas e valores reais

- Remover a string "X dias" de `condicoes_pagamento` e desenhar, no PDF (`generate-report/index.ts`), uma tabela pequena com `ParcelaPrevista[]` (já calculada em `budget-financial-summary.ts`): número da parcela, data de vencimento (absoluta), valor.
- Isso deve reutilizar os valores customizados por parcela do item 5, quando existirem — senão cai no cálculo de divisão igual já existente.

## Análise de ecossistema (obrigatória)

- **Depende de `orcamentos`, `projeto_parcelas`, `contatos`, `usuarios`?** Sim — `orcamentos` (novo enum de forma de pagamento, novo array/jsonb de parcelas), `projeto_parcelas` (novo campo de fornecedor de permuta), `contatos` (fonte de engenheiros e fornecedor de permuta).
- **Afeta CRM, Orçamentos, Financeiro?** Orçamentos (principal), Financeiro (só na contrapartida da permuta — nova FK em `negociacoes`/`transacoes`), CRM (só verificação de paridade do bug de cliente, sem mudança de schema).
- **Dado duplicado que deveria ser derivado?** Não identificado nesta SPEC — os valores por parcela e o fornecedor de permuta são dados genuinamente negociados, não derivam de nenhuma outra tabela.
- **Migration antiga que contradiz o snapshot central?** `supabase/db/current/01_schema_full.sql` está desatualizado (snapshot de 2026-07-07) e não reflete `orcamentos.numero_venda`, `perfil`, `natureza_operacao`, nem o enum real de `pagamento_forma` (que já devia ter sido reextraído há tempo, conforme o próprio `orcamentos.md` já registra como pendência crônica). Recomendo reextrair `supabase/db/current/` antes ou junto da implementação desta SPEC, para não implementar em cima de suposições.
- **Exige atualizar `AI_DB_CONTEXT.md`?** Sim — do sistema de Orçamentos (novo enum, novo(s) campo(s) de parcela, correção da seção SPEC-019 desatualizada) e, num grau menor, do sistema Financeiro (nova FK de rastreio da permuta).
- **Padrão de acesso a dados já usado pelo sistema**: Orçamentos usa `useBudgetStore.ts` (Zustand store) + chamadas diretas `supabase.rpc(...)`/`supabase.from(...)` dentro de componentes de página (`BudgetFormPage.tsx`) — não há camada de `services/` separada para esse fluxo (diferente de outros sistemas do ecossistema). Esta SPEC deve seguir o mesmo padrão, sem introduzir uma camada nova.

## Realizado

_(nada implementado ainda — SPEC recém-criada)_

## Pendências

- [ ] Decidir a semântica exata da forma de pagamento "Carteira": ainda cria `projeto_parcelas` (só sem boleto) para controle de saldo em aberto, ou fica inteiramente fora do sistema de parcelas/boletos?
- [ ] Escolher Opção A (array paralelo `valores_parcelas_customizados`) ou Opção B (`plano_parcelas jsonb` unificado) para o schema de parcelas customizadas.
- [ ] Decidir `plano_de_contas`/`categorias_financeiras` para o lançamento automático de Contas a Pagar da contrapartida de permuta.
- [ ] Confirmar ao vivo (Skip publicado) se a regra "pagamento/total não reinicia aprovação do cliente" está mesmo assim hoje em produção — a investigação de código aponta que sim (SPEC-135), mas o teste do usuário na reunião não fechou essa confirmação de forma inequívoca.
- [ ] Confirmar se o bug de "cliente sem cadastro trava criar projeto" também existe em alguma tela do CRM além de `ProjectNew.tsx` (que já parece resolvido) — usuário precisa apontar a tela exata, se for outra.
- [ ] `supabase/db/current/` está desatualizado (snapshot de 2026-07-07) — recomendo reextração antes de implementar esta SPEC, para confirmar nomes/enums exatos no banco real (não só no `AI_DB_CONTEXT.md`/código local).
