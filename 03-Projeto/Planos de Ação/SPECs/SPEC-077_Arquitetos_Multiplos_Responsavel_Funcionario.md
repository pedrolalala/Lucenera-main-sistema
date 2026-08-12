# SPEC-077: Arquitetos Múltiplos com % + Responsável Vinculado a Funcionários

**Data:** 2026-08-11
**Sistemas:** CRM (`lucenera-crm-3bd29`, Skip projectId `24580`) + Orçamentos (`gestao-financeira-clone-544cb`, Skip projectId `32554`)
**Status:** Publicado em produção (CRM v0.0.299, hash `761f086`; Orçamentos v0.0.313, hash `0f15c81`)

## Pedido do usuário

Tarefa formal ("Reestruturar campos de projeto no CRM — responsável vinculado a funcionários e arquitetos múltiplos"), resumida:

- Campo "Responsável" deve ser FK real para uma entidade "Funcionários" (criar se não existir), dropdown só ativos, permitir cadastro inline sem sair da tela.
- Campo "Arquiteto" (projeto **e** orçamento) vira seleção múltipla com percentual de participação por arquiteto; soma validada como 100% antes de salvar; percentual editável individualmente.
- Regras de validação: não salvar projeto sem responsável; não salvar sem pelo menos 1 arquiteto; soma de percentuais = 100%; sem arquiteto duplicado no mesmo projeto.
- Interface: percentual ao lado de cada arquiteto, soma calculada em tempo real, botão salvar desabilitado se soma ≠ 100%, busca/typeahead nos dropdowns.
- Instrução explícita do usuário: responder 7 perguntas de escopo antes de codar.

## Perguntas de escopo — respostas

3 das 7 perguntas foram respondidas por investigação direta (sem redundância com o usuário): `funcionarios` já existe (não precisou ser criada); módulo de orçamento já existe e tem campo Arquiteto próprio; não existe cálculo de comissão hoje que dependa de `arquiteto_id` (`vw_comissao_mensal` não usa essa coluna).

As demais foram perguntadas via `AskUserQuestion` e respondidas pelo usuário:

- **Quais papéis participam da divisão de lucro por percentual?** → Só Arquiteto. Engenheiro (`responsavel_obra_id`) e Responsável continuam vínculo simples, sem percentual.
- **Um projeto pode ter mais de um Responsável?** → Não, só um responsável principal — continua seleção única, só que vinculada a `funcionarios` em vez de texto livre.

## Achado crítico que mudou o desenho

`projetos.responsavel_nome` (texto livre) não é só um label de exibição — um trigger (`fn_sync_equipe_por_responsavel`, `BEFORE UPDATE OF responsavel_nome`) usa esse texto para resolver a "equipe" do projeto em `equipes_projetos`, que por sua vez alimenta o cálculo de comissão (`vw_comissao_mensal`). A cláusula `OF responsavel_nome` só dispara quando essa coluna aparece explicitamente na lista de colunas do `INSERT`/`UPDATE` da query original — um trigger encadeado que setasse `NEW.responsavel_nome` por trás do novo campo FK não contaria.

**Solução adotada:** o frontend sempre grava os dois campos juntos, no mesmo `INSERT`/`UPDATE` — `responsavel_funcionario_id` (novo, FK real) e `responsavel_nome` (nome do funcionário selecionado no dropdown, preenchido pelo frontend, não mais digitado à mão). Sem trigger novo.

`projetos.responsavel_id` (FK morta para `usuarios`, sempre `NULL` na prática — só 4 valores distintos em 2168/3702 linhas) foi deixado intocado: não repurposed, não removido, risco desnecessário para um mecanismo legado pouco entendido.

## Estrutura de dados

Migrations `supabase/db/migrations/20260811_100_arquitetos_multiplos_responsavel_funcionario/` (5 arquivos, todas aditivas):

- **`001_tabelas_arquitetos_split.sql`** — `projeto_arquitetos` (`projeto_id` FK `projetos(id) ON DELETE CASCADE`, `arquiteto_id` FK `contatos(id)`, `percentual numeric(5,2) CHECK (percentual > 0 AND percentual <= 100)`, `UNIQUE(projeto_id, arquiteto_id)`) e `orcamento_arquitetos` (mesmo desenho, `orcamento_id` FK `orcamentos(id)`). RLS habilitado, só `SELECT` para `authenticated` — escrita exclusiva via RPC.
- **`002_projetos_responsavel_funcionario.sql`** — `projetos.responsavel_funcionario_id` (FK `funcionarios(id) ON DELETE SET NULL`) + índice. Sem trigger novo.
- **`003_rpc_replace_projeto_arquitetos.sql`** — `replace_projeto_arquitetos(p_projeto_id, p_arquitetos jsonb)`, `SECURITY DEFINER`. Guard: `role IN ('admin','gerente','operador') OR hub_pode_executar('crm', NULL, 'editar')` (mesmo bar de `projetos_update`). Valida sem duplicata e soma=100% (só quando array não vazio). Delete+insert atômico (mesmo molde de `replace_orcamento_itens`), depois sincroniza `projetos.arquiteto_id` com o arquiteto de maior percentual (desempate por ordem de inserção).
- **`004_rpc_replace_orcamento_arquitetos.sql`** — mesmo desenho, guard `hub_pode_executar('orcamentos', NULL, 'editar')`.
- **`005_backfill_arquitetos_por_status_atual.sql`** — migra `arquiteto_id` singular existente para a tabela de junção (100% cada). Resultado real: 2272 projetos, 20 orçamentos.

Backfill de `responsavel_funcionario_id` a partir de `responsavel_nome` (~15 nomes distintos, só primeiro nome) **não foi automatizado** — ambíguo demais para confiar cegamente; fica como revisão manual futura, fora do escopo desta SPEC.

## Bug de segurança encontrado e corrigido (smoke-test)

`replace_projeto_arquitetos` tinha `IF NOT (v_user_role IN ('admin','gerente','operador') OR hub_pode_executar(...)) THEN RAISE EXCEPTION`. Quando `v_user_role` é SQL `NULL` (sessão sem `auth.uid()` válido — ex.: teste direto via `psql`), `NULL OR false` avalia para `NULL`, `NOT NULL` também é `NULL`, e `IF NULL THEN` é tratado como falso pelo PL/pgSQL — a exceção esperada era silenciosamente pulada, permitindo a operação sem autorização.

Descoberto testando a RPC com um UUID falso (sem contexto de usuário válido) antes de confiar nela — o resultado esperado era "Permissão negada", mas chegou até "Projeto não encontrado", revelando o bypass. Corrigido envolvendo a expressão inteira em `COALESCE(..., false)`. A RPC irmã (`replace_orcamento_arquitetos`, um único `hub_pode_executar()` sem `OR` com `IN`) não tinha esse problema — foi o que despertou a suspeita da assimetria.

## Obrigatoriedade

A tarefa original pediu explicitamente que projeto não possa ser salvo sem responsável nem sem pelo menos 1 arquiteto — implementado literalmente no CRM (`salvar-projeto/index.ts` valida `responsavel_funcionario_id`; `ProjectDetail.tsx`/`ProjectNew.tsx` validam ≥1 arquiteto e soma=100% antes de salvar). Isso é uma mudança de comportamento real: antes os dois campos eram opcionais (1430/3702 projetos não tinham arquiteto). Afeta só criação/edição daqui pra frente, não mexe em dado histórico.

Em Orçamentos, arquiteto **continua opcional** — a tarefa não pedia esse requisito ali, e o dado real confirma (só 20 de muitos orçamentos tinham arquiteto preenchido). A validação de soma=100% só roda quando o array não está vazio.

## Frontend

### CRM (7 arquivos)

- `src/hooks/use-auth.tsx` — contexto ganhou `role`.
- `src/components/ArchitectSplitPicker.tsx` (novo) — Popover+Command com busca ao vivo debounced em `contatos` (`tipo='arquiteto' AND empresa_id IS NULL`, filtro SPEC-044); redistribui percentuais igualmente a cada adição/remoção; usuário edita à mão depois se quiser desigual.
- `src/components/NewEmployeeModal.tsx` (novo) — cadastro inline de funcionário (nome/cargo/email/status/data_admissao), checagem de duplicata client-side, tratamento de erro de RLS.
- `src/services/projetos.ts` — embeds novos (`projeto_arquitetos`, `responsavel_funcionario`), `replaceProjetoArquitetos()`.
- `supabase/functions/salvar-projeto/index.ts` — aceita e exige `responsavel_funcionario_id`.
- `src/pages/ProjectNew.tsx` — combobox de funcionários + botão "Novo Funcionário"; `ArchitectSplitPicker` no lugar do combobox de arquiteto único.
- `src/pages/ProjectDetail.tsx` — precisou ser resincronizado do Skip antes de editar (checkout local desatualizado — 1025 linhas locais vs 1105 reais, mesmo padrão recorrente nesta sessão). Campo "Responsável Principal" (que lia de `contatos` tipo='outro', incompatível com a FK real) substituído pelo combobox de funcionários; Arquiteto Designado substituído pelo split picker.

### Orçamentos (3 arquivos)

- `src/components/ArchitectSplitPicker.tsx` (novo) — construído sobre `SearchableSelect` já existente (`src/components/ui/searchable-select.tsx`) em vez do Popover+Command com fetch debounced do CRM; a lista de arquitetos já vem inteira de `useOptions()` (sem filtro `empresa_id IS NULL`, comportamento pré-existente não alterado por esta SPEC).
- `src/stores/useBudgetStore.ts` — `Budget.arquitetos[]`, `replaceOrcamentoArquitetos()`, `addBudget`/`updateBudget` chamam a RPC depois do insert/update de itens.
- `src/pages/BudgetFormPage.tsx` — campo `arquiteto_id` (`SearchableSelect`) trocado por `ArchitectSplitPicker`. Auto-vínculo legado adaptado em dois pontos: `handleProjectSelect` (projeto selecionado) agora popula o picker inteiro quando o projeto já tem `projeto_arquitetos`, com fallback para o antigo texto `"Nome Arquiteto"` (match único → 1 linha de 100%); `handleBatchComplete` (import de PDF) segue a mesma lógica de fallback por nome.

## Verificação

- `npx tsc --noEmit` + `npx oxlint` + `npm run build` limpos nos dois sistemas, a cada leva de mudanças.
- Migrations aplicadas no Supabase real com autorização explícita do usuário via `AskUserQuestion`, uma pergunta por leva (convenção já estabelecida — o classificador do Auto Mode bloqueia DDL/DML mesmo com autorização geral prévia).
- Ambas as RPCs testadas com UUID inexistente/sem contexto de autenticação válido antes de confiar nelas — foi assim que o bug de bypass de permissão (acima) foi encontrado.
- QA do Skip (setup/staticAnalysis/build/integrations/test) limpo nos dois projetos antes do publish.
- Nenhum teste de UI ao vivo (browser) foi feito — instabilidade de automação de navegador já documentada em sessões anteriores; validação via build + QA do Skip + leitura de código.

## Pendências / fora de escopo

- Backfill de `responsavel_funcionario_id` a partir de `responsavel_nome` — deixado como revisão manual futura (ver "Estrutura de dados" acima).
- `ProjectCreateModal.tsx` (modal de criação rápida de projeto embutido em Orçamentos) ainda escreve `projetos.arquiteto_id` diretamente, sem passar por `projeto_arquitetos`/RPC — gap pré-existente não coberto por esta SPEC (fora do escopo pedido, não listado no plano aprovado).
