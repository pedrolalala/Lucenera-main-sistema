# Instrucao da Pasta scripts

Esta pasta guarda scripts administrativos e de manutencao do repositorio central: clonar/registrar submodules e importar dados pontuais para o Supabase.

## Regras

- Scripts que acessam o Supabase real devem usar o `.env` geral da raiz do repositorio central (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_URL`). Nunca hardcodar credencial.
- Script de importacao pontual (ex.: `importar_razao_social_clientes.py`) deve ser idempotente ou documentar claramente que roda uma unica vez.
- `submodules-clone-all.sh` e `submodules-register.sh` sao os unicos scripts que devem alterar `.gitmodules`; qualquer novo sistema deve passar por eles em vez de `git submodule add` manual sem registro.
- Nunca commitar `.env`, dump de banco ou credencial dentro desta pasta.

## Antes de rodar ou criar um script aqui

1. Confirmar que o `.env` da raiz existe e esta correto.
2. Ler `../00-Contexto/` para entender se a acao ja e coberta por um fluxo existente.
3. Rodar em modo leitura/dry-run primeiro quando o script alterar dados de producao.

## Ciclo de sincronizacao Connect (ContaPagar/ContaReceber, PedidoCompra, Produtos)

Roda toda vez que o usuario disponibiliza planilhas novas em
`01-Documento/01 - Planilhas/`. Fluxo: bumpar a constante de caminho nos 3
scripts (`importar_contas_pagar_receber.py`, `importar_pedido_compra.py`,
`importar_produtos_estoque.py`) para a data nova -> `--dry-run` em cada um
(conferir que os numeros batem com a execucao real) -> gravar -> conferir o
Dashboard contra a planilha.

**Invariantes que os scripts JA implementam e NAO podem ser removidas** (cada
uma corrigiu um bug real de divergencia planilha x Dashboard):

- **`to_numeric_br` (Produtos)** trata os DOIS formatos: BR com milhar
  (`"1.409,76"`) e US (`"3709.9"`). Na planilha Produtos o custo unitário vem em
  BR e o `ValorVenda` em US. Nunca voltar ao `.replace(",", ".")` simples
  (zerava `custo_total` de todo produto >= R$ 1.000).

- **Coluna do custo unitário mudou de nome no export de 2026-09-10**: era
  `CustoTotal`, virou `vlCustoTotal` (mesmo dado, mesmo formato BR). O script já
  lê `vlCustoTotal`. Se um export futuro voltar a `CustoTotal`, o script quebra
  com KeyError — checar o nome da coluna antes de rodar.

- **`ncm` / `cest` (Produtos)** são sincronizados desde 2026-09-10 (SPEC-132
  Fase A). São TEXTO — `cest` tem zero à esquerda (`"0900100"`), nunca converter
  para número. Regra: só grava quando a planilha traz valor; planilha vazia
  **não apaga** ncm/cest que já exista no banco (o export Connect pode estar
  incompleto). Backfill inicial: ~4.344 ncm, ~1.099 cest.

- **Campos fiscais (SPEC-132 Fase B, 2026-09-10)** — o import de Produtos sincroniza:
  `icmsST→porc_st`, `ipi→ipi_entrada`, `despesas→porc_despesas`, `desconto→porc_desconto`,
  `frete→porc_frete`, `GrupoFiscalNContribuinte→grupo_fiscal_nao_contribuinte`,
  `GrupoFiscalRevenda→grupo_fiscal_revenda` (2 colunas de texto, migration 131). Formato US
  (sem milhar). `close_enough` é **NaN-safe** — `pandas.to_dict` transforma NULL de coluna
  numérica em NaN e `NaN or 0 == NaN`; sem o guard, todo campo nulo parecia "≠ 0" e o script
  gravava 0 em tudo.
- **Preço NÃO muda.** `ipi_entrada`/`porc_despesas`/`porc_desconto` estão no `UPDATE OF` do
  trigger `trg_atualizar_preco_venda`. O script grava o campo fiscal e **logo em seguida
  regrava `preco_venda`** com o valor de antes (não está no `UPDATE OF` → não redispara), e
  no fim faz um passe de verificação/reparo re-lendo `preco_venda` dos produtos afetados.
  O trigger **não** é alterado nem desligado. `icms_entrada` **não** é escrito (evita a
  divergência form × trigger: o `PecaForm` usa `porc_st` como "% ST", o trigger usa
  `icms_entrada`). `custo_total`/`valor_venda` seguem vindo da Connect.

- **`importar_contas_pagar_receber.py` sincroniza tambem `vl_parcela`,
  `dt_vencimento`, `dt_emissao`, `vl_frete`, `vl_ipi`** em linha existente
  (nao so status/pagamento). Duplicata renegociada no Connect (valor/vencimento
  novo) precisa refletir no banco, senao o "Em Aberto"/fluxo futuro do Dashboard
  fica com valores antigos.

- **Duplicatas ambiguas** (`(cod_duplicata, tipo)` em >1 empresa): NAO pular.
  Rotear para a negociacao **MANOELLA/preferida** (a mais antiga por `created_at`,
  que a view `v_financeiro_realizado` usa via `rn=1`). Sao recebimentos reais
  (parcelas de datas diferentes do mesmo cliente; ou empresa trocada para acordo
  de RT). Pular = "desconsiderar da soma", que o usuario vetou.

- **Parcelas orfas**: para cada duplicata que ESTA no export atual, cancelar
  (`status_pago = 2`) as `transacoes` cujo `cod_itens_duplicata` NAO esta no
  export. Sao parcelas substituidas/removidas no Connect (e imports antigos
  colaram despesa - COMPRAS-REVENDA, RT, RETIRADA DE LUCRO, ICMS - dentro de
  negociacao `tipo='receita'`). A planilha e a fonte de verdade.

- **`LUCE NERA` = MANOELLA** (`EMPRESA_LUCE_NERA_ID`). Mapeamento permanente do
  Connect, nao e decisao. Duplicata genuinamente nova -> criada sob MANOELLA.

Criterio de sucesso da conferencia: receita e despesa **realizadas** (status
pago, por `dt_pagamento`) batem mes a mes com a planilha, e "Em Aberto" (por
`dt_vencimento`, `pago==0`) bate com a planilha. Diferenca esperada: R$ 0,00.
