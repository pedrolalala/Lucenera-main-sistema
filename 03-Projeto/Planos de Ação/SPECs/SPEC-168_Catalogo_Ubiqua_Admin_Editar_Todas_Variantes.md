---
titulo: "SPEC-168 — Catálogo Ubiqua: admin edita foto de toda variante"
status: concluído
data_ultima_modificacao: 2026-09-28
sistemas_envolvidos:
  - catalogo-pecas-ubiqua-e6fa0
---

# SPEC-168 — Catálogo Ubiqua: admin edita foto de toda variante

## Checklist de Ação

- [x] Card da aba de imagens do admin lista todas as variantes do grupo (referência, cor, estoque, com/sem foto), cada uma abrindo o modal de edição.
- [x] Publicado no Skip 33302 v0.0.91 (`61e0030`).
- [x] Commit/push do submódulo + ponteiro no central.
- [ ] Teste logado no admin em produção (usuário).

### Passos manuais do usuário

Nenhum. Não tem migration.

## Objetivo

O usuário relatou que peças que aparecem no site do Catálogo Ubiqua não aparecem no admin para trocar a
foto. Toda variante que está no catálogo tem que poder receber foto pelo admin.

## Causa raiz (investigação 2026-09-28, banco real)

- A página inicial e o admin usam o mesmo agrupamento (`groupCatalogItems` em `src/hooks/use-parts.ts`): as
  linhas de `revenda_ubiqua` viram cards por família (SPEC-147/150 juntam cores e as versões Manoella e `-IS`).
- No admin (`AdminImages.tsx`), o botão "Editar Variante" abria **uma variante por cor**: a de maior
  `disponivel`. As outras linhas da mesma cor no grupo nunca eram editáveis.
- Simulação com os dados reais: 87 linhas → 76 visíveis em 28 cards → **13 variantes sem acesso no admin**
  (ex.: 339104 VERDE SALVIA, 366102 PRETO, 189302/189303/189304/189308 PLISSE MINI, 321403/321404 STANDY
  MINI, 366402 TORUS GLASS). As 11 linhas restantes são órfãs sem estoque (SPEC-147) e não aparecem nem na
  página inicial.

## Definição

Só frontend, em `src/pages/admin/AdminImages.tsx`: o rodapé do card troca o botão único por uma linha por
variante do grupo (bolinha verde/vermelha = com/sem foto, referência, cor, estoque). Clicar abre o mesmo modal
de sempre (descrição, valor, cor, imagem), que grava na linha certa de `revenda_ubiqua`.

O upload continua salvando em `catalogos/<referencia>_catalogo.jpg`, então cada referência tem arquivo próprio.

## Rollback

Reverter o commit do submódulo e republicar no Skip.
