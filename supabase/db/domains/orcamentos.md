# Domínio: Orçamentos

## Papel no ecossistema

Orçamentos representam a proposta comercial antes de virar execução operacional.

Somente orçamento aprovado deve gerar itens em `projeto_itens`.

## Decisão atual

Ao aprovar um orçamento:

1. O sistema usa `orcamento_id` como chave principal de rastreio.
2. Os itens aprovados são levados para `projeto_itens`.
3. As parcelas são criadas em `projeto_parcelas` com `orcamento_id`.
4. Boletos são criados/disponibilizados na Administração Bancária com `boletos.orcamento_id`.
5. O financeiro exibe orçamento, projeto e cliente derivados do `orcamento_id`.

Não usar `venda_id` nesse fluxo.

Antes da aprovação, o orçamento precisa ter:

- projeto vinculado;
- itens válidos;
- prazo de cobrança interpretável (`prazo_inicio_cobranca_dias` e/ou `prazo_pagamento_dias`);
- frete estruturado (`frete_tipo = com_frete | sem_frete` e `frete_valor` coerente);
- forma de pagamento e quantidade de parcelas compatíveis com a RPC.
- aprovação do cliente concluída e orçamento em `Aprovação Financeira` conforme contrato consolidado na SPEC-016.

## Aprovação do cliente e aprovação financeira

O banco real de 06/07/2026 já contém colunas e RPCs de aprovação do cliente e a normalização da SPEC-016 foi aplicada para consolidar o contrato oficial:

- `enviar_orcamento_para_cliente`, `cliente_aprovar_orcamento`, `cliente_recusar_orcamento`, `adm_aprovar_pelo_cliente`, com status `enviado_cliente`, `aprovado_cliente`, `recusado_cliente`.
- `aprovar_orcamento_cliente`, `aprovar_orcamento_cliente_manual`, `aprovar_orcamento_cliente_publico`, `handle_orcamento_workflow`, com transição para `Aprovação Financeira`.

O banco real possui registros em `Orçamento Aprovado`, `enviado_cliente` e `Aprovação Financeira`.

A SPEC-016 decidiu o contrato oficial: `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado`. A aprovação do cliente apenas coloca o orçamento na fila financeira; geração de `projeto_itens`, `projeto_parcelas`, boletos, nota fiscal manual e reserva só pode ocorrer quando o financeiro aprovar por `orcamento_id`.

A SPEC-017 foi implementada na UI de Orçamentos em 06/07/2026: a aba financeira lista orçamentos em `Aprovação Financeira`, usa a tela padrão de edição de orçamento e chama a RPC por `orcamento_id`. `aprovado_cliente`, `aprovado` e `aprovado_financeiro` devem seguir tratados como legados/compatibilidade.

## Relação com planilhas da Connect

A planilha de vendas aprovada da Connect serve como histórico para identificar:

- orçamento aprovado;
- projeto relacionado pelo código antes do nome do cliente;
- itens aprovados;
- histórico comercial.

As demais movimentações com cliente devem ser tratadas como estoque/operação, não como venda aprovada.

## Automações atuais

Automatizações identificadas no Supabase real relacionadas a Orçamentos/Projetos:

- `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)`: RPC principal do fluxo `Aprovação Financeira -> Orçamento Aprovado`; aceita somente orçamento em fila financeira no caminho normal.
- `public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id uuid)`: wrapper de compatibilidade para a RPC oficial da SPEC-016.
- `public.enviar_orcamento_para_cliente(p_orcamento_id uuid)`: envia orçamento ao cliente e gera token.
- `public.cliente_aprovar_orcamento(p_orcamento_id uuid, p_token text)`: aprova via token conforme SPEC-009.
- `public.cliente_recusar_orcamento(p_orcamento_id uuid, p_token text, p_motivo text)`: recusa via token conforme SPEC-009.
- `public.adm_aprovar_pelo_cliente(p_orcamento_id uuid, p_observacao text)`: registra aprovação manual.
- `public.aprovar_orcamento_cliente*`: família alternativa real mantida compatível com a transição para `Aprovação Financeira`.
- `public._lucenera_parse_prazo_pagamento(...)`: interpreta prazos de pagamento para cálculo de parcelas/vencimentos.
- `public.fn_gerar_numero_orcamento()` e `public.set_orcamento_numero()`: geração/atribuição de número de orçamento.
- `public.fn_update_orcamento_timestamp()`: atualização de timestamp do orçamento.
- `public.sync_projeto_valor_total()`: sincroniza `projetos.valor_total` a partir de `projeto_itens.subtotal`.
- `public.gerenciar_fluxo_projeto()`: automação atual de fluxo/status de projeto.
- `public.trigger_fechar_projeto()` e `public.trigger_proteger_fechamento()`: automações de fechamento/proteção de projeto.
- `public.trigger_proteger_parcelas()`: proteção de parcelas legadas; desde a SPEC-005 libera inserções com `orcamento_id IS NOT NULL`.

Triggers relacionadas:

- `public.orcamentos.trigger_set_orcamento_numero`
- `public.orcamentos.trg_normalize_orcamento_status`
- `public.orcamentos.trg_orcamento_workflow`
- `public.orcamentos_revenda_ubiqua.trigger_auto_numero_orcamento`
- `public.orcamentos_revenda_ubiqua.trigger_orcamento_updated_at`
- `public.projeto_itens.trg_sync_valor_total`
- `public.projeto_parcelas.trg_proteger_parcelas`
- `public.projetos.trg_fechar_projeto`
- `public.projetos.trg_gerenciar_fluxo_projeto`
- `public.projetos.trg_proteger_fechamento`

Edge Functions relacionadas:

- `parse-budget-pdf`: leitura/processamento inicial de PDF de orçamento.
- `process-budget-pdf`: processamento/geração/envio relacionado a PDF de orçamento.
- `enviar-confirmacao-email`: confirmação por e-mail de orçamento, ainda simples e pendente de revisão.
- `salvar-projeto` e `update-project`: criação/atualização de projeto por Edge Function.

Observações:

- `public.fn_aprovar_orcamento()` e `public.orcamentos.trg_aprovar_orcamento` foram removidos pela SPEC-005 porque criavam projeto a partir de orçamento em um modelo antigo e bloqueavam a RPC nova.
- `process-billing-automation` ainda aparece no remoto como Edge Function legada, mas não deve ser usada nem evoluída; o fluxo novo deve usar a RPC `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)`.
- `historico_status_orcamentos` é a tabela de auditoria do fluxo Lucenera; `historico_status_orcamento` permanece ligado à família Ubiqua/revenda.

## Achado crítico e hotfix (22/07/2026)

`aprovar_orcamento_financeiro` esteve **quebrada em produção para toda aprovação nova desde algum momento após 06/07/2026** (nenhum `projeto_itens` no banco tem `created_at` posterior a essa data). Causa: `projeto_itens.subtotal` virou coluna `GENERATED ALWAYS` na migration `20260626_009_spec005_remocao_triggers_legados_aprovacao/002_fix_subtotal_coluna_gerada.sql`, que corrigiu o `INSERT` — mas na função **errada** (`aprovar_orcamento_financeiro_base_spec001`, a variante legada/wrapper, não a função oficial que o sistema realmente chama). A função oficial nunca foi corrigida naquele momento; um hotfix não documentado (nenhuma migration deste repositório o captura) aplicado depois de 06/07/2026 reintroduziu o `INSERT` explícito em `subtotal` na função oficial, quebrando toda aprovação nova com `cannot insert a non-DEFAULT value into column "subtotal"` (Postgres `428C9`).

Descoberto durante a SPEC-040 (Necessidade de Compra — granularidade por L Fixo), ao investigar por que itens de orçamentos já aprovados não apareciam vinculados. Confirmado com um orçamento sintético de teste (criado e removido na mesma sessão) reproduzindo o erro ao vivo antes da correção.

**Corrigido em 22/07/2026** via `supabase/db/migrations/20260722_058_hotfix_aprovar_orcamento_subtotal_gerado/001_...sql` — remove `subtotal` do `INSERT INTO projeto_itens`, mesma técnica já usada em `20260626_009/002` para a função legada. Testado com aprovação real (orçamento sintético com 2 itens do mesmo produto em L Fixos diferentes, L01/L35): RPC retornou sucesso, 2 `projeto_itens` criados e corretamente vinculados por item de orçamento, 1 parcela e 1 boleto gerados.

**Pendência separada, não resolvida por este hotfix**: `supabase/db/migrations/20260706_020_normalizacao_aprovacao_financeira_orcamento/001_...sql` (SPEC-016 — checagem de permissão admin/gerente, validação de `frete_tipo` obrigatório) nunca foi de fato aplicada neste banco, apesar de `supabase/db/current/` documentar como se estivesse. Decidir se isso deve ser aplicado intencionalmente é uma decisão de produto do domínio de Orçamentos/Financeiro, fora do escopo deste hotfix.

**Reextrair `supabase/db/current/` para este domínio também** — mesma pendência crônica já registrada em `supabase/db/domains/estoque_compras.md` para o domínio de Compras, agora confirmada aqui também.

## Achado adicional e correção: reserva de estoque por item nunca acontecia (22/07/2026)

Ao verificar visualmente se os itens do ORC-0010 apareciam na Necessidade de Compra "Por Item de Orçamento" (`compras-lucenera-3o23t98ee`), descoberto que **`aprovar_orcamento_financeiro` nunca criou `estoque_saldos_projeto_item` (SPEC-010) nem reservou `estoque_itens.quantidade_reservada`** — só cria `projeto_itens`/`projeto_parcelas`/`boletos`. Sem o saldo operacional por item, a peça nunca tem como aparecer numa tela de déficit de estoque, mesmo com o vínculo de L Fixo correto.

Achado: existe uma SEGUNDA função no banco, `aprovar_orcamento_financeiro_base_spec001`, que já fazia isso corretamente (lock de `estoque_itens`, cálculo de cobertura física disponível, criação do saldo por item, registro em `estoque_movimentos_projeto_item`) — mas usa a nomenclatura de status antiga (`'aprovado'` minúsculo, não o contrato oficial `'Orçamento Aprovado'` da SPEC-016) e não é a função que o sistema chama.

**Corrigido** via `supabase/db/migrations/20260722_059_unificar_reserva_estoque_aprovacao/001_...sql` — incorpora a lógica de reserva de `_base_spec001` dentro da função oficial `aprovar_orcamento_financeiro`, preservando o contrato de status correto e as colunas `orcamento_item_id`/`l_fixo` da SPEC-040. Testado com orçamento sintético (quantidade proposital maior que o estoque físico, para forçar entrega futura real): RPC criou o saldo operacional corretamente, e o item apareceu na view `vw_necessidade_compra_item_orcamento` de verdade. Dados de teste removidos, estoque revertido ao valor original.

**Backfill retroativo do ORC-0010** (com autorização explícita do usuário, já que a RPC não permite reprocessar um orçamento já totalmente aprovado): aplicada manualmente a mesma lógica de reserva para os 3 itens já existentes. Resultado real: L01 e L02 ficaram cobertos pelo estoque físico disponível (sem necessidade de compra, corretamente); L03 ficou com `q_entrega_futura = 1` — item confirmado aparecendo na tela real (`ORC-0010 / L03 / PLAFON DE EMB ECO / Pendente 1`).

`aprovar_orcamento_financeiro_base_spec001` não foi alterada nem removida — permanece como estava, variante não usada pelo sistema.

## Auditoria dos orçamentos aprovados (22/07/2026, pós-hotfix)

Com a função corrigida, auditados os 12 orçamentos em `Orçamento Aprovado` para achar quais tinham `projeto_itens`/`projeto_parcelas`/`boletos` incompletos (provavelmente vítimas do mesmo bug, ou de uma importação legada que nunca passou pela RPC):

- **4 já corretos**: ORC-0005, ORC-0006, ORC-0007, ORC-0009 — itens/parcelas/boletos consistentes.
- **1 corrigido nesta sessão**: **ORC-0010** — tinha dados válidos (forma de pagamento, prazo) mas nunca foi processado. Status voltado para `Aprovação Financeira` (sem tocar em itens, não reinicia o ciclo do cliente), `aprovar_orcamento_financeiro` chamada de verdade, gerou 3 `projeto_itens` (vinculados a L01/L02/L03), 1 parcela e 1 boleto. Status retornado a `Orçamento Aprovado`.
- **1 bloqueado por ambiguidade, por desenho — ORC-0013**: 2 `projeto_itens` já existem, mas os 2 itens de orçamento de origem são avulsos (sem `produto_id`) e **textualmente idênticos** entre si (mesma descrição, quantidade e preço) — não há como saber com certeza qual `projeto_item` corresponde a L01 e qual a L02. Deixado sem vínculo, seguindo a mesma decisão de não adivinhar já tomada na SPEC-040 (P-05).
- **2 bloqueados por dado incompleto no próprio orçamento — ORC-0004 e LEG-1100**: nenhum tem `forma_pagamento` nem prazo de pagamento cadastrado — a RPC não consegue processar sem essa informação, e não deve ser inventada.
- **4 bloqueados por dado pré-existente inconsistente — LEG-1092, LEG-1108, LEG-1115, LEG-1169**: cada um já tem uma parcela solta no banco (criada pela importação legada, sem nenhum `projeto_itens` correspondente), o que faz a própria RPC recusar rodar (`processamento parcial inconsistente`). Corrigir exigiria decidir manualmente o que fazer com essa parcela órfã antes — não decidido nesta sessão.

## Diretriz ativa

Manter uma função/RPC transacional única para aprovação financeira por `orcamento_id`. O contrato oficial decidido pela SPEC-016 é `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado`; o frontend deve listar/editar orçamentos nessa fila e só disparar efeitos financeiros após confirmação final do financeiro.
