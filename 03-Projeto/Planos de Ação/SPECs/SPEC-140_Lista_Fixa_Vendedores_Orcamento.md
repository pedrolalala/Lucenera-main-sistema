---
titulo: "SPEC-140 — Campo Vendedor do Orçamento: lista fixa de 5 pessoas"
status: "concluído — publicado em produção (Skip 32554 v0.0.367, faec56f) em 2026-09-16, migration aplicada (só o cadastro do Filippo; a renomeação de Marina foi revertida por decisão do usuário, ver abaixo)"
data_ultima_modificacao: 2026-09-16
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — `BudgetFormPage.tsx`
dependencias: []
---

# SPEC-140 — Campo Vendedor do Orçamento: lista fixa de 5 pessoas

> Pedido do usuário (2026-09-14): "Seguindo a linha de Orçamento em vendedores devem aparecer somente: Thairine Cristina da Silva, Thais Gomes Pegrucci Favaron, Marina Pousa, Barbara Gregorio, Vinicius Bortolin Costa, Filippo Giorgi".

## Checklist de Ação

- [x] Investigar os nomes reais em `funcionarios` antes de filtrar por nome exato.
- [x] Achado 1: **confirmado com o usuário** que "Marina Pousa Barbara Gregorio" é 1 única funcionária com o nome errado no banco (não duas pessoas) — corrigido pra "Marina Pousa" (o usuário/login vinculado a esse registro já se chamava só "Marina").
- [x] Achado 2: **confirmado com o usuário** que Filippo Giorgi é o dono da Lucenera e precisa ter cadastro de funcionário pra poder ser selecionado como Vendedor — criado, vinculado ao usuário CRM dele já existente.
- [x] Trocar `PRIORITY_SELLERS` (só ordenava, não filtrava) por `VENDEDORES_PERMITIDOS` — lista fechada de 5 nomes, `sortedVendedores` agora **filtra** em vez de só ordenar.
- [x] Escrever migration em `supabase/db/migrations/20260914_140_fix_vendedores_orcamento/`.
- [x] Publicado o código no Skip (v0.0.361, QA verde; revisado em v0.0.367 após o achado abaixo).
- [x] **Aplicar a migration no Supabase real** — aplicada em 2026-09-16 (dry-run + commit real), só o `INSERT` do Filippo (o `UPDATE` do nome da Marina foi removido da migration, ver achado abaixo).
- [ ] Teste ao vivo: abrir Novo Orçamento, conferir que só essas 5 pessoas aparecem no campo Vendedor, na ordem certa.

## Decisão final: 5 pessoas, não 6

O pedido original listava 6 nomes; a investigação inicial (14/09) tinha concluído, com o usuário, que "Marina Pousa" e "Barbara Gregorio" eram a mesma pessoa (erro de cadastro) e que o nome devia ser corrigido para "Marina Pousa". **Revertido em 16/09**: ao confirmar a aplicação da migration, o usuário decidiu explicitamente **manter o nome completo como está no banco** ("Marina Pousa Barbara Gregorio"), sem renomear. A lista final continua com 5 pessoas, só que o nome usado no filtro do código é o nome completo real:

1. Thairine Cristina da Silva
2. Thais Gomes Pegrucci Favaron
3. Marina Pousa Barbara Gregorio
4. Vinicius Bortolin Costa
5. Filippo Giorgi

## Achado (2026-09-16): filtro por nome exato exigia ajuste

Como `sortedVendedores` filtra por match **exato** de nome (`v.nome.trim().toLowerCase()`), manter o nome completo no banco sem ajustar `VENDEDORES_PERMITIDOS` (que ainda dizia `'Marina Pousa'`) faria ela desaparecer do dropdown. Corrigido: `VENDEDORES_PERMITIDOS` agora usa `'Marina Pousa Barbara Gregorio'`. Commit `8451216` (gestao-financeira-clone), publicado no Skip v0.0.367 (`faec56f`).

## Como foi aplicado

Migration `001_fix_nome_marina_e_cadastro_filippo.sql` reescrita (16/09) para conter **só** o `INSERT` do cadastro do Filippo — o `UPDATE` do nome da Marina foi removido do arquivo por decisão do usuário. Dry-run (`BEGIN; ...; ROLLBACK;`) antes da aplicação real; aplicada via Supabase Management API (psql direto com problema de DNS, ver [[reference_supabase_management_api_fallback_psql]]). Confirmado no banco: Marina continua com o nome completo; Filippo Giorgi criado (`cargo: Sócio-Diretor`, `status: Ativo`).

## Pendências / decisões de baixo risco (fácil de ajustar depois)

- `empresa_id` do Filippo foi escolhida como FOCO ILUMINACAO (mesma empresa do Vinicius Bortolin Costa, Gerente Administrativo) — os outros 4 vendedores permitidos estão espalhados nas 3 empresas do grupo (Foco/iSlight/Manoella), não há uma "empresa certa" óbvia pra quem é dono do grupo todo. Ajustável a qualquer momento pela tela de Cadastro/RH sem impacto no filtro do Vendedor (que não depende de empresa).
- `cargo` do Filippo foi definido como "Sócio-Diretor" — ajustável do mesmo jeito.

## Critérios de aceite

- [ ] Campo Vendedor do Orçamento mostra só as 5 pessoas listadas, nesta ordem.
- [ ] Orçamento já existente com vendedor fora da lista continua mostrando o nome dele corretamente (não quebra, não fica em branco) — comportamento já existente de fallback (`assignedVendedorNome`) preservado.
- [ ] `pnpm run lint`/`pnpm run build` passam.
