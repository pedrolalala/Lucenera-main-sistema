---
titulo: "SPEC-307 — Central de Solicitações (abertos 13/11): Entrada de NF (parcelas, frete, ST/IPI) e Antecipações"
status: 14/11 — migration 358 APLICADA e 363 (frete) APLICADA; telas do Compras prontas (tsc+build ok), sem commit/deploy; faltam A3 (ST/IPI) e teste
data_ultima_modificacao: 2026-11-14
sistemas_envolvidos:
  - Compras (04-Sistemas/compras-lucenera-3o23t98ee) — Entrada de NF, pedido
  - Contas a Pagar / Contas a Receber (04-Sistemas/retorno-bancario-bradesco-5392a) — Antecipações
  - Banco (migration 358 da SPEC-301; possível migration nova para frete)
---

# SPEC-307

Agrupa 5 pedidos abertos da Central (Debora e Carol, 13/11/2026). Temas A (Entrada de NF) e B (Antecipações).

## A. Entrada de NF (Debora)

### A1. "Sistema não permite registrar a entrada — parcelas" (id 86ec1b0a)
- Print: nota R$ 7.441,97, parcelas somam 7.441,96, "Diferença: OK" e botão cinza.
- **Já corrigido pela SPEC-304** (arredondamento em centavos, commit 6b7ca2e, Compras no ar). As parcelas já são editáveis na tela.
- Sobra a queixa de fundo: a sugestão automática das parcelas não bate com a do fisco/nota (1ª R$ 2.656,20 e resto ~R$ 1.196, contra 3.081,36 + 4×1.090,15 no print). Regra pendente (condição do pedido × ST na 1ª parcela).
- [ ] Confirmar com a Debora que o botão libera e que ela consegue digitar as parcelas da nota.

### A2. Campo de frete na Entrada de NF (id a00b0efd)
- Hoje o "Resumo da nota" tem: produtos (fixo), IPI, ST, Desconto, **Despesas acessórias** e total. Não existe "Frete" separado.
- Não existe coluna de frete em nota de compra no snapshot (só `orcamentos.frete_valor` e `produtos.porc_frete`).
- Proposta: campo **Frete (R$)** no Resumo da nota, somado ao total da nota e às parcelas; gravado em coluna própria da nota de compra (migration nova, com RLS/GRANT conforme AGENTS.md).
- Decisão do usuário (14/11): frete **separado** de "Despesas acessórias".
- [x] Migration 363 aplicada: `notas_fiscais_compra.valor_frete`; `registrar_entrada_nota_compra` grava; `espelho_entrada_nota_compra` devolve.
- [x] Compras: campo Frete no Resumo da nota (soma no total), serviço e linha no PDF do espelho. tsc e build ok.
- [ ] Commit/deploy do Compras e teste da Debora.

### A3. ST e IPI não calculados (id e0cafb5a)
- A tela da Entrada lê `valor_ipi`/`valor_st` por item do **pedido** (`EntradaNotaFiscal.tsx` linhas ~410-417 e 522-529); se o pedido nasceu com 0, a entrada nasce com 0. O pedido recebe esses valores de `ModalGerarCompraItemOrcamento.tsx` (linhas ~437-438) e do cadastro da peça.
- Falta investigar: de onde vêm ST/IPI no cadastro (`porc_ipi`, `tem_st`, `icms_entrada`, `ipi_entrada`) e para quais peças/fornecedores o cálculo sai zerado.
- Relacionado: SPEC-263 (ajuste global de ST/IPI por marca/fornecedor, em desenvolvimento).
- [ ] Pedir à Debora 1 exemplo (pedido/peça) em que ST/IPI deveria aparecer e não aparece.

## B. Antecipações (Carol, ids e32712ee e 1c8a2845)

- Ambos os pedidos (a pagar e a receber/sinal de cliente) já têm **solução escrita na SPEC-301** (migration 358): antecipação nasce em aberto, sem baixa automática; rótulos "Valor do vencimento"/"Data do vencimento"; nº do pedido digitado.
- **Verificado em 14/11 no banco de SP: a migration 358 NÃO está aplicada** (colunas `pedido_numero_manual` e `em_aberto_manual` não existem; `lancar_pagamento_antecipado` ainda com a assinatura antiga). Ou seja, o comportamento reclamado continua no ar.
- Print "sinal baixado automatico": Contas a Receber, título da AGUA AZUL HOLDING LTDA já baixado, que é o comportamento antigo.
- [ ] Aplicar 358 (dry-run já ensaiado), deploy dos dois modos do Retorno Bancário, teste da Carol.
- Pontos de negócio herdados da SPEC-301 (decisão Carol/Debora): Entrada de NF abater antecipação ainda não paga; compensação do Receber (SPEC-270) exigir baixa antes.

## Ordem proposta
1. B: aplicar 358 e publicar (já pronto, só falta autorização).
2. A1: confirmar com a Debora.
3. A2: frete (migration + tela).
4. A3: investigar e corrigir ST/IPI.

## Rollback
B: `rollback.sql` da 358. A2: remover coluna nova e campo da tela.

## Documentos a atualizar ao concluir
CHANGELOG.md, SPEC-301 e SPEC-304 (status), `supabase/docs/relationships.md` se houver coluna nova, memória do projeto.
