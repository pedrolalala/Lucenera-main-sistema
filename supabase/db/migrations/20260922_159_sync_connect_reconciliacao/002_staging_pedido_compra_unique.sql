-- SPEC-157 (2026-09-22): garante no banco que a dupla (codigo_pedido,
-- num_parc) e' de fato uma chave, para impedir acumulo de parcelas
-- duplicadas entre execucoes de importar_pedido_compra.py (o script hoje
-- faz DELETE+INSERT do subconjunto de codigo_pedido presente no export a
-- cada run, mas sem constraint no banco nada impede duplicidade se o
-- padrao de escrita mudar no futuro).
--
-- num_parc chega NULL na maioria dos pedidos sem parcela lancada (ver
-- COLUNAS/normalizacao no script) -- normalizado para 1 aqui e na carga,
-- porque UNIQUE do Postgres trata multiplos NULL como distintos entre si
-- (nao pegaria duplicata real de "pedido sem parcela" duplicado).
--
-- RASCUNHO -- NAO aplicar sem execucao manual do usuario.

BEGIN;

UPDATE public.staging_pedido_compra
SET num_parc = 1
WHERE num_parc IS NULL;

-- Dedup defensivo: mantem so a linha mais recente (importado_em) por par,
-- caso um import antigo (antes desta SPEC) tenha deixado duplicata parada
-- na tabela -- sem isso o ADD CONSTRAINT abaixo falharia.
DELETE FROM public.staging_pedido_compra s
WHERE ctid NOT IN (
    SELECT DISTINCT ON (codigo_pedido, num_parc) ctid
    FROM public.staging_pedido_compra
    ORDER BY codigo_pedido, num_parc, importado_em DESC NULLS LAST, ctid DESC
);

ALTER TABLE public.staging_pedido_compra
    ADD CONSTRAINT uq_staging_pedido_compra_codigo_num_parc
    UNIQUE (codigo_pedido, num_parc);

COMMIT;
