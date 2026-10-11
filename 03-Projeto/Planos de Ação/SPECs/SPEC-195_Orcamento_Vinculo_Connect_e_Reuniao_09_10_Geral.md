---
titulo: "SPEC-195 — Orçamento de vínculo (venda já aprovada na Connect) + pendências da reunião 30 (09/10)"
status: aguardando aprovação
data_ultima_modificacao: 2026-10-11
origem:
  - "pedido do usuário 11/10: orçamento que só liga peças e valor, sem estoque e sem financeiro"
  - "02-Reunioes/30. Lucenera (Filippo e Vinicius) 09.10.2026_ Questões gerais antes do começo da implematação do sistema/Reunião.01 a .05"
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554)
  - Vendas (vendas-lucenera) — não pode emitir nota de venda de vínculo
  - Separação Parcial / Logística / Compras (Necessidade de Compra) — não podem enxergar vínculo como pendência
  - Cadastro — Consulta de Produtos (cadastro-lucenera-b86fe, Skip 36668)
  - Central (Acesso a Sistemas)
  - Supabase (orcamentos, orcamento_itens, projeto_itens, aprovar_orcamento_financeiro, views de estoque/compra)
relacionadas: [SPEC-050, SPEC-136, SPEC-152, SPEC-183, SPEC-190, SPEC-191, SPEC-193, SPEC-194]
---

# SPEC-195 — Orçamento de vínculo (Connect) + pendências da reunião 30

> **Intocável:** a regra de custo da SPEC-190 e a decisão de impostos da SPEC-193 (cada produto com os próprios
> impostos, sem motor fiscal). A Reunião 30.01 é a mesma conversa da reunião 29 e já está coberta pela SPEC-193.

## Bloco A — Orçamento de vínculo (prioridade)

### Por quê

Connect e sistema novo vão rodar em paralelo. Muitas vendas já foram **aprovadas na Connect**, que já reservou o
estoque, gerou o financeiro e emitiu a nota. O sistema novo precisa saber **quais peças e qual valor** pertencem a
cada projeto/cliente, sem reservar estoque de novo, sem gerar parcela/boleto e sem nota.

### Como a aprovação funciona hoje (conferido no banco em 11/10)

`aprovar_orcamento_financeiro` (ramo venda) faz tudo de uma vez:

| O que grava | Tabela | No vínculo |
|---|---|---|
| número da venda `VENDA-XXXX` | `orcamentos.numero_venda` | **não** (pergunta 2) |
| itens do projeto (peça, qtd, preço, L) | `projeto_itens` | **sim** — é o "link" |
| reserva de estoque | `estoque_itens.quantidade_reservada`, `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item` | **não** |
| parcelas | `projeto_parcelas` | **não** |
| boletos / contas a pagar de permuta | `boletos` | **não** |
| histórico | `historico_status_orcamentos` | sim |

Hoje há só 20 orçamentos no sistema (4 aprovados). Já existe o **import de XML da Connect** no Novo Orçamento
(SPEC-050), que preenche cliente/itens e grava `origem_connect_cod_orcamento` (único) — é a porta de entrada natural
do vínculo.

### Checklist

- [ ] **A1. Marcar o orçamento como vínculo.** Nova coluna `orcamentos.vinculo_connect boolean NOT NULL DEFAULT false`
  (ou `natureza_operacao = 'vinculo_connect'` — decidir na implementação; a coluna é mais segura porque `natureza`
  já separa venda × devolução). Exige `origem_connect_cod_orcamento` preenchido (número do orçamento na Connect).
- [ ] **A2. RPC nova `vincular_orcamento_connect(p_orcamento_id)`**, separada de `aprovar_orcamento_financeiro`
  (a aprovação normal não muda):
  - mesmas validações básicas: projeto, cliente, empresa, itens com produto cadastrado, quantidade e preço > 0;
  - **não** exige forma/plano de pagamento;
  - grava `projeto_itens` com `orcamento_id`/`orcamento_item_id`/`l_fixo` (igual à aprovação);
  - **não** toca estoque, parcelas, boletos;
  - status final: `Orçamento Aprovado` (com `vinculo_connect = true`) ou um status próprio "Vinculado (Connect)" —
    pergunta 3;
  - grava histórico "Vínculo de venda aprovada na Connect nº X — sem estoque e sem financeiro";
  - idempotente (rodar duas vezes não duplica `projeto_itens`);
  - permissão: `hub_pode_executar(..., 'orcamentos', NULL, 'aprovar')` (mesma de aprovar).
- [ ] **A3. Tela (Orçamentos):** no orçamento importado da Connect (ou marcado à mão), botão **"Vincular venda da
  Connect"** no lugar de "Enviar para aprovação". Pula as etapas cliente/equipe/financeira. Etiqueta visível
  "Vínculo Connect nº X" na lista, no detalhe e no filtro.
- [ ] **A4. Ninguém pode tratar vínculo como venda nova.** Conferir e ajustar cada consumidor:
  - **Vendas / Pendências de Nota Fiscal:** vínculo não aparece para emitir nota (a Connect já emitiu).
  - **Necessidade de Compra** (`vw_necessidade_compra`, `_detalhe`, `_item_orcamento`) e **Entrega Futura**
    (`vw_entrega_futura_projeto_item`, `vw_pendencias_re_reserva`): leem `projeto_itens`; sem filtro, um item de
    vínculo sem reserva pode virar **pendência de compra falsa**. Excluir vínculo.
  - **Separação Parcial / Logística / Trocar reserva / Devolução:** item de vínculo não tem saldo no sistema; bloquear
    ações que movem estoque nele até decidir a virada (pergunta 4).
  - **Dashboard / relatórios de venda, RT e comissão:** decidir se o valor conta (pergunta 5).
  - `vw_cadastro_produto_movimentos` (aba Movimentos do Cadastro): mostrar com a etiqueta "Connect".
- [ ] **A5. Desfazer:** `desvincular_orcamento_connect` apaga os `projeto_itens` do vínculo e volta para rascunho
  (só se nada foi feito em cima deles).
- [ ] **A6. Teste ponta a ponta** com um XML real da Connect: importar → vincular → conferir que `estoque_itens`,
  `estoque_saldos_projeto_item`, `projeto_parcelas` e `boletos` **não mudaram**, que o projeto mostra peças/valor e
  que Necessidade de Compra e Vendas não mostram nada novo.

## Bloco B — Consulta de Produtos (reunião 30.02)

- [ ] **B1. Não carregar peça com estoque zero na lista inicial.** A busca continua procurando em todas as peças
  (Filippo: *"se eu procurar, procura sim"*). Junta com a view enxuta de estoque da SPEC-193 C1.
- [ ] **B2. Busca combinada marca + categoria**: digitar "Stella lâmpada" traz o que é da marca Stella e categoria
  Lâmpada. Na Consulta aparece **marca, não fornecedor** (fornecedor só no Cadastro — decisão da SPEC-193 B2).
- [ ] **B3. Campos da Consulta**: código interno, referência, descrição, marca, categoria/grupo, setores e preço de
  venda (sem impostos — SPEC-193 C2).
- [ ] **B4. Linhas da tabela invisíveis no computador do Vinícius** (os "quadradinhos" não aparecem): aumentar o
  contraste das bordas/linhas.
- [ ] **B5. "Fora do disponível"** (Casa Cor e Garantia) fica — Vinícius confirmou que faz sentido; só deixar mais
  bonito, ao lado do número.

## Bloco C — Trocar reserva direto da peça (reunião 30.02)

Hoje a troca existe na **Separação Parcial**, a partir da venda (com log de quem, quando, de quem para quem). O
Filippo pediu a mesma coisa **sem sair da Consulta de Produtos**:

- [ ] **C1.** No detalhe da reserva da peça (ex. 6654: reserva 21 de vários clientes), botão **"Trocar"** → janela:
  quantas peças, de qual cliente/venda e **de qual L**, para qual venda em aberto (busca pelo nome do cliente/
  orçamento). Usa a mesma rotina da Separação Parcial (mesmo log, mesma regra: em separação não pode).
- [ ] **C2.** Duas situações (Vinícius): (a) venda feita → continua na Separação Parcial; (b) cliente chegou agora →
  faz o orçamento/venda e depois troca. A troca só vale para quem já tem venda.
- [ ] **C3.** Pergunta 6: precisa de autorização do vendedor dono da reserva?

## Bloco D — Separação: editar lista em vez de estornar tudo (reunião 30.02)

- [ ] **D1.** Hoje, para acrescentar 1 item numa lista de 50, é preciso estornar as 50 e refazer. Permitir
  **editar a lista** (incluir/remover item) enquanto ela não foi entregue ao Matheus. Levantar a regra exata com o
  Vinícius/Matheus antes de implementar.

## Bloco E — Orçamentos (reunião 30.02)

- [ ] **E1. Filtro por etapa** na lista: aprovação do cliente, da equipe, financeira, aprovados.
- [ ] **E2.** Conferir o aviso de **atualizar preço depois de 10 dias** (validade do orçamento): Pedro disse que já
  funciona; validar com o Vinícius.

## Bloco F — Acesso por área (reunião 30.03) → usa na SPEC-194 e na SPEC-183

| Área | Sistemas | Quem |
|---|---|---|
| Projetos (equipe de vendas) | Orçamentos, Sistema de Entregas, Fichas Técnicas, Showroom, Central | equipe de projetos |
| Financeiro / CRM | Financeiro, CRM | Lana, Vinícius, Carol |
| Estoque | Logística, Consulta de Produtos, Sistema de Entregas | Débora, Vitória, Matheus, Alexandre (e os auxiliares da SPEC-194) |
| Controle de Garantia / Produção | "por enquanto nem usamos" | — |

- [ ] **F1.** Aplicar essa matriz em Acesso a Sistemas (uma vez, "para nunca mais"), começando pelos 6 auxiliares de
  estoque da SPEC-194.
- [ ] **F2.** Dashboard Financeiro: **esconder de todo mundo o que o Filippo recebe**.

## Bloco G — Backlog registrado (não fazer agora)

Filippo: *"não interessa agora implementar coisas que não são indispensáveis"*. Ficam só anotados:

- G1. Fotos e fichas técnicas do SharePoint vinculadas à peça pelo código (Pedro já começou a trazer).
- G2. Tipos de contato e categorias financeiras como **tabelas de referência com ID** (hoje é texto) — analisar.
- G3. Relatório semanal por e-mail (sexta) para o Filippo com o resumo administrativo — em andamento.
- G4. Uma "agenda de ações" dentro do sistema para guardar esses itens.

## Perguntas abertas

1. **A1/A3:** o vínculo nasce sempre do **XML da Connect** (import já existe) ou também pode ser digitado à mão?
2. **A2:** o vínculo ganha número `VENDA-XXXX` do sistema, ou fica só com o **nº da Connect**? (Recomendo só o da
   Connect, para não parecer venda feita aqui.)
3. **A2:** status final `Orçamento Aprovado` com etiqueta "Vínculo Connect", ou um status próprio
   "Vinculado (Connect)"? (Recomendo status próprio: nenhuma tela que filtra "Orçamento Aprovado" pega por engano.)
4. **A4:** quando a entrega dessas vendas acontecer, ela é feita **na Connect** (sistema novo só consulta) ou o
   sistema novo deve permitir separar/entregar, puxando a reserva nessa hora?
5. **A4:** o valor do vínculo entra nos relatórios de venda, RT e comissão do sistema novo?
6. **C3:** trocar reserva de outro vendedor precisa de autorização dele, ou basta ficar no log?

## Realizado

(nada ainda — SPEC criada em 11/10/2026. O mapa da aprovação e dos consumidores foi conferido no banco no mesmo dia.)
