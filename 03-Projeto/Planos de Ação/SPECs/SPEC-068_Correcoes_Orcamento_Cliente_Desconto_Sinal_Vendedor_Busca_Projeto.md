---
titulo: "SPEC-068 — Correções em Orçamento: Nome do Cliente, Desconto/Sinal, Vendedor Automático e Busca de Projeto"
status: pendente
data_ultima_modificacao: 2026-08-06
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb (1))
  - CRM (lucenera-crm-3bd29 (1))
  - Supabase (banco central)
---

# SPEC-068 — Correções em Orçamento: Nome do Cliente, Desconto/Sinal, Vendedor Automático e Busca de Projeto

> Origem: 4 pontos trazidos pela Mariane (equipe de Projetos) sobre a tela de orçamento (`gestao-financeira-clone-544cb (1)`). Sem ata formal em `02-Reunioes/` — registrado a partir do relato repassado ao orquestrador em 2026-08-06. Esta SPEC referencia e complementa a SPEC-061 (`SPEC-061_Novo_Orcamento_Autopreenchimento_Projeto_e_Cadastro_Cliente.md`), que já mexeu nos mesmos arquivos (`BudgetFormPage.tsx`, `ClientCreateModal.tsx`) em 2026-08-05.

## Checklist de Ação

**2.1 — Nome do cliente exibindo código do projeto**
- [x] Corrigido o binding para exibir `razao_social + ' - ' + nome` (fantasia) quando ambos preenchidos e distintos; exibir apenas `nome`/`razao_social` quando não houver fantasia — aplicado no painel de detalhes do projeto e no combobox de cliente do `BudgetFormPage.tsx`.
- [ ] **Não fechado**: investigação direta no Skip publicado (`ClientCreateModal.tsx`, `ClientFormFields.tsx` do CRM) não encontrou nenhum ponto onde `projeto.codigo` é atribuído ao campo de nome do cliente. A correção acima resolve a formatação (nome completo + fantasia), mas a causa raiz literal relatada ("mostrando código do projeto") não foi reproduzida nem confirmada — pode já ter sido corrigida por SPEC anterior, ou pode reaparecer; reabrir se o sintoma persistir.

**2.2 — Desconto %/R$ + campo Sinal**
- [x] Migration `20260806_083_spec068_desconto_tipo_sinal_orcamento` aplicada no Supabase real: `orcamentos.desconto_tipo` (check `percentual`|`valor`), `orcamentos.valor_sinal` (numeric).
- [x] `BudgetFormPage.tsx`: seletor de tipo de desconto (% / R$ fechado) com cálculo automático nos dois sentidos.
- [x] `BudgetFormPage.tsx`: campo "Sinal (R$)".
- [x] Documento do cliente (`ClientApproval.tsx`, via RPC `buscar_orcamento_para_aprovacao` atualizada): exibe valor total, desconto (R$ e %), sinal e saldo restante após o sinal. (`FiscalSummaryDialog.tsx` não foi tocado — é o resumo fiscal interno/NF, não o documento do cliente; fora de escopo.)
- [x] Decisão do usuário: Sinal é puramente informativo no documento — não gera parcela financeira nem afeta aprovação.

**2.3 — Vendedor automático a partir do responsável da obra**
- [x] `BudgetFormPage.tsx`: trocado `projeto.vendedor_id || projeto.responsavel_id` (coluna morta) por `projeto.responsavel_obra_id || projeto.responsavel_id`.
- [x] Autopreenchimento agora só roda quando `!isEditing` (criação) — nunca sobrescreve Vendedor alterado manualmente em edição.

**2.4 — Projeto 24.200 não aparece na busca**
- [x] Decisão do usuário: o dado estava errado. `UPDATE projetos SET arquivado = false WHERE id = '660853b9-21df-46c1-901c-0c45c7a13d2f'` aplicado no Supabase real.
- [ ] Não investigado no CRM publicado (Skip `24580`) como a Mariane via o projeto como "ativo" apesar do dado — não bloqueou a correção (decisão do usuário já resolveu o caso concreto), mas fica como possível sintoma recorrente se outros projetos tiverem o mesmo problema de dado.

**Transversal**
- [ ] Atualizar `supabase/db/domains/orcamentos.md` (itens 2.2 e 2.3) — pendente.
- [ ] Atualizar `AI_DB_CONTEXT.md` do sistema Orçamentos — pendente.

### Passos manuais do usuário

- [x] Decisão do item 2.4: dado errado — resolvido.
- [x] Decisão do item 2.2 (Sinal): informativo, sem afetar financeiro — resolvido.
- [ ] Homologação manual no navegador dos 4 itens (nenhum dos sistemas tem suíte automatizada real) — ainda não feita nesta sessão.
- [ ] Auditar se existem outros projetos com `arquivado=true` por engano, na mesma situação do 24.200 (359 projetos arquivados no total, não auditados individualmente).

## Objetivo

Corrigir 4 gaps pontuais na tela de orçamento (Orçamentos) trazidos pela equipe de Projetos:

1. Campo de nome do cliente exibindo o código do projeto em vez do nome real.
2. Desconto sem suporte a valor fechado (R$) e ausência de campo "Sinal" no orçamento e no documento final.
3. Campo Vendedor não vindo do responsável da obra do projeto (vem de `responsavel_id`, não `responsavel_obra_id`).
4. Bug: projeto 24.200, considerado ativo pela equipe, não aparece na busca de projetos ao criar orçamento.

## Decisões aprovadas

- Sinal é sempre valor fixo em R$ (não percentual).
- Desconto suporta os dois formatos (percentual e R$ fechado), com cálculo automático entre eles.
- Campo Vendedor continua editável — autopreenchido do responsável da obra apenas como ponto de partida, nunca travado; autopreenchimento só ocorre na criação, nunca sobrescreve alteração manual posterior.
- (Herdadas da SPEC-061, não reabrir): e-mail obrigatório no cadastro de cliente; Vendedor da tela principal já vem de `funcionarios`; `contatos.vendedor_id`/`vendedor_padrao_id` apontam para `funcionarios(id)`.

## Definição da SPEC

### Análise obrigatória de ecossistema

- **Depende de**: `projetos` (`responsavel_obra_id`, `responsavel_id`, `arquivado`, `status`, `codigo`, `cliente_id`), `orcamentos` (`desconto_global` existente + 2 colunas novas propostas), `contatos` (`nome`, `razao_social`). Não depende de `boletos`, `projeto_itens` diretamente — exceto se a Pendência do item 2.2 (sinal virar parcela) for aprovada no futuro, o que passaria a envolver `projeto_parcelas`.
- **Afeta**: Orçamentos (principal, os 4 itens) e CRM (item 2.4, investigação de como "projeto ativo" é definido; possivelmente item 2.1 se o binding problemático estiver do lado do CRM).
- **Dado duplicado a observar**: nenhum identificado nestes 4 itens. `contatos.nome` (fantasia/comercial) e `contatos.razao_social` (jurídico) já são campos distintos por desenho, não duplicados — o item 2.1 apenas os combina na exibição, não cria coluna nova.
- **Migration antiga contradizendo snapshot central**: não identificada para estes itens.
- **`AI_DB_CONTEXT.md`**: precisa ser atualizado no sistema Orçamentos após a migration do item 2.2.
- **Padrão de acesso a dados já usado pelo sistema (não propor um novo)**: `BudgetFormPage.tsx` acessa o Supabase diretamente via `supabase.from(...)` (sem camada `services/` dedicada) e persiste via a store Zustand `useBudgetStore.ts` (`addBudget`/`updateBudget`). Toda mudança desta SPEC deve seguir esse padrão já estabelecido.

### 2.1 — Nome Completo / Fantasia exibindo código do projeto

**Estado atual (achado):** o label "Nome Completo / Fantasia" existe só em `ClientCreateModal.tsx` (`gestao-financeira-clone-544cb (1)`), por volta da linha 463, dentro do form de **criação** de cliente (usado tanto pelo botão "+" direto na tela de orçamento quanto pelo fluxo de import de XML quando o cliente do XML não é encontrado — `handleXmlImportNeedsClient`). Nesse arquivo local, `defaultValues.nome` é sempre `''` e não existe nenhuma prop de inicialização (`clientToEdit`/`initialData`) sendo passada para o modal a partir de `BudgetFormPage.tsx` — não há edição de cliente existente por este componente. Uma busca por `codigo`/`projeto.codigo`/`selectedProject` dentro de `ClientCreateModal.tsx` e nos pontos de `BudgetFormPage.tsx` que abrem esse modal não encontrou nenhum caminho onde `projeto.codigo` é atribuído a `nome`/`nome_empresa`/`razao_social`.

**Causa raiz:** não confirmada localmente. Duas explicações possíveis: (a) o bug existe apenas na versão publicada no Skip (projectId `32554`), que pode estar à frente ou divergente deste submodule local (WIP de import de XML tocando os mesmos arquivos); (b) o bug está em uma tela de edição de cliente que não existe/não foi encontrada localmente. Não inventar a causa — o implementador deve confirmar via `skip_file_read` antes de codar.

**Mudança proposta:**
- Localizar (via Skip) o binding real que alimenta o campo com `projeto.codigo`.
- Corrigir a exibição para: `razao_social + ' - ' + nome` quando `nome` (fantasia) estiver preenchido e for diferente da razão social; apenas `nome`/`razao_social` sozinho quando não houver fantasia (ex.: CPF, que tipicamente não tem `nome_empresa` preenchido). Não criar coluna nova — `contatos.nome` (comentário no schema: "nome fantasia/comercial") e `contatos.razao_social` já cobrem o caso.

**Impacto no banco:** nenhum — reutiliza colunas existentes de `contatos`.

**Critério de aceite:** abrir/selecionar um cliente vinculado a um orçamento mostra o nome do cliente (nunca um código de projeto); cliente PJ com fantasia preenchida mostra "Razão Social - Fantasia"; cliente PF/sem fantasia mostra apenas o nome, sem hífen ou sufixo vazio.

### 2.2 — Desconto (% ou R$) + campo Sinal

**Estado atual (achado):** `orcamentos.desconto_global numeric DEFAULT 0` existe no banco, mas hoje é tratado **exclusivamente como percentual** — confirmado em `FiscalSummaryDialog.tsx` (`valorLiquido = subtotalItens * (1 - budget.desconto_global / 100)`) e no payload de `onSubmit` de `BudgetFormPage.tsx` (`desconto_global: values.desconto_global ?? 0`, sem tipo). Não existe nenhum campo de "sinal" em `orcamentos` nem em nenhum componente do submodule (`sinal`/`Sinal` não aparece em nenhum formulário ou store relacionado a orçamento). Confirma que este item é feature nova, não bugfix.

**Mudança proposta — banco (rascunho de migration, nomes de coluna a confirmar contra o padrão do domínio antes de aplicar):**

```sql
-- supabase/db/migrations/YYYYMMDD_NNN_spec068_desconto_tipo_sinal_orcamento/001_....sql
ALTER TABLE public.orcamentos
  ADD COLUMN desconto_tipo text DEFAULT 'percentual'
    CHECK (desconto_tipo IN ('percentual', 'valor')),
  ADD COLUMN valor_sinal numeric(12,2) DEFAULT 0
    CHECK (valor_sinal >= 0);
```

- `desconto_global` continua guardando o número digitado (10 para "10%" OU 150 para "R$150,00"); `desconto_tipo` define como interpretá-lo. Sem trigger — cálculo é feito no frontend, seguindo a diretriz de não usar trigger para regra de negócio de orçamento.
- Cálculo bidirecional (frontend, `BudgetFormPage.tsx`):
  - se `desconto_tipo = 'percentual'`: desconto em R$ = `subtotal * desconto_global / 100`.
  - se `desconto_tipo = 'valor'`: percentual equivalente (só exibido, não persistido) = `desconto_global / subtotal * 100`.
  - saldo restante = `(subtotal - desconto_em_reais) - valor_sinal`.
- UI: seletor de tipo (%/R$) ao lado do campo de desconto global; novo campo "Sinal (R$)".
- Documento/resumo do orçamento (`FiscalSummaryDialog.tsx` e qualquer outra tela de resumo enviada ao cliente, ex. `ClientApprovalTab.tsx`) passa a exibir: valor total, desconto (valor e/ou %), sinal, saldo restante após o sinal.
- Fora de escopo: desconto por item (`orcamento_itens.desconto`) não muda de formato — só o desconto global do orçamento.

**Impacto no banco:** migration nova em `orcamentos` (2 colunas, sem trigger, sem afetar `aprovar_orcamento_financeiro`).

**Pendência de negócio explícita (não decidir sozinho):** o "Sinal" deve gerar automaticamente a primeira parcela em `projeto_parcelas` na aprovação financeira, ou é puramente informativo no documento comercial, sem tocar no fluxo financeiro? Ver Pendências.

**Critério de aceite:**
- Subtotal R$1.000, tipo percentual, 10% → desconto R$100, valor líquido R$900, refletido no documento.
- Mesmo subtotal, tipo valor, R$150 → 15% equivalente exibido, valor líquido R$850.
- Sinal R$300 sobre valor líquido R$850 → saldo restante R$550 exibido no documento.
- `SELECT desconto_tipo, valor_sinal FROM orcamentos WHERE id = ...` confirma persistência após salvar.

### 2.3 — Vendedor automático a partir do responsável da obra

**Estado atual (achado):** em `BudgetFormPage.tsx` (~linha 576), o autopreenchimento (já implementado pela SPEC-061) usa:

```ts
const targetVendedorId = projeto.vendedor_id || projeto.responsavel_id
```

Achado adicional confirmado no schema real (`supabase/db/current/01_schema_full.sql`, `CREATE TABLE public.projetos`) e em `supabase/db/migrations/`: **a tabela `projetos` não tem coluna `vendedor_id`** — nenhuma migration a cria. Ou seja, `projeto.vendedor_id` é sempre `undefined` em runtime, e o autopreenchimento hoje sempre cai em `projeto.responsavel_id` — nunca em `projeto.responsavel_obra_id`, que é a coluna que corresponde literalmente ao "responsável da obra" pedido agora. O projeto 24.200 (achado do item 2.4) tem `responsavel_obra_id` E `responsavel_id` nulos — qualquer fallback precisa continuar funcionando (campo fica vazio) nesse caso.

**Mudança proposta:**
```ts
const targetVendedorId = projeto.responsavel_obra_id || projeto.responsavel_id
```
Remove a referência morta a `projeto.vendedor_id`. Prioriza `responsavel_obra_id` (pedido literal), com fallback para `responsavel_id` quando a obra não tiver responsável definido. Confirmar/garantir que esse bloco só roda na criação de um orçamento novo (`!isEditing`), nunca sobrescrevendo uma alteração manual do Vendedor em um orçamento já salvo — o trecho lido não deixa claro esse guard; se não existir, adicionar.

**Impacto no banco:** nenhum — usa coluna já existente (`projetos.responsavel_obra_id`).

**Critério de aceite:** criar orçamento novo a partir de projeto com `responsavel_obra_id` preenchido pré-seleciona esse funcionário como Vendedor; projeto com `responsavel_obra_id` nulo mas `responsavel_id` preenchido usa o fallback; projeto com os dois nulos deixa o campo vazio para seleção manual; alterar o Vendedor manualmente e reabrir/editar o orçamento não reverte a escolha.

### 2.4 — Bug: projeto 24.200 não aparece na busca de projetos

**Estado atual (achado confirmado no Supabase real):** o projeto código `24.200` (id `660853b9-21df-46c1-901c-0c45c7a13d2f`, "MARINA E MARCELO") tem `arquivado = true`, `status = 'Obra Finalizada'`, `cliente_id` e `arquiteto_id` preenchidos, mas `responsavel_id`, `responsavel_obra_id`, `equipe_id`, `equipe_responsavel_obra_id` todos nulos. No banco existem 359 projetos com `arquivado = true` (184 "Obra Finalizada", 162 "Não Fechou", 8 "Elaboração Orçamento", 3 "Proposta Sinal", 2 "Estudo Inicial").

Em `BudgetFormPage.tsx` (~linhas 1299-1305), o combobox de busca de projeto no "Novo Orçamento" filtra:
```ts
projetos.filter(p => !p.arquivado || (isEditing && budgetToEdit?.projeto_id === p.id))
```
— projeto arquivado só aparece se já se estiver editando um orçamento que aponta para ele; nunca aparece ao criar um orçamento novo. Uma segunda trava equivalente existe em `onSubmit` (~linhas 681-690), que rejeita `projeto.arquivado` do mesmo jeito. Isso bate exatamente com o sintoma relatado.

Esse filtro **é aparentemente intencional** (impedir orçamento novo em obra já fechada/arquivada). O problema é que a Mariane afirma que o 24.200 está "ativo" no CRM, o que contradiz `arquivado = true` no banco. No CRM local (`lucenera-crm-3bd29 (1)`, submodule sabidamente desatualizado — ver `[[feedback_crm_submodule_muito_desatualizado]]`), a listagem principal (`Index.tsx`) também filtra `.eq('arquivado', false)` por padrão — ou seja, o próprio CRM, ao menos nesta versão local, não trataria o 24.200 como parte da lista padrão de projetos ativos. Não foi possível confirmar contra o Skip publicado (projectId `24580`) como a Mariane efetivamente localizou/considerou o projeto "ativo" (busca sem esse filtro, tela de detalhe direta, ou versão publicada com regra diferente da local).

**Decisão de negócio pendente (não decidida por este agente — ver "Decisão Pendente" abaixo).**

### Decisão Pendente — item 2.4 (registrar explicitamente, não reabrir sem essa resposta)

Duas opções mapeadas, mutuamente exclusivas:

- **(a) O dado está errado**: o projeto 24.200 foi arquivado por engano (ou o fechamento de obra não deveria implicar `arquivado = true` automaticamente) — a correção é ajustar o dado (`arquivado = false`), não o filtro do formulário. Precisaria de auditoria adicional para saber se há outros projetos na mesma situação antes de corrigir só este.
- **(b) O filtro está errado**: obra finalizada/arquivada ainda pode precisar de um orçamento novo (ex.: pedido complementar/aditivo pós-entrega) — nesse caso a regra do formulário precisa mudar, por exemplo com um toggle "mostrar projetos arquivados" na busca, exigindo confirmação extra antes de vincular um orçamento a um projeto arquivado (para não banalizar o bloqueio existente).

**Critério de aceite (só aplicável após a decisão):** projeto 24.200 (ou qualquer projeto na mesma situação decidida como correta) passa a estar disponível na busca de "Novo Orçamento" sem contornar a proteção de projetos genuinamente encerrados/sem uso futuro.

## Realizado

### 2026-08-06

- Migration `20260806_083_spec068_desconto_tipo_sinal_orcamento` aplicada no Supabase real (`orcamentos.desconto_tipo`/`valor_sinal`, RPC `buscar_orcamento_para_aprovacao` atualizada).
- Dado corrigido: projeto 24.200 (`arquivado` de `true` para `false`).
- `gestao-financeira-clone-544cb` (Skip `projectId 32554`) publicado em produção, versão `0.0.303`/`f06803c`: `BudgetFormPage.tsx` (nome cliente, desconto/sinal, vendedor), `ClientApproval.tsx` + `services/clientApprovalService.ts` (documento do cliente).
- QA pipeline do Skip (setup/static/build/integrations/test) passou limpo antes da publicação.
- Itens 2.2, 2.3, 2.4 (correção do dado) concluídos. Item 2.1 mitigado (formatação corrigida) mas causa raiz literal não confirmada — ver Pendências.

## Pendências

- [ ] **Item 2.1 — causa raiz literal não confirmada**: a formatação do nome do cliente foi corrigida (Razão Social + Nome Fantasia), mas não foi encontrado, no código publicado no Skip, nenhum ponto onde `projeto.codigo` era atribuído ao campo de nome — reabrir com um print/passo a passo de reprodução se o sintoma persistir após esta publicação.
- [ ] **Item 2.4 — CRM não investigado**: não foi confirmado, contra o Skip publicado do CRM (projectId `24580`), como a Mariane via o projeto 24.200 como "ativo" apesar do dado incorreto — não bloqueou a correção do caso concreto, mas explica a causa apenas parcialmente.
- [ ] **Item 2.4 — auditoria mais ampla**: existem 359 projetos com `arquivado = true` no banco; não foram auditados individualmente para saber se algum outro está arquivado por engano como o 24.200 estava.
- [ ] **Homologação manual**: os 4 itens publicados ainda não foram testados manualmente no navegador nesta sessão (golden path + edge cases) — recomendado antes de considerar a SPEC 100% encerrada.
- [ ] **Documentação**: `supabase/db/domains/orcamentos.md` e `AI_DB_CONTEXT.md` do sistema Orçamentos ainda não foram atualizados com as colunas novas (`desconto_tipo`, `valor_sinal`).
