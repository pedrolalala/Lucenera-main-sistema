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
- [x] Fase 2 — código pronto e testado, NÃO aplicado/publicado: botão "Importar pedido da Connect (PDF)" que lê o PDF do pedido (peças) e completa o `N CONNECT` sem itens ou cria o pedido. Migration 291 (`20261105_291_spec247_importar_pedido_connect_pdf`, função `importar_pedido_connect_pdf`), parser por posição (`src/lib/pedido-connect-parser.ts`), leitor `pdfjs-dist@4.10.38` (`src/lib/pdf-pedido-connect.ts`), janela `ImportarPdfPedidoConnectDialog.tsx`.
- [x] Migration 291 APLICADA no Supabase real (05/11, com aval do usuário).
- [x] Publicar o Compras com o botão de PDF — NO AR 05/11 (deploy 4ded0eb4; bundle em São Paulo, os 2 botões e o worker do pdf.js conferidos em produção).

### Passos manuais do usuário

- [x] Aprovar a aplicação da migration 290.
- [ ] Testar os botões na tela: planilha `PedidoCompra_…xlsx` e PDFs de pedido da Connect (com a conta da Marina).
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

### Fase 2 — PDF do pedido da Connect (com as peças)

Layout lido (igual nos PDFs reais `1743 - STELLA - FOCO` e `1765 - ILUMINAR - ISLIGHT`, em `01-Documento/02 - Descritivo Connect/PDF/`): cabeçalho (empresa, Pedido, Fornecedor, Pagamento, Data Emissão/Entrega, "Referente a…") + tabela `Item | Produto | Referencia | Descrição | Qtd | UN | Vl. Unit. | Vl. Total` + rodapé (`BC ICMS`… `VL Total Nota`). **"Produto" = `produtos.codigo_produto`** (a referência do PDF = `produtos.referencia`, usada só para avisar divergência).

- **Leitura no navegador** (`pdfjs-dist`, por posição das colunas; só a descrição quebra em 2+ linhas). O PDF não sai do computador; só os dados lidos vão para o banco. PDF sem texto (scan) = erro claro.
- **Função `importar_pedido_connect_pdf(p_pedido jsonb, p_aplicar boolean)`** (SECURITY DEFINER, mesma permissão `necessidade-de-compra/criar`, sem `anon`):
  - pedido `N CONNECT` existe **sem itens** (os da planilha) → `completar`: grava os itens e só preenche o que está vazio (entrega, condição de pagamento, empresa); **não troca valor, fornecedor nem status**;
  - pedido não existe → `criar` (`N CONNECT`, aprovado, valor = Total da Nota, fornecedor pelo nome normalizado, empresa pelo nome; `LUCE NERA` = `MANOELLA`);
  - pedido já tem itens, ou está cancelado/concluído → não grava;
  - **peça sem cadastro bloqueia o pedido inteiro** (nada é gravado) e é listada para cadastrar;
  - itens: `quantidade` e `custo_unitario` (= Vl. Unit.); sem parcelas nem Contas a Pagar.
- **Tela**: vários PDFs de uma vez; uma ficha de prévia por pedido (ação, peças lidas, avisos) e só grava ao confirmar. Se o PDF não bate (soma dos itens ≠ Total da Nota, item ilegível) a ficha fica bloqueada: melhor não importar do que importar torto.
- **Efeito de negócio (decidir/avisar):** `vw_necessidade_compra_pedidos_abertos`, `vw_necessidade_compra_pedido_detalhe` e `vw_necessidade_compra_item_orcamento` leem `pedido_compra_itens`. Os pedidos da Connect com peças passam a contar como **pedido em aberto/pendente de entrega** na Necessidade de Compra (evita comprar de novo o que já foi pedido na Connect). Ao dar entrada pela Entrada de NF o estoque do sistema novo sobe, como em qualquer pedido do sistema.
- **Não coberto:** o PDF que o **próprio sistema novo** gera para o fornecedor ("Pedido de compra para…", SPEC-211/214) tem outro layout; esse pedido já está no banco e não precisa ser importado.
- Rollback: `DROP FUNCTION` (ver `rollback.sql`; itens já gravados saem por `DELETE` conferido).

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
- Fase 2 (PDF) desenvolvida e testada; migration 291 APLICADA e Compras publicado (deploy 4ded0eb4) — falta o usuário testar na tela com PDFs de pedido: parser conferido nos 2 PDFs reais (12 peças = R$ 17.545,12; 4 peças = R$ 2.241,41); os 16 códigos de peça existem no cadastro (e as referências batem); migration 291 testada em ROLLBACK (11 casos: criar, completar sem mudar valor, já tem itens, peça sem cadastro, fornecedor sem cadastro, aviso de soma, sem permissão, `anon`) e ponta a ponta com os PDFs reais (pedidos criados com empresa, entrega e pagamento corretos). `tsc` sem erro nos arquivos novos e build ok (`pdf.js` em arquivo separado, só carrega ao usar o botão).
- Migration 290 APLICADA e Compras publicado (deploy 5c02058f). Falta o usuário testar o botão na tela com a planilha.
- Botão e janela de prévia feitos no Compras. `tsc` sem erro nos arquivos novos; build ok; leitura da planilha real conferida (código vem como texto, data `dd/mm/aaaa`, valor numérico).

## Pendências

- [ ] Fase 2: importar o PDF do pedido da Connect para preencher os itens dos pedidos `N CONNECT` (casar peça pelo código do produto, tela de conferência, avisar peça não cadastrada); depende de PDFs reais e de confirmar com o Vinicius que não conflita com a SPEC-244.
- [ ] Cadastrar fornecedores Metalúrgica IL e Nordecor e importar os pedidos 1856, 1976 e 1964.
- [ ] Unificar os dois cadastros duplicados de TENSOFLEX e de STELLA no Cadastro.
