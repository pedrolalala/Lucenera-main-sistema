-- SPEC-266: permissoes da Debora definidas pelo usuario (09/11/2026).
-- Cadastro (criar/editar/visualizar) | Necessidade de Compra (tudo) | Entregas (so visualizar) | CRM (so a aba Fornecedores)
-- | Producao e Garantia (visualizar) | Central de Solicitacoes (criar/visualizar) | Venda Parcial (como esta, tudo).
-- Fornecedor no CRM: criar/editar vem da Necessidade de Compra (politicas spec069_contatos_* usam o tipo do contato).
BEGIN;

-- modulo "Fornecedores" do CRM (permissao so da aba)
INSERT INTO public.modulos (system_id, chave, nome, descricao, ordem)
SELECT s.id, 'fornecedores', 'Fornecedores (CRM)', 'Só a aba Fornecedores do CRM (SPEC-266).', 20
  FROM public.systems s WHERE s.slug = 'crm'
   AND NOT EXISTS (SELECT 1 FROM public.modulos m WHERE m.system_id = s.id AND m.chave = 'fornecedores');

INSERT INTO public.modulo_acoes (modulo_id, chave)
SELECT m.id, a.chave
  FROM public.modulos m JOIN public.systems s ON s.id = m.system_id AND s.slug = 'crm' AND m.chave = 'fornecedores'
  CROSS JOIN (VALUES ('visualizar'), ('criar'), ('editar'), ('deletar')) AS a(chave)
 WHERE NOT EXISTS (SELECT 1 FROM public.modulo_acoes x WHERE x.modulo_id = m.id AND x.chave = a.chave);

-- papel novo
INSERT INTO public.papeis (nome, descricao)
SELECT 'compras_cadastro_fornecedores',
       'SPEC-266: Cadastro (criar/editar), Necessidade de Compra (tudo), Entregas (visualizar), CRM só Fornecedores, Produção/Garantia (visualizar), Solicitações (criar/visualizar), Venda Parcial (tudo).'
 WHERE NOT EXISTS (SELECT 1 FROM public.papeis WHERE nome = 'compras_cadastro_fornecedores');

INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, s.id, m.id, v.acao
  FROM public.papeis p
  JOIN (VALUES
    ('cadastro',              NULL,           'visualizar'),
    ('cadastro',              NULL,           'criar'),
    ('cadastro',              NULL,           'editar'),
    ('necessidade-de-compra', NULL,           NULL),
    ('logistica',             NULL,           'visualizar'),
    ('crm',                   'fornecedores', 'visualizar'),
    ('controle-producao',     NULL,           'visualizar'),
    ('controle-garantia',     NULL,           'visualizar'),
    ('solicitacoes',          NULL,           'visualizar'),
    ('solicitacoes',          NULL,           'criar'),
    ('separacao-parcial',     NULL,           NULL)
  ) AS v(slug, modulo, acao) ON true
  JOIN public.systems s ON s.slug = v.slug
  LEFT JOIN public.modulos m ON m.system_id = s.id AND m.chave = v.modulo
 WHERE p.nome = 'compras_cadastro_fornecedores'
   AND NOT EXISTS (
     SELECT 1 FROM public.papel_permissoes x
      WHERE x.papel_id = p.id AND x.system_id = s.id
        AND x.modulo_id IS NOT DISTINCT FROM m.id AND x.acao IS NOT DISTINCT FROM v.acao);

-- troca os papeis da Debora (funcionario + compras_e_entregas -> o novo). usuarios.role continua 'funcionario'.
DELETE FROM public.usuario_papeis
 WHERE usuario_id = '78c716d7-9ca2-4449-8ac6-50c1905d21ef'
   AND papel_id IN (SELECT id FROM public.papeis WHERE nome IN ('funcionario', 'compras_e_entregas'));

INSERT INTO public.usuario_papeis (usuario_id, papel_id)
SELECT '78c716d7-9ca2-4449-8ac6-50c1905d21ef', id FROM public.papeis WHERE nome = 'compras_cadastro_fornecedores'
ON CONFLICT DO NOTHING;

COMMIT;
