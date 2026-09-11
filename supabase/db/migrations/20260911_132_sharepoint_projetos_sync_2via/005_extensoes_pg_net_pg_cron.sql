-- SPEC-130 — habilita pg_net (chamar a Edge Function de push a partir do trigger) e pg_cron
-- (agendar a Edge Function de pull). NENHUM dos dois estava habilitado neste projeto até
-- 2026-09-11 (conferido direto no banco real: `select * from pg_available_extensions`).
--
-- ATENÇÃO: são extensões de nível de projeto (afetam o banco inteiro, compartilhado pelos
-- 10 sistemas), não algo isolado desta feature. Revisar antes de aplicar — se preferir não
-- habilitar globalmente, a alternativa é trocar o push por polling via pg_cron também (ver
-- SPEC-130, sem trigger em tempo real).

-- pg_net cria seus próprios objetos no schema `net`; pg_cron no schema `cron` — é o padrão
-- do Supabase, não precisam de `with schema` aqui.
create extension if not exists pg_net;
create extension if not exists pg_cron;
