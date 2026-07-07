-- Migration 20260708_029 - SPEC-006 Parte 3
-- Trigger de auditoria automatica em papeis/papel_permissoes/usuario_papeis/
-- usuario_permissao_excecoes.

CREATE OR REPLACE FUNCTION public.fn_auditoria_permissoes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.auditoria_permissoes (autor_id, entidade, entidade_id, antes, depois)
  VALUES (
    auth.uid(),
    TG_TABLE_NAME,
    CASE WHEN TG_OP = 'DELETE' THEN (to_jsonb(OLD)->>'id')::uuid ELSE (to_jsonb(NEW)->>'id')::uuid END,
    CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION public.fn_auditoria_permissoes() IS
'SPEC-006. Grava em auditoria_permissoes toda alteracao de papel/permissao/atribuicao/excecao. entidade_id vem da coluna id de cada tabela (usuario_papeis nao tem id proprio - ver excecao abaixo).';

CREATE TRIGGER trg_auditoria_papeis
  AFTER INSERT OR UPDATE OR DELETE ON public.papeis
  FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_permissoes();

CREATE TRIGGER trg_auditoria_papel_permissoes
  AFTER INSERT OR UPDATE OR DELETE ON public.papel_permissoes
  FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_permissoes();

CREATE TRIGGER trg_auditoria_usuario_permissao_excecoes
  AFTER INSERT OR UPDATE OR DELETE ON public.usuario_permissao_excecoes
  FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_permissoes();

-- usuario_papeis tem chave primaria composta (usuario_id, papel_id), sem
-- coluna id: usa uma funcao de trigger dedicada para nao quebrar o
-- "(to_jsonb(NEW)->>'id')::uuid" da funcao generica acima.
CREATE OR REPLACE FUNCTION public.fn_auditoria_usuario_papeis()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.auditoria_permissoes (autor_id, entidade, entidade_id, antes, depois)
  VALUES (
    auth.uid(),
    'usuario_papeis',
    CASE WHEN TG_OP = 'DELETE' THEN OLD.usuario_id ELSE NEW.usuario_id END,
    CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_auditoria_usuario_papeis
  AFTER INSERT OR UPDATE OR DELETE ON public.usuario_papeis
  FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_usuario_papeis();
