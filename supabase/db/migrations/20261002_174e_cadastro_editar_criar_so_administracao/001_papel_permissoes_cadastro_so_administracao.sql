-- SPEC-174 N7 (decisão do usuário, 02/10/2026): no sistema Cadastro, só a
-- administração edita e cria peça. Papéis com editar/criar no Cadastro:
--   admin, admin_geral (acao NULL = todas, sem mudança),
--   administracao_comercial (criar/editar, sem mudança),
--   compras_e_entregas (já tinha editar; ganha criar — é a Débora quem cadastra peça, SPEC-158).
-- Todos os outros passam a só consultar (visualizar):
--   equipe_projetos e estoque perdem 'editar';
--   gerente, funcionario, operador e viewer tinham acao NULL ("todas") e passam a 'visualizar'.
--
-- Observação: produtos ainda aceita INSERT/UPDATE via permissões de 'orcamentos' e
-- 'necessidade-de-compra' (policies spec069_produtos_*, criar_produto_orcamento,
-- atualizar_preco_custo_produto) — de propósito, para o "item sem cadastro" do orçamento e a
-- atualização de custo continuarem funcionando. Esta migration controla só o que o próprio
-- Cadastro mostra (Editar/Copiar/Excluir/Nova Peça via hub_pode_executar 'cadastro').
--
-- Sem BEGIN/COMMIT no texto: aplicar dentro de uma transação externa (dry-run com rollback antes).
-- Idempotente (NOT EXISTS / DELETE / UPDATE por condição).

-- 1) compras_e_entregas ganha 'criar'
INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, s.id, NULL, 'criar'
FROM public.papeis p
CROSS JOIN public.systems s
WHERE s.slug = 'cadastro'
  AND p.nome = 'compras_e_entregas'
  AND NOT EXISTS (
    SELECT 1 FROM public.papel_permissoes pp
    WHERE pp.papel_id = p.id AND pp.system_id = s.id
      AND pp.modulo_id IS NULL AND pp.acao = 'criar'
  );

-- 2) equipe_projetos e estoque perdem 'editar' (e 'criar', se houver) no Cadastro
DELETE FROM public.papel_permissoes pp
USING public.papeis p, public.systems s
WHERE pp.papel_id = p.id AND pp.system_id = s.id
  AND s.slug = 'cadastro'
  AND p.nome IN ('equipe_projetos', 'estoque')
  AND pp.acao IN ('editar', 'criar', 'deletar');

-- 3) gerente, funcionario, operador, viewer: "todas" (acao NULL) vira só 'visualizar'
UPDATE public.papel_permissoes pp
SET acao = 'visualizar'
FROM public.papeis p, public.systems s
WHERE pp.papel_id = p.id AND pp.system_id = s.id
  AND s.slug = 'cadastro'
  AND p.nome IN ('gerente', 'funcionario', 'operador', 'viewer')
  AND pp.acao IS NULL;

NOTIFY pgrst, 'reload schema';

-- Rollback (se precisar desfazer):
-- UPDATE papel_permissoes pp SET acao = NULL FROM papeis p, systems s
--  WHERE pp.papel_id=p.id AND pp.system_id=s.id AND s.slug='cadastro'
--    AND p.nome IN ('gerente','funcionario','operador','viewer') AND pp.acao='visualizar';
-- INSERT INTO papel_permissoes (papel_id, system_id, modulo_id, acao)
--  SELECT p.id, s.id, NULL, 'editar' FROM papeis p CROSS JOIN systems s
--  WHERE s.slug='cadastro' AND p.nome IN ('equipe_projetos','estoque');
-- DELETE FROM papel_permissoes pp USING papeis p, systems s
--  WHERE pp.papel_id=p.id AND pp.system_id=s.id AND s.slug='cadastro'
--    AND p.nome='compras_e_entregas' AND pp.acao='criar';
