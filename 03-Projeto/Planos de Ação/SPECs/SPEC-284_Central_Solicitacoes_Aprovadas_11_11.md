---
titulo: "SPEC-284 — Solicitações aprovadas na Central (11/11): PDF da venda, rodapé, Fatura/Duplicata e número no endereço"
status: código do rodapé local; migration 337 redigida e testada em ROLLBACK, NÃO aplicada; nada publicado
data_ultima_modificacao: 2026-11-11
sistemas_envolvidos:
  - Edge Function generate-report (supabase/functions/generate-report)
  - Banco (financeiro_titulos, vw_financeiro_duplicatas)
  - Separação Parcial / CRM (só diagnóstico)
---

# SPEC-284 — As 4 solicitações `aprovado` de 11/11

## 1. Vencimentos divergentes no PDF da venda (13:25, Vendas)
Já tratado pela **SPEC-277** (parcelas do financeiro no PDF; commit ccbab40). Falta só **publicar `generate-report`** (versão 5 no ar). Esta SPEC não muda nada aqui.

## 2. Rodapé do orçamento (17:07)
Pedido: manter as observações atuais e acrescentar que não há mão de obra de instalação.
- `generate-report/index.ts`: nova linha **"4- A LuceNera não possui mão de obra de instalação."** depois das 3 observações existentes.
- Sai junto com a publicação da função do item 1 (uma única publicação).

## 3. NF virando Duplicata em vez de Fatura (17:19, Contas a Pagar)
- Causa: em título de NF, `financeiro_titulos.documento` = nº da NF, e `vw_financeiro_duplicatas.numero_documento` (coluna "Duplicata") usa `documento`. A "Fatura" já saía certa (nº da NF).
- Migration `20261111_337_spec284_duplicata_automatica_nf_compra`: coluna `numero_duplicata`, trigger `BEFORE INSERT` que numera títulos `nota_fiscal_compra` pela sequência nativa `seq_cod_duplicata_nativa` (900000+, não colide com a Connect), backfill dos 7 títulos de NF existentes por ordem de lançamento, e a view passa a mostrar `numero_duplicata` em `numero_documento`. Fatura não muda.
- Dry-run (ROLLBACK) sem erro: 7 linhas atualizadas, view recriada. `rollback.sql` restaura a view antiga e remove coluna/trigger.
- **Atenção:** a sequência é global, então a duplicata da NF segue a ordem dos lançamentos nativos (inclui os de orçamento), não uma contagem só de NFs. Se a Débora quiser 1, 2, 3 só das NFs, é outra sequência.
- Pendente: confirmar com a imagem anexada da solicitação que "duplicata automática" é esse formato; aplicar a 337.

## 4. Endereço de entrega sem o número (18:58, CRM / Separação)
- **Não é bug de código:** a Separação já monta rua + número + complemento + bairro + cidade (`SeparacaoParcialPage.tsx`, função de endereço). O número some quando o cadastro em `contatos` não tem número.
- Dados: 2.766 de 4.277 contatos têm endereço de faturamento sem número (herança da Connect); 3 dos 35 com endereço de entrega estão sem `numero_entrega`.
- Sem alteração de código. Decisão pendente do usuário: tornar o número obrigatório no CRM quando houver rua, e/ou completar os cadastros.

## Checklist
- [x] Rodapé alterado no código
- [x] Migration 337 escrita e testada em ROLLBACK
- [ ] Aplicar a 337 (autorização)
- [ ] Publicar `generate-report` (itens 1 e 2) e reimprimir a VENDA-8508
- [ ] Decidir item 4
- [ ] Marcar as 4 solicitações na Central após teste

## Rollback
Item 2: reverter a linha. Item 3: `rollback.sql` da 337.
