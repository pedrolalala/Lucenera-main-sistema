# SPEC-078: Correções no módulo de Novo Orçamento (4 bugs)

**Data:** 2026-08-12
**Sistema:** Orçamentos (`gestao-financeira-clone-544cb`, Skip projectId `32554`) + 1 arquivo no Cadastro (`cadastro-lucenera-b86fe`)
**Status:** Concluído — os 4 bugs estão publicados em produção (Skip 32554), confirmado em 2026-09-16 comparando `skip_file_read` de `ProjectCreateModal.tsx`/`ProjetoFormDialog.tsx`/`use-options.ts`/`BudgetFormPage.tsx`/`generate-report/index.ts` contra o checkout local: Bug 1 (`"Residencial"` nos 2 sistemas + 2 linhas no banco), Bug 2 (`setClientes` otimista), Bug 3 (bloco `empresaSelecionadaPerfil`), Bug 4 (`valorAposSinal`/linha "Sinal:" no PDF) — todos presentes. Commit local nunca tinha sido feito apesar de já publicado: comitado e pushado em `3f7a16d` (gestao-financeira-clone) e já existia como ancestral em `db7f99a`→origin (cadastro-lucenera-b86fe).

## Contexto

Tarefa formal do usuário listando 4 bugs no formulário de "Novo Orçamento", cada um com passos de investigação obrigatórios antes de corrigir. Investigação feita por leitura de código (frontend, edge functions) e consultas diretas ao Supabase real (`psql`), já que o MCP do Skip está desconectado nesta sessão — não foi possível confirmar se o checkout local de cada arquivo bate com o que está publicado no Skip; isso precisa ser reverificado (via `skip_file_read`) antes de qualquer `skip_file_write`, assim que o MCP reconectar.

---

## Bug 1 — Typo "Residential"

### Investigação

Busca por "residential" (case-insensitive) em todos os 10 sistemas encontrou 2 arquivos de código-fonte real com essa string como *valor* de um campo "Tipo de Projeto/Área" (os demais hits são `types.ts` gerados ou textos não relacionados):

- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/ProjectCreateModal.tsx` — modal "Criar Novo Projeto" acessível pelo "+" dentro de Novo Orçamento. Aqui o `value` e o `label` exibido ao usuário são o MESMO texto `'Residential'` (sem tradução) — o usuário literalmente vê "Residential" em inglês no dropdown.
- `04-Sistemas/cadastro-lucenera-b86fe/src/components/projetos/ProjetoFormDialog.tsx` — tela de projeto do sistema Cadastro. Aqui o `label` exibido já é `"Residencial"` (correto, em português) mas o `value`/enum interno continua `'Residential'` (inglês) — bug invisível ao usuário nesta tela, mas presente no dado gravado.

O valor é armazenado dentro da coluna JSONB `projetos.area_do_projeto` (`{"tipo": "Residential"}`), não é uma coluna dedicada nem tem CHECK constraint no banco — é só uma string livre dentro do JSON.

Consulta ao banco real: `SELECT area_do_projeto->>'tipo', count(*) FROM projetos WHERE area_do_projeto IS NOT NULL GROUP BY 1` → **1 única linha** com `"Residential"`.

Nenhuma comparação de negócio (`if (tipo === 'residential')`) foi encontrada usando esse valor — é só exibido/armazenado, não branching de lógica.

### Correção

- `ProjectCreateModal.tsx`: trocar `'Residential'` por `'Residencial'` no array de opções (linha ~213) e no schema Zod (linha ~66).
- `ProjetoFormDialog.tsx`: trocar o `value` do enum Zod (linha 45) e os 2 defaults (`'Residential'`, linhas 109 e 123) e o `<SelectItem value="Residential">` (linha 419) para `'Residencial'` — o label visível já está certo, só o value interno muda.
- Migration (`supabase/db/migrations/`) para atualizar a única linha existente: `UPDATE projetos SET area_do_projeto = jsonb_set(area_do_projeto, '{tipo}', '"Residencial"') WHERE area_do_projeto->>'tipo' = 'Residential';`

### Critério de aceitação

Zero ocorrências de `'Residential'` (valor) no código-fonte dos 2 sistemas e no banco.

---

## Bug 2 — Cliente novo inline não linkado / não aparece na busca

### Investigação

Fluxo atual (`ClientCreateModal.tsx` + `BudgetFormPage.tsx`):

1. `ClientCreateModal.onSubmit` insere em `contatos` com `tipo: 'cliente'` (default correto) e `.select().single()` retornando a linha completa com `id`.
2. RLS de `contatos`: **INSERT** tem 2 policies permissivas (`contatos_insert` por role, `spec069_contatos_insert` por `hub_pode_executar`) — OR entre elas, insert não deveria estar bloqueado silenciosamente. **SELECT** tem 4 policies, todas `USING (true)` para `authenticated` — sem nenhum filtro que excluiria um cliente recém-criado.
3. `BudgetFormPage.tsx` (`onSuccess` do `ClientCreateModal`): `await fetchClientes()` (refetch completo de `contatos` tipo='cliente') **seguido de** `form.setValue('cliente_id', newClient.id, {shouldValidate:true})`.
4. Não há nenhuma lib de cache HTTP (`react-query`/`swr`) no projeto — todo acesso é direto via `supabase-js`, então "invalidação de cache" não se aplica aqui.
5. Consulta ao banco: 0 orçamentos com `cliente_id IS NULL` — ou seja, nenhum orçamento salvo ficou "sem cliente" (a validação `min(1)` do Zod bloqueia o submit se o campo realmente ficasse vazio).

**Não encontrei uma causa determinística via leitura estática** — o fluxo está estruturalmente correto no meu checkout local. Duas explicações prováveis, que não consigo distinguir sem testar ao vivo no navegador (instabilidade de automação de browser já documentada neste projeto) ou sem acesso ao Skip (desconectado agora) pra comparar com o que está realmente publicado:
- Uma corrida entre o `await fetchClientes()` (round-trip de rede) e o momento em que o `SearchableSelect` já fechou o popover/capturou as opções, fazendo o combobox não refletir o cliente novo imediatamente mesmo com o `field.value` já correto por baixo.
- O checkout local não bate com o que está publicado no Skip (padrão já visto várias vezes nesta sessão) — não posso confirmar nem descartar isso agora.

### Correção (defensiva, resolve a causa mais provável independente de qual das duas acima é a real)

Em vez de depender só do round-trip de `fetchClientes()`, injeta o cliente recém-criado na lista local **de forma síncrona/otimista**, eliminando qualquer corrida:

- `src/hooks/use-options.ts`: expor `setClientes` no retorno do hook.
- `BudgetFormPage.tsx` (`onSuccess` do `ClientCreateModal`): antes/junto do `fetchClientes()`, chamar `setClientes((prev) => [newClient, ...prev.filter((c) => c.id !== newClient.id)])` e só então `form.setValue(...)`. O `fetchClientes()` continua sendo chamado em paralelo pra reconciliar com o servidor (pega `codigo_legado` real etc.), mas a UI não depende mais dele pra mostrar o cliente imediatamente.

### Critério de aceitação

Cliente novo aparece imediatamente no combobox (sem precisar fechar/reabrir) e fica vinculado (`cliente_id`) ao salvar o orçamento.

### Risco residual

Se a causa real for divergência local↔Skip, esta correção não resolve nada de fato — por isso, ao reconectar o MCP, o primeiro passo antes de publicar é `skip_file_read` em `ClientCreateModal.tsx` e `BudgetFormPage.tsx` pra comparar com o local.

---

## Bug 3 — Perfil da empresa deve aparecer no topo

### Investigação

Busquei por um componente de "perfil da empresa" (nome/logo/endereço/contato) condicionado à existência de itens, em: tela de Novo Orçamento, PDF (`generate-report/index.ts`), tela pública de aprovação do cliente (`ClientApproval.tsx`) e o header genérico da aplicação (`Header.tsx`). Achados:

- **O PDF (`generate-report/index.ts`, linhas 209-303) já desenha o cabeçalho da empresa (logo, nome, razão social, endereço, telefone) de forma totalmente incondicional, sempre no topo da primeira página** — não depende de haver itens. Não há bug aqui.
- **Não existe, na tela de edição, nenhum componente que mostre nome/logo/endereço/contato da empresa** — nem condicionado a itens, nem incondicional. O único candidato próximo é o campo **"Perfil"** dentro do card "Pagamento e Totais" (rótulo herdado da SPEC-064 — é só uma tag informativa "Ribeirão"/"São Paulo", sem relação com dados cadastrais da empresa), que hoje mostra apenas o placeholder "Não informado".

O usuário confirmou (ao colar o texto renderizado do card "Pagamento e Totais" e apontar "dentro de perfil") que é exatamente essa área vazia que deveria mostrar o perfil da empresa.

**Interpretação adotada** (não 100% confirmada por falta de mais detalhe/screenshot, mas é a leitura mais direta do pedido original + do apontamento do usuário): a tela nunca teve, de fato, um bloco de "Perfil da Empresa" — o campo "Perfil" (Ribeirão/SP) é um recurso separado e será mantido como está (é usado e documentado desde a SPEC-064). Este bug pede a **criação** de um bloco novo, sempre visível, mostrando nome/logo/endereço/contato da empresa selecionada no campo "Empresa" — não a correção de uma condição de exibição que eu não localizei no código.

### Correção

- Novo bloco/card no topo do formulário (seção "Informações Gerais", logo após o campo "Empresa"), renderizado sempre que uma empresa está selecionada — **sem depender de `watchItens`/`fields.length`**:
  - Nome (nome fantasia/nome), Razão Social, endereço (logradouro, número, bairro, cidade/UF, CEP), telefone fixo da Lucenera (mesmo texto hardcoded `(16) 3442 - 3545` já usado no PDF).
  - Logo: reusa o mesmo asset estático (`lucenera-vertical-527dd.png`) já usado no `Header.tsx` — `empresas` não tem coluna de logo por-empresa no banco.
- Nenhuma mudança no PDF (já está correto).

### Critério de aceitação

Perfil da empresa selecionada aparece no topo do formulário assim que a empresa é escolhida, mesmo com o orçamento ainda vazio (zero itens).

---

## Bug 4 — Ordem do cálculo de valor final

### Investigação (respostas às 4 perguntas obrigatórias)

**1. O desconto é fixo ou percentual? Sobre o que incide?**
Configurável por orçamento via `desconto_tipo` (`'percentual'` ou `'valor'`, escolhido pelo usuário no form). Hoje, quando percentual, incide sobre `valorSubtotal` **puro** (soma dos itens, sem descontar o sinal antes): `descontoValorReais = valorSubtotal * (desconto% / 100)`.

**2. O sinal é fixo ou percentual? Sobre o que incide?**
Sempre valor fixo em R$ (`valor_sinal`, campo numérico livre — não existe `sinal_tipo` no schema, nunca existiu percentual de sinal).

**3. Há arredondamento em etapas intermediárias?**
No cálculo do total em si (frontend), não. No backend, a RPC `aprovar_orcamento_financeiro` usa `round(v_valor_total / v_qtd_parcelas, 2)` só para dividir o valor entre parcelas (a última parcela absorve o resto pra fechar a soma exata) — isso não muda com esta correção.

**4. Orçamentos já salvos devem ser recalculados retroativamente?**
**Não é necessário.** Consulta ao banco real: de 27 orçamentos no total, **apenas 1 tem `valor_sinal > 0`** (ORC-0020, status "Aprovação Financeira", sinal R$ 5.000,00) — e esse único orçamento **ainda não foi processado pela aprovação financeira** (0 `projeto_itens`, 0 `projeto_parcelas` gerados). Ou seja, não existe nenhum dado histórico com parcelas já cobradas incorretamente. A mudança de fórmula vale para esse orçamento (ainda pendente) e para todos os futuros — sem necessidade de script de migração retroativa.

### Achado além do que o bug descrevia

O problema real não era "ordem trocada de duas subtrações" (isso não mudaria nada se ambos os termos fossem fixos) — é que **o sinal nunca era efetivamente deduzido em lugar nenhum que gera cobrança real**:

- Frontend: calculava um `saldoRestanteAposSinal` (= `valorTotal - valorSinal`) só como número exibido na tela — **não usado em mais nada**.
- `orcamentos.valor_total` (coluna salva no banco): sempre foi `subtotal - desconto + frete`, **sem nunca subtrair o sinal**.
- RPC `aprovar_orcamento_financeiro`: lê `orcamentos.valor_total` direto e divide entre as parcelas — como esse valor nunca tinha o sinal descontado, **as parcelas sempre cobravam o valor cheio, sinal ou não**.
- PDF (`generate-report/index.ts`): nunca exibe "Sinal" em lugar nenhum; e o "Desconto" mostrado é o número cru de `desconto_global` — se o orçamento usa desconto percentual, o PDF mostra esse número como se fosse R$ (ex.: desconto de "10%" aparece como "Desconto: R$ 10,00"), o que já é inconsistente com a fórmula usada na tela/RPC, independente deste bug.

Usuário confirmou (após ver este achado): sim, o sinal deve reduzir de fato o valor das parcelas geradas.

### Correção (decisão: mudar `valor_total` na origem, não duplicar lógica em cada consumidor)

A fórmula pedida — `subtotal - sinal - desconto` — passa a ser calculada **uma vez só**, no frontend, no momento de montar o `valor_total` que é salvo em `orcamentos.valor_total`. Como a RPC e o PDF já leem esse campo, nenhum dos dois precisa duplicar a fórmula:

- `BudgetFormPage.tsx`:
  ```
  valorAposSinal = max(0, subtotal - sinal)
  descontoValorReais = desconto_tipo === 'valor' ? min(max(desconto,0), valorAposSinal) : valorAposSinal * (min(desconto,100)/100)
  valorComDesconto = valorAposSinal - descontoValorReais
  valorTotal = valorComDesconto + (frete se com_frete)
  ```
  Isso muda o significado de `orcamentos.valor_total`: passa a já vir com o sinal descontado. O label "Saldo restante após o sinal" na tela deixa de fazer sentido como um segundo número (já é o próprio Valor Total) — removido, mantendo só "Valor Total" como o número final de verdade.
- **RPC `aprovar_orcamento_financeiro`: nenhuma mudança de código necessária** — já lê `valor_total` e divide entre parcelas; como o valor que chega até ela já vem correto, o resultado passa a ser certo automaticamente. Isso reduz o risco de mexer em lógica de banco sensível/já testada.
- PDF (`generate-report/index.ts`): adicionar uma linha "Sinal:" (usando `budget.valor_sinal`) antes de "Valor Total", pra transparência ao cliente (hoje o sinal simplesmente não aparece em lugar nenhum do documento). Corrigir também o "Desconto" exibido para respeitar `desconto_tipo` (mostrar o valor em R$ equivalente quando for percentual, não o número cru) — necessário pra manter PDF e tela consistentes, conforme pedido em "garanta que todos os pontos usem exatamente a mesma fórmula".

### Critério de aceitação

Valor exibido na tela, salvo no banco (`orcamentos.valor_total`, usado pela RPC pra gerar parcelas) e impresso no PDF são idênticos e seguem `subtotal - sinal - desconto (+ frete se com_frete)`.

### Migration de banco

Nenhuma migration de schema necessária para o Bug 4 (não há coluna nova). Não há necessidade de script de recálculo retroativo (ver pergunta 4 acima) — o único orçamento com sinal>0 ainda não foi processado, então a fórmula nova já vale pra ele na próxima vez que for salvo/aprovado.

---

## Arquivos a criar/modificar (resumo)

| Arquivo | Sistema | Bug(s) |
| --- | --- | --- |
| `src/components/ProjectCreateModal.tsx` | Orçamentos | 1 |
| `src/components/projetos/ProjetoFormDialog.tsx` | Cadastro | 1 |
| `supabase/db/migrations/20260812_101_fix_typo_residential/001_...sql` (novo) | central | 1 |
| `src/hooks/use-options.ts` | Orçamentos | 2 |
| `src/pages/BudgetFormPage.tsx` | Orçamentos | 2, 3, 4 |
| `supabase/functions/generate-report/index.ts` | Orçamentos | 4 |

Nenhuma migration de schema para os bugs 2, 3, 4 — só a migration de dado do Bug 1 (1 linha).

## Verificação planejada

1. `npx tsc --noEmit` + `npx oxlint` + `npm run build` nos 2 sistemas tocados, local, antes de qualquer publish.
2. Migration do Bug 1 aplicada no Supabase real com autorização explícita (1 UPDATE, 1 linha).
3. **Skip desconectado nesta sessão** — publicação (`skip_file_write`/`skip_project_apply_changes`/`skip_project_publish`) e o commit+push dos submodules ficam pendentes até a reconexão. Antes de publicar, reconferir via `skip_file_read` se os arquivos tocados batem com o publicado (checkout local pode estar desatualizado, padrão já visto nesta sessão).
4. Sem teste de UI ao vivo via browser — validação por build + leitura de código + consultas diretas ao banco.
