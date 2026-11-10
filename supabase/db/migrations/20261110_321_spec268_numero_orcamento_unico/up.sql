-- SPEC-268: número de orçamento repetido (ORC-0004 x2, ORC-0005 x3 na MANOELLA etc.).
-- Causa: set_orcamento_numero() calculava MAX()+1 como o USUÁRIO que insere. Com a RLS por equipe (SPEC-200) cada pessoa só enxerga os
-- orçamentos da própria equipe, então o "máximo" era o da equipe e o número saía repetido (ex.: a Marina via ORC-0009 e gerava ORC-0010
-- quando o maior real era ORC-0014).
-- Correção: a função roda como dono (SECURITY DEFINER, enxerga todos) e trava o cálculo com um advisory lock de transação, para dois
-- inserts ao mesmo tempo não pegarem o mesmo número. Formato igual ao atual (ORC-NNNN). NÃO renumera os duplicados existentes (decisão à parte).
-- Sem BEGIN/COMMIT de propósito (o dry_run.sql abre a transação e termina em ROLLBACK).
CREATE OR REPLACE FUNCTION public.set_orcamento_numero()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_max_num INTEGER;
BEGIN
  IF NEW.numero IS NULL OR NEW.numero = '' THEN
    PERFORM pg_advisory_xact_lock(hashtext('orcamentos_numero_orc'));
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero FROM 5) AS INTEGER)), 0)
    INTO v_max_num
    FROM public.orcamentos
    WHERE numero LIKE 'ORC-%' AND numero ~ '^ORC-\d+$';

    NEW.numero := 'ORC-' || LPAD((v_max_num + 1)::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.set_orcamento_numero() FROM PUBLIC, anon;
