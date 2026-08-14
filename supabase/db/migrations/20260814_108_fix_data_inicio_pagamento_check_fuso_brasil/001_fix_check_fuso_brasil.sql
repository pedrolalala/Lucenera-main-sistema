-- Achado testando criação de orçamento ao vivo às ~22h49 (horário de Brasília) de 13/08.
-- orcamentos_data_inicio_pagamento_check comparava com CURRENT_DATE, que roda em UTC
-- na sessão do Postgres (Supabase). O frontend, porém, oferece "hoje" no fuso do
-- navegador (Brasil, UTC-3). Entre ~21h e meia-noite (horário de Brasília), CURRENT_DATE
-- em UTC já virou o dia seguinte, então qualquer data que o calendário oferece como "hoje"
-- falha a constraint — o usuário via o erro cru do Postgres
-- ("new row for relation orcamentos violates check constraint ...").
--
-- Fix: comparar com a data no fuso America/Sao_Paulo em vez de UTC.

ALTER TABLE public.orcamentos
  DROP CONSTRAINT orcamentos_data_inicio_pagamento_check;

-- NOT VALID: orçamentos antigos legitimamente têm data_inicio_pagamento no passado
-- (era "hoje ou futuro" quando criados) — só precisamos validar daqui pra frente.
ALTER TABLE public.orcamentos
  ADD CONSTRAINT orcamentos_data_inicio_pagamento_check
  CHECK (
    data_inicio_pagamento IS NULL
    OR data_inicio_pagamento >= ((now() AT TIME ZONE 'America/Sao_Paulo')::date)
  ) NOT VALID;
