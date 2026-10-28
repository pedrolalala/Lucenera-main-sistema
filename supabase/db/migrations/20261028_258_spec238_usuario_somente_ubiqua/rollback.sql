-- Rollback da 258 (SPEC-238): volta o handle_new_user anterior e tira a coluna.
BEGIN;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_nome text;
BEGIN
    v_nome := COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1));

    -- Insert into usuarios (permissions table)
    INSERT INTO public.usuarios (id, email, nome, role)
    VALUES (NEW.id, NEW.email, v_nome, 'viewer')
    ON CONFLICT (id) DO NOTHING;

    -- Try to link an existing funcionario by email
    UPDATE public.funcionarios
    SET usuario_id = NEW.id
    WHERE email = NEW.email AND usuario_id IS NULL;

    -- If not linked, create a new funcionario record
    IF NOT EXISTS (SELECT 1 FROM public.funcionarios WHERE usuario_id = NEW.id) THEN
        INSERT INTO public.funcionarios (usuario_id, nome, email, status)
        VALUES (NEW.id, v_nome, NEW.email, 'Ativo');
    END IF;

    RETURN NEW;
END;
$function$;

ALTER TABLE public.usuarios DROP COLUMN IF EXISTS somente_ubiqua;
COMMIT;
