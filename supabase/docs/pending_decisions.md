# Decisões pendentes

## Snapshot do DB

Snapshot reextraído em 2026-06-25 para as SPECs 001-004.

Pendente: reextrair novamente após a SPEC-005. A tentativa local em 2026-06-26 falhou porque o ambiente não tinha Docker disponível para `supabase db dump` nem `pg_dump` instalado.

Até a reextração, considerar `db/current/` como fotografia pré-SPEC-005 para funções/triggers e usar `db/migrations/20260626_009_spec005_remocao_triggers_legados_aprovacao/` como fonte da correção aplicada.

## Nota fiscal

Decidir qual API/ferramenta será usada para emissão de notas fiscais.

Depois disso, implementar função de integração e atualizar Financeiro/Administração Bancária.

## Storage

Avaliar migração de uploads de boletos e notas fiscais para OneDrive/SharePoint.

Motivo: reduzir custo de armazenamento no Supabase.

## Estoque/Compras

Criar SPEC própria para novo sistema.

Ele deve ter dados cadastrais necessários para operação e informações operacionais de estoque/compras.

## Orçamentos antigos

Orçamentos criados antes das SPECs 002 e 003 ainda podem estar sem prazo de início de cobrança e/ou frete estruturado. Eles precisam ser editados manualmente antes da aprovação.

## Projetos fechados

Decidir se `projetos_fechados` deve ser mantida como histórico morto ou removida em migration futura. A função `sync-fechamentos-automatica` foi descontinuada e removida do remoto.

## Segurança

Após consolidar o DB, fazer revisão detalhada de:

- RLS;
- policies;
- permissões anon/authenticated;
- buckets públicos/privados;
- tabelas expostas.
