---
titulo: "SPEC-134 — Memória Lucenera: campo Código do Projeto em todos os formulários de adicionar informação"
status: concluído
data_ultima_modificacao: 2026-09-11
sistemas_envolvidos:
  - Memória Lucenera (Skip projectId 57204)
---

# SPEC-134 — Memória Lucenera: campo Código do Projeto em todos os formulários de adicionar informação

## Checklist de Ação

- [x] Migration `memoria.*` — coluna `project_code text` em `entities`, `knowledge_items`, `experiences`, `decisions`, `projects`, `sources`, `inbox_items` + índice parcial por tabela.
- [x] Migration aplicada no Supabase real (confirmado via `information_schema.columns`).
- [x] Frontend (`public/app/app.js`, Skip 57204): campo "Código do Projeto" nos 6 formulários genéricos (Entidade, Conhecimento, Experiência, Decisão, Projeto, Fonte) via `fields{}`.
- [x] Frontend: campo no formulário rápido de captura (`inboxForm`, botão "Nova captura" / "✎ Escrever" / "↗ Adicionar link").
- [x] Frontend: campo exibido no card "Informações" da tela de detalhe de qualquer registro.
- [x] Frontend: campo no formulário de revisão da memória por voz (`openVoiceReview` → `saveVoiceMemoryToSupabase`), gravado tanto no `inbox_items` quanto no `knowledge_items` gerado.
- [x] Frontend (`public/app/supabase-adapter.js`): campo no formulário de envio de arquivo (`fileForm`); valor herdado automaticamente ao "Organizar material" (transformar item da caixa de entrada em registro estruturado).
- [x] QA do Skip verde (setup/static/build/integrations/test) e publicado em produção (`memoria-lucenera-2e074.goskip.app`, versão 0.0.8 / `cc8afcf`).
- [x] `supabase/db/domains/memoria.md` atualizado.

### Passos manuais do usuário

- Nenhum. Migration já aplicada no banco real e app já publicado em produção.

## Objetivo

O usuário pediu para que **todo formulário de adicionar informação** na Memória Lucenera (SPEC-129) ganhasse um campo de texto livre para o **código do projeto Lucenera** (ex.: `26.181`), para depois ser mais fácil filtrar/achar memórias ligadas a um projeto específico.

## Decisões aprovadas

- `project_code` é **texto livre**, sem FK para `public.projetos` — mantém a regra de isolamento do domínio `memoria` ("nenhum objeto cruza para `public`", ver `supabase/db/domains/memoria.md`). O vínculo é só por convenção de digitação do código.
- Não confundir com o campo "Projeto" já existente na Memória Lucenera (`memoria.projects`, um tipo de registro interno do Filippo — ex.: "Base de Conhecimento Pessoal"). São conceitos diferentes: `project_code` referencia o projeto **operacional Lucenera**, o outro é um registro de conhecimento pessoal do próprio app.
- A busca global (`runSearch`/`filterList`) já faz *full-text* sobre `JSON.stringify(registro)`, então qualquer `project_code` preenchido já fica pesquisável digitando o código na caixa "Pesquisar" — não foi criado filtro dedicado por não ter sido pedido e para não aumentar o escopo.

## Definição da SPEC

### Estado antes

`memoria-lucenera` (Skip 57204) é um app estático (`public/app/*.js`) carregado dentro de um shell React vazio; **o código real não está no submodule Git** `04-Sistemas/memoria-lucenera` (esse submodule só tem o shell/scaffold, registrado nesta mesma sessão). Editar é feito direto na working tree do Skip, como já documentado para outros sistemas.

Havia 6 tipos de registro com formulário genérico dirigido por um objeto `fields{}` em `app.js` (entidades, conhecimentos, experiências, decisões, projetos, fontes), mais 3 fluxos de captura com HTML próprio: captura rápida (`inboxForm`), upload de arquivo (`fileForm`, sobrescrito em `supabase-adapter.js` para gravar em Supabase de verdade) e revisão de memória por voz (`openVoiceReview`/`saveVoiceMemoryToSupabase`). Nenhum desses tinha campo de código de projeto.

### Banco (schema `memoria`, aplicado)

```sql
alter table memoria.<tabela> add column if not exists project_code text;
-- + índice parcial memoria.<tabela>_project_code_idx where project_code is not null
```
Tabelas: `entities`, `knowledge_items`, `experiences`, `decisions`, `projects`, `sources`, `inbox_items`.

Migration: `supabase/db/migrations/20260911_134_memoria_lucenera_project_code/01_add_project_code.sql`.

### Frontend

- `fields{}` (app.js): adicionado `['project_code','Código do Projeto','text']` em cada um dos 6 tipos, logo antes do campo `visibility` — aparece automaticamente em Criar **e** Editar (mesmo `openForm`), pois o formulário é gerado dinamicamente a partir desse array.
- `inboxForm` (app.js): novo `<label>Código do Projeto<input name="project_code">` — o `onsubmit` já espalha todos os campos do form (`...a`), sem precisar de lógica extra.
- `detail()` (app.js): card "Informações" passa a mostrar `Código do Projeto` junto de Categoria/Subcategoria/Status — cobre todos os tipos, inclusive `inbox_items`.
- `openVoiceReview` (app.js, a versão realmente usada — havia uma 1ª declaração de mesmo nome, código morto, sobrescrita por redeclaração; não foi tocada) + `saveVoiceMemoryToSupabase`: novo campo no formulário de revisão; valor gravado tanto no `inbox_items` quanto no `knowledge_items` criado a partir da gravação de voz.
- `window.fileForm` (supabase-adapter.js — versão que roda de verdade, sobrescreve a de `app.js`): novo campo; valor gravado no `inbox_items` resultante do upload.
- `window.organize` (supabase-adapter.js): ao transformar um item da caixa de entrada em registro estruturado, o `project_code` do item original é herdado no formulário de criação.

### Por que não foi criado filtro dedicado de busca

A pesquisa global já casa contra o JSON inteiro do registro (`JSON.stringify(x).toLowerCase().includes(q)`), então digitar o código do projeto na caixa "Pesquisar" (ou no filtro de texto de cada lista) já encontra tudo que tiver aquele código — o pedido do usuário ("ficar mais fácil de buscar") já fica atendido só com o campo existindo e sendo salvo. Criar um filtro dedicado (dropdown/coluna na tabela) não foi pedido; fica como possível melhoria futura se o uso mostrar necessidade.

## Realizado

### 2026-09-11

- Migration criada e aplicada no Supabase real (7 colunas + 7 índices, confirmado por consulta a `information_schema.columns`).
- `public/app/app.js` e `public/app/supabase-adapter.js` (Skip 57204) editados via `skip_file_patch` (11 + 3 blocos).
- `skip_project_apply_changes` → QA 100% verde → `skip_project_publish` → produção em `memoria-lucenera-2e074.goskip.app`, versão `0.0.8` (`cc8afcf`).
- Sem teste ao vivo no navegador (login/SSO da Memória Lucenera segue não testado ao vivo desde a SPEC-129 — ver pendência lá). Validação feita por: QA automático do Skip (setup/lint/build/test) verde + releitura de cada arquivo publicado confirmando literalmente os 14 pontos de inserção do `project_code`.

## Pendências

- [ ] Teste manual ao vivo no navegador (criar um registro de cada tipo com Código do Projeto preenchido e confirmar que persiste/aparece na busca) — mesma pendência de teste-SSO-ao-vivo já registrada na SPEC-129, ainda não resolvida.
