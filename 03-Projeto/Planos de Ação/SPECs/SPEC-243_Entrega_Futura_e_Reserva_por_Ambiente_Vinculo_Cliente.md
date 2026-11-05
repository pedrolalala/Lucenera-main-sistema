---
titulo: "SPEC-243 — Herança Connect por cliente: vendas da Connect viram orçamentos do sistema (Reserva × Ambiente e Entrega Futura × Ambiente), com vínculo Connect em orçamento, venda e Venda Parcial"
status: não iniciado
data_ultima_modificacao: 2026-11-04
sistemas_envolvidos:
  - Banco (Supabase SP) — tabela de espelho, orçamentos/itens/saldos gerados, vínculos Connect, tratamento ("matar"), views, RLS
  - Script de importação (scripts/) — importador das 2 planilhas, na rodada de 04/11
  - Venda Parcial (separacao-parcial) — duas visões: vendas do sistema Lucenera × vendas parciais Connect
  - Cadastro (consulta de produtos) — setores "Reserva herança Connect" e "Entrega futura herança Connect" por cliente
  - Orçamentos (gestao-financeira-clone-544cb) — "Orçamento vinculado Connect" em todo orçamento; "Vendas vinculadas Connect" em toda venda
  - Compras (entrada de NF) — mostra a entrega futura do sistema e a da herança Connect juntas
  - Logística — entrega de peça da herança baixa a herança (fase 2)
---

# SPEC-243 — Herança Connect por cliente (vendas da Connect viram orçamentos do sistema)

> Origem: pedido do usuário em 04/11/2026 e reunião "41. Lucenera (Vinicius e Matheus) 04.11.2026 / Reunião.01".
> Planilhas da Connect de 04/11: `EntregaFuturaxAmbiente.xlsx`, `ReservaxAmbiente (1).xlsx`, junto de `Produtos__2026-11-04`,
> `PedidoCompra_2026-11-04`, `ContaPagar_2026-11-04`, `ContaReceber_2026-11-04`.
> Relacionadas: SPEC-232 (herança Connect não muda com venda interna), SPEC-235 (Venda Parcial), SPEC-195 (vínculo Connect),
> SPEC-010/013 (reserva por cliente), SPEC-012 (entrega futura).
> **Esta SPEC é só o desenho. Nada foi implementado nem aplicado no banco.**
> Versão 2 (04/11): reescrita. A v1 tratava as planilhas como "somente espelho". Como cada linha traz venda, cliente, projeto, peça,
> L e quantidade, a venda Connect passa a virar orçamento do sistema (mesma Venda Parcial, mesmo layout).

## Checklist de Ação

- [x] A — Perguntas respondidas (04/11) e reunião com Vinicius e Matheus incorporada.
- [x] A2 — Limpar os dados de teste do sistema (4 orçamentos, incl. o teste da venda Connect 5882) — seção 7. Feito em 04/11 com backup em `backup.`.
- [x] B — Regras de saldo, triggers e campos obrigatórios conferidos (seção 4.3); Entrega Futura = regra A.
- [x] C1 — Migration **264** (**APLICADA em 04/11**, autorizada): `connect_reserva_ambiente` (espelho bruto), `connect_reserva_tratamento`, `orcamentos.origem/connect_lote/vendas_vinculadas_connect`, permissão `pode_tratar_heranca_connect`, RLS, views. Pasta `supabase/db/migrations/20261104_264_spec243_heranca_connect_base/`. Conferido no banco depois de aplicar: tabelas, views, colunas e permissão do Matheus criadas; RLS ligada; 0 orçamentos.
- [x] C2 — Migration **266** (função de carga) **APLICADA em 04/11** (só cria funções; sem dado): `20261104_266_spec243_funcao_carga_connect/` (`up.sql`, `rollback.sql`, `dry_run.sql`).
- [x] D — Script `scripts/importar_reserva_entrega_futura_connect.py` escrito (dry-run por padrão = roda tudo e desfaz; `--aplicar` grava; idempotente; preserva o tratado). **`--aplicar` rodado em 04/11 (autorizado): 191 orçamentos Connect gravados.**
- [ ] E — Rodada de 04/11 na ordem certa (produtos → pedidos → contas → reserva/entrega futura) e reconciliação por peça com Produtos.
- [ ] F — Vínculo em tudo: "Orçamento vinculado Connect" e "Vendas vinculadas Connect" (seção 6.1).
- [x] G — Venda Parcial com duas visões (seção 6.2): **NO AR** (commit 2fba684, https://separacao-lucenera.pages.dev, conferido que o código novo está no bundle da tela); migration 268 APLICADA. Falta o teste visual do usuário.
- [x] H — Cadastro: setores "Reserva herança Connect" e "Entrega futura herança Connect" por cliente: migration 270 **APLICADA** e código **commitado e pushado** (`cadastro-lucenera` 9e5393f); falta o teste visual do usuário.
- [ ] I — Compras (entrada de NF): as duas entregas futuras juntas.
- [ ] J — Destaque de venda antiga (≤ 2477) e fila para "matar" (fase 2, seção 6.3).
- [ ] K — Conferência de totais e documentação (CHANGELOG, AI_DB_CONTEXT, Pendencias).

### Passos manuais do usuário

- [ ] Responder as perguntas da seção "Perguntas ainda em aberto".
- [ ] Confirmar, orçamento por orçamento, a limpeza dos dados de teste.
- [ ] Autorizar a aplicação da migration (dry-run e ROLLBACK primeiro).
- [ ] Conferir 3 ou 4 vendas conhecidas na Venda Parcial Connect (ex.: venda 5799, "25.411 Manuella e Matheus").

## Objetivo

Hoje o banco sabe **quanto** de cada peça está reservado na Connect (`estoque_itens.quantidade_reservada`, a "herança Connect"), mas
**não sabe de quem é**. As planilhas dizem: venda, cliente, projeto, peça, L, quantidade e data, separados em Reserva e Entrega Futura.

Resultado esperado: toda venda da Connect aparece no sistema como orçamento/venda, **com seus itens por L**, na **mesma Venda Parcial** do dia a dia
(aba própria), ligada ao projeto e ao cliente, para o Matheus e as projetistas consultarem, separarem e "matarem" o que ficou velho —
**sem tocar em Contas a Pagar, Contas a Receber, parcelas, boletos nem no estoque geral na importação**.

## Decisões aprovadas

### Usuário (04/11)
- Ligação pelos dois: **número da venda e código do projeto**.
- Linha que não casa aparece **com aviso e com o motivo**.
- **Valor de venda só para Administração**; a equipe de projetos nunca vê.
- Reserva sem data de entrega = provável erro da Connect: **aviso**, sem inventar data.
- Mesmo desenho do sistema atual (itens por L, colunas Reserva e Entrega Futura, links).
- **Os 4 orçamentos de teste do sistema são apagados** (combinado com o Vinicius): tudo passa a vir das planilhas.
- Importação manual, na rodada, como as outras planilhas.
- **Vínculo em tudo:** todo orçamento com "Orçamento vinculado Connect", toda venda com "Vendas vinculadas Connect", Venda Parcial com a visão "Vendas parciais Connect".
- **Cada venda Connect vira orçamento do sistema com `projeto_itens` e `l_fixo`** (esta versão).
- **A coluna `Funcionario` da planilha é o digitador do orçamento** (`orcamentos.digitado_por`). A **equipe** vem da equipe do funcionário
  (`funcionarios.equipe_id` → `equipes_projetos`), nunca da planilha.
- **A empresa é deduzida por engenharia reversa** a partir dos dados que já temos (seção 4.5), sem pedir ao usuário.
- **Regra fixa (registrada em `AGENTS.md`): `LUCE NERA` (nome no Contas a Receber/Pagar da Connect) = MANOELLA no banco.**
- **Fonte da empresa: Contas a Receber e Contas a Pagar da Connect** (as fontes confiáveis). Venda sem empresa deduzida fica **só no espelho, com aviso**.
- **Equipe do orçamento Connect** (definida pelo usuário em 04/11, igual ao cadastro atual):
  - **Equipe Marina:** Beatriz Vicentini, Giovanna Nori, Isabella Jacob, Ketlyn Verônica, Marina Pousa.
  - **Equipe Thairine:** Adriana Jabur, Giovana Gonella, Rafaela Netto, Thairine Silva.
  - **Equipe Thais:** Helena Fogaça, Murillo Spimpolo, Thais Gomes, Trícia Borges.
  - **Todo o resto vai para a equipe "Administração"** (Débora, Filippo, Mariane, Moara, Matheus, Vinicius, Vitória e os ex-funcionários Katia, Ricardo e Terezinha).
  - "Planejado no escritório" apareceu nas listas do usuário como linha avulsa, não como pessoa: **não é tratado** (ver pergunta 3).

### Reunião de 04/11 (Vinicius e Matheus)
- **Trazer tudo e "matar" depois**; o filtro de vendas velhas antes de importar foi descartado (não há tempo; o Matheus levaria cerca de 30 dias em paralelo).
- **3 linhas da Entrega Futura nem entram:** "PRODUTO ESPCIAL" sem cadastro (orçamentos 79, 115 e 4252; produto faturado sem cadastro, coisa antiga).
- **A importação não mexe em estoque.** O estoque geral vem da planilha de Produtos; os números das planilhas **precisam bater** com ela.
- Mexer em estoque só por operação feita no nosso sistema (fase 2): sai da herança e o estoque geral acompanha.
- Setores novos "Reserva herança Connect" e "Entrega futura herança Connect". As reservas/entregas futuras do sistema novo começam em zero.
- Venda Parcial com duas visões: **sistema Lucenera** × **Connect**; os dados de teste são zerados porque os da Connect vêm com histórico.
- Compras (entrada de mercadoria): as duas entregas futuras aparecem juntas, para não virar duas entradas.
- **Quem "mata":** só Matheus e administração (Vinicius), sempre com observação e log.
- **Antiguidade:** venda Connect nº **≤ 2477** (última de 30/06/2025) com cartão de cor diferente, mostrando vendedor e equipe. A cor é da **venda**, não da peça.
- Venda velha pode ser real (ex.: venda 74, entrega segurada porque o cliente devia): **nada é apagado automaticamente**.

## Definição da SPEC

### 1. O que tem em cada planilha (conferido em 04/11)

Colunas idênticas: `Orçamento, Venda, Cliente, Nome, Produto, Referência, Descrição, Qtd, Ambiente, Data Entrega, Funcionario, Valor Venda, Observação, Adicional`.

| | Entrega Futura × Ambiente | Reserva × Ambiente |
|---|---|---|
| Linhas | 1.009 (**importam 1.006**) | 2.820 |
| Orçamentos / vendas distintos | 151 / 151 | 265 / 265 |
| Clientes distintos (código Connect) | 100 | 167 |
| Soma de Qtd | 5.555 | 17.215,7 |
| Ambientes (L) distintos | 111 | 147 |
| Sem ambiente | 6 | 25 |
| Sem data de entrega | 0 | 2.131 |
| Sem venda | 0 | 1 |
| "Produto 0" (produto especial) — **não importa** | 3 | 0 |
| Linhas repetidas (mesmo orçamento + peça + ambiente) | 0 | 4 |
| Datas de entrega | 2024: 18 · 2025: 139 · 2026: 852 | 2024: 6 · 2025: 405 · 2026: 278 |

- 100 orçamentos aparecem **nas duas** planilhas (parte já reservada, parte em entrega futura) → o mesmo orçamento Connect recebe itens das duas.
- O mesmo L pode ter a mesma peça nas duas (ex.: 6 vendidos = 4 em entrega futura + 2 em reserva). **Quantidade vendida e entregue não vêm da Connect**: vendido = reserva + entrega futura; entregue é desconhecido.
- `Nome` = `"24.365 MARIANA MEIRELLES"` (código do projeto + nome do cliente); em parte das linhas não tem código.
- `Valor Venda` é o **total da linha** (2 unidades = 314,66; 4 = 629,32 → unitário = valor ÷ quantidade).
- `Observação` (3 casos: "BRINDE", "GARANTIA – solicitado via email", "peça danificada, pendente SAC") e `Adicional` (vazia) são guardadas.

### 2. Mapa de chaves (testado no banco real em 04/11, só leitura)

| Elo | Tabela e coluna | Acerto Entrega Futura / Reserva | Observação |
|---|---|---|---|
| Peça | `produtos.codigo_produto` | 245/258 · 496/496 | 13 faltantes = peças novas, estão no Produtos de 04/11 |
| Cliente | `contatos.codigo_legado` | 82/100 · 152/167 | Faltantes: clientes novos (≥ 2.830; maior no banco 2.995) |
| Projeto | `projetos.codigo` (extraído do `Nome`) | 82/83 · 120/120 | Projeto 26.121 inexistente; nomes sem padrão `NN.NNN` |
| Venda (financeiro) | `transacoes.cod_venda` | 89/151 · 190/264 | Sobe para 135 e 238 com o Contas a Receber de 04/11. Esse vínculo é só **conferência**: a carga **não grava** em `transacoes` |
| L (ambiente) | `projeto_itens.l_fixo` (formato `L11`) | — | Só existe em vendas do sistema (100 itens). Vendas Connect **passam a ter** `l_fixo` ao serem geradas |
| Orçamento Connect | `orcamentos.origem_connect_cod_orcamento` | — | Hoje 1 de 4 preenchido (SPEC-195); passa a ser a chave da geração |
| Venda Connect | `vendas.cod_venda` | — | Vazio (263 linhas sem código); `transacoes.cod_venda` tem 2.897 vendas, nenhuma com `projeto_id`. **O elo venda → projeto vem da planilha**, não do banco |
| Parcial | `separacoes.numero_venda` | — | Só números do sistema (`VENDA-000X`/`ORC-000X`). Parcial Connect nasce no sistema depois, sobre o orçamento gerado |

### 2.1 Por que linhas não casam (investigado em 04/11)

| Não casa | Causa | Resolve sozinho? |
|---|---|---|
| Venda sem título (62 / 74) | Banco na importação de 14/10; vendas novas só estão no `ContaReceber_2026-11-04` (135/151 e 238/264 casam) | **Sim**, rodando Contas a Receber antes. O resto: "venda sem título no financeiro" |
| Peças (13: 13777–13797) | Cadastradas depois de 14/10; as 5 testadas estão em `Produtos__2026-11-04` | **Sim**, rodando Produtos antes |
| Cliente (23 códigos em cada planilha) | Clientes novos; nenhuma planilha da rodada traz cadastro de cliente | **Não** — pergunta 1 |
| Projeto (1) | Sem projeto no banco (ainda não veio do SharePoint) | Parcial |
| Nome sem código de projeto (17 e 47) | Digitação livre ("23297 HOTEL CLARA", "PROJ. 18.235 LOARA") | Parcial: extrair com mais de um padrão |

A coluna `motivo_sem_vinculo` guarda: `venda_sem_titulo`, `peca_nao_cadastrada`, `cliente_nao_cadastrado`, `projeto_nao_encontrado`, `nome_sem_codigo_projeto`.

### 3. Duas camadas

1. **Espelho bruto** `public.connect_reserva_ambiente`: uma linha por linha da planilha, sempre gravada (mesmo sem vínculo), com o motivo.
2. **Orçamento Connect gerado**: para cada venda Connect **com projeto, cliente e peça casados**, um orçamento do sistema marcado `origem = 'connect'`, com `projeto_itens` por L e saldos
   de Reserva e Entrega Futura. Linha sem projeto/cliente/peça **fica só no espelho** com aviso (`projeto_itens.projeto_id` é obrigatório).

Orçamentos Connect **não aparecem** nas listas normais do Orçamentos (filtro por origem); aparecem na Venda Parcial, na aba Connect, e no Cadastro.

### 4. Banco — o que criar (a confirmar no snapshot antes da migration)

#### 4.1 `public.connect_reserva_ambiente` (espelho)

| Coluna | Observação |
|---|---|
| `id`, `tipo` (`reserva`/`entrega_futura`), `lote_importacao` | |
| `cod_orcamento_connect`, `cod_venda_connect` (NULL se vazio), `cod_cliente_connect` | |
| `nome_bruto`, `projeto_codigo`, `nome_cliente` | extraídos de `Nome` |
| `produto_codigo`, `referencia`, `descricao`, `quantidade` (numeric 12,3) | |
| `ambiente`, `data_entrega`, `aviso_data`, `vendedor_nome`, `observacao`, `adicional` | |
| `valor_venda` | **só Administração** |
| `venda_antiga` boolean | `cod_venda_connect ≤ 2477` (limite configurável) |
| `projeto_id`, `produto_id`, `cliente_id`, `orcamento_id` (gerado), `projeto_item_id` (gerado) | NULL quando não casa |
| `motivo_sem_vinculo` (inclui `digitador_nao_encontrado`, `digitador_sem_equipe`, `empresa_nao_deduzida`, `empresa_ambigua`), `empresa_id` deduzida, `digitado_por`, `created_at` | |

#### 4.2 `public.connect_reserva_tratamento` ("matar", fase 2)

`chave` (tipo + venda + produto + L), `acao` (`mantida_confirmada`, `entregue_sem_estoque`, `entregue_voltou_ao_estoque`, `cancelada_volta_ao_estoque`, `observacao`),
`mexe_estoque` boolean, `quantidade`, `observacao` (**obrigatória**), `usuario_id`, `criado_em`. Escrita: **só Matheus e administração** (função própria,
não `_mov_pode`). **Reimportar não ressuscita linha tratada** (a planilha final sairá de novo perto da virada).

#### 4.3 Regras de saldo e o que confirmar antes (item B)

- **Reserva:** a reserva da Connect já está em `estoque_itens.quantidade_reservada`. Gerar `q_reserva` por cliente **sem somar de novo** em `quantidade_reservada` só reparte a herança
  entre os clientes (herança = reservado − Reserva − Entrega Futura − Separação dos L, SPEC-232). É o efeito desejado.
- **Entrega Futura (corrigido em 04/11 depois do `--incluir-estoque`):** a aprovação normal soma a quantidade **inteira** (Reserva + Entrega Futura) em `quantidade_reservada`.
  Com a reserva da Connect já atualizada para 04/11, o reservado da Connect **também inclui a Entrega Futura**: nas 257 peças com Entrega Futura, `reservado = Reserva + EF` em **183**
  e `reservado = Reserva` em **0**; nas 341 peças sem EF, `reservado = Reserva` em 298. Logo **a Entrega Futura da Connect conta no reservado, igual à do sistema (regra A)** e a fórmula
  da herança (reservado − Reserva − EF − Separação) **não precisa mudar**. A "Entrega futura herança Connect" é um setor próprio, como a reunião pediu, mas dentro da mesma conta.
- **Ensaio da regra (04/11):** a primeira simulação usou o reservado de 14/10 e indicou 98 peças negativas (regra A) contra 29 (regra B). Estava **enganada pela base velha**.
  Depois de aplicar `--incluir-estoque` (reserva de 04/11), a mesma simulação com 598 peças dá: **regra A: 4 peças negativas, déficit −22,0**; regra B: 3 peças, déficit −12,0.
  A diferença entre A e B é pequena, e A é a que bate com os dados (183 de 257) e com o sistema. **Regra adotada: A.** As 4 peças negativas entram na reconciliação (critério 12).
  Nada foi simulado com gravação: o ROLLBACK será necessário no ensaio da função de carga.
  Sobra de reservado sem dono (sem cliente na planilha): 7.793 unidades — é a herança que continua "Reserva sem venda (herança Connect)".
- **Caminho de carga próprio:** `orcamentos` tem 9 triggers (`trg_orcamento_workflow`, `trg_0_proteger_vinculo_connect`, `trigger_set_orcamento_numero`, equipe/digitador…) e `projeto_itens` 3
  (`trg_sync_valor_total`…). A aprovação normal (`aprovar_orcamento_financeiro`) cria parcelas e reservas; a carga **não pode passar por ela**. Função `SECURITY DEFINER` própria
  grava orçamento, itens e saldos, e um teste prova que `transacoes`, `projeto_parcelas`, `boletos`, `vendas` e `estoque_itens` ficam idênticos antes e depois.
- **Campos obrigatórios:** `orcamentos.empresa_id` e digitador/equipe: ver 4.5. Preço unitário = `Valor Venda ÷ Qtd`. Sem forma de pagamento e sem parcelas.
- **Segurança:** RLS ligada, `REVOKE ALL FROM anon`, acesso por `(SELECT public.pode_acessar_sistema('...'))`; valor de venda só em view/RPC restrita; nunca `select('*')`.

#### 4.5 Digitador, equipe e empresa (engenharia reversa)

**Digitador e equipe** (revisado em 04/11: o digitador é um **funcionário**; usuário é consequência)
- Regra do usuário: só tem usuário quem é da empresa, ou seja, funcionário. O digitador da planilha é gravado como **funcionário**: `Funcionario` → `funcionarios.nm_connect` (e, na falta, nome normalizado)
  → `orcamentos.vendedor_id` (FK para `funcionarios`). O usuário (`orcamentos.digitado_por`, FK para `usuarios`) vem de `funcionarios.usuario_id` **quando existir**; senão fica nulo.
- **Equipe = regra do usuário** gravada em `orcamentos.equipe_id` (Marina / Thairine / Thais; qualquer outro = "Administração"), sem alterar o cadastro do funcionário.
  O cadastro atual já bate com as listas do usuário (Marina: Giovanna, Isabella, Ketlyn, Marina; Thairine: Adriana, Giovana, Rafaela, Thairine; Thais: Helena, Murillo, Thais, Trícia).
- **Vínculo usuário × funcionário já existe (conferido em 04/11):** 34 dos 39 funcionários têm `usuario_id`; os 5 sem usuário são Teresinha (Inativo) e 4 contas de teste. Só 2 usuários não têm funcionário:
  `kimberly` (admin inativo, conta da consultoria — **removida em 04/11**) e `pedrollaghi` (conta pessoal do desenvolvedor — **mantida como usuário e sem registro em `funcionarios`**, para não duplicar no RH; o funcionário "Pedro Leonel Laghi" usa `pedro@lucenera.com.br`). Nenhum dos dois é digitador da planilha.
  `funcionarios.usuario_id` aceita um usuário por funcionário; as contas extras (ex.: `marianelighting`) são funcionários próprios criados pelo `handle_new_user`.
- **O que faltava era o `nm_connect`:** só 16 funcionários o têm. Dos 22 nomes da planilha, 6 não tinham e casam por nome com um único funcionário: FILIPPO, HELENA FOGAÇA, MATHEUS, RAFAELA NETTO, VITORIA LIDIA e TEREZINHA
  (= "Teresinha do Amaral Figueiredo", Inativo, sem usuário). Preenchido pela **migration 265** (`20261104_265_spec243_funcionarios_nm_connect`), **APLICADA em 04/11 com autorização do usuário**: 16 → 22 funcionários com `nm_connect`.
- **KATIA e RICARDO não têm cadastro em `funcionarios`:** a linha entra com `vendedor_id` nulo, o nome preservado no espelho (`vendedor_nome`) e o aviso `digitador_nao_encontrado`; a equipe vira Administração.
  Alternativa (pergunta 10): criar os dois como funcionários **Inativos**, para o vínculo existir.
- O trigger `orcamento_definir_equipe_digitador` só sobrescreve o digitador quando há usuário logado, então a carga grava `vendedor_id`, `digitado_por` e `equipe_id` sem conflito.
- O relatório do dry-run lista cada nome da planilha, o funcionário encontrado, o usuário e a equipe resultante.

**Empresa (hierarquia de fontes, da mais para a menos confiável)**
1. **`nm_empresa` do `ContaReceber_2026-11-04.xlsx` e do `ContaPagar_2026-11-04.xlsx`** (decisão do usuário: Contas a Receber e a Pagar são as fontes confiáveis), casando pelo `cod_venda`. Só o Contas a Receber foi medido: cobre **279 das 315 vendas** das duas planilhas (o Contas a Pagar será medido no dry-run). No banco,
   `transacoes.empresa_id` está **vazio** e `projetos.empresa_id` tem **994 projetos, todos "MANOELLA"** (valor padrão, não serve).
   O importador lê a planilha de Contas a Receber direto; não depende de `transacoes`.
2. **Notas Fiscais Connect (SPEC-204)**, que já vêm por empresa — só se o usuário quiser; não foi pedido.
3. Sem fonte → `empresa_id` nulo, aviso `empresa_nao_deduzida` e o orçamento **não é gerado** (a coluna é obrigatória); a linha **fica só no espelho, com aviso** (decisão do usuário).
- Mapeamento de nome (**regra fixa**): `LUCE NERA` → MANOELLA, `ISLIGHT` → ISLIGHT, `FOCO ILUMINACAO` → FOCO ILUMINACAO. Em 3 vendas do Contas a Receber
  aparecem **duas empresas**; essas vão para o aviso `empresa_ambigua` e para revisão manual.

#### 4.4 Vínculos Connect

- `orcamentos.origem_connect_cod_orcamento` (existe) → exibido em **todo** orçamento como **"Orçamento vinculado Connect"**.
- Novo campo **"Vendas vinculadas Connect"** (lista de `cod_venda` Connect) na venda/orçamento aprovado: preenchido pela carga ou manualmente; uma obra pode ter mais de uma venda Connect.
- Sugestão automática quando o projeto + cliente casam com venda Connect.

### 5. Importação (script)

- `scripts/importar_reserva_entrega_futura_connect.py`, no padrão de `sync_connect_common.py`: `--dry-run` por padrão (linhas, vínculos, motivos, duplicadas, descartadas), `--aplicar` para gravar.
- **Ordem da rodada de 04/11:** (1) Produtos; (2) Pedido de Compra; (3) Contas a Pagar/Receber; (4) **este script**. Esta SPEC não altera os importadores 1–3.
- Descarta as 3 linhas "produto especial" (e as lista). As 4 linhas repetidas da Reserva **ficam as duas**, listadas no relatório.
- Cada importação **substitui o lote do `tipo`** e **regenera** os orçamentos Connect de forma idempotente (mesmo arquivo = mesmo resultado); linha já tratada continua tratada.
- Importação **manual** na rodada (pergunta 6 da v1): é o script que eu rodo; "botão" no sistema não foi pedido.
- Backup do estado anterior no schema `backup` (nunca no `public`).

### 6. Telas

#### 6.1 Vínculo Connect em orçamento e venda
Todo orçamento mostra "Orçamento vinculado Connect"; toda venda, "Vendas vinculadas Connect". Vazio é permitido; o sistema sugere pelo projeto + cliente.

#### 6.2 Venda Parcial — duas visões
- **Abas:** "Vendas do sistema Lucenera" (como hoje) e "Vendas parciais Connect" (orçamentos Connect gerados, com histórico). Os dados de teste do sistema são zerados (seção 7).
- Layout igual ao de hoje: itens por L, Venda / Reserva / Entrega Futura / Ag. separar / Separado / Entregue, links para orçamento, projeto e cliente.
- Aviso "entregue não disponível na Connect"; reserva sem data com aviso; venda ≤ 2477 com cartão de outra cor, vendedor e equipe, e a observação do tratamento.
- Linha do espelho **sem** orçamento gerado aparece numa lista "Sem vínculo" com o motivo.
- Valor só Administração.
- Ajuste Reserva ↔ Entrega Futura (SPEC-235 B) e troca de reserva continuam valendo; sobre a herança só na fase 2.

#### 6.3 Fase 2 — "matar" a herança (só Matheus e administração)
1. **Já entregue, só não tirou a lista** → dar como entregue **sem mexer no estoque** (check "não mexe"), com observação.
2. **Não vai mais ser entregue (obra acabou)** → dar como entregue e **voltar a peça ao estoque disponível** (check "mexe"): sai da herança e o estoque geral acompanha (invariante SPEC-232). Sem crédito, sem financeiro.
3. **Entrega Futura que não vem mais** → baixar com observação; se a peça chegar, a entrada de NF mostra as duas entregas futuras.
4. **Venda real que deve ficar** → marcar "mantida/confirmada".
- Tudo grava `connect_reserva_tratamento`. Nada mexe sozinho.
- Fora desta SPEC: estornar entrega finalizada, botão "separar tudo", ajuste do estoque geral com motivo, observações da venda (ver Pendências).

#### 6.4 Cadastro e Compras
- Cadastro (consulta de produtos): setores **"Reserva herança Connect"** e **"Entrega futura herança Connect"** por cliente (hoje a herança é um número sem dono).
- Compras (entrada de NF): a entrega futura do sistema e a da herança Connect do mesmo cliente/peça aparecem juntas para o vínculo.

### 7. Limpeza dos dados de teste (pré-requisito)

- **Conteúdo dos 4 orçamentos (conferido em 04/11, só leitura):**

  | Orçamento | Projeto | Itens / `projeto_itens` | Parcelas | Separações | Reserva / Entrega Futura / Entregue |
  |---|---|---|---|---|---|
  | ORC-0001 (Connect 8222, valor 96.000) | 26.209 CRISTIANE TORRENTE | 95 / 95 | 1 | 0 | 101 / 273,5 / 0 |
  | ORC-0002 (valor 601,30) | 26.333 Vinicius Teste | 2 / 2 | 1 | 1 | 2 / 0 / 9 entregue |
  | ORC-0003 (valor 7.438,97) | V-1670 RODRIGO SACARELLI | 3 / 3 | 1 | 2 | 1 / 1 / 0 |
  | ORC-0004 (valor 386,55) | 26.333 Vinicius Teste | 3 / **0** | 1 | 0 | 0 / 0 / 0 |

  Todos "Aprovado". O ORC-0001 é a venda de teste que usa a Cristiane Torrente (a mesma da reunião, venda 5882). Ao apagar: parcelas e saldos somem e o `quantidade_reservada` é devolvido; o ORC-0004 tem itens sem `projeto_itens` (aprovação incompleta).
- Os 4 orçamentos atuais (`ORC-0001`…`ORC-0004`; só 1 tem `origem_connect_cod_orcamento`), incluindo o teste da venda Connect **5882**. **Antes de apagar:** listar o que cada um tem
  (itens, projeto, separações, reservas, parcelas, boletos — como no apagar do ORC-0001 de 15/10) e **pedir confirmação por orçamento**. Backup no schema `backup`.
- Apagar orçamento aprovado desfaz reserva/saldo/parcelas ligados: passo próprio, com ROLLBACK ensaiado, **antes** da carga e fora da migration do espelho.

### 8. Critérios de aceite

1. Dry-run lê 1.009 + 2.820 linhas, importa 1.006 + 2.820 e lista as 3 descartadas, sem erro de data ou valor com vírgula de milhar.
2. Depois de aplicar: linhas por `tipo` = planilha (menos descartadas); soma de `quantidade` = 5.555 − descartadas e 17.215,7.
3. Reimportar o mesmo arquivo não duplica orçamento, item nem saldo.
4. **`transacoes`, `projeto_parcelas`, `boletos`, `vendas` e `estoque_itens` com contagem e soma idênticas antes e depois da carga** (Contas a Pagar/Receber intactas).
5. `quantidade_reservada` total não muda; a herança de cada peça diminui exatamente pela Reserva atribuída a clientes.
6. Herança **nunca negativa** (resolvida a regra da Entrega Futura, 4.3).
7. Venda 5799 ("25.411 Manuella e Matheus", orçamento 7994) mostra na aba Connect os itens de Entrega Futura (L17) com as quantidades da planilha.
8. Venda presente nas duas planilhas mostra Reserva e Entrega Futura no mesmo L, somadas e separadas.
9. Usuário da equipe de projetos **não** recebe valor de venda; admin recebe (testar como `authenticated`, `anon` e usuário sem o sistema, em ROLLBACK).
10. Toda linha sem vínculo mostra o motivo; reserva sem data mostra o aviso.
11. Depois da rodada de 04/11 na ordem certa: vendas casadas ≥ 135 (EF) e ≥ 238 (Reserva); peças sem cadastro = 0.
12. **Reconciliação com Produtos:** por peça, Reserva da planilha comparada à herança do banco após importar `Produtos__2026-11-04`; as que não batem são listadas e explicadas.
    (Hoje: planilha 17.215,7 × banco 26.813,4, mas o banco está na base de 14/10 — inconclusivo.)
13. Reimportar depois de "matar" uma linha: continua tratada e o estoque não muda.
14. Venda ≤ 2477 aparece com a cor de antiga, com vendedor e equipe.
15. Compras mostra as duas entregas futuras (sistema e herança).
16. Orçamento Connect não aparece na lista normal do Orçamentos; aparece na aba Connect.

### 9. Plano de rollback

- Migration com rollback (DROP das views/funções/tabelas novas, remoção das colunas de origem/vínculo).
- Orçamentos Connect gerados têm `origem = 'connect'` e `lote_importacao`: um comando os remove por lote (itens, saldos, espelho), sem tocar nos do sistema.
- Antes de qualquer carga: backup em `backup` e ensaio com ROLLBACK.

### 10. Documentos a atualizar

`CHANGELOG.md`, `supabase/db/current` (snapshot), `AI_DB_CONTEXT.md` de separacao-parcial, gestao-financeira-clone, Cadastro e Compras, `Pendencias.md`, memória do projeto.

### 11. Ordem de implementação

A2 (limpeza, com confirmação) → B (regras de saldo, só relatório) → C (migration) → D (script, dry-run) → aprovação → E (rodada de 04/11 + reconciliação) → F (vínculos) → G (Venda Parcial, duas visões) → H (Cadastro) → I (Compras) → J (antigas + fase 2) → K (conferência e documentação).
Prazo da reunião: planilha de teste imediata; data de virada a combinar (Connect em paralelo, depois só consulta/fiscal).

## Perguntas ainda em aberto

1. **Cliente novo (23 códigos):** cadastrar em `contatos` com nome e código da planilha, ou esperar um import de clientes? (Proposta: esperar; fica no espelho com aviso, sem orçamento.)
2. **Fase 2 junto ou depois?** (Proposta: primeiro importação + orçamentos Connect + vínculos; as ações que mexem em estoque depois, com teste separado.)
3. **"Planejado no escritório"** apareceu em duas das listas de equipe como linha avulsa. É uma pessoa/rótulo a tratar, ou só ruído da cópia? (Proposta: ignorar.)
4. **Corte de vendas antigas:** venda ≤ 2477 (junho/2025) como o Vinicius disse, ou outro? Será configurável.
5. ~~Regra da Entrega Futura~~ — **resolvida: regra A** (a EF Connect conta no reservado; ver 4.3).
6. ~~Peças novas~~ — **resolvida:** aplicado em 04/11.
7. ~~Reserva atual da Connect~~ — **resolvida:** `--incluir-estoque` aplicado em 04/11 depois da limpeza.
8. ~~Apagar os 4 orçamentos~~ — **resolvida:** apagados em 04/11, com backup em `backup.`.
10. **Katia e Ricardo:** criar os dois como funcionários Inativos (preciso dos nomes completos) ou deixar sem vínculo, só com o nome no espelho? (Proposta: deixar sem vínculo.)
9. **Peças divergentes:** as 4 peças que ficam com herança negativa e as 42 sem EF cujo reservado é maior que a Reserva da planilha: tratar na reconciliação (lista no dry-run) ou ignorar?

## Realizado

### 2026-11-04 (269, reimportação e 270 aplicadas; Cadastro publicado)

- **269 aplicada** e **importador `--aplicar` rodado** (lote anterior removido, 2.645 itens e 191 orçamentos recriados no lote `76b26f00-5d75-4500-9861-a79cb930a857`; espelho antigo em backup): 191 de 191 orçamentos com valor, soma R$ 12.136.545,94 (CNX-1264 = 80.000, CNX-1405 = 320.000, CNX-1351 = 5.800, CNX-1505 = 4.680, CNX-1641 = 8.868,53, CNX-1812 = 85.950). Conferido: itens com preço 0, estoque 31.966,70/25.453,70, transações 23.243, parcelas 387, boletos 12, vendas 263 e 28 projetos com valor — todos iguais a antes.
- **270 aplicada:** Reserva e Entrega Futura do sistema = 0; Connect = 13.333,5 (Reserva) e 3.692,2 (Entrega Futura) nas colunas próprias; 5 views dependentes seguem funcionando.
- **Cadastro publicado por push:** `cadastro-lucenera` 9e5393f (só os 3 arquivos da SPEC-243; `public/_headers` solto ficou de fora).

### 2026-11-04 (Cadastro: setores da Connect — migration 270 em rascunho)

- Pedido do usuário (decisão da reunião): em **Consultar produtos** a herança da Connect aparece em setores próprios, só visualização: **"Reserva herança Connect"** e **"Entrega futura herança Connect"**.
- **Achado:** depois da carga, `vw_cadastro_produto_setores` somava as vendas Connect dentro da Reserva/Entrega Futura do sistema (13.333,5 e 3.692,2). A quantidade da **Necessidade de Compra** não é afetada (vem de `estoque_itens`); só o contador "projetos com entrega futura" passa a contar projetos Connect.
- **Migration 270 (RASCUNHO, NÃO aplicada):** coluna `origem` no fim de `vw_estoque_saldos_projeto_item` (view de dono: a origem sai igual para todos, sem o RLS por equipe), `vw_estoque_por_produto_projeto` e `vw_cadastro_produto_movimentos`; `vw_cadastro_produto_setores` passa a somar Reserva/Separação/Entrega Futura **só do sistema** (como antes da carga) e ganha `q_reserva_connect` e `q_entrega_futura_connect`.
  Dry-run: 0 peças divergentes da soma direta dos saldos; Marina (equipe restrita) e Matheus (Estoque) veem os mesmos totais da Connect (13.333,5 / 3.692,2); 8 views dependentes seguem funcionando (necessidade de compra 258 linhas, entrega futura 652, venda parcial 191...); depois do ROLLBACK a coluna nova não existe.
- **Código (`cadastro-lucenera`, não commitado):** `getSetoresProduto` lê as 2 colunas novas; `SETORES_OBRIGATORIOS` ganha os 2 setores; a sobra "Reserva sem venda (herança Connect)" desconta o que já tem cliente; abas "Reserva Connect" e "Entrega Futura Connect" com o aviso "somente visualização"; as abas do sistema passam a mostrar só vendas do sistema. `tsc` sem erro e `vite build` ok.
- **Ordem obrigatória:** aplicar a 270 ANTES de publicar o Cadastro (sem as colunas novas a consulta da peça quebra).

### 2026-11-04 (valor do orçamento Connect — migration 269 em rascunho)

- O usuário viu os orçamentos Connect com **R$ 0,00** e corrigiu a regra: o valor do orçamento **pode aparecer** (visualização); o que não pode aparecer no CRM é **quanto foi pago**. Isso substitui a decisão "valor só para Administração" para o valor do orçamento (o valor da planilha por item continua só no espelho/administração).
- A planilha Reserva/Entrega Futura **não serve** como total da venda (traz só as peças em aberto: venda 1264 = R$ 155 na planilha contra R$ 80.000 no Contas a Receber; só a 1268 bate). Fonte adotada: **parcelas vigentes de receita do Contas a Receber** já importado (`status_pago <> 2`), primeiro pelas transações marcadas com o número da venda e, se não houver, pela negociação da venda (as vendas 1505 e 1641 só aparecem por esse caminho). **`vl_pago` não é usado.**
- **Migration 269 (RASCUNHO, não aplicada):** `_valor_venda_connect(integer[])` + `carregar_connect_reserva_ambiente` passa a gravar `valor_total`. Dry-run (remove e recarrega o lote dentro da transação, depois ROLLBACK): 191 de 191 orçamentos com valor, soma R$ 12.136.545,94; 1264 = 80.000, 1351 = 5.800 (renegociada: só a duplicata consolidada), 1405 = 320.000, 1505 = 4.680, 1641 = 8.868,53, 1812 = 85.950; preço dos itens segue 0 e os 28 `projetos.valor_total` ficam iguais.
- Para os 191 já gravados é preciso **reimportar** (`--aplicar`) depois de aplicar a 269. Só o sistema Orçamentos lê `orcamentos.valor_total` (mais 2 views de aprovação); dashboards não duplicam.
- Limite conhecido: venda renegociada mostra a duplicata consolidada, não o valor original; venda sem parcela no Contas a Receber fica com 0.

### 2026-11-04 (Venda Parcial no ar; 268 aplicada)

- **268 aplicada** (autorizada). **Venda Parcial publicada** (autorizado): commit `2fba684` em `separacao-parcial/main`, só os 2 arquivos da SPEC-243 (o `public/_headers` solto, da SPEC-242, ficou fora); a Cloudflare compilou e o bundle da tela no ar (`SeparacaoParcialPage-C_KZjCdv.js`) contém `vw_venda_parcial_lista`, "Vendas parciais Connect", "somente consulta" e o aviso "Sem data de entrega".
- Teste visual pelo usuário pendente: aba "Vendas parciais Connect", venda 5799, uma venda antiga (amarela) e conferir que Separar/Trocar/Ajustar não aparecem.

### 2026-11-04 (Venda Parcial: duas abas — código pronto, 268 pendente)

- **Migration 268 (rascunho, NÃO aplicada — a aplicação foi bloqueada por não estar autorizada):** `vw_venda_parcial_lista`, uma linha por venda com `origem`, equipe, vendedor, vendas vinculadas, `venda_antiga` e totais de Reserva/Entrega Futura, sem valor em dinheiro, `security_invoker`.
  Dry-run: 191 vendas Connect (2.645 itens), 32 vendas antigas; Marina (equipe própria) enxerga 59 e Matheus (Estoque) 191; `anon` sem acesso. Motivo da view: a tela lia `vw_estoque_saldos_projeto_item` inteira (uma linha por item) e agrupava no navegador; com 2.645 itens Connect passaria de 1.000 linhas e misturaria as origens.
- **Código (`04-Sistemas/separacao-parcial`, não commitado):** `listarVendasDisponiveis(origem)` lê a nova view (paginando em blocos de 1.000); `VendaInfo` ganha `origem`, `vendasVinculadasConnect`, `vendaAntiga`; cada item Connect traz data de entrega, aviso "sem data", observação e "tratada" do espelho.
  Tela: abas "Vendas do sistema Lucenera (n)" e "Vendas parciais Connect (n)"; na aba Connect mostra equipe, vendedor, Reserva e Entrega Futura, e linha amarela com selo "Até jun/2025" para venda antiga; ao abrir uma venda Connect aparece o selo "Connect — somente consulta", o aviso de que o entregue não existe na Connect, e somem Separar, À Separar, Trocar e Ajustar.
  `tsc --noEmit` sem erros e `vite build` ok. **Não publicado** (o deploy é por wrangler e depende da 268 no banco).
- Observação (já existia): `vw_estoque_saldos_projeto_item` não filtra por equipe; quem digitar um número `CNX-…` de outra equipe vê os itens (o cabeçalho respeita o RLS por equipe). Vale para venda do sistema também; ver SPEC-200.

### 2026-11-04 (importação aplicada: 191 orçamentos Connect no banco)

- `python scripts/importar_reserva_entrega_futura_connect.py --aplicar` (autorizado). Lote `01fe0c7b-1d6b-4675-a388-3d537bb86097`. Excel: `scripts/logs/reserva_connect/reserva_connect_20261104_195311.xlsx`.
- **Gravado:** espelho com 3.826 linhas (Reserva 2.820 = 17.215,7; Entrega Futura 1.006 = 5.552), **191 orçamentos Connect** (`origem = 'connect'`, `valor_total` 0), 2.645 itens, saldos de 13.333,5 em Reserva e 3.692,2 em Entrega Futura; **2.692 linhas vinculadas, 1.134 só no espelho** com o motivo.
  Por empresa: ISLIGHT 88, MANOELLA 55, FOCO ILUMINACAO 48. Por equipe: Thais 64, Marina 59, Thairine 54, Administração 14. 71 vendas antigas (≤ 2477).
- **Conferido depois (nada fora do escopo mudou):** `estoque_itens` 31.966,70 / reservado 25.453,70 (iguais a antes); transações 23.243, parcelas 387, boletos 12 e vendas 263 (iguais); contatos tipo cliente 2.642 (igual); 28 projetos com `valor_total` (igual); orçamentos do sistema 0 (só os 191 Connect).
- A Venda Parcial já os lê pela `vw_estoque_saldos_projeto_item` (ex.: venda `CNX-5799`, várias peças por L). 1 peça com herança negativa (13653, reservado −1 vindo da Connect).

### 2026-11-04 (migration 267 aplicada)

- **267 aplicada** (`20261104_267_spec243_view_sem_vinculo`): `vw_connect_reserva_ambiente.sem_vinculo` passou de "tem motivo" para "não virou orçamento" (`orcamento_id IS NULL`). Linha com orçamento e motivo só informativo (`digitador_nao_encontrado`, `projeto_por_codigo_legado`) não aparece mais como sem vínculo. Dry-run com 3 casos ok; `anon` sem acesso.

### 2026-11-04 (migration 266 aplicada; script de importação e dry-run real)

- **266 aplicada** (autorizada): `carregar_connect_reserva_ambiente` e `remover_connect_lote` criadas; `authenticated` e `anon` não executam, só `service_role`.
- **Script `scripts/importar_reserva_entrega_futura_connect.py`:** lê as duas planilhas e o Contas a Receber/Pagar (empresa; LUCE NERA = MANOELLA), resolve peça, cliente, projeto (`NN.NNN` no nome; senão pelo número no início = `projetos.codigo_legado`), digitador e equipe,
  grava o espelho com todas as linhas e motivo, chama a carga e gera `scripts/logs/reserva_connect/*.xlsx` (abas: com_motivo, heranca_negativa, descartadas, digitadores, sugestao_projeto). O dry-run roda a carga inteira dentro de uma transação e desfaz.
- **Resultado do dry-run real (04/11, nada gravado; conferido 0 orçamentos/espelho/itens/saldos depois):**
  - lidas 2.820 (Reserva) + 1.009 (Entrega Futura); descartadas as 3 de "produto especial" (orçamentos 79, 115, 4252);
  - **191 orçamentos Connect, 2.645 itens, 2.692 de 3.826 linhas vinculadas (70%)**; 0 orçamentos com vínculos conflitantes; 0 erros;
  - **1.134 linhas ficam só no espelho:** 679 por `cliente_nao_cadastrado` (os 23 clientes novos), 429 por `nome_sem_codigo_projeto`, ~56 por empresa/venda sem título no Contas a Receber/Pagar (algumas somam mais de um motivo);
  - 11 linhas ganharam projeto por `codigo_legado` (`projeto_por_codigo_legado`, informativo); 18 orçamentos sem código têm cliente com **um único projeto** e estão listados na aba `sugestao_projeto` (NÃO aplicados);
  - digitadores: 19 achados (Marina, Thairine e Thais com a própria equipe; Débora, Filippo, Mariane, Moara, Matheus e Vitória em Administração), Teresinha achada sem usuário, **Katia e Ricardo não encontrados** (→ Administração, aviso `digitador_nao_encontrado`);
  - **herança negativa depois da carga: 1 peça** (13653, reservado −1 já vindo da Connect, não causada pela carga). Soma de Reserva 17.215,7 e Entrega Futura 5.552 (5.555 − 3 descartadas).

### 2026-11-04 (migration 264 aplicada; migration 266 ensaiada)

- **264 aplicada** com autorização do usuário.
- **266 (rascunho) — `carregar_connect_reserva_ambiente(lote)` e `remover_connect_lote(lote)`**, só `service_role`/administração (authenticated comum é barrado). A carga:
  - lê as linhas do espelho já resolvidas pelo script (empresa, projeto, cliente, peça, funcionário, equipe) e gera **um orçamento por `cod_orcamento_connect`** (`numero = CNX-<orçamento>`, `numero_venda = CNX-<venda>`, status "Orçamento Aprovado", `origem = 'connect'`,
    `vendas_vinculadas_connect`, `vinculo_connect = false`), **um `projeto_item` por peça + L** (quantidade = Reserva + Entrega Futura) e os saldos `q_reserva`/`q_entrega_futura`;
  - **preço 0 e `valor_total` 0**: o valor da Connect fica só no espelho (administração); nada entra em `projetos.valor_total`;
  - linha sem empresa, projeto, cliente ou peça **fica só no espelho**; orçamento cujas linhas discordam de projeto/cliente/empresa **não é gerado** (`orcamento_com_vinculos_conflitantes`);
  - linha "matada" (entregue/cancelada no tratamento) **não volta**;
  - desliga **só dentro da transação** `trg_sync_valor_total` (zeraria o `valor_total` dos 28 projetos que já têm valor) e `trg_sync_contact_type_on_budget` (trocaria o tipo de contatos), e confere no fim que **estoque_itens (quantidade e reservado), transações, parcelas, boletos e vendas** ficaram iguais, senão se desfaz com erro;
  - `remover_connect_lote` recusa se alguém já separou/entregou/devolveu algo no lote (reimportar depois disso é a fase 2).
- **Ensaio com ROLLBACK (dados reais, venda 5799):** 2 orçamentos criados, 3 itens, 4 de 5 linhas vinculadas (a do cliente não cadastrado ficou só no espelho, como esperado). Itens da 5799: 5285 no L17 = 6 (Entrega Futura 6) e 5980 no L17 = 3 (Entrega Futura 2 + Reserva 1), batendo com a planilha.
  A Venda Parcial já os enxerga pela `vw_estoque_saldos_projeto_item` como `CNX-5799`. Estoque, reservado, transações e parcelas iguais; `projetos.valor_total` preservado (20.000); tipo do contato arquiteto preservado;
  segunda carga idempotente; remoção do lote volta a 0 orçamentos. Depois do ROLLBACK não ficou função nem linha no banco.

### 2026-11-04 (funcionários e usuários, autorizado pelo usuário)

- **Migration 265 aplicada:** `nm_connect` preenchido para FILIPPO, HELENA FOGAÇA, MATHEUS, RAFAELA NETTO, VITORIA LIDIA e TEREZINHA (16 → 22 funcionários com `nm_connect`).
- **Limpeza de contas:** removidos a usuária `kimberly` (`usuarios`, `auth.users`, 1 papel, 1 acesso a sistema) e os 4 funcionários de teste (`teste.garantia`, `pedrollaghi+spec159test`, `teste-pdf`, `teste.storage`; nenhum tinha referência).
  Backup em `backup._bkp_limpeza_contas_20261104_*` (funcionários, usuário, papel, acesso e um extrato mínimo de `auth.users`, sem senha). Agora: 35 funcionários (1 sem usuário: Teresinha, Inativo), 35 usuários.
- A conta `pedrollaghi@gmail.com` (viewer) foi mantida e **não** é funcionário.

### 2026-11-04 (migration 264 em rascunho)

- Escrita `supabase/db/migrations/20261104_264_spec243_heranca_connect_base/` (`up.sql`, `rollback.sql`, `dry_run.sql`). **Não aplicada.** O dry-run (ROLLBACK, sem a palavra de gravação no arquivo) passou:
  anon barrado; usuário sem o sistema vê 0 linhas; `valor_venda` barrado por coluna e a view de valor devolve 0 linhas para não-admin; só Matheus/admin tratam (usuário aleatório = `false`, corrigido para
  nunca devolver `NULL`); orçamentos existentes ficam com `origem = 'sistema'`; depois do ROLLBACK nada ficou no banco.
- Achados que ajustam o desenho:
  - `orcamentos.digitado_por` aponta para **`usuarios.id`**, não para `funcionarios.id`. O digitador da planilha vira `funcionarios.usuario_id`; funcionário sem usuário fica com `digitado_por` nulo e só a **equipe** é gravada (por `equipe_id`).
  - O gatilho `orcamento_definir_equipe_digitador` só sobrescreve o digitador quando há usuário logado (`auth.uid()`); a carga (sem usuário) grava digitador e equipe sem conflito.
  - `vinculo_connect` (SPEC-195) já protege orçamento aprovado contra edição. O orçamento Connect gerado fica com `vinculo_connect = false` e `origem = 'connect'`, para a trava não bloquear a carga nem as ações de tratamento.
  - Leitura liberada para Venda Parcial, Cadastro, Orçamentos, Necessidade de Compra e Logística (ver `cra_leitura`); gravação só por função.

### 2026-11-04 (rodada de importação, autorizada pelo usuário)

- Dry-run e aplicação, nesta ordem: **Produtos** (78 atualizados, sem `--incluir-estoque`), **Pedido de Compra** (42 novos, 1 atualizado, 36 marcados como não vigentes, 0 erros) e **Contas a Pagar/Receber**
  (322 negociações novas, 594 transações novas, 580 atualizadas, 209 parcelas órfãs canceladas, 9 abertas canceladas, 0 sem negociação). Conferido no banco: `transacoes` 22.649 → 23.243 (+594), 55 pedidos vigentes, 78 produtos atualizados hoje.
- **Peças novas** (`importar_produtos_novos.py`, autorizado): 24 peças criadas e a marca NORDECOR (0 erros).
- **Limpeza** (autorizada): ORC-0001 a ORC-0004 apagados com `scripts/apagar_orcamento.py` (460 + 36 + 28 + 10 linhas; reserva devolvida em 44 `estoque_itens`; 424 separações antigas mantidas). O script foi ajustado
  para apagar também `nota_fiscal_compra_vinculos` e `movimentacoes_peca` (FKs novas que o travavam). Backup no schema `backup` (`_bkp_del_orc000X_20261104_*`). Banco com 0 orçamentos.
- **Reserva da Connect de 04/11** (`importar_produtos_estoque.py --incluir-estoque`, autorizado, depois da limpeza): 398 produtos atualizados. Reservado total do Estoque: 25.453,7.
- **Correção da regra da Entrega Futura:** o reservado atualizado mostra que a Connect já inclui a EF (183 de 257 peças): regra A, não B (seção 4.3).

### 2026-11-04

- Planilhas lidas e perfiladas; chaves testadas no banco real (só leitura): peça, cliente, projeto, venda; verificado que L, parcial e venda Connect não existem como elo no banco.
- Causas das linhas sem vínculo investigadas (seção 2.1).
- Reunião de 04/11 (Vinicius e Matheus) incorporada.
- Digitador e empresa investigados (4.5): 19/22 digitadores achados; empresa deduzida do Contas a Receber de 04/11 para 279/315 vendas.
- SPEC reescrita (v2): vendas Connect viram orçamentos do sistema, em duas camadas (espelho + orçamento gerado). Nada implementado, nenhuma migration criada ou aplicada.

## Pendências

- [ ] Responder as 7 perguntas da seção "Perguntas ainda em aberto".
- [ ] Decidir as 18 sugestões de projeto (cliente com um único projeto) da aba `sugestao_projeto`.
- [ ] Telas: Venda Parcial (duas abas), Cadastro (setores), Orçamentos (campos de vínculo; esconder `origem = 'connect'` da lista normal) e Compras.
- [ ] Medir no dry-run a cobertura de empresa com Contas a Receber + Contas a Pagar e decidir as 3 vendas com duas empresas (revisão manual).
- [ ] Cadastro: o funcionário "beatriz" (Beatriz Vicentini) está sem equipe; a lista do usuário a põe na equipe Marina.
- [ ] Decidir o tratamento dos 23 clientes novos da Connect que não existem em `contatos.codigo_legado`.
- [ ] SPEC própria: estornar entrega finalizada (peça entregue volta a reserva, com log e sem cancelar o histórico), só Matheus e administração.
- [ ] SPEC própria: ajuste do estoque geral pelo cadastro da peça com motivo e log (só Vinicius e Matheus; Matheus com acesso total em produtos, sem cadastrar peça).
- [ ] SPEC própria: botão "separar tudo" (sem deixar peça transferida para trás) e "devolver ao estoque sem gerar crédito" (standby, pouco frequente).
- [ ] SPEC própria: observações da venda (pasta da venda com histórico "entregou L1 para teste / voltou").
