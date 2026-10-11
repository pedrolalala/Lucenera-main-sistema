---
titulo: "SPEC-195 — Orçamento de vínculo (venda já aprovada na Connect) + pendências da reunião 30 (09/10)"
status: em andamento — F1 Estoque e F2 aplicados; A aguardando respostas
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

> **NÃO MEXER — impostos e custo da peça (decisão do usuário, 11/10):** a conta de imposto da peça **já está
> funcionando** e esta SPEC **não altera nada** nela: nem a regra de custo da SPEC-190 (custo − desconto + BDI de
> Frete/ST/IPI/Outras Despesas × (1 + % Lucro)), nem os campos de imposto do cadastro, nem o import diário da
> planilha. A Reunião 30.01 é a mesma conversa da reunião 29 e já está coberta pela SPEC-193.
>
> **Import de XML da Connect (SPEC-050):** já funciona e fica como está.

## Bloco A — Orçamento de vínculo (prioridade)

### Por quê

Connect e sistema novo vão rodar em paralelo. Muitas vendas já foram **aprovadas na Connect**, que já reservou o
estoque, gerou o financeiro e emitiu a nota. O sistema novo precisa saber **quais peças e qual valor** pertencem a
cada projeto/cliente, sem reservar estoque de novo, sem gerar parcela/boleto e sem nota.

### Como a aprovação funciona hoje (conferido no banco em 11/10)

`aprovar_orcamento_financeiro` (ramo venda) faz tudo de uma vez:

| O que grava | Tabela | No vínculo |
|---|---|---|
| número da venda | `orcamentos.numero_venda` | **sim, o número da Connect** (decisão 11/10) |
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
  - **número da venda = número da Connect** (decisão 11/10). Quando o sistema novo passar a vender de verdade, a
    sequência própria **continua a partir do último número da Connect** (não recomeça em 0001 e não repete número);
  - status final: **`Orçamento Aprovado`** com `vinculo_connect = true` — **sem status próprio** (decisão 11/10). Por
    isso o filtro do A4 (pela coluna, não pelo status) é obrigatório antes de ir para produção;
  - grava histórico "Vínculo de venda aprovada na Connect nº X — sem estoque e sem financeiro";
  - idempotente (rodar duas vezes não duplica `projeto_itens`);
  - permissão: `hub_pode_executar(..., 'orcamentos', NULL, 'aprovar')` (mesma de aprovar).
- [ ] **A3. Tela (Orçamentos):** no orçamento importado da Connect (ou marcado à mão), botão **"Vincular venda da
  Connect"** no lugar de "Enviar para aprovação". Pula as etapas cliente/equipe/financeira. Etiqueta visível
  "Vínculo Connect nº X" na lista, no detalhe e no filtro.
- [ ] **A4. (DEPOIS — decisão do usuário 11/10: resolver mais tarde) Ninguém pode tratar vínculo como venda nova.** Conferir e ajustar cada consumidor:
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

## Bloco B — Consulta de Produtos (reunião 30.02 + respostas 11/10)

- [ ] **B1. Filtro "Só com estoque"** (positivo **ou negativo**; esconde só os zerados). A busca continua achando
  todas as peças. Peça **desativada** aparece com a marcação **"Desativada"** (não some).
- [ ] **B2. Marca prevalece** na Consulta e na busca. O **fornecedor continua no Editar** da peça (campo que já
  existe), não na lista. Busca combinada marca + categoria: "Stella lâmpada".
- [ ] **B3. Campos da Consulta**: código interno, referência, descrição, marca, categoria/grupo, setores e preço de
  venda (sem impostos — SPEC-193 C2).
- [ ] **B4. Linhas da tabela em preto**, no estilo padrão de sistema operacional (hoje somem no computador do
  Vinícius).
- [ ] **B5. "Fora do disponível"** (Casa Cor e Garantia) fica ao lado do número e o texto deixa claro que a peça
  **não está disponível** (ex.: "não disponível").

## ~~Bloco C — Trocar reserva direto da peça~~ (descartado 11/10)

Decidido na própria reunião que não faz sentido: a troca já existe na Separação Parcial, a partir da venda
(Vinícius: na venda feita é lá que elas vão; Filippo: *"ficou da hora do jeito que nós fez"*).

## Bloco D — Editar em vez de estornar tudo (a confirmar)

Trecho da transcrição (30.02, 81:58–83:33):
- Pedro: *"Estornar é estornar uma lista de separação. Tipo, alterou uma lista, tem que estornar para fazer de novo."*
- Vinícius: *"Uma vez eu fui separar o material do Clara e era um trilhão de item. Aí um item tinha ficado para
  trás. Para não ter que gerar uma lista separada, eu estornei tudo e tirei tudo de novo."*
- *"Você não foi lá em São Paulo e mudou um monte de coisa? Teve que estornar todas as listas."*
- *"No caso dela teria que ter como editar, mas não existe isso."* / *"de 50 itens eu tive que estornar os 50 para
  pegar 51"* / *"Só pegou ali, apertou editar."* / Filippo: *"eu não quero repetir as cagadas do outro."*

Leitura: é a **lista de separação** (na Connect), e o motivo é o **orçamento que mudou** (item esquecido ou cliente
alterou o pedido). O usuário entende que o ponto é o orçamento.
- [ ] **D1.** Confirmar com o Vinícius: quando o orçamento aprovado muda (entra ou sai item), a lista de separação
  já gerada deve **se ajustar só na diferença** (sem estornar tudo)? Ou o pedido é poder **editar a lista** direto?

## ~~Bloco E — Filtro por etapa no Orçamento~~ (já existe — confirmado 11/10)

## Bloco F — Acesso por área (reunião 30.03) → usa na SPEC-194 e na SPEC-183

| Área | Sistemas | Quem |
|---|---|---|
| Projetos (equipe de vendas) | Orçamentos, Sistema de Entregas, Fichas Técnicas, Showroom, Central | equipe de projetos |
| Financeiro / CRM | Financeiro, CRM | Lana, Vinícius, Carol |
| Estoque | Logística, Consulta de Produtos, Sistema de Entregas | Débora, Vitória, Matheus, Alexandre (e os auxiliares da SPEC-194) |
| Controle de Garantia / Produção | "por enquanto nem usamos" | — |

- [x] **F1 (Estoque, 11/10).** Liberados Separação Parcial, Consultar Produtos e Sistema de Entregas para Vitória,
  Matheus, Alexandre e os 5 auxiliares (Débora já tinha). Quem não tinha papel ganhou o papel `estoque`. Só
  acrescentou, nada removido.
- [x] **F1 (Projetos, 11/10).** Orçamentos, Sistema de Entregas, Fichas Técnicas e Showroom liberados para as 3
  equipes (lista do usuário): **Thais** (Helena Fogaça, Murillo Spimpolo, Thais Gomes, Trícia Borges), **Marina**
  (Giovanna Nori, Isabella Jacob, Ketlyn Verônica, Marina Pousa), **Thairine** (Adriana Jabur, Giovana Gonella,
  Rafaela Netto, Thairine Silva). 10 ganharam o papel `equipe_projetos` (Marina e Thairine já tinham); Rafaela
  Netto entrou na equipe Thairine (estava sem equipe). Os outros 11 já estavam na equipe certa. Só acrescentou.
  Financeiro/CRM (Lana, Vinícius, Carol): já têm os acessos de hoje — não mexido.
- [x] **F2 (11/10).** Dashboard Financeiro: a Distribuição de Lucro (RETIRADAS LUCRO FILIPPO/MANOELLA e LUCRO
  DISTRIBUÍDO FILIPPO) só aparece para **Filippo, Pedro e Vinícius** (decisão do usuário). Migration
  `20261011_196_dashboard_ocultar_distribuicao_lucro` **aplicada** (aprovada pelo usuário): função
  `pode_ver_distribuicao_lucro()` + filtro nas views `v_financeiro_realizado` e `v_cash_flow_lucenera`; conexão direta
  e service_role continuam vendo tudo (Panorama/imports); `anon` revogado. Conferido depois: Vinícius 193 linhas, Lana
  0. Tela: cartão escondido para quem não pode (Skip 41135 v0.0.46 `3ff7aa4`, publicado; nenhuma Edge Function
  alterada).
- **Achado de segurança (11/10):** a tabela `transacoes` tem política `authenticated_all_transacoes = true` —
  qualquer pessoa com login (inclusive os auxiliares novos) consegue ler e alterar todo o financeiro pela API. E as
  views financeiras estavam abertas a `anon`. Precisa de SPEC própria.

## Bloco G — Backlog registrado (não fazer agora)

Filippo: *"não interessa agora implementar coisas que não são indispensáveis"*. Ficam só anotados:

- G1. Fotos e fichas técnicas do SharePoint vinculadas à peça pelo código (Pedro já começou a trazer).
- G2. Tipos de contato e categorias financeiras como **tabelas de referência com ID** (hoje é texto) — analisar.
- G3. Relatório semanal por e-mail (sexta) para o Filippo com o resumo administrativo — em andamento.
- G4. Uma "agenda de ações" dentro do sistema para guardar esses itens.

## Perguntas abertas

1. **D1:** ver Bloco D (confirmar com o Vinícius).

Respondidas em 11/10: número = o da Connect, e a sequência própria continua depois dele; sem status próprio
(`Orçamento Aprovado` + `vinculo_connect`); equipes de projetos (F1); XML fica como está; riscos do A4 ficam para
depois; impostos não mexe; filtro de estoque com desativadas marcadas; marca prevalece (fornecedor no Editar);
linhas pretas; "não disponível"; troca direta descartada; filtro por etapa já existe; matriz de acesso aprovada.

## Realizado

(nada ainda — SPEC criada em 11/10/2026. O mapa da aprovação e dos consumidores foi conferido no banco no mesmo dia.)
