---
titulo: "SPEC-040 — Necessidade de Compra: Granularidade por Item de Orçamento (L Fixo)"
status: implementado, aplicado e publicado em produção (Skip v0.0.46)
data_ultima_modificacao: 2026-07-21
sistemas_envolvidos:
  - Supabase (banco central) — toca também a RPC aprovar_orcamento_financeiro,
    que é do domínio Orçamentos/Financeiro (SPEC-016), não só Compras
  - compras-lucenera-3o23t98ee (Necessidade de Compra)
referencias:
  - SPEC-016 (aprovar_orcamento_financeiro — contrato oficial de aprovação financeira)
  - SPEC-010/012 (estoque_saldos_projeto_item, vw_necessidade_compra — saldo granular por projeto_item_id)
  - SPEC-022 (vw_necessidade_compra_detalhe — 1 linha por produto_id + projeto_item_id)
  - SPEC-038 Item 3 (pedido_compra_item_origem — vínculo informativo pedido_compra_itens ↔ projeto_itens)
  - SPEC-039 (layout full-screen, coluna Pendente, fix de busca — Fluxo A, não alterado por esta SPEC)
  - supabase/db/domains/estoque_compras.md (reunião 08/06/2026: necessidade de compra agregada por produto)
---

# SPEC-040 — Necessidade de Compra: Granularidade por Item de Orçamento (L Fixo)

> Pedido do usuário: poder comprar uma peça específica de uma posição
> específica ("L Fixo") de um orçamento específico, sem misturar com outras
> posições do mesmo produto em outros orçamentos — **sem remover** a visão
> agregada por produto que a SPEC-039 acabou de publicar em produção
> (Skip v0.0.45). Decisão do usuário nesta sessão: **as duas visões devem
> coexistir** — Fluxo A (agregado por produto, existente) e Fluxo B (por
> `[orçamento + produto + L Fixo]`, novo).
>
> Esta SPEC não implementa nada. Ela mapeia o estado real do banco (incluindo
> um achado técnico crítico que destrava a viabilidade do Fluxo B) e deixa
> como perguntas abertas (P-01 a P-06) as decisões de produto/negócio que
> precisam da confirmação do usuário antes de qualquer migration ou código.

## Checklist de Ação

### Backend

- [x] **Decisão do usuário necessária antes de escrever qualquer migration desta SPEC** — ver P-01 a P-06 em "Pendências" (fechadas em 21/07/2026)
- [x] (Após decisão) `ALTER TABLE projeto_itens ADD COLUMN orcamento_item_id uuid REFERENCES orcamento_itens(id)` + `ADD COLUMN l_fixo text` — rascunhada em `001_projeto_itens_orcamento_item_id.sql`, não aplicada
- [x] (Após decisão) Recriar `aprovar_orcamento_financeiro` (SPEC-016) para gravar `orcamento_item_id`/`l_fixo` no `INSERT INTO projeto_itens` — **aplicada em 21/07/2026, `002_aprovar_orcamento_financeiro_l_fixo.sql`**. **Achado crítico do orquestrador antes de aplicar**: a versão originalmente rascunhada (baseada na migration `20260706_020` e em `db/current/03_functions.sql`) NÃO batia com a função real em produção — `pg_get_functiondef` confirmou que a função ao vivo não tem checagem de permissão (admin/gerente), não tem validação de `frete_tipo`, e não tem o passo de reserva automática em `estoque_itens` que `20260706_020`/`db/current` descrevem (ou seja, essa migration nunca foi de fato aplicada neste banco — mesmo padrão do bug da SPEC-038 com `pedidos_compra`). A função ao vivo também tinha `subtotal`/fallback `oi.custom_id` não capturados em nenhuma migration (hotfix direto no banco, nunca registrado). A migration `002` foi reescrita para copiar o corpo REAL (via `pg_get_functiondef`, confirmado byte a byte), preservando 100% do comportamento ao vivo, só acrescentando `orcamento_item_id`/`l_fixo`. Ver `supabase/db/domains/estoque_compras.md` para o achado completo, registrado como pendência separada (fora do escopo desta SPEC).
- [x] (Após decisão) Backfill best-effort de `orcamento_item_id` para os `projeto_itens` já existentes, só nos casos inequívocos — **aplicado em 21/07/2026**, `003_backfill_orcamento_item_id_best_effort.sql` (corrigido durante a aplicação: `MIN(uuid)` não existe neste Postgres, trocado por `(array_agg(...))[1]`). Resultado real: 9 de 11 `projeto_itens` existentes ganharam `orcamento_item_id`/`l_fixo`; 2 ficaram `NULL` (ambíguos, conforme P-05).
- [x] (Após P-01) Criar view irmã nova (`vw_necessidade_compra_item_orcamento`) com `orcamento_item_id` (implícito no filtro), `l_fixo`, `pendente_item` — **aplicada em 21/07/2026**, `004_vw_necessidade_compra_item_orcamento.sql`; `vw_necessidade_compra_detalhe` (SPEC-022) não foi tocada
- [x] (Após P-03) Tornar `vincular_origem_pedido_compra_item` (SPEC-038 Item 3) uma chamada obrigatória no fluxo de criação de compra do Fluxo B (permanece opcional no Fluxo A) — implementado em `ModalGerarCompraItemOrcamento.tsx`, sem try/catch silencioso; testado end-to-end com chamada RPC real
- [ ] Reextrair `supabase/db/current/` depois de aplicar — reforça pendência crônica já registrada em `supabase/db/domains/estoque_compras.md`, agora com um segundo achado crítico do mesmo tipo

### Frontend (`compras-lucenera-3o23t98ee`)

- [x] (Após P-01) Implementar a alternativa de UI escolhida para o Fluxo B — abas (`Tabs`/`TabsList`/`TabsContent`) em `NecessidadeCompra.tsx`, componente novo `NecessidadeCompraPorItemTab.tsx`
- [x] Coluna "L Fixo" visível no Fluxo B, associada ao orçamento de origem (coluna "Orçamento" ao lado)
- [x] Estado de seleção (checkbox) do Fluxo B vinculado a `projeto_item_id` (chave granular real), não a `produto_id`
- [x] Ação "Gerar Compra" do Fluxo B processa apenas as linhas marcadas, respeitando `[orçamento_id + produto_id + l_fixo]` (cada linha é sua própria posição, sem agregação por produto)
- [x] Vínculo com `pedido_compra_item_origem` obrigatório no fluxo de criação de compra por L Fixo (não "best effort" como hoje em `ModalRegistrarCompra.tsx`) — falha aparece como toast destrutivo detalhado por linha
- [x] Rodar `oxlint`/`oxfmt`/`vite build` após as alterações — todos passaram (ver "Realizado")
- [x] **Não alterar** `NecessidadeCompra.tsx` (Fluxo A), `ModalPedidoLote.tsx`, `criar_pedido_compra_lote`, `vw_necessidade_compra` — comportamento/JSX do Fluxo A preservado, só reindentado para dentro de `TabsContent`; `ModalPedidoLote.tsx`/`criar_pedido_compra_lote` (a função)/`vw_necessidade_compra` não foram tocados (a função `criar_pedido_compra_lote` é reutilizada, não modificada, pelo Fluxo B via `services/pedido-compra.ts`)

### Passos manuais do usuário

- [x] Decidir P-01 (alternativa de UI para os dois fluxos coexistirem) — Alternativa A (abas)
- [x] Decidir P-02 (comportamento ao selecionar linhas de fornecedores diferentes no Fluxo B) — bloquear
- [x] Decidir P-03 (vínculo de origem obrigatório no Fluxo B) — obrigatório
- [x] Decidir P-04 (itens de orçamento sem L Fixo/`custom_id` preenchido) — linha própria, "—" na coluna
- [x] Decidir P-05 (backfill histórico dos `projeto_itens` já existentes — o que fazer com os casos ambíguos) — deixar em branco, sem adivinhar
- [x] Decidir P-06 (comportamento do Fluxo B para uma linha sem `orcamento_item_id` preenchido) — cai no comportamento agregado (Fluxo A)
- [x] Rodar `pg_get_functiondef('public.aprovar_orcamento_financeiro'::regprocedure)` no Supabase real **antes** de aplicar a migration `002` — feito, e revelou o achado crítico documentado acima (a migration foi reescrita antes de aplicar, não só comparada)
- [x] Aplicar as migrations no Supabase real, em ordem (001 → 002 → 003 → 004) — todas aplicadas e commitadas em 21/07/2026
- [x] Testado end-to-end via chamadas reais (RPC + REST): backfill confirmado (9/11), view nova retornando dados corretos (JOINs/resolução de fornecedor validados), `criar_pedido_compra_de_necessidade` + `vincular_origem_pedido_compra_item` (P-03) testados com sucesso, `pedido_compra_item_origem` gravado corretamente, dados de teste limpos
- [x] Frontend sincronizado com Skip (projeto 40326), QA completo, publicado em produção — versão `0.0.46`
- [ ] Testar golden path no navegador manualmente (o orquestrador validou via API/RPC direta, não clicando na tela) — cenário do Orçamento A (produto X em L01 e L35) + Orçamento B (produto X em L04) gerando 3 linhas distintas e seletividade independente na aba "Por Item de Orçamento"
- [ ] Reextrair `supabase/db/current/` depois de aplicar

## Objetivo

Hoje a tela **Necessidade de Compra** (`compras-lucenera-3o23t98ee`) agrega o
déficit por `produto_id` — decisão da reunião 08/06/2026, reafirmada nas
SPECs 020/022/030/038/039. O usuário quer, **adicionalmente**, poder comprar
uma peça específica identificada por `[orçamento_id + produto_id + L Fixo]`
(posição/linha do orçamento de origem), sem que isso afete as demais
ocorrências do mesmo produto em outras posições ou outros orçamentos.

Exemplo de validação usado nesta SPEC: Orçamento A tem o produto X nas
posições L01 e L35; Orçamento B tem o mesmo produto X na posição L04 → o
Fluxo B deve exibir 3 linhas distintas e seletivas, mesmo que o Fluxo A
continue mostrando 1 única linha agregada para o produto X.

## Decisões aprovadas

- As duas visões coexistem: **Fluxo A** (agregado por produto, `vw_necessidade_compra`, `criar_pedido_compra_lote`, tudo publicado na SPEC-039) permanece **sem alteração nenhuma**. **Fluxo B** (por item de orçamento/L Fixo) é aditivo, novo.
- "L Fixo" = `orcamento_itens.custom_id` (coluna `text`, confirmada no schema real — `supabase/db/current/01_schema_full.sql`). Não existe hoje nenhuma coluna com esse nome literal em nenhuma tabela.
- Esta SPEC substitui, **apenas para o Fluxo B**, o entendimento de que "necessidade de compra nunca fica amarrada a orçamento/cliente" (reunião 08/06/2026) — decisão explícita do usuário, não invenção do planejador. O Fluxo A continua 100% fiel a essa regra.

## Análise de ecossistema

- **Depende de**: `orcamentos`, `orcamento_itens`, `projetos`, `projeto_itens`, `produtos` — diretamente. `usuarios` indiretamente (nenhuma mudança de permissão nesta SPEC). Não depende de `boletos`, `contatos` além do que já é usado hoje pelo domínio.
- **Sistemas afetados**: Estoque/Compras (`compras-lucenera-3o23t98ee`) é o único sistema com mudança de frontend. **Atenção**: o backend toca `aprovar_orcamento_financeiro`, que é a RPC central do domínio **Orçamentos/Financeiro** (SPEC-016) — não existe um sistema `orcamentos-lucenera` separado neste inventário até onde a investigação alcançou, mas qualquer sistema que dependa do formato/comportamento de `projeto_itens` (CRM, Financeiro) deve ser avisado antes de aplicar a migration, porque a função é compartilhada.
- **Dado duplicado vs. derivado por relacionamento**: `projeto_itens` já é uma tabela de **snapshot** (duplica `quantidade`, `preco_unitario`, `desconto`, `descricao` de `orcamento_itens` no momento da aprovação, em vez de fazer JOIN ao vivo) — este é o padrão já estabelecido, não uma escolha nova desta SPEC. Por isso, a proposta de gravar `l_fixo` como snapshot em `projeto_itens` (além da FK `orcamento_item_id`) é consistente com o padrão existente, não uma nova duplicação injustificada. A FK `orcamento_item_id` é o que garante rastreabilidade/derivação por relacionamento; o campo `l_fixo` snapshotado é só conveniência de leitura, igual às demais colunas da mesma tabela.
- **Migration antiga que contradiz o snapshot central**: **achado relevante** — `supabase/db/current/01_schema_full.sql` (pg_dump real) contém uma versão de `aprovar_orcamento_financeiro_base_spec001` com corpo completo antigo (status `'aprovado'` minúsculo, lógica de reserva item-a-item com `RETURNING`), enquanto a migration `20260706_020` (SPEC-016) e `03_functions.sql` mostram essa mesma função como um wrapper simples de 3 linhas que só chama `aprovar_orcamento_financeiro`. Isso é sinal de que `db/current` pode não refletir 100% o estado real do banco quanto a essa função específica (não afeta `aprovar_orcamento_financeiro` propriamente dita, cujo corpo bateu identicamente entre `01_schema_full.sql` e `03_functions.sql`/migration 20260706_020 — então a leitura usada nesta SPEC é confiável). Reforça a pendência crônica de reextração já registrada no domínio.
- **Exige atualizar `AI_DB_CONTEXT.md`**: `compras-lucenera-3o23t98ee` não tem hoje um arquivo `supabase/AI_DB_CONTEXT.md` (confirmado — não encontrado no submodule). Se esta SPEC for implementada, é o momento de criar um, dado o aumento de complexidade do domínio (2 fluxos, novas colunas/views). Fora isso, atualizar `supabase/db/domains/estoque_compras.md`.
- **Padrão de acesso a dados já usado pelo sistema**: `services/*.ts` com chamadas diretas `supabase.from(...)`/`supabase.rpc(...)`, sem camada de hooks/stores. Esta SPEC deve seguir o mesmo padrão para o Fluxo B (ex.: `services/necessidade-compra-por-item.ts` ou extensão de `necessidade-compra-detalhe.ts`).

## Definição da SPEC

### 1. Achado técnico central — viabilidade da FK `projeto_itens → orcamento_itens`

Investigação da RPC `aprovar_orcamento_financeiro` (confirmada idêntica em
`supabase/db/migrations/20260706_020_normalizacao_aprovacao_financeira_orcamento/001_normalizacao_aprovacao_financeira.sql`,
`supabase/db/current/03_functions.sql` e `supabase/db/current/01_schema_full.sql`
— as três fontes batem exatamente para esta função). O trecho relevante:

```sql
INSERT INTO public.projeto_itens (
  projeto_id, produto_id, descricao, quantidade,
  preco_unitario, desconto, validado, orcamento_id
)
SELECT
  v_orcamento.projeto_id,
  oi.produto_id,
  COALESCE(oi.descricao, p.nome, 'Item sem descrição'),
  COALESCE(oi.quantidade, 1),
  COALESCE(oi.preco_unitario, 0),
  COALESCE(oi.desconto, 0),
  true,
  p_orcamento_id
FROM public.orcamento_itens oi
LEFT JOIN public.produtos p ON p.id = oi.produto_id
WHERE oi.orcamento_id = p_orcamento_id;
```

**Conclusão: a FK é trivialmente viável, sem RETURNING/loop, sem mudança
estrutural na função.** Este é um `INSERT ... SELECT` **set-based direto de
`orcamento_itens`, sem `GROUP BY`** — 1 linha de `projeto_itens` é criada
para **cada** linha de `orcamento_itens`, na ordem em que já existem hoje.
Isso significa que `projeto_itens` **já é granular por item de orçamento**;
só falta a função gravar o vínculo (`oi.id`) e o valor de L Fixo (`oi.custom_id`)
que já estão disponíveis no mesmo `SELECT`. A mudança é apenas:

```sql
INSERT INTO public.projeto_itens (
  projeto_id, produto_id, descricao, quantidade,
  preco_unitario, desconto, validado, orcamento_id,
  orcamento_item_id, l_fixo                              -- NOVO
)
SELECT
  v_orcamento.projeto_id, oi.produto_id,
  COALESCE(oi.descricao, p.nome, 'Item sem descrição'),
  COALESCE(oi.quantidade, 1), COALESCE(oi.preco_unitario, 0),
  COALESCE(oi.desconto, 0), true, p_orcamento_id,
  oi.id, oi.custom_id                                     -- NOVO
FROM public.orcamento_itens oi
LEFT JOIN public.produtos p ON p.id = oi.produto_id
WHERE oi.orcamento_id = p_orcamento_id;
```

Pré-requisito: `ALTER TABLE public.projeto_itens ADD COLUMN orcamento_item_id uuid REFERENCES public.orcamento_itens(id), ADD COLUMN l_fixo text;`

Onde a granularidade **é** perdida hoje: não em `projeto_itens`, e sim em
`estoque_itens` — a mesma função faz, logo depois, um `UPSERT` **agregado por
`produto_id`** (`GROUP BY oi.produto_id ... ON CONFLICT ... quantidade_reservada + EXCLUDED`),
que é a fonte de `vw_necessidade_compra` (Fluxo A). `estoque_saldos_projeto_item`
(SPEC-010), por outro lado, **já é gravada por `projeto_item_id`** (1:1
com `projeto_itens.id`, portanto 1:1 com `orcamento_itens.id` uma vez que a
FK acima existir) — é essa tabela que dá a base granular para o Fluxo B.

**Backfill histórico (75 `projeto_itens` já existentes)**: só é seguro
automatizar quando o par `(orcamento_id, produto_id)` aparece **exatamente
uma vez** em `orcamento_itens` para aquele orçamento (sem ambiguidade
possível). Quando o mesmo produto aparece em 2+ posições do mesmo orçamento
(exatamente o caso do exemplo do usuário — L01 e L35), **não há como saber
retroativamente**, com os dados disponíveis hoje, qual `projeto_item`
corresponde a qual `orcamento_item` — a única saída correta é registrar
`orcamento_item_id = NULL` nesses casos, marcá-los num relatório de
conferência e **não adivinhar**. Isso é decisão de negócio (ver P-05).

### 2. Alternativas de UI para os dois fluxos coexistirem

Cenário de validação (usado nas 3 alternativas): Orçamento A com produto X
em L01 e L35, Orçamento B com produto X em L04 → em qualquer alternativa, o
usuário precisa ver 3 linhas distintas e marcar/comprar apenas L35 do
Orçamento A sem afetar as outras duas.

**Alternativa A — Toggle/abas na mesma tela** (`/necessidade-compra`)

Duas abas "Por Produto" (Fluxo A, default, como está hoje) / "Por Item de
Orçamento" (Fluxo B, novo). Reaproveita o mesmo shell full-screen da
SPEC-039 (busca, layout), troca só o grid e o estado de seleção conforme a
aba ativa. Menor fragmentação de rota, descoberta mais fácil pelo usuário
(está tudo no mesmo lugar).

**Alternativa B — Rota separada** (ex.: `/necessidade-compra-por-item`)

Página nova, componente novo, sem tocar em `NecessidadeCompra.tsx`. Isolamento
total de risco em relação ao Fluxo A recém-publicado (SPEC-039); exige um
ponto de navegação novo (link/botão) e replica parte do layout/filtros já
existentes.

**Alternativa C — Expansão inline no painel já existente**

`NecessidadeCompraDetalhe.tsx` (painel expansível da SPEC-022, que já
mostra **1 linha por `projeto_item_id`** por produto) ganha checkbox próprio
por linha + um botão "Comprar este item" por linha expandida. Sem tela nova,
reaproveita a view `vw_necessidade_compra_detalhe` (só precisa ganhar as
colunas `orcamento_item_id`/`l_fixo`/`pendente_item`). É a alternativa mais
barata de implementar porque `ModalRegistrarCompra.tsx` **já tem** um
mecanismo de seleção de "origens" (`projeto_item_id`) via checkbox — hoje
usado só como vínculo informativo opcional; o Fluxo B tornaria esse mesmo
mecanismo o caminho principal e obrigatório de compra por item.

Nenhuma das três é tecnicamente inviável; a escolha é de produto/UX — ver
P-01.

### 3. Itens de orçamento sem L Fixo (`custom_id IS NULL`)

Confirmado anteriormente nesta sessão: 63 de 75 linhas de `orcamento_itens`
têm `custom_id` preenchido; 12 ficam `NULL`.

**Proposta técnica (não é decisão de negócio em si, mas precisa confirmação — P-04)**:
como a chave real de granularidade do Fluxo B passa a ser `orcamento_item_id`
(mais forte que a combinação textual `[orçamento + produto + L Fixo]` citada
pelo usuário, porque é imune a duplicidade de texto), um item sem `custom_id`
simplesmente aparece como sua própria linha no Fluxo B, com a coluna "L Fixo"
mostrando "—" — não desaparece da lista, não é agrupado com outros itens sem
L Fixo do mesmo produto. **Ressalva de UX**: se dois itens do mesmo produto,
no mesmo orçamento, estiverem **ambos** sem `custom_id`, eles aparecerão como
duas linhas visualmente idênticas na coluna L Fixo (ambas "—") — o usuário
só consegue diferenciá-las por quantidade/preço/descrição, se esses campos
forem diferentes. Isso é um lembrete de design para o implementador, não uma
pergunta bloqueante.

### 4. Conexão com as RPCs existentes de compra

- **Seleção**: `Set<string>` de `projeto_item_id` (não `produto_id`) — é o
  identificador único real de "uma peça numa posição de um orçamento",
  porque `projeto_itens` é 1:1 com `orcamento_itens` desde a aprovação.
- **Deficit por linha**: já existe pronto em `estoque_saldos_projeto_item.q_entrega_futura`
  (granular por `projeto_item_id`, SPEC-010) — não precisa inventar nova
  lógica de rateio de estoque físico entre L Fixos do mesmo produto.
- **"Pendente" por linha** (paralelo ao `pendente` do Fluxo A, SPEC-039 P-04):
  requer descontar do `q_entrega_futura` da linha o que já foi coberto por
  pedidos de compra em aberto **especificamente vinculados àquele
  `projeto_item_id`** via `pedido_compra_item_origem.quantidade_atendida`
  (SPEC-038 Item 3). Isso só funciona de forma confiável se o vínculo de
  origem deixar de ser opcional no Fluxo B — ver P-03.
- **Geração da compra**: reaproveita `criar_pedido_compra_de_necessidade`
  (compra individual, já existe) passando `p_quantidade` = a quantidade
  pendente **daquela linha específica** (não o `necessidade_compra` agregado
  do produto inteiro), seguida de `vincular_origem_pedido_compra_item(pedido_compra_item_id, projeto_item_id, quantidade_atendida)`.
  Para seleção múltipla de linhas de fornecedores diferentes, ver P-02.
- **Rascunho conceitual de view** (não aplicar sem confirmar contra o banco real):

```sql
-- Estende vw_necessidade_compra_detalhe (SPEC-022) com orcamento_item_id/l_fixo
-- e um "pendente_item" análogo ao P-04 da SPEC-039, mas por projeto_item_id.
WITH cobertura_pedidos AS (
    SELECT pcio.projeto_item_id,
           SUM(pcio.quantidade_atendida) AS qtd_coberta_por_pedido_aberto
    FROM public.pedido_compra_item_origem pcio
    JOIN public.pedido_compra_itens pci ON pci.id = pcio.pedido_compra_item_id
    JOIN public.pedidos_compra pc ON pc.id = pci.pedido_id
    WHERE pc.status NOT IN ('recebido', 'cancelado')
      AND pcio.quantidade_atendida IS NOT NULL
    GROUP BY pcio.projeto_item_id
)
SELECT
    ..., -- colunas já existentes na vw_necessidade_compra_detalhe
    pi.orcamento_item_id,
    oi.custom_id AS l_fixo,
    GREATEST(0, esp.q_entrega_futura - COALESCE(cob.qtd_coberta_por_pedido_aberto, 0)) AS pendente_item
FROM ...
LEFT JOIN public.orcamento_itens oi ON oi.id = pi.orcamento_item_id
LEFT JOIN cobertura_pedidos cob ON cob.projeto_item_id = pi.id
```

### 5. O que esta SPEC não altera (garantia explícita)

`vw_necessidade_compra`, `estoque_itens`, `criar_pedido_compra_lote`,
`ModalPedidoLote.tsx`, `NecessidadeCompra.tsx` (grid do Fluxo A, colunas
Fornecedor/Empresa/Status/Data prevista da SPEC-039) permanecem exatamente
como estão. Todas as mudanças de banco propostas são aditivas (colunas
novas nullable em `projeto_itens`, colunas novas em view via `CREATE OR
REPLACE VIEW` sem remover/reordenar as existentes).

## Migrations propostas (rascunho — bloqueadas por decisão do usuário)

Pasta sugerida: `supabase/db/migrations/20260723_057_spec040_necessidade_compra_l_fixo/`

- `001_projeto_itens_orcamento_item_id.sql` — `ALTER TABLE projeto_itens ADD COLUMN orcamento_item_id uuid REFERENCES orcamento_itens(id), ADD COLUMN l_fixo text` + índice. **Não bloqueada por P-01/P-02**, só precisa confirmação geral de seguir em frente com a SPEC.
- `002_aprovar_orcamento_financeiro_l_fixo.sql` — `CREATE OR REPLACE FUNCTION aprovar_orcamento_financeiro` incluindo `oi.id`/`oi.custom_id` no INSERT. **Rodar `pg_get_functiondef` antes de aplicar** (achado de possível drift em `db/current`, seção "Análise de ecossistema").
- `003_backfill_orcamento_item_id_best_effort.sql` — backfill só dos casos inequívocos (1 correspondência possível por `orcamento_id + produto_id`); gera relatório dos casos deixados `NULL`. **Bloqueada por P-05.**
- `004_vw_necessidade_compra_detalhe_l_fixo.sql` (ou view irmã nova, conforme P-01) — colunas `orcamento_item_id`, `l_fixo`, `pendente_item`. **Bloqueada por P-01, P-03, P-04.**
- Frontend — implementação da alternativa de UI escolhida (P-01), sem migration adicional além das acima.

## Realizado

**23/07/2026 — implementação completa, migrations rascunhadas (não aplicadas), frontend testado via lint/build.**

Backend (migrations em `supabase/db/migrations/20260723_057_spec040_necessidade_compra_l_fixo/`, rascunhadas, **não aplicadas no Supabase real**):

- `001_projeto_itens_orcamento_item_id.sql` — `projeto_itens.orcamento_item_id`/`l_fixo` (colunas nullable + índice).
- `002_aprovar_orcamento_financeiro_l_fixo.sql` — recria `aprovar_orcamento_financeiro` (domínio Orçamentos/Financeiro, SPEC-016) para gravar as duas colunas novas no `INSERT INTO projeto_itens`. Corpo completo copiado da migration `20260706_020` e conferido, linha a linha, contra `supabase/db/current/03_functions.sql` antes de reescrever — as duas fontes bateram identicamente, sem divergência (a única mudança real está isolada no `INSERT`). A conferência via `pg_get_functiondef` contra o Supabase real (recomendada pela SPEC) continua sendo passo manual do usuário antes de aplicar, por precaução.
- `003_backfill_orcamento_item_id_best_effort.sql` — backfill idempotente, só dos pares `(orcamento_id, produto_id)` inequívocos.
- `004_vw_necessidade_compra_item_orcamento.sql` — view nova, não altera `vw_necessidade_compra`/`vw_necessidade_compra_detalhe`.
- README.md da pasta com aviso destacado sobre a migration `002` tocar um domínio diferente de Compras.
- `supabase/db/domains/estoque_compras.md` atualizado com o resumo da SPEC-040.

Frontend (`compras-lucenera-3o23t98ee`):

- `src/services/necessidade-compra-item.ts` — `getNecessidadeCompraPorItem()`, mesmo padrão de paginação em lote e a mesma correção de busca (`.eq` para código numérico, `.ilike` para o resto) da SPEC-039.
- `src/components/compra/NecessidadeCompraPorItemTab.tsx` — grid da aba "Por Item de Orçamento": Orçamento, L Fixo, Código, Produto, Fornecedor, Pendente, checkbox por `projeto_item_id`, trava de fornecedor único (P-02).
- `src/components/compra/ModalGerarCompraItemOrcamento.tsx` — gera o pedido via `criar_pedido_compra_lote` (reutilizada sem alteração) e chama `vincular_origem_pedido_compra_item` para CADA linha, mapeado por índice (não por `produto_id`, que pode se repetir entre linhas com L Fixos diferentes); falha de vínculo vira toast destrutivo detalhado por linha, nunca é engolida silenciosamente (P-03).
- `src/pages/NecessidadeCompra.tsx` — abas "Por Produto"/"Por Item de Orçamento" via `Tabs`/`TabsList`/`TabsContent` (`@/components/ui/tabs`, já existente no projeto). Todo o JSX/estado/lógica do Fluxo A foi preservado — só reindentado para dentro de `TabsContent value="produto"`, sem mudança de comportamento.
- `oxfmt`, `oxlint` e `vite build` executados com sucesso (únicos avisos de lint são pré-existentes em `Cotacoes.tsx`, não relacionados a esta SPEC).

Pendente (passo manual do usuário, ver checklist acima): conferir `aprovar_orcamento_financeiro` contra o Supabase real, aplicar as 4 migrations em ordem, testar o golden path no navegador (cenário L01/L35/L04), reextrair `supabase/db/current/`.

Antes desta implementação, a SPEC era 100% planejamento (decisões P-01 a
P-06 fechadas pelo usuário em 21/07/2026, ver seção abaixo).

## Decisões do usuário (21/07/2026)

- **P-01 — UI dos dois fluxos**: **Alternativa A**. Duas abas em `/necessidade-compra`: "Por Produto" (Fluxo A, default, inalterado) e "Por Item de Orçamento" (Fluxo B, novo).
- **P-02 — Multi-fornecedor no Fluxo B**: **Bloquear**. Mesma trava já usada em `toggleSelect` do Fluxo A — todas as linhas marcadas precisam resolver para o mesmo `fornecedor_id` antes de habilitar "Gerar Compra".
- **P-03 — Vínculo de origem no Fluxo B**: **Obrigatório**. Toda compra gerada pelo Fluxo B chama `vincular_origem_pedido_compra_item` automaticamente (não é mais melhor-esforço/silencioso como no Fluxo A). O Fluxo A continua com o vínculo opcional, sem mudança.
- **P-04 — Itens sem L Fixo**: **Linha própria, "—" na coluna**. Não exclui da lista, não agrupa com outros itens sem L Fixo do mesmo produto.
- **P-05 — Backfill ambíguo**: **Deixar em branco, sem adivinhar**. Preenche automaticamente só os casos inequívocos (produto aparece uma única vez no orçamento); casos ambíguos ficam com `orcamento_item_id`/`l_fixo` `NULL` permanentemente, sem geração de planilha de conferência (não pedida).
- **P-06 — Linha sem vínculo no Fluxo B**: **Cai no comportamento agregado**. Uma linha sem `orcamento_item_id` (legado ou ambígua) simplesmente não aparece na aba "Por Item de Orçamento" — continua coberta normalmente pela aba "Por Produto", sem bloqueio nem aviso especial.

## Pendências

- [x] P-01 a P-06 decididas (ver acima)
- [ ] Reextrair `supabase/db/current/` — pendência crônica do domínio, reforçada pelo achado desta SPEC sobre `aprovar_orcamento_financeiro_base_spec001` (função legada com corpo divergente entre `db/current` e o que a migration SPEC-016 deveria ter deixado).
