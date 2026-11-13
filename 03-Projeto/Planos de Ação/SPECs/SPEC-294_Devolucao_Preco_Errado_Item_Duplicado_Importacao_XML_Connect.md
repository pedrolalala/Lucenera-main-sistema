---
titulo: "SPEC-294 — Devolução com preço unitário errado (R$ 67 em vez de R$ 146,59): item duplicado pela importação do XML da Connect"
status: em andamento
data_ultima_modificacao: 2026-11-13
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone)
  - Banco (Supabase) — orcamentos / orcamento_itens
  - Importação XML Connect (SPEC-243, migration 273)
---

# SPEC-294 — Devolução com preço unitário errado (item duplicado pela importação do XML da Connect)

> **STATUS: RETOMADA (13/11/2026).** Migration 351 redigida e ensaiada com ROLLBACK, APLICADA em 13/11. Migration 352 (importação por referência) também aplicada.
>
> Origem: 13/11/2026, a Ketlyn está fazendo uma devolução da venda **CNX-6001** (orçamento herdado **CNX-8479**) e o preço unitário da peça aparece como **R$ 67**, sendo que a peça custa **R$ 146,59**.

## Checklist de Ação

- [x] A1 (migration 351 APLICADA em 13/11) — Corrigir o orçamento CNX-8479: apagar a linha duplicada de `orcamento_itens` e recalcular o `desconto_global`.
- [ ] A2 — Conferir os outros 3 orçamentos com a mesma duplicata (CNX-6879, CNX-7763, CNX-7861) e corrigir no mesmo script.
- [x] B1 (migration 352 APLICADA em 13/11; importador não reexecutado) — Corrigir a causa na importação do XML (migration 273): casar o item do XML com o item já carregado também pela **referência** quando o código do produto vier em branco.
- [ ] B2 — Travar a regra para não voltar: impedir (índice/validação) duas linhas de `orcamento_itens` iguais no mesmo orçamento Connect.
- [x] C1 — Tela de devolução: **não alterar** (D1 decidida: manter o preço líquido; ver "Decisão D1"). Mostrar também o valor cheio fica como melhoria opcional, só se o usuário pedir.
- [ ] D1 — Investigar os 29 orçamentos Connect cujo `desconto_global` não bate com `soma dos itens do XML − valor_total` (pode ser outra causa).
- [ ] E1 — Registrar no `CHANGELOG.md`.

### Passos manuais do usuário

- [x] Responder a decisão D1 (valor da peça na devolução) — respondida em 13/11/2026 (ver "Decisão D1").
- [ ] Autorizar aplicar a migration no Supabase real depois do ensaio com rollback.
- [ ] Pedir à Ketlyn para refazer a devolução do CNX-6001 depois de A1.

## Objetivo

Fazer a devolução mostrar o valor correto da peça. Hoje o valor sai errado porque o orçamento herdado da Connect tem a peça **duplicada**, o que infla o desconto global e derruba o preço líquido calculado na tela.

## Análise do estado atual (verificada no banco real, somente leitura)

**Venda CNX-6001 / orçamento CNX-8479** (`orcamentos.id = 9ad6bb22-9bd6-4558-bbbc-c0a9391a11b3`):

| Fonte | Itens | Total |
|---|---|---|
| XML da Connect (`connect_xml_item`, orçamento 8479) | **1 linha**: L01, ref STL21423/27, 5 un × R$ 146,59 | R$ 732,95 (total do orçamento no XML: **R$ 670,00**) |
| `projeto_itens` (item da venda, usado na devolução) | 1 linha: 5 un × R$ 146,59 | R$ 732,95 |
| `orcamento_itens` | **2 linhas** de 5 un × R$ 146,59 (criadas 13:27:03 e 13:27:18, a 2ª com `produto_id` nulo) | R$ 1.465,90 |

**Como o R$ 67 nasce** (`devolucoesService.ts` → `getVendasOrigemParaDevolucao` / `descontoGlobalPercentual` / `precoLiquidoDevolucao`):

1. Para venda de origem `connect`, a base do desconto vem de `orcamento_itens` (regra da SPEC-275) = R$ 1.465,90 (inflada pela duplicata).
2. `orcamentos.desconto_global` = **R$ 795,90**, tipo `valor`, gravado pela migration 273 como `soma(orcamento_itens) − total do XML` = 1.465,90 − 670,00.
3. Percentual = 795,90 / 1.465,90 = **54,3%**.
4. Preço líquido = 146,59 × (1 − 54,3%) = **R$ 67,00**.

Com a base certa (R$ 732,95) o desconto real seria R$ 62,95 = 8,6%, e o preço líquido R$ 134,00.

**Causa raiz — migration 273 (SPEC-243), passo "(b2) itens avulsos":** o XML traz `cod_produto` em branco para essa linha (só a referência STL21423/27). O passo (b) não casou com o item já carregado da reserva (casa por produto) e o passo (b2) reinseriu a linha como "item avulso", sem `produto_id`. Em seguida o `desconto_global` foi calculado sobre a soma já duplicada.

**Alcance (contagem em 13/11/2026):**

| Orçamento | Venda | valor_total | desconto_global gravado | base `orcamento_itens` | base `projeto_itens` | itens do XML |
|---|---|---|---|---|---|---|
| CNX-8479 | CNX-6001 | 670,00 | 795,90 | 1.465,90 | 732,95 | 732,95 |
| CNX-6879 | CNX-4865 | 248.472,08 | 60.154,82 | 308.626,90 | 277.989,42 | 299.219,75 |
| CNX-7763 | CNX-5786 | 135.000,00 | 36.184,57 | 171.184,57 | 155.964,13 | 157.390,21 |
| CNX-7861 | CNX-5619 | 200.000,00 | 114.159,14 | 314.159,14 | 238.751,05 | 238.608,94 |

- 4 orçamentos Connect (de 315) têm linha duplicada (6 linhas a mais no total).
- Outros 29 orçamentos Connect têm `desconto_global` que não bate com `soma dos itens do XML − valor_total`. Não foi investigado (item D1 da checklist).

## Decisões aprovadas

- O erro é de **dado** (duplicata na importação), não da conta da tela: a duplicata sai do banco.
- Regra do usuário (13/11/2026): **"o valor da peça é o valor da peça"** — a devolução não pode mostrar um preço que não corresponda ao valor real da peça na venda.
- Decisão do Vinicius (13/11/2026): **se tem desconto, deve vir como desconto** — a devolução continua usando o preço líquido (D1-a). Não mudar a regra de cálculo.
- A SPEC fica **em standby**: nenhuma migration, correção de dado ou alteração de código foi autorizada.
- Regra fixa já existente: planilhas/XML da Connect só enriquecem o documento e **não mexem em quantidade de estoque**; `projeto_itens` (quantidade, saldos, reservas) fica intacto.

## Decisão D1 — qual valor a devolução mostra (RESOLVIDA em 13/11/2026)

**Decisão do Vinicius (relatada pelo usuário): o comportamento está certo — se a venda tem desconto, a devolução deve vir com o desconto.** Vale a opção **D1-a (líquido)**; a regra atual (SPEC-178/182) não muda e a D1-b (valor cheio) fica descartada.

Consequência para esta SPEC: o item C (tela) e qualquer mudança no cálculo do crédito de devolução **não são necessários**. Continua em aberto apenas o ponto de dado: o desconto de 54,3% do CNX-8479 só existe por causa da linha duplicada (o desconto real da venda no XML é R$ 62,95 = 8,6%, preço líquido R$ 134,00). Nenhuma correção foi autorizada ainda; os itens A, B e D seguem em standby.

Contexto original da pergunta: a venda tem desconto real de R$ 62,95 sobre R$ 732,95. Duas leituras possíveis:

| Opção | Preço unitário na devolução do CNX-6001 | Observação |
|---|---|---|
| **D1-a — líquido (regra atual, SPEC-178/182)** | R$ 134,00 | Devolve o que o cliente pagou (preço × desconto do item × desconto global da venda). Só corrige a duplicata. |
| **D1-b — valor cheio da peça** | R$ 146,59 | Devolução usa sempre o `preco_unitario` da venda, sem desconto global. Muda a regra para **todas** as devoluções (Orçamentos, financeiro, crédito da SPEC-258 fase 4d). |

A correção A/B valeria nas duas opções.

## Definição da SPEC

### A — Correção do dado (migration nova, ensaio com rollback antes de aplicar)

Para cada orçamento `origem = 'connect'` com grupos de `orcamento_itens` iguais (`orcamento_id`, `custom_id`, `descricao`, `quantidade`, `preco_unitario`) com mais de uma linha:

1. Manter a linha que tem `produto_id` (ligada ao item da venda por `projeto_itens.orcamento_item_id`) e apagar a duplicada (`produto_id` nulo), **sem apagar nenhuma linha referenciada por `projeto_itens.orcamento_item_id`**.
2. Recalcular `desconto_global = greatest(0, soma(quantidade × preco_unitario) − valor_total)` sobre a base já sem duplicata, mantendo `desconto_tipo = 'valor'`.
3. Conferências dentro da transação (aborta se falhar): `projetos.valor_total`, soma de `projeto_itens.quantidade`, estoque e financeiro **iguais antes e depois**; só `orcamento_itens` (linhas duplicadas) e `orcamentos.desconto_global` mudam; `valor_total` não muda.
4. Tabela de backup no schema `backup` (nunca no `public`) com as linhas apagadas e o `desconto_global` antigo.
5. Atenção para CNX-6879, CNX-7763 e CNX-7861: a base de `orcamento_itens` sem a duplicata precisa ser conferida contra `projeto_itens` e o XML **antes** de recalcular (os totais atuais divergem do XML por mais que a duplicata). Se a conta não fechar, o orçamento sai do script e vai para D1.
6. Entregar `up.sql`, `dry_run.sql` (sem COMMIT embutido), `rollback.sql`. Pasta: `supabase/db/migrations/20261113_NNN_spec294_orcamento_itens_duplicados_connect/` (NNN = próximo número livre; a 347 já está redigida e não aplicada).

### B — Causa raiz

- Alterar a lógica de importação do XML (migration 273 / script de import) para: quando `cod_produto` vier em branco, tentar casar por `referencia` com o item já existente do orçamento (e por `custom_id` + quantidade + preço) antes de criar "item avulso".
- Só criar item avulso se não houver linha equivalente no orçamento.
- Calcular o `desconto_global` sempre sobre a base **depois** da deduplicação.
- Constraint/validação: no máximo uma linha com a mesma combinação (`orcamento_id`, `custom_id`, `descricao`, `quantidade`, `preco_unitario`) em orçamento Connect.

### C — Tela de devolução (depende de D1)

- Aplicar D1-a ou D1-b em `getVendasOrigemParaDevolucao` (`04-Sistemas/gestao-financeira-clone-544cb (1)/src/services/devolucoesService.ts`) e na RPC que grava a devolução, se ela recalcular valor.
- Mostrar nas linhas da busca (`DevolucaoItemSearchModal.tsx`) o preço cheio **e** o líquido, para a pessoa enxergar a diferença.

## Análise de ecossistema

- Depende de `orcamentos`, `orcamento_itens`, `projeto_itens`, `connect_xml_orcamento`, `connect_xml_item`. Afeta Orçamentos (devolução) e, indiretamente, o crédito de devolução do Financeiro (SPEC-258 fase 4d, migration 313).
- Dado duplicado: o valor da peça existe em `orcamento_itens` e `projeto_itens`; a devolução lê `projeto_itens` para o preço e `orcamento_itens` só para a base do desconto de venda Connect (SPEC-275).
- Nenhuma migration antiga contradiz o snapshot central neste ponto; `AI_DB_CONTEXT.md` só precisa de ajuste se a regra D1-b for adotada.

## Critérios de aceite

- CNX-8479: `orcamento_itens` com 1 linha; `desconto_global` = 62,95; `valor_total` continua 670,00; na devolução da Ketlyn o preço aparece conforme D1 (R$ 134,00 em D1-a, R$ 146,59 em D1-b).
- Nenhum orçamento Connect com linhas duplicadas de `orcamento_itens` (consulta de verificação retorna 0).
- Quantidades, saldos de estoque, reservas, `projetos.valor_total` e financeiro idênticos antes e depois.
- Reimportar o XML do 8479 não cria a linha de novo.

## Testes obrigatórios

- Dry-run em transação com ROLLBACK, comparando antes × depois (contagens e somas acima).
- Devolução de teste do CNX-6001 em ambiente de teste/rollback com o preço esperado.
- Reexecutar a importação do XML em ensaio e confirmar que não duplica.

## Plano de rollback

- Restaurar as linhas e o `desconto_global` antigo a partir da tabela do schema `backup`.
- Reverter o código do import e da tela pelo commit.

## Documentos a atualizar

- `CHANGELOG.md` (raiz); `03-Projeto/Planos de Ação/SPECs/SPEC-275` (nota apontando para esta correção); `AI_DB_CONTEXT.md` do sistema Orçamentos, se D1-b for adotada.

## Realizado

### 2026-11-13

- SPEC retomada. Migration `20261113_351_spec294_orcamento_itens_duplicados_connect` (up/dry_run/rollback) redigida; ensaio com ROLLBACK: apaga 1 linha, só no CNX-8479 (base 732,95 = XML, `desconto_global` 62,95, nenhuma linha com vínculo em `projeto_itens`). `desconto_global` do CNX-8479 já estava em 62,95 no banco (alguém corrigiu antes); a duplicata continuava.
- Migration 351 APLICADA: CNX-8479 com 1 linha, base 732,95, `desconto_global` 62,95. Migration 352 APLICADA: a função agora casa por referência. Reexecutar o importador mudaria a base de 8 orçamentos e deixaria duplicatas onde a referência não bate (CNX-6879, 7034, 7301, 7327, 7618) — não reexecutado; investigar junto com a D1.
- CNX-6879, CNX-7763 e CNX-7861 têm 5 linhas duplicadas, mas a base sem a duplicata não fecha com o XML (diferenças de 8,7 mil, 7,9 mil e 55 mil) — ficaram fora do script e vão para a D1 (item D1).

- Diagnóstico feito no banco real (somente leitura): causa raiz e alcance levantados. Nada alterado no banco nem no código.
- D1 respondida pelo Vinicius (via usuário): manter o preço líquido com desconto. SPEC colocada em standby.

## Pendências

- [x] Decidir D1 — decidido: a devolução mostra o preço líquido (com desconto); regra atual mantida.
- [ ] SPEC em standby: aguardar o usuário pedir para retomar a correção do dado (linha duplicada e desconto global do CNX-8479 e dos outros 3 orçamentos).
- [ ] Redigir e ensaiar a migration de correção (itens A1/A2) e só aplicar com autorização do usuário.
- [ ] Corrigir a importação do XML para casar por referência quando o código do produto vier em branco.
- [ ] Investigar os 29 orçamentos Connect com `desconto_global` que não bate com o XML.
- [ ] Depois da correção, a Ketlyn refaz a devolução do CNX-6001.
