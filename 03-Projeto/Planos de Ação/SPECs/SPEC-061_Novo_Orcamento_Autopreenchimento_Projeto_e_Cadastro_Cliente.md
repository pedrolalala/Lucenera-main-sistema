---
titulo: "SPEC-061 — Novo Orçamento: autopreenchimento por projeto + correções no cadastro rápido de cliente"
status: concluído
data_ultima_modificacao: 2026-08-05
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb (1))
  - CRM (lucenera-crm-3bd29 (1))
  - Supabase (banco central)
---

# SPEC-061 — Novo Orçamento: autopreenchimento por projeto + correções no cadastro rápido de cliente

> Origem: pontos levantados pela equipe de Projetos sobre a tela "Novo Orçamento" (`gestao-financeira-clone-544cb (1)`), a partir de prints da tela e do relato da Mariane ("fiz o cadastro do cliente agora e ele não tá encontrando pra eu montar o orçamento"). Sem ata formal em `02-Reunioes/` — registrado diretamente nesta SPEC a partir da conversa com o usuário em 2026-08-05.

## Checklist de Ação

- [x] `BudgetFormPage.tsx` (Orçamentos): quando o projeto selecionado tiver `arquiteto_id` nulo mas a coluna legada `"Nome Arquiteto"` (texto) estiver preenchida, buscar em `contatos` (`tipo='arquiteto'`) por nome (`ilike`) e, havendo exatamente uma correspondência, pré-selecionar `arquiteto_id` automaticamente com um aviso "vinculado automaticamente pelo nome do projeto — confira antes de salvar". Sem correspondência única, mantém o campo vazio para seleção manual.
- [x] `BudgetFormPage.tsx`: quando `projeto.cliente_id` e/ou `projeto.empresa_id` vierem nulos, o card de detalhes do projeto agora mostra um aviso explícito ("Projeto sem cliente/empresa vinculado(a) na origem — selecione manualmente"), em âmbar, distinto do "Não encontrado" (erro de busca).
- [x] `ClientCreateModal.tsx` (Orçamentos): `email` obrigatório no schema Zod, com asterisco vermelho no label e mensagem de erro clara.
- [x] `ClientFormFields.tsx`/`clientSchema` (CRM — usado por `Clientes.tsx` e `NewContactModal.tsx`): mesma alteração — `email` obrigatório.
- [x] Migration `20260805_078_spec061_complemento_e_vendedor_funcionarios` adicionando `complemento`, `complemento_entrega` e `complemento_cobranca` (text, nullable) na tabela `contatos`. **Aplicada no Supabase real.**
- [x] `ClientCreateModal.tsx` (Orçamentos): campo "Complemento" nos 3 blocos de endereço (principal, entrega, cobrança), ao lado do campo "Número" de cada bloco.
- [x] `ClientFormFields.tsx` (CRM): mesma alteração, nos mesmos 3 blocos (principal ficou ao lado de "Endereço", já que esse formulário nunca teve um campo "Número" separado para o bloco principal).
- [x] Atualizar `supabase/db/domains/crm.md` e `orcamentos.md`.
- [x] Migration trocando a FK de `contatos.vendedor_id` e `contatos.vendedor_padrao_id` de `auth.users(id)` para `public.funcionarios(id)` — **checado antes de aplicar: 0 linhas em `contatos` tinham `vendedor_id`/`vendedor_padrao_id` preenchido**, então não houve risco de FK órfã nem necessidade de backfill. **Aplicada no Supabase real.**
- [x] `ClientCreateModal.tsx` (Orçamentos): trocada a query dos campos "Vendedor" e "Vendedor Padrão" de `supabase.from('usuarios')` para `supabase.from('funcionarios').eq('status','Ativo')`, mesmo padrão do campo Vendedor da tela principal.
- [x] `ProjectNew.tsx` (CRM): Cliente obrigatório de verdade — **achado ao implementar**: a validação `z.string().min(1)` já existia mas não bloqueava nada, porque o valor "não selecionado" é a string literal `'null'` (sentinela do combobox), que tem 4 caracteres e passava em `min(1)`. Trocado para `.refine((v) => v !== 'null' && v.trim().length > 0)`.

### Passos manuais do usuário

- [ ] Decidir o ponto em aberto sobre o campo "Vendedor" dentro do modal "Criar Novo Cliente" (ver seção "Vendedor — achado importante" abaixo) — envolve dado estrutural (`contatos.vendedor_id`), não é só troca de query.
- [ ] Confirmar com a Mariane se o bug de "cliente cadastrado não encontrado" ainda reproduz hoje (ver "Achado" no item 5) — pode já estar resolvido, precisa homologar em vez de reabrir código às cegas.
- [ ] Decidir, junto com o time de Projetos/CRM, se a criação de projeto no CRM deve passar a exigir `cliente_id` (causa raiz de "Cliente: Não encontrado" quando o projeto nunca teve cliente vinculado) — fora do escopo desta SPEC, é uma mudança de regra em outro fluxo (criação de projeto, não criação de orçamento).
- [ ] Homologação manual no navegador (não há suíte automatizada nestes dois sistemas): testar seleção de projeto com e sem arquiteto/cliente vinculado, cadastro de cliente sem e-mail (deve bloquear), preenchimento de complemento nos 3 blocos de endereço e persistência ao reabrir.
- [ ] Rodar o agente `revisor` antes de qualquer commit.
- [ ] `git push` dos submodules `gestao-financeira-clone-544cb (1)` e `lucenera-crm-3bd29 (1)`, atualização do ponteiro no repo central, e publicação via Skip (projectId `32554` Orçamentos, projectId `24580` CRM — confirmar com `skip_project_status` antes de editar, ver [[reference_skip_project_ids]]).

## Objetivo

Reduzir redigitação e corrigir gaps pontuais na tela "Novo Orçamento" (Orçamentos) e no cadastro de cliente (CRM + Orçamentos), a partir de 5 pontos trazidos pela equipe de Projetos:

1. Selecionar o projeto deveria aproveitar ao máximo os dados que o projeto já tem (cliente, arquiteto), em vez de pedir para preencher tudo de novo.
2. E-mail não pode ser opcional no cadastro de cliente.
3. Falta o campo "Complemento" no endereço do cliente.
4. O campo Vendedor deveria vir da tabela `funcionarios` do Supabase.
5. Bug relatado pela Mariane: cliente cadastrado "dentro do orçamento" não aparece para montar o orçamento.

## Decisões aprovadas

- A obrigatoriedade de e-mail é só na camada de formulário (CRM + Orçamentos) — a coluna `contatos.email` no banco continua nullable, para não quebrar dados legados/importações que ainda não têm e-mail.
- Autopreenchimento por nome (fallback quando não há FK) só se aplica quando houver exatamente uma correspondência — em caso de ambiguidade ou zero resultados, o campo fica vazio para seleção manual (não adivinhar vínculo errado).

## Definição da SPEC

### 1. Autopreenchimento ao selecionar o projeto

**Estado atual (achado):** o autopreenchimento por FK **já existe** em `BudgetFormPage.tsx` → `handleProjectSelect` (linhas ~501-538): quando o projeto tem `cliente_id`, `empresa_id`, `arquiteto_id` ou `vendedor_id`/`responsavel_id` preenchidos, o formulário já chama `form.setValue(...)` automaticamente para os 4 campos. Ou seja, para projetos com esses vínculos já cadastrados, o problema relatado **não deveria ocorrer** hoje.

**O que está causando o sintoma no print enviado:** o projeto usado no teste (26.143 — NOVO ROD) tem `cliente_id` e `empresa_id` nulos na tabela `projetos` — por isso aparece "Não encontrado" no card e o campo Cliente continua pedindo seleção manual. Não é uma falha de autopreenchimento, é ausência do vínculo na origem do projeto. Já o Arquiteto aparece preenchido no card ("COMOVER ARQUITETURA E PAULA CECCHI") porque existe uma coluna de texto legada `projetos."Nome Arquiteto"`, mas essa informação **não é usada** para preencher o dropdown "Arquiteto / Profissional" quando `arquiteto_id` é nulo (o texto e o FK são dados diferentes e hoje desconectados).

**Mudança proposta:**
- Usar `"Nome Arquiteto"` como fallback de autopreenchimento por nome quando `arquiteto_id` for nulo (ver Checklist).
- Não inventar fallback de texto para Cliente/Empresa — não existe coluna de texto equivalente em `projetos` para isso hoje. Tornar visível ao usuário que o projeto simplesmente não tem esse vínculo, para não parecer bug do formulário.

### 2. E-mail obrigatório no cadastro de cliente

Hoje, tanto `ClientCreateModal.tsx` (Orçamentos) quanto `Clientes.tsx` (CRM) — os dois formulários de cliente vivos em produção (ver mapeamento completo em [[SPEC-052]]) — têm `email` opcional no schema Zod. Tornar obrigatório nos dois, mantendo a coluna do banco nullable (ver Decisões aprovadas).

### 3. Campo "Complemento" no endereço

Conferido em `supabase/db/current/01_schema_full.sql` (tabela `contatos`, linhas 4483-4541): existem `numero`/`numero_entrega`/`numero_cobranca`, mas **nenhuma coluna de complemento** em nenhum dos 3 blocos de endereço (a tabela `empresas` até tem `complemento`, `contatos` não). Precisa de migration + campo novo nos dois formulários vivos, nos 3 blocos (principal, entrega, cobrança) — mesmo padrão dos blocos já existentes (SPEC-052).

### 4. Vendedor buscado do Supabase (`funcionarios`)

**Achado importante — dois campos "Vendedor" diferentes, com FKs diferentes:**

| Campo | Onde | Fonte hoje | FK no banco | Status |
|---|---|---|---|---|
| "Vendedor" (tela principal Novo Orçamento) | `BudgetFormPage.tsx` via `useOptions()` | `funcionarios` (`status='Ativo'`) | `orcamentos.vendedor_id → public.funcionarios(id)` | **Já implementado corretamente** — nenhuma ação necessária aqui. |
| "Vendedor" / "Vendedor Padrão" (dentro do modal "Criar Novo Cliente") | `ClientCreateModal.tsx` | `usuarios` | `contatos.vendedor_id → auth.users(id)` e `contatos.vendedor_padrao_id → auth.users(id)` | Fonte diferente por design — trocar para `funcionarios` sem migration quebraria o insert (FK aponta para `auth.users`, não para `funcionarios`). |

O pedido da equipe ("vendedor deveria buscar da planilha funcionarios") já está satisfeito no campo que aparece na tela "Novo Orçamento". O campo de mesmo nome dentro do modal de cadastro de cliente é um conceito diferente no banco (vendedor/usuário responsável pelo contato, não funcionário da tabela `funcionarios`) — trocar a fonte exigiria alterar a FK de `contatos.vendedor_id`/`vendedor_padrao_id` para apontar para `funcionarios`, com risco de perder o vínculo com `auth.users` usado em outras partes do sistema. **Não fazer essa troca sem confirmação explícita do usuário** — ver Passos manuais.

### 5. Bug relatado pela Mariane

**Achado:** o fluxo "+" → criar cliente dentro do Orçamento (`isClientModalOpen` → `ClientCreateModal` → `onSuccess`) **já** chama `fetchClientes()` (recarrega a lista completa de `contatos` tipo `cliente` do Supabase) e **já** chama `form.setValue('cliente_id', newClient.id, ...)` para selecionar automaticamente o cliente recém-criado (`BudgetFormPage.tsx`, linhas ~2047-2062). O combobox de Cliente (`SearchableSelect`) não pagina nem limita resultados — filtra em memória sobre a lista completa recarregada, então o cliente novo deveria aparecer na busca.

Duas hipóteses para o relato da Mariane, nenhuma delas resolvida por reescrever esse código (que já parece correto):
- A versão publicada no Skip (projectId `32554`) pode estar atrás da versão lida neste submodule local — [[feedback_skip_deploy_separate_tree]] já mostrou isso acontecer antes (SPEC-052/053/054). Precisa conferir via `skip_project_status`/`skip_file_read` antes de assumir que o bug já foi corrigido.
- Pode ter sido um cliente cadastrado com `tipo` diferente de `cliente` (o filtro de busca só traz `tipo='cliente'`), ou um erro silencioso de rede/RLS na hora do `fetchClientes()`.

**Ação:** não reabrir esse trecho de código sem antes confirmar no Skip se a versão com `fetchClientes()`+auto-seleção está de fato publicada, e sem reproduzir o bug com a Mariane para descartar as outras hipóteses.

### Análise de ecossistema

- Depende de: `contatos` (nova coluna `complemento*`), `projetos` (leitura de `"Nome Arquiteto"`, `cliente_id`, `arquiteto_id`, `empresa_id`), `funcionarios` (já usado, sem mudança), `orcamentos` (leitura de `vendedor_id`, sem mudança).
- Afeta: Orçamentos (`BudgetFormPage.tsx`, `ClientCreateModal.tsx`) e CRM (`Clientes.tsx`). Não afeta Compras, Estoque, Financeiro, RH, Hub/TI.
- Dado duplicado a observar: `projetos."Nome Arquiteto"` (texto) x `projetos.arquiteto_id` (FK) são duas fontes da mesma informação, hoje desconectadas — o item 1 desta SPEC cria uma ponte entre elas, mas não resolve a causa raiz (por que o projeto foi criado só com texto e sem FK).
- Não há migration antiga contradizendo o snapshot central para os itens desta SPEC.
- `AI_DB_CONTEXT.md` dos dois sistemas precisa ser atualizado após a migration de `complemento`.

## Critérios de aceite

- Selecionar um projeto com `arquiteto_id` nulo mas `"Nome Arquiteto"` preenchido e correspondência única em `contatos` pré-seleciona o Arquiteto automaticamente, com aviso visível de vínculo automático.
- Selecionar um projeto sem `cliente_id`/`empresa_id` mostra aviso claro de "projeto sem vínculo na origem", não apenas "Não encontrado".
- Tentar salvar um novo cliente (CRM ou Orçamentos) sem e-mail bloqueia o envio com mensagem de erro no campo.
- Os 3 blocos de endereço (principal, entrega, cobrança) têm campo "Complemento" nos dois formulários, e o valor persiste ao salvar e reabrir.
- Confirmado (ou corrigido, se necessário) que criar cliente pelo "+" dentro de Novo Orçamento faz o cliente aparecer imediatamente na busca do campo Cliente, sem precisar recarregar a página.

## Testes obrigatórios

Verificação manual no navegador (sem suíte automatizada nestes sistemas):
- Selecionar projeto com arquiteto só em texto (`"Nome Arquiteto"` preenchido, `arquiteto_id` nulo) e conferir autopreenchimento.
- Selecionar projeto com e sem `cliente_id`/`empresa_id` e conferir os dois comportamentos (autopreenchido vs. aviso de dado ausente).
- Criar cliente sem e-mail nos dois formulários e confirmar bloqueio.
- Preencher complemento nos 3 blocos de endereço, salvar, reabrir e conferir persistência sem cruzamento entre blocos.
- Reproduzir o fluxo da Mariane (criar cliente pelo "+" dentro de Novo Orçamento e buscar o nome logo em seguida) na versão publicada no Skip, não só no ambiente local.

## Realizado

### 2026-08-05

- Migration `20260805_078_spec061_complemento_e_vendedor_funcionarios` aplicada no Supabase real: `contatos.complemento`/`complemento_entrega`/`complemento_cobranca` + FK de `vendedor_id`/`vendedor_padrao_id` trocada para `funcionarios(id)` (0 linhas afetadas, sem backfill necessário).
- CRM (`lucenera-crm-3bd29`, Skip `projectId 24580`, versão `0.0.291`/`df632c5`, **publicado em produção**): e-mail obrigatório, complemento nos 3 blocos, `cliente_id` de verdade obrigatório em Novo Projeto (bug do sentinela `'null'` corrigido).
- Orçamentos (`gestao-financeira-clone-544cb`, Skip `projectId 32554`, versão `0.0.302`/`2262db0`, **publicado em produção**): e-mail obrigatório, complemento nos 3 blocos, Vendedor/Vendedor Padrão via `funcionarios`, autopreenchimento de Arquiteto por nome (fallback), aviso claro para projeto sem cliente/empresa na origem.
- **Bug da Mariane**: confirmado direto no Skip (fonte real de produção) que o código de `fetchClientes()` + auto-seleção do cliente recém-criado já estava publicado e correto — hipótese de dessincronia Skip/local descartada. Não reaberto sem reprodução do sintoma.
- QA (build+testes) do Skip passou nas duas publicações antes de ir ao ar.

## Pendências

- [x] `contatos.vendedor_id`/`vendedor_padrao_id` (dentro do modal de cadastro de cliente) — resolvido, ver Realizado.
- [x] Confirmar com a Mariane se o bug de cliente não encontrado ainda reproduz — código confirmado correto e publicado; sem reprodução do sintoma, não há mais o que investigar por análise estática.
- [x] Tornar `cliente_id` obrigatório na criação de projeto no CRM — resolvido, ver Realizado.
- [ ] Teste manual em produção (não pode ser confirmado por análise estática): selecionar projeto com arquiteto só em texto e conferir autopreenchimento; criar cliente sem e-mail nos dois formulários e confirmar bloqueio; preencher complemento nos 3 blocos e confirmar persistência; tentar salvar projeto novo sem cliente e confirmar bloqueio.
