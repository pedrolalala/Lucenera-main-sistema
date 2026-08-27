---
titulo: "SPEC-045 — CRM: Card de Link do SharePoint no Detalhe do Projeto"
status: concluído
data_ultima_modificacao: 2026-07-24
sistemas_envolvidos:
  - CRM (lucenera-crm)
---

# SPEC-045 — CRM: Card de Link do SharePoint no Detalhe do Projeto

> Preencher o frontmatter acima antes de escrever o resto. `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Nota sobre origem do código

O sistema **CRM** está registrado como submodule em `04-Sistemas/lucenera-crm-3bd29 (1)/`, mas esse submodule está desatualizado em relação à produção (mesma situação das SPEC-042/043/044). Implementação feita direto no projeto Skip "Lucenera CRM" (`projectId 24580`).

## Checklist de Ação

- [x] Item 1 — Coluna `projetos.link_sharepoint` (text, nullable) adicionada e aplicada no Supabase real via migration `supabase/db/migrations/20260724_061_link_sharepoint_projeto/` (`up.sql`/`down.sql`).
- [x] Item 2 — `src/pages/ProjectDetail.tsx`: novo card "Link do SharePoint" adicionado logo após o grid "Informações Gerais"/"Responsáveis" e antes de "Itens Aprovados do Projeto". Leitura mostra link clicável (abre em nova aba) ou "Nenhum link do SharePoint cadastrado ainda."; edição mostra `<Input type="url">` dentro do mesmo toggle Editar/Salvar/Cancelar já existente.
- [x] Item 3 — `link_sharepoint` incluído no payload de `handleSave`.
- [x] Item 4 — `supabase/db/domains/crm.md` (repo central) e `supabase/AI_DB_CONTEXT.md` do CRM atualizados.

### Passos manuais do usuário

- [ ] Preencher o link da pasta raiz do SharePoint em cada projeto existente (a coluna nasce vazia — não há como popular retroativamente sem uma lista dos links reais).
- [ ] Confirmar que o link salvo abre corretamente a pasta certa no SharePoint (teste com pelo menos 1 projeto real).

## Objetivo

O chefe quer acompanhar os projetos de perto, mas hoje o CRM só tem os dados que estão no Supabase — as informações que vivem no SharePoint (pasta do projeto com subpastas WhatsApp, Projetos, Originais, Orçamentos, Fotos, Email, DocuSign) não têm nenhum vínculo com o sistema. Esta SPEC adiciona um campo simples no projeto para guardar o link da pasta raiz do SharePoint daquele projeto específico, editável na mesma tela onde já se edita o projeto, para que qualquer pessoa consiga ir direto da ficha do projeto no CRM para a pasta correspondente no SharePoint.

## Decisões aprovadas

- Guardar apenas o **link da pasta raiz** do projeto no SharePoint (não as subpastas individualmente, não uma sincronização de conteúdo) — o usuário confirmou que a estrutura de subpastas (WhatsApp, Projetos, Originais, Orçamentos, Fotos, Email, DocuSign) é padronizada para todo projeto, então um único link para a pasta raiz já dá acesso a tudo.
- Editável no mesmo fluxo Editar/Salvar/Cancelar que já existe em `ProjectDetail.tsx` — não é um card/modal separado com seu próprio botão de salvar.
- Não confundir com a Edge Function `sync-sharepoint` já existente no projeto (que sincroniza LISTAS do SharePoint de um site diferente, `LUCENERAPROJETOS345`, para preencher `projetos`/`tabela_precos` em massa) — são funcionalidades independentes; esta SPEC não usa nem altera essa function.

## Definição da SPEC

### 1. Banco de dados

Nova coluna, puramente aditiva, sem impacto em dado existente:

```sql
ALTER TABLE public.projetos
  ADD COLUMN IF NOT EXISTS link_sharepoint text;

COMMENT ON COLUMN public.projetos.link_sharepoint IS
  'Link da pasta raiz do projeto no SharePoint (contém subpastas padrão: WhatsApp, Projetos, Originais, Orçamentos, Fotos, Email, DocuSign). Preenchido manualmente pelo usuário no CRM — não é sincronizado automaticamente.';
```

Migration em `supabase/db/migrations/20260724_061_link_sharepoint_projeto/`.

### 2. Frontend — `ProjectDetail.tsx`

- Novo card, mesmo padrão visual dos outros (`Card`/`CardHeader`/`CardTitle`/`CardContent`), título "Link do SharePoint", ícone de pasta/link.
- Modo leitura: se `projeto.link_sharepoint` preenchido, mostra um link (`<a target="_blank" rel="noopener noreferrer">`) com texto tipo "Abrir pasta no SharePoint" + ícone de link externo; se vazio, mostra texto discreto "Nenhum link cadastrado ainda".
- Modo edição: `<Input type="url">` vinculado a `editForm.link_sharepoint`, com placeholder indicando o formato esperado (ex.: `https://lucenera.sharepoint.com/sites/...`).
- `handleSave`: incluir `link_sharepoint: editForm.link_sharepoint || null` no payload de `updateProjetoById`.
- Posição do card: logo abaixo do grid "Informações Gerais"/"Responsáveis" e acima de "Itens Aprovados do Projeto" — primeiro card de conteúdo adicional, como pedido pelo usuário.

### Impacto no banco

Uma coluna nova (`projetos.link_sharepoint`), nullable, sem default além de `NULL`. Não afeta nenhuma query, view, RPC ou trigger existente.

### Impacto em telas

Só `ProjectDetail.tsx` (`/projeto/:id`). Nenhuma outra tela lista ou usa esse campo.

### Regras de permissão

Nenhuma mudança — segue a mesma permissão de quem já pode editar projeto.

### Critérios de aceite

- Card "Link do SharePoint" aparece na página cheia de qualquer projeto, entre as informações gerais e "Itens Aprovados do Projeto".
- Ao clicar em "Editar Projeto", o campo de link fica editável junto com os demais campos.
- Salvar persiste o valor em `projetos.link_sharepoint`; recarregar a página mostra o valor salvo.
- Link vazio não quebra a tela (mostra estado "sem link", não um link quebrado).
- Clicar no link abre a pasta do SharePoint em nova aba.

### Testes/verificações obrigatórias

- Editar um projeto real, colar um link de SharePoint válido, salvar, recarregar e conferir que persiste.
- Confirmar que projetos sem link continuam abrindo normalmente (sem erro).
- QA completo do Skip (`skip_project_apply_changes`) antes de publicar.

## Análise obrigatória de ecossistema

- **Depende de `projetos`, `orcamentos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios` ou `user_system_access`?** Sim — `projetos`, tabela já usada por CRM/Orçamentos/Financeiro/Estoque.
- **A mudança afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística ou Hub/TI?** Só o CRM lê/escreve esse campo. Como `projetos` é compartilhada, a coluna nova fica visível para os outros sistemas também, mas nenhum outro sistema precisa fazer nada com ela.
- **Existe dado duplicado que deveria ser derivado por relacionamento?** Não.
- **Existe migration antiga que contradiz o snapshot central?** Não aplicável.
- **Exige atualização de `AI_DB_CONTEXT.md`?** Sim — do CRM, e do domínio `supabase/db/domains/crm.md` no repo central.

## Realizado

### 2026-07-24

- Migration `20260724_061_link_sharepoint_projeto` (só `ALTER TABLE ... ADD COLUMN IF NOT EXISTS link_sharepoint text` + `COMMENT ON COLUMN`) aplicada diretamente no Supabase real via script Python (`psycopg2` + `SUPABASE_DB_URL` do `.env`), com autorização explícita do usuário — a primeira tentativa de rodar o script foi bloqueada automaticamente pelo classificador de segurança do Claude Code (ação de escrita direta em infraestrutura compartilhada); o usuário confirmou e autorizou antes da segunda tentativa, que aplicou com sucesso (`information_schema` conferido: `link_sharepoint | text | nullable`).
- `src/pages/ProjectDetail.tsx` (Skip, `projectId 24580`): novo card "Link do SharePoint", `link_sharepoint` incluído no payload de save.
- **Limitação registrada**: `src/lib/supabase/types.ts` (tipos gerados do Supabase) não foi atualizado com a coluna nova — o arquivo excede o limite de tamanho da ferramenta de patch (256.000 bytes) usada nesta sessão. Contornado com casts `as any` nos pontos onde `link_sharepoint` é lido/escrito em `ProjectDetail.tsx`, seguindo o mesmo padrão já usado no código para `get_dashboard_stats` (RPC sem tipo gerado). Documentado em `supabase/AI_DB_CONTEXT.md` do CRM para não ser esquecido caso o types.ts seja regerado no futuro.
- `supabase/db/domains/crm.md` (repo central) e `supabase/AI_DB_CONTEXT.md` (CRM) atualizados.
- QA completo `ok` em dois ciclos (código + doc), publicado como versão `0.0.284` (hash `c590768`) em produção (`https://lucenera-crm-3bd29.goskip.app`).

## Pendências

- [ ] Preencher o link real de cada projeto existente no SharePoint (não há import automático — ver "Passos manuais do usuário").
- [ ] Confirmar/realizar o push do commit publicado no Skip para o `main` do GitHub `pedrolalala/lucenera-crm` — mesma pendência recorrente das SPECs anteriores.
- [ ] Se `src/lib/supabase/types.ts` for regerado no futuro (ex.: via Supabase CLI `gen types`), remover os casts `as any` de `link_sharepoint` em `ProjectDetail.tsx`, já que o tipo passará a incluir a coluna nativamente.
