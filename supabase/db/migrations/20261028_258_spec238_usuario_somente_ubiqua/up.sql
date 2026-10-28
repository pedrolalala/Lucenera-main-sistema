-- SPEC-238: conta criada pelo Catálogo Ubiqua (user_metadata.origem = 'catalogo-ubiqua') não é da Lucenera.
--  1. usuarios.somente_ubiqua — a Central esconde essas contas.
--  2. Marca as contas que já existem (nada é apagado).
--  3. handle_new_user: marca a conta nova do catálogo e não cria funcionário para ela.
BEGIN;

ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS somente_ubiqua boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.usuarios.somente_ubiqua IS
  'SPEC-238: conta criada pelo cadastro do Catálogo Ubiqua (revendedor). Não aparece na Central da Lucenera.';

UPDATE public.usuarios u
   SET somente_ubiqua = true
  FROM auth.users a
 WHERE a.id = u.id AND a.raw_user_meta_data->>'origem' = 'catalogo-ubiqua';

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_nome text;
    v_ubiqua boolean;
BEGIN
    v_nome := COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1));
    v_ubiqua := COALESCE(NEW.raw_user_meta_data->>'origem', '') = 'catalogo-ubiqua';

    -- Insert into usuarios (permissions table)
    INSERT INTO public.usuarios (id, email, nome, role, somente_ubiqua)
    VALUES (NEW.id, NEW.email, v_nome, 'viewer', v_ubiqua)
    ON CONFLICT (id) DO NOTHING;

    -- SPEC-238: revendedor do Catálogo Ubiqua não é funcionário da Lucenera
    IF v_ubiqua THEN
        RETURN NEW;
    END IF;

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

COMMIT;
