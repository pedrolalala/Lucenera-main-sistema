BEGIN;
DROP TRIGGER IF EXISTS trg_orcamentos_valida_data_inicio_pagamento ON public.orcamentos;
DROP FUNCTION IF EXISTS public.fn_orcamentos_valida_data_inicio_pagamento();
ALTER TABLE public.orcamentos ADD CONSTRAINT orcamentos_data_inicio_pagamento_check
  CHECK (data_inicio_pagamento IS NULL OR data_inicio_pagamento >= (now() AT TIME ZONE 'America/Sao_Paulo')::date) NOT VALID;
COMMIT;
