---
titulo: "SPEC-298 — Número de venda por tipo de operação (DEV, CSCE, CSCS, USC, BR) ao efetivar"
status: migration 355 APLICADA em 13/11/2026 (retroativo feito); Orçamentos (rótulos) e generate-report (PDF) alterados, sem commit de deploy
data_ultima_modificacao: 2026-11-13
sistemas_envolvidos:
  - Banco (orcamentos.numero_venda, gatilho, sequências)
  - Orçamentos (04-Sistemas/gestao-financeira-clone-544cb (1)) — rótulo na lista e no cabeçalho
  - Edge Function generate-report — rótulo no PDF
---

# SPEC-298

**Origem:** solicitação da Carol na Central em 13/11/2026 14:10, "ORÇAMENTOS QUE PRECISAM GERAR NUMERO DE VENDA AO EFETIVAR": devolução, entrada/saída casa cor, uso/consumo e bonificação devem gerar número de venda como a venda normal, "sinalizado conforme tipo", e os já efetivados devem ser atualizados.

## Decisões do usuário (13/11/2026)
1. Formato com **sequência própria por tipo**: `DEV-0001` (devolução/troca dev), `CSCE-0001` (casa cor entrada), `CSCS-0001` (casa cor saída), `USC-0001` (uso e consumo), `BR-0001` (bonificação).
2. **Retroativo: sim**, na ordem da efetivação, sem mexer em financeiro, estoque ou títulos.
3. Reverte a SPEC-136 (devolução sem número) e a parte "sem número de venda" da SPEC-255 **só para esses tipos**. GARANTIA, DESCARTE, EMPRÉSTIMO e demais continuam sem número de venda.

## Feito
- [x] Migration 355 (aplicada): 5 sequências, função `prefixo_numero_operacao`, gatilho `trg_3_numero_venda_por_tipo` (BEFORE UPDATE OF status, quando vira "Orçamento Aprovado" sem `numero_venda`). **Nenhuma função de aprovação foi reescrita.** A sequência das vendas (`VENDA-%`) não é afetada.
- [x] Retroativo: BR-0001 (ORC-0021), BR-0002 (ORC-0010), BR-0003 (ORC-0038), DEV-0001 (ORC-0009), DEV-0002 (ORC-0026), DEV-0003 (ORC-0042), USC-0001 (ORC-0016). De/para em `backup.spec298_numero_venda_por_tipo`.
- [x] Pendentes de aprovação (ORC-0049, ORC-0053, ORC-0054, ORC-0060) recebem o número quando forem efetivados (ensaio: ORC-0053 → BR-0004, ORC-0049 → DEV-0004 antes do ROLLBACK).
- [x] Rótulo acompanha o tipo (`rotuloNumeroVenda`): lista e cabeçalho do orçamento ("Devolução: DEV-0003") e PDF ("Devolução" em vez de "Venda").
- [ ] Deploy: Orçamentos (wrangler) e Edge Function `generate-report` (precisa de `supabase login`); reimprimir o PDF do ORC-0026 para conferir.
- [ ] Carol testar (efetivar uma devolução nova e uma bonificação).

## Atenção
- Os títulos do financeiro já criados (`financeiro_titulos.documento`, ex.: `ORC-0042`) **não foram renomeados**; a Duplicata da devolução continua com o número do orçamento. Se ela quiser DEV-0003 na Contas a Receber, é outra etapa.
- A tela de devolução (`devolucoesService`) já filtra `natureza_operacao='venda'`, então não oferece os novos números como venda de origem.
- CSCE/CSCS: ainda não há orçamento desses tipos; o primeiro nasce em CSCE-0001/CSCS-0001.

## Rollback
`rollback.sql` da 355: remove o gatilho e volta `numero_venda` a NULL só dos que receberam número por esta migration (usa o de/para); as sequências ficam.
