-- SPEC-153: sem esta migration, hub_pode_executar(usuario, 'vendas', ...)
-- nega TODO usuário não-service_role, inclusive admin -- a função não tem
-- bypass embutido pra role='admin', só checa papel_permissoes/exceções
-- (confirmado via pg_get_functiondef em 2026-09-17). Todo sistema já
-- existente recebeu, na criação, uma linha em branco (acao=NULL,
-- modulo_id=NULL = acesso total) pros papéis 'admin' e 'admin_geral' --
-- ver, por exemplo, o mesmo padrão em 'orcamentos'/'crm'/'separacao-parcial'.
-- Esta migration só replica esse mesmo bootstrap mínimo pro sistema novo
-- 'vendas', sem inventar regra de negócio nova (RBAC fino de Carol/Lana
-- continua pendência separada, registrada na SPEC-153).
--
-- Depende de 002_registro_vendas_no_hub.sql já aplicada (systems.slug='vendas'
-- precisa existir antes).
--
-- RASCUNHO -- NÃO aplicar sem aprovação/execução manual do usuário.

BEGIN;

INSERT INTO public.papel_permissoes (papel_id, system_id, acao, modulo_id)
SELECT p.id, s.id, NULL, NULL
FROM public.papeis p
CROSS JOIN public.systems s
WHERE p.nome IN ('admin', 'admin_geral')
  AND s.slug = 'vendas'
  AND NOT EXISTS (
    SELECT 1 FROM public.papel_permissoes pp
    WHERE pp.papel_id = p.id AND pp.system_id = s.id
      AND pp.acao IS NULL AND pp.modulo_id IS NULL
  );

COMMIT;
