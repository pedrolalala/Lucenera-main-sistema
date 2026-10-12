-- SPEC-193 C2, parte 1 (só ACRESCENTA, não fecha nada ainda).
-- Decisão 09/10: custo e impostos da peça só para a Administração (Lana, Débora, Carol, Matheus, Vinícius)
-- + Pedro/Filippo como suporte do sistema. Mesmo modelo da SPEC-191 (producao_editores).
-- A parte 2 (migration 203) fecha as colunas de custo em `produtos` para `authenticated`, depois que os
-- sistemas passarem a ler o custo por `vw_produtos_custo` e o "tem ST" por `produtos.tem_st`.

CREATE TABLE IF NOT EXISTS public.produto_custo_visualizadores (
  email text PRIMARY KEY,
  nome text NOT NULL,
  observacao text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.produto_custo_visualizadores ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.produto_custo_visualizadores FROM anon, authenticated;
COMMENT ON TABLE public.produto_custo_visualizadores IS
  'SPEC-193 C2: quem vê custo e impostos da peça (Administração). Lido só por pode_ver_custo_produto().';

INSERT INTO public.produto_custo_visualizadores (email, nome, observacao) VALUES
  ('financeiro@lucenera.com.br', 'Lana', NULL),
  ('debora@lucenera.com.br', 'Débora', NULL),
  ('caroline@lucenera.com.br', 'Carol', NULL),
  ('matheus@lucenera.com.br', 'Matheus', NULL),
  ('vinicius@lucenera.com.br', 'Vinícius', NULL),
  ('pedro@lucenera.com.br', 'Pedro', 'suporte do sistema'),
  ('pedrollaghi@gmail.com', 'Pedro', 'suporte do sistema'),
  ('filippo@lucenera.com.br', 'Filippo', 'suporte do sistema')
ON CONFLICT (email) DO NOTHING;

CREATE OR REPLACE FUNCTION public.pode_ver_custo_produto()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN coalesce(nullif(current_setting('request.jwt.claims', true), ''), '') = '' THEN true
    WHEN coalesce(auth.role(), '') = 'service_role' THEN true
    ELSE EXISTS (
      SELECT 1
      FROM public.usuarios u
      JOIN public.produto_custo_visualizadores v ON lower(v.email) = lower(u.email)
      WHERE u.id = auth.uid() AND COALESCE(u.ativo, true))
  END
$function$;
REVOKE ALL ON FUNCTION public.pode_ver_custo_produto() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_ver_custo_produto() TO authenticated, service_role;

-- Orçamento (resumo fiscal) e Vendas (CFOP da DANFE) só precisam saber SE a peça tem ST, não o %.
ALTER TABLE public.produtos
  ADD COLUMN IF NOT EXISTS tem_st boolean GENERATED ALWAYS AS (COALESCE(porc_st, 0) > 0) STORED;
COMMENT ON COLUMN public.produtos.tem_st IS 'SPEC-193 C2: true quando porc_st > 0 (sem expor o percentual).';

-- Custo e impostos da peça: devolve linhas só para quem está em produto_custo_visualizadores.
CREATE OR REPLACE VIEW public.vw_produtos_custo AS
 SELECT p.id,
    p.preco_custo,
    p.porc_desconto,
    p.percentual_desconto_compra,
    p.porc_frete,
    p.porc_st,
    p.ipi_entrada,
    p.icms_entrada,
    p.porc_despesas,
    p.porc_bdi,
    p.vl_custo_indireto,
    p.custo_total,
    p.margem_lucro,
    p.percentual_lucro
   FROM public.produtos p
  WHERE (SELECT public.pode_ver_custo_produto());
REVOKE ALL ON public.vw_produtos_custo FROM PUBLIC, anon;
GRANT SELECT ON public.vw_produtos_custo TO authenticated, service_role;
COMMENT ON VIEW public.vw_produtos_custo IS
  'SPEC-193 C2: custo/impostos da peça; vazia para quem não está em produto_custo_visualizadores.';
