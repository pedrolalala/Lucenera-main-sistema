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

## Import/Export de XML no padrão Connect (SPEC-050, 27/07/2026)

Migration redigida, **não aplicada no Supabase real ainda**: `supabase/db/migrations/20260727_065_spec050_import_export_xml_connect/001_orcamentos_origem_connect.sql`.

- `orcamentos.origem_connect_cod_orcamento` (integer, índice único parcial `WHERE origem_connect_cod_orcamento IS NOT NULL`): guarda o `cod_orcamento` do XML do ERP concorrente "Connect" quando o orçamento é criado por import de arquivo, no sistema de Orçamentos (`gestao-financeira-clone-544cb`). É a chave de idempotência: reimportar o mesmo XML deve ser bloqueado no frontend (query pontual antes de aplicar), não pela constraint em si sendo a única linha de defesa.
- `orcamentos.origem_connect_importado_em` (timestamptz): quando o import foi aplicado.
- Ambas as colunas são `NULL` para todo orçamento criado nativamente no Lucenera (fluxo normal, sem XML).
- Resolução no import: `empresa_id` por `empresas.cnpj` (prioridade) com fallback `empresas.codigo`; `cliente_id` por `contatos.codigo_legado`; `produto_id` por item via `produtos.codigo_produto` (confirmado no banco real que é equivalente a `codigo_legado` em 4.725 de 4.726 produtos, usado por ter 0 nulos) com fallback `produtos.referencia`.
- Produto sem match vira item avulso (sem `produto_id`, só com `descricao` = `desc_produto` do XML) — mesmo padrão já usado no domínio (ver ORC-0013 acima). Diferente do import de PDF, o import de XML sempre preserva a `descricao` do XML mesmo quando o produto foi casado por código.
- `desc_marca`/`desc_categoria` do XML não são persistidos em `orcamento_itens` — evita duplicar dado que já existe por relacionamento via `produto_id`.
- Export (botão "Exportar XML", só em orçamento já salvo) gera um XML com raiz `Laghi_systems` (em vez de `connect_systems` do Connect) e a mesma estrutura de tags de item, usando `orcamentos.numero` como `<cod_orcamento>` exportado (não é puramente numérico como no Connect, decisão aceita do usuário).
- Implementação: `src/lib/xml-budget-import.ts`, `src/lib/xml-budget-export.ts`, `src/components/budgets/ImportConnectXmlModal.tsx` em `gestao-financeira-clone-544cb (1)` — parsing/serialização 100% client-side (`DOMParser`/`Blob`), sem Edge Function nova.
- Pendências técnicas em aberto na SPEC-050 (P-4, P-5, P-7 nomenclatura já assumida pelo usuário nesta implementação, P-8): ver seção "Pendências" do arquivo da SPEC.

## Fase explícita de Rascunho antes do envio ao cliente (SPEC-051, 27/07/2026)

Migration redigida e **aplicada no Supabase real em 2026-07-27**: `supabase/db/migrations/20260727_066_spec051_fase_rascunho_orcamento/` (3 arquivos: remoção do bloco de auto-transição em `handle_orcamento_workflow()`, remoção completa de `trg_orcamento_item_workflow`/`handle_orcamento_item_workflow()`, e validação de completude em `enviar_orcamento_para_cliente`). Confirmado por leitura direta do banco pós-aplicação (`pg_get_functiondef`/`pg_get_triggerdef`) e refletido em `supabase/db/current/03_functions.sql`/`04_triggers.sql`. Falta apenas a homologação manual no navegador antes da publicação no Skip.

Contrato de status passa a ter 5 etapas: `rascunho -> enviado_cliente -> Aprovação da Equipe -> Aprovação Financeira -> Orçamento Aprovado`.

- **Achado (confirmado por leitura direta do Supabase real em 2026-07-27)**: até esta SPEC, `handle_orcamento_workflow()` (trigger `trg_orcamento_workflow`, `BEFORE INSERT OR UPDATE ON orcamentos`) promovia automaticamente qualquer orçamento em `rascunho`/`aguardando_cliente`/`aguardando_aprovacao`/NULL para `enviado_cliente` assim que `empresa_id`, `projeto_id`, `cliente_id` e `forma_pagamento` estavam preenchidos e já existia pelo menos 1 item — sem nenhuma ação explícita do usuário. Existia também um segundo gatilho equivalente e mais direto, `trg_orcamento_item_workflow` (`AFTER INSERT ON orcamento_itens`) → `handle_orcamento_item_workflow()`, que disparava assim que o primeiro item era inserido (inclusive ao reeditar itens de um rascunho via `replace_orcamento_itens`). Ambos os blocos/função foram removidos por esta SPEC; `handle_orcamento_item_workflow()` foi descartada por completo (não tinha nenhuma outra responsabilidade). Os dois blocos restantes de `handle_orcamento_workflow()` (reset pós-aprovação da SPEC-019 e geração de token quando o status já chega como `enviado_cliente`) não mudaram.
- **`enviar_orcamento_para_cliente(p_orcamento_id uuid)`** passa a ser o único ponto de entrada para `enviado_cliente` e ganhou validação de completude antes do `UPDATE` (decisão do usuário, P-1): `empresa_id`, `projeto_id`, `cliente_id`, `forma_pagamento` não nulos e pelo menos 1 linha em `orcamento_itens`; se faltar algo, `RAISE EXCEPTION` (`ERRCODE = 'P0003'`) listando o que falta, sem alterar o orçamento.
- **Achado de bug pré-existente corrigido nesta SPEC**: `useBudgetStore.ts` (`enviarOrcamentoCliente`, ação usada por `ClientApprovalTab.tsx` e `BudgetTableRow.tsx` para (re)enviar ao cliente) chamava a RPC `public.enviar_orcamento_cliente` (sem "para"). Confirmado por leitura direta do Supabase real que essa função **não existe** — só existe `public.enviar_orcamento_para_cliente(uuid)`. O botão "Reenviar"/"Aprovar" estava quebrado em produção antes desta correção. Frontend corrigido para chamar o nome real.
- Frontend (`gestao-financeira-clone-544cb (1)`): nova aba "Rascunho" (`DraftBudgetsTab.tsx`) e novo branch em `BudgetTableRow.tsx`, ambos com ação "Enviar para o Cliente" aberta a qualquer usuário autenticado, sem restrição de papel (decisão do usuário, P-2 — diferente das demais ações de aprovação/reenvio do sistema, que exigem `admin`/`gerente`/`operador`). Por decisão do usuário (P-3), orçamentos já em `enviado_cliente`/etapas posteriores no momento da implementação não recebem tratamento retroativo. Por decisão do usuário (P-4), não existe botão "Salvar e Enviar" no formulário de criação/edição — o envio é sempre uma ação separada feita pela aba "Rascunho".
- Ver SPEC-051 completa para os arquivos exatos tocados e o texto integral do SQL.

## SPEC-061 — Autopreenchimento por projeto + cadastro de cliente (2026-08-05)

`BudgetFormPage.tsx`: quando o projeto não tem `arquiteto_id` mas tem a coluna legada de texto `"Nome Arquiteto"`, busca em `contatos` por correspondência única de nome e pré-seleciona (sem inventar vínculo em caso de ambiguidade). Card de detalhes do projeto agora distingue "Não encontrado" (erro) de "sem vínculo na origem" (normal) para cliente/empresa. `ClientCreateModal.tsx`: e-mail obrigatório, campo "Complemento" nos 3 blocos de endereço, Vendedor/Vendedor Padrão passam a vir de `funcionarios` (não mais `usuarios`) — FK de `contatos.vendedor_id`/`vendedor_padrao_id` migrada para `funcionarios(id)`. Skip `projectId 32554`.

## SPEC-064 — Perfil Ribeirão/São Paulo (2026-08-05)

`orcamentos.perfil` (`text`, `CHECK IN ('ribeirao','sao_paulo')`, nullable) — rótulo puramente informativo, preenchido manualmente em `BudgetFormPage.tsx`, sem afetar cálculo, aprovação ou qualquer outro fluxo. Skip `projectId 32554`.

## SPEC-070 — Voltar orçamento para Rascunho (2026-08-06)

Migration redigida, **não aplicada no Supabase real ainda**: `supabase/db/migrations/20260806_082_spec070_voltar_orcamento_rascunho/001_voltar_orcamento_rascunho.sql`.

- Nova RPC `public.voltar_orcamento_rascunho(p_orcamento_id uuid, p_motivo text)`: única forma de sair de `enviado_cliente`/`recusado_cliente` de volta para `rascunho`. Restrita a `role IN ('admin', 'gerente')`, sem fallback via `hub_pode_executar` (diferente de `equipe_devolver_orcamento_cliente`) — decisão literal do usuário.
- `p_motivo` obrigatório, gravado em `historico_status_orcamentos.observacao`.
- Efeito: `status = 'rascunho'`, `token_aprovacao_cliente = NULL` (invalida o link já enviado ao cliente; nenhum token novo é gerado até o orçamento ser reenviado via `enviar_orcamento_para_cliente`). `enviado_cliente_em`/`enviado_cliente_por`/`recusado_cliente_em` **não** são apagados — ficam como registro histórico do envio/recusa que aconteceu.
- Contrato de status passa a admitir um caminho de volta pontual: `enviado_cliente|recusado_cliente -> rascunho` (além do fluxo linear `rascunho -> enviado_cliente -> Aprovação da Equipe -> Aprovação Financeira -> Orçamento Aprovado`). Não se estende às etapas de Aprovação da Equipe/Financeira/Aprovado — fora do escopo desta SPEC.
- Frontend (`gestao-financeira-clone-544cb (1)`): botão "Voltar para Rascunho" em `BudgetTableRow.tsx` e `ClientApprovalTab.tsx`, visível para `enviado_cliente`/`recusado_cliente`, restrito à mesma checagem de `canApproveFinancial` (admin/gerente) já usada no arquivo, com dialog de motivo obrigatório no mesmo padrão de `TeamApprovalTab.tsx`.
- Ver SPEC-070 completa para o texto integral do SQL e as decisões aprovadas (P-1 a P-4).

## SPEC-077 — Arquitetos múltiplos com % (2026-08-11)

Espelha a mudança de modelagem feita no CRM (ver `crm.md`): nova tabela `orcamento_arquitetos` (`orcamento_id` FK `orcamentos(id) ON DELETE CASCADE`, `arquiteto_id` FK `contatos(id)`, `percentual numeric(5,2) CHECK (percentual > 0 AND percentual <= 100)`, `UNIQUE(orcamento_id, arquiteto_id)`), escrita só via RPC `SECURITY DEFINER` `replace_orcamento_arquitetos(p_orcamento_id, p_arquitetos jsonb)` (mesmo guard de `spec069_orcamentos_update`, `hub_pode_executar('orcamentos', NULL, 'editar')`). `orcamentos.arquiteto_id` (coluna singular) continua sincronizada (maior percentual) só por compatibilidade. Diferente do CRM, esse campo continua **opcional** no orçamento (só valida soma=100% quando o array não está vazio) — orçamento não ganhou um requisito novo de "obrigatório ter arquiteto". Não existe conceito de "Responsável" em orçamentos, então essa parte da SPEC-077 não se aplica aqui.

`BudgetFormPage.tsx`: o autopreenchimento por projeto (`handleProjectSelect`) e por PDF (`handleBatchComplete`) descritos na SPEC-061 acima foram adaptados — quando o projeto já tem `projeto_arquitetos` cadastrados, popula o picker inteiro (todos os arquitetos + percentuais); no fallback legado por `"Nome Arquiteto"` (texto livre), continua só populando 1 linha de 100% quando há exatamente 1 correspondência única por nome. `ArchitectSplitPicker.tsx` deste sistema é construído sobre o `SearchableSelect` já existente (`src/components/ui/searchable-select.tsx`), diferente do Popover+Command com busca ao vivo no banco usado no componente equivalente do CRM — aqui a lista de arquitetos já vem inteira do `useOptions()` (sem filtro `empresa_id IS NULL`, diferente do CRM/SPEC-044; comportamento pré-existente, não alterado por esta SPEC). Skip `projectId 32554`.

## SPEC-152 — Parcelas customizadas, Carteira/Permuta, Responsável de Obra (2026-09-17)

- `orcamentos.plano_parcelas` (jsonb, nullable): array de `{numero, dias_offset, valor, forma_pagamento, permuta_fornecedor_id}` — Opção B decidida pelo usuário, substitui gradualmente `prazo_pagamento_dias` como fonte de **valor** por parcela (a coluna antiga continua existindo e sendo gravada, só deixa de ser a única fonte). `NULL`/vazio preserva 100% o comportamento legado (divisão igual de `valor_total`).
- Enum `public.pagamento_forma` ganhou `'carteira'` (parcela sem boleto, aparece em relatórios de pendência) e reconfirmou `'permuta'` (a migration da SPEC-107 não parecia ter sido de fato aplicada em produção, apesar de registrada "concluído" — `ADD VALUE IF NOT EXISTS` idempotente resolve os dois casos).
- `projeto_parcelas.permuta_fornecedor_id` (uuid, `REFERENCES contatos(id)`, nullable): obrigatório quando aquela parcela é `forma_pagamento = 'permuta'` — a aprovação lança automaticamente uma contrapartida de Contas a Pagar (ver `financeiro.md`, SPEC-152) usando o padrão já existente de `boletos.tipo_operacao = 'CP'` (SPEC-073), sem criar FK nova em `negociacoes`/`transacoes`.
- `aprovar_orcamento_financeiro(uuid)` (assinatura inalterada): passou a usar `plano_parcelas` quando presente, validando no backend (não só no frontend) que a soma bate exatamente com `valor_total`; pula geração de boleto pra parcela `'carteira'`/`'permuta'`.
- `ProjectCreateModal.tsx` (usado só dentro do fluxo "Criar Projeto" de `BudgetFormPage.tsx`, este sistema não tem uma tela própria de Projetos): campo Cliente ganhou ação "Novo Cliente" (mesmo padrão do Cliente do orçamento); `responsavel_obra_id` passou a listar só `contato_tipos.tipo = 'engenheiro'` (antes listava todos os `contatos`). CRM (`projetos.md`/`crm.md`) já filtrava corretamente antes desta SPEC, via `contatos.tipo` (coluna singular) em vez do join — comportamento equivalente na prática, verificado sem necessidade de mudança lá.
- Migration: `supabase/db/migrations/20260917_152_melhorias_orcamento/` (repositório central).

## SPEC-156 — Recálculo automático de parcelas + permuta aceita cliente (2026-09-21)

- `projeto_parcelas.permuta_fornecedor_id` (mesma coluna, não renomeada) passa a aceitar `contatos.tipo IN
  ('fornecedor', 'cliente')` em vez de só `'fornecedor'` — às vezes a contraparte da permuta é o próprio
  cliente oferecendo produto/serviço em troca. Validado em `aprovar_orcamento_financeiro(uuid)` (assinatura
  inalterada, só a condição de `tipo` mudou).
- `BudgetFormPage.tsx`: editar o valor de uma parcela do Plano de Parcelas agora redistribui
  automaticamente o restante entre as demais parcelas (antes, editar uma travava o array inteiro e exigia
  digitar todas manualmente pra soma bater).
- Migration: `supabase/db/migrations/20260921_156_permuta_fornecedor_ou_cliente/` (repositório central).

## Diretriz ativa

Manter uma função/RPC transacional única para aprovação financeira por `orcamento_id`. O contrato oficial (SPEC-051, sobre a base da SPEC-016/SPEC-031) é `rascunho -> enviado_cliente -> Aprovação da Equipe -> Aprovação Financeira -> Orçamento Aprovado`; a transição `rascunho -> enviado_cliente` é sempre manual, via `enviar_orcamento_para_cliente`. O frontend deve listar/editar orçamentos nessa fila e só disparar efeitos financeiros após confirmação final do financeiro.
