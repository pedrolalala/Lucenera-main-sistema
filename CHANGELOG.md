# Changelog

Registro cronologico das mudancas no repositorio central `Lucenera - ADAPTA PASS`.

## 2026-07-17

### Corrigido

- Aplicadas no Supabase real as 5 migrations de `supabase/db/migrations/20260716_049_spec030_pedido_lote_marca_fornecedor/` (SPEC-030 Parte 2), que estavam apenas em rascunho desde 2026-07-16: coluna `marcas.fornecedor_id`, `vw_necessidade_compra` estendida com `marca_id`/`marca_nome`/`fornecedor_id`/`fornecedor_nome`, RPC `criar_pedido_compra_lote`, índice fuzzy `idx_contatos_nome_unaccent_trgm` e RPC `buscar_fornecedores_fuzzy`. Motivo: Pedro reportou que a marca não aparecia vinculada em Necessidade de Compra (sistema `compras-lucenera-3o23t98ee`), apesar de já aparecer em Estoque de Produtos — o frontend já estava pronto (commit `eb5cc7e`), só faltava a migration no banco.
- Corrigidos 2 bugs no rascunho da migration, encontrados só ao aplicar contra o Postgres real: (1) `004_idx_contatos_nome_unaccent_trgm.sql` usava `unaccent()` direto em expressão de índice, que exige função `IMMUTABLE` (`unaccent()` é `STABLE`) — corrigido com wrapper `public.immutable_unaccent()`; (2) `005_rpc_buscar_fornecedores_fuzzy.sql` tinha `SELECT DISTINCT ... ORDER BY` por expressão fora da lista de SELECT, rejeitado pelo Postgres — corrigido com subquery.
- Confirmado por query direta: `vw_necessidade_compra` agora retorna `marca_nome` preenchido em 230 de 233 linhas (as 3 restantes são produtos sem `marca_id` cadastrado, não um bug).

### Pendente

- Backfill de `marcas.fornecedor_id` (mapeamento marca → fornecedor, decisão de dado de Pedro/Filippo) — sem ele, `fornecedor_id`/`fornecedor_nome` continuam nulos e o Pedido em Lote não tem itens selecionáveis, embora a marca já apareça.
- Busca fuzzy de fornecedor (`buscar_fornecedores_fuzzy`) roda sem erro mas retorna 0 resultados em buscas curtas contra nomes de fornecedor longos (ex.: "Stella" vs. "STELLA IMPORTACAO E EXPORTACAO DE LUMINARIAS LTDA" tem `similarity() = 0.119`, abaixo do threshold `0.3`) — precisa de ajuste de algoritmo (`word_similarity()` em vez de `similarity()`), não só de threshold. Ver Pendências da SPEC-030 Parte 2.
- Teste manual no navegador e publicação via Skip continuam pendentes do usuário.
- Reextração do snapshot `supabase/db/current/` (desatualizado desde 2026-07-07) continua pendente.

## 2026-07-16

### Corrigido

- `compras-lucenera-3o23t98ee`: commit `55fd80e` (pushado) corrige `getFornecedores()` em `src/services/pedido-compra.ts` para filtrar por `contato_tipos.tipo = 'fornecedor'` (antes retornava contatos de qualquer tipo — arquiteto, cliente — na busca de "Marca/Fornecedor" do Registrar Pedido de Compra). Removida duplicata morta `getFornecedores()`/`FornecedorOption` em `services/compras.ts` e o mock associado. Ponteiro do submodule atualizado no repo central (`6ca80f2`). SPEC-030, Parte 1. Revisado pelo agente `revisor` sem achado crítico/aviso, lint/build limpos. **Publicação via Skip ainda pendente**: o servidor MCP `skip` está registrado mas com status "Needs authentication" — falta concluir OAuth para liberar as ferramentas `mcp__skip__*` de publish.

### Atualizado

- `03-Projeto/Planos de Ação/SPECs/SPEC-030_Fix_Filtro_Tipo_Fornecedor_Compras.md` expandida com uma Parte 2 (planejamento, não implementado): consolidar a Necessidade de Compra por fornecedor, fluxo de "Pedido em Lote" (1 pedido = 1 fornecedor, gerado a partir de `produtos.fornecedor_principal_id`) e busca de fornecedor tolerante a erro de digitação/variação de nome via `pg_trgm` + `unaccent` (extensões já habilitadas no banco). Decisões de escopo confirmadas por Pedro; implementação ainda não iniciada.

### Adicionado

- SPEC-030 Parte 2 implementada em código (commit `d1a2a7e`, pushado): filtro por **marca** (não fornecedor direto — marca/fornecedor tratados como equivalentes a pedido de Pedro) na Necessidade de Compra, fluxo de "Pedido em Lote" (`ModalPedidoLote.tsx` + RPC `criar_pedido_compra_lote`, generalização transacional de `criar_pedido_compra_de_necessidade`) e busca de fornecedor tolerante a erro de digitação via nova RPC `buscar_fornecedores_fuzzy` (`pg_trgm` + `unaccent`, threshold `similarity() > 0.3`). Migrations em rascunho (`supabase/db/migrations/20260716_049_spec030_pedido_lote_marca_fornecedor/`), **ainda não aplicadas no Supabase real** — inclui a coluna nova `marcas.fornecedor_id` (nullable, depende de backfill manual de Pedro/Filippo: mapear cada marca ao fornecedor correspondente). Revisado pelo agente `revisor` sem achado crítico/aviso; lint/build limpos. Publicação via Skip segue pendente (mesmo bloqueio de OAuth do MCP `skip` da Parte 1).
- Durante o push do commit `d1a2a7e`, reconciliados via merge vários commits automáticos do bot `Skip <skip@usecurling.com>` já presentes em `origin/main` (bumps de versão `v0.0.30`–`v0.0.32` e sincronizações de build) — evidência de que a plataforma Skip publica direto no GitHub por conta própria, independente da autenticação do MCP usada por agentes desta sessão.

## 2026-07-07

### Adicionado

- Criada `SPEC-019_Origem_Aprovacao_Cliente_e_Reset_Pos_Aprovacao.md`: coluna `orcamentos.aprovado_cliente_origem` (manual/token), reset automático da aprovação ao editar valor/frete/forma de pagamento/prazo/itens de um orçamento já em `Aprovação Financeira`/`Orçamento Aprovado`, RPC `financeiro_editar_orcamento` com opção explícita de não reiniciar (modal na tela de Aprovação Financeira), e criação de `buscar_orcamento_para_aprovacao`/`recusar_orcamento_cliente_publico` — RPCs que o frontend do sistema de Orçamentos (`ClientApproval.tsx`) já chamava mas nunca existiram no banco, causando "Link Inválido" em qualquer link público de aprovação.
- Corrigido no sistema de Orçamentos: modal de criar cliente/projeto direto do formulário de orçamento mostrava sucesso sem persistir nada — o evento de submit borbulhava por portal React até o form pai; adicionado `stopPropagation` em `ClientCreateModal.tsx`/`ProjectCreateModal.tsx`.
- Criado `03-Projeto/07_ANALISE_LACUNAS_IMPLEMENTACAO_2026_07_07.md`, comparando reuniões, mapeamentos, SPECs, snapshot Supabase e código dos sistemas para listar lacunas implementáveis, bloqueios, riscos de segurança, status de build/lint e ordem recomendada de execução.
- Implementadas localmente as migrations centrais `20260708_029_spec006_permissoes_granulares_hub` e `20260708_030_spec007_sso_cross_system`, com permissões granulares no Hub, SSO por `sso_code`, Edge Functions `generate-cross-system-code`/`exchange-cross-system-code` e checagem TDD em `scripts/verify-spec006-007.mjs`.
- Criada a evidência TDD `03-Projeto/Evidencias TDD/SPEC-006-007_TDD_2026_07_07.md` com RED/GREEN e comandos de build/lint executados.
- Adicionado `src/lib/cross-system-auth.ts` nos apps Hub, Orçamentos, Financeiro/Retorno e CRM para `redirectWithCode`/`consumeCodeFromUrl`.
- Aplicada/verificada a SPEC-006 no Supabase remoto e aplicada a SPEC-007 via `SUPABASE_DB_URL` do `.env`; Edge Functions `generate-cross-system-code` e `exchange-cross-system-code` publicadas como `ACTIVE`.

### Atualizado

- Atualizado `03-Projeto/00_INDICE.md` para incluir a análise de lacunas e corrigir status obsoletos das SPECs 008 a 018.
- Atualizadas `SPEC-006`, `SPEC-007`, `00_TASKS_GERAIS_ECOSSISTEMA.md`, `supabase/db/domains/hub_ti.md` e contextos locais dos sistemas afetados para refletir aplicação/publicação remota e pendência real de homologação/adopção.
- Reextraído `supabase/db/current/` após SPEC-006/007, atualizando schema, funções, triggers, views, policies, inventário e manifesto.
- Hub/Central: dashboard agora prefere `hub_sistemas_permitidos` para cards por permissão e abre sistemas com `redirectWithCode`; administração recebeu telas de papéis, exceções e auditoria de permissões.
- Orçamentos, Financeiro/Retorno e CRM: fluxos cross-system passaram a consumir/gerar `sso_code` para evitar login duplicado entre apps, mantendo fallback para link direto.
- Implementada a SPEC-014 no CRM: `getProjeto()` passa a carregar `projeto_itens(*)` e `ProjectDetail.tsx` ganhou o Card "Itens Aprovados do Projeto", somente leitura, com quantidade, preço, desconto, subtotal, origem por orçamento e situação `Cancelado`/`Ativo`. `getProjetos()` permaneceu sem `projeto_itens(*)` para não pesar a listagem. Badges ricos de estoque seguem pendentes da leitura da SPEC-010 com RLS/policy definida.
- Confirmada a SPEC-010 no Supabase real e escrita a migration corretiva `20260707_023_spec010_hardening`: recria views com `security_invoker`, revoga grants de `anon`/`authenticated`, reconcilia `estoque_itens.quantidade_reservada` para os quatro produtos divergentes encontrados e endurece `trigger_fechar_projeto` para não transformar `q_entrega_futura` diretamente em entregue.

## 2026-07-06

### Atualizado

- Escrita a migration central `20260706_022_saldos_estoque_projeto_item` implementando a SPEC-010 (saldos operacionais de estoque por item de projeto): cria `estoque_saldos_projeto_item`/`estoque_movimentos_projeto_item`, atualiza `aprovar_orcamento_financeiro_base_spec001` (alocação `q_reserva`/`q_entrega_futura` item por item, com lock por produto/local), `cancelar_orcamento` (reversão pelo saldo aberto real, não pela quantidade original) e `trigger_fechar_projeto` (move saldo para `q_entregue`), cria as views `vw_estoque_saldos_projeto_item`/`vw_estoque_por_produto_projeto`/`vw_estoque_resumo`, e um backfill conservador para itens aprovados antes da migration. RLS habilitada sem policy nas duas tabelas novas, por decisão de segurança pendente (ver README da migration e pendência crítica 7 do checklist geral). Aplicação no Supabase real confirmada em 07/07/2026; hardening complementar ficou em `20260707_023_spec010_hardening`.
- Aplicadas no Supabase real as migrations centrais `20260706_020_normalizacao_aprovacao_financeira_orcamento` e `20260706_021_criar_produto_orcamento`.
- Normalizada a aprovação financeira de orçamento no banco conforme SPEC-016: contrato oficial `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado`, RPC transacional por `orcamento_id`, wrappers legados protegidos e auditoria por orçamento.
- Criada a RPC `public.criar_produto_orcamento(p_payload jsonb)` para a SPEC-018, gravando diretamente em `public.produtos` com validações cadastrais canônicas, sem catálogo paralelo.
- Atualizadas `SPEC-016`, `SPEC-017` e `SPEC-018` com o estado aplicado no banco.
- Implementadas na UI de Orçamentos, via projeto Skip da org Lucenera, as SPECs `SPEC-017` e `SPEC-018`: aba financeira agora trabalha por orçamento em `Aprovação Financeira`, aprovação final usa `orcamento_id`, e o cadastro de produto pode ser feito direto no fluxo de orçamento.
- Aplicado `skip_project_apply_changes` no projeto Skip `32554` (`Orçamentos Aprovação`) em modo development, gerando a versão `0.0.273` / `dcd3442` com QA verde.
- Refatoradas as SPECs pendentes de Estoque para consolidar o contrato técnico por `projeto_item_id`: `SPEC-010` agora define `estoque_saldos_projeto_item` e `estoque_movimentos_projeto_item`; `SPEC-011` transfere entre itens de projeto; `SPEC-013` foi absorvida; `SPEC-015` passou a usar a regra de devolução dos vídeos Connect.
- Reextraído `supabase/db/current/` a partir do Supabase real, refletindo `razao_social` em contatos e o fluxo parcial de aprovação do cliente em orçamentos.
- Regenerado `supabase/db/current/09_schema_inventory.md`.
- Incorporada a reunião 08 em `02-Reunioes/`, com transcrição, ata, fluxos, decisões/pendências e insights.
- Consolidadas SPECs 010/011/012/013/014 para saldos por item de projeto, entrega futura, transferência de reservas e badges no CRM.
- Criada e depois consolidada `SPEC-015_Devolucao_Estoque_por_Item_de_Projeto.md` para a regra de devolução.
- Criadas `SPEC-016`, `SPEC-017` e `SPEC-018` para normalizar aprovação financeira de orçamentos, unificar o modal/fluxo de edição financeira e permitir criação de produto dentro do modal de orçamento.
- Atualizados `00_TASKS_GERAIS_ECOSSISTEMA.md`, escopos afetados e docs/domínios Supabase.

### Inconsistências registradas

- Aprovação do cliente possuía contratos concorrentes no banco real; a SPEC-016 decidiu e aplicou o contrato oficial `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado` na camada Supabase. A UI de Orçamentos foi atualizada pela SPEC-017 e segue para homologação visual.
- `estoque_saldos_projeto_item` e `estoque_movimentos_projeto_item` já existem no banco real, mas a revisão encontrou exposição das views para `anon`/`authenticated`, divergência de `quantidade_reservada` em quatro produtos e entrega direta de `q_entrega_futura`; aplicar `20260707_023_spec010_hardening` antes de destravar transferência, entrega futura detalhada, devolução automatizada e badges ricos no CRM.
- `supabase/db/current/` ainda precisa ser reextraído depois das migrations 020 e 021; esta etapa ficou pendente para não sobrescrever alterações locais já existentes no snapshot.

## 2026-06-26

### Atualizado

- Baixadas as Edge Functions remotas atuais do projeto Supabase `vcvcwzmbiftcawncibke`.
- Removida a cópia central de `sync-fechamentos-automatica`, ausente no remoto.
- Documentado `process-billing-automation` como legado ainda ativo no remoto e fora do fluxo novo.
- Espelhadas as migrations da SPEC-005 em `supabase/db/migrations/20260626_009_spec005_remocao_triggers_legados_aprovacao/`.
- Atualizados domínios, inventário de automações, mapa de relacionamentos, status/enums e contexto global do Supabase.
- Atualizadas SPECs 001-005 e `00_TASKS_GERAIS_ECOSSISTEMA.md` com o que foi confirmado nos repos e no remoto.
- Puxadas atualizações dos repositórios de sistemas; alterações locais existentes foram preservadas em stash antes do pull.

### Pendente

- Reextrair `supabase/db/current/` após a SPEC-005. A tentativa local falhou sem Docker/`pg_dump`.
- Confirmar remoção definitiva de `process-billing-automation` após checar scheduler/webhook externo.
- Homologar o fluxo de aprovação real com orçamento completo, frete, prazo, histórico, parcelas e boletos.

### Adicionado

- Criada governanca inicial do repositorio central.
- Criado `README.md` com fontes de verdade, estrutura alvo e regras de leitura.
- Criado `AGENTS.md` geral com fluxo obrigatorio para IA/desenvolvedor.
- Criada regra de `.gitignore` para evitar commit de `.env`, `node_modules`, `dist` e temporarios.
- Criados documentos operacionais em `00-Contexto/`.
- Criados `AGENTS.md` por area principal do repositorio central.
- Adicionada instrucao de submodules em `00-Contexto/SUBMODULES.md`.
- Adicionados scripts `scripts/submodules-clone-all.sh` e `scripts/submodules-register.sh`.
- Adicionado `.env.example` e instrucao para criar `.env` local geral para acesso ao Supabase.

### Decisao

- O repositorio central guarda memoria, contexto, banco consolidado, relatorios, specs e inventario.
- Cada sistema continua sendo atualizado tambem em seu repositorio proprio.
- Sistemas com repositorio proprio devem ser registrados como submodules dentro de `04-Sistemas/`.
- O `.env` geral deve existir apenas localmente e nao deve ser commitado.
- O banco consolidado em `supabase/` e a fonte de verdade tecnica; migrations antigas dentro de sistemas sao historico, nao definicao final.
