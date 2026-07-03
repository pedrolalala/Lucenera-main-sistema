# Domínio: Logística

## Papel no ecossistema

Logística acompanha separação, entrega, retirada, conferência e movimentações relacionadas aos projetos/itens.

## Relação com outros domínios

- Recebe demanda a partir de `projeto_itens`.
- Pode consultar cliente/projeto via orçamento/projeto.
- Pode depender de estoque para confirmar disponibilidade.
- Pode atualizar status operacional na timeline.

## Automações atuais

Automatizações identificadas no Supabase real relacionadas à Logística:

- `public.sync_separacao_cliente()`: sincroniza cliente na separação.
- `public.sync_separacao_codigo_obra()`: sincroniza código da obra na separação.
- `public.trigger_separacao_pronta()`: automação de separação pronta.
- `public.track_reagendamento()`: rastreia reagendamento.
- `public.trigger_reserva_estoque()`: reserva estoque ligada a projeto, com impacto operacional.

Triggers relacionadas:

- `public.entregas.entregas_updated_at`
- `public.separacoes.separacoes_updated_at`
- `public.separacoes.trg_separacao_pronta`
- `public.separacoes.trg_sync_sep_cliente`
- `public.separacoes.trg_sync_sep_codigo_obra`
- `public.separacoes.trg_track_reagendamento`
- `public.projetos.trg_reserva_estoque`

Edge Functions / funções locais relacionadas:

- As funções da Logística backup não aparecem no Supabase remoto porque aquele sistema está fora do Supabase atual.
- Ao replicar o backup para o novo sistema de Logística, analisar: `create-user`, `reset-user-password`, `optimize-route`, `sincronizar-fotos`, `sincronizar-materiais` e `migrate-helper`.
- Nenhuma dessas funções locais de backup deve ser promovida sem revisão de escopo e adaptação ao novo sistema.

## Ação a ser realizada

Ao consolidar o schema, mapear tabelas de separação, entrega e movimentação logística. Garantir que o vínculo principal seja com projeto/item aprovado, não com dados soltos de planilha.
