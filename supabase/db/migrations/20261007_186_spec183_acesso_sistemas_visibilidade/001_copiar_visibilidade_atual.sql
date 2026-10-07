-- SPEC-183 (07/10/2026): "Acesso a Sistemas" (user_system_access) passa a ser
-- a ÚNICA fonte do que a pessoa vê no Hub. Antes de trocar a regra (002),
-- grava em user_system_access o que cada usuário NÃO admin COM papel vê hoje
-- (resultado atual de hub_sistemas_permitidos) — ninguém ganha nem perde nada
-- no dia da troca (decisão do usuário 07/10).
--
-- Exceções:
--   * Mariane (mariane@lucenera.com.br): fica com a lista que o usuário já
--     marcou na aba (sem Adm. Bancária, com Showroom) — decisão 07/10.
--   * Usuários SEM papel: já veem a lista antiga hoje, nada muda.
--   * Admin (usuarios.role = 'admin'): bypass, nada muda.
--   * Sistemas internos (visivel_no_hub = false): linhas não são tocadas.
--
-- Backup da tabela inteira em _bkp_user_system_access_20261007 (rollback.sql).
-- Precisa rodar ANTES do 002 (usa a hub_sistemas_permitidos antiga).
-- Sem BEGIN/COMMIT no texto (aplicar com dry-run + rollback antes).

CREATE TABLE IF NOT EXISTS public._bkp_user_system_access_20261007 AS
SELECT * FROM public.user_system_access;

CREATE TEMP TABLE _spec183_alvo ON COMMIT DROP AS
SELECT u.id AS user_id
FROM public.usuarios u
WHERE u.role::text IS DISTINCT FROM 'admin'
  AND lower(u.email) <> 'mariane@lucenera.com.br'
  AND EXISTS (SELECT 1 FROM public.usuario_papeis up WHERE up.usuario_id = u.id);

CREATE TEMP TABLE _spec183_ve_hoje ON COMMIT DROP AS
SELECT a.user_id, s.id AS system_id
FROM _spec183_alvo a
CROSS JOIN LATERAL public.hub_sistemas_permitidos(a.user_id) s;

DELETE FROM public.user_system_access usa
USING public.systems s
WHERE s.id = usa.system_id
  AND s.visivel_no_hub = true
  AND usa.user_id IN (SELECT user_id FROM _spec183_alvo);

INSERT INTO public.user_system_access (user_id, system_id)
SELECT user_id, system_id FROM _spec183_ve_hoje
ON CONFLICT (user_id, system_id) DO NOTHING;
