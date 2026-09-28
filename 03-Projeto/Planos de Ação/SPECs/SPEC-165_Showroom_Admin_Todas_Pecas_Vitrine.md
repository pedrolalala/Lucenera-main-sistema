---
titulo: "SPEC-165 — /admin do Showroom: toda peça da vitrine achável e editável"
status: concluído
data_ultima_modificacao: 2026-09-28
sistemas_envolvidos:
  - showroom-qtq8er2dk
---

# SPEC-165 — /admin do Showroom: toda peça da vitrine achável e editável

## Checklist de Ação

- [x] Aba de fotos com filtro "Na vitrine / Sem foto / Todos" (mesma regra da página inicial, via `vw_showroom_publico`).
- [x] Badge "Na vitrine" em cada produto que aparece na página inicial.
- [x] Busca local por nome, marca, referência, código e código legado (sem acento/maiúscula).
- [x] `/admin` abre direto na aba "Peças e fotos" (antes abria em "Vincular do PPT").
- [x] Publicado no Skip (projectId 54698) v0.0.16 `e4713c0` — bundle de produção conferido.
- [x] Commit do submódulo `11c3df7` + ponteiro no central.
- [ ] Teste visual logado no /admin em produção (usuário).

### Passos manuais do usuário

Nenhum. Não tem migration.

## Objetivo

O usuário relatou que peças que aparecem na página inicial do Showroom não aparecem no `/admin` para trocar a foto ou vincular. Toda peça da vitrine tem que ser editável no admin.

## Causa raiz (investigação 2026-09-28, banco real)

- Vitrine (`vw_showroom_publico`) = **123 peças**. RPC da aba de fotos (`showroom_listar_produtos_estoque`) = **281 produtos**, e as 123 estão todas lá (0 faltando). Nada está faltando no banco.
- A aba padrão "Vincular do PPT" só lista as 167 peças do PowerPoint. As **33 peças Ubiqua** da vitrine (foto copiada do catálogo Ubiqua na SPEC-137) não têm slide e não aparecem nessa aba.
- Na aba "Fotos do estoque", a lista vem ordenada "sem foto primeiro": são 158 produtos sem foto antes das 123 da vitrine. Não havia nenhuma marcação de "está na vitrine", e a busca não procurava por marca.

## Definição

Mudança só de frontend, sem banco:

- `src/services/curadoriaEstoque.ts`: `listarCodigosNaVitrine()` lê `codigo_produto` de `vw_showroom_publico` (a leitura anon já existe).
- `src/components/showroom-admin/FotosEstoqueTab.tsx`: carrega a lista inteira uma vez (RPC com `p_termo = null`), filtra no cliente e, depois de um upload, atualiza o conjunto "na vitrine". Filtro padrão = "Na vitrine".
- `src/pages/Admin.tsx`: a aba "Fotos do estoque" passa a se chamar "Peças e fotos", vem primeiro e abre por padrão.

"Atrelar" continua como já era: a foto enviada nesta aba grava direto em `produtos.imagem_showroom_url` daquele produto, e "Gerenciar composição" junta outros produtos à peça.

## Rollback

Reverter o commit do submódulo e republicar no Skip.
