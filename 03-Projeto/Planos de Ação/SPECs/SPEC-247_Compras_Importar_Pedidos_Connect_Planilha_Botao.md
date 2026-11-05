---
titulo: "SPEC-247 — Compras: botão para importar pedidos da Connect (planilha) e busca na Entrada de NF"
status: pendente
data_ultima_modificacao: 2026-11-05
sistemas_envolvidos:
  - Compras (aba Pedidos, Entrada de Nota Fiscal)
  - Supabase (função de importação)
---

# SPEC-247 — Compras: botão para importar pedidos da Connect (planilha) e busca na Entrada de NF

## Checklist de Ação

- [x] Busca da Entrada de NF acha `1993 CONNECT` e `PC-LEGADO-N` (número exato, depois "contém"; vários candidatos = lista e pede o número completo) — NO AR 05/11 (Compras `efef826`).
- [x] Aviso na Entrada de NF quando o pedido não tem itens (usar entrada avulsa) — NO AR 05/11.
- [x] Importação inicial dos 42 pedidos da planilha `PedidoCompra_2026-11-05.xlsx` por script (`scripts/importar_pedidos_compra_connect_cabecalho.py`) — APLICADA 05/11.
- [x] Migration 290: função `importar_pedidos_connect_cabecalho(p_pedidos jsonb, p_aplicar boolean)` (rascunho + dry-run em ROLLBACK).
- [x] Migration 290 APLICADA no Supabase real (05/11, com aval do usuário).
- [x] Botão "Importar da Connect (.xlsx)" na aba Pedidos do Compras: escolher arquivo → prévia → confirmar. Código pronto e compilando (`ImportarPedidosConnectDialog.tsx`, `services/importar-pedidos-connect.ts`, `PedidosCompra.tsx`, dependência `read-excel-file@9.3.14`); NÃO publicado (precisa da migration 290 aplicada antes, senão a prévia dá erro).
- [x] Publicar o Compras (wrangler, build com as chaves de São Paulo) e conferir o bundle — NO AR 05/11 (deploy 5c02058f; bundle conferido em São Paulo e com o botão).
- [ ] Fase 2 (fora desta entrega): ler o PDF do pedido da Connect para preencher os ITENS dos pedidos `N CONNECT` (precisa de PDFs reais de exemplo).

### Passos manuais do usuário

- [x] Aprovar a aplicação da migration 290.
- [ ] Testar o botão com a planilha `PedidoCompra_…xlsx` mais recente.
- [ ] Cadastrar no Cadastro os fornecedores que aparecerem em "sem cadastro" (hoje: Metalúrgica IL e Nordecor) e importar de novo.
- [ ] Conferir qual dos dois cadastros de TENSOFLEX é o certo (e unificar o duplicado).
- [ ] Pedir à Marina 2 ou 3 PDFs de pedido de compra da Connect (fornecedores diferentes, com mais de uma página) para a fase 2.

## Objetivo

A Marina precisa achar, na Entrada de Nota Fiscal, os pedidos de compra que ainda estão abertos na Connect (ex.: pedido 1993) e, depois, subir os pedidos da Connect sem digitar. Hoje isso só foi possível porque a IA rodou um script; a tela não tem como importar.

## Decisões aprovadas

- Botão na aba **Pedidos** (não na Necessidade de Compra: ela calcula o que falta comprar; importar pedido já feito é cadastro de pedido).
- Primeiro a planilha (`.xlsx`, que já temos); o PDF com itens vem numa fase 2.
- A planilha só traz cabeçalho (fornecedor, emissão, valor, parcelas): o pedido entra **sem itens, sem parcelas e sem Contas a Pagar**. O financeiro continua vindo da Connect (SPEC-245).
- Número do pedido: `<codigo> CONNECT` (mesmo formato do `1993 CONNECT` criado na tela).
- Status `aprovado` (pedido em aberto na Connect), com `aprovado_por`/`criado_por` = quem importou.
- O usuário confirma numa **prévia** antes de gravar.

## Definição da SPEC

### Estado atual (analisado em 05/11)

- `pedidos_compra` só tem policy de SELECT para `authenticated`; toda escrita é por função `SECURITY DEFINER`. Permissão do Compras para criar: `hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'criar')`.
- Gatilhos em `pedidos_compra`: só auditoria e numeração (nada gera Contas a Pagar; isso é feito pela função `aprovar_pedido_compra`, que a importação NÃO chama).
- `contatos.codigo_legado` é código de **cliente** da Connect, não de fornecedor. Fornecedor casa pelo **nome normalizado** (sem acento, só letras/números, espaços colapsados), `tipo = 'fornecedor'`.
- Entrada de NF por pedido só conclui com itens (`itensChegando.length > 0`). Pedido sem itens usa a entrada avulsa (a tela avisa).

### Banco — migration 290

`public.importar_pedidos_connect_cabecalho(p_pedidos jsonb, p_aplicar boolean DEFAULT false) RETURNS jsonb`

- `SECURITY DEFINER`, `search_path = public`; `REVOKE ALL FROM PUBLIC, anon`; `GRANT EXECUTE TO authenticated`.
- Exige `auth.uid()` e `hub_pode_executar(..., 'necessidade-de-compra', NULL, 'criar')` (`42501` se não tiver).
- Entrada: array de `{codigo_pedido, nm_fornecedor, emissao_pedido (AAAA-MM-DD), vl_nota}`; máx. 500; linha inválida aborta com mensagem.
- Regras por pedido:
  - já existe (`N`, `N CONNECT` ou `PC-LEGADO-N`) → `ja_existem`, não grava;
  - fornecedor sem cadastro → `sem_fornecedor`, não grava;
  - fornecedor com cadastro duplicado → usa o que tem mais pedidos, depois o de menor id, e marca `duplicado: true`;
  - repetido na própria planilha → conta uma vez.
- `p_aplicar = false` devolve só a prévia (nada gravado). `p_aplicar = true` grava tudo numa transação (`ON CONFLICT (numero) DO NOTHING`).
- Retorno: `{aplicado, inseridos, novos[], ja_existem[], sem_fornecedor[]}`.
- Rollback: `DROP FUNCTION`. Os pedidos já gravados saem por `DELETE ... WHERE observacao LIKE 'Importado da Connect (planilha)%'` (sem itens nem notas ligadas).

### Compras (frontend)

- Aba Pedidos: botão **"Importar da Connect (.xlsx)"** ao lado de "Atualizar".
- Janela: escolher arquivo → lê no navegador (`read-excel-file`) as colunas `codigo_pedido`, `nm_fornecedor`, `emissao_pedido`, `vl_nota` (uma linha por parcela; vale a primeira de cada pedido) → chama a função com `p_aplicar = false` → mostra "N novos (R$ total) · M já existem · K sem cadastro de fornecedor (lista)" → **Confirmar** chama com `p_aplicar = true` → recarrega a lista.
- Sem migration aplicada a janela mostra o erro da função (não quebra a tela).
- Deploy: wrangler com `VITE_SUPABASE_URL`/`VITE_SUPABASE_PUBLISHABLE_KEY` de São Paulo no ambiente do build (o `.env` local do Compras ainda aponta para Ohio).

### Análise de ecossistema

- Depende de `contatos`, `pedidos_compra`, `usuarios`/Hub (`hub_pode_executar`). Não toca `projetos`, `orcamentos`, `boletos`, estoque nem financeiro.
- Afeta só Compras. Importa para `AI_DB_CONTEXT.md` do Compras a nova função.
- Não duplica dado: o pedido é a mesma tabela que a tela usa.

### Critérios de aceite

1. Planilha com os 45 pedidos: prévia = 0 novos, 42 já existem, 3 sem cadastro.
2. Planilha com um pedido novo: prévia mostra 1 novo; confirmar grava 1; rodar de novo mostra 0 novos.
3. Usuário sem permissão de criar pedido recebe "Sem permissão" e nada grava; `anon` não executa a função.
4. Nenhum Contas a Pagar, parcela ou item é criado.
5. `1993` na Entrada de NF encontra `1993 CONNECT`.

## Realizado

### 2026-11-05

- Busca da Entrada de NF corrigida e publicada (Compras `efef826`); aviso de pedido sem itens.
- 42 pedidos importados por script (R$ 251.551,89); 3 ficaram sem fornecedor cadastrado (1856, 1976 Metalúrgica IL; 1964 Nordecor).
- SPEC criada. Migration 290 escrita (`up.sql`, `rollback.sql`, `dry_run.sql`) e testada no banco real em ROLLBACK: prévia não grava; grava e é idempotente; itens/parcelas/transações ficam iguais; sem permissão = 42501; `anon` bloqueado; valor negativo recusado. Critério de aceite 1 conferido com a planilha real (0 novos, 42 já existem, 3 sem cadastro: 1856, 1964, 1976). Migration NÃO aplicada.
- Migration 290 APLICADA e Compras publicado (deploy 5c02058f). Falta o usuário testar o botão na tela com a planilha.
- Botão e janela de prévia feitos no Compras. `tsc` sem erro nos arquivos novos; build ok; leitura da planilha real conferida (código vem como texto, data `dd/mm/aaaa`, valor numérico).

## Pendências

- [ ] Fase 2: importar o PDF do pedido da Connect para preencher os itens dos pedidos `N CONNECT` (casar peça pelo código do produto, tela de conferência, avisar peça não cadastrada); depende de PDFs reais e de confirmar com o Vinicius que não conflita com a SPEC-244.
- [ ] Cadastrar fornecedores Metalúrgica IL e Nordecor e importar os pedidos 1856, 1976 e 1964.
- [ ] Unificar os dois cadastros duplicados de TENSOFLEX e de STELLA no Cadastro.
