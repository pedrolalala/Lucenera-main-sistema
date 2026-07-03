---
titulo: "SPEC-004 — Auditoria e Proteção de Parcelas do Orçamento Aprovado"
status: parcial
data_ultima_modificacao: 2026-06-26
sistemas_envolvidos:
  - Orçamentos
  - CRM
  - Administração Bancária / Financeiro
  - Supabase / Banco
  - Edge Functions
---

# SPEC-004 — Auditoria e Proteção de Parcelas do Orçamento Aprovado

## Checklist de Ação

- [x] Criar tabela de histórico própria que referencie `public.orcamentos(id)`, sem alterar a FK da família Ubiqua/revenda.
- [x] Atualizar `aprovar_orcamento_financeiro_base_spec001` para gravar histórico obrigatório e parar de engolir `foreign_key_violation`.
- [x] Ajustar a unicidade de `projeto_parcelas` para respeitar `orcamento_id` no fluxo novo (índices únicos parciais).
- [x] Proteger parcelas geradas por orçamento contra atualização/deleção por fluxos legados baseados apenas em `projeto_id` (CRM).
- [x] Descontinuar a Edge Function `sync-fechamentos-automatica` e o mecanismo legado `projetos_fechados` (decisão revisada — ver Frente 3).
- [x] Ajustar telas/serviços do CRM que editam `projeto_parcelas` manualmente.
- [x] Rodar build/type-check nos sistemas alterados.
- [x] Reextrair snapshot do banco após aplicar as migrations.

### Passos manuais do usuário

- [x] Aplicar as migrations desta SPEC no banco remoto compartilhado.
- [x] Deletar a função remota `sync-fechamentos-automatica` do projeto Supabase.
- [x] Publicar o commit do CRM no repositório remoto. O commit original `3e36f36` foi incorporado em `main` e o repositório atual contém commits posteriores.
- [ ] Homologar aprovação de orçamento e edição manual de parcelas no CRM no mesmo projeto de teste.
- [ ] Decidir, em conversa separada, se a tabela `projetos_fechados` (hoje vazia e sem leitor) deve ser dropada ou mantida como histórico morto.

## Objetivo

A aprovação de orçamento precisa deixar rastro auditável e preservar as parcelas geradas por `orcamento_id`. Hoje há duas quebras de integridade:

1. o histórico de status não é gravado, porque `historico_status_orcamento.orcamento_id` aponta para `orcamentos_revenda_ubiqua(id)` e a RPC engole a violação de FK;
2. fluxos legados de parcelas continuam operando por `projeto_id + numero_parcela`, sem reconhecer que parcelas do fluxo novo pertencem a um orçamento aprovado.

Esta SPEC torna `orcamento_id` a fronteira operacional do fluxo aprovado: histórico deve ser gravado contra `orcamentos(id)` e nenhuma rotina legada pode sobrescrever parcelas geradas por orçamento.

## Decisões aprovadas

- Não reapontar cegamente a FK de `historico_status_orcamento`, porque a tabela atual pertence à família Ubiqua/revenda no snapshot vigente.
- Criar uma tabela de histórico própria para `public.orcamentos(id)` ou migrar a tabela atual somente depois de auditar uso Ubiqua/revenda.
- Falha ao gravar histórico de aprovação não deve ser silenciosa no fluxo novo.
- `orcamento_id` prevalece sobre `projeto_id + numero_parcela` para parcelas geradas por aprovação de orçamento.
- A sincronização legada de `projetos_fechados` só pode criar/alterar parcelas sem `orcamento_id`.
- O CRM pode exibir parcelas geradas por orçamento, mas não deve editá-las/deletá-las pelo editor manual de projeto.
- **Decisão revisada em 2026-06-25**: `projetos_fechados`/`sync-fechamentos-automatica` não é protegido — é descontinuado. O status "projeto fechado" só deve mudar via aprovação de orçamento; depois de aprovado, valor total e forma de pagamento ficam imutáveis para qualquer sistema. Confirmado pelo usuário: 0 linhas em `projetos_fechados`, última execução de sync em 2026-04-07 sem updates, 0 overlap com projetos de orçamento aprovado, nenhum frontend invoca a função.

## Definição da SPEC

### Estado atual verificado

| Evidência | Situação |
|---|---|
| `supabase/db/current/01_schema_full.sql` | `historico_status_orcamento.orcamento_id` possui FK para `public.orcamentos_revenda_ubiqua(id)`. |
| `supabase/db/current/01_schema_full.sql` | `aprovar_orcamento_financeiro_base_spec001` tenta inserir histórico e faz `EXCEPTION WHEN ... foreign_key_violation THEN NULL`. |
| `supabase/db/current/01_schema_full.sql` | `projeto_parcelas` possui `orcamento_id`, mas a unicidade real é `UNIQUE (projeto_id, numero_parcela)`. |
| `supabase/functions/sync-fechamentos-automatica/index.ts` | A função busca parcelas por `projeto_id`, compara só `numero_parcela` e atualiza `valor` / `data_fechamento` sem considerar `orcamento_id`. |
| `Sistema/lucenera-crm-3bd29 (1)/src/services/projetos.ts` | `saveProjetoParcelas` atualiza/deleta/insere `projeto_parcelas` por `id` e `projetoId`, sem regra de proteção para `orcamento_id`. |
| `Sistema/lucenera-crm-3bd29 (1)/src/pages/Projetos.tsx` | O editor manual salva pagamentos direto em `projeto_parcelas` e remove ids antigos que sumiram da lista editada. |

Observação histórica: em 2026-06-25, o catálogo central `supabase/functions/deno.json` ainda registrava `sync-fechamentos-automatica` na versão 6, e a árvore local continha cópias dessa função em vários sistemas (`Central`, `Orçamentos/Financeiro`, `CRM`, `RH`, `Cadastro`, `Logística`, `Retorno Bancário` e `Catálogo Ubíqua`). Em 2026-06-26, a função já não aparece no remoto nem na pasta central.

### Frente 1 — Histórico correto da aprovação

Criar um destino de auditoria para o fluxo `public.orcamentos`:

- opção preferida: nova tabela `historico_status_orcamentos` com FK para `public.orcamentos(id)`;
- manter `historico_status_orcamento` para a família Ubiqua/revenda até prova contrária;
- gravar `orcamento_id`, status anterior, status novo, usuário, observação e `created_at`;
- atualizar a RPC para inserir no histórico correto;
- remover o tratamento silencioso de `foreign_key_violation` para a gravação do histórico novo.

Critério: se a aprovação retornar sucesso, deve existir registro de histórico para o `orcamento_id` aprovado.

### Frente 2 — Unicidade e propriedade de `projeto_parcelas`

A constraint atual `projeto_parcelas_projeto_id_numero_parcela_key UNIQUE (projeto_id, numero_parcela)` mistura parcelas legadas do projeto com parcelas geradas por orçamento. A regra nova deve separar os dois mundos:

- parcelas com `orcamento_id IS NOT NULL` devem ser únicas por `(orcamento_id, numero_parcela)`;
- parcelas sem `orcamento_id` podem continuar únicas por `(projeto_id, numero_parcela)`;
- a migration deve auditar registros existentes antes de derrubar/recriar constraint;
- qualquer conflito encontrado deve gerar relatório de revisão manual, não correção automática cega.

### Frente 3 — Descontinuação de `sync-fechamentos-automatica` / `projetos_fechados`

O plano original previa apenas proteger a função (Frente 3 original: ignorar parcelas com `orcamento_id`). Durante a implementação, o usuário esclareceu a regra de negócio real: "projeto fechado" não é um mecanismo paralelo de sincronização — é apenas o status de um projeto cujo orçamento foi aprovado. Quando não há orçamento aprovado, o projeto fica pendente até que um seja criado e aprovado; depois de aprovado, valor total e forma de pagamento não podem ser alterados por nenhum sistema (ver SPEC-001/002).

Investigação empírica antes da decisão:

- `projetos_fechados`: 0 linhas;
- `sync_history`: última execução em 2026-04-07, 0 registros atualizados;
- 0 sobreposição entre projetos com fechamento legado e projetos com orçamento aprovado;
- nenhum código de frontend, em nenhum dos 11 sistemas, invoca `sync-fechamentos-automatica`.

Decisão: descontinuar por completo, em vez de proteger.

- Removida a pasta `supabase/functions/sync-fechamentos-automatica/` e a entrada correspondente em `supabase/functions/deno.json` nos 8 sistemas que tinham cópia local da função.
- Removida a função publicada `sync-fechamentos-automatica` do projeto Supabase remoto (`vcvcwzmbiftcawncibke`).
- A tabela `projetos_fechados` **não** foi dropada — fica registrada como pendência em aberto (ver Pendências), já que sua remoção não foi pedida explicitamente.

### Frente 4 — CRM e edição manual de parcelas

Separar visualização de edição:

- parcelas com `orcamento_id` podem aparecer no detalhe do projeto como origem "Orçamento aprovado";
- editor manual de projeto deve bloquear alteração/deleção dessas parcelas;
- updates/deletes do editor manual devem filtrar por `orcamento_id IS NULL` quando estiverem tratando parcelas legadas;
- novas parcelas criadas manualmente continuam com `orcamento_id = null`;
- se for necessário corrigir parcela de orçamento, criar fluxo próprio de reabertura/ajuste autorizado, fora do editor legado.

### Critérios de aceite

- Aprovar orçamento grava um registro de histórico referenciando `public.orcamentos(id)`.
- A RPC não retorna sucesso se a gravação obrigatória do histórico falhar.
- Dois orçamentos do mesmo projeto podem ter `numero_parcela = 1` sem conflitar, desde que tenham `orcamento_id` diferentes.
- `sync-fechamentos-automatica` foi descontinuada (removida do código e do projeto remoto), então não existe mais rotina capaz de alterar `valor`, `data_fechamento`, `data_vencimento` ou `status` de parcela com `orcamento_id` por esse caminho.
- O CRM não permite editar nem deletar parcela com `orcamento_id` pelo editor manual do projeto.
- Parcelas legadas sem `orcamento_id` continuam editáveis e sincronizáveis pelos fluxos existentes.

## Realizado

### 2026-06-25

- Migration `20260625210000_spec004_historico_e_unicidade_parcelas.sql` criada e aplicada no banco remoto:
  - nova tabela `public.historico_status_orcamentos` (FK para `public.orcamentos(id)`, índices em `orcamento_id` e `created_at DESC`, RLS habilitada com policies de select/insert para `authenticated`);
  - constraint antiga `projeto_parcelas_projeto_id_numero_parcela_key` removida e substituída por dois índices únicos parciais: `projeto_parcelas_orcamento_numero_uniq (orcamento_id, numero_parcela) WHERE orcamento_id IS NOT NULL` e `projeto_parcelas_projeto_numero_legado_uniq (projeto_id, numero_parcela) WHERE orcamento_id IS NULL`;
  - `aprovar_orcamento_financeiro_base_spec001` passou a inserir em `historico_status_orcamentos` sem engolir erro de FK — se a gravação do histórico falhar, a aprovação inteira falha.
  - Verificado no banco: tabela existe, os 2 índices parciais existem, a constraint antiga foi removida, as 2 policies de RLS estão ativas.
- Investigação e decisão sobre a Frente 3 original (proteger `sync-fechamentos-automatica`): o usuário esclareceu que "projeto fechado" é apenas um status decorrente de orçamento aprovado, não um mecanismo paralelo. Confirmado por consulta direta ao banco que `projetos_fechados` tem 0 linhas, a função não roda updates desde 2026-04-07 e nenhum frontend a invoca. Decisão: descontinuar em vez de proteger.
  - Removida a pasta `supabase/functions/sync-fechamentos-automatica/` e a entrada em `supabase/functions/deno.json` nos 8 sistemas com cópia local: `gestao-financeira-clone-544cb (1)`, `lucenera-crm-3bd29 (1)`, `dashboard-rh-lucenera-5fe9c`, `retorno-bancario-bradesco-5392a`, `catalogo-pecas-ubiqua-e6fa0`, `cadastro-lucenera-b86fe`, `lucenera-logistics-b7cd1`, `central-lucenera-dashboard-1c9ba`.
  - Função remota `sync-fechamentos-automatica` deletada do projeto Supabase (`vcvcwzmbiftcawncibke`) via `supabase functions delete`; confirmado ausente em `supabase functions list`.
- Frente 4 (CRM) implementada em `lucenera-crm-3bd29 (1)`: `services/projetos.ts` (`saveProjetoParcelas` agora ignora parcelas com `orcamento_id` e filtra updates/deletes por `orcamento_id IS NULL`), `pages/Projetos.tsx` e `pages/ProjectDetail.tsx` (edição manual só considera parcelas legadas; tabela read-only ganhou coluna "Origem" com badge "Orçamento aprovado"/"Manual").
- Build e type-check executados com sucesso em `gestao-financeira-clone-544cb (1)` e `lucenera-crm-3bd29 (1)`.
- Commits criados e enviados para os repositórios remotos: `gestao-financeira-clone-544cb (1)` (push ok), `dashboard-rh-lucenera-5fe9c` (push ok), `retorno-bancario-bradesco-5392a` (merge com alterações concorrentes do auto-sync + push ok), `central-lucenera-dashboard-1c9ba` (push ok). O commit em `lucenera-crm-3bd29 (1)` foi criado localmente (`3e36f36`) mas o push falhou com erro 403 (usuário sem permissão de escrita no repositório `pedrolalala/lucenera-crm`). `catalogo-pecas-ubiqua-e6fa0`, `cadastro-lucenera-b86fe` e `lucenera-logistics-b7cd1` não são repositórios git — a remoção da função ficou apenas no disco local.

### 2026-06-26

- Confirmado por `git pull --ff-only` que o CRM remoto incorporou a mudança originalmente criada no commit `3e36f36` (`92b72e3 Merge commit '3e36f36...'`) e avançou até `dc7371e`.
- Confirmado por `supabase functions list --project-ref vcvcwzmbiftcawncibke` que `sync-fechamentos-automatica` não aparece mais como função remota ativa.
- Pasta central `supabase/functions/sync-fechamentos-automatica/` removida para acompanhar o estado remoto.
- Snapshot de 2026-06-25 já reflete `historico_status_orcamentos` e os índices únicos parciais criados por esta SPEC. A nova pendência de snapshot é apenas pós-SPEC-005.

## Pendências

- [ ] Homologar aprovação de orçamento (gravação de histórico) e edição manual de parcelas no CRM no mesmo projeto de teste.
- [ ] Decidir se a tabela `projetos_fechados` (vazia, sem leitor desde a remoção da função) deve ser dropada ou mantida.
- [ ] Sem repositório git local em `catalogo-pecas-ubiqua-e6fa0`, `cadastro-lucenera-b86fe` e `lucenera-logistics-b7cd1` — confirmar se esses sistemas usam outro mecanismo de deploy/versionamento antes de considerar a remoção "publicada" neles.
