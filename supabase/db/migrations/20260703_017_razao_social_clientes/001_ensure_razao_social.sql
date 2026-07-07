-- Migration 20260703_017
-- Garante que a coluna razao_social existe em contatos e documenta o mapeamento
-- com o campo rzCliente da planilha de importação de Clientes.
--
-- Mapeamento da planilha Clientes.xlsx → contatos:
--   codCliente  → codigo_legado   (chave de join para atualização)
--   nmCliente   → nome            (nome fantasia / comercial)
--   rzCliente   → razao_social    (razão social / nome jurídico)
--
-- A coluna razao_social já foi criada em versão anterior do schema.
-- Este script é idempotente (IF NOT EXISTS) e serve como documentação.

ALTER TABLE public.contatos
    ADD COLUMN IF NOT EXISTS razao_social text;

COMMENT ON COLUMN public.contatos.razao_social IS
'Razão social (nome jurídico) do cliente. Equivale ao campo rzCliente da planilha de importação. Diferente de nome (nome fantasia/comercial = nmCliente).';
