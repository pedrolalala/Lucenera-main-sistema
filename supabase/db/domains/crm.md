# Domínio: CRM

## Papel no ecossistema

O CRM controla etapas, timeline, sub-status, checklists, responsáveis e SLA do fluxo comercial/operacional.

## Decisão atual

As etapas do CRM devem ser configuráveis pela UI.

Não hardcodar regra de negócio fixa no banco ou no código para:

- etapas;
- sub-status;
- checklists;
- bloqueios;
- tarefas paralelas;
- tarefas sequenciais;
- responsáveis;
- SLA ativo/inativo;
- exceções editáveis por caso.

## Fluxo esperado

Cada projeto/orçamento anda por uma timeline. Dentro de cada etapa, a interface permite configurar sub-status, checklists e regras de execução.

## Automações atuais

Automatizações identificadas no Supabase real relacionadas ao CRM/Pipeline:

- `public.get_dashboard_crm_by_closing(data_inicial date, data_final date)`: consulta projetos por fechamento no período.
- `public.get_dashboard_kpi(p_date_now date)`: métricas/KPIs de dashboard.
- `public.get_dashboard_stats()`: estatísticas de dashboard.
- `public.gerenciar_fluxo_projeto()`: automação atual de fluxo/status de projeto.
- `public.sync_responsavel_nome()`: sincroniza nome do responsável.
- `public.trigger_fechar_projeto()`: automação de fechamento.
- `public.trigger_proteger_fechamento()`: proteção de fechamento.

Triggers relacionadas:

- `public.projetos.trg_gerenciar_fluxo_projeto`
- `public.projetos.trg_fechar_projeto`
- `public.projetos.trg_proteger_fechamento`
- `public.projetos.trg_sync_responsavel_nome`
- `public.projetos.update_projetos_updated_at`

Edge Functions relacionadas:

- `generate-report`: relatórios/exportações.

Edge Functions descontinuadas:

- `sync-fechamentos-automatica`: removida do projeto Supabase remoto e da pasta central pela SPEC-004. O status "projeto fechado" não é mais tratado como sincronização paralela; deve decorrer do fluxo de orçamento aprovado e das regras atuais de projeto.

Observação: apesar de existirem automações atuais de fluxo/status, a decisão de produto é evoluir CRM para configuração pela UI, sem hardcode de etapas/sub-status/checklists.

Observação sobre itens aprovados: a SPEC-014 prevê leitura de `projeto_itens` no detalhe do projeto. A SPEC-010 já existe no banco, mas o CRM só deve enriquecer a situação do item lendo a view de saldos por `projeto_item_id` (`q_reserva`, `q_entrega_futura`, `q_separado`, `q_entregue`) depois do hardening `20260707_023` e da policy de RLS. Até lá, deve usar rótulo genérico para itens válidos.

## Ação a ser realizada

Modelar tabelas de configuração para etapas, sub-status, checklists, regras de bloqueio, paralelismo/sequência, SLA e responsáveis. O código deve ler essas configurações da UI, não codificar regras fixas por etapa.
