-- SPEC-143: "Dar Baixa" -- acao nova e separada de "Separar" (confirmado com
-- o usuario 2026-09-14, com referencia visual do Connect legado). Uma
-- separacao/parcial ja registrada ("quem pediu") pode receber depois, numa
-- etapa a parte, a confirmacao de que foi entregue/retirada ("quem fez a
-- entrega"), com seu proprio codigo, funcionario e responsavel que retirou.
--
-- Decisao (baixo risco, facil de estender): 1 baixa por parcial (indice
-- UNIQUE em separacao_id). Nao reaproveita `entregas_finalizadas`
-- (Logistica) -- achado durante a investigacao que aquele fluxo (
-- RegistrarEntregaPage.tsx / useFinalizarEntrega.ts) parece ter um bug de
-- assinatura ja hoje (os campos que a pagina manda nao batem com os que o
-- hook espera) e, mesmo corrigido, nao captura quem registrou a baixa
-- (funcionario) -- reportado a parte, fora do escopo desta SPEC.

BEGIN;

CREATE TABLE IF NOT EXISTS public.separacao_baixas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo bigserial,
  separacao_id uuid NOT NULL REFERENCES public.separacoes(id) ON DELETE CASCADE,
  funcionario_id uuid REFERENCES public.usuarios(id),
  responsavel_retirou text NOT NULL,
  data_baixa timestamptz NOT NULL DEFAULT now(),
  observacoes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_separacao_baixas_separacao_id
  ON public.separacao_baixas (separacao_id);

ALTER TABLE public.separacao_baixas ENABLE ROW LEVEL SECURITY;

-- Mesmo padrao de permissao ja usado em `separacoes` (SPEC-069).
CREATE POLICY "separacao_baixas_select" ON public.separacao_baixas
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "separacao_baixas_insert" ON public.separacao_baixas
  FOR INSERT TO authenticated
  WITH CHECK (
    public.hub_pode_executar(auth.uid(), 'separacao-parcial', NULL, 'criar')
    OR public.hub_pode_executar(auth.uid(), 'logistica', NULL, 'criar')
  );

CREATE POLICY "separacao_baixas_delete" ON public.separacao_baixas
  FOR DELETE TO authenticated
  USING (
    public.hub_pode_executar(auth.uid(), 'separacao-parcial', NULL, 'deletar')
    OR public.hub_pode_executar(auth.uid(), 'logistica', NULL, 'deletar')
  );

NOTIFY pgrst, 'reload schema';

COMMIT;
