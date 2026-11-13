---
titulo: "SPEC-305 — Contas a Pagar/Receber: filtro Tipo data = Pagamento, situação Todos e total Pago correto"
status: pendente
data_ultima_modificacao: 2026-11-13
sistemas_envolvidos:
  - Retorno Bancário (Contas a Pagar e Contas a Receber, mesmo código: ConsultarDuplicatas)
---

# SPEC-305 — Contas a Pagar/Receber: filtro Tipo data = Pagamento, situação Todos e total Pago correto

## Checklist de Ação

- [x] Tipo data ganha a opção **Pagamento** (Contas a Receber e Contas a Pagar); o período Data início/final filtra por `data_pagamento`.
- [x] Contas a Pagar ganha a situação **Todos** (Contas a Receber já tinha).
- [x] Total **Pago** do rodapé soma só o dinheiro recebido/pago (`valor_pago`); parcela quitada sem caixa (baixa interna, valor pago 0) não volta a valer o valor da parcela.
- [x] Publicar Contas a Receber e Contas a Pagar (wrangler, 13/11) — commit 129a4b5.
- [x] Migration 360 (APLICADA 13/11): título legado da duplicata 2988 de ISLIGHT para FOCO ILUMINACAO (como na planilha).
- [x] Migration 361 (APLICADA 13/11; os 6 `sao_paulo` ficam como estão, decisão do usuário): `perfil = 'ribeirao'` nos 10.396 títulos legado_connect sem perfil (planilha: tudo RIBEIRAO PRETO); gera 10.396 eventos no histórico; 6 títulos `sao_paulo` do Contas a Pagar (duplicatas 7524, 7525, 7570, 7591, 7610, 7677) divergem da planilha e não são tocados.
- [x] Migration 362 (APLICADA 13/11, decisão do usuário): o que ainda estava sem perfil (39 títulos nativos + 44 boletos) vira `ribeirao`; backup em `backup._bkp_spec305_perfil_restante`.
- [ ] Conferir janeiro/2026 na tela contra a Connect.

### Passos manuais do usuário

- [ ] Conferir na tela: Receber, FOCO ILUMINACAO, perfil Ribeirão, Pago, vencimento 01–31/01/2026 → Total Parcela R$ 155.697,81 e Pago R$ 132.728,18.

## Objetivo

Pedido do Vinicius (reunião): no Contas a Pagar e no Contas a Receber o "Tipo data" só tinha Vencimento e precisa ter também Pagamento; o "Tipo situação" do Contas a Pagar não tinha Todos. No teste de janeiro/2026 o Pago da tela (R$ 155.871,32) não batia com a Connect (R$ 132.728,18).

## Decisões aprovadas

- Reverte o "sem Todos no Contas a Pagar" da SPEC-245 (reunião 04): pedido novo do Vinicius.
- Na Connect, parcela quitada por baixa interna entra no Total Parcela mas não no Pago; o sistema novo segue a mesma regra.

## Achados da investigação (13/11/2026)

- A view `vw_financeiro_duplicatas` já devolve `valor_pago` certo: soma R$ 132.728,18 nas 45 parcelas (inclui juros; 5 baixas internas com 0). Nada a mudar no banco.
- Causa do Pago errado: `ConsultarDuplicatas.tsx` somava `valor_pago || valor`, e o `0` caía no valor da parcela.
- Pendência separada: `perfil` é NULL em todas as duplicatas do financeiro novo; o filtro Perfil (Ribeirão/São Paulo) não encontra nada nelas. A decidir com o usuário.

## Rollback

Reverter o commit de `src/pages/ConsultarDuplicatas.tsx`. Sem migration.
