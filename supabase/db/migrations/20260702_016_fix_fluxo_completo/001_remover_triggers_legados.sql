-- Migration 20260702_016 — Parte 1
-- Remove triggers e funções legadas que conflitam com o novo fluxo.
--
-- trg_reserva_estoque:
--   Disparava em projetos.status → 'Proposta Sinal' e criava linhas local='Reservado'.
--   O novo sistema (migration 010) reserva via quantidade_reservada na linha local='Estoque'.
--   Se ainda existir na live DB, cria dupla reserva pelo caminho errado.
--
-- trg_gerenciar_fluxo_projeto:
--   Disparava em projetos.status = 'Aprovado' (enum inexistente no projeto_status atual).
--   Referencia colunas item_id / orcamento_item_id que não existem em projeto_itens.
--   Nunca dispara na prática mas é código morto com risco latente.

DROP TRIGGER IF EXISTS trg_reserva_estoque       ON public.projetos;
DROP TRIGGER IF EXISTS trg_gerenciar_fluxo_projeto ON public.projetos;

DROP FUNCTION IF EXISTS public.trigger_reserva_estoque();
DROP FUNCTION IF EXISTS public.gerenciar_fluxo_projeto();
