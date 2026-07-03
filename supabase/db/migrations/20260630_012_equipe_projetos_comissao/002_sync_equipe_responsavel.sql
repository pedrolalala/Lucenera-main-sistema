-- Migration 20260630_012 — Parte 2
-- Sincroniza projetos.equipe_id com base em responsavel_nome.
--
-- Como existem apenas 3 equipes (Thais, Marina, Thairine) e o nome da equipe
-- é idêntico ao nome da responsável nos projetos, o match é feito diretamente
-- entre projetos.responsavel_nome e equipes_projetos.equipes.
-- Não há necessidade de passar por funcionarios_novo.

UPDATE public.projetos p
SET    equipe_id = ep.id
FROM   public.equipes_projetos ep
WHERE  lower(trim(p.responsavel_nome)) = lower(trim(ep.equipes))
  AND  p.equipe_id IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- DIAGNÓSTICO — execute após o UPDATE para validar:
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Contagem por equipe (deve ter Thais, Marina e Thairine):
--
-- SELECT ep.equipes, COUNT(p.id) AS total_projetos
-- FROM   public.projetos p
-- JOIN   public.equipes_projetos ep ON ep.id = p.equipe_id
-- GROUP  BY ep.equipes
-- ORDER  BY ep.equipes;

-- 2. Projetos sem equipe (responsavel_nome diferente das 3 ou nulo):
--
-- SELECT codigo, nome, responsavel_nome
-- FROM   public.projetos
-- WHERE  equipe_id IS NULL
--   AND  responsavel_nome IS NOT NULL
-- ORDER  BY responsavel_nome;
