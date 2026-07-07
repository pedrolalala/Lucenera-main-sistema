# Decisões pendentes

## Snapshot do DB

Snapshot reextraído em 2026-07-06 a partir do Supabase real.

Resolvido: o snapshot pós-SPEC-005 e pós-migrations `017/018` foi reextraído com `pg_dump`/`psql` via `libpq`.

Pendente: reextrair `db/current/` depois das migrations `20260706_020`, `20260706_021`, `20260706_022` e do hardening `20260707_023`, sem sobrescrever alterações locais já existentes no snapshot.

## Aprovação do cliente

O banco real já contém colunas e RPCs de aprovação do cliente, e a migration de normalização da SPEC-016 já foi aplicada. O contrato oficial é:

- Oficial: `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado`.
- Legados/compatibilidade: `aprovado_cliente`, `aprovado` e `aprovado_financeiro`.

Resolvido tecnicamente em 06/07/2026: SPEC-016 aplicada no Supabase real e SPEC-017 aplicada na UI de Orçamentos via Skip. Pendência remanescente: homologar o fluxo completo com orçamento real e confirmar a experiência final de envio/link para cliente.

## Saldos de estoque por item de projeto

`estoque_saldos_projeto_item` e `estoque_movimentos_projeto_item` já existem no banco real em 07/07/2026, junto com as views da SPEC-010.

Aplicar o hardening `20260707_023_spec010_hardening` antes de SPEC-011/012/015 e antes de mostrar badges ricos de reserva/entrega futura no CRM. A decisão de modelagem já foi tomada: saldo vivo por `projeto_item_id`; cliente/projeto/orçamento/produto por `JOIN`. Decisão ainda pendente: policy de RLS de negócio para leitura operacional.

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
