---
titulo: "SPEC-184 — Showroom: tirar peça da vitrine (ocultar) e trazer de volta"
status: concluído
data_ultima_modificacao: 2026-10-08
sistemas_envolvidos:
  - Showroom Lucenera (showroom-qtq8er2dk, Skip 54698)
  - Supabase (vw_showroom_publico + tabela/RPCs novas)
---

# SPEC-184 — Showroom: tirar peça da vitrine (ocultar) e trazer de volta

## Checklist de Ação

- [x] Migration `20261008_187_showroom_ocultar_peca`: tabela `showroom_ocultos`, filtro na `vw_showroom_publico`, RPCs `showroom_ocultar_peca`, `showroom_reexibir_peca`, `showroom_listar_ocultas` (todas com `showroom_cred_ok`).
- [x] `/admin` → aba "Peças e fotos": botão "Tirar da vitrine" nas peças que estão na vitrine; filtro "Ocultas" com botão "Voltar para a vitrine".
- [x] Publicar no Skip 54698 e conferir no site público que a peça some/volta.

### Passos manuais do usuário

- [ ] Testar no /admin: ocultar uma peça, conferir que sumiu do site, trazer de volta.

## Objetivo

Hoje a peça entra na vitrine sozinha (produto ativo + foto do showroom + `estoque_showroom > 0`, estoque vindo do Connect) e não há como tirá-la pelo /admin. O usuário precisa "apagar" peças da vitrine.

## Decisões aprovadas

- (2026-10-08) "Apagar" = **ocultar da vitrine**, reversível. Produto, foto e estoque ficam intactos (o produto é o mesmo cadastro de Orçamentos/Compras/Estoque — nunca excluir).
- A peça oculta continua oculta mesmo que o Connect traga estoque de novo, até alguém clicar "Voltar para a vitrine".

## Definição

- Tabela `public.showroom_ocultos (codigo_produto int PK → produtos.codigo_produto, ocultado_em timestamptz)`. RLS ligada sem policy: só as RPCs `SECURITY DEFINER` mexem nela. A view é do `postgres` (não é `security_invoker`), então lê a tabela normalmente.
- `vw_showroom_publico`: `NOT EXISTS (showroom_ocultos)` nas peças avulsas e no principal dos conjuntos. Mesmas colunas, na mesma ordem.
- Conjunto: ocultar o principal tira o conjunto inteiro; membros não aparecem sozinhos na vitrine.
- Não afeta Cadastro/Orçamentos/Compras/Dashboard (nenhum deles lê `showroom_ocultos`).

## Critérios de aceite

- Peça ocultada some de `vw_showroom_publico` e do site; volta ao reexibir.
- Credencial errada nas 3 RPCs → erro 28000, nada gravado.
- Sync do Connect não traz a peça de volta.

## Realizado

### 2026-10-08

- Migration 187 aplicada após dry-run com ROLLBACK (teste como `anon`: senha errada recusada; ocultar tirou a peça da view 166→165; tabela não legível direto; reexibir voltou a 166). Vitrine seguiu com 166 peças depois de aplicar.
- Showroom Skip 54698 v0.0.18 (`432c11f`) publicado; textos conferidos no bundle de produção. Teste visual pelo usuário pendente.

## Pendências

- [ ] Nenhuma além do checklist.
