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

**Estoque da Connect suspenso (SPEC-222, 22/10/2026).** `importar_produtos_estoque.py` NAO grava mais
`estoque_total`/`estoque_disponivel` por padrao: o trigger `fn_sync_estoque_itens_from_produtos` sobrescreve
`estoque_itens` (quantidade E quantidade_reservada) e apagaria as entradas de nota fiscal e as reservas das
aprovacoes do sistema novo. SPEC-224 (23/10): `estoque_showroom` tambem fica de fora (o Showroom e do sistema
Movimentacao de Pecas). So use `--incluir-estoque` com decisao explicita do usuario.

**Fornecedor da peca = fornecedor da marca (SPEC-193 B2, decisao 09/10/2026).** O import de
Produtos NUNCA grava fornecedor por produto. No fim dele roda `conferencia_marca_fornecedor.py`
(tambem roda sozinho), que so le a planilha (`CodFornecedor`/`nmFornecedor`) e o banco e gera
`scripts/logs/conferencia_fornecedor/conferencia_marca_fornecedor_<data>.xlsx` com: marcas sem
fornecedor (e o sugerido pela planilha), marcas cujo fornecedor na planilha e outro, e pecas com
fornecedor diferente do da marca. Correcao e manual (Cadastro/Connect). `contatos` nao tem o
codigo da Connect: o casamento e pelo nome normalizado; contatos duplicados contam como o mesmo.

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

- **DEV TROCA = DEVOLUÇÃO** (decisao do usuario, 2026-10-07): duplicata de
  despesa com `tipo_pagamento = 'DEV TROCA'` cujo `cod_apropriacao` nao
  resolve no plano (a Connect manda `1`, sem nome, em ~metade delas) entra
  com a categoria DEVOLUCAO (`codigo_connect = 2020028`). Categoria valida
  vinda da planilha vence. Backfill do historico feito no mesmo dia: 505
  negociacoes (R$ 1.793.930,18) -> DEVOLUCAO; nao ha trigger em
  `negociacoes`. ContaReceber nao traz `tipo_pagamento = 'DEV TROCA'`.

- **`LUCE NERA` = MANOELLA** (`EMPRESA_LUCE_NERA_ID`). Mapeamento permanente do
  Connect, nao e decisao. Duplicata genuinamente nova -> criada sob MANOELLA.

Criterio de sucesso da conferencia: receita e despesa **realizadas** (status
pago, por `dt_pagamento`) batem mes a mes com a planilha, e "Em Aberto" (por
`dt_vencimento`, `pago==0`) bate com a planilha. Diferenca esperada: R$ 0,00.

## SPEC-157 (2026-09-22): reconciliacao/espelho formal

Biblioteca compartilhada `scripts/sync_connect_common.py` usada pelos 4
scripts (`importar_contas_pagar_receber.py`, `importar_pedido_compra.py`,
`importar_produtos_estoque.py`, `importar_produtos_novos.py`). Invariantes
novas, **nao podem ser removidas**:

- **Descoberta automatica do arquivo mais recente** (`descobrir_planilha_mais_recente`)
  — nao precisa mais editar constante de caminho a cada exportacao nova. Pega o
  maior nome de arquivo `<Prefixo>_*.xlsx` na pasta (funciona porque o padrao
  de nome e' `Prefixo_AAAA-MM-DD.xlsx`).
- **Pre-validacoes obrigatorias antes de tocar no banco**: cabecalho (so
  presenca das colunas usadas — os scripts leem por NOME, nunca por posicao,
  entao ordem de coluna no export NAO importa e nunca deve voltar a ser
  validada), minimo de linhas (piso de seguranca contra export vazio/truncado,
  NUNCA expectativa de volume), e unicidade da chave natural na propria
  planilha. Qualquer falha aborta ANTES de qualquer escrita — ver
  `ImportacaoAbortada`.
- **Produtos (estoque)**: soft delete via `produtos.ativo` — produto que
  estava ativo e saiu do export atual e' inativado (`ativo=false`); produto
  que volta a aparecer e' reativado (`ativo=true`). Roda dentro da MESMA
  transacao que ja desligava os 2 triggers de preco (nao mudou).
- **Produtos (novos)**: insert virou `upsert(..., on_conflict="codigo_produto", ignore_duplicates=True)`
  — idempotente de verdade (rodar 2x nao duplica nem erra).
- **Pedido de compra**: coluna `pedido_compra.vigente` (migration
  `20260922_159_sync_connect_reconciliacao`, APLICADA no Supabase real em
  2026-10-07; no 1o run 155 de 204 pedidos viraram `vigente=false`) — pedido que sai do export vira
  `vigente=false`, NUNCA DELETE (decisao de 2026-07-22, a planilha nao traz
  historico). O script detecta em runtime se a coluna ja existe
  (`_coluna_vigente_existe`) e degrada de forma segura (sem marcar
  nao-vigencia) se a migration ainda nao foi aplicada — nunca falha por
  coluna faltando. `num_parc` vazio e' normalizado para 1 (nunca NULL) —
  `staging_pedido_compra` ganha `UNIQUE(codigo_pedido, num_parc)` na mesma
  migration.
- **Contas a pagar/receber**: a fase de gravacao (stg_duplicatas_vigentes +
  negociacoes novas + transacoes novas/atualizadas + os 3 cancelamentos)
  roda **dentro de uma unica transacao `psycopg2`** — tudo ou nada. As
  negociacoes novas usam sentinela `("NOVA", chave)` em `neg_map` durante o
  calculo em Python (em vez de criar via REST antes do resto) e so ganham id
  real dentro da transacao, via `INSERT ... ON CONFLICT (empresa_id,
  cod_duplicata, tipo) DO UPDATE ... RETURNING id` — nunca REST insert solto
  fora da transacao. O cancelamento (`status_pago=2`) continua sendo a
  politica pra "ausente na planilha" (NAO virou DELETE fisico — decisao
  confirmada com o usuario em 2026-09-22, motivo:
  `retorno_bancario_registros.transacao_id` referencia `transacoes(id)` sem
  `ON DELETE CASCADE`, e apagar destruiria historico de conciliacao
  bancaria).
- **Log estruturado**: cada run grava um JSON em `scripts/logs/sync_connect/`
  com contadores por modulo (inseridos/atualizados/removidos ou
  inativados/cancelados/ignorados/erros) e timestamp — usar pra conferencia
  do gestor em vez de so ler o stdout.

Ver `03-Projeto/Planos de Ação/SPECs/SPEC-157_Reconciliacao_Espelho_Import_Connect.md`
pra decisoes completas e pendencias (migration 159 aplicada em 2026-10-07).

**Rede sem IPv6**: o host direto `db.<ref>.supabase.co` so resolve IPv6. Se
`psycopg2.connect` falhar com "could not translate host name", usar o session
pooler IPv4 (`aws-1-us-east-2.pooler.supabase.com:5432`, usuario
`postgres.<ref>`) trocando `SUPABASE_DB_URL` no modulo `_supabase_client`
antes de chamar o script (o `.env` e' carregado com `override=True`).

## Sync 2026-09-29: 3 falsos "alterados" corrigidos (nao remover)

Primeira execucao real da versao SPEC-157. O dry-run logo apos gravar tem de
dar **zero pendencias** nos 4 scripts — e' o teste de idempotencia; se nao
der, ha comparacao errada.

- **Contas**: `transacoes` existentes vem do DataFrame com NULL = NaN e
  `NaN or None` continua NaN — toda parcela sem `dt_pagamento` parecia
  alterada (2.946 falsos positivos de 2.947). Correcao:
  `trans.astype(object).where(pd.notna(trans), None)` logo apos carregar.
- **Produtos (estoque)**: `percentual_lucro` e' `numeric(,2)` e a planilha
  manda 3 casas; a diferenca 0,005 saia 0,0050000000000x em ponto flutuante e
  estourava a tolerancia. `close_enough` agora usa `tol + 1e-9`.
- **Pedido de compra**: `valor_nota`/`valor_duplicata` sao `numeric(,2)` e a
  planilha manda 3 casas; a comparacao agora arredonda para 2 casas
  (`_cmp`, mantendo 0 == vazio como antes).

Conferencia 29/09: recebido/pago jun-set e em aberto set-dez da planilha x
`v_financeiro_realizado` = R$ 0,00 de diferenca. `cod_apropriacao = 1` (sem
nome) continua sem categoria — 14 despesas novas (R$ 48.186,30) com
`tipo_pagamento = 'DEV TROCA'` ligadas a clientes/projetos; decisao do usuario
pendente desde 21/09.
