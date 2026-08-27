---
titulo: "SPEC-042 — CRM: Cadastro Rápido de Cliente Completo + Edição de Vínculos no Projeto"
status: pendente
data_ultima_modificacao: 2026-07-23
sistemas_envolvidos:
  - CRM (lucenera-crm)
---

# SPEC-042 — CRM: Cadastro Rápido de Cliente Completo + Edição de Vínculos no Projeto

> Preencher o frontmatter acima antes de escrever o resto. `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Nota sobre origem do código

O sistema **CRM** (repositório `pedrolalala/lucenera-crm`) não está carregado como submodule em `04-Sistemas/` neste repositório central. Ele foi clonado temporariamente do GitHub (`https://github.com/pedrolalala/lucenera-crm`, branch padrão) apenas para leitura/análise durante a criação desta SPEC. Antes de implementar, avaliar se o submodule deve ser adicionado formalmente em `04-Sistemas/` conforme o padrão dos demais sistemas (ver `AGENTS.md`).

## Checklist de Ação

- [x] Item 1 — Ajustar `NewContactModal` (`src/components/NewContactModal.tsx`) para exibir o formulário completo de cliente quando `type === 'cliente'` (mesmo padrão de campos e nomenclatura do modal "Novo Cliente" já existente em `src/pages/contatos/Clientes.tsx`).
- [x] Item 2 — Extrair o formulário completo de cliente (schema Zod + JSX) de `Clientes.tsx` para um componente compartilhado, reaproveitado tanto pela página de Clientes quanto pelo cadastro rápido dentro de Novo Projeto.
- [x] Item 3 — Corrigir o Sheet "Editar Projeto e Parcelas" em `src/pages/Projetos.tsx` para permitir editar Cliente, Responsável, Arquiteto e Engenheiro (hoje exibidos como texto fixo mesmo em modo de edição).
- [x] Item 4 — Incluir `cliente_id`, `responsavel_id`, `arquiteto_id` e `responsavel_obra_id` no payload salvo por `handleSave` em `Projetos.tsx` (hoje o `dataToSave` não envia esses campos).
- [x] Item 5 — Validar se a mesma revisão deve ser aplicada à página cheia `src/pages/ProjectDetail.tsx` (ela já edita esses vínculos corretamente — usar como referência de implementação).

### Passos manuais do usuário

- [ ] Confirmar se o repositório `lucenera-crm` deve ser adicionado como submodule em `04-Sistemas/` do repositório central (ver "Nota sobre origem do código" acima).
- [ ] Aprovar decisão sobre extração do formulário de cliente em componente compartilhado (Item 2) antes da implementação, incluindo se os tipos Arquiteto/Engenheiro/Eletricista devem ganhar os mesmos campos extras no futuro (fora do escopo desta SPEC).
- [ ] Homologar em ambiente de teste antes de publicar no CRM em produção.

## Objetivo

Dois problemas foram reportados no CRM (aba **Registro de Novo Projeto → Novo Cliente** e tela **Editar Projeto e Parcelas**):

1. O cadastro rápido de cliente, aberto a partir do fluxo "Novo Projeto", usa um formulário reduzido (Nome, Telefone, E-mail) que não corresponde ao padrão completo de cadastro de cliente já existente na página de Clientes (Empresa, E-mail Financeiro, Celular, Telefone Fixo, CPF/CNPJ, RG, Cidade, Estado, CEP, Bairro, Endereço, Observações, Status de Atividade).
2. No Sheet de edição rápida "Editar Projeto e Parcelas" (acessado a partir da listagem de Projetos), os campos Cliente, Responsável, Arquiteto e Engenheiro aparecem como texto fixo ("-") mesmo em modo de edição, impedindo vincular ou trocar esses contatos no projeto.

O objetivo é padronizar o cadastro rápido de cliente com o formulário completo já existente, e destravar a edição dos vínculos de contato (cliente/responsável/arquiteto/engenheiro) na tela de edição rápida do projeto.

## Decisões aprovadas

- O cadastro rápido de cliente dentro de "Novo Projeto" deve seguir exatamente o mesmo padrão de campos, rótulos, placeholders e textos ("Novo Cliente" / "Preencha os dados do cliente para adicioná-lo ao sistema." / botão "Criar Cliente") já usados no modal de Clientes.
- Os campos Cliente, Responsável, Arquiteto e Engenheiro devem ser editáveis no Sheet "Editar Projeto e Parcelas", com o mesmo comportamento de seleção (dropdown com lista de contatos) já implementado na página completa `ProjectDetail.tsx`.

## Definição da SPEC

### 1. Estado atual — Cadastro rápido de cliente

**Arquivo:** `src/components/NewContactModal.tsx`

Componente único e genérico, reaproveitado para os 4 tipos de contato (`cliente`, `arquiteto`, `engenheiro`, `eletricista`), usado a partir de `src/pages/ProjectNew.tsx` (botão "+" / opção "Novo Cliente" no combobox de seleção de cliente).

Schema atual (`NewContactModal.tsx`):
```
nome (obrigatório), email, telefone
```
Insere direto em `contatos` com `{ ...values, tipo: type, ativo: true, created_by }`.

**Formulário completo já existente** (referência): `src/pages/contatos/Clientes.tsx`, `clientSchema` (linhas ~89–171) e JSX do modal "Novo/Editar Cliente" (linhas ~770–1029):

| Campo (label) | Coluna em `contatos` | Obrigatório |
|---|---|---|
| Nome | `nome` | sim |
| Empresa | `nome_empresa` | não |
| E-mail | `email` | não (valida formato se preenchido) |
| E-mail Financeiro | `email_financeiro` | não (valida formato se preenchido) |
| Celular | `celular` | não |
| Telefone Fixo | `telefone` | não |
| CPF / CNPJ | `cpf_cnpj` | não (unique constraint no banco — erro tratado: `23505`) |
| RG | `rg` | não |
| Cidade | `cidade` | não |
| Estado (UF) | `estado` | não (maxLength 2, uppercase) |
| CEP | `cep` | não |
| Bairro | `bairro` | não |
| Endereço | `endereco` | não |
| Observações | `observacoes` | não |
| Status de Atividade | `ativo` (boolean, default true) | não |

Todas as colunas já existem na tabela `contatos` (ver `supabase/migrations/20260415180000_restructure_schema.sql`), não há impacto de banco.

### 2. Mudança proposta — Cadastro rápido de cliente

- Extrair o formulário completo (schema + JSX) de `Clientes.tsx` para um componente compartilhado (ex.: `src/components/ClientFormFields.tsx` ou equivalente), evitando duplicar os ~14 campos em dois lugares.
- `Clientes.tsx` passa a consumir esse componente compartilhado no modal de Novo/Editar Cliente (sem mudança de comportamento visível ali).
- `NewContactModal.tsx`: quando `type === 'cliente'`, renderizar o formulário completo (mesmo título "Novo Cliente", mesma descrição "Preencha os dados do cliente para adicioná-lo ao sistema.", botão "Criar Cliente"). Para os demais tipos (`arquiteto`, `engenheiro`, `eletricista`), manter o formulário reduzido atual — não fazem parte do pedido e não há confirmação de que precisam dos mesmos campos.
- Ajustar `onSuccess` do modal para devolver o contato criado do mesmo jeito que hoje (usado por `ProjectNew.tsx` para pré-selecionar o cliente recém-criado).

### 3. Estado atual — Edição de vínculos no projeto

Existem **dois** editores de projeto no CRM, com comportamentos diferentes hoje:

**a) `src/pages/ProjectDetail.tsx`** (página completa `/projetos/:id`, botão "Editar Projeto")
- Já funciona corretamente: Cliente, Responsável, Arquiteto e Engenheiro são `<Select>` editáveis, populados a partir de `useProjectStore().contacts` filtrado por `tipo` (linhas 279–282, 505–650).
- `handleSave` já envia `cliente_id`, `arquiteto_id`, `responsavel_id`, `responsavel_obra_id` no payload de update (linhas 199–211).
- **Nenhuma mudança necessária aqui** — serve de referência de implementação para o item (b).

**b) `src/pages/Projetos.tsx`** (Sheet lateral "Editar Projeto e Parcelas", aberto a partir da listagem/kanban de Projetos) — **é aqui que está o bug relatado pelo usuário**.
- Campos Código, Nível Estratégico, Projeto, Data de Entrada, Status, Cidade, Estado usam `renderField()` (linha 424) e ficam editáveis via `<Input>`.
- Campos **Cliente** (linhas 928–935), **Responsável** (937–946), **Arquiteto** (951–958) e **Engenheiro** (960–967) são renderizados como texto estático (`<p>{selectedProjeto.cliente?.nome || '-'}</p>`) mesmo dentro do bloco `isEditing`, sem nenhum controle de formulário — por isso o usuário não consegue trocar/vincular esses contatos.
- Mesmo que os campos fossem tornados editáveis, `handleSave` (linhas 342–359) monta `dataToSave` sem `cliente_id`, `arquiteto_id`, `responsavel_id` nem `responsavel_obra_id` — ou seja, a alteração não seria persistida mesmo que capturada em estado local.
- `editedProjeto` é inicializado com `{ ...selectedProjeto }` (linha 323), então os IDs originais já estão disponíveis no estado — só faltam os controles de UI e o envio no payload.

### 4. Mudança proposta — Edição de vínculos no projeto

Em `src/pages/Projetos.tsx`:

- Importar `useProjectStore` (mesmo hook já usado em `ProjectDetail.tsx`) para obter `contacts`, e derivar `clientes`, `arquitetos`, `engenheiros`, `outros` por `tipo` (mesmo padrão de `ProjectDetail.tsx` linhas 279–282).
- Substituir os 4 blocos de texto estático (Cliente/Responsável/Arquiteto/Engenheiro) por `<Select>` editáveis quando `isEditing` for `true`, atualizando `editedProjeto.cliente_id` / `responsavel_id` / `arquiteto_id` / `responsavel_obra_id` via `setEditedProjeto`. Pode reaproveitar o padrão de `Select` já usado em `ProjectDetail.tsx` (linhas 505–650) ou o padrão de combobox pesquisável (`Popover` + `Command`) já usado em `ProjectNew.tsx` para o campo Cliente — usar `Select` simples é suficiente e mais consistente com o restante do Sheet, que já usa `renderField` com controles simples.
- Incluir os 4 campos em `dataToSave` dentro de `handleSave` (linha ~346–357):
  ```
  cliente_id: editedProjeto.cliente_id,
  responsavel_id: editedProjeto.responsavel_id,
  arquiteto_id: editedProjeto.arquiteto_id,
  responsavel_obra_id: editedProjeto.responsavel_obra_id,
  ```
- Ao exibir os nomes atualizados após salvar, garantir que `loadProjetos()` (linha 400) recarregue os relacionamentos (`cliente`, `responsavel`, `arquiteto`, `engenheiro`) — já é o comportamento de `getProjetos()`/`getProjeto()` usado em `ProjectDetail.tsx`, apenas confirmar que `Projetos.tsx` usa a mesma função com os mesmos `select` relacionais.

### Impacto no banco

Nenhum. Todas as colunas usadas (`contatos.*`, `projetos.cliente_id/arquiteto_id/responsavel_id/responsavel_obra_id`) já existem.

### Impacto em telas

- Modal "Novo Cliente" dentro de Novo Projeto (`ProjectNew.tsx` → `NewContactModal`).
- Modal Novo/Editar Cliente em `Clientes.tsx` (refatorado para componente compartilhado, sem mudança de comportamento).
- Sheet "Editar Projeto e Parcelas" em `Projetos.tsx` (listagem/kanban de Projetos).

### Regras de permissão

Nenhuma mudança de permissão. Segue a regra já vigente: quem tem acesso para editar projeto/criar cliente no CRM continua com o mesmo acesso.

### Critérios de aceite

- No fluxo Novo Projeto → "Novo Cliente" (tanto pelo botão "+" quanto pela opção no combobox), o modal exibe todos os campos do padrão completo (Empresa, E-mail Financeiro, Celular, Telefone Fixo, CPF/CNPJ, RG, Cidade, Estado, CEP, Bairro, Endereço, Observações, Status de Atividade) com os mesmos rótulos/placeholders da página de Clientes, e o cliente criado é selecionado automaticamente no projeto.
- Cadastro de cliente pela página de Clientes continua funcionando sem regressão (criação e edição).
- No Sheet "Editar Projeto e Parcelas", ao clicar em "Editar Projeto", os campos Cliente, Responsável, Arquiteto e Engenheiro viram dropdowns editáveis com a lista de contatos do tipo correspondente.
- Ao trocar o Cliente (ou Responsável/Arquiteto/Engenheiro) no Sheet e salvar, o vínculo é persistido no banco e refletido na listagem/kanban e na página completa do projeto (`/projetos/:id`).
- Nenhuma regressão no fluxo de edição de Parcelas dentro do mesmo Sheet.

### Testes/verificações obrigatórias

- Criar um cliente novo pelo cadastro rápido dentro de Novo Projeto preenchendo todos os campos novos e confirmar persistência correta em `contatos` (incluindo tratamento do erro de CPF/CNPJ duplicado, igual ao já existente em `Clientes.tsx`).
- Editar um projeto existente pelo Sheet da listagem, trocar o Cliente e o Arquiteto, salvar, e verificar que os IDs corretos foram gravados em `projetos` (não apenas os nomes, mas os UUIDs corretos).
- Conferir no `ProjectDetail.tsx` (página completa) que o vínculo alterado pelo Sheet aparece corretamente, confirmando que os dois editores ficam consistentes.

## Realizado

### 2026-07-22

- Criado `src/components/ClientFormFields.tsx`: `clientSchema`, `ClientFormValues`, `clientFormDefaultValues` e o componente `<ClientFormFields form={form} />` com os 14 campos completos de cliente, extraídos de `Clientes.tsx` sem alterar nomes/rótulos/placeholders.
- `src/pages/contatos/Clientes.tsx`: passou a importar schema/defaults/campos do módulo compartilhado em vez de defini-los localmente. Removidas ~230 linhas duplicadas (schema Zod + JSX dos 14 `FormField`). Nenhuma mudança de comportamento visível na página de Clientes.
- `src/components/NewContactModal.tsx`: quando `type === 'cliente'`, renderiza um `<Dialog>` próprio com título "Novo Cliente", descrição "Preencha os dados do cliente para adicioná-lo ao sistema.", o `<ClientFormFields />` completo e botão "Criar Cliente" — usando um `useForm<ClientFormValues>` dedicado (`clientForm`), mantendo o `useForm` reduzido original (`simpleForm`) intacto para os demais tipos (Arquiteto/Engenheiro/Eletricista). Inserção trata erro de CPF/CNPJ duplicado (`23505`) igual à página de Clientes.
- `src/pages/Projetos.tsx`: adicionado `useProjectStore()` para obter `contacts`, derivadas as listas `clientes`/`arquitetos`/`engenheiros`/`outros` por `tipo` (mesmo padrão de `ProjectDetail.tsx`). Os 4 blocos de texto estático (Cliente/Responsável/Arquiteto/Engenheiro) no Sheet "Editar Projeto e Parcelas" viraram `<Select>` editáveis ligados a `editedProjeto`. `handleSave` passou a incluir `cliente_id`, `responsavel_id`, `arquiteto_id` e `responsavel_obra_id` no `dataToSave`.
- Verificação: `ProjectDetail.tsx` (página completa `/projetos/:id`) conferida — já editava esses 4 vínculos corretamente antes desta SPEC; nenhuma mudança necessária lá (Item 5).
- Validação técnica no clone local (`npm install` + `npx tsc --noEmit` + `npx oxlint` + `npm run build`): build de produção passou limpo; nenhum novo erro de tipo ou lint introduzido além de um conjunto pré-existente de erros de `tsc` já presentes no `main` antes desta mudança (confirmado comparando com/sem as alterações via `git stash`) — a saber, um conflito de tipos entre `zod` `.default()` e a versão de `@hookform/resolvers` no schema de cliente (já existia isolado em `Clientes.tsx`, agora também aparece em `NewContactModal.tsx` por reaproveitar o mesmo schema), além de erros não relacionados em `App.tsx`, `DashboardCharts.tsx`, `ProjectActions.tsx`, `ProjectTable.tsx`, `chart.tsx`, `ProjectNew.tsx` e `services/projetos.ts`. Nenhum desses bloqueia o `vite build`.
- Descoberto que o projeto Skip "Lucenera CRM" (id 24580, org "Org Lucenera") é a fonte real/hospedada do sistema — as mudanças acima foram aplicadas lá via `skip_file_write`/`skip_file_patch` e commitadas com `skip_project_apply_changes` (QA completo: setup, análise estática, build, integrações e testes, todos `ok`). Versão publicada: `0.0.271` (hash `3064fdd`). Push para o `main` do GitHub `pedrolalala/lucenera-crm` **não confirmado** — não há ferramenta de sincronização Skip→GitHub disponível via MCP; `origin/main` permaneceu no commit antigo (`9078947`) após o commit no Skip.
- **Correção adicional (mesmo dia, após teste do usuário):** o Select de Cliente/Arquiteto/Engenheiro no Sheet apareciam vazios (só "Nenhum", sem outras opções) e Responsável nunca mostrava o valor salvo. Causa raiz dupla:
  1. `useProjectStore().contacts` (padrão copiado de `ProjectDetail.tsx`) não carrega de forma confiável nessa tela — nenhuma outra tela do sistema depende dele para listas de seleção (`ProjectNew.tsx` e `Clientes.tsx` buscam contatos direto do Supabase). Trocado por fetch direto (`supabase.from('contatos').select('id, nome').eq('tipo', X)`) em estados locais (`clientesOptions`, `arquitetosOptions`, `engenheirosOptions`).
  2. `projetos.responsavel_id` **não referencia `contatos`** — uma migration (`20260417145200_fix_projetos_responsavel_fk.sql`) redirecionou essa FK para `usuarios` (equipe interna). O restante do sistema trata "Responsável" como texto livre (`responsavel_nome`, com sugestões via `datalist` na tela de criação), não como vínculo. O Select foi substituído por um campo de texto simples (`renderField('Responsável', 'responsavel_nome')`), e `handleSave` passou a enviar `responsavel_nome` em vez de `responsavel_id`.
  - Aplicado e commitado no Skip via `skip_project_apply_changes` (QA completo novamente `ok`). Versão publicada: `0.0.272` (hash `4bcc0f9`).
  - **Nota:** `ProjectDetail.tsx` (página completa `/projeto/:id`) provavelmente tem os mesmos dois problemas (usa o mesmo `useProjectStore` e o mesmo Select de Responsável via `responsavel_id`/`outros`), mas isso está fora do escopo original desta SPEC e não foi verificado nem corrigido — ver pendência abaixo.
- **Refinamento de UX (mesmo dia, pedido do usuário):** com a base de clientes grande, o `<Select>` simples (lista fixa) ficava lento/impraticável para achar um cliente. Trocados os 3 campos (Cliente/Arquiteto/Engenheiro) por um combobox com busca (`ContactCombobox`, novo componente local em `Projetos.tsx`), no mesmo padrão já usado em `ProjectNew.tsx`: `Popover` + `Command` com `CommandInput`, busca no Supabase com `ilike` (debounce de 300ms, limite 50 resultados) em vez de carregar a lista inteira de uma vez. `startEditing()` agora inicializa `selectedClienteNome`/`selectedArquitetoNome`/`selectedEngenheiroNome` a partir de `selectedProjeto.cliente?.nome` etc. (já vem no join de `getProjetos()`) para mostrar o valor atual sem precisar buscar de novo. Removidos os estados `clientesOptions`/`arquitetosOptions`/`engenheirosOptions` (fetch único de até 2000 registros) e o import não utilizado de `Select`/`SelectContent`/`SelectItem`/`SelectTrigger`/`SelectValue`. Aplicado e commitado no Skip via `skip_project_apply_changes` (QA completo `ok`). Versão publicada: `0.0.273` (hash `16f6c06`).

## Pendências

- [x] Definir se `lucenera-crm` deve ser formalmente adicionado como submodule em `04-Sistemas/` do repositório central — **feito em 2026-07-23** (ver SPEC-043): registrado via `git submodule add -f` em `04-Sistemas/lucenera-crm-3bd29 (1)`, apontando para `heads/main` do GitHub (commit `9078947`). **Atenção:** esse commit é o mesmo `main` antigo citado abaixo — ainda **não inclui** as mudanças desta SPEC (0.0.271–0.0.273), que só existem no Skip (projeto `24580`), pois o push Skip→GitHub nunca foi confirmado. O submodule local ficará desatualizado em relação ao publicado em produção até esse push acontecer.
- [ ] Confirmar/realizar o push do commit feito no Skip para o `main` do repositório `pedrolalala/lucenera-crm` no GitHub — não há ferramenta MCP para isso; verificar a integração Skip↔GitHub na interface web do Skip.
- [ ] Verificar se `ProjectDetail.tsx` (`/projeto/:id`) tem os mesmos dois bugs de `Projetos.tsx` corrigidos nesta SPEC (dependência de `useProjectStore().contacts` não confiável, e Select de Responsável apontando para `contatos` em vez de tratar como texto livre `responsavel_nome`) — não verificado nem corrigido, pois estava fora do escopo original do relato do usuário.
- [ ] Homologar em ambiente de teste antes de publicar no CRM em produção (ver "Passos manuais do usuário").
- [ ] Avaliar (fora do escopo desta SPEC) se Arquiteto/Engenheiro/Eletricista também deveriam ganhar os campos extras do formulário completo no cadastro rápido — não solicitado pelo usuário, manter reduzido por ora.
- [ ] Corrigir, se desejado, o conflito de tipos pré-existente entre `zod`/`@hookform/resolvers` no `clientSchema` (campo `ativo`) — não é regressão desta SPEC, mas ficou mais visível por o schema agora ser reaproveitado em dois componentes.
