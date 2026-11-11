-- SPEC-260: papel proprio "assistente_administrativa" para a Caroline, no lugar do papel admin.
-- Hoje ela tem os papeis admin + administracao_comercial. O admin (mesmo da Pedro/Filippo/Vinicius) da acao total em tudo.
-- O novo papel cobre SO os 10 sistemas que ela ja tem em Acesso a Sistemas. administracao_comercial FICA
-- (pode_editar_caixa_fechada depende dele). Nada do banco depende do papel admin dela: orcamentos_equipe_restrita so olha equipe_projetos.
-- Acesso a Sistemas (user_system_access) nao muda.

INSERT INTO public.papeis (nome, descricao)
SELECT 'assistente_administrativa',
       'SPEC-260: Assistente administrativa — Financeiro (Contas a Pagar/Receber, Adm. Bancaria), Vendas, Orcamentos, Necessidade de Compra e Cadastro; so consulta em Garantia/Producao; Central de Solicitacoes sem aprovar.'
WHERE NOT EXISTS (SELECT 1 FROM public.papeis WHERE nome = 'assistente_administrativa');

-- acao NULL = todas as acoes do sistema.
INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, s.id, NULL, v.acao
FROM public.papeis p
JOIN (VALUES
  ('financeiro', NULL), ('contas-pagar', NULL), ('contas-receber', NULL), ('vendas', NULL),
  ('orcamentos', NULL), ('necessidade-de-compra', NULL), ('cadastro', NULL),
  ('controle-garantia', 'visualizar'), ('controle-producao', 'visualizar'),
  ('solicitacoes', 'visualizar'), ('solicitacoes', 'criar')
) AS v(slug, acao) ON true
JOIN public.systems s ON s.slug = v.slug
WHERE p.nome = 'assistente_administrativa'
  AND NOT EXISTS (SELECT 1 FROM public.papel_permissoes x
                  WHERE x.papel_id = p.id AND x.system_id = s.id AND x.modulo_id IS NULL AND x.acao IS NOT DISTINCT FROM v.acao);

INSERT INTO public.usuario_papeis (usuario_id, papel_id)
SELECT u.id, p.id FROM public.usuarios u, public.papeis p
WHERE lower(u.email) = 'caroline@lucenera.com.br' AND p.nome = 'assistente_administrativa'
  AND NOT EXISTS (SELECT 1 FROM public.usuario_papeis x WHERE x.usuario_id = u.id AND x.papel_id = p.id);

DELETE FROM public.usuario_papeis up
USING public.usuarios u, public.papeis p
WHERE up.usuario_id = u.id AND up.papel_id = p.id
  AND lower(u.email) = 'caroline@lucenera.com.br' AND p.nome = 'admin';
