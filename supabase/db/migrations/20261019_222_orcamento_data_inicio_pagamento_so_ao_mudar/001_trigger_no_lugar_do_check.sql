-- 19/10/2026 (achado na SPEC-206): orcamentos_data_inicio_pagamento_check compara com now(). Um CHECK é
-- reavaliado em TODO update da linha, então qualquer orçamento cujo início de pagamento já passou fica
-- impossível de alterar (status, aprovação, itens via handle_orcamento_item_change_reset...). Caso real:
-- ORC-0001 (início 15/10) travou em 16/10.
-- A regra original (migration 108) só queria "hoje ou futuro" ao criar ou ao trocar a data. Agora é um
-- trigger que valida só no INSERT ou quando a data muda.
BEGIN;

ALTER TABLE public.orcamentos DROP CONSTRAINT IF EXISTS orcamentos_data_inicio_pagamento_check;

CREATE OR REPLACE FUNCTION public.fn_orcamentos_valida_data_inicio_pagamento()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.data_inicio_pagamento IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.data_inicio_pagamento IS DISTINCT FROM OLD.data_inicio_pagamento)
     AND NEW.data_inicio_pagamento < (now() AT TIME ZONE 'America/Sao_Paulo')::date THEN
    RAISE EXCEPTION 'A data de início do pagamento não pode ser anterior a hoje.'
      USING ERRCODE = '23514', CONSTRAINT = 'orcamentos_data_inicio_pagamento_check';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_orcamentos_valida_data_inicio_pagamento ON public.orcamentos;
CREATE TRIGGER trg_orcamentos_valida_data_inicio_pagamento
  BEFORE INSERT OR UPDATE OF data_inicio_pagamento ON public.orcamentos
  FOR EACH ROW EXECUTE FUNCTION public.fn_orcamentos_valida_data_inicio_pagamento();

COMMIT;
