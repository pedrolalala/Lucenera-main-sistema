-- Migration 20260710_031 - SPEC-020 Parte 1
-- SPEC-EST-02: produto_fornecedores — dados operacionais por relacao produto-fornecedor.
-- Nao duplica o cadastro mestre de produtos/contatos; adiciona custo, prazo e minimo.
-- Idempotente: usa IF NOT EXISTS em todas as operacoes.

CREATE TABLE IF NOT EXISTS public.produto_fornecedores (
    id                  uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    produto_id          uuid NOT NULL REFERENCES public.produtos(id) ON DELETE RESTRICT,
    fornecedor_id       uuid NOT NULL REFERENCES public.contatos(id) ON DELETE RESTRICT,
    codigo_fornecedor   text,
    custo_unitario      numeric(12,4),
    prazo_entrega_dias  integer CHECK (prazo_entrega_dias >= 0),
    qtd_minima          numeric(10,3) CHECK (qtd_minima > 0),
    unidade             text,
    ativo               boolean NOT NULL DEFAULT true,
    observacao          text,
    criado_em           timestamptz NOT NULL DEFAULT now(),
    atualizado_em       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (produto_id, fornecedor_id)
);

ALTER TABLE public.produto_fornecedores ADD COLUMN IF NOT EXISTS codigo_fornecedor  text;
ALTER TABLE public.produto_fornecedores ADD COLUMN IF NOT EXISTS custo_unitario     numeric(12,4);
ALTER TABLE public.produto_fornecedores ADD COLUMN IF NOT EXISTS prazo_entrega_dias integer;
ALTER TABLE public.produto_fornecedores ADD COLUMN IF NOT EXISTS qtd_minima         numeric(10,3);
ALTER TABLE public.produto_fornecedores ADD COLUMN IF NOT EXISTS unidade            text;
ALTER TABLE public.produto_fornecedores ADD COLUMN IF NOT EXISTS ativo              boolean NOT NULL DEFAULT true;
ALTER TABLE public.produto_fornecedores ADD COLUMN IF NOT EXISTS observacao         text;
ALTER TABLE public.produto_fornecedores ADD COLUMN IF NOT EXISTS criado_em          timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.produto_fornecedores ADD COLUMN IF NOT EXISTS atualizado_em      timestamptz NOT NULL DEFAULT now();

COMMENT ON TABLE public.produto_fornecedores IS
'SPEC-020 / SPEC-EST-02. Informacoes operacionais por par produto-fornecedor: custo, prazo, minimo. Nao substitui cadastro em produtos/contatos.';

CREATE INDEX IF NOT EXISTS idx_pf_produto    ON public.produto_fornecedores (produto_id);
CREATE INDEX IF NOT EXISTS idx_pf_fornecedor ON public.produto_fornecedores (fornecedor_id);

ALTER TABLE public.produto_fornecedores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_select_produto_fornecedores ON public.produto_fornecedores;
CREATE POLICY authenticated_select_produto_fornecedores
  ON public.produto_fornecedores
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.produto_fornecedores TO authenticated;
