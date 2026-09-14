---
titulo: "SPEC-140 — Campo Vendedor do Orçamento: lista fixa de 5 pessoas"
status: "código pronto (Skip 32554 v0.0.361, QA verde), NÃO publicado — depende da migration de dados"
data_ultima_modificacao: 2026-09-14
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
- [x] Publicado o código no Skip (v0.0.361, QA verde).
- [ ] **Aplicar a migration no Supabase real** — bloqueada pelo classificador de modo automático; comando pronto abaixo.
- [ ] Teste ao vivo: abrir Novo Orçamento, conferir que só essas 5 pessoas aparecem no campo Vendedor, na ordem certa.

## Decisão final: 5 pessoas, não 6

O pedido original listava 6 nomes, mas a investigação + confirmação do usuário resolveu que "Marina Pousa" e "Barbara Gregorio" eram a mesma pessoa (erro de cadastro) — a lista final tem 5 pessoas:

1. Thairine Cristina da Silva
2. Thais Gomes Pegrucci Favaron
3. Marina Pousa
4. Vinicius Bortolin Costa
5. Filippo Giorgi

## Como aplicar

```
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "supabase/db/migrations/20260914_140_fix_vendedores_orcamento/001_fix_nome_marina_e_cadastro_filippo.sql"
```

Testada com dry-run (`BEGIN; ...; ROLLBACK;`) antes de qualquer tentativa real — `UPDATE 1` (nome da Marina) + `INSERT 0 1` (cadastro do Filippo), sem erro.

## Pendências / decisões de baixo risco (fácil de ajustar depois)

- `empresa_id` do Filippo foi escolhida como FOCO ILUMINACAO (mesma empresa do Vinicius Bortolin Costa, Gerente Administrativo) — os outros 4 vendedores permitidos estão espalhados nas 3 empresas do grupo (Foco/iSlight/Manoella), não há uma "empresa certa" óbvia pra quem é dono do grupo todo. Ajustável a qualquer momento pela tela de Cadastro/RH sem impacto no filtro do Vendedor (que não depende de empresa).
- `cargo` do Filippo foi definido como "Sócio-Diretor" — ajustável do mesmo jeito.

## Critérios de aceite

- [ ] Campo Vendedor do Orçamento mostra só as 5 pessoas listadas, nesta ordem.
- [ ] Orçamento já existente com vendedor fora da lista continua mostrando o nome dele corretamente (não quebra, não fica em branco) — comportamento já existente de fallback (`assignedVendedorNome`) preservado.
- [ ] `pnpm run lint`/`pnpm run build` passam.
