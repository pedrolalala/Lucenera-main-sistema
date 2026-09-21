-- SPEC-154: agenda o job de fallback (polling) que consulta a Focus NFe
-- para notas presas em 'processando_autorizacao' há mais de 10 minutos --
-- rede de segurança para quando o webhook falha/atrasa além do último
-- retry da Focus (24h).
--
-- `pg_cron` e `pg_net` JÁ estão habilitados neste projeto (confirmado via
-- pg_extension em 2026-09-21) -- nenhum CREATE EXTENSION aqui.
--
-- RASCUNHO -- NÃO aplicar sem execução manual do usuário, e só DEPOIS que
-- a Edge Function `verificar-notas-pendentes` já estiver deployada (a URL
-- abaixo só existe depois do deploy -- ver "Passos manuais" da SPEC-154).
--
-- IMPORTANTE: nenhum token/segredo real deve ser colado neste arquivo, nem
-- na hora de aplicar manualmente via SQL editor (isso viraria um segredo em
-- texto plano dentro do histórico de migrations do repositório). A forma
-- recomendada é usar o Vault do Supabase (`supabase_vault`/
-- `vault.decrypted_secrets`) para guardar o token que a Edge Function
-- `verificar-notas-pendentes` valida (secret `FOCUS_NFE_CRON_SECRET`,
-- comparado manualmente dentro da função -- não é a
-- SUPABASE_SERVICE_ROLE_KEY, é um secret próprio, mesmo padrão do
-- `focus-nfe-webhook`/`FOCUS_NFE_WEBHOOK_SECRET`) e referenciá-lo aqui por
-- nome, nunca pelo valor.
--
-- Passo manual antes de aplicar:
--   1. Substituir <PROJECT_REF> pela referência real do projeto Supabase.
--   2. Gerar um valor aleatório para o secret de autenticação do cron e
--      configurá-lo em DOIS lugares com o MESMO valor:
--        a. Secret da Edge Function `FOCUS_NFE_CRON_SECRET` (supabase
--           functions secrets set FOCUS_NFE_CRON_SECRET=...).
--        b. Um secret no Vault do Postgres (ex. nome
--           'focus_nfe_cron_auth') -- trocar o placeholder
--           <VAULT_SECRET_NOME> abaixo pelo nome real usado no Vault.
--   3. Só então rodar este arquivo contra o banco real.

BEGIN;

-- Remove agendamento anterior do mesmo nome, se existir, antes de recriar
-- (idempotente para reaplicação manual).
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'verificar-notas-pendentes-focus-nfe';

SELECT cron.schedule(
  'verificar-notas-pendentes-focus-nfe',
  '*/15 * * * *',
  $cron$
  SELECT net.http_post(
    url := 'https://<PROJECT_REF>.supabase.co/functions/v1/verificar-notas-pendentes',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        SELECT decrypted_secret
        FROM vault.decrypted_secrets
        WHERE name = '<VAULT_SECRET_NOME>'
        LIMIT 1
      )
    ),
    body := jsonb_build_object('trigger', 'pg_cron')
  );
  $cron$
);

COMMIT;
