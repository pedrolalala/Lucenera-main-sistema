-- Migration 20260716_049 — Parte 1 (SPEC-030 Parte 2)
-- Vinculo explicito marca -> fornecedor (novo). Hoje public.marcas so tem
-- id, nome, ativo, created_at, codigo_legado — nao ha nenhuma coluna ligando
-- uma marca a um fornecedor/contato.
--
-- Necessario porque public.pedidos_compra.fornecedor_id e NOT NULL REFERENCES
-- contatos(id), e o fluxo de "Pedido em Lote" (RPC criar_pedido_compra_lote,
-- ver 003 desta pasta) precisa resolver um fornecedor_id real por marca,
-- em cascata com produtos.fornecedor_principal_id
-- (COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)).
--
-- Coluna nullable de proposito: o backfill (qual fornecedor corresponde a
-- cada marca ja cadastrada) e uma decisao de dado de Pedro/Filippo, nao
-- responsabilidade desta migration (ver Pendencias da SPEC-030 Parte 2).
-- Casar por nome (contatos.nome = marcas.nome) foi descartado -- e o mesmo
-- tipo de inconsistencia de nome que a SPEC-030 Parte 1 ja teve que corrigir.

ALTER TABLE public.marcas
    ADD COLUMN IF NOT EXISTS fornecedor_id uuid REFERENCES public.contatos(id);

CREATE INDEX IF NOT EXISTS idx_marcas_fornecedor_id ON public.marcas (fornecedor_id);

COMMENT ON COLUMN public.marcas.fornecedor_id IS
'SPEC-030 Parte 2. Fornecedor padrao da marca (contatos.id). Nullable — depende
de backfill manual (Pedro/Filippo) para mapear marca -> fornecedor real. Usado
como fallback em COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)
na resolucao de fornecedor de um produto.';
