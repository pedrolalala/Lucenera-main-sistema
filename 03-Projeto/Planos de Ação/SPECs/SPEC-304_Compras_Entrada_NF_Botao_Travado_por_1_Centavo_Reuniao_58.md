# SPEC-304 — Compras: Entrada de NF com botão travado por 1 centavo (reunião 58, Débora)

Data: 13/11/2026 · Sistema: Compras (Necessidade de Compra → Entrada de NF) · Banco: sem mudança

## Problema
Na Entrada de NF, com nota R$ 7.441,97 e parcelas somando R$ 7.441,96, a tela mostrava "Diferença: OK" mas o botão "Registrar Entrada" ficava cinza.

## Causa
`financeiroOk` comparava `Math.abs(valorNota - usadoTotal - somaParcelas) <= 0.01` sem arredondar; em ponto flutuante 7441,97 − 7441,96 = 0,010000000000218 > 0,01. O painel (`FinanceiroNotaEntrada`) arredonda, a trava não. O banco (`registrar_entrada_nota_compra`, numeric) já aceita 1 centavo.

## Correção
`EntradaNotaFiscal.tsx`: arredondar a diferença em centavos (`r2`) antes de comparar.

## Aceite
Nota 7.441,97 com parcelas somando 7.441,96 (ou ,98) libera o botão; 2 centavos de diferença continua barrando.

## Pendente (não resolvido)
Parcelas sugeridas não batem com as do fisco (1ª R$ 2.656,20; resto ~R$ 1.196): depende de a Carol confirmar a regra (condição do pedido x ST na 1ª parcela).
