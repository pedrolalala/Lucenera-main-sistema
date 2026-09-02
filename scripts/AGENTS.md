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
  (`"1.409,76"`) e US (`"3709.9"`). Na planilha Produtos o `CustoTotal` vem em
  BR e o `ValorVenda` em US. Nunca voltar ao `.replace(",", ".")` simples
  (zerava `custo_total` de todo produto >= R$ 1.000).

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
