-- Migration 20260707_028 - SPEC-008 Parte 4
-- Achado em teste (rollback, sem dado real afetado): hash_conteudo UNIQUE
-- impede que "forcar reprocessamento" grave uma nova linha de auditoria em
-- retorno_bancario_arquivos, porque o hash repete de proposito. O bloqueio
-- de reprocessamento ja e feito na propria RPC (EXISTS ... WHEN NOT p_forcar),
-- entao a constraint UNIQUE do banco so precisa virar indice normal (mantendo
-- performance de lookup, sem travar o INSERT quando forcado).

ALTER TABLE public.retorno_bancario_arquivos DROP CONSTRAINT retorno_bancario_arquivos_hash_conteudo_key;
CREATE INDEX idx_retorno_bancario_arquivos_hash ON public.retorno_bancario_arquivos (hash_conteudo);
