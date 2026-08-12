-- Migration 20260811_100 — Parte 2
-- Pedido do usuário: campo "Responsável" do projeto deve ser vínculo real
-- ao cadastro de Funcionários (que já existe), não texto livre derivado
-- do histórico. A FK antiga projetos.responsavel_id aponta pra `usuarios`
-- e está praticamente morta (ProjectNew.tsx sempre manda null nela); não
-- é alterada/removida aqui — só o texto livre `responsavel_nome` deixa de
-- ser digitado à mão e passa a ser preenchido a partir do funcionário
-- escolhido nesta coluna nova.
--
-- Não há trigger de sincronização aqui de propósito: trg_sync_equipe_por_
-- responsavel é "BEFORE UPDATE OF responsavel_nome", que só dispara se
-- essa coluna aparecer explicitamente no SET da query — um trigger
-- encadeado que escrevesse responsavel_nome por trás não faria o gatilho
-- de equipe/comissão disparar. O frontend passa a gravar
-- responsavel_funcionario_id e responsavel_nome juntos, sempre, no mesmo
-- INSERT/UPDATE.

ALTER TABLE public.projetos
  ADD COLUMN responsavel_funcionario_id uuid REFERENCES public.funcionarios(id) ON DELETE SET NULL;

CREATE INDEX idx_projetos_responsavel_funcionario ON public.projetos(responsavel_funcionario_id);
