---
titulo: "SPEC-191 — Reunião 08/10 (geral): Controle de Produção, disponível certo na Consulta de Produtos e rotina \"tratar a reserva\""
status: blocos A, B e D2/D3 publicados (09/10); C e D1 aguardando
data_ultima_modificacao: 2026-10-09
origem: "02-Reunioes/28. Lucenera (viniciu) - 08.10.2026_ Reuniões gerais/Reunião.01"
sistemas_envolvidos:
  - Controle de Produção (controle-de-producao)
  - Cadastro Lucenera — Consulta de Produtos (cadastro-lucenera-b86fe, Skip 36668)
  - Compras / Logística (rotina de tratar a reserva — a definir com o Mateus)
  - Supabase (estoque_itens, estoque_saldos_projeto_item, vw_cadastro_produto_movimentos, produtos)
  - scripts/importar_produtos_estoque.py (sync Connect)
---

# SPEC-191 — Reunião 08/10 (geral)

> **Fora do escopo e intocável:** a regra de custo/venda da SPEC-190 (Preço de Custo − % Desconto = Custo c/
> Desconto; + BDI (% Frete + % ST + % IPI + % Outras Despesas sobre o custo c/ desconto) = Custo Total;
> × (1 + % Lucro) = Preço de Venda). Nada nesta SPEC altera preço de custo, desconto, BDI, custo total, lucro ou venda.

## Checklist de Ação

### Bloco A — Controle de Produção

- [x] **A1. Inativar em vez de apagar.** Pedido não é apagado: ganha a ação "Inativar" (some das listas, fica no
  histórico). Vinícius: "pode deixar liberado só para mim… em vez de apagar, inativar o pedido".
- [x] **A2. Poder editar o pedido** ("Deixa eu poder editar. Não tem como editar").
- [x] **A3. Visão principal só com os em aberto.** Pedido com status Pronto/Concluído sai da visão principal e
  fica numa outra aba (ou filtro de status) para consulta posterior ("depois que ficar pronto, na teoria eu não quero
  ver mais… só se tiver necessidade de busca"). A prioridade (ex.: Urgente) continua como está.
- [x] **A4. Filtro de empresa:** rótulo "Empresas" (em vez de "Todas as empresas"), opções Todas / Foco / ISLIGHT /
  Manoela ("slide" na transcrição = ISLIGHT).
- [x] **A5. Permissão:** todos podem ver; **só Vinícius, Débora, Mateus, Vitória e João podem alterar** (pessoal do
  estoque). As demais ("as meninas") só visualizam. Se o João faltar, delega-se a outra pessoa (ex.: Vitória).
  Contas: o Mateus vai mandar o e-mail de todos; o João ainda não tem e-mail da Lucenera.

### Bloco B — Consulta de Produtos (Cadastro): disponível certo

- [x] **B1. Conta do disponível** (Vinícius, exemplo peça 66554/6654):
  ```
  Disponível = Estoque Geral − Reserva − Separação
  ```
  Estoque geral 52, reserva 21, separação 12 → **disponível 19**. Hoje aparecem dois números errados:
  - linha da lista: **45** — é `produtos.estoque_disponivel` (vem da planilha da Connect; "52 − 12 + 5", não bate);
  - painel dos setores: **31** — `PecaDetailsPanel.tsx` calcula `totalGeral − q_reserva`, sem tirar a separação.
  O mesmo valor (19) tem que aparecer **nos dois lugares** (coluna Disponível da lista e destaque do painel).
- [x] **B2. Destaque "Disponível" do painel puxando o estoque total** (ex. 10289: estoque total 568, disponível 191 —
  o painel mostra 568). Corrigir junto com B1.
- [x] **B3. Datas dos setores (Reserva, Separação, Entrega Futura): data da VENDA, não do orçamento** ("o orçamento pode
  ter acontecido em janeiro e ter fechado em março"). Hoje vem `data_orcamento` de `vw_cadastro_produto_movimentos`.
- [x] **B4. Visualização dos setores:** trazer a coluna de quantidade para perto do nome do setor (hoje "abre muito
  longe", tem que correr o olho) ou linha tracejada guia; clicar no setor continua abrindo o detalhe (ex. Reserva).
- [x] **B5. Ganhar espaço:** tirar a linha "Pendente" (negativo, já mostrado em destaque) e informação repetida, para
  caber mais itens; manter visível qual peça está selecionada ao rolar ("perdi a intenção de qual que é a peça").

### Bloco C — Rotina "tratar a reserva" (precisa ser criada; acontece todo dia)

- [ ] **C1.** Quando entra material (devolução ou entrada) de um produto que tem **Entrega Futura** em aberto, vincular a
  quantidade que ficou disponível à venda que está esperando: Entrega Futura diminui, Reserva aumenta, disponível
  bate. Ex. do Vinícius: geral 10, reserva 10, disponível 0; venda de 5 → entrega futura 5, disponível −5 (abre
  necessidade de compra para a Débora); entra devolução de 5 → geral 15, disponível 0, mas entrega futura continua 5 →
  o Mateus vincula os 5 → entrega futura 0, reserva 15. Evita compra desnecessária (peças de giro: lâmpada, fita).
  Devolução de peça já instalada/usada **não** é vinculada (fica disponível ou vai para Casa Cor, conforme o estado).
- [ ] **C2.** Disponível positivo e Entrega Futura ao mesmo tempo não deveria existir (ex. 66554: disponível 19 e
  entrega futura 5 → depois de vincular, disponível 14). Investigar de onde vieram os 5 da 66554 (separação parcial?
  empréstimo? planilha?).
- [ ] **C3.** Antes de implementar: **o Mateus vai mostrar a rotina atual** (transferência de reserva) — levantar a tela
  e o passo a passo com ele.

### Bloco D — Estoque da planilha x estoque do sistema

- [ ] **D1. Decisão a confirmar (Filippo/Vinícius):** "teoricamente não vai poder ficar carregando mais a planilha" de
  estoque — usar os dois sistemas em paralelo e um bater com o outro; carregar a planilha por cima bagunça o estoque
  (ex. 9801: planilha de ontem com disponível −204 + entrada de 400 da Débora hoje). Hoje o sync da Connect grava
  `estoque_total`/`estoque_disponivel`/`estoque_showroom` todo dia.
- [x] **D2.** Conferir se todo orçamento aprovado está indo para Entrega Futura mesmo com estoque disponível (dúvida
  levantada com a venda de exemplo da 9801).
- [x] **D3.** Compra simulada de 10 unidades (teste do Pedro) aparecendo na peça — localizar e remover.

## Perguntas abertas

1. A1: "Inativar" fica só para o Vinícius ou para os 5 que podem alterar (A5)?
2. A3: aba separada "Concluídos" ou filtro de status com padrão "Em aberto"?
3. A4: "tira toda, deixa só a prioridade" — tirar a opção "Todas" também do filtro de prioridade?
4. B1: a Entrega Futura entra na conta do disponível da lista (hoje a Connect manda negativo quando falta)? Pela fala:
   disponível = geral − reserva − separação, e a entrega futura é tratada pela rotina C.
5. D1: parar de importar o **estoque** da Connect (mantendo preço/fiscal da SPEC-190)? A partir de quando?

## Realizado (09/10/2026)

Migration `20261009_194_spec191_producao_permissao_data_venda` (dry-run com teste como usuário comum e como editor,
depois aplicada com autorização do usuário). Publicados: Controle de Produção (Skip 60535) v0.0.16 `f485e3d` e Cadastro
(Skip 36668) v0.0.100 `510e81f`. Nenhuma Edge Function foi redeployada (conferido pela API).

- **A1** `producao_pedidos.inativo/inativado_em/inativado_por`; botão "Inativar" (com confirmação) e "Reativar" na aba
  Inativos. Nada é apagado. Inativar fica com os mesmos que podem alterar (A5) — pergunta aberta 1.
- **A2** O "Editar" já existia (SPEC-174), mas a coluna Ação ficava no fim de uma tabela de 1300px e saía da tela.
  Agora a coluna é fixa à direita.
- **A3** Abas "Em aberto" (padrão) / "Concluídos" (status Pronto) / "Inativos". Pergunta aberta 2 resolvida como aba.
- **A4** Filtros mostram "Empresas" e "Prioridade"; dentro, "Todas" + Foco/ISLIGHT/Manoella e Normal/Urgente.
- **A5** Tabela `producao_editores` (e-mail) + função `producao_pode_alterar()`; RLS de INSERT/UPDATE/DELETE de todas
  as tabelas `producao_*` exige estar na lista. Lista: Vinícius, Débora, Matheus, Vitória + Pedro/Filippo (suporte).
  **João entra quando tiver e-mail** (`INSERT INTO producao_editores (email, nome) VALUES (...)`, sem migration).
  Quem não está na lista vê tudo e lê "Somente visualização".
- **B1/B2** Disponível = Estoque Geral − maior(Reserva+Separação do sistema, reservado da Connect) — decisão do usuário
  09/10, porque as duas reservas convivem enquanto a Connect roda em paralelo. Mesma função (`calcularDisponivel`) na
  coluna da lista e no destaque do painel. 6654 → 52 − 33 = **19**; 10289 → 568 − 757 = −189 (o 191 da reunião era
  o dado da Connect daquele dia; a planilha muda todo dia).
- **B3** `vw_cadastro_produto_movimentos.data_venda` = primeira vez que virou "Orçamento Aprovado" (quando ganha o
  número da venda); sem histórico, aceite do cliente. Abas mostram "Data da Venda".
- **B4** Setores numa lista estreita com linha pontilhada até a quantidade; clicar continua abrindo o detalhe.
- **B5** Saiu a faixa "Fornecedor Sugerido · Pendente". O cabeçalho (código/referência/descrição) ficou, porque é o
  que mostra qual peça está selecionada quando a lista rola.
- **C2 (investigado)** Os 5 de Entrega Futura da 6654 vieram da aprovação do ORC-0034 (VENDA-0002) em 15/09: 34
  peças, e só 29 apareciam livres naquele dia (número da Connect) → 29 reserva + 5 entrega futura. Não foi separação
  parcial nem empréstimo. Esses 5 são exatamente o caso da rotina C1 ("tratar a reserva").
- **D2** Não é todo orçamento: a aprovação reserva até `estoque − quantidade_reservada` de `estoque_itens`, e esse
  reservado é sobrescrito todo dia pela planilha da Connect. A 9801 (ORC-0032, 11/09) foi inteira para Entrega Futura
  porque a Connect dizia disponível negativo naquele dia. Liga direto com D1.
- **D3** Pedido de compra nº 1771 (obs. "Teste", 18/09, 10 un. da 6654) cancelado com autorização do usuário.

**Falta:** C1/C3 (rotina "tratar a reserva" — depende do Mateus mostrar a rotina atual) e D1 (decisão
Filippo/Vinícius sobre parar de importar estoque da Connect).
