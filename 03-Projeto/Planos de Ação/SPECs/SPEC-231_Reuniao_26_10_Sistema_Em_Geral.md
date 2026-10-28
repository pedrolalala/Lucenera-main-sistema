---
titulo: "SPEC-231 — Reunião 26/10 (sistema em geral): Compras, Entrada NF → Contas a Pagar, Separação, Entregas, Contas a Pagar/Receber, Emissão de NF e relatório de movimentação"
status: pendente
data_ultima_modificacao: 2026-10-27
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee) — pedido de compra e entrada de NF
  - Contas a Pagar / Contas a Receber (retorno-bancario-bradesco-5392a, 2 modos — SPEC-225)
  - Separação Parcial (separacao-parcial)
  - Logística (lucenera-logistics-b7cd1) — entregas finalizadas
  - Vendas (vendas-lucenera) — emissão de NF
  - Orçamentos (gestao-financeira-clone-544cb (1)) / Consulta de Produtos — reservas e entrega futura
  - Relatórios (dashboard-lucenera-b02z85wa3) — movimentação do item
  - Banco (estoque/reservas, notas_fiscais, contas a pagar)
---

# SPEC-231 — Reunião 26/10 (sistema em geral)

> Fonte: `02-Reunioes/38. Lucenera (vinicius) - 26.10.2026_ sistema em geral/Reunião.01` (teste guiado com o Vinicius,
> peça de teste **12822**). Transcrição automática: nomes podem estar trocados ("herança" = Reserva sem venda / herança Connect,
> SPEC-232; "Pontas Apagar" = Contas a Pagar; "Citel" = sistema antigo de busca; "7886" = pedido 1786). Quem decide status de separação é o **Sérgio** (não o Mateus).
>
> Itens já cobertos por outra SPEC e **fora** desta:
> - preço do orçamento ≠ consulta (12822: 42,95 × 35,79) → **SPEC-230** (migration 246 aplicada; na reunião o
>   orçamento da Marina já saiu certo, 35,79);
> - Showroom "pegando o campo antigo" no empréstimo → corrigido durante a reunião (conferir no teste).

## Checklist de Ação

Agrupado por sistema. Cada bloco pode ser implementado e publicado separado. Ordem sugerida: **A (bugs) → B → C → D → E → F → G**.

### A. Bugs que apareceram no teste (prioridade)
- [x] A1 — Separação Parcial: peças iam para "Separado" sozinhas. **Causa (27/10):** não era o estorno. Quando a
      separação pede tudo o que falta da venda, `finalizar_separacao_parcial_pronta` marcava a separação como
      `'Pronto'` e o trigger `sync_separado_ao_ficar_pronto` passava tudo de "Aguardando separar" para "Separado"
      (ORC-0002 em 26/10 16:03:00, no mesmo segundo da criação; o estorno foi às 16:05). Correção (migration 248):
      vai para `'material_solicitado'` (aba Solicitado do estoque) e a RPC cria a entrega; "Separado" só quando o
      estoque marca `separado` na Logística; se voltar para Solicitado/Em separação, as peças voltam para
      "Aguardando separar". Estorno mantém o status (testado em ROLLBACK). Separação Parcial: textos dos avisos.
- [x] A2 — Entrada de NF com financeiro não gerava Contas a Pagar. **Causa (27/10):** o sistema Contas a Pagar lê
      `boletos` (`tipo_operacao = 'CP'`) e nada criava esses registros — as parcelas da nota
      (`nota_fiscal_compra_parcelas`) só iam para a `vw_contas_pagar_pedidos_compra` (painel financeiro). Correção
      (migration 248): trigger em `nota_fiscal_compra_parcelas` gera 1 duplicata por parcela (fornecedor, NF, valor,
      vencimento, apropriação = plano de contas da nota, referência = pedido; `conta_grupo_id` = id da nota,
      `nosso_numero` = `NFC-<id da parcela>`); cancelar a entrada apaga as não pagas e é bloqueado se alguma já foi
      paga. As 2 notas da Stella (26102026 em 2x, 261000 em 1x) ganham as 3 duplicatas. Nenhum painel lê `boletos`,
      então não conta em dobro.
- [x] A3 — "Herança" da 12822 subiu de 32 para 35 depois da devolução → resolvido pela **SPEC-232** (26/10,
      migration 247 aplicada: entregar/devolver/re-reservar não mexem mais na herança da Connect; 12822 acertada).
- [ ] A4 — Pedido de compra: valores de ST e IPI com diferença de centavos em relação à conta na calculadora
      (ST 175,01 × 175,20; IPI 31,25 × 31,20). Conferir a base de cálculo e o arredondamento (arredondar por item
      ou no total? aplicar desconto antes?) em `services/pedido-compra.ts`, `EditarPedidoDialog.tsx` e no PDF.
      **Conferido 27/10 (pedido 1787, 40 × R$ 12,02 = R$ 480,80; peça com ST 36,4% e IPI 6,5%):** o sistema calcula
      o imposto sobre o total do item — ST 175,01 e IPI 31,25, que é como a NF-e faz. A calculadora arredondou o
      imposto por peça antes (4,38 × 40 = 175,20; 0,78 × 40 = 31,20). **Aguardando decisão do usuário** se muda.
- [ ] A5 — Necessidade/Compras: informação de pedidos **cancelados** ou **ainda não aprovados** (ex.: pedido 7886)
      não pode aparecer como compra em andamento / previsão de entrada. Só pedido aprovado conta. Conferir também que
      reserva 0 não aparece mais (Pedro já tirou "informações sobrando" — validar).
      **Conferido 27/10:** cancelado já não entra em nenhuma view da Necessidade. Pedido **aguardando aprovação**
      (o 1786 estava assim na hora) conta como "em pedido aberto" (`vw_necessidade_compra_pedidos_abertos`) e abate a
      necessidade. Tirar faz a peça voltar à lista e permite comprar em dobro. **Aguardando decisão do usuário.**

### B. Compras — pedido e entrada de NF
- [x] B1 — Condição de pagamento do pedido de compra: além de "30/60 dias", permitir **digitar a data** de cada
      parcela (pedido da Débora). Motivo: é previsão — se a entrega é em 15 dias e a condição é 30 da nota, a 1ª parcela
      é ~45 dias, não 30 a partir de hoje. Hoje a data só existe na entrada da nota (`CondicaoPagamentoCampo.tsx`).
      **Feito 27/10:** opção "Por datas" (calendário por parcela, + Parcela / tirar) no Novo Pedido e no Editar
      Pedido; grava "dd/mm/aaaa, dd/mm/aaaa" em `condicoes_pagamento`, que `_lucenera_datas_parcelas` já lia
      (conferido no banco). Valor em partes iguais. Sem mudança no banco.
- [x] B2 — Entrada de NF: **alerta ao salvar** quando há item sem vínculo (necessidade/cliente). No teste o Pedro
      salvou sem vincular e o estoque ficou somado errado (32 + 48 = 80 em vez de abater a necessidade). Não travar —
      só avisar e pedir confirmação. (Uso principal: Débora.)
      **Feito 27/10:** se parte do que chegou não foi vinculada e há cliente em entrega futura da peça, abre aviso
      com a peça, a quantidade sem vínculo e quem está esperando (venda, L, quantidade): "Voltar e vincular" ou
      "Registrar mesmo assim".
- [x] B3 — Entrada de NF, layout da lista de itens: tirar a parte de baixo que sobra, trazer a quantidade para a
      linha do item e **alargar a coluna do nome** da peça.
      **Feito 27/10:** era a tela do **Espelho da entrada** (o "chegaram X" embaixo do nome). Agora coluna
      "Chegou" na linha da peça, nome com ~metade da largura e janela mais larga. O PDF do espelho já era assim.

### C. Consulta de Produtos / Orçamentos — reservas e entrega futura visíveis para todos
- [x] C1 — Na lista de **reservas** e de **entrega futura** de uma peça, **todo mundo vê** (não só a própria equipe —
      SPEC-200): orçamento, número da venda, funcionário, cliente, projeto, quantidade, data da venda e data de entrega.
      **Só o valor (valor total da venda) fica oculto** para quem não é da equipe. Motivo: uma vendedora pede peça
      emprestada à outra ("Marina, preciso de uma lâmpada da venda tal").
      Exemplo do teste: Adriana (equipe da Marina) não aparecia para o Pedro.
      **27/10 — migration 249 APLICADA (autorizada pelo usuário), Cadastro `1a5d480` publicado.** A tela é o Cadastro → peça → abas Reserva / Entrega
      Futura / Separação / Entregue (`PecaAbasSetores.tsx`, view `vw_cadastro_produto_movimentos`). Causa: a view era
      `security_invoker` e a política restritiva `spec200_orcamentos_equipe` apagava orçamento/venda/funcionário/datas
      das outras equipes. Migration `20261027_249_spec231_reservas_visiveis_todas_equipes`: a view roda como dono com o
      mesmo portão de sistemas de `orcamentos` no WHERE e `valor_total_orcamento` nulo para outra equipe; sem anon.
      Dry-run (ROLLBACK): Tricia (Thais) passou de 5 linhas vazias para orçamento/venda/Marina/cliente com valor oculto;
      Marina e Vinicius veem o valor; anon bloqueado. Cadastro: dica "Valor visível só para a equipe da venda"
      Conferido no banco depois de aplicar: view `security_invoker=false`, só SELECT para authenticated; Tricia vê
      as linhas com valor oculto, Marina vê o valor, anon bloqueado.

### D. Separação Parcial + Logística — editar pedido e ver a entrega
- [x] D1 — Ao clicar **Separar** na Separação Parcial, abrir a **mesma tela de solicitação** que as meninas já usam
      (pedido normal / empréstimo / garantia, incluir garantia, "retirar devolução nesta visita", endereço de entrega,
      observações tipo "falar com o eletricista"), para não precisarem abrir uma solicitação nova. Se a venda tiver
      garantia, a solicitação de garantia também sai por aqui.
- [x] D2 — Permitir **editar** endereço de entrega e observações de uma separação já enviada (antes de sair para
      entrega).
- [x] D3 — **Visualização simples da entrega** dentro da Separação Parcial: status (ex.: finalizado), quem recebeu
      (ex.: porteiro) e data — para não ter que ir na Logística → Finalizados.
- [x] D4 — (27/10: separação nova grava `numero_entrega` = número da parcial, ex.: `0002-P2`; e "Venda 0003" ao lado
      no cartão, nas finalizadas e no detalhe) **Código do pedido = código da parcial** (ex.: `0002-P1`) em Logística → Entregas finalizadas e na nova
      separação, **mais o número da venda** ao lado. Hoje aparece o código do projeto/obra. Assim as meninas filtram
      o cliente, acham a parcial e veem quem recebeu.

### E. Contas a Pagar / Contas a Receber
- [x] E1 — Busca de cliente/fornecedor com **duplo clique** abrindo uma tela de pesquisa (como no sistema antigo),
      em vez da lista que abre para baixo. Selecionou → filtra **só aquele** cadastro.
      - Contas a Receber: código do projeto, nome do cliente (razão social), nome do projeto, CPF/CNPJ.
      - Contas a Pagar: nome fantasia (se tiver), razão social, CNPJ.
      Motivo: vários cadastros com o mesmo nome (ex.: "Estância Santa Clara" com CNPJs diferentes; cliente com 2–3
      casas/projetos, caso do André; vários "Vinícius").
      **Feito 27/10:** campo "Pessoa" de Consultar Duplicatas e Contas em Aberto — digitar continua filtrando pelo nome;
      dois cliques (ou a lupa) abrem a busca do cadastro (`BuscaPessoaDialog`). Receber: linhas por projeto (código,
      razão social, nome do projeto, CPF/CNPJ) e uma linha "(todos)" por cliente; Pagar: fornecedores (fantasia,
      razão social, CNPJ). CPF/CNPJ lido de `cpf_cnpj`, `cnpj` ou `cpf`. Escolhido vira etiqueta "Só: ..." com X.
      Filtro: projeto → `orcamentos.projeto_id` (duplicatas) / `negociacoes.projeto_id` (em aberto); cliente/fornecedor
      → `contato_id` ou `orcamentos.cliente_id`; duplicata antiga sem vínculo casa pelo nome. Sem mudança no banco.
- [x] E2 — Contas a Pagar: **juntar "Notas Fiscais" (registrar NF avulsa) e "Cadastrar Duplicatas" em uma só**
      ("Cadastrar duplicata"), com campo de número da nota e demais dados da NF. Nome continua "duplicata" (não "boleto").
      **Feito 27/10 (Pagar e Receber):** menu "Notas Fiscais" saiu e a rota leva ao Cadastrar Duplicata (campo NF). A
      tela gravava em `notas_fiscais` (tabela das notas de venda) e não tinha nenhum registro — nada perdido.
- [ ] E3 — Consultar Duplicatas: trazer o **histórico** das duplicatas em aberto da planilha antiga (Connect) para poder
      dar baixa no sistema novo — sem vínculo de venda, mas com o número da venda da planilha. Pedro vai avaliar como
      (ver SPEC-215, que já casa por `num_nota`).
- [ ] E4 — Conferir os filtros de data/situação das telas (Vinicius disse que "não mudou nada"); o filtro de pagamento
      só aparece quando houver algo pago — confirmar com ele.

### F. Vendas — emissão de NF (Focus NFe, SPEC-154)
- [x] F1 — (venda e devolução; remessas ficam para a SPEC-233) Emissão de NF **só em Vendas** (Contas a Receber não emite). Tudo cai em Vendas com a nomenclatura e a
      **configuração fiscal do tipo**: venda, devolução, remessa em garantia, simples remessa. Remessa em garantia /
      simples remessa **não geram financeiro**.
- [x] F2 — Número, série e data de emissão **automáticos e travados** (não digitáveis). Tirar os campos que não
      importam (descrição solta etc.).
- [x] F3 — Espelho da nota já vem **100% preenchido** com o que o sistema tem (cliente, CPF/CNPJ, IE, itens, impostos,
      faturamento). Pode editar: CPF/CNPJ e IE (quando vieram errados), **dados adicionais**, **transportadora**,
      **frete CIF/FOB**, valor, desconto e data do boleto.
- [ ] F4 — Valor dos boletos tem que fechar com o valor da nota (nota de 10.000 à vista → boleto de 10.000). Sinal pago
      antes entra como parcela de adiantamento + boleto do restante, nunca um boleto menor solto.
      **F2/F3 — 27/10, NO AR (migration 250 aplicada, Edge Function v5, Vendas `f320f44`):**
      tela "Emitir Nota Fiscal" do Vendas sem número/série/data/tipo/perfil/fornecedor (número e série vêm da
      Focus na autorização; rascunho grava "A DEFINIR"); mostra emissão de hoje e emitente. Campos ajustáveis:
      CPF/CNPJ e IE do destinatário (pré-preenchidos do cliente; limpos ao trocar o pagador), desconto (R$), frete
      (CIF/FOB/terceiros/sem frete), transportadora + CNPJ, dados adicionais. Migration
      `20261027_250_spec231_nf_emissao_dados_editaveis` (9 colunas em `notas_fiscais`, `registrar_nota_fiscal_parcial`
      mesma assinatura com número opcional, RPC `definir_dados_emissao_nota_fiscal` com a permissão
      `vendas/emitir_nota_fiscal`); dry-run ok (rascunho sem número, dados gravados, frete inválido recusado, estoque
      barrado). Edge Function `emitir-nota-fiscal` + `montar-payload-nfe`: manda `informacoes_adicionais_contribuinte`,
      `modalidade_frete`, `nome_/cnpj_transportador`, `valor_desconto` (rateado nos itens), IE corrigida (ISENTO =
      indicador 2) e `formas_pagamento` com o valor líquido; `deno check` ok.
      Ordem para publicar: 1) migration 250, 2) deploy da Edge Function, 3) push do Vendas.
      **F1 — 27/10, especificação do usuário (nota de venda e de devolução) + decisões:** a devolução continua
      nascendo no orçamento de Devolução (que já gera o crédito e devolve as peças) e a nota de devolução é só o
      documento fiscal; a nota de venda NÃO baixa estoque (continua na entrega, SPEC-232); usar o crédito como saldo
      numa compra nova / estornar fica para SPEC própria. Feito (junto da migration 250, no ar):
      `notas_fiscais.tipo_nota` (venda|devolucao, definido pelo orçamento) e `chave_nfe_referenciada`;
      `registrar_nota_fiscal_parcial` aceita devolução aprovada; Vendas lista devoluções aprovadas com a venda original
      (venda_origem_id ou a venda dos itens devolvidos), mostra empresa/projeto/cliente da venda e a chave da NF de
      venda (pré-preenchida se houver nota autorizada); Focus: entrada, finalidade 4, notas_referenciadas, CFOP
      1202/1411 (validar com contador), sem pagamento, ref `DEV-<orçamento>`; espelho igual. Vendas `f162b41`.
      Remessa em garantia / simples remessa: etapa futura (SPEC-233). F4 depende do Vinicius; F5 da conta Focus.
- [ ] F5 — Teste de emissão real: hoje não emite ("não está configurado"). Fazer 1 emissão em **homologação** a partir
      de uma venda de teste para validar o fluxo.

- [x] D5 — (pedido do usuário 27/10) PDF "Pedido em Separação" com a coluna **Marca** (`produtos.marca_id → marcas`;
      fornecedor principal quase nunca preenchido) nos dois sistemas — layouts duplicados, mudar juntos. Separação
      Parcial `c743a2f`, Logística `a7a72c7`.
- [x] D6 — (pedido do usuário 27/10) rodapé do mesmo PDF com "Separado por" e "Conferido por" (controle interno,
      duas etapas). Separação Parcial `019dd74`, Logística `b36ecf9`.

### G. Relatório de movimentação do item (kardex)
- [x] G1 — Relatório "Movimentação do item" (Relatórios → Estoque): filtro por **código da peça**, **período** e
      **setor** (sem setor = todos; ex.: Showroom mostra só o Showroom). Colunas: código, data, histórico (venda nº,
      NF nº, devolução...), tipo (E entrada / S saída / T transferência), quantidade, **saldo após** e setor.
      É o que acontece no estoque da empresa — **não** tem a ver com entregue ao cliente (8 vendidas podem estar
      ainda reservadas no estoque). Fonte: schema `auditoria` / movimentações (SPEC-206/224) — conferir se a view já
      existe antes de criar.

### Passos manuais do usuário
- [ ] Aprovar esta SPEC (e a ordem dos blocos) antes de implementar.
- [ ] Confirmar com o Vinicius: F4 (regra de sinal/adiantamento). (C1 liberado pelo usuário em 27/10.)
- [x] Aplicar a migration 248 (A1 + A2) — aplicada 27/10.
- [x] Publicar a Separação Parcial (textos dos avisos do A1) — `9f64dd6`.
- [x] Aplicar a migration 249 (C1) — aplicada 27/10; Cadastro publicado.
- [x] Aplicar a migration 250 (F1–F3), publicar a Edge Function emitir-nota-fiscal e fazer push do Vendas — feito 27/10 (Edge v5).
- [x] Aplicar as migrations que surgirem (G1) depois do dry-run — 251 aplicada 28/10 (depois da 255 da SPEC-234); Dashboard `058cb21`.
- [ ] Teste guiado de novo com a 12822: compra → entrada NF → Contas a Pagar → orçamento → separação → estorno →
      devolução → relatório de movimentação.

## Objetivo

Corrigir os erros vistos no teste de ponta a ponta de 26/10 (estorno muda status, entrada de NF não gera Contas a
Pagar, reserva muda na devolução, centavos de ST/IPI) e fazer os ajustes pedidos para o uso diário em Compras,
Separação, Contas a Pagar/Receber, emissão de NF e um relatório de movimentação do item.

## Decisões aprovadas (na reunião)

- Cadastro de fornecedor/cliente é **só no CRM** (todo mundo tem acesso) — sem cadastro novo em outros sistemas.
- Status de separação é responsabilidade do Sérgio; estorno não altera status.
- Reservas/entrega futura: informação visível a todos, valor oculto.
- Toda entrada de NF de mercadoria com financeiro gera Contas a Pagar.
- Emissão de NF centralizada em Vendas, por tipo de operação com configuração fiscal própria.
- Contas a Pagar: um único "Cadastrar duplicata" (sai o registrar NF avulsa).
- Relatório de movimentação do item é do estoque da empresa, independente de entrega.

## Definição da SPEC

### Análise de ecossistema
| Pergunta | Resposta |
|---|---|
| Tabelas centrais | `projeto_itens`, `projeto_parcelas`, `contatos`, `produtos` (só leitura; custo continua só em `vw_produtos_custo`), notas fiscais de compra/venda, reservas/estoque por setor |
| Sistemas | Compras, Contas a Pagar/Receber, Separação Parcial, Logística, Vendas, Orçamentos, Relatórios |
| Permissão | C1 mexe na regra da SPEC-200 (equipe) — a linha fica visível a todos, a coluna de valor continua com o filtro de equipe. Qualquer view nova com `(SELECT pode_acessar_sistema(...))`, sem grant para `anon` |
| Dado duplicado | Código da parcial e nº da venda devem vir por relacionamento, não copiados para a entrega |
| `AI_DB_CONTEXT.md` | Atualizar em Separação Parcial (A1), Compras (A2/B1) e Relatórios (G1) se mudar banco |

### Critérios de aceite
- A1: estornar parte de uma separação em "Aguardando separar" → status continua "Aguardando separar"; em "Separado"
  → continua "Separado" com quantidade atualizada; reimpressão mostra as quantidades certas.
- A2: entrada de NF com 1 parcela e com 3 parcelas → duplicatas aparecem no Contas a Pagar com valor e vencimento da
  entrada.
- A3: devolução de N peças só altera o setor de origem escolhido; reserva de outro pedido não muda.
- A4: ST e IPI do pedido batem com a conta manual (diferença máxima de arredondamento final: R$ 0,01).
- C1: usuária da equipe A vê reserva de vendedora da equipe B com todos os campos, sem o valor.
- D4: entrega finalizada mostra `0002-P1` + nº da venda.
- E1: com dois clientes de mesmo nome, duplo clique → escolher um → lista só as duplicatas dele.
- F2/F3: abrir emissão a partir de uma venda → número/série travados, espelho preenchido, transportadora/CIF-FOB e
  dados adicionais editáveis.
- G1: 12822 no período do teste mostra as entradas/saídas do dia 26/10 com saldo correndo e filtro de setor.

### Rollback
Cada bloco é independente: reverter o commit do sistema e, se houver migration, o `rollback.sql` dela.

## Realizado

### 2026-10-27

- A1/A2: diagnóstico pelo `auditoria.eventos` e `estoque_movimentos_projeto_item` do teste de 26/10; migration
  `20261027_248_spec231_separacao_status_e_nf_compra_contas_pagar` (up + rollback) gerada a partir do
  `pg_get_functiondef` atual. Dry-run em ROLLBACK: separação de teste Pendente → Solicitado (continua aguardando) →
  estorno 1 (status mantido) → estoque marca separado (3 em Separado) → volta Em separação (volta para aguardando) →
  separado + estorno 1 (status mantido); duplicatas das 2 notas da Stella geradas; parcela nova gera duplicata e
  atualiza o total; excluir parcela paga é bloqueado, não paga apaga a duplicata.
- Separação Parcial: avisos "Venda totalmente separada" trocados por "enviada para o estoque separar".
- D1 (pedido do usuário 27/10): "Separar" abre a tela **Nova Separação** igual à da Logística (componente
  `NovaSeparacaoModal`, cópia de `lucenera-logistics-b7cd1/src/components/separacao/SeparacaoFormModal.tsx`) com a lista
  das peças e já preenchida: código da obra, nº da venda, nº da parcial, gestora (equipe do orçamento →
  Marina Pousa / Thais Gomes / Thairine Silva / Matheus), solicitante (usuário logado), cliente, telefone e endereço.
  A separação nasce em `material_solicitado` com todos os campos da Logística (tipo, horário, responsável,
  complexidade, forma de entrega, observações, garantia, retirada de devolução) e os anexos vão para
  `materiais-separacao`/`separacao_arquivos`. Saiu o campo solto "Data de entrega" ao lado do botão. Gravação testada
  como usuário logado em ROLLBACK. Separação Parcial publicada.
- Ajustes pedidos pelo usuário (27/10): nº da venda aparece só como número (ex.: `0003`, sem "VENDA-" e sem o
  orçamento). Logística: botão **Pedido** no cartão da separação exporta o mesmo "Pedido em Separação" que a Separação
  Parcial imprime ao separar (`src/lib/pedido-separacao.ts`, layout copiado — mudou um, mudar o outro), a qualquer
  momento, não só na hora de separar. Conferido que o estoque (Matheus) lê orçamento, peças, cliente e empresa — sem
  mudança no banco. Logística `8e9abac`, Separação Parcial `2232ef0`.
- D2/D3 (Separação Parcial `2794bf2`): histórico das parciais com status claro (Solicitado ao estoque, Em separação,
  Separado, Entregue, Estornado, Recusado pelo estoque) e coluna Entrega (prevista dd/mm, ou entregue dd/mm + quem
  recebeu). Em "Ver itens", bloco Entrega com previsão, endereço, responsável, telefone, observações e, se entregue,
  data/hora, recebido por, entregue por e observação da Logística (`entregas_finalizadas`). Botão **Editar** (data,
  endereço, responsável, telefone, observações) enquanto a parcial não foi entregue nem estornada; grava nos mesmos
  campos que a Logística lê.
- D4 (Logística `41625a2`): `separacoes.numero_venda` guarda o nº do orçamento (ORC-0003); o nº da venda vem de
  `orcamentos.numero_venda` e aparece como "Venda 0003" no cartão da separação, na lista de entregas finalizadas e
  no detalhe da entrega. Separações antigas (numero_venda em outro formato) ficam sem o rótulo. Sem mudança no banco.
- A3: já resolvido pela SPEC-232. A4 e A5: conferidos, aguardando decisão.
- Migration 248 APLICADA (autorizada pelo usuário). Conferido no banco: 2 triggers em `nota_fiscal_compra_parcelas`,
  funções novas no ar, 3 duplicatas CP da Stella (261000 1/1 293,54; 26102026 1/2 431,03 e 2/2 256,03).
  Separação Parcial `9f64dd6` publicada (push).

## Pendências

- [ ] SPEC-231 A4 — decidir se ST/IPI do pedido de compra continuam calculados sobre o total do item (como a NF-e) ou arredondando por peça (como a calculadora do Vinicius). Resposta "ok" em 28/10 não diz qual — reperguntado.
- [x] SPEC-231 A5 — **Decidido (usuário, 28/10): continua abatendo.** Pedido aguardando aprovação já "atendeu a necessidade" (evita comprar em dobro). Nada a mudar.
- [x] SPEC-231 E4 — **Esclarecido (usuário, 28/10):** o "não mudou nada" era porque as duplicatas do Excel (Connect) ainda não tinham sido carregadas. Não é defeito dos filtros; depende do E3.
- [x] SPEC-231 F4 — sinal: **sem percentual fixo** (usuário, 28/10; ver SPEC-234 C).
- [ ] SPEC-231 E3 — decidir como importar o histórico de duplicatas em aberto da planilha antiga para o Consultar Duplicatas (Pedro vai avaliar).
- [ ] SPEC-231 F5 — emissão de NF em homologação (Focus NFe) nunca foi testada a partir de uma venda; depende da configuração da SPEC-154.
