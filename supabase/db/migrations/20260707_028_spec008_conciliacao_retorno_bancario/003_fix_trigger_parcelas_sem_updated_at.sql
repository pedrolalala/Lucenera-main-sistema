-- Migration 20260707_028 - SPEC-008 Parte 3
-- BUG pre-existente encontrado ao testar processar_retorno_bancario:
--
-- O trigger update_parcelas_updated_at (BEFORE UPDATE ON projeto_parcelas,
-- executando update_updated_at_column()) faz "NEW.updated_at = NOW()"
-- incondicionalmente, mas projeto_parcelas NAO TEM coluna updated_at
-- (confirmado em 01_schema_full.sql). Qualquer UPDATE em projeto_parcelas
-- falha hoje com "record new has no field updated_at" - inclusive o update
-- direto que RetornoBoletos.tsx ja tenta fazer hoje, e a nova RPC desta SPEC.
--
-- Nenhum frontend (Orcamentos, Financeiro) le ou espera projeto_parcelas.updated_at
-- (confirmado por grep), entao a coluna nunca deveria existir aqui - o trigger
-- e residuo de copiar o padrao usado em produtos/projetos/vendas (que tem
-- updated_at de verdade) para uma tabela que nao tem.
--
-- Correcao: remover o trigger orfao. Nao adicionamos updated_at porque nada
-- depende dela.

DROP TRIGGER IF EXISTS update_parcelas_updated_at ON public.projeto_parcelas;
