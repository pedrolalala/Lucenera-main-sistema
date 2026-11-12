---
titulo: "SPEC-293 — Compras: editar o número do pedido de compra (temporário), com auditoria e financeiro em dia"
status: implementada localmente em 12/11/2026 (migration 347 redigida e ensaiada, NÃO aplicada; Compras sem commit/publicação)
data_ultima_modificacao: 2026-11-12
sistemas_envolvidos:
  - Compras / Necessidade de Compra (04-Sistemas/compras-lucenera-3o23t98ee) — aba Pedidos
  - Banco (pedidos_compra.numero, set_pedido_compra_numero, financeiro_ponte_pedido, financeiro_titulos, auditoria)
---

# SPEC-293 — Editar o número do pedido (temporário)

**Origem:** solicitação da Débora na Central em 12/11/2026 19:11 ("PERMISSÃO PARA EDIÇÃO DA NUMERAÇÃO DO PEDIDO - TEMPORARIO": "ainda não consigo editar a numeração dos pedidos, no novo sistema, para acertar todos"). O usuário disse que ela já tinha pedido "ontem", mas **não existe registro**: nenhuma solicitação em 11/11 sobre isso, nenhuma SPEC e nenhuma menção nas reuniões 44 a 52 (verificado em 12/11/2026). Tratar como pedido novo.
Nota de numeração: o número 292 foi usado por outra sessão (SPEC-292 da Carol, CRM e Cadastro; migration 346). Esta SPEC é a 293; a migration usará o próximo número livre.

## Checklist de Ação

- [x] A. RPC `renomear_numero_pedido_compra(p_pedido, p_novo_numero, p_motivo)` (SECURITY DEFINER, `search_path` fixo, `REVOKE ALL FROM PUBLIC, anon`): recusa número vazio ou só espaços, número já existente (comparação sem diferenciar maiúsculas e sem espaços nas pontas) e pedido inexistente; permissão por lista + papel (item B)
- [x] B. Permissão **restrita**: só a Débora e administradores (lista em `compras_config`, chave `numero_pedido_editavel_por`), com chave liga/desliga `numero_pedido_edicao_ativa` para encerrar o "temporário" sem nova migration; trava de papel com `IS DISTINCT FROM`
- [x] C. **Qualquer status** do pedido pode ser renomeado (inclusive com NF e financeiro já lançados); pedido `cancelado` também
- [x] D. Auditoria: número antigo, número novo, quem, quando e motivo (obrigatório); de/para guardado em `backup.spec293_renumeracao_pedidos_compra` para poder desfazer
- [x] E. Atualizar o que guarda o número como **texto**: `financeiro_titulos.documento` e `descricao` do título do pedido (origem `pedido_compra`) e a observação das parcelas previstas ("Previsão do pedido <nº>"); rótulos gravados em `pagamento_existente_vinculos` (SPEC-290, `pedido_numero`) e em `pagamentos_antecipados.observacao` só se citarem o número do pedido; nada que seja ligado por `id` precisa mudar
- [x] F. Tela: botão "Editar número" na linha do pedido (só para quem pode) com janela de confirmação mostrando "de → para" e motivo; mensagem clara de erro para número duplicado
- [x] G. Os 44 pedidos importados da Connect (`NNNN CONNECT`) também podem ser renomeados; o sufixo " CONNECT" deixa de ser obrigatório no número (a origem continua identificável pela observação do pedido)
- [x] H. A sequência automática (`pedidos_compra_numero_seq`) passa a continuar do **maior número numérico existente**, para o próximo pedido novo não repetir um número da Connect; ajuste de uma vez só e como parte do mesmo ensaio
- [x] I. Migration + `rollback.sql` + dry-run em ROLLBACK (como Débora, como administrador e como usuário sem permissão e `anon`); aplicar **só com autorização**
- [ ] J. `vite build` (feito), CHANGELOG (feito); pendentes: revisor antes do commit, publicar Compras (wrangler), `AI_DB_CONTEXT.md`, snapshot

### Passos manuais do usuário
- [ ] Rodar o agente `revisor`, autorizar e aplicar a migration 347 (`python scripts/aplicar_migration_sql.py 20261112_347_spec293_renomear_numero_pedido_compra`), commitar e publicar Compras
- [ ] Confirmar com a Débora **quais números** quer trocar e para quê (renumerar os pedidos nativos 1790–1803 para os números que a Connect deu? tirar o sufixo CONNECT?). Se ela tiver a lista de-para, uma carga única fica mais segura que 40 edições manuais
- [ ] Débora testar a edição em um pedido de teste e conferir o número no Contas a Pagar
- [ ] Definir quando desligar a chave "temporário"

## Estado verificado (12/11/2026, somente leitura)

- `pedidos_compra.numero` é texto com `UNIQUE (numero)` (`pedidos_compra_numero_uniq`). O trigger `set_pedido_compra_numero` só preenche quando o número vem vazio; o banco **não** impede alterar o número depois. A tela não oferece edição.
- Numeração atual: nativos do sistema 1790 a 1803 (sequência automática); 44 pedidos `NNNN CONNECT` (1733 a 199x, vindos da planilha da Connect) e 51 `PC-LEGADO-…`. Como a Connect continua numerando, os números nativos se sobrepõem aos dela.
- 35 títulos do Contas a Pagar de origem `pedido_compra` guardam o número do pedido como texto.
- Lição da SPEC-268 (orçamentos renumerados em 11/11): o número aparece em PDF, XML, boletos e títulos; sempre ligar por `id` e guardar de/para em `backup`.

## Decisões (recomendações do usuário, 12/11/2026)

1. Só a Débora e administradores editam.
2. Vale para qualquer status do pedido, com os textos do financeiro atualizados e auditoria.
3. Os pedidos `CONNECT` também podem ser renomeados; o sufixo vira só marca de origem.
4. "Temporário" = uma chave de configuração que o usuário desliga; sem data fixa.
5. A sequência automática continua do maior número existente.
6. **Em aberto:** quais números a Débora quer trocar (de/para).

## Riscos / atenção

- Renomear pedido com NF/financeiro lançado muda o texto no Contas a Pagar e nos PDFs/e-mails **já enviados** ao fornecedor continuam com o número antigo; avisar na janela de confirmação.
- Dois pedidos trocando de número entre si (1802 ↔ 1803) esbarram na regra de número único: a RPC aceita um por vez; para trocas cruzadas usar um número temporário ou a carga única.
- A sequência automática não pode retroceder nem repetir número já usado, inclusive os que a Connect ainda vai emitir.

## Rollback

Telas: reverter o commit de Compras. Banco: `rollback.sql` remove a RPC e restaura a sequência; os números já alterados voltam pelo de/para em `backup.spec293_renumeracao_pedidos_compra`.

## Realizado (12/11/2026)

- Migration `supabase/db/migrations/20261112_347_spec293_renomear_numero_pedido_compra/` (up, rollback, dry_run, dry_run_rollback, tests.sql): **não aplicada**. A configuração fica em **duas colunas novas de `compras_config`** (tabela de uma linha só, sem chave/valor): `numero_pedido_editavel_por uuid[]` (inicial: Débora, `debora@lucenera.com.br`) e `numero_pedido_edicao_ativa` (nasce ligada). Administradores (`usuarios.role = 'admin'`) passam sempre que a chave estiver ligada. Desligar: `UPDATE compras_config SET numero_pedido_edicao_ativa = false`.
- Textos atualizados por id: título do pedido, observação das parcelas "Previsão do pedido N (parcela k)", títulos de NF "NF x (pedido N)", `pagamento_existente_vinculos.pedido_numero`, `pagamentos_antecipados.observacao` (só o trecho "(pedido N)"). `financeiro_ponte_pedido` usa o número atual e `trg_fin_ponte_pedido` não reage a UPDATE de `numero`; ensaio confirmou que nada volta ao número antigo. Histórico de estoque (texto livre do kardex) não é alterado.
- Sequência: sobe para 1993 (maior número que começa por dígitos, incluindo "NNNN CONNECT"), nunca retrocede; rollback devolve ao valor de antes sem ficar abaixo do maior número puramente numérico.
- Ensaio em ROLLBACK (tudo passou): Débora ok; admin fora da lista ok; Isabella (funcionária) recusada; anon recusado (sem EXECUTE); chave desligada recusa até admin; vazio, só espaços, motivo vazio, pedido inexistente, duplicado ("  1803 " e caixa diferente); pedido 1930 CONNECT -> "1930-TESTE" com título, 2 títulos de NF e parcelas atualizados e ponte rodando depois sem reverter; PC-LEGADO -> 1448; próximo pedido novo gerou 1994; de/para e auditoria com motivo gravados; rollback.sql reensaiado.
- Tela: Compras, aba Pedidos (`PedidosCompra.tsx`, `pedido-compra.ts`): botão "Editar número" via RPC `pode_editar_numero_pedido_compra` (sem usuário fixo no front). `vite build` e `oxlint` ok; `tsc` sem erro novo (erros antigos em outros arquivos).
- ATENÇÃO: sequências do Postgres não voltam com ROLLBACK; os ensaios deixaram `pedidos_compra_numero_seq` em 1994 no banco real (era 1803). Efeito prático igual ao da migration (que a leva a 1993), mas pulou um número.
- Observação: um PC-LEGADO renomeado deixa de ser ignorado por `financeiro_ponte_pedido` (que pula só números `PC-LEGADO-%`); como são pedidos cancelados, a ponte só os trataria como cancelados.
- Não implementada a carga em massa (de/para da Débora ainda não existe). Trocas cruzadas (1802 ↔ 1803) exigem número temporário.
- Teste manual: Débora abrir Compras > Pedidos, editar um pedido de teste, conferir o número no Contas a Pagar.

### Correções após o revisor (12/11/2026, ainda sem aplicar)

- **PC-LEGADO:** a RPC recusa destino que comece por `PC-LEGADO` (sem diferenciar caixa) e recusa renomear pedido `PC-LEGADO` que não esteja cancelado. Leitura no banco real: os 51 `PC-LEGADO` estão todos `cancelado` (0 fora de cancelado), então a trava hoje não bloqueia nenhum caso real.
- **Importador da Connect:** `scripts/importar_pedidos_compra_connect_cabecalho.py` passa a tratar como existente também o `numero_antigo` de `backup.spec293_renumeracao_pedidos_compra` (tolera a tabela inexistente via `to_regclass`; ignora a linha marcador da sequência). `scripts/importar_pedido_compra.py` não precisa mudar: ele trabalha na tabela `pedido_compra` (Connect, por `codigo_pedido`), não em `pedidos_compra`. A janela da tela avisa que o pedido da Connect renomeado segue protegido contra reimportação duplicada e que a observação mantém a origem. Ensaio só de leitura: o `psql` do script não alcança o host direto daqui (sem IPv6), então a lógica foi conferida pela consulta `to_regclass` via pooler (tabela ainda não existe, ramo pulado); sem inserção nenhuma.
- **Sequência:** a RPC faz `setval` para o maior entre a sequência e o novo número quando ele é puramente numérico (até 9 dígitos); nunca retrocede. Ensaio: renomear para 7000 leva a sequência a 7000, renomear para 1500 não retrocede, pedido novo sai 7001.
- **Trigger BEFORE UPDATE OF numero (flag da RPC): NÃO implementado.** `authenticated` tem GRANT de UPDATE na coluna `numero`, mas `pedidos_compra` tem RLS ligada e a única policy é `SELECT`; logo um UPDATE direto de usuário logado é negado pelo RLS. Quem altera o número são só funções SECURITY DEFINER e service role (importadores/scripts), que um trigger de trava poderia quebrar sem ganho de segurança real.
- **seq_antes = 1994:** a linha marcador em `backup.spec293_renumeracao_pedidos_compra` vai gravar `seq_antes = 1994` (e não 1803), porque os ensaios de 12/11 avançaram a sequência real (não volta com ROLLBACK). Por isso o rollback.sql devolve a 1994, não a 1803. Os dry-runs agora guardam e devolvem a sequência ao fim (`_seq0`); conferido: sequência real continua 1994 depois deles.
- **Auditoria:** cada troca gera 2 eventos (o do gatilho `auditoria_registrar` com número antigo/novo e o da RPC com o motivo em `motivo_troca_numero`). No ensaio do 1930 a contagem pela chave `numero` apareceu como 3 (a conferir pelo revisor; não afeta o resultado).
- **Ensaio completo repetido:** `dry_run.sql` e `dry_run_rollback.sql` passam. O teste do duplicado por caixa passou a usar "1930 connect" (o antigo usava PC-LEGADO, agora reservado).
