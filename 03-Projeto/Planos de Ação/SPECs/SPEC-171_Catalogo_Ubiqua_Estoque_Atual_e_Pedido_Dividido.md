---
titulo: "SPEC-171 — Catálogo Ubiqua: estoque atual de produtos e pedido dividido entre referências"
status: concluído
data_ultima_modificacao: 2026-09-28
sistemas_envolvidos:
  - catalogo-pecas-ubiqua-e6fa0
---

# SPEC-171 — Catálogo Ubiqua: estoque atual de produtos e pedido dividido entre referências

## Checklist de Ação

- [x] Migration `20260928_171_ubiqua_estoque_atual`: função `ubiqua_estoque_atual()` (dry-run ok com ROLLBACK, testada como `authenticated`).
- [x] `src/lib/estoque-atual.ts`: troca `disponivel` pelo estoque de `produtos` (catálogo, página da peça, busca do orçamento).
- [x] `QuantityModal`: limite = soma da cor; pedido dividido entre as referências (maior estoque primeiro).
- [x] Migration aplicada no Supabase real (2026-09-28). `authenticated` executa; `anon` recebe 401 (42501).
- [x] Publicado no Skip 33302 v0.0.94 (`be3b4e1`). Nenhuma Edge Function alterada; `schema_migrations` segue com 239.
- [ ] Teste do usuário: FLORA VERDE SALVIA mostra 12 e aceita 12 (10 de 339104-IS + 2 de 339104).

### Passos manuais do usuário

Nenhum.

## Objetivo

O usuário viu 3 números diferentes para a FLORA VERDE SALVIA no Catálogo Ubiqua: 14 no card, 12 no
Supabase e só 11 aceitos no orçamento.

## Causa raiz (2026-09-28)

A cor tem 2 linhas em `revenda_ubiqua`: `339104` (Manoella) e `339104-IS` (Islight), juntas no mesmo card
(SPEC-147).

| Número | Origem |
|---|---|
| 14 | card: soma de `revenda_ubiqua.disponivel` (3 + 11) |
| 12 | `produtos.estoque_disponivel` (2 + 10), atualizado pelo import do Connect |
| 11 | orçamento: `QuantityModal` usava **uma** referência (a de maior estoque, 339104-IS = 11) |

`revenda_ubiqua` é uma cópia parada: todas as linhas da FLORA com `updated_at` = 03/06/2026, sem nenhum
script de sincronização. A AREIA batia porque todo o estoque está numa referência só (339103-IS).

## Decisões aprovadas (2026-09-28, usuário)

1. O catálogo lê o estoque atual de `produtos` (não atualiza a cópia de `revenda_ubiqua`).
2. Quando a cor tem estoque nas duas empresas, o orçamento aceita até a soma e divide sozinho: primeiro a
   referência de maior estoque, o que faltar vai da outra (2 linhas no orçamento).

## Definição

- RLS de `produtos` (`spec069_produtos_select`) exige papel do Hub; representante não tem. A função
  `ubiqua_estoque_atual()` é SECURITY DEFINER e devolve só `(referencia, disponivel)` das referências que
  estão em `revenda_ubiqua`. `EXECUTE` só para `authenticated`.
- Cruzamento `upper(trim(referencia))` (chave da SPEC-137): 77 de 87 linhas casam, nenhuma duplicada; as 10
  sem par ficam com 0 (não tinham estoque).
- Não escreve em `produtos` nem em `revenda_ubiqua` (SPEC-137: `produtos` é a fonte de verdade).
- Se a RPC falhar, o site usa os valores de `revenda_ubiqua` para o catálogo não ficar vazio.
- Divisão do pedido desconta o que já está no carrinho de cada referência. Sem estoque em nenhuma, segue o
  fluxo de encomenda de importação que já existia.

## Rollback

`DROP FUNCTION public.ubiqua_estoque_atual();` e reverter o commit do submódulo (o site volta a ler
`revenda_ubiqua.disponivel`; sem a função, ele já cai nesse comportamento sozinho).
