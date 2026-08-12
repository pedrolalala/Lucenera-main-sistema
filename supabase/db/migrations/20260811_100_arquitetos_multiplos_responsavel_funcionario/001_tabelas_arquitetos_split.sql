-- Migration 20260811_100 — Parte 1
-- Pedido do usuário: divisão de lucro do projeto (e do orçamento) precisa
-- ser repartida entre múltiplos arquitetos, cada um com seu percentual.
-- Hoje projetos.arquiteto_id / orcamentos.arquiteto_id são FK únicas pra
-- contatos (tipo='arquiteto'). Cria tabelas de junção many-to-many com
-- percentual; a coluna singular é mantida (não dropada) e sincronizada
-- pelas RPCs replace_projeto_arquitetos/replace_orcamento_arquitetos
-- (migrations 003/004 desta mesma pasta) pra não quebrar nenhum relatório
-- ou sistema que ainda lê o campo antigo.
--
-- Sem policy de INSERT/UPDATE/DELETE: escrita só acontece através das RPCs
-- SECURITY DEFINER, que já fazem a validação de soma=100% e permissão —
-- mesma superfície mínima já usada em outras tabelas de junção do projeto.

CREATE TABLE public.projeto_arquitetos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE CASCADE,
  arquiteto_id uuid NOT NULL REFERENCES public.contatos(id),
  percentual numeric(5,2) NOT NULL CHECK (percentual > 0 AND percentual <= 100),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (projeto_id, arquiteto_id)
);

CREATE TABLE public.orcamento_arquitetos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  orcamento_id uuid NOT NULL REFERENCES public.orcamentos(id) ON DELETE CASCADE,
  arquiteto_id uuid NOT NULL REFERENCES public.contatos(id),
  percentual numeric(5,2) NOT NULL CHECK (percentual > 0 AND percentual <= 100),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (orcamento_id, arquiteto_id)
);

CREATE INDEX idx_projeto_arquitetos_projeto ON public.projeto_arquitetos(projeto_id);
CREATE INDEX idx_projeto_arquitetos_arquiteto ON public.projeto_arquitetos(arquiteto_id);
CREATE INDEX idx_orcamento_arquitetos_orcamento ON public.orcamento_arquitetos(orcamento_id);
CREATE INDEX idx_orcamento_arquitetos_arquiteto ON public.orcamento_arquitetos(arquiteto_id);

ALTER TABLE public.projeto_arquitetos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orcamento_arquitetos ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_select_projeto_arquitetos
  ON public.projeto_arquitetos FOR SELECT TO authenticated USING (true);

CREATE POLICY authenticated_select_orcamento_arquitetos
  ON public.orcamento_arquitetos FOR SELECT TO authenticated USING (true);
