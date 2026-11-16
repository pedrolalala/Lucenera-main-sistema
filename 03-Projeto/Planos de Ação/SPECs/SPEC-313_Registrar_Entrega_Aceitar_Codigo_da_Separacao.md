---
titulo: "SPEC-313 — Registrar Entrega aceita o código que aparece na Separação"
status: concluida
data_ultima_modificacao: 2026-11-16
sistemas_envolvidos:
  - Logística (lucenera-logistics-b7cd1)
---

# SPEC-313 — Registrar Entrega aceita o código que aparece na Separação

## Checklist de Ação

- [x] Pedido do usuário (16/11): o Matheus tentava dar baixa digitando `ORC-0080-P1` e a tela respondia "Código inválido".
- [x] Busca nova `buscarParaRegistro` (`useSeparacoes.ts`): código da entrega/parcial, número da venda e código da obra com ou sem ponto.
- [x] Tela `RegistrarEntregaPage.tsx`: sem validação de formato; lista para escolher quando o código bate com mais de uma entrega; Enter busca.
- [x] Status "Cancelado" bloqueado (além de recusado, material solicitado, pendente e finalizado).
- [x] Publicado (logistica-lucenera, commit b32c0eb) e CHANGELOG.
- [ ] Teste do Matheus.

## Causa

- A tela só aceitava `LUC-NNNN` ou 5–6 dígitos; as parcelas usam `ORC-0080-P1`, `5777-P1` etc.
- `codigo_obra` é gravado com ponto (`23.230`), então `23230` nunca batia.
- `maybeSingle()` devolvia vazio quando a obra tinha mais de uma separação.

## Regra

Aceita `numero_entrega` (igual ou `<código>-P%`), `numero_venda` e `codigo_obra` (`23.230`, `23230`). Normaliza maiúsculas, espaços e `Ç`→`C`. Se houver várias, ignora finalizadas/canceladas quando existir alguma aberta; se ainda sobrar mais de uma, o usuário escolhe.

## Banco

Sem mudança.

## Rollback

Reverter o commit b32c0eb do lucenera-logistics e republicar.
