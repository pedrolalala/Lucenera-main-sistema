---
titulo: "SPEC-152 — Melhorias no fluxo de Orçamento (reunião Vinícius 16/09)"
status: implementado, aplicado no banco real e publicado (Skip 32554 v0.0.368) — aguardando testes manuais ao vivo
data_ultima_modificacao: 2026-09-17
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb)
  - CRM (lucenera-crm-3bd29) — apenas verificação/possível paridade
  - Financeiro / Administração Bancária (retorno-bancario-bradesco-5392a) — só no item de Permuta (contrapartida em Contas a Pagar)
---

# SPEC-152 — Melhorias no fluxo de Orçamento (reunião Vinícius 16/09)

> Origem: primeira metade da reunião "24. Lucenera (Vinicius) - 16.09.2026_novo sistema de vendas" (`02-Reunioes/.../Reunião 01`), antes de entrar no assunto de Vendas/Fiscal (coberto pela SPEC-153).

## Checklist de Ação

- [x] `ProjectCreateModal.tsx` (Orçamentos): permitir cadastrar um cliente novo sem fechar o fluxo de "Criar Projeto" — adicionar ação "Novo Cliente" no campo Cliente (reaproveitando `ClientCreateModal.tsx`, já existente desde a SPEC-061). **Implementado com o padrão real já usado no próprio `BudgetFormPage.tsx`** (botão "+" ao lado do `SearchableSelect`, não Popover+Command como no CRM) — mais consistente com o resto deste app, que não usa Command/Popover pra isso em nenhum outro lugar.
- [x] `ProjectCreateModal.tsx` (Orçamentos): campo "Responsável Obra" (`responsavel_obra_id`) passa a listar apenas contatos com `contato_tipos.tipo = 'engenheiro'`, em vez de todos os `contatos`. Campo "Arquiteto" (`arquiteto_id`) é mantido como está. Verificado CRM (`ProjectNew.tsx`/`ProjectDetail.tsx`) — já filtrava corretamente (via `contatos.tipo`, coluna singular), sem necessidade de mudança lá.
- [x] Adicionar `'carteira'` ao enum `public.pagamento_forma` (`ALTER TYPE ... ADD VALUE`) e ao seletor de forma de pagamento em `BudgetFormPage.tsx`. Comportamento na aprovação (`aprovar_orcamento_financeiro`): quando a forma de pagamento é `carteira`, gera `projeto_parcelas` normalmente, só **não gera boleto** (decisão do usuário, 2026-09-17). Migration redigida, **não aplicada**.
- [x] Adicionar `'permuta'` ao enum `public.pagamento_forma` — **correção pós dry-run (2026-09-17)**: o implementador suspeitou de "Skip drift" (baseado em `types.ts` local desatualizado), mas o dry-run confirmou direto no banco real que `'permuta'` **já existe** no enum de produção (a SPEC-107 foi aplicada corretamente; só o `types.ts` do checkout local nunca foi regenerado). Migration usa `ADD VALUE IF NOT EXISTS` de qualquer forma (idempotente, sem risco). **Achado novo do dry-run**: existe 1 orçamento real em rascunho (`ORC-0035`, R$4.201,73) já com `forma_pagamento='permuta'` — como ele não usa o `plano_parcelas` novo, ao chegar em "Aprovação Financeira" a função vai exigir um `permuta_fornecedor_id` que hoje não existe pra ele; precisa reabrir esse orçamento e preencher o fornecedor via o novo bloco "Plano de Parcelas" antes de aprovar, depois que isso for pra produção.
- [x] Corrigir bug: campo "Quantidade de Parcelas" (`BudgetFormPage.tsx`, `parcelas`) não permite apagar o valor anterior ao editar (fica "cravado"). Corrigido trocando `z.coerce.number()` puro por `z.preprocess(...)` (aceita string vazia em trânsito, normaliza só no submit/blur) + input não força mais parse a cada tecla.
- [x] Corrigir bug: ao editar campos do plano de pagamento, a tela não reflete a mudança até salvar. **Investigado**: não foi encontrado nenhum componente lendo de um snapshot antigo (`budget` carregado) em vez de `form.watch(...)` — a hipótese original da SPEC não bateu com o código real encontrado. O novo bloco "Plano de Parcelas" (itens abaixo) já nasce 100% orientado a `form.watch()`/efeito reativo, então esse sintoma não deveria mais se repetir de qualquer forma; falta confirmação do usuário ao vivo se o sintoma relatado na reunião ainda ocorre em algum outro ponto específico não coberto aqui.
- [x] Nova granularidade de parcelas: permitir valor **customizado por parcela**. **Decisão (2026-09-17): Opção B** — `orcamentos.plano_parcelas jsonb` (array de `{numero, dias_offset, valor, forma_pagamento, permuta_fornecedor_id}`), substituindo gradualmente `prazo_pagamento_dias` (mantida em paralelo, não removida). Migration redigida, **não aplicada**.
- [x] UI em `BudgetFormPage.tsx`: novo bloco "Plano de Parcelas" com valor/forma de pagamento/fornecedor de permuta editáveis por parcela (pré-preenchido com a divisão igual até o usuário editar manualmente), validando ao vivo (banner verde/vermelho) que a soma bate com `valor_total`; bloqueia submit (toast de erro) se não bater.
- [x] `aprovar_orcamento_financeiro`: reescrita para usar `orcamentos.plano_parcelas` (quando presente) em vez da divisão igual, nos dois ramos (venda e devolução) — com validação de segurança no próprio backend (soma exata, fornecedor de permuta válido). Assinatura mantida `(uuid)` — o parâmetro `p_valores_parcelas` da migration abandonada da SPEC-133 (`20260914_141`) nunca foi aplicado em produção e não foi usado.
- [x] Suporte a parcela paga por **permuta**: parcela nasce com `status = 'paga'`, sem boleto; a aprovação lança automaticamente uma obrigação de Contas a Pagar pro fornecedor. Decisões de implementação, confirmadas contra o schema real antes de nomear qualquer coisa nova (AGENTS.md):
  - Nova coluna `projeto_parcelas.permuta_fornecedor_id uuid REFERENCES contatos(id)` nullable — feito.
  - **Sem FK nova em `negociacoes`/`transacoes`** (a SPEC cogitou `negociacoes.orcamento_id_origem` só como exemplo) — em vez disso, reaproveitado o padrão manual já existente de "Cadastrar Duplicatas" (SPEC-073, `retorno-bancario-bradesco-5392a`): um `boletos` com `tipo_operacao = 'CP'` + `apropriacao_id`, rastreado por `boletos.orcamento_id` (já existente, é o link primário do financeiro — não precisa de coluna nova). `negociacoes`/`transacoes` é o universo legado de import do Connect (`cod_duplicata` obrigatório, sem equivalente natural aqui), não o lugar certo pra um lançamento novo gerado pelo sistema.
  - Categoria nova em `plano_de_contas`: `'PERMUTA/CONTRAPARTIDA'` (nível 3/Apropriação, `codigo_connect = 90000035`, `parent_id` = "Com Vendas", `tipo = 'despesa'`) — decisão do usuário (2026-09-17), seguindo o mesmo padrão da reconciliação de 11/08 (`20260811_096`).
- [x] PDF do orçamento (`supabase/functions/generate-report/index.ts`, `reportType === 'orcamento'`): parou de mostrar "condição de pagamento" como contagem de dias — agora desenha uma tabela de parcelas com número, data de vencimento absoluta (`data_inicio_pagamento` + `dias_offset`) e valor, reaproveitando `plano_parcelas` quando presente (senão cai na divisão igual, mesma lógica de `calcularResumoFinanceiro`, duplicada localmente porque a Edge Function roda isolada em Deno).
- [x] Atualizado `AI_DB_CONTEXT.md` de Orçamentos: a seção "SPEC-019" foi corrigida/anotada como superada pela SPEC-135 — o reset por campo de pagamento nunca foi o mecanismo real em produção, só o trigger em `orcamento_itens`. Documentadas todas as mudanças novas desta SPEC (enum, `plano_parcelas`, `permuta_fornecedor_id`) no mesmo arquivo e no `AI_DB_CONTEXT.md` de Administração Bancária (`retorno-bancario-bradesco-5392a`), além de `supabase/db/domains/orcamentos.md` e `financeiro.md`.

### Passos manuais do usuário

- [x] **(2026-09-17) Migrations aplicadas no Supabase real**, nesta ordem, com dry-run/`ROLLBACK` antes de cada `COMMIT` real: `001_enum_carteira_e_permuta.sql` (confirmado sozinho primeiro), `002_orcamentos_plano_parcelas.sql`, `003_projeto_parcelas_permuta_fornecedor.sql`, `004_plano_de_contas_permuta_contrapartida.sql`, `005_aprovar_orcamento_financeiro_plano_parcelas.sql`. Verificado pós-aplicação: coluna/categoria/função presentes; `aprovar_orcamento_financeiro` continua com 1 argumento.
  - **Correção de achado**: `'permuta'` já existia no enum real antes desta SPEC (SPEC-107 foi aplicada corretamente — a suspeita de "Skip drift" era só `types.ts` local desatualizado). Só `'carteira'` era novo de fato.
  - **Achado de dado real**: `ORC-0035` (rascunho, R$4.201,73) já tinha `forma_pagamento='permuta'` antes desta SPEC, sem fornecedor associado. Com a função nova, esse orçamento vai EXIGIR um `permuta_fornecedor_id` quando chegar em "Aprovação Financeira" — precisa reabrir e preencher o fornecedor no novo bloco "Plano de Parcelas" antes de aprovar (não é regressão, é o comportamento novo pedido pelo usuário pegando um dado pré-existente incompleto).
- [ ] Reextrair `src/lib/supabase/types.ts` (Orçamentos e Administração Bancária) e `supabase/db/current/` no repositório central — o snapshot central já estava desatualizado antes desta SPEC (2026-07-07).
- [x] **(2026-09-17) Publicado no Skip**: `gestao-financeira-clone-544cb` (projectId 32554), versão 0.0.368 (`1ed6376`), QA 100% verde (setup/análise estática/build/integrações/testes). Merge de 3 vias necessário em `BudgetFormPage.tsx` — o Skip já tinha o campo "Perfil" reposicionado pro topo (SPEC-146), mudança nunca sincronizada de volta pro git local; o merge preservou essa posição e adicionou o código da SPEC-152 por cima, sem regressão.
- [ ] Testar ao vivo (golden path) depois de aplicado: (1) criar orçamento com "Novo Cliente" dentro de "Criar Projeto"; (2) conferir que "Responsável Obra" só lista engenheiros; (3) criar parcela com forma "Carteira" e confirmar que não gera boleto; (4) criar parcela "Permuta" com fornecedor e confirmar que aprova sem boleto pro cliente e cria uma linha nova em Contas a Pagar (`retorno-bancario-bradesco-5392a`, `ConsultarDuplicatas.tsx`/`Boletos.tsx`, categoria "Permuta/Contrapartida"); (5) editar valor por parcela no "Plano de Parcelas" e confirmar que a soma trava o salvamento se não bater; (6) gerar o PDF do orçamento e conferir a tabela de parcelas.
- [ ] Confirmar, ao vivo no Skip publicado (não só no código local — risco conhecido de "Skip drift"), que a regra "pagamento/total não reinicia aprovação do cliente, só item reinicia" está de fato assim hoje.
- [ ] Homologar visualmente o novo PDF do orçamento com Vinícius (ele reagiu especificamente ao "14 dias de quando?" — validar que a tabela de parcelas resolve a confusão).
- [ ] Publicar no Skip (build local já passou `oxlint`/`vite build` sem erros novos — ver "Realizado").

## Objetivo

Consolidar as melhorias e correções pontuais no sistema de Orçamentos discutidas na primeira metade da reunião de 16/09 — antes de qualquer coisa relacionada a Vendas/Nota Fiscal (SPEC-153) — cobrindo: cadastro de cliente sem sair do fluxo de criar projeto, campo Responsável de Obra restrito a engenheiros, nova forma de pagamento "Carteira", correção de dois bugs de UI no plano de pagamento, parcelas com valor customizável (não só divisão igual), forma de pagamento "Permuta" com lançamento automático de contrapartida no Financeiro, e PDF do orçamento mostrando datas/valores reais de vencimento em vez de contagem de dias.

## Decisões aprovadas

- Manter os dois campos "Arquiteto" e "Responsável da Obra" no projeto — não eliminar nenhum dos dois. "Responsável da Obra" passa a ser conceitualmente um Engenheiro (lista filtrada), não mais qualquer contato.
- Campo "Código do Projeto" fica fora de escopo por decisão explícita do usuário — não implementar agora (mencionado na reunião só como bug de validação incidental durante um teste, não como pedido de mudança).
- "Sinal" continua sendo um conceito diferente de "parcela 1 customizada" — o sinal é abatido antes da divisão em parcelas e não muda de comportamento nesta SPEC; a novidade é permitir editar o valor de cada parcela gerada depois do sinal/desconto/frete já aplicados.
- Regra de negócio "não emitir nota fiscal nem boleto direto na aprovação do orçamento" pertence à SPEC-153, não a esta.
- A impressão do orçamento (PDF) deve sempre dizer "Orçamento", nunca "Venda" — investigação confirmou que o gerador atual (`generate-report`) já respeita isso; não é necessário mudar esse rótulo, só o formato de condição de pagamento.
- **(2026-09-17, decisão do usuário)** Forma de pagamento "Carteira": gera `projeto_parcelas` normalmente, só não gera `boletos` — aparece em relatórios de saldo em aberto/pendências.
- **(2026-09-17, decisão do usuário)** Contrapartida de Permuta: cria categoria nova no plano de contas do Financeiro, "Permuta/Contrapartida", usada em todo lançamento automático desse tipo.
- **(2026-09-17, decisão do usuário)** Parcelas customizadas: Opção B — `orcamentos.plano_parcelas jsonb` (array de `{numero, dias_offset, valor, forma_pagamento, permuta_fornecedor_id}`), substituindo gradualmente `prazo_pagamento_dias`.

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
- Adicionar `'carteira'` ao enum e à UI. **Decidido (2026-09-17)**: ainda cria `projeto_parcelas` normalmente, só não gera `boletos` — aparece em relatórios de saldo em aberto/pendências.

### 4. Bugs de UI no plano de pagamento

- Bug 1 (input "cravado"): campo `parcelas` usa `z.coerce.number()` — ao apagar o conteúdo do input, o valor não some porque a coerção reverte para o número anterior antes do usuário conseguir digitar o novo. Corrigir permitindo string vazia como estado transitório, coagindo só no blur/submit.
- Bug 2 (tela não reflete até salvar): reportado ao vivo na reunião ao editar quantidade de parcelas — precisa investigar se `BudgetFormPage.tsx` está re-renderizando a partir do estado do form (`react-hook-form`) corretamente ou se há um componente derivado (ex. pré-visualização de parcelas) lendo de um estado desatualizado (`budget` original em vez de `form.watch(...)`).

### 5. Parcelas com valor customizado

- **Decidido (2026-09-17): Opção B** — `orcamentos.plano_parcelas jsonb`, array de `{numero, dias_offset, valor, forma_pagamento, permuta_fornecedor_id}`, substituindo gradualmente `prazo_pagamento_dias`. Evita um terceiro array paralelo quando entra a Permuta por parcela.
- Regra dura, conforme pedido do usuário: soma das parcelas deve ser **exatamente** igual ao valor a pagar (`valor_total`, já líquido de sinal/desconto/frete) — bloquear salvamento/aprovação se não bater, nunca arredondar silenciosamente sobre o usuário.

### 6. Permuta com contrapartida automática

- Caso de uso real, não hipotético (ex. "Rod Parrilha", "Florença" citados na reunião).
- Fluxo: parcela marcada `forma_pagamento = 'permuta'` + `permuta_fornecedor_id` (fornecedor real, `contatos.tipo = 'fornecedor'`) → na aprovação financeira, a parcela nasce com `status = 'paga'`/sem boleto, e o sistema cria uma obrigação de Contas a Pagar espelhada no Financeiro (mesmo valor, fornecedor da permuta) — cruza para o domínio Financeiro (`transacoes`/`negociacoes`), que precisa de uma FK nova de rastreio (`orcamento_id_origem`) para não ficar uma obrigação financeira "solta" sem origem.
- Categoria/plano de contas da despesa de contrapartida: **decidido (2026-09-17)** — categoria nova "Permuta/Contrapartida" no plano de contas do Financeiro.

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

### 2026-09-17 — Implementação (agente implementador)

- **Frontend (`gestao-financeira-clone-544cb`)**:
  - `ProjectCreateModal.tsx`: ação "Novo Cliente" (modal empilhado) + filtro de engenheiros em "Responsável Obra" (`contato_tipos`).
  - `BudgetFormPage.tsx`: fix do bug de "Quantidade de Parcelas" cravada (`z.preprocess`); campo de parcelas liberado pra qualquer forma de pagamento exceto pix/dinheiro; novo bloco "Plano de Parcelas" (valor/forma de pagamento/fornecedor de permuta por parcela, com sincronismo reativo via `form.watch` e validação de soma ao vivo); enum `pagamento_forma` com `'carteira'` na UI.
  - `budget-financial-summary.ts`: `FORMA_PAGAMENTO_LABELS.carteira`; `calcularResumoFinanceiro`/`ParcelaPrevista` passam a usar `plano_parcelas` quando presente.
  - `useBudgetStore.ts`: tipo `Budget.plano_parcelas` adicionado (query `select('*')` já traz a coluna automaticamente quando existir no banco).
  - `supabase/functions/generate-report/index.ts`: tabela de parcelas (número, vencimento absoluto, valor) no lugar da contagem de dias — `calcularParcelasPdf`, duplicada localmente (Edge Function isolada, Deno).
  - Verificação: `oxlint src` → 0 erros (15 warnings pré-existentes, nenhum novo); `vite build` → sucesso; `tsc --noEmit` **não é utilizável neste repositório** — `tsconfig.app.json` tem `ignoreDeprecations: "6.0"`, inválido pra qualquer versão do TypeScript instalada (pré-existente, não introduzido por esta SPEC); rodando com essa linha removida (só para diagnóstico, sem commitar a mudança), o número de erros é **idêntico antes e depois desta SPEC (184)** — confirma que nenhum erro novo foi introduzido (o repo já tem uma incompatibilidade sistêmica de versão entre `@hookform/resolvers`/`zod` que afeta virtualmente todo `FormField` do arquivo, preexistente).
- **Banco** (`supabase/db/migrations/20260917_152_melhorias_orcamento/`, 5 arquivos — **redigidos, não aplicados no Supabase real**):
  - `001_enum_carteira_e_permuta.sql`, `002_orcamentos_plano_parcelas.sql`, `003_projeto_parcelas_permuta_fornecedor.sql`, `004_plano_de_contas_permuta_contrapartida.sql`, `005_aprovar_orcamento_financeiro_plano_parcelas.sql`.
- **Docs**: `AI_DB_CONTEXT.md` de Orçamentos (seção SPEC-019 corrigida + seção SPEC-152 nova) e de Administração Bancária; `supabase/db/domains/orcamentos.md` e `financeiro.md`; `CHANGELOG.md`.
- **Achado durante a implementação, corrigido no dry-run**: o implementador suspeitou que `'permuta'` não estava no enum real (baseado em `src/lib/supabase/types.ts` local desatualizado). **Confirmado direto no banco no dry-run (2026-09-17): `'permuta'` já existia** — a SPEC-107 foi aplicada corretamente, só o `types.ts` do checkout local nunca foi regenerado. Não é uma regressão nem precisa de investigação adicional.
- **Decisão de implementação, documentada por já ter confirmado contra o schema real (AGENTS.md)**: a contrapartida de permuta **não** criou a FK `negociacoes.orcamento_id_origem` que a SPEC cogitou como exemplo — em vez disso reaproveita o padrão manual já existente de `boletos.tipo_operacao = 'CP'` (SPEC-073), rastreado por `boletos.orcamento_id` (já existente). Ver Checklist para o raciocínio completo.
- **Não fechado nesta implementação**: "Bug 2" (tela não reflete edição do plano de pagamento) — investigado, não foi encontrado o componente com o bug hipotetizado pela SPEC; o novo "Plano de Parcelas" já nasce reativo, mas não há confirmação de que o sintoma original relatado na reunião estava exatamente aí.

## Pendências

- [x] ~~Aplicar as migrations no Supabase real~~ — feito 2026-09-17, verificado.
- [x] ~~Rodar o agente `revisor` antes de qualquer commit~~ — feito, sem achado crítico.
- [x] ~~Publicar no Skip~~ — feito 2026-09-17, v0.0.368 (`1ed6376`), QA 100% verde.
- [ ] Testar ao vivo (golden path completo) na produção publicada — nada disto foi testado por um humano ainda.
- [ ] Confirmar ao vivo (Skip publicado) se a regra "pagamento/total não reinicia aprovação do cliente" está mesmo assim hoje em produção — a investigação de código aponta que sim (SPEC-135), mas o teste do usuário na reunião não fechou essa confirmação de forma inequívoca.
- [ ] Confirmar se o bug de "cliente sem cadastro trava criar projeto" também existe em alguma tela do CRM além de `ProjectNew.tsx` (que já parece resolvido) — usuário precisa apontar a tela exata, se for outra.
- [ ] Homologar visualmente o novo PDF do orçamento com Vinícius.
- [ ] Reabrir e completar o orçamento `ORC-0035` (rascunho, R$4.201,73, `forma_pagamento='permuta'` sem fornecedor) antes de aprová-lo — achado do dry-run, ver "Realizado".
- [ ] Achado de git/Skip drift (não é desta SPEC): a SPEC-146 (campo "Perfil" no topo do orçamento) estava publicada no Skip mas nunca sincronizada de volta pro `BudgetFormPage.tsx` do git local — só descoberto ao publicar esta SPEC (precisou merge de 3 vias pra não regredir). Recomenda-se ressincronizar o git local com o Skip publicado numa sessão futura, pra achar outros gaps parecidos.
