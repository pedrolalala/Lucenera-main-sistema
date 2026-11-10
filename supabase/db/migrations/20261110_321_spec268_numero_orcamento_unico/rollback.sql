-- SPEC-268: volta set_orcamento_numero() à versão anterior (sem SECURITY DEFINER e sem lock).
CREATE OR REPLACE FUNCTION public.set_orcamento_numero()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_max_num INTEGER;
BEGIN
  IF NEW.numero IS NULL OR NEW.numero = '' THEN
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero FROM 5) AS INTEGER)), 0)
    INTO v_max_num
    FROM public.orcamentos
    WHERE numero LIKE 'ORC-%' AND numero ~ '^ORC-\d+$';

    NEW.numero := 'ORC-' || LPAD((v_max_num + 1)::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$function$;
