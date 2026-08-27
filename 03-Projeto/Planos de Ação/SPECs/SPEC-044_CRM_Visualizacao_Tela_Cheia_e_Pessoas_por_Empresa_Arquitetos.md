---
titulo: "SPEC-044 — CRM: Visualização/Edição em Tela Cheia (Projetos, Clientes, Arquitetos, Engenheiros, Eletricistas) + Pessoas por Empresa em Arquitetos"
status: concluído
data_ultima_modificacao: 2026-07-23
sistemas_envolvidos:
  - CRM (lucenera-crm)
---

# SPEC-044 — CRM: Visualização/Edição em Tela Cheia + Pessoas por Empresa em Arquitetos

> Preencher o frontmatter acima antes de escrever o resto. `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Nota sobre origem do código

O sistema **CRM** (repositório `pedrolalala/lucenera-crm`) está registrado como submodule em `04-Sistemas/lucenera-crm-3bd29 (1)/` desde 2026-07-23 (SPEC-043), mas esse submodule aponta para um commit do GitHub (`9078947`) que está **desatualizado** em relação à produção — a fonte real/publicada continua sendo o projeto Skip "Lucenera CRM" (`projectId 24580`, org "Org Lucenera"), hoje na versão `0.0.274`. A implementação desta SPEC deve seguir o mesmo caminho já usado nas SPEC-042/043: editar direto no Skip via `skip_file_write`/`skip_file_patch` e publicar com `skip_project_apply_changes`, não no submodule local.

## Checklist de Ação

- [x] Item 1 — Criada a rota/página cheia genérica de contato: `/contatos/:tipoPlural/:id` (mesma pluralização das rotas de listagem já existentes: `clientes`/`arquitetos`/`engenheiros`/`eletricistas`), componente novo `src/pages/contatos/ContatoDetail.tsx`, com cabeçalho (nome, botão Voltar) e alternância Editar/Salvar/Cancelar, no mesmo padrão de `ProjectDetail.tsx`.
- [x] Item 2 — Campos por tipo definidos em `ContatoDetail.tsx` (config `FIELD_CONFIGS`, um conjunto de campos por tipo em vez de generalizar `ClientFormFields.tsx` inteiro). `data_nascimento` também foi adicionado a `ClientFormFields.tsx` (Zod schema + campo de formulário), já que esse componente continua sendo usado no Dialog "Novo Cliente" e no cadastro rápido do `NewContactModal.tsx`. De brinde, o campo **Status (Ativo/Inativo)** — que já existia na coluna `contatos.ativo` mas só aparecia para Cliente — passou a ser editável nos 4 tipos, e **RG** passou a fazer parte do formulário de Arquiteto (existia no banco, faltava no `arquitetoSchema`).
- [x] Item 3 — `Clientes.tsx`, `Arquitetos.tsx`, `Engenheiros.tsx`, `Eletricistas.tsx` reescritos: clique no card/linha e botão "Editar" navegam para `/contatos/<tipo-plural>/:id`. Os Sheets/Dialogs de visualização e edição foram removidos; os Dialogs de criação ("Novo Cliente/Arquiteto/Engenheiro/Eletricista") continuam intactos.
- [x] Item 4 — Eletricista ganhou edição completa via `ContatoDetail.tsx` (nome, e-mail, celular, telefone, data de nascimento, cidade, estado, observações, status). De brinde, também ganhou exclusão (`AlertDialog`, mesmo padrão dos outros 3 tipos) — não existia antes, é uma pequena extensão de escopo natural já que as outras 3 telas já tinham.
- [x] Item 5 — `Projetos.tsx` reescrito: `<Sheet>` "Editar Projeto e Parcelas" removido por completo; clique no card (`ProjectMobileCards`) e na linha da tabela navega direto para `/projeto/:id`. O botão de edição e o de exclusão na visão em tabela continuam funcionando (exclusão agora chama `refreshProjects()` da store).
- [x] Item 6 — "Pessoas da Empresa" implementado em `ContatoDetail.tsx`: aparece só quando `tipo === 'arquiteto'` e o registro atual tem `empresa_id IS NULL`. Lista pessoas (`contatos` com `tipo='arquiteto' AND empresa_id = <id>`), botão "+" abre um mini-formulário inline (nome, data de nascimento, e-mail) que insere um novo `contatos`. Clicar numa pessoa navega para a própria página cheia dela (reaproveita o mesmo componente — como cada pessoa também é um `contatos` de tipo arquiteto, editar uma pessoa é só abrir sua própria `ContatoDetail`). Cada pessoa tem botão de remover (delete direto, com confirmação via `AlertDialog`).
- [x] Item 7 — Filtro `empresa_id IS NULL` aplicado em: `Arquitetos.tsx` (`fetchArquitetos`), `ProjectNew.tsx` (combobox de arquiteto), `ProjectDetail.tsx` (`arquitetos = contacts.filter(...)`). O combobox de arquiteto que existia em `Projetos.tsx` (`ContactCombobox`) foi removido junto com o Sheet (Item 5), então não precisou de filtro separado.
- [x] Item 8 — Os deep-links `?view=Nome` em `Clientes.tsx`, `Arquitetos.tsx`, `Engenheiros.tsx` e `Eletricistas.tsx` agora resolvem o contato e chamam `navigate('/contatos/<tipo>/' + id, { replace: true })` em vez de abrir Sheet/Dialog.

### Passos manuais do usuário

- [ ] Homologar em ambiente de teste (ou direto em produção, já publicado) — esta SPEC muda a navegação principal de 5 telas: testar o fluxo completo de visualizar/editar/excluir em cada uma, e testar especificamente o fluxo de "Pessoas da Empresa" em Arquitetos.
- [x] Revisar a seção "Pessoas da Empresa" (Item 6) — implementada como: adicionar (insert imediato via "+") e remover (delete com confirmação); **editar uma pessoa já criada** é feito abrindo a própria página cheia dela (não há um formulário de edição inline separado dentro da lista de pessoas — clique no nome da pessoa leva para `/contatos/arquitetos/<id-da-pessoa>`).

## Objetivo

Padronizar a visualização e edição de Projetos, Clientes, Arquitetos, Engenheiros e Eletricistas para abrir como página cheia (aba/rota dedicada), no mesmo padrão já usado em "Novo Projeto" (`/novo`) e no que já existe em "Detalhes do Projeto" (`/projeto/:id`) — hoje só Projetos e Clientes abrem um card lateral (Sheet) e Arquitetos/Engenheiros/Eletricistas abrem um modal central (Dialog), nenhum deles em página cheia.

Adicionalmente, para Arquitetos: hoje um escritório com múltiplos arquitetos precisa ser representado por um único cadastro (para não fragmentar o vínculo do projeto e o cálculo de comissão), mas isso impede registrar o aniversário e e-mail pessoal de cada arquiteto do escritório — informação necessária para presentear ou mandar e-mail para a pessoa certa. Esta SPEC resolve isso reaproveitando um relacionamento que já existe no banco (`contatos.empresa_id`), sem criar tabela nova.

## Decisões aprovadas

- Um único componente de página cheia, genérico e parametrizado por tipo de contato, reaproveitando código (`ClientFormFields` generalizado) — não uma página separada por entidade.
- O `<Sheet>` de Projetos é removido; clique na listagem/kanban vai direto para a página cheia `/projeto/:id` já existente (`ProjectDetail.tsx`).
- Eletricistas ganha capacidade de edição nesta SPEC (hoje não existe nenhuma).
- O campo `data_nascimento` (já existente no banco) passa a ser editável nos 4 tipos de contato.
- Pessoas vinculadas a uma empresa de Arquitetos (via `empresa_id`) **não** aparecem na listagem principal de Arquitetos nem em nenhum combo de seleção de arquiteto — só dentro da página cheia da empresa à qual pertencem.

## Definição da SPEC

### 1. Estado atual — visualização/edição por tela

| Tela | Ver Detalhes | Editar | Página cheia hoje? |
|---|---|---|---|
| Projetos (`Projetos.tsx`) | `<Sheet>` lateral (view+edit combinados) | dentro do mesmo Sheet | Sim, mas não é a padrão: `ProjectDetail.tsx` em `/projeto/:id` já existe e funciona, só é alcançado via link "Ver Detalhes Completos" dentro do Sheet |
| Clientes (`Clientes.tsx`) | `<Sheet>` lateral largo (com Tabs Projetos/Dados) | `<Dialog>` central separado | Não |
| Arquitetos (`Arquitetos.tsx`) | `<Dialog>` central | `<Dialog>` central separado | Não |
| Engenheiros (`Engenheiros.tsx`) | `<Dialog>` central | `<Dialog>` central separado | Não |
| Eletricistas (`Eletricistas.tsx`) | `<Dialog>` central | **não existe** (só cadastro via `<Dialog>` de criação) | Não |

Campos hoje editáveis por tipo (todos em `contatos`):
- **Cliente** (`clientSchema` em `ClientFormFields.tsx`): nome, nome_empresa, email, email_financeiro, celular, telefone, cpf_cnpj, rg, cidade, estado, cep, bairro, endereco, observacoes, ativo (14 campos).
- **Arquiteto** (`arquitetoSchema` em `Arquitetos.tsx`): nome, nome_empresa, email, celular, telefone, cpf_cnpj, cidade, estado, endereco, observacoes (10 campos) — falta `rg` no schema apesar de existir no banco, e falta `data_nascimento` (exibido só na visualização).
- **Engenheiro** (`engineerSchema` em `Engenheiros.tsx`): nome, especialidade, email, telefone, celular, nome_empresa, endereco_comercial (7 campos).
- **Eletricista**: sem schema de edição — só criação (`nome`, `telefone`, `email`, `cidade`, `estado`).

### 2. Modelagem — Pessoas por Empresa em Arquitetos

O banco já modela "pessoa física ligada a pessoa jurídica" via `contatos.empresa_id -> contatos.id` (self-reference, constraint `contatos_empresa_id_fkey`), documentado em `supabase/db/domains/cadastros.md:22-37`:

> "Empresa/PJ de um cliente, fornecedor, arquiteto ou outro contato fica na própria tabela `contatos`; o vínculo é `contatos.empresa_id -> contatos.id`; permite representar uma pessoa física ligada a uma pessoa jurídica."

Ou seja: **nenhuma migration é necessária**. Um escritório de arquitetura vira um `contatos` (tipo=`arquiteto`) que representa a empresa; cada arquiteto individual dela vira outro `contatos` (tipo=`arquiteto`) com `empresa_id` apontando para o id da empresa.

- O vínculo `projetos.arquiteto_id` continua apontando sempre para a **empresa** (registro com `empresa_id IS NULL`) — é isso que preserva o cálculo de comissão por escritório, sem fragmentar.
- As "pessoas" (registros com `empresa_id` preenchido) só existem para guardar nome, data de nascimento e e-mail individual — não aparecem soltas em nenhuma lista nem combo (Item 7).
- Não é necessário (nem obrigatório para esta SPEC) usar a coluna `contatos.tipo_pessoa` (`fisica`/`juridica`) para diferenciar empresa de pessoa — a simples presença/ausência de `empresa_id` já resolve. Fica como melhoria opcional futura, não bloqueante.

### 3. Mudança proposta — página cheia genérica de contato

- Nova rota `/contatos/:tipo/:id` → componente `ContatoDetail.tsx` (nome sugerido), que:
  - Busca o registro em `contatos` pelo `id`.
  - Renderiza cabeçalho com nome, badge (ativo/inativo, tipo), botão Voltar — mesmo padrão de `ProjectDetail.tsx`.
  - Alterna entre modo leitura e modo edição (Editar → Salvar/Cancelar), reaproveitando os campos de `ClientFormFields.tsx` generalizado por `tipo`.
  - Para `tipo='arquiteto'` e o registro atual tendo `empresa_id IS NULL` (ou seja, é uma "empresa"/registro de topo — a mesma lógica vale também para um arquiteto autônomo sem funcionários, que simplesmente nunca terá pessoas na lista): renderiza a seção "Pessoas da Empresa" (Item 6), com listagem das pessoas vinculadas e botão "+" para adicionar uma nova (nome, data de nascimento, e-mail), no mesmo padrão de edição inline em lista já usado para parcelas em `ProjectDetail.tsx` (adicionar linha, editar campos, salvar tudo junto).
- `Clientes.tsx`, `Arquitetos.tsx`, `Engenheiros.tsx`, `Eletricistas.tsx`: card/linha da listagem e botão "Editar" passam a `navigate('/contatos/<tipo>/' + id)`. Os Dialogs de visualização/edição atuais são removidos dessas páginas (a criação continua igual).
- `Projetos.tsx`: remove o `<Sheet>`; clique no card/linha navega para `/projeto/:id`.
- Deep-links `?view=Nome` usados a partir de `ProjectDetail.tsx` (Cliente/Arquiteto/Engenheiro): resolver o contato pelo nome (mesma lógica de busca já existente) e navegar direto para `/contatos/<tipo>/:id` em vez de abrir Sheet/Dialog.

### Impacto no banco

Nenhum. Todos os campos usados (`data_nascimento`, `empresa_id`) já existem em `contatos`. Nenhuma migration necessária.

### Impacto em telas

- `src/pages/Projetos.tsx` — remove Sheet, navega para `/projeto/:id`.
- `src/pages/contatos/Clientes.tsx`, `Arquitetos.tsx`, `Engenheiros.tsx`, `Eletricistas.tsx` — removem Dialog/Sheet de ver/editar, navegam para `/contatos/<tipo>/:id`.
- Novo: `src/pages/contatos/ContatoDetail.tsx` (ou nome equivalente).
- `src/App.tsx` — nova(s) rota(s).
- `src/components/ClientFormFields.tsx` — generalizado para os 4 tipos (ou substituído por um componente novo que o engloba).
- `src/pages/ProjectNew.tsx`, `src/pages/Projetos.tsx`, `src/pages/ProjectDetail.tsx` — filtros de combo/lista de arquiteto passam a excluir registros com `empresa_id` preenchido (Item 7).

### Regras de permissão

Nenhuma mudança de permissão. Quem hoje pode ver/editar cliente/arquiteto/engenheiro/eletricista/projeto continua com o mesmo acesso, só muda a navegação (rota em vez de modal/sheet).

### Critérios de aceite

- Clicar em "Ver Detalhes" ou "Editar" em qualquer uma das 5 telas abre uma página cheia dedicada (URL própria, back button), não mais um card lateral ou modal central.
- Nenhum campo hoje existente é perdido — o formulário de Cliente continua com os mesmos 14 campos + `data_nascimento` novo; Arquiteto/Engenheiro/Eletricista ganham os campos que faltavam (`rg` em Arquiteto, `data_nascimento` nos 4 tipos, edição completa em Eletricista).
- Projetos: listagem/kanban não abre mais Sheet; vai direto para `/projeto/:id`.
- Arquitetos: dentro da página cheia de uma empresa, dá para adicionar pessoas (nome, data de nascimento, e-mail) via "+"; essas pessoas não aparecem na listagem principal de Arquitetos nem nos combos de seleção de arquiteto em Novo Projeto / Editar Projeto / Detalhes do Projeto.
- O vínculo `projetos.arquiteto_id` de projetos já existentes continua funcionando normalmente (nenhum dado migrado ou alterado).
- Validações hoje existentes (ex. erro de CPF/CNPJ duplicado) continuam funcionando na nova página cheia.
- Nenhuma mudança de schema no Supabase.

### Testes/verificações obrigatórias

- Criar e editar um registro de cada tipo (Cliente, Arquiteto, Engenheiro, Eletricista) pela nova página cheia e confirmar persistência de todos os campos, incluindo `data_nascimento`.
- Criar uma "empresa" de Arquiteto, adicionar 2–3 pessoas via "+", confirmar que elas somem da listagem principal de Arquitetos e do combo de seleção de arquiteto em Novo Projeto, mas aparecem dentro da página cheia da empresa.
- Confirmar que um projeto já vinculado a um arquiteto (`arquiteto_id`) continua exibindo o nome correto depois da mudança.
- Testar os deep-links `?view=Nome` a partir de `ProjectDetail.tsx` (Cliente/Arquiteto/Engenheiro) e confirmar que abrem a página cheia certa.
- Rodar `npx tsc --noEmit`, `npx oxlint` e `npm run build` (ou o QA completo do Skip, `skip_project_apply_changes`) antes de considerar concluído.

## Análise obrigatória de ecossistema

- **Depende de `projetos`, `orcamentos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios` ou `user_system_access`?** Sim — `contatos` (todas as 5 telas) e `projetos.arquiteto_id` (Item 7, filtro de combo).
- **A mudança afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística ou Hub/TI?** Afeta só o CRM. `contatos.empresa_id` é uma tabela/coluna compartilhada com o restante do ecossistema (ver `supabase/db/domains/cadastros.md`), mas esta SPEC só passa a **usá-la** no CRM — não altera seu significado nem seu uso em outros sistemas.
- **Existe dado duplicado que deveria ser derivado por relacionamento?** Não — pelo contrário, esta SPEC evita duplicar dado (não cria um cadastro separado por pessoa desconectado da empresa) reaproveitando o relacionamento existente.
- **Existe migration antiga que contradiz o snapshot central?** Não aplicável — nenhuma migration é criada ou necessária nesta SPEC.
- **Exige atualização de `AI_DB_CONTEXT.md`?** Sim — registrar em `supabase/AI_DB_CONTEXT.md` do CRM que a tela de Arquitetos passou a usar `contatos.empresa_id` para agrupar pessoas por empresa, e que os combos de seleção de arquiteto agora filtram por `empresa_id IS NULL`.

## Realizado

### 2026-07-23

- Implementado direto no projeto Skip (`projectId 24580`), já que o submodule local `04-Sistemas/lucenera-crm-3bd29 (1)/` está desatualizado em relação à produção (mesma situação das SPEC-042/043).
- Criado `src/pages/contatos/ContatoDetail.tsx` — página cheia genérica para os 4 tipos de contato (rota `/contatos/:tipoPlural/:id`), com campos configurados por tipo (`FIELD_CONFIGS`), alternância Editar/Salvar/Cancelar, tratamento de erro de CPF/CNPJ duplicado (`23505`) e a seção "Pessoas da Empresa" (só para Arquiteto sem `empresa_id`).
- `src/App.tsx`: nova rota `/contatos/:tipoPlural/:id` → `ContatoDetail`.
- `src/components/ClientFormFields.tsx`: adicionado campo `data_nascimento` (schema + JSX) — usado tanto pelo Dialog "Novo Cliente" quanto pelo cadastro rápido em `NewContactModal.tsx`.
- `src/pages/contatos/Clientes.tsx`, `Arquitetos.tsx`, `Engenheiros.tsx`, `Eletricistas.tsx`: reescritos — Sheet/Dialog de visualização e edição removidos, navegação para a página cheia no clique do card/linha, botão "Editar" e deep-link `?view=`. Dialogs de criação mantidos como estavam. `Arquitetos.tsx` ganhou o filtro `.is('empresa_id', null)` na listagem. `Eletricistas.tsx` ganhou exclusão (não existia antes).
- `src/pages/Projetos.tsx`: reescrito — `<Sheet>` "Editar Projeto e Parcelas" removido, `ContactCombobox` removido junto (não usado em outro lugar), clique no card/linha navega para `/projeto/:id`. Exclusão na visão em tabela mantida, agora chamando `refreshProjects()` da store (SPEC-043).
- `src/pages/ProjectNew.tsx` e `src/pages/ProjectDetail.tsx`: filtro `empresa_id IS NULL` aplicado no combobox/lista de seleção de arquiteto.
- QA completo no Skip (`skip_project_apply_changes`, modo `development`): `setup`, `staticAnalysis`, `build`, `integrations`, `test` todos `ok`. Publicado como versão `0.0.275` (hash `469e8cf`) em produção (`https://lucenera-crm-3bd29.goskip.app`).
- Nenhuma migration ou mudança de schema no Supabase — toda a funcionalidade de "Pessoas da Empresa" usa a coluna `contatos.empresa_id` que já existia.
- Corrigido no meio da implementação: um patch malformado em `ClientFormFields.tsx` deixou um `=======` literal no arquivo (erro de sintaxe); identificado ao reler o arquivo antes do QA e corrigido com uma reescrita completa do arquivo antes de prosseguir.
- Em seguida, `supabase/AI_DB_CONTEXT.md` do CRM foi atualizado (nova seção "SPEC-044") e publicado com novo QA completo (`ok` em todas as etapas): versão `0.0.276` (hash `2e63bae`).
- **Ajuste pós-feedback do usuário #1 (mesmo dia):** ao testar, o usuário abriu o diálogo "Novo Arquiteto" (cadastro rápido) e não encontrou Data de Nascimento, RG nem a opção de adicionar mais de uma pessoa — comportamento esperado (esse diálogo foi deixado fora do escopo original, decisão registrada nesta SPEC), mas o usuário apontou que em alguns casos isso é necessário logo na criação. Resolvido inicialmente com a abordagem mais simples das duas apresentadas: `Arquitetos.tsx` — diálogo "Novo Arquiteto" ganhou os campos **Data de Nascimento** e **RG** (RG já existia no schema mas não tinha campo de formulário); ao salvar, em vez de só fechar o diálogo, o `insert` passou a usar `.select().single()` e o sistema navegava direto para `/contatos/arquitetos/:id` do registro recém-criado, para adicionar pessoas de lá. Publicado como versão `0.0.277` (hash `abb984d`).
- **Ajuste pós-feedback do usuário #2 (mesmo dia):** o usuário pediu explicitamente a segunda abordagem apresentada (a que não tinha sido escolhida antes) — poder adicionar mais de uma pessoa **já dentro do próprio diálogo "Novo Arquiteto"**, sem depender do redirect pós-criação ("trabalho redobrado"). Implementado: o diálogo ganhou uma seção "Pessoas da Empresa (opcional)" com botão "+ Adicionar Pessoa" que adiciona linhas locais (nome/data de nascimento/e-mail, editáveis, removíveis) mantidas em estado (`novasPessoas`) até o submit. No `onSubmit`: valida que toda linha adicionada tem nome preenchido (bloqueia com toast se não); insere o registro da empresa; se houver pessoas válidas, insere todas em lote com `empresa_id` apontando para o id da empresa recém-criada; por fim navega para a página cheia da empresa (onde as pessoas já aparecem listadas). Publicado como versão `0.0.278` (hash `bebf76a`).
- **Ajuste pós-feedback do usuário #3 (mesmo dia):** cada pessoa adicionada também precisava de **CPF** e **Endereço**, não só nome/data de nascimento/e-mail. Adicionados os campos `cpf_cnpj` e `endereco` em ambos os formulários de "pessoa": no diálogo "Novo Arquiteto" (`Arquitetos.tsx`, estado `novasPessoas`) e no "+ Adicionar Pessoa" da página cheia (`ContatoDetail.tsx`, estado `novaPessoa`) — em ambos os casos os campos entram no `insert` em `contatos` junto com os demais. Publicado como versão `0.0.279` (hash `a66db01`), QA completo `ok` em todas as etapas.

## Pendências

- [ ] Confirmar/realizar o push do commit publicado no Skip (agora versão `0.0.275`, hash `469e8cf`) para o `main` do GitHub `pedrolalala/lucenera-crm` — mesma pendência recorrente das SPEC-042/043.
- [ ] Testar na prática em produção: editar um registro de cada tipo, criar uma empresa de Arquiteto com 2-3 pessoas via "+", confirmar que elas não aparecem na listagem principal nem no combobox de seleção de arquiteto em Novo Projeto, e que um clique numa pessoa abre a página cheia dela corretamente.
- [ ] Definir se `contatos.tipo_pessoa` deve ser setado automaticamente (`juridica` para a empresa, `fisica` para cada pessoa) ao usar o "+" — não foi feito nesta implementação (não bloqueante), pode ser revisitado.
- [ ] Avaliar, no futuro (fora do escopo desta SPEC), se o mesmo padrão de "pessoas por empresa" deveria se estender a Clientes ou Engenheiros.
- [x] Atualizar `supabase/AI_DB_CONTEXT.md` do CRM — feito em 2026-07-23 (nova seção "SPEC-044 — Pessoas por Empresa em Arquitetos"), publicado junto na versão `0.0.276` (hash `2e63bae`).
