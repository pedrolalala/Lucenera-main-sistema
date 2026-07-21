-- Migration 20260721_055 - Correcao retroativa de base (achado pre-SPEC-038)
-- solicitacoes_compra.projeto_id e quantidade_pedida estavam NOT NULL, mas a
-- necessidade de compra e agregada por produto (reuniao 08/06/2026, ver
-- supabase/db/domains/estoque_compras.md) e nao deve ficar amarrada a um
-- projeto/cliente especifico. As RPCs criar_pedido_compra_de_necessidade e
-- criar_pedido_compra_lote criam solicitacoes_compra sem projeto_id nem
-- quantidade_pedida, o que so foi detectado ao testar essas RPCs pela
-- primeira vez (o "Registrar Compra" nunca havia funcionado de fato ate
-- entao). Idempotente: DROP NOT NULL e no-op se a coluna ja aceitar NULL.

ALTER TABLE public.solicitacoes_compra ALTER COLUMN projeto_id DROP NOT NULL;
COMMENT ON COLUMN public.solicitacoes_compra.projeto_id IS
'Opcional. Necessidade de compra e agregada por produto, nao amarrada a projeto/cliente (reuniao 08/06/2026).';

ALTER TABLE public.solicitacoes_compra ALTER COLUMN quantidade_pedida DROP NOT NULL;
COMMENT ON COLUMN public.solicitacoes_compra.quantidade_pedida IS
'Opcional. Preenchida quando o pedido de compra e gerado a partir da necessidade agregada.';
