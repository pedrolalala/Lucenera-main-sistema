---
titulo: "SPEC-024 — Sincronização Comissão × Equipe × Responsável de Projeto"
status: pendente
data_ultima_modificacao: 2026-07-14
sistemas_envolvidos:
  - dashboard-rh-lucenera-5fe9c (Comissão)
  - Banco central (Supabase) — projetos, equipes_projetos, funcionarios_financeiro
dependencias:
  - SPEC-RH-05 (03-Projeto/Escopos/08_ESCOPO_RH.md) — Folha e integração financeira
  - supabase/db/migrations/20260630_012_equipe_projetos_comissao (migration original)
---

# SPEC-024 — Sincronização Comissão × Equipe × Responsável de Projeto

> A comissão por equipe (`vw_comissao_mensal`, tela "Comissão" do RH) já existe, mas
> depende de um vínculo `projetos.equipe_id` sincronizado por **comparação de texto**
> (`responsavel_nome` vs `equipes_projetos.equipes`) — mesma classe de bug já corrigida
> na SPEC-023 (Vale Transporte). Além disso, o frontend cai silenciosamente em
> **dados fictícios (mock)** quando a view não retorna nada, sem avisar o usuário.

---

## Checklist de Ação

### Diagnóstico — rodado em produção em 2026-07-14
- [x] `SELECT count(*) FROM projetos WHERE equipe_id IS NULL AND responsavel_nome IS NOT NULL` → **1.659 de 3.694 projetos (45%)** estão fora do cálculo de comissão hoje.
- [x] Os `responsavel_nome` órfãos **não são variações de acento/maiúscula de Thais/Marina/Thairine** — são pessoas totalmente diferentes, sem equipe cadastrada: `Mariane` (333 projetos), `Ricardo` (243), `Amanda` (67), `Angélica` (63+2 em caixa alta), `Rianne` (61), `Ligia` (61), `Vilber` (54), `Bender` (49), `Filippo` (39), `Mary` (14), `Eduardo` (9), `Terezinha` (3), `Maria` (1), `João` (1). Ou seja: `equipes_projetos` só tem 3 linhas (Thais, Marina, Thairine) mas há pelo menos 14 outros responsáveis reais sem equipe/comissão configurada — **não é bug de comparação de texto, é cadastro incompleto**.
- [x] Achado mais crítico: de **3.694 projetos no total, apenas 33 têm `valor_total > 0`** — é por isso que a equipe "Thais" (124 projetos, nenhum com `valor_total > 0`) nunca aparece em `vw_comissao_mensal` em nenhum mês, mesmo com o vínculo `equipe_id` correto. Marina tem 761 projetos mas só 2 com valor; Thairine tem 745 mas só 1. Isso é a causa raiz de a tela mostrar `MOCK_DATA` na prática — quase nenhum mês tem dado real suficiente para preencher a view.

### Correção do vínculo projeto ↔ equipe (migration Supabase)
- [x] Tornar `fn_sync_equipe_por_responsavel()` tolerante a acento (`unaccent()`), além do `lower(trim())` já existente — proteção defensiva para o futuro. **Não resolve os 1.659 órfãos atuais** (confirmado no diagnóstico: não são variação de acento, são responsáveis sem equipe cadastrada).
- [ ] Cadastro das equipes/responsáveis que faltam em `equipes_projetos` — depende de decisão de negócio (ver "Pendências"), não é algo que a IA deva inventar.
- [ ] Decidir o destino de `equipe_id` vs `equipe_responsavel_obra_id` (ver Pendências) e documentar em `supabase/docs/relationships.md`.

### Limpeza de divergência local (dashboard-rh-lucenera-5fe9c)
- [ ] `04-Sistemas/dashboard-rh-lucenera-5fe9c/supabase/migrations/20260630141000_create_vw_comissao_mensal.sql` define uma versão **antiga e diferente** de `vw_comissao_mensal` (3% fixo, join via `projetos_fechados`, uma linha por equipe em vez de por funcionário, com inserts de seed/demo). Não é a fonte da verdade — a view real vive no banco central (migration `006_fix_view_comissao_por_funcionario.sql`). Marcar esse arquivo local como histórico/não aplicar, para não sobrescrever a view real se alguém rodar as migrations locais do submódulo.
- [ ] `04-Sistemas/dashboard-rh-lucenera-5fe9c/supabase/migrations/20260424183000_add_comissao_padrao.sql` referencia `funcionarios.comissao_padrao`, coluna que **não existe** na tabela `funcionarios` real (a migration nunca foi aplicada em produção ou foi revertida). Remover ou marcar como obsoleta para não confundir.
- [ ] Atualizar `supabase/db/domains/rh.md` — hoje não menciona `funcionarios_financeiro`, `equipes_projetos` nem `vw_comissao_mensal`, ficando desatualizado em relação ao schema real.

### Correção do frontend (dashboard-rh-lucenera-5fe9c)
- [x] Remover o fallback silencioso para `MOCK_DATA` em `src/services/comissao.ts` — ele mascarava erro de query e mês sem dados como se fossem números reais (era literalmente o que aparecia na tela em produção antes desta correção).
- [x] Tratar separadamente: (a) erro de conexão/query → mensagem de erro explícita; (b) mês sem nenhum projeto/comissão → estado vazio explícito ("Nenhuma comissão calculada neste período").
- [ ] Exibir aviso quando existirem projetos do mês selecionado com `responsavel_nome` preenchido mas sem `equipe_id` (dado fora do cálculo) — não implementado nesta rodada; depende de decidir o que fazer com os 14 responsáveis órfãos primeiro.

### Passos manuais do usuário

- [ ] **Decisão de negócio necessária**: cadastrar em `equipes_projetos` (+ `funcionarios_financeiro.equipes_id` + `comissao_percentual`) os responsáveis reais que hoje não geram comissão nenhuma. Status conhecido até agora (usuário, 2026-07-14):
  - **Mariane** (333 projetos) — virou gerente de projetos; falta decidir se ainda entra no cálculo de comissão nessa nova função ou não.
  - **Ricardo** (243) e **Amanda** (67) — não trabalham mais na empresa; os projetos/histórico devem **permanecer no banco**, mas não precisam gerar comissão nova.
  - Ainda sem decisão: Angélica (63), Rianne (61), Ligia (61), Vilber (54), Bender (49), Filippo (39), Mary (14), Eduardo (9), Terezinha (3), Maria (1), João (1).
  - Sem essa definição, 45% do volume de projetos continua fora do cálculo de comissão — não é algo que a IA deva decidir sozinha (nome completo, vínculo com `funcionarios_novo`, % de comissão).
- [x] `valor_total = 0` na maioria dos projetos (3.661/3.694) é **esperado**, confirmado pelo usuário em 2026-07-14 — não é bug, não precisa de investigação adicional.
- [ ] Validar com o negócio se `comissao_percentual` de cada funcionário deve continuar sendo aplicado individualmente sobre 100% do valor da equipe (comportamento atual da view) ou se existe um teto por equipe.
- [ ] Confirmar com Thais/Marina/Thairine (ou substitutas) se os nomes cadastrados em `equipes_projetos.equipes` continuam corretos após qualquer troca de responsável.

---

## Objetivo

Garantir que a comissão mensal exibida em **RH → Comissão** reflita fielmente os
projetos realmente vinculados a cada equipe, e nunca exiba números fictícios sem
avisar o usuário — hoje isso pode acontecer de duas formas: (1) um projeto não
entra no cálculo porque o nome do responsável não bateu byte-a-byte com o nome
da equipe, e (2) a tela mostra dados de exemplo (`MOCK_DATA`) como se fossem reais
quando a consulta falha ou volta vazia.

---

## Decisões aprovadas

- A comissão de cada funcionário é calculada individualmente: `valor_total dos
  projetos da equipe no mês × comissao_percentual do funcionário / 100`
  (`funcionarios_financeiro.comissao_percentual`). Cada funcionário da mesma
  equipe pode ter um percentual diferente — isso já é o comportamento da view
  `vw_comissao_mensal` (migration `006_fix_view_comissao_por_funcionario.sql`) e
  não muda nesta SPEC.
- Um funcionário pertence a no máximo uma equipe por vez
  (`funcionarios_financeiro.funcionario_id` é `UNIQUE`, `equipes_id` é coluna
  única na mesma linha) — comportamento atual, mantido.

---

## Definição da SPEC

### Estado atual (grounded no schema real)

**Tabelas envolvidas:**

| Tabela | Colunas relevantes |
|---|---|
| `public.projetos` | `equipe_id uuid` (FK → `equipes_projetos.id`), `equipe_responsavel_obra_id uuid` (FK → `equipes_projetos.id`, duplicada), `responsavel_nome text`, `responsavel_id uuid`, `valor_total`, `data_entrada` |
| `public.equipes_projetos` | `id uuid PK`, `equipes text` (nome da equipe, sem `UNIQUE`), `created_at` |
| `public.funcionarios_financeiro` | `id uuid PK`, `funcionario_id uuid UNIQUE` (FK → `funcionarios_novo.id`), `comissao_percentual numeric(5,2) default 0`, `equipes_id uuid` (FK → `equipes_projetos.id`, `ON DELETE SET NULL`) |
| `public.funcionarios_novo` | `id`, `nome`, `ativo` |

**View:** `public.vw_comissao_mensal` (migration `20260630_012_equipe_projetos_comissao/006_fix_view_comissao_por_funcionario.sql`)

```sql
FROM projetos p
JOIN equipes_projetos ep ON ep.id = p.equipe_id
JOIN funcionarios_financeiro ff ON ff.equipes_id = ep.id
JOIN funcionarios_novo fn ON fn.id = ff.funcionario_id
WHERE p.valor_total > 0 AND p.data_entrada IS NOT NULL AND fn.ativo IS TRUE
```

Todos os `JOIN`s são internos — um projeto sem `equipe_id` correspondente simplesmente
**desaparece** do resultado, sem erro nem aviso.

**Trigger:** `trg_sync_equipe_por_responsavel` → `fn_sync_equipe_por_responsavel()`
(migration `005_fix_sync_ambas_colunas.sql`), disparado em `INSERT`/`UPDATE OF
responsavel_nome` em `projetos`:

```sql
SELECT id INTO v_equipe_id
FROM equipes_projetos
WHERE lower(trim(equipes)) = lower(trim(NEW.responsavel_nome))
LIMIT 1;

NEW.equipe_id := v_equipe_id;
NEW.equipe_responsavel_obra_id := v_equipe_id;
```

Só cobre `lower()` + `trim()` — **não normaliza acento**. Se `responsavel_nome`
divergir da equipe por qualquer motivo (acento, apelido, nome desatualizado), o
projeto fica com `equipe_id = NULL` silenciosamente e some da comissão.

**Frontend:** `src/services/comissao.ts:43-58` (`fetchComissaoMensal`) — se a
query falhar OU vier vazia, retorna `MOCK_DATA` (3 registros fixos de
Thais/Marina/Thairine com valores inventados) sem sinalizar ao usuário que os
dados são fictícios. `Comissao.tsx` renderiza o que vier de
`fetchComissaoMensal` sem distinguir dado real de mock.

### Raiz do problema (mesma classe da SPEC-023)

| Problema | Causa |
|---|---|
| Projeto some do cálculo de comissão sem aviso | `equipe_id` só é preenchido por match textual exato (case+trim) entre `responsavel_nome` e `equipes_projetos.equipes` |
| Sem visibilidade de projetos órfãos | Nenhuma view/relatório lista `projetos` com `responsavel_nome` preenchido e `equipe_id IS NULL` |
| Tela pode mostrar número fictício como se fosse real | `MOCK_DATA` é retornado em erro E em resultado vazio, sem flag |
| Duas colunas fazem a mesma coisa | `equipe_id` e `equipe_responsavel_obra_id` são sempre gravadas com o mesmo valor pelo mesmo trigger — motivo de manter as duas não está documentado |

### Regras de negócio

| # | Regra |
|---|---|
| RN-01 | O vínculo `projeto → equipe` deve ser tolerante a acento, caixa e espaços extras na comparação `responsavel_nome` × `equipes.equipes` |
| RN-02 | A comissão de cada funcionário é `valor_total dos projetos da equipe no mês × comissao_percentual individual / 100`, aplicada por funcionário (não dividida entre os membros da equipe) |
| RN-03 | A tela de Comissão nunca deve exibir dado fictício sem indicar explicitamente que é um exemplo/placeholder |
| RN-04 | Quando existirem projetos do período sem `equipe_id`, a tela deve avisar que o total pode estar incompleto |

### Critérios de aceite

- [ ] `SELECT` de diagnóstico mostra 0 projetos com `responsavel_nome` preenchido e `equipe_id IS NULL` após a correção do trigger + backfill (ou os remanescentes são justificáveis e documentados)
- [ ] Trocar o nome do responsável de um projeto para uma variação com acento/caixa diferente da equipe ainda resulta no `equipe_id` correto
- [ ] Selecionar um mês sem nenhuma comissão real mostra estado vazio explícito, nunca os valores de Thais/Marina/Thairine do mock
- [ ] Erro de conexão com Supabase mostra mensagem de erro, não os dados mock
- [ ] Query da tela de Comissão continua funcionando para os meses com dado real existente

---

## Realizado

### 2026-07-14

- Diagnóstico completo em produção via Supabase (REST + `supabase db query --linked`): 1.659/3.694 projetos sem `equipe_id`, 14 responsáveis reais sem equipe cadastrada, e apenas 33/3.694 projetos com `valor_total > 0` — esse último é a causa raiz de a tela mostrar mock quase sempre.
- Migration `supabase/db/migrations/20260714_040_fix_sync_equipe_unaccent/001_unaccent_sync_equipe.sql` aplicada em produção — `fn_sync_equipe_por_responsavel()` agora tolera acento. Confirmado que não reduziu os 1.659 órfãos (não era essa a causa).
- `src/services/comissao.ts` e `src/pages/Comissao.tsx` (dashboard-rh-lucenera-5fe9c): removido o fallback para `MOCK_DATA`; adicionado estado de erro explícito e estado vazio explícito.
- Fix do frontend replicado e publicado no projeto Skip Cloud "RH Lucenera" (id 23919) — https://dashboard-rh-lucenera-5fe9c.goskip.app.
- Repositório local `dashboard-rh-lucenera-5fe9c` com as duas alterações no working tree, ainda não commitado (aguardando confirmação do usuário).

## Pendências

- [ ] Definir se `equipe_responsavel_obra_id` deve ser removida (redundante com `equipe_id`) ou se tem um uso distinto planejado — hoje as duas colunas são gravadas de forma idêntica pelo mesmo trigger.
- [ ] Rodar o diagnóstico de projetos órfãos (`equipe_id IS NULL`) em produção para dimensionar o impacto real antes de aplicar a migration — números não foram levantados nesta SPEC por falta de acesso direto ao Supabase de produção nesta sessão.
- [ ] Validar com o negócio se `MOCK_DATA` deve ser removido por completo do código ou mantido apenas atrás de uma flag de ambiente de desenvolvimento.
- [ ] Confirmar se `equipes_projetos` deveria ter uma FK explícita para a pessoa responsável (`usuarios`/`funcionarios_novo`) em vez de depender de comparação de nome em texto livre — mudança estrutural maior, fora do escopo desta correção pontual.
