-- Migration 20260708_029 - SPEC-006 Parte 4
-- Seed: papeis equivalentes aos 5 valores de usuarios.role, com acesso total
-- (todos os sistemas, todos os modulos, todas as acoes), para nao quebrar
-- acesso de ninguem na migracao. Nada consome hub_pode_executar ainda, entao
-- este seed e preparatorio, nao uma mudanca de comportamento.

INSERT INTO public.papeis (nome, descricao) VALUES
  ('admin', 'Migrado de usuarios.role = admin. Acesso total por padrao.'),
  ('gerente', 'Migrado de usuarios.role = gerente. Acesso total por padrao.'),
  ('operador', 'Migrado de usuarios.role = operador. Acesso total por padrao.'),
  ('funcionario', 'Migrado de usuarios.role = funcionario. Acesso total por padrao.'),
  ('viewer', 'Migrado de usuarios.role = viewer. Acesso total por padrao.')
ON CONFLICT (nome) DO UPDATE SET descricao = EXCLUDED.descricao;

-- Acesso total (modulo_id NULL, acao NULL) para cada papel, em todo sistema.
INSERT INTO public.papel_permissoes (papel_id, system_id)
SELECT p.id, s.id
FROM public.papeis p
CROSS JOIN public.systems s
ON CONFLICT DO NOTHING;

-- Atribui cada usuario ao papel equivalente ao seu usuarios.role atual.
INSERT INTO public.usuario_papeis (usuario_id, papel_id)
SELECT u.id, p.id
FROM public.usuarios u
JOIN public.papeis p ON p.nome = u.role::text
WHERE u.role IS NOT NULL
ON CONFLICT DO NOTHING;

-- Auto-governanca: o modulo de permissoes do proprio Hub entra no cadastro
-- de modulos/modulo_acoes, regido pela mesma matriz.
INSERT INTO public.modulos (system_id, chave, nome, descricao, ordem)
SELECT id, 'permissoes', 'Permissões', 'Matriz de papéis, permissões e exceções do ecossistema.', 0
FROM public.systems WHERE slug = 'hub'
ON CONFLICT (system_id, chave) DO UPDATE
SET nome = EXCLUDED.nome,
    descricao = EXCLUDED.descricao,
    ordem = EXCLUDED.ordem;

INSERT INTO public.modulo_acoes (modulo_id, chave)
SELECT m.id, a.chave
FROM public.modulos m
CROSS JOIN (VALUES ('criar'), ('editar'), ('deletar'), ('visualizar')) AS a(chave)
WHERE m.system_id = (SELECT id FROM public.systems WHERE slug = 'hub')
  AND m.chave = 'permissoes'
ON CONFLICT (modulo_id, chave) DO NOTHING;
