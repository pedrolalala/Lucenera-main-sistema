# Relatório 05/11 — Financeiro: receita em dobro e estrutura definitiva (SPEC-246)

## 1. O que descobri (somente leitura)
A receita do sistema era maior que a da planilha da Connect (6.623 parcelas ativas contra 5.064; pago R$ 32,56 mi contra R$ 27,91 mi). A causa:

- **1.572 parcelas gravadas como receita são cópias exatas de despesas** (mesmo `cod_itens_duplicata`, valor e vencimento de uma despesa ativa) e **não existem na planilha ContaReceber de 05/11**.
- Vieram das cargas de 29/06 (a maioria, FOCO e ISLIGHT) e 08/05. Somam **R$ 4.505.280,87** (R$ 4.443.892,00 pagos) contadas **como receita e como despesa**.
- Explicam também os **28 códigos duplicados** da receita: depois de tirar as cópias, **restam 0 duplicados**.
- Nenhuma dessas parcelas bate com uma linha da planilha de receber, e a despesa nunca muda.
- Sobram 82 parcelas pagas de 08/05 (2024–2025) sem par na planilha. Não são cópias; ficam como histórico e viram pendência de conferência, **não foram tocadas**.

Ver também a regra de coerência: a própria Connect usa contas de tipo "despesa" no Receber e "receita" no Pagar. Por isso a coerência plano × tipo é **alerta** para o legado, não trava.

## 2. O que foi FEITO (aplicado e conferido)
- **Cópias de despesa canceladas** (`corrigir_receitas_copia_de_despesa.py --aplicar`, aplicado pelo usuário): 1.572 parcelas, backup `backup._bkp_transacoes_receita_copia_despesa_20261105_155220`. Receita ativa 6.623 -> 5.051 parcelas (R$ 43,03 mi -> R$ 38,52 mi; pago R$ 32,56 mi -> R$ 28,11 mi); despesa inalterada; duplicados 0.
- **Conferência diária reexecutada: BATE** nos dois lados. Em aberto igual à planilha (Receber 459 · R$ 2.851.487,96; Pagar 1.238 · R$ 4.082.025,35), 0 linhas ausentes, 0 diferenças nos 6 campos críticos e espelho igual.

## 3. APLICADO em 05/11 (pelo usuário) e conferido
1. **Migration 284** aplicada e verificada no banco: marco do financeiro (05/11), gatilho do código legado, índice único `uq_transacoes_tipo_cod_ativa`, tabelas `contato_legado_ids` e `vendas_connect` (vazias) e a view `vw_financeiro_integridade` (11 verificações; 0 cópias de despesa, 0 sem empresa, 0 parcelas sem duplicata). Desfazer: `aplicar_migration_sql.py <pasta> --rollback`.
2. **`preencher_conta_projeto_financeiro.py --aplicar`**: `transacoes.conta_id` +13.517 (cobertura ativa 17.565 de 18.665 = 94%); `negociacoes.projeto_id` +1.329 (2.934 de 6.087 = 48%; 31 ambíguas e 2 sem projeto ficaram de fora). Contagens e somas idênticas antes e depois. Backups: `backup._bkp_transacoes_conta_id_20261105_160731`, `backup._bkp_negociacoes_projeto_id_20261105_160731`.
3. **Carga travada**: importador, corretores e a cadeia `--carregar/--ensaio` da conferência diária recusam rodar (`exigir_financeiro_aberto`). A conferência de leitura continua livre.

## 4. O que ainda falta (nesta SPEC)
- Mapa `contato_legado_ids` (preencher), CPF/CNPJ dos clientes (planilha de Clientes e NF) e `vendas_connect`: tabelas criadas na 284; o preenchimento é um script à parte (próximo lote).
- Baixa/edição/acordo nativos para duplicatas da Connect no front (D13), com os dois sistemas em paralelo.
- Pedido de compra aprovado gerando parcelas no Contas a Pagar (35 de 51 sem parcelas).
- 82 parcelas pagas de 08/05 sem par na planilha: conferir (não são cópias).
- Cadastro "PESSOA NÃO IDENTIFICADA" e 3 contas do plano: aguardando averiguação do usuário.
- Nada foi apagado; nada foi commitado nem enviado por push.

## 5. Batimento do Supabase (05/11, `scripts/bater_supabase_financeiro.py`, somente leitura)
- **Planilha x espelho x sistema FECHA** nas parcelas ativas: Receber 4.969 · R$ 38.273.249,74 · pago R$ 27.905.574,40; Pagar 13.347 · R$ 36.930.520,03 · pago R$ 29.730.336,73. As 95 (Receber, R$ 800.313,96) e 961 (Pagar, R$ 9.861.076,00) linhas restantes têm `pago = 2` na própria Connect e estão canceladas (`status_pago = 2`) no sistema.
- **Fora da planilha (histórico de cargas antigas, pagas):** 82 receitas (R$ 205.950,27) e 267 despesas (R$ 1.083.839,52) — explicam a diferença de pago e ficam fora do dashboard.
- **Duplicidade: 0** (código, cópia receita×despesa, mesma parcela com códigos diferentes, duplicata repetida).
- **Pontos a decidir/tratar (não são erro de carga):**
  1. **2.295 parcelas "pagas" com valor pago zero (R$ 10,76 mi de parcela)** — a própria planilha traz assim (Carteira 935, DEV TROCA 713, Duplicata Gerada 321, Boleto 234, Acordo 64...). O "realizado" do dashboard soma `vl_pago`, então esses R$ não entram. Precisa de regra do financeiro (Filippo): contam como pago? Boleto pago sem valor é suspeito.
  2. **2.456 duplicatas sem nenhuma parcela** (841 despesa, 1.615 receita; criadas em 07/05, 15/05 e 29/06). Não têm dinheiro; 236 têm outra duplicata de mesmo número com as parcelas. Candidatas a limpeza/arquivo, com backup.
  3. 489 parcelas ativas com valor zero; 78 pagas acima do valor (juros/multa); 5 pagas sem data de pagamento; 919 com vencimento antes da emissão (dado da Connect).
  4. 2 boletos ligados a parcela cancelada/inexistente (de 5 boletos).
  5. 1.723 despesas ligadas a contato do tipo "cliente" e 229 duplicatas cujo contato tem nome diferente do da planilha — rever junto do mapa de pessoas.
