-- SPEC-130 — fix de achado 🟡 do revisor (2026-09-11): `disparar_pull_sharepoint()` (010) foi
-- criada sem revogar o EXECUTE padrão de PUBLIC, diferente das outras 3 funções desta
-- migration — qualquer usuário autenticado podia chamá-la via RPC e forçar uma rodada de
-- pull fora do cron. Alinha com o mesmo padrão das demais.

revoke all on function public.disparar_pull_sharepoint() from public;
grant execute on function public.disparar_pull_sharepoint() to service_role;
