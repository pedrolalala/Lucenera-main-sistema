---
titulo: "SPEC-296 — Permissões da Vitória (reunião 54, Vinicius e Vitória)"
status: migration 347 APLICADA em 13/11/2026; falta teste real da Vitória
---
# SPEC-296
Papel novo `estoque_entrada_nf` só para a Vitória (Matheus/Alexandre seguem no `estoque`). Migration `20261113_347_spec293_papel_vitoria_estoque_entrada_nf` (up/rollback).

| Sistema | Nível |
|---|---|
| Consultar Produtos (Cadastro) | ver + editar (sem criar) |
| Orçamentos | ver/criar/editar (como o Matheus, p/ liberar garantia) |
| Venda Parcial | ver/criar/editar (já tinha exceção editar) |
| Entregas | ver/criar/editar (como estava) |
| Controle de Produção / Garantia | ver + criar + editar (liberado depois, migration 348) |
| Compras (Necessidade de Compra) | ver + editar — **só** porque `registrar_entrada_nota_compra` exige `editar`; decisão do usuário (reunião disse "não precisa de compra") |
| Central de Solicitações | ver + criar |
| Movimentação de Peças | não ("por enquanto não") |

Obs.: Orçamentos por equipe (SPEC-200) pode limitar quais orçamentos ela enxerga. Pendente: teste real, CHANGELOG.
