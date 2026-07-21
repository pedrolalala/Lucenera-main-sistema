# Domínio: Estoque e Compras

## Papel no ecossistema

Estoque/Compras deve ser um sistema próprio.

Ele trata movimentações operacionais de produtos, compras, estoque e relação com clientes/projetos.

## Decisão atual

Vendas aprovadas pertencem ao domínio de Orçamentos/Projetos.

O restante das entradas da Connect ligadas a clientes deve ser tratado como movimentação de estoque/operação, não como orçamento aprovado.

A reunião 08 de 06/07/2026 consolidou:

- "estoque de cliente" e "itens reservados" são o mesmo conceito de tela/operação;
- estoque disponível = estoque físico total - estoque reservado;
- entrega futura é compromisso ativo sem cobertura física;
- necessidade de compra é agregada por produto e não deve ficar amarrada a cliente;
- transferência entre clientes deve registrar operação, origem, destino, solicitante e aprovador.

## Relação com Cadastros

O sistema pode mostrar dados cadastrais, mas seu foco é operacional:

- produto em estoque;
- produto comprado;
- produto reservado;
- produto entregue;
- movimentação por cliente/projeto;
- necessidade de compra/reposição;
- disparos futuros para financeiro quando houver fluxo de compra.

## Automações atuais

Automatizações identificadas no Supabase real relacionadas a Produtos/Estoque/Compras:

- `public.fn_atualizar_preco_venda()`: atualiza preço de venda de produto.
- `public.generate_product_slug(nome text, preco numeric)`: gera slug de produto.
- `public.get_next_sku(prefix text)`: gera próximo SKU por prefixo.
- `public.trigger_reserva_estoque()`: automação atual de reserva de estoque ligada ao projeto.
- `public.trigger_update_revenda_ubiqua_slug()`: atualiza slug de revenda Ubiqua.
- `public.update_revenda_ubiqua_ordem(payload jsonb)`: atualiza ordem da revenda Ubiqua.
- `public.update_revenda_ubiqua_updated_at()`: atualiza timestamp da revenda Ubiqua.

Triggers relacionadas:

- `public.produtos.produtos_updated_at`
- `public.produtos.trg_atualizar_preco_venda`
- `public.produtos.trg_calculo_preco_venda`
- `public.produtos.update_produtos_updated_at`
- `public.projetos.trg_reserva_estoque`
- `public.revenda_ubiqua.trg_revenda_ubiqua_slug`
- `public.revenda_ubiqua.trigger_revenda_ubiqua_updated_at`

Edge Functions relacionadas:

- Não há Edge Function central ativa específica de Estoque/Compras no inventário atual.
- Funções da Logística backup que lidam com materiais devem ser analisadas quando o novo sistema de Estoque/Compras/Logística for especificado.

Objetos aplicados / pendentes:

- `estoque_saldos_projeto_item` e `estoque_movimentos_projeto_item`: SPEC-010 aplicada no Supabase real em 07/07/2026. A migration corretiva `20260707_023_spec010_hardening` ficou escrita para fechar a exposição das views, reconciliar o agregado `estoque_itens.quantidade_reservada` e endurecer a entrega de itens com `q_entrega_futura`.
- `transferencias_estoque`, `devolucoes_estoque`, `vw_entrega_futura_projeto_item` e `vw_necessidade_compra` ainda não existem; estão desenhados nas SPECs 011/012/015 e dependem do hardening/RLS da SPEC-010 antes de expor a operação.
- SPEC-020/021 (10/07/2026): `produto_fornecedores`, `solicitacoes_compra`, `cotacoes_compra`, `cotacao_itens`, `pedidos_compra`, `pedido_compra_itens`, `recebimentos_compra` e a RPC `criar_pedido_compra_de_necessidade` — fluxo operacional de compra (Necessidade de Compra → Registrar Compra → Recebimento). `solicitacoes_compra`/`pedido_compra_itens` não têm `projeto_id`/`orcamento_id` — compra é agregada por produto, não por cliente (decisão reunião 08/06/2026).
- SPEC-030 (16/07/2026): `marcas.fornecedor_id`, `vw_necessidade_compra` com `marca_id`/`marca_nome`/`fornecedor_id`/`fornecedor_nome` (resolução em cascata `COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)`), RPC `criar_pedido_compra_lote` (1 pedido = 1 fornecedor, N produtos), RPC `buscar_fornecedores_fuzzy`.
- SPEC-034 (18/07/2026): backfill de `marcas.fornecedor_id` para ~61 marcas + fluxo de sugestão automática de fornecedor por marca.
- SPEC-036 (18/07/2026): `produtos.preco_custo` editável via `atualizar_preco_custo_produto` (tela Cotações do sistema `compras-lucenera-3o23t98ee` — não confundir com o catálogo Ubiqua isolado, que tem seu próprio domínio de marca/fornecedor/cliente).
- **Achado crítico (21/07/2026)**: a tabela `pedidos_compra` — redigida em `20260710_031_spec020_operacionalizacao_compras/004_pedidos_compra.sql` — nunca havia sido aplicada no Supabase real, apesar de as RPCs de "Registrar Compra" dependerem dela desde 10/07/2026. `CREATE FUNCTION` não valida tabelas referenciadas, então o problema passou despercebido por 11 dias e por várias SPECs (021/022/030/033/034/035). Corrigido e testado end-to-end em 21/07/2026 via migration `20260721_055_fix_pedidos_compra_base` (aplicação retroativa de `004_pedidos_compra.sql` + FK `pedido_compra_itens.pedido_id → pedidos_compra.id` + `DROP NOT NULL` em `solicitacoes_compra.projeto_id`/`quantidade_pedida`, que também bloqueavam as RPCs).
- SPEC-038 (21/07/2026, migration `20260721_054_spec038_compras_melhorias`, **aplicada e testada no Supabase real em 21/07/2026**):
  - Item 1 — `pedido_compra_itens.custo_liquido`/`valor_icms`/`valor_ipi`/`valor_st` (snapshot de imposto por compra, efetivo/editável; não sincroniza com `produtos.icms_entrada`/`ipi_entrada`/`porc_st`). `criar_pedido_compra_de_necessidade`/`criar_pedido_compra_lote` recriadas com parâmetros novos (opcionais, no final) para gravar esse breakdown.
  - Item 2 — numeração automática: trigger `set_pedido_compra_numero()`/`trigger_set_pedido_compra_numero` (formato `PC-<ano>-NNNN`, mesmo padrão de `set_orcamento_numero()`), `UNIQUE` em `pedidos_compra.numero`, `p_numero` agora opcional nas duas RPCs de criação de pedido.
  - Item 3 — `pedido_compra_item_origem` (vínculo informativo N:N entre `pedido_compra_itens` e `projeto_itens`, nullable/opcional — não contradiz a decisão da reunião 08) + `vw_pedido_compra_item_origem` + RPC `vincular_origem_pedido_compra_item` (escrita exclusivamente via RPC, sem policy de INSERT aberta).
  - Item 4 — `pedido_compra_parcelas` (parcelas do lado **pagável**, Lucenera → fornecedor; tabela própria, não reaproveita `projeto_parcelas`/`boletos` que são exclusivos do lado recebível) + RPCs `gerar_parcelas_pedido_compra` (usa `_lucenera_parse_prazo_pagamento()`) e `atualizar_parcela_pedido_compra` (edição manual de valor/vencimento por parcela — decisão explícita do usuário, parcela não fica travada na divisão automática igual). `pedidos_compra.prazo_pagamento_dias` (mesmo padrão de `orcamentos.prazo_pagamento_dias`).
  - Item 5 — `produtos.percentual_desconto_compra` (coluna dedicada, isolada de `produtos.porc_desconto` — não dispara `fn_atualizar_preco_venda()`) + RPC `atualizar_desconto_compra_produto`, exposta em `vw_necessidade_compra`.
  - Frontend: nova página `PedidosCompra.tsx` (rota `/pedidos`, antes placeholder "Em breve") lista pedidos e permite gerar/editar parcelas via `PedidoParcelasPanel.tsx`. Publicado em produção (Skip, projeto 40326, versão 0.0.44).
- SPEC-039 (22/07/2026, migration `20260722_056_spec039_necessidade_compra_grid`, **rascunhada, não aplicada** — aplicação é passo manual do usuário):
  - `pedidos_compra.empresa_id uuid REFERENCES empresas(id)`, preenchida automaticamente por `criar_pedido_compra_de_necessidade`/`criar_pedido_compra_lote` a partir de `usuarios.empresa_id` do usuário autenticado (P-03) — sem input manual no frontend.
  - Views novas `vw_necessidade_compra_pedidos_abertos` (1 linha por produto: `qtd_pedidos_abertos`, `qtd_em_pedidos_abertos`, `proxima_data_prevista_entrega`, `status_mais_critico`) e `vw_necessidade_compra_pedido_detalhe` (1 linha por `pedidos_compra` em aberto: `numero`, `status` cru, `empresa_nome`, `data_prevista_entrega`) — "pedido em aberto" = `pedidos_compra.status NOT IN ('recebido', 'cancelado')`. Granularidade de `vw_necessidade_compra` continua 1 linha por produto (P-01) — reafirma a decisão da reunião 08/06/2026, não a contradiz.
  - `vw_necessidade_compra` recriada com `pendente` (= `GREATEST(0, necessidade_compra - qtd_em_pedidos_abertos)`), `qtd_pedidos_abertos`, `proxima_data_prevista_entrega`, `status_mais_critico`. **Decisão de produto P-04 (21/07/2026)**: o `WHERE` que decide quais produtos aparecem na lista mudou de `qtd_reservada > qtd_estoque` para `pendente > 0` — um produto sai da lista quando o déficit já está 100% coberto por pedido de compra em aberto, mesmo antes do recebimento efetivo (rastreabilidade completa continua disponível via `vw_necessidade_compra_pedidos_abertos`/`vw_necessidade_compra_pedido_detalhe`, que não filtram por `pendente`). A coluna `necessidade_compra` (déficit bruto) continua exibida.
  - Frontend (`compras-lucenera-3o23t98ee`): bug de busca corrigido em `services/necessidade-compra.ts` (`produto_codigo` é `integer` — `ilike` não existe para esse tipo, `.or()` derrubava toda busca não vazia; corrigido para comparação exata `.eq()` quando o termo é numérico). Grid de Necessidade de Compra ganhou colunas Fornecedor/Empresa que comprou/Status do pedido/Data prevista de entrega e virou full-screen (sem `hidden md/lg/xl:table-cell`, scroll horizontal). Vocabulário de status (P-02): `rascunho`→"Pendente", `aprovado`→"Aprovado", `enviado`→"Pedido Emitido", `parcialmente_recebido`→"Em Trânsito", `recebido`→"Recebido", `cancelado`→"Cancelado" (dicionário `STATUS_PEDIDO_COMPRA_LABEL` em `services/necessidade-compra.ts`).

## Ação a ser realizada

Aplicar a migration `20260707_023_spec010_hardening` no Supabase real, depois reextrair `supabase/db/current/` e definir a policy de RLS antes de avançar transferência, entrega futura detalhada, devolução automatizada e badges ricos no CRM. No banco, separar claramente tabelas cadastrais de tabelas operacionais de movimentação. O saldo vivo usa `projeto_item_id`; cliente/projeto/orçamento/produto vêm por relacionamento (ver `vw_estoque_saldos_projeto_item`). `estoque_itens.quantidade_reservada` deve permanecer como agregado de compatibilidade dos saldos abertos por produto.

**Reextrair `supabase/db/current/` para todo o domínio de Compras** — pendência crônica desde 07/07/2026, agora mais urgente: foi o que escondeu a tabela `pedidos_compra` inteira estar ausente do banco real por 11 dias (ver achado crítico acima). Sem essa reextração, novas SPECs continuam correndo o risco de assumir "backend pronto" com base em migrations apenas redigidas, não aplicadas.
