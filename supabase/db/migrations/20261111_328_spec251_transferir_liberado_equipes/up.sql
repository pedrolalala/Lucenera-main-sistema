BEGIN;
-- SPEC-251 (complemento, 11/11): a tela do Transferir foi aberta a todas as equipes em 06/11, mas pode_trocar_reserva() seguiu por cargo
-- (admin, gerente, Projetista, exceção individual) e as equipes não viam o botão. Passa a aceitar também quem tem o papel 'equipe_projetos'.
CREATE OR REPLACE FUNCTION public.pode_trocar_reserva()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_role public.usuario_role;
BEGIN
    SELECT role INTO v_role FROM public.usuarios WHERE id = auth.uid();
    IF v_role IN ('admin', 'gerente') THEN
        RETURN true;
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.funcionarios
        WHERE usuario_id = auth.uid() AND btrim(cargo) = 'Projetista'
    ) THEN
        RETURN true;
    END IF;
    -- SPEC-251 (11/11): equipes de projetos (vendedoras) transferem peça entre vendas
    IF EXISTS (
        SELECT 1 FROM public.usuario_papeis up JOIN public.papeis p ON p.id = up.papel_id
         WHERE up.usuario_id = auth.uid() AND p.nome = 'equipe_projetos'
    ) THEN
        RETURN true;
    END IF;
    RETURN coalesce((
        SELECT e.tipo = 'conceder'
          FROM public.usuario_permissao_excecoes e
          JOIN public.modulos m ON m.id = e.modulo_id AND m.chave = 'transferir_reserva'
          JOIN public.systems s ON s.id = m.system_id AND s.slug = 'separacao-parcial'
         WHERE e.usuario_id = auth.uid()
           AND (e.valido_até IS NULL OR e.valido_até > now())
         ORDER BY e.criado_em DESC
         LIMIT 1), false);
END;
$function$;

REVOKE ALL ON FUNCTION public.pode_trocar_reserva() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_trocar_reserva() TO authenticated;
COMMIT;
