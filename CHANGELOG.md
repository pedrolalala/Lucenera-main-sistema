# Changelog

Registro cronologico das mudancas no repositorio central `Lucenera - ADAPTA PASS`.

## 2026-07-07

### Atualizado

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
