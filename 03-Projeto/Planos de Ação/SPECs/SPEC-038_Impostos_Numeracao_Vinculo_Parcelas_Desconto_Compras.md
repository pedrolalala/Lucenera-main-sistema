---
titulo: "SPEC-038 — Impostos separados, numeração automática, vínculo de origem, parcelas de fornecedor e desconto em Cotações (compras-lucenera)"
status: implementado (migrations em rascunho, aplicação real pendente)
data_ultima_modificacao: 2026-07-21
sistemas_envolvidos:
  - Supabase (banco central)
  - compras-lucenera-3o23t98ee (Necessidade de Compra + Cotações)
referencias:
  - SPEC-020 (produto_fornecedores, solicitacoes_compra, cotacoes_compra, pedidos_compra)
  - SPEC-021 (RPC criar_pedido_compra_de_necessidade)
  - SPEC-022 (vw_necessidade_compra_detalhe — vínculo informativo projeto/orçamento)
  - SPEC-030/033/034 (marca → fornecedor, Pedido em Lote, busca fuzzy)
  - supabase/db/domains/estoque_compras.md (decisão da reunião 08: compra não amarrada a cliente)
---

# SPEC-038 — Impostos, Numeração Automática, Vínculo de Origem, Parcelas de Fornecedor e Desconto em Cotações

> Esta SPEC cobre 5 pedidos pontuais de melhoria nas telas **Necessidade de
> Compra** e **Cotações** do sistema `compras-lucenera-3o23t98ee`. As 5
> decisões de negócio pendentes (P-01, P-04, P-05) foram confirmadas pelo
> usuário em 2026-07-21 e a implementação de ponta a ponta (migrations
> redigidas + frontend) foi concluída na mesma data — ver "Realizado".
> **Nenhuma migration foi aplicada no Supabase real** (regra fixa do agente
> implementador) — isso continua sendo um passo manual do usuário.

## Checklist de Ação

### Backend

- [x] ~~Decisão do usuário necessária antes de escrever a migration final do Item 1~~ — **resolvida 2026-07-21, ver P-01**
- [x] Criar migration `supabase/db/migrations/20260721_054_spec038_compras_melhorias/001_pedido_compra_itens_impostos.sql` (Item 1 — ICMS+IPI+ST, híbrido). **Nota: pasta renomeada de `20260721_052_...` (nome original desta SPEC) para `20260721_054_...`** porque os números `052`/`053` já foram consumidos por SPEC-036/`ubiqua_necessidade_importacao` entre a redação e a implementação desta SPEC — próximo número sequencial livre confirmado em `supabase/db/migrations/` no momento da implementação.
- [x] Criar migration `.../002_pedidos_compra_numero_automatico.sql` (Item 2 — trigger de numeração + `UNIQUE` em `pedidos_compra.numero` + `p_numero` opcional nas 2 RPCs existentes). Também estende as mesmas 2 RPCs com parâmetros novos (opcionais, no final da assinatura) para gravar o breakdown de imposto do Item 1.
- [x] Criar migration `.../003_pedido_compra_item_origem.sql` (Item 3 — tabela de vínculo informativo, não obrigatório) + view `vw_pedido_compra_item_origem`
- [x] ~~Decisão do usuário necessária antes de escrever a migration final do Item 4~~ — **resolvida 2026-07-21, ver P-04 (tabela real + parcela editável)**
- [x] Criar migration `.../004_pedido_compra_parcelas.sql` (Item 4 — tabela real + `gerar_parcelas_pedido_compra` + `atualizar_parcela_pedido_compra` para edição manual do valor/data de cada parcela). Corrigido bug de formatação no `RAISE WARNING` do rascunho original (`%%` duplo escapava o placeholder e quebraria a substituição dos 2 argumentos — trocado para `%` simples).
- [x] Criar migration `.../005_cotacoes_desconto_produto.sql` (Item 5 — nova coluna + RPC, sem tocar em `produtos.porc_desconto`)
- [ ] Aplicar as 5 migrations no Supabase real (passo manual do usuário/implementador — **não aplicado nesta sessão**, ver regra do agente implementador)
- [ ] Reextrair `supabase/db/current/` depois de aplicar (pendência já crônica desde a SPEC-030 — este é mais um motivo para finalmente fazer)

### Frontend (`compras-lucenera-3o23t98ee`)

- [x] `ModalRegistrarCompra.tsx` e `ModalPedidoLote.tsx`: separar "Custo unitário" em custo líquido + ICMS + IPI + ST, pré-preenchidos via `getProdutoImpostos`/`getProdutoImpostosBulk` (produto + override de `produto_fornecedores` quando existir) e editáveis
- [x] `ModalRegistrarCompra.tsx` e `ModalPedidoLote.tsx`: campo "Nº do pedido / referência" não é mais obrigatório — vira opcional/informativo ("gerado automaticamente se deixado em branco")
- [x] `ModalRegistrarCompra.tsx`: ao abrir o modal para um produto, busca os candidatos de origem (`getNecessidadeCompraDetalhe`, mesma fonte de `NecessidadeCompraDetalhe.tsx`) e permite marcar (opcional) quais `projeto_item_id` motivaram a compra — grava em `pedido_compra_item_origem` via `vincularOrigemPedidoItem`. **Desvio de design consciente:** em vez de depender da linha já estar expandida na tabela pai (`NecessidadeCompra.tsx`), o próprio modal busca os candidatos ao abrir — evita lifting de estado entre componentes e mantém a mesma fonte de dados.
- [x] `ModalRegistrarCompra.tsx` e `ModalPedidoLote.tsx`: campo "Condições de pagamento" ganha checkbox "Gerar parcelas automaticamente" (chama `gerar_parcelas_pedido_compra` após criar o pedido; falha de geração não bloqueia o sucesso da criação do pedido, só avisa)
- [x] Nova página `PedidosCompra.tsx` (rota `/pedidos`, antes placeholder "Em breve" — a navegação já tinha o item "Pedidos" apontando para essa rota) + novo componente `PedidoParcelasPanel.tsx`: lista pedidos, expande para ver/gerar/editar parcelas (valor e data de vencimento editáveis por linha, chamando `atualizar_parcela_pedido_compra`) — decisão explícita do usuário de não travar a divisão automática igual
- [x] `Cotacoes.tsx`: nova coluna editável "% Desconto", persistindo via `atualizar_desconto_compra_produto` (não via `atualizar_preco_custo_produto`/`porc_desconto`)
- [x] `services/pedido-compra.ts`, `services/necessidade-compra.ts`, `services/cotacoes.ts`: novas funções/tipos correspondentes
- [x] Rodar `oxlint`/`oxfmt`/`vite build` após as alterações — todos passaram (ver "Realizado")
- [x] Atualizar `supabase/db/domains/estoque_compras.md` com os objetos da SPEC-020/021/030/034/036/038 (estava sem nenhum deles documentado)

### Passos manuais do usuário

- [x] ~~Decidir P-01~~ — resolvida 2026-07-21 (ver acima)
- [x] ~~Decidir P-04~~ — resolvida 2026-07-21 (ver acima)
- [x] ~~Decidir P-05~~ — resolvida 2026-07-21 (Alternativa B, coluna isolada)
- [ ] Confirmar terminologia de "código da venda" (P-03) — não bloqueou a implementação (Item 3 não usa esse termo na UI; usa "Itens de projeto que motivaram esta compra")
- [ ] **Checar duplicatas de `pedidos_compra.numero` antes de aplicar a migration 002** (`SELECT numero, count(*) FROM pedidos_compra GROUP BY numero HAVING count(*) > 1` deve retornar 0 linhas, senão o `ADD CONSTRAINT ... UNIQUE` falha)
- [ ] **Conferir a definição real de `vw_necessidade_compra` no Supabase antes de aplicar a migration 005** (`SELECT pg_get_viewdef('public.vw_necessidade_compra')`) — este agente não tem acesso ao banco real; a migration foi escrita com base na última migration real conhecida (`20260716_049`), confirmada por grep como a mais recente a recriar essa view, mas isso não substitui a conferência direta no banco
- [ ] Aplicar as 5 migrations da pasta `20260721_054_spec038_compras_melhorias/` no Supabase real, na ordem numérica (001 → 005)
- [ ] Reextrair `supabase/db/current/` depois de aplicar
- [ ] Testar golden path no navegador (ver "Realizado")
- [ ] Rodar o agente `revisor` antes de qualquer commit

## Objetivo

Pedro pediu 5 melhorias pontuais no fluxo de Necessidade de Compra / Cotações
do sistema de Compras (`compras-lucenera-3o23t98ee`, sistema central — não
confundir com o catálogo Ubiqua isolado):

1. Separar custo e impostos no campo "Custo unitário (R$)".
2. Gerar automaticamente o "Nº do pedido / referência" (hoje manual).
3. Amarrar o "código da venda" do pedido de compra ao orçamento e projeto de origem.
4. Permitir registrar parcelas em "Condições de pagamento" (hoje texto livre).
5. Adicionar campo "% de desconto" na tela de Cotações.

Esta SPEC investiga o estado real de cada um (código + banco), confirma o que
já existe versus o que precisa ser criado, e — para os dois itens com
ambiguidade genuína de regra de negócio — apresenta alternativas em vez de
decidir sozinha.

## Decisões aprovadas

Decisões já fechadas em SPECs anteriores deste mesmo domínio, **reafirmadas,
não reabertas** por esta SPEC:

- **Necessidade de compra é agregada por produto, não por cliente/projeto**
  (reunião 08/06/2026, `supabase/db/domains/estoque_compras.md`, SPEC-020:
  *"Compra não fica vinculada a cliente específico —
  `solicitacoes_compra` referencia apenas `produto_id` + quantidade"*,
  *"Rastreabilidade de 'quem vai receber' é informativa... e não uma chave
  da compra"*). O Item 3 desta SPEC propõe um vínculo **informativo**
  (nullable, non-blocking), nunca uma chave obrigatória — isso não
  contradiz a decisão da reunião 08, apenas estende o que a SPEC-022 já fez
  para leitura (`vw_necessidade_compra_detalhe`) também para o momento de
  criação do pedido.
- `marcas.fornecedor_id`, resolução em cascata `COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)`, modelo "1 pedido = 1 fornecedor" no Pedido em Lote — SPEC-030/033/034, não alterados aqui.
- `boletos.orcamento_id` é o único link financeiro de recebível; pedidos de compra a fornecedor são **pagáveis**, não recebíveis, e não usam `boletos` (invariante do ecossistema — ver "Decisões aprovadas" globais). O Item 4 desta SPEC propõe uma tabela nova e separada, não reaproveita `boletos` nem `projeto_parcelas`.

## Achados de grounding (por item do pedido)

| # | Pedido do usuário | Onde está hoje (arquivo:linha) | Coluna/tabela real no banco | Achado |
|---|---|---|---|---|
| 1 | Separar custo e impostos | `ModalRegistrarCompra.tsx:241-253` (Label "Custo unitário (R$) *", `Input type=number`, `form.custoUnitario`); `ModalPedidoLote.tsx:156-157,203-213` (coluna "Custo unitário (R$)" por linha, `LinhaLote.custoUnitario`) | `pedido_compra_itens.custo_unitario numeric(12,4)` — coluna única, sem breakdown (`supabase/db/migrations/20260710_031_spec020_operacionalizacao_compras/004_pedidos_compra.sql:65`) | Não existe **nenhuma** coluna de imposto em `pedido_compra_itens` nem em `cotacao_itens` (`003_cotacoes_compra.sql:45-57`: só `custo_unitario`, `prazo_entrega_dias`, `ncm`). Porém `produtos` **já tem** `icms_entrada numeric(5,2)`, `ipi_entrada numeric(5,2)`, `porc_st numeric`, `porc_desconto numeric`, `porc_despesas numeric` (`01_schema_full.sql:5579-5593`), consumidos pelo trigger `fn_atualizar_preco_venda()` (`01_schema_full.sql:2270-2304`) para calcular `preco_venda` — mas isso é dado **mestre do produto** (mantido em Cadastro), não por transação de compra. Achado adicional: a tabela de staging legada `staging_conta_pagar` (import do Excel `ContaPagar` do Connect, `01_schema_full.sql:6122-6172`) tem colunas `vl_ipi`, `vl_st`, `vl_desconto`, `vl_frete` — **não tem `vl_icms`** — evidência histórica de que o ERP anterior rastreava IPI/ST/desconto/frete por linha de conta a pagar, mas não ICMS separado. |
| 2 | Gerar número do pedido automaticamente | `ModalRegistrarCompra.tsx:262-273` (Label "Nº do pedido / referência *", placeholder `"ex: PC-2026-001"`, obrigatório em `canSubmit` linha 97); `ModalPedidoLote.tsx:230-240` (mesmo campo, nível do lote) | `pedidos_compra.numero text NOT NULL` — **sem `UNIQUE`, sem `DEFAULT`, sem trigger** (`004_pedidos_compra.sql:8,26`) | Confirmado: 100% manual hoje, inclusive sem constraint de unicidade (duas pessoas podem digitar o mesmo número sem erro). Existe padrão pronto e testado para reaproveitar: `set_orcamento_numero()` (`01_schema_full.sql:3712-3728`, trigger `BEFORE INSERT ON orcamentos`, calcula `MAX+1` com prefixo `ORC-` e `LPAD` 4 dígitos) e `fn_gerar_numero_orcamento()`/`fn_auto_numero_orcamento()` (`01_schema_full.sql:2359-2392`, variante com ano: `ORC-<ano>-<seq>`, usada em `orcamentos_revenda_ubiqua`). Este segundo padrão bate exatamente com o placeholder já exibido na tela (`PC-2026-001`). |
| 3 | Amarrar "código da venda" ao orçamento/projeto | Tabelas usadas por `ModalRegistrarCompra.tsx`/`ModalPedidoLote.tsx` via `services/pedido-compra.ts`: `solicitacoes_compra`, `pedidos_compra`, `pedido_compra_itens` | `solicitacoes_compra (produto_id, quantidade, status, prioridade, ...)` — **sem `projeto_id`, sem `orcamento_id`** (`002_solicitacoes_compra.sql:7-19`); `pedido_compra_itens (pedido_id, solicitacao_id, produto_id, quantidade, custo_unitario)` — idem, sem vínculo a projeto/orçamento (`004_pedidos_compra.sql:58-68`) | Confirmado: nenhuma tabela do fluxo de compra grava vínculo a `projetos`/`orcamentos`/`projeto_itens` hoje — é deliberado (ver "Decisões aprovadas"). Existe hoje **apenas leitura** informativa: `vw_necessidade_compra_detalhe` (SPEC-022) já faz o JOIN `estoque_itens → projeto_itens → estoque_saldos_projeto_item → projetos → orcamentos → contatos`, expondo `projeto_codigo`, `orcamento_numero`, `cliente` — mas nada disso é persistido quando o pedido é de fato criado. **Termo "código da venda" não existe em nenhuma tabela/coluna viva** (busca em todo o código dos sistemas retornou zero resultados) — a única ocorrência literal do conceito é `staging_conta_pagar.cod_venda numeric`, uma tabela de staging de import único do Excel legado, sem FK para nada, não usada por nenhum código ativo. **Achado adicional de contradição:** `supabase/db/current/01_schema_full.sql:6108-6115` ainda mostra uma versão **legada** de `solicitacoes_compra` com `projeto_id uuid NOT NULL` e `quantidade_pedida` — isso contradiz a definição real e aplicada (`20260710_031/002_solicitacoes_compra.sql`, sem `projeto_id`). Reforça a pendência crônica já registrada nas SPEC-030/033/034: `supabase/db/current/` está desatualizado desde 2026-07-07 para todo o domínio de Compras. |
| 4 | Registrar parcelas em "Condições de pagamento" | `ModalRegistrarCompra.tsx:287-295` (Label "Condições de pagamento (opcional)", `Input` texto livre, `form.condicoesPagamento`); `ModalPedidoLote.tsx:252-260` (mesmo campo, nível do lote) | `pedidos_compra.condicoes_pagamento text` — texto livre, passado direto pelas RPCs (`criar_pedido_compra_de_necessidade`, `criar_pedido_compra_lote`) sem nenhum parsing (`001_rpc_criar_pedido.sql:12,58-65`; `003_rpc_criar_pedido_compra_lote.sql:26,88-97`) | Não existe `pedido_compra_parcelas` nem equivalente (confirmado via busca em todo `supabase/db/migrations` e `01_schema_full.sql`). Existe padrão maduro e pronto do lado **recebível**: `projeto_parcelas` (`01_schema_full.sql:5624-5650`) gerada por RPC que usa `_lucenera_parse_prazo_pagamento(condicoes_pagamento, prazo_pagamento_dias)` (`01_schema_full.sql:314-373`) para transformar texto/array em dias de vencimento, dividindo `valor_total` entre N parcelas (`01_schema_full.sql:920-962`). Esse é o padrão a reaproveitar — mas para o lado **pagável** (Lucenera → fornecedor), não existe hoje nenhuma tabela equivalente nem qualquer integração com Financeiro (não existem tabelas `contas_a_pagar`/`previsoes_financeiras` no banco — SPEC-EST-10/13 do escopo de Estoque/Compras seguem não implementadas). |
| 5 | "% desconto" em Cotações | `Cotacoes.tsx` inteiro (1-415) | `produtos.preco_custo` via RPC `atualizar_preco_custo_produto` (`supabase/db/migrations/20260713_036_cotacoes_preco_custo/001_add_preco_custo_a_view.sql:57-86`) | **Achado crítico:** a tela "Cotações" **não é** um comparador de cotações por fornecedor. Ela é um editor inline de `produtos.preco_custo`, montado sobre a mesma `vw_necessidade_compra` da tela de Necessidade de Compra (`services/cotacoes.ts` tem só 9 linhas, 1 única função). As tabelas reais de cotação por fornecedor (`cotacoes_compra`, `cotacao_itens`, criadas na SPEC-020, `003_cotacoes_compra.sql`) **existem no banco mas estão órfãs** — nenhuma função em `04-Sistemas/compras-lucenera-3o23t98ee/src` faz `INSERT`/`UPDATE` nelas; só têm policy de `SELECT`. `cotacao_itens` não tem coluna de desconto. `produtos.porc_desconto numeric DEFAULT 0` **já existe** e já é usado pelo trigger `fn_atualizar_preco_venda()` para calcular `preco_venda` (`01_schema_full.sql:2282`, `v_valor_liquido := preco_custo - preco_custo * porc_desconto/100`) — mas essa coluna já tem um efeito colateral em produção (recalcula o preço de venda) que o usuário provavelmente não quer disparar só por editar uma cotação de compra. |

## Definição da SPEC

### Item 1 — Custo e impostos separados

**Não decido isso sozinho** — a única informação factual disponível é que `produtos` já tem `icms_entrada`, `ipi_entrada`, `porc_st`, `porc_desconto`, `porc_despesas` como *percentuais mestres do produto*, e que o ERP legado rastreava `vl_ipi`/`vl_st`/`vl_desconto`/`vl_frete` como *valores por transação*. Não há como saber, sem confirmação de Pedro/Filippo, se o pedido de compra deve (a) herdar os percentuais do produto, (b) registrar valores digitados manualmente por compra (podem divergir da NF-e real), ou (c) as duas coisas.

**Alternativas:**

| | Descrição | Prós | Contras |
|---|---|---|---|
| **A — Herdar do produto** | `pedido_compra_itens` ganha colunas calculadas a partir de `produtos.icms_entrada`/`ipi_entrada`/`porc_st` no momento da compra (snapshot, não live-join) | Reaproveita dado já mantido em Cadastro; sem digitação manual | Uma compra pontual pode ter imposto diferente do padrão do produto (regime especial do fornecedor, substituição tributária pontual) — não é flexível |
| **B — Independente por compra** | `pedido_compra_itens` ganha campos próprios (`custo_liquido`, `valor_icms`, `valor_ipi`, `valor_st`), digitados a cada pedido, sem relação com `produtos` | Reflete a nota fiscal real de cada compra; nenhum risco de side-effect em `produtos` | Mais campos para o comprador preencher a cada pedido; nenhuma reconciliação automática com o cadastro do produto |
| **C — Híbrida (recomendada)** | Pré-preenche os campos de imposto a partir de `produtos.icms_entrada`/`ipi_entrada`/`porc_st` (via `produto_fornecedores` se existir override por fornecedor, senão `produtos`), mas grava o valor **efetivo** digitado/editado em `pedido_compra_itens` — sem sincronizar de volta para `produtos` | Menor esforço de digitação nos casos comuns, mas mantém rastreabilidade exata do que foi realmente pago naquela compra | Precisa decidir a ordem de precedência (produto vs. `produto_fornecedores`) e se ICMS/ST devem ser um único campo ou dois (ver P-01) |

**Recomendação:** C, mas **P-01 (quais impostos exatamente) precisa de resposta antes de fechar as colunas.** O rascunho de migration abaixo assume ICMS + IPI + ST como ponto de partida (mesmo vocabulário já usado em `produtos`/`staging_conta_pagar`), mas isso é só um placeholder até confirmação.

### Item 2 — Numeração automática do pedido

Reaproveita o padrão exato de `set_orcamento_numero()`, mas escopado por ano (mais próximo do placeholder `PC-2026-001` já exibido na UI hoje). Novo trigger `BEFORE INSERT ON pedidos_compra`, mais `UNIQUE` na coluna (gap de integridade que já existe hoje, independente desta SPEC). As duas RPCs existentes (`criar_pedido_compra_de_necessidade`, `criar_pedido_compra_lote`) precisam que `p_numero` vire opcional — se `NULL`/vazio, o trigger assume.

**Frontend:** o campo "Nº do pedido / referência" deixa de ser obrigatório em `canSubmit` (`ModalRegistrarCompra.tsx:97`, `ModalPedidoLote.tsx:101`); pode virar um texto informativo "será gerado automaticamente" ou continuar existindo como campo opcional de referência interna adicional (não mais a chave visível) — o `numero` real retornado pela RPC já é exibido no toast de sucesso hoje (`ModalRegistrarCompra.tsx:114-117`), então basta parar de exigir preenchimento.

### Item 3 — Vínculo informativo a orçamento/projeto de origem

Segue a mesma filosofia já usada por `vw_necessidade_compra_detalhe` (SPEC-022): **não** vira uma FK obrigatória em `pedidos_compra`/`pedido_compra_itens` (isso contradiria a decisão da reunião 08 e da SPEC-020, que a compra deve permanecer agregada por produto). Proposta: nova tabela de junção `pedido_compra_item_origem`, N:N entre `pedido_compra_itens` e `projeto_itens`, nullable/opcional, preenchida (se o comprador quiser) no momento de registrar o pedido a partir da linha expandida (`NecessidadeCompraDetalhe.tsx` já lista os `projeto_item_id` candidatos por produto).

**"Código da venda":** como não existe esse nome de campo em lugar nenhum vivo (só na staging legada, desconectada), a interpretação mais provável é `orcamentos.numero` (formato `ORC-XXXX`), já exposto como `orcamento_numero` em `vw_necessidade_compra_detalhe` e em `EntregaFuturaRow`. **Fica como pergunta aberta confirmar isso com Pedro (P-03)** antes de nomear qualquer coluna/label na UI.

### Item 4 — Parcelas do pedido a fornecedor

**Não decido isso sozinho.** O padrão técnico de parsing (`_lucenera_parse_prazo_pagamento`) é claramente reaproveitável, mas o desenho de "onde essas parcelas vivem" depende de decisão de produto.

**Alternativas:**

| | Descrição | Prós | Contras |
|---|---|---|---|
| **A — Nova tabela `pedido_compra_parcelas` (recomendada)** | Espelha `projeto_parcelas`, mas para o lado pagável: `pedido_id`, `numero_parcela`, `valor`, `data_vencimento`, `status` (texto+CHECK, seguindo o padrão já usado em `pedidos_compra.status`/`solicitacoes_compra.status`, **não** reaproveitando o enum `parcela_status` que é do lado recebível). Nova RPC gera as parcelas usando `_lucenera_parse_prazo_pagamento()` já existente, alimentada por `pedidos_compra.condicoes_pagamento` e um novo array opcional `pedidos_compra.prazo_pagamento_dias integer[]` (mesmo padrão de `orcamentos.prazo_pagamento_dias`) | Reaproveita função já testada; mantém pagável/recebível conceitualmente separados (sem risco de um `UPDATE` em massa em `projeto_parcelas` afetar compras por engano); não depende de Financeiro existir | Cria uma tabela nova que hoje não tem nenhum consumidor em Financeiro (não há `contas_a_pagar` no banco ainda) — fica "presa" dentro de Compras até o Financeiro alcançar essa parte do escopo (SPEC-EST-13) |
| **B — Só UI, sem persistência** | Campo calcula e mostra a divisão em parcelas (client-side) a partir do texto digitado, mas grava só o texto livre em `condicoes_pagamento`, como hoje | Zero migration | Não atende literalmente o pedido ("registrar as parcelas") — é só uma calculadora visual, não um registro |
| **C — Esperar o módulo de Financeiro (`contas_a_pagar`)** | Não implementa nada agora; aguarda a SPEC-EST-10/13 (previsão financeira + confirmação de conta a pagar) do escopo de Estoque/Compras, ainda não iniciada | Evita modelar uma tabela que pode ser substituída/duplicada quando o Financeiro chegar nesse ponto | Bloqueia o pedido do usuário por tempo indeterminado — a SPEC-EST-10/13 não tem data |

**Recomendação:** A, mas **P-04 (layout de status/campos exatos e se deve haver alguma integração futura com Financeiro) precisa de confirmação.**

### Item 5 — % de desconto em Cotações

**Não** reaproveitar `produtos.porc_desconto` diretamente — essa coluna já alimenta `fn_atualizar_preco_venda()` (recalcula `preco_venda` de vendas automaticamente). Se o "% desconto" que o comprador digita numa cotação sobrescrever esse campo, ele estaria mexendo (talvez sem perceber) no preço de venda ao cliente — um efeito colateral real de produção, não hipotético.

**Alternativas:**

| | Descrição | Prós | Contras |
|---|---|---|---|
| **A — Reaproveitar `produtos.porc_desconto`** | `Cotacoes.tsx` ganha um segundo campo editável escrevendo direto em `produtos.porc_desconto` via extensão de `atualizar_preco_custo_produto` (ou nova RPC) | Zero coluna nova; reaproveita campo já existente | Dispara recalculo de `preco_venda` como efeito colateral — risco de mudar preço de venda sem intenção, a não ser que isso seja exatamente o que Pedro quer |
| **B — Nova coluna dedicada em `produtos` (recomendada)** | `produtos.percentual_desconto_compra numeric(5,2)`, nova, isolada de `porc_desconto`; nova RPC `atualizar_desconto_compra_produto`; exposta em `vw_necessidade_compra` | Sem efeito colateral em `preco_venda`; mesmo padrão (RPC dedicada + coluna em `produtos`) já usado pela própria SPEC-036 para `preco_custo` | Cria uma segunda noção de "desconto" em `produtos` (`porc_desconto` vs. `percentual_desconto_compra`) — precisa de nome claro para não confundir os dois no futuro |
| **C — Construir o fluxo real de `cotacao_itens`** | Adiciona `desconto_percentual` a `cotacao_itens` e implementa de fato o CRUD de cotação por fornecedor (que hoje é código morto no frontend) | Architeturalmente correto, alinhado ao SPEC-EST-08 original | Escopo muito maior que "5 melhorias pontuais" — exige telas novas de criar/listar cotação por fornecedor que não existem hoje |

**Recomendação:** B — mas **P-05 (o desconto deve ou não alimentar `preco_venda`) precisa de confirmação**, porque muda diretamente entre A e B.

## Migrations propostas (rascunho — não aplicadas)

Pasta: `supabase/db/migrations/20260721_052_spec038_compras_melhorias/`

### `001_pedido_compra_itens_impostos.sql` (Item 1 — placeholder até P-01 ser respondida)

```sql
-- SPEC-038 — Item 1. RASCUNHO sujeito a confirmação de quais impostos exatamente
-- (ICMS? IPI? ST? outro?) — ver Pendências P-01. Nomenclatura escolhida por
-- analogia com produtos.icms_entrada/ipi_entrada/porc_st (01_schema_full.sql:5579-5593)
-- e com a tabela legada staging_conta_pagar.vl_ipi/vl_st (sem vl_icms).
-- NÃO APLICAR sem confirmação explícita do usuário.

ALTER TABLE public.pedido_compra_itens
  ADD COLUMN IF NOT EXISTS custo_liquido   numeric(12,4),  -- custo antes de impostos
  ADD COLUMN IF NOT EXISTS valor_icms      numeric(12,4),
  ADD COLUMN IF NOT EXISTS valor_ipi       numeric(12,4),
  ADD COLUMN IF NOT EXISTS valor_st        numeric(12,4);

COMMENT ON COLUMN public.pedido_compra_itens.custo_liquido IS
'SPEC-038. Custo unitário antes de impostos. custo_unitario (já existente) passa a
representar o custo TOTAL (líquido + impostos) — a definir na implementação real
conforme resposta de P-01.';

-- Nenhum GRANT/RLS novo necessário — pedido_compra_itens já tem policy de SELECT
-- authenticated; escrita segue via RPC SECURITY DEFINER, como hoje.
```

### `002_pedidos_compra_numero_automatico.sql` (Item 2)

```sql
-- SPEC-038 — Item 2. Numeração automática de pedidos_compra.numero,
-- reaproveitando o padrão já usado por set_orcamento_numero() e
-- fn_gerar_numero_orcamento() (ano-escopado, bate com o placeholder
-- "PC-2026-001" já exibido na UI hoje).

CREATE OR REPLACE FUNCTION public.set_pedido_compra_numero()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_max_num integer;
  v_ano     text := to_char(CURRENT_DATE, 'YYYY');
BEGIN
  IF NEW.numero IS NULL OR trim(NEW.numero) = '' THEN
    SELECT COALESCE(MAX(CAST(SPLIT_PART(numero, '-', 3) AS integer)), 0)
    INTO v_max_num
    FROM public.pedidos_compra
    WHERE numero LIKE 'PC-' || v_ano || '-%'
      AND numero ~ ('^PC-' || v_ano || '-[0-9]+$');

    NEW.numero := 'PC-' || v_ano || '-' || LPAD((v_max_num + 1)::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_pedido_compra_numero() IS
'SPEC-038. Gera pedidos_compra.numero automaticamente no formato PC-<ano>-NNNN
quando NEW.numero vier NULL/vazio. Mesmo padrão de set_orcamento_numero()/
fn_gerar_numero_orcamento().';

DROP TRIGGER IF EXISTS trigger_set_pedido_compra_numero ON public.pedidos_compra;
CREATE TRIGGER trigger_set_pedido_compra_numero
  BEFORE INSERT ON public.pedidos_compra
  FOR EACH ROW EXECUTE FUNCTION public.set_pedido_compra_numero();

-- Gap de integridade pré-existente: numero nunca teve UNIQUE. Adicionar agora.
-- Se já houver duplicatas reais no banco, este ALTER falha — checar antes:
--   SELECT numero, count(*) FROM pedidos_compra GROUP BY numero HAVING count(*) > 1;
ALTER TABLE public.pedidos_compra
  ADD CONSTRAINT pedidos_compra_numero_uniq UNIQUE (numero);

-- Torna p_numero opcional nas duas RPCs existentes (trigger assume se NULL/vazio)
CREATE OR REPLACE FUNCTION public.criar_pedido_compra_de_necessidade(
    p_produto_id             uuid,
    p_fornecedor_id          uuid,
    p_quantidade             numeric,
    p_custo_unitario         numeric,
    p_numero                 text    DEFAULT NULL,
    p_data_prevista_entrega  date    DEFAULT NULL,
    p_condicoes_pagamento    text    DEFAULT NULL,
    p_observacao             text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_solicitacao_id  uuid;
    v_pedido_id       uuid;
    v_pedido_item_id  uuid;
    v_numero_final    text;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    IF p_custo_unitario IS NULL OR p_custo_unitario <= 0 THEN
        RAISE EXCEPTION 'Custo unitario deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.produtos WHERE id = p_produto_id) THEN
        RAISE EXCEPTION 'Produto % nao encontrado.', p_produto_id USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
        RAISE EXCEPTION 'Fornecedor % nao encontrado em contatos.', p_fornecedor_id USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.solicitacoes_compra (
        produto_id, quantidade, status, prioridade, observacao, solicitado_por
    ) VALUES (
        p_produto_id, p_quantidade, 'pedido_gerado', 'normal', p_observacao, auth.uid()
    )
    RETURNING id INTO v_solicitacao_id;

    -- p_numero NULL/vazio: trigger_set_pedido_compra_numero preenche automaticamente
    INSERT INTO public.pedidos_compra (
        numero, fornecedor_id, status, data_emissao,
        data_prevista_entrega, condicoes_pagamento,
        valor_total, observacao, aprovado_por, aprovado_em, criado_por
    ) VALUES (
        NULLIF(trim(p_numero), ''), p_fornecedor_id, 'enviado', CURRENT_DATE,
        p_data_prevista_entrega, p_condicoes_pagamento,
        p_quantidade * p_custo_unitario, p_observacao,
        auth.uid(), now(), auth.uid()
    )
    RETURNING id, numero INTO v_pedido_id, v_numero_final;

    INSERT INTO public.pedido_compra_itens (
        pedido_id, solicitacao_id, produto_id,
        quantidade, qtd_recebida, custo_unitario
    ) VALUES (
        v_pedido_id, v_solicitacao_id, p_produto_id,
        p_quantidade, 0, p_custo_unitario
    )
    RETURNING id INTO v_pedido_item_id;

    RETURN jsonb_build_object(
        'pedido_id',      v_pedido_id,
        'solicitacao_id', v_solicitacao_id,
        'pedido_item_id', v_pedido_item_id,
        'numero',         v_numero_final,
        'status',         'enviado'
    );
END;
$$;

COMMENT ON FUNCTION public.criar_pedido_compra_de_necessidade(uuid, uuid, numeric, numeric, text, date, text, text) IS
'SPEC-021, atualizada pela SPEC-038: p_numero agora opcional — se NULL/vazio, gerado
automaticamente por trigger_set_pedido_compra_numero (formato PC-<ano>-NNNN).';

GRANT EXECUTE ON FUNCTION public.criar_pedido_compra_de_necessidade(uuid, uuid, numeric, numeric, text, date, text, text) TO authenticated;

-- Mesma alteração de assinatura para criar_pedido_compra_lote (p_numero DEFAULT NULL,
-- NULLIF(trim(p_numero), '') no INSERT, retorno lê numero pós-trigger). Corpo
-- omitido aqui por repetição — implementador deve aplicar o mesmo padrão ao SQL
-- já existente em 20260716_049_spec030_pedido_lote_marca_fornecedor/003_rpc_criar_pedido_compra_lote.sql.
```

### `003_pedido_compra_item_origem.sql` (Item 3)

```sql
-- SPEC-038 — Item 3. Vínculo INFORMATIVO (não obrigatório, não bloqueante) entre
-- um item de pedido de compra e o(s) projeto_item(s) que o motivaram. Não
-- contradiz a decisão da reunião 08 / SPEC-020 (compra agregada por produto,
-- sem dono fixo) — é só rastreabilidade de "por que compramos isso".

CREATE TABLE IF NOT EXISTS public.pedido_compra_item_origem (
    id                    uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    pedido_compra_item_id uuid NOT NULL REFERENCES public.pedido_compra_itens(id) ON DELETE CASCADE,
    projeto_item_id       uuid NOT NULL REFERENCES public.projeto_itens(id) ON DELETE CASCADE,
    quantidade_atendida   numeric(10,3) CHECK (quantidade_atendida IS NULL OR quantidade_atendida > 0),
    observacao            text,
    criado_por            uuid REFERENCES auth.users(id),
    criado_em             timestamptz NOT NULL DEFAULT now(),
    UNIQUE (pedido_compra_item_id, projeto_item_id)
);

COMMENT ON TABLE public.pedido_compra_item_origem IS
'SPEC-038. Vinculo INFORMATIVO (nao obrigatorio) entre pedido_compra_itens e
projeto_itens — registra qual(is) demanda(s) de projeto motivaram esta compra,
sem tornar a compra dependente de um unico cliente/projeto (decisao da
reuniao 08/06/2026, SPEC-020). orcamento_id/cliente sao resolvidos por JOIN via
projeto_itens.orcamento_id -> orcamentos, nao duplicados aqui.';

CREATE INDEX IF NOT EXISTS idx_pcio_item    ON public.pedido_compra_item_origem (pedido_compra_item_id);
CREATE INDEX IF NOT EXISTS idx_pcio_projeto ON public.pedido_compra_item_origem (projeto_item_id);

ALTER TABLE public.pedido_compra_item_origem ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_select_pedido_compra_item_origem ON public.pedido_compra_item_origem;
CREATE POLICY authenticated_select_pedido_compra_item_origem
  ON public.pedido_compra_item_origem
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS authenticated_insert_pedido_compra_item_origem ON public.pedido_compra_item_origem;
CREATE POLICY authenticated_insert_pedido_compra_item_origem
  ON public.pedido_compra_item_origem
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (true);

GRANT SELECT, INSERT ON TABLE public.pedido_compra_item_origem TO authenticated;

-- View de leitura (opcional, para a UI mostrar orçamento/cliente por JOIN,
-- no mesmo espírito de vw_necessidade_compra_detalhe da SPEC-022):
CREATE OR REPLACE VIEW public.vw_pedido_compra_item_origem
WITH (security_invoker = true)
AS
SELECT
    pcio.id,
    pcio.pedido_compra_item_id,
    pcio.projeto_item_id,
    pcio.quantidade_atendida,
    pr.codigo   AS projeto_codigo,
    pr.nome     AS projeto_nome,
    o.numero    AS orcamento_numero,
    c.nome      AS cliente
FROM public.pedido_compra_item_origem pcio
JOIN public.projeto_itens pi ON pi.id = pcio.projeto_item_id
LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
LEFT JOIN public.contatos c ON c.id = COALESCE(o.cliente_id, pr.cliente_id, pr.client_id);

COMMENT ON VIEW public.vw_pedido_compra_item_origem IS
'SPEC-038. Resolve projeto/orcamento/cliente por JOIN a partir de
pedido_compra_item_origem, mesmo padrao da vw_necessidade_compra_detalhe (SPEC-022).';

GRANT SELECT ON public.vw_pedido_compra_item_origem TO authenticated;
```

### `004_pedido_compra_parcelas.sql` (Item 4 — placeholder até P-04 ser respondida)

```sql
-- SPEC-038 — Item 4. RASCUNHO sujeito a confirmação de layout (ver Pendências
-- P-04). Reaproveita _lucenera_parse_prazo_pagamento() já existente e testado
-- (01_schema_full.sql:314-373), mas cria tabela PRÓPRIA para o lado pagável —
-- não reaproveita projeto_parcelas (que é o lado recebível, cliente -> Lucenera)
-- nem o enum parcela_status (que é do mesmo domínio recebível).
-- NÃO APLICAR sem confirmação explícita do usuário.

ALTER TABLE public.pedidos_compra
  ADD COLUMN IF NOT EXISTS prazo_pagamento_dias integer[];  -- mesmo padrão de orcamentos.prazo_pagamento_dias

CREATE TABLE IF NOT EXISTS public.pedido_compra_parcelas (
    id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    pedido_id       uuid NOT NULL REFERENCES public.pedidos_compra(id) ON DELETE CASCADE,
    numero_parcela  integer NOT NULL,
    valor           numeric(12,2) NOT NULL CHECK (valor > 0),
    data_vencimento date NOT NULL,
    status          text NOT NULL DEFAULT 'pendente'
                    CHECK (status IN ('pendente', 'pago', 'atrasado', 'cancelado')),
    forma_pagamento public.pagamento_forma,
    observacao      text,
    criado_em       timestamptz NOT NULL DEFAULT now(),
    atualizado_em   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (pedido_id, numero_parcela)
);

COMMENT ON TABLE public.pedido_compra_parcelas IS
'SPEC-038. Parcelas do PAGAVEL (Lucenera -> fornecedor), analogas a
projeto_parcelas (RECEBIVEL, cliente -> Lucenera), mas tabela separada e sem
relacao com boletos (boletos.orcamento_id continua exclusivo do lado
recebivel). Geradas por RPC gerar_parcelas_pedido_compra.';

CREATE INDEX IF NOT EXISTS idx_pcp_pedido ON public.pedido_compra_parcelas (pedido_id);
CREATE INDEX IF NOT EXISTS idx_pcp_status ON public.pedido_compra_parcelas (status);

ALTER TABLE public.pedido_compra_parcelas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_select_pedido_compra_parcelas ON public.pedido_compra_parcelas;
CREATE POLICY authenticated_select_pedido_compra_parcelas
  ON public.pedido_compra_parcelas
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.pedido_compra_parcelas TO authenticated;

CREATE OR REPLACE FUNCTION public.gerar_parcelas_pedido_compra(
    p_pedido_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pedido          public.pedidos_compra%ROWTYPE;
    v_prazos          integer[];
    v_qtd_parcelas    integer;
    v_valor_base      numeric(12,2);
    v_valor_acumulado numeric(12,2) := 0;
    v_valor_parcela   numeric(12,2);
    v_i               integer;
    v_criadas         integer := 0;
BEGIN
    SELECT * INTO v_pedido FROM public.pedidos_compra WHERE id = p_pedido_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
    END IF;

    IF v_pedido.valor_total IS NULL OR v_pedido.valor_total <= 0 THEN
        RAISE EXCEPTION 'Pedido % nao possui valor_total valido.', v_pedido.numero USING ERRCODE = 'P0001';
    END IF;

    v_prazos := public._lucenera_parse_prazo_pagamento(
        v_pedido.condicoes_pagamento, v_pedido.prazo_pagamento_dias
    );
    v_qtd_parcelas := COALESCE(array_length(v_prazos, 1), 0);

    IF v_qtd_parcelas = 0 THEN
        RAISE EXCEPTION 'Nao foi possivel interpretar condicoes_pagamento/prazo_pagamento_dias do pedido %.', v_pedido.numero
            USING ERRCODE = 'P0001';
    END IF;

    -- Idempotente: nao duplica se ja houver parcelas geradas
    IF EXISTS (SELECT 1 FROM public.pedido_compra_parcelas WHERE pedido_id = p_pedido_id) THEN
        RAISE EXCEPTION 'Pedido % ja possui parcelas geradas.', v_pedido.numero USING ERRCODE = 'P0001';
    END IF;

    v_valor_base := round(v_pedido.valor_total / v_qtd_parcelas, 2);

    FOR v_i IN 1..v_qtd_parcelas LOOP
        v_valor_parcela := CASE
            WHEN v_i < v_qtd_parcelas THEN v_valor_base
            ELSE v_pedido.valor_total - v_valor_acumulado
        END;

        INSERT INTO public.pedido_compra_parcelas (
            pedido_id, numero_parcela, valor, data_vencimento, status
        ) VALUES (
            p_pedido_id, v_i, v_valor_parcela,
            v_pedido.data_emissao + v_prazos[v_i],
            'pendente'
        );

        v_valor_acumulado := v_valor_acumulado + v_valor_parcela;
        v_criadas := v_criadas + 1;
    END LOOP;

    RETURN jsonb_build_object('pedido_id', p_pedido_id, 'parcelas_criadas', v_criadas);
END;
$$;

COMMENT ON FUNCTION public.gerar_parcelas_pedido_compra(uuid) IS
'SPEC-038. Gera pedido_compra_parcelas a partir de condicoes_pagamento/
prazo_pagamento_dias do pedido, reaproveitando _lucenera_parse_prazo_pagamento()
ja usada por orcamentos. Idempotente: falha se ja houver parcelas.';

GRANT EXECUTE ON FUNCTION public.gerar_parcelas_pedido_compra(uuid) TO authenticated;

-- Decisão do usuário (P-04, 2026-07-21): o valor de cada parcela gerada acima
-- precisa poder ser editado manualmente depois (não é fixo na divisão igual).
CREATE OR REPLACE FUNCTION public.atualizar_parcela_pedido_compra(
    p_parcela_id      uuid,
    p_valor           numeric,
    p_data_vencimento date
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pedido_id     uuid;
    v_valor_total   numeric(12,2);
    v_soma_parcelas numeric(12,2);
BEGIN
    IF p_valor IS NULL OR p_valor <= 0 THEN
        RAISE EXCEPTION 'Valor da parcela deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    SELECT pedido_id INTO v_pedido_id
    FROM public.pedido_compra_parcelas WHERE id = p_parcela_id;

    IF v_pedido_id IS NULL THEN
        RAISE EXCEPTION 'Parcela % nao encontrada.', p_parcela_id USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.pedido_compra_parcelas
    SET valor = p_valor,
        data_vencimento = COALESCE(p_data_vencimento, data_vencimento),
        atualizado_em = now()
    WHERE id = p_parcela_id;

    SELECT valor_total INTO v_valor_total
    FROM public.pedidos_compra WHERE id = v_pedido_id;

    SELECT COALESCE(SUM(valor), 0) INTO v_soma_parcelas
    FROM public.pedido_compra_parcelas WHERE pedido_id = v_pedido_id;

    IF v_soma_parcelas <> v_valor_total THEN
        RAISE WARNING 'Soma das parcelas (%%) diverge do valor_total do pedido (%%) apos edicao manual.',
          v_soma_parcelas, v_valor_total;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.atualizar_parcela_pedido_compra(uuid, numeric, date) IS
'SPEC-038 (P-04). Permite editar manualmente valor/data_vencimento de uma
parcela ja gerada por gerar_parcelas_pedido_compra — decisao do usuario de
nao travar a divisao automatica igual entre parcelas. Emite WARNING (nao
bloqueia) se a soma das parcelas divergir de pedidos_compra.valor_total,
para o comprador poder ajustar arredondamento manualmente entre parcelas.';

GRANT EXECUTE ON FUNCTION public.atualizar_parcela_pedido_compra(uuid, numeric, date) TO authenticated;
```

### `005_cotacoes_desconto_produto.sql` (Item 5)

```sql
-- SPEC-038 — Item 5. Nova coluna DEDICADA em produtos, separada de
-- porc_desconto (que ja alimenta fn_atualizar_preco_venda() e o preco de
-- VENDA ao cliente) — evita efeito colateral nao intencional em vendas ao
-- editar um desconto de COMPRA na tela de Cotacoes. Ver P-05.

ALTER TABLE public.produtos
  ADD COLUMN IF NOT EXISTS percentual_desconto_compra numeric(5,2) DEFAULT 0;

COMMENT ON COLUMN public.produtos.percentual_desconto_compra IS
'SPEC-038. Percentual de desconto negociado na COMPRA (tela Cotacoes,
compras-lucenera). Distinto de produtos.porc_desconto, que alimenta
fn_atualizar_preco_venda() e o preco de VENDA ao cliente — NAO dispara
recalculo de preco_venda. Ver P-05 (pendencia) sobre se essa separacao deve
ser mantida ou se o valor deve, no futuro, alimentar o mesmo calculo.';

CREATE OR REPLACE FUNCTION public.atualizar_desconto_compra_produto(
    p_produto_id              uuid,
    p_percentual_desconto     numeric
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_percentual_desconto IS NULL OR p_percentual_desconto < 0 OR p_percentual_desconto > 100 THEN
        RAISE EXCEPTION 'Percentual de desconto deve estar entre 0 e 100.' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.produtos
    SET percentual_desconto_compra = p_percentual_desconto,
        updated_at = now()
    WHERE id = p_produto_id
      AND ativo = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Produto % nao encontrado ou inativo.', p_produto_id USING ERRCODE = 'P0001';
    END IF;
END;
$$;

COMMENT ON FUNCTION public.atualizar_desconto_compra_produto(uuid, numeric) IS
'SPEC-038. Atualiza produtos.percentual_desconto_compra via tela Cotacoes.
Mesmo padrao de atualizar_preco_custo_produto (SPEC-036). SECURITY DEFINER.
NAO afeta fn_atualizar_preco_venda()/preco_venda.';

GRANT EXECUTE ON FUNCTION public.atualizar_desconto_compra_produto(uuid, numeric) TO authenticated;

-- Estende vw_necessidade_compra (CREATE OR REPLACE acrescenta coluna no final,
-- sem quebrar consumidores existentes — mesmo padrão da migration 20260713_036)
CREATE OR REPLACE VIEW public.vw_necessidade_compra
WITH (security_invoker = true)
AS
SELECT
    p.id                                            AS produto_id,
    p.nome                                          AS produto,
    p.codigo_produto                                AS produto_codigo,
    coalesce(ei_agg.qtd_estoque, 0)                 AS qtd_fisica,
    coalesce(ei_agg.qtd_reservada, 0)               AS qtd_comprometida,
    GREATEST(0, coalesce(ei_agg.qtd_reservada, 0) - coalesce(ei_agg.qtd_estoque, 0)) AS necessidade_compra,
    coalesce(ei_agg.qtd_estoque, 0) - coalesce(ei_agg.qtd_reservada, 0) AS qtd_disponivel,
    coalesce(proj.n_projetos, 0)                    AS projetos_com_entrega_futura,
    p.preco_custo,
    m.id                                            AS marca_id,
    m.nome                                          AS marca_nome,
    COALESCE(p.fornecedor_principal_id, m.fornecedor_id) AS fornecedor_id,
    fc.nome                                         AS fornecedor_nome,
    p.percentual_desconto_compra                    AS percentual_desconto_compra
FROM public.produtos p
JOIN (
    SELECT produto_id, SUM(quantidade) AS qtd_estoque, SUM(quantidade_reservada) AS qtd_reservada
    FROM public.estoque_itens GROUP BY produto_id
) ei_agg ON ei_agg.produto_id = p.id
LEFT JOIN (
    SELECT pi.produto_id, count(DISTINCT pi.projeto_id) AS n_projetos
    FROM public.estoque_saldos_projeto_item esp
    JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
    WHERE esp.status_operacional = 'ativo' AND (esp.q_reserva > 0 OR esp.q_entrega_futura > 0)
    GROUP BY pi.produto_id
) proj ON proj.produto_id = p.id
LEFT JOIN public.marcas m ON m.id = p.marca_id
LEFT JOIN public.contatos fc ON fc.id = COALESCE(p.fornecedor_principal_id, m.fornecedor_id)
WHERE p.ativo = true
  AND coalesce(ei_agg.qtd_reservada, 0) > coalesce(ei_agg.qtd_estoque, 0)
ORDER BY necessidade_compra DESC, p.nome;

COMMENT ON VIEW public.vw_necessidade_compra IS
'SPEC-038 (estende migration 20260716_049 + 20260713_036). Adiciona
percentual_desconto_compra ao final. SECURITY INVOKER.';

GRANT SELECT ON TABLE public.vw_necessidade_compra TO authenticated;
```

> **Nota de risco desta migration 005:** o `CREATE OR REPLACE VIEW` acima
> precisa ser conferido linha a linha contra a definição **realmente aplicada**
> no Supabase (não a de `db/current/`, que está desatualizada) antes de rodar —
> reescrevi com base na versão documentada na SPEC-030/033 (`marca_id`,
> `marca_nome`, `fornecedor_id`, `fornecedor_nome`, `qtd_disponivel`), mas não
> tenho acesso ao banco real nesta sessão para confirmar que não há mais
> nenhuma coluna intermediária adicionada depois da SPEC-034.

## Ecossistema — respostas obrigatórias

- **Depende de `projetos`/`orcamentos`/`contatos`/`produtos`/`boletos`/`projeto_itens`/`projeto_parcelas`/`usuarios`/`systems`/`user_system_access`?** Sim, fortemente — ao contrário do catálogo Ubiqua (isolado), este é o sistema central de Compras. Depende de `produtos` (Item 1, 5), `contatos` (fornecedor, Item 2/4), `projeto_itens`/`projetos`/`orcamentos` (Item 3, leitura/vínculo informativo), `pedidos_compra`/`pedido_compra_itens`/`solicitacoes_compra` (Item 1-4, já existentes). **Não** depende de `boletos` nem `projeto_parcelas` diretamente — o Item 4 propõe deliberadamente uma tabela nova e separada (`pedido_compra_parcelas`) para não violar o invariante de que `boletos`/`projeto_parcelas` são exclusivos do fluxo recebível (cliente → Lucenera).
- **Afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística, RH, Hub/TI?** Afeta só Estoque/Compras (`compras-lucenera-3o23t98ee`) e o banco central. Não altera nenhuma tela de Orçamentos, Cadastro ou Financeiro — mas o Item 5 evita deliberadamente tocar em `produtos.porc_desconto`/`preco_venda`, que **são** consumidos por Vendas/Orçamentos, exatamente para não vazar efeito para esses sistemas sem decisão explícita (ver P-05).
- **Existe dado duplicado que deveria ser derivado por relacionamento em vez de duplicado?** Não introduzida por esta SPEC — o Item 3 é desenhado deliberadamente como vínculo por relacionamento (`projeto_item_id`, resolvendo `orcamento_id`/`cliente` por JOIN via `vw_pedido_compra_item_origem`), não duplicando `orcamento_id`/`cliente_id` na nova tabela. O Item 1, dependendo de qual alternativa for escolhida (P-01), pode introduzir duplicação intencional e temporária entre `produtos.icms_entrada`/`ipi_entrada` (mestre) e os novos campos de `pedido_compra_itens` (snapshot da transação) — isso é esperado/aceitável para um snapshot fiscal por compra, não um erro de modelagem, mas deve ficar documentado como tal.
- **Existe migration antiga em algum sistema que contradiz o snapshot central?** Sim — achado novo desta SPEC: `supabase/db/current/01_schema_full.sql:6108-6115` ainda mostra uma versão legada de `solicitacoes_compra` (com `projeto_id NOT NULL`, `quantidade_pedida`) que contradiz a definição real e aplicada (`20260710_031/002_solicitacoes_compra.sql`, sem `projeto_id`). Isso reforça a pendência crônica (db/current desatualizado desde 2026-07-07 para todo o domínio de Compras) já registrada nas SPEC-030/033/034.
- **A mudança exige atualizar `AI_DB_CONTEXT.md` de algum sistema?** Não existe esse arquivo em `compras-lucenera-3o23t98ee` (confirmado nas SPEC-033/034). `supabase/db/domains/estoque_compras.md` já está desatualizado (não menciona nenhum dos objetos das SPEC-030/033/034 nem os desta SPEC) — recomenda-se atualização quando as decisões pendentes forem fechadas, sem bloquear esta SPEC.
- **Sistema(s) afetado(s) e padrão de acesso a dados já em uso?** Só `compras-lucenera-3o23t98ee`. Padrão já estabelecido e a ser seguido, não substituído: `src/services/*.ts` chamando `supabase-js` direto (`.from()`/`.rpc()`), tipos TypeScript explícitos, sem store global nem `react-query`; páginas com `useState`/`useEffect` local; modais recebem dados via props.

## Critérios de aceite

- Cada item desta SPEC só é implementado depois da decisão correspondente estar registrada (P-01, P-03, P-04, P-05).
- `SELECT numero, count(*) FROM pedidos_compra GROUP BY numero HAVING count(*) > 1` retorna 0 linhas antes de aplicar o `UNIQUE` do Item 2.
- Criar um pedido de compra sem preencher "Nº do pedido" gera automaticamente `PC-<ano>-NNNN` sequencial, sem colisão.
- `pedido_compra_item_origem` aceita 0, 1 ou N vínculos por `pedido_compra_item_id`, nunca bloqueia a criação do pedido em si.
- `gerar_parcelas_pedido_compra` (se A for a decisão do Item 4) soma exatamente `pedidos_compra.valor_total` entre as parcelas geradas (arredondamento absorvido na última parcela, mesmo comportamento de `projeto_parcelas`).
- Editar "% desconto" em Cotações não altera `produtos.preco_venda` nem dispara `fn_atualizar_preco_venda()` (a não ser que P-05 decida o contrário).
- Lint (`oxlint`/`oxfmt`) e `vite build` do sistema passam sem novo erro após a implementação frontend.
- Verificação manual (golden path no navegador + `SELECT` de conferência no Supabase) substitui suíte de testes automatizados — este sistema não tem testes automatizados reais.

## Realizado

**2026-07-21 — implementação de ponta a ponta dos 5 itens (migration + frontend), nenhuma migration aplicada no Supabase real.**

### Backend (migrations redigidas, não aplicadas)

Pasta `supabase/db/migrations/20260721_054_spec038_compras_melhorias/` (renomeada de `052` para `054` por colisão de numeração — ver Checklist):

- `001_pedido_compra_itens_impostos.sql` — `pedido_compra_itens` ganha `custo_liquido`/`valor_icms`/`valor_ipi`/`valor_st` (numeric(12,4), nullable).
- `002_pedidos_compra_numero_automatico.sql` — trigger `set_pedido_compra_numero()`/`trigger_set_pedido_compra_numero`, `UNIQUE (numero)`, e recriação de `criar_pedido_compra_de_necessidade`/`criar_pedido_compra_lote` com `p_numero` opcional + parâmetros novos (opcionais, ao final) para gravar o breakdown de imposto do Item 1.
- `003_pedido_compra_item_origem.sql` — tabela `pedido_compra_item_origem` (N:N `pedido_compra_itens` ↔ `projeto_itens`, nullable) + view `vw_pedido_compra_item_origem`.
- `004_pedido_compra_parcelas.sql` — `pedidos_compra.prazo_pagamento_dias`, tabela `pedido_compra_parcelas`, RPCs `gerar_parcelas_pedido_compra` e `atualizar_parcela_pedido_compra`. Corrigido bug de `RAISE WARNING` do rascunho da SPEC (`%%` duplo em vez de `%` simples, que quebraria a interpolação dos 2 argumentos).
- `005_cotacoes_desconto_produto.sql` — `produtos.percentual_desconto_compra`, RPC `atualizar_desconto_compra_produto`, `CREATE OR REPLACE VIEW vw_necessidade_compra` acrescentando a coluna ao final (base conferida contra a última migration real conhecida, `20260716_049_spec030_pedido_lote_marca_fornecedor/002_vw_necessidade_compra_marca_fornecedor.sql` — confirmado por grep como a mais recente a recriar essa view; ainda assim, **conferir no Supabase real antes de aplicar**, ver Pendências).

Todas as 5 migrations foram conferidas linha a linha contra o schema real em `supabase/db/current/01_schema_full.sql` e contra as migrations mais recentes do domínio (`20260710_031`, `20260710_032`, `20260713_036`, `20260716_049`) antes de serem finalizadas. Nenhuma foi aplicada no Supabase real nesta sessão — nem via CLI, nem via MCP, nem por qualquer outro meio.

### Frontend (`compras-lucenera-3o23t98ee`)

- `src/services/pedido-compra.ts` — `CriarPedidoInput`/`CriarPedidoLoteInput` com `numero` opcional e campos de imposto opcionais; `getProdutoImpostos`/`getProdutoImpostosBulk` (pré-preenchimento, P-02: `produto_fornecedores` vence se existir, senão `produtos`); `vincularOrigemPedidoItem`; `gerarParcelasPedidoCompra`/`getParcelasPedidoCompra`/`atualizarParcelaPedidoCompra`; `getPedidosCompra` (nova listagem para a página de Pedidos).
- `src/services/necessidade-compra.ts` — `NecessidadeCompraRow` ganha `percentual_desconto_compra`.
- `src/services/cotacoes.ts` — `atualizarDescontoCompra`.
- `src/components/compra/ModalRegistrarCompra.tsx` — custo separado em líquido + ICMS + IPI + ST (pré-preenchido, editável); número do pedido opcional; checklist de origem (projeto_item_id) buscado ao abrir o modal; checkbox "gerar parcelas automaticamente".
- `src/components/compra/ModalPedidoLote.tsx` — mesma separação de custo/impostos por linha (pré-preenchimento em lote via `getProdutoImpostosBulk`); número opcional; checkbox de parcelas.
- `src/pages/Cotacoes.tsx` — coluna "% Desconto" editável inline, mesmo padrão UX da coluna de preço de custo já existente.
- `src/pages/PedidosCompra.tsx` (novo) + `src/components/compra/PedidoParcelasPanel.tsx` (novo) — rota `/pedidos` deixou de ser "Em breve"; lista pedidos, expande linha para gerar/editar parcelas.
- `src/components/StatusBadge.tsx` — cores para os status de parcela (`pendente`/`pago`/`atrasado`).
- `src/App.tsx` — rota `/pedidos` aponta para `PedidosCompra`.

`oxlint src`, `oxfmt --check` e `vite build` rodados após as alterações — todos passaram sem erro (2 warnings pré-existentes de `react-hooks/exhaustive-deps` em `Cotacoes.tsx`, mesmo padrão do código original, não introduzidos por esta mudança de forma nova — o segundo é uma repetição do primeiro padrão já existente para o novo estado `editandoDesconto`).

### Não testado no navegador ainda (verificação manual do usuário recomendada, mas backend já confirmado funcional — ver "Achado crítico" abaixo)

- Registrar um pedido (único e em lote) pela UI sem preencher "Nº do pedido" e confirmar que o número `PC-<ano>-NNNN` aparece na tela.
- Conferir visualmente que o pré-preenchimento de custo líquido/ICMS/IPI/ST reflete `produtos.icms_entrada`/`ipi_entrada`/`porc_st` reais e que a edição manual é respeitada.
- Marcar itens de projeto na origem de um pedido pela UI (backend já testado via RPC direta).
- Gerar parcelas automaticamente pela UI e editar valor/data de uma parcela na página `/pedidos`, conferindo o aviso de divergência quando a soma não bate com `valor_total`.
- Editar "% Desconto" em Cotações pela UI e confirmar visualmente que `produtos.preco_venda` **não** muda.

## Achado crítico de grounding (pós-implementação, antes de aplicar) — 2026-07-21

**Antes de aplicar qualquer migration desta SPEC, uma checagem contra o Supabase real revelou que toda a base em que SPEC-020/021/030/033/034/038 foram construídas — inclusive a documentação em `supabase/db/current/` — estava incorreta em um ponto fundamental: a tabela `pedidos_compra` (plural), usada por `criar_pedido_compra_de_necessidade`/`criar_pedido_compra_lote` desde a SPEC-021 (10/07), nunca existiu de verdade no banco.** A migration que deveria criá-la (`20260710_031_spec020_operacionalizacao_compras/004_pedidos_compra.sql`) nunca foi aplicada — só as migrations vizinhas do mesmo lote (001/002/003/005-008) foram. Como PL/pgSQL não valida a existência de tabelas referenciadas no momento do `CREATE FUNCTION` (só na execução), as duas RPCs foram criadas e ficaram publicadas normalmente, mas **todo INSERT real falhava com "relation pedidos_compra does not exist"** — ou seja, a funcionalidade de "Registrar Compra" (individual e em lote) esteve **quebrada em produção desde 10/07/2026**, sem que nenhuma SPEC subsequente (021/022/030/033/034/035) detectasse isso, porque todas confiaram em `supabase/db/current/` (que documentava a tabela como existente) em vez de consultar o banco real. A SPEC-035 (análise de lacunas, 18/07) chegou a mencionar essa funcionalidade como "backend pronto desde a SPEC-020", repetindo o mesmo engano.

Ao investigar (com acesso real ao Postgres via `SUPABASE_DB_URL`), foram encontrados e corrigidos **3 problemas de base**, todos antes desta SPEC e não causados por ela, aplicados diretamente no Supabase real com autorização do usuário:

1. **`pedidos_compra` não existia** — aplicada a migration `20260710_031_spec020_operacionalizacao_compras/004_pedidos_compra.sql` (nunca aplicada antes), que a cria. Também adicionada a FK `pedido_compra_itens.pedido_id → pedidos_compra.id` (nunca existia, porque não havia tabela para referenciar).
2. **`solicitacoes_compra.projeto_id`** ainda tinha `NOT NULL` de uma versão legada anterior à SPEC-020 (a mesma coluna que a própria SPEC-038 havia encontrado em `db/current` e descartado como "desatualizada" — na verdade ela refletia corretamente o banco real). `criar_pedido_compra_de_necessidade`/`criar_pedido_compra_lote` nunca preenchem essa coluna (decisão da reunião 08/06: compra não amarrada a projeto). Corrigido: `ALTER ... DROP NOT NULL`.
3. **`solicitacoes_compra.quantidade_pedida`** — mesma situação: coluna legada `NOT NULL`, nunca preenchida pelas RPCs novas (que usam `quantidade`). Corrigido: `ALTER ... DROP NOT NULL`.

Depois dessas 3 correções, `criar_pedido_compra_de_necessidade` e `criar_pedido_compra_lote` foram **testadas de ponta a ponta via chamada HTTP real** (não simulação) e funcionaram — primeira vez, ao que tudo indica, que essas RPCs funcionaram de verdade desde que foram criadas.

### Migrations aplicadas e testadas em 2026-07-21 (pelo orquestrador, nunca por subagente, com confirmação explícita do usuário)

1. `20260710_031_spec020_operacionalizacao_compras/004_pedidos_compra.sql` (retroativa — corrige gap de 10/07).
2. `20260721_054_spec038_compras_melhorias/001_pedido_compra_itens_impostos.sql`
3. `20260721_054_spec038_compras_melhorias/002_pedidos_compra_numero_automatico.sql`
4. `20260721_054_spec038_compras_melhorias/003_pedido_compra_item_origem.sql`
5. `20260721_054_spec038_compras_melhorias/004_pedido_compra_parcelas.sql`
6. `20260721_054_spec038_compras_melhorias/005_cotacoes_desconto_produto.sql`

**Testes reais executados (via REST/RPC, dados de teste criados e removidos em seguida):**
- `criar_pedido_compra_de_necessidade` com `p_numero=NULL` e breakdown de impostos → gerou `PC-2026-0002` automaticamente, gravou `custo_liquido`/`valor_icms`/`valor_ipi`/`valor_st`.
- `gerar_parcelas_pedido_compra` → 3 parcelas criadas a partir de "30/60/90".
- `atualizar_parcela_pedido_compra` → edição manual de valor/vencimento de uma parcela, sucesso.
- `vincular_origem_pedido_compra_item` → vínculo informativo criado com sucesso (via RPC, não mais INSERT direto — ver seção "Revisão").
- `atualizar_desconto_compra_produto` → sucesso.
- `vw_necessidade_compra` → confirmada respondendo com a nova coluna `percentual_desconto_compra`, sem quebrar.

**Pendência que deixou de ser pendência:** "Confirmar a definição real de `vw_necessidade_compra` antes de aplicar a migration 005" — feito; a definição real (`pg_get_viewdef`) batia exatamente com o rascunho da migration, sem surpresas.
**Pendência que deixou de ser pendência:** "Confirmar duplicata de `numero` antes do `UNIQUE`" — feito (zero duplicatas, tabela estava vazia por estar quebrada desde sempre).

## Pendências

- [x] **P-01 (Item 1) — RESOLVIDA 2026-07-21:** Usuário confirmou ICMS + IPI + ST, Alternativa C (híbrida): pré-preenche a partir de `produtos.icms_entrada`/`ipi_entrada`/`porc_st`, mas grava o valor efetivo (editável) em `pedido_compra_itens` por compra. Migration `001` pode ser finalizada com essas 3 colunas de imposto (mais `custo_liquido`).
- [ ] **P-02 (Item 1, não bloqueante):** Se existir `produto_fornecedores.custo_unitario`/prazo específico daquele fornecedor, decidir se ele vence sobre `produtos.icms_entrada`/`ipi_entrada` na hora de pré-preencher. Default de implementação na ausência de resposta: `produto_fornecedores` vence se existir (mais específico), senão cai para `produtos`.
- [ ] **P-03 (Item 3, não bloqueante):** Assumido "código da venda" = `orcamentos.numero` (já exposto como `orcamento_numero` em `vw_necessidade_compra_detalhe`) — interpretação mais provável, não contestada pelo usuário. Se estiver errado, avisar antes de nomear qualquer label na UI.
- [x] **P-04 (Item 4) — RESOLVIDA 2026-07-21:** Usuário confirmou Alternativa A (nova tabela `pedido_compra_parcelas`, real no banco), **com um ajuste importante**: o valor de cada parcela precisa poder ser **editado manualmente** pelo usuário depois de gerado (não travado no cálculo automático de divisão igual) — "Tendo também a possibilidade de valor de parcela! assim conseguimos estipular todos os campos necessários!". Implementação: `gerar_parcelas_pedido_compra()` continua gerando a divisão automática como ponto de partida, mas a UI (`ModalRegistrarCompra.tsx`/`ModalPedidoLote.tsx` ou uma tela de detalhe do pedido) precisa permitir editar `valor`/`data_vencimento` de cada `pedido_compra_parcelas` depois de criada (nova função `atualizar_parcela_pedido_compra(p_parcela_id, p_valor, p_data_vencimento)`, com validação de que a soma das parcelas continua batendo com `pedidos_compra.valor_total`).
- [x] **P-05 (Item 5) — RESOLVIDA 2026-07-21:** Usuário confirmou Alternativa B (recomendada): campo isolado `produtos.percentual_desconto_compra`, não afeta `preco_venda`/`fn_atualizar_preco_venda()`.
- [ ] **Reextrair `supabase/db/current/`** — pendência crônica desde 2026-07-07 (SPEC-030/033/034), reforçada por um novo achado desta SPEC (`solicitacoes_compra` legado contradizendo a versão real em `db/current`). Não bloqueia esta SPEC, mas deve ser feita antes ou junto da implementação para não confundir o próximo agente.
- [ ] **Atualizar `supabase/db/domains/estoque_compras.md`** — não documenta nenhum objeto das SPEC-030/033/034 nem os desta SPEC. Pendência já registrada anteriormente, reafirmada aqui.
- [ ] **Confirmar a definição real e atualmente aplicada de `vw_necessidade_compra`** antes de aplicar a migration `005` — o `CREATE OR REPLACE VIEW` proposto foi reconstruído a partir da documentação das SPEC-030/033/034 (sem acesso ao Supabase real nesta sessão), e pode estar desatualizado se houve alguma mudança não documentada depois da SPEC-034.

## Revisão (agente `revisor`, 2026-07-21)

Revisão read-only concluída antes de qualquer commit/aplicação. Nenhum achado crítico. 2 achados médios, **ambos corrigidos** pelo orquestrador logo após a revisão:

- **Aviso 1 (corrigido):** `criar_pedido_compra_de_necessidade` mudava de 8 para 12 parâmetros — no Postgres isso não substitui a função antiga via `CREATE OR REPLACE`, cria uma sobrecarga órfã (a versão de 8 parâmetros, com número obrigatório e sem colunas de imposto, continuaria invocável). Corrigido com `DROP FUNCTION IF EXISTS ...(uuid, uuid, numeric, numeric, text, date, text, text)` explícito antes do `CREATE OR REPLACE FUNCTION`, em `002_pedidos_compra_numero_automatico.sql`. `criar_pedido_compra_lote` não tinha esse problema (manteve os mesmos 6 tipos de parâmetro, só adicionou `DEFAULT`).
- **Aviso 2 (corrigido):** `pedido_compra_item_origem` tinha policy de `INSERT` aberta (`WITH CHECK (true)`) com o frontend gravando direto via `supabase-js` — divergia do padrão de "escrita só via RPC `SECURITY DEFINER`" seguido por todas as outras tabelas de escrita deste domínio (`solicitacoes_compra`, `pedidos_compra`, `pedido_compra_itens`, `pedido_compra_parcelas`). Corrigido em `003_pedido_compra_item_origem.sql`: removida a policy de INSERT e o `GRANT INSERT`, criada a RPC `vincular_origem_pedido_compra_item` (idempotente via `ON CONFLICT DO UPDATE`). `src/services/pedido-compra.ts` (`vincularOrigemPedidoItem`) atualizado para chamar a RPC em vez de `.insert()` direto. `tsc --noEmit` conferido novamente após a mudança — sem erros.

Pontos conferidos pelo revisor e considerados corretos, sem necessidade de ajuste: numeração de migration sem conflito (`054` livre), base de `vw_necessidade_compra` (migration 005) consistente com a última migration real conhecida, soma de impostos (líquido+ICMS+IPI+ST = custo total) consistente nos dois modais, vínculo de origem e geração de parcelas nunca bloqueiam a criação do pedido, tratamento de erro sem `catch` silencioso nas funções novas, RLS/GRANT das demais tabelas novas consistentes com o domínio, nenhum nome de coluna/tabela/RPC inventado. Nenhuma migration foi aplicada no Supabase real nem houve commit em nenhum dos dois repositórios até este ponto.
