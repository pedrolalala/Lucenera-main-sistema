-- SPEC-069: matriz de 6 papéis reutilizáveis (Administrador Geral, Gestão de
-- RH, Administração Comercial, Compras e Entregas, Equipe de Projetos,
-- Equipe de Entrega) sobre a infraestrutura de permissões já criada pela
-- SPEC-006 (papeis, papel_permissoes, usuario_papeis, hub_pode_executar).
--
-- Não altera o modelo de dados da SPEC-006 — só estende o CHECK de ação para
-- incluir 'aprovar' (a hierarquia TOTAL > EDITAR > EDITAR SEM CADASTRAR >
-- CONSULTAR > SEM ACESSO pedida pelo usuário trata "aprovar" como uma ação
-- distinta de "editar", necessária para o caso da Carol em Orçamentos).
--
-- "Ficha Técnica" (P6 da SPEC-069) fica de fora deste seed: repositório novo
-- ainda não registrado em `public.systems`. Adotar em migration separada
-- depois que o sistema existir.

ALTER TABLE public.papel_permissoes DROP CONSTRAINT papel_permissoes_acao_check;
ALTER TABLE public.papel_permissoes ADD CONSTRAINT papel_permissoes_acao_check
  CHECK (acao = ANY (ARRAY['criar','editar','deletar','visualizar','aprovar']));

ALTER TABLE public.modulo_acoes DROP CONSTRAINT modulo_acoes_chave_check;
ALTER TABLE public.modulo_acoes ADD CONSTRAINT modulo_acoes_chave_check
  CHECK (chave = ANY (ARRAY['criar','editar','deletar','visualizar','aprovar']));

-- 1) Papéis

INSERT INTO public.papeis (nome, descricao) VALUES
  ('admin_geral', 'SPEC-069: Administrador Geral — acesso TOTAL a todos os sistemas.'),
  ('rh_administracao', 'SPEC-069: Gestão de RH — TOTAL só em RH, sem acesso ao resto.'),
  ('administracao_comercial', 'SPEC-069: Administração comercial — Cadastro, Orçamentos (com aprovação financeira) e Necessidade de Compra.'),
  ('compras_e_entregas', 'SPEC-069: Operação de compras e entregas — Cadastro (consulta), Necessidade de Compra e Sistema de Entrega.'),
  ('equipe_projetos', 'SPEC-069: Equipe de Projetos — CRM, Necessidade de Compra e Entrega em Editar; Cadastro e Orçamentos em Editar sem cadastrar.'),
  ('equipe_entrega', 'SPEC-069: Equipe de Entrega — Consulta em Orçamentos, Editar em Sistema de Entrega.')
ON CONFLICT (nome) DO NOTHING;

-- 2) Permissões por papel × sistema
-- TOTAL = 1 linha com acao NULL (hub_pode_executar trata NULL como coringa).
-- EDITAR = criar+editar+visualizar. EDITAR SEM CADASTRAR = editar+visualizar.
-- CONSULTAR = visualizar. SEM ACESSO = nenhuma linha (default-deny já existente).

DO $$
DECLARE
  v_admin_geral uuid := (SELECT id FROM public.papeis WHERE nome = 'admin_geral');
  v_rh_admin uuid := (SELECT id FROM public.papeis WHERE nome = 'rh_administracao');
  v_adm_comercial uuid := (SELECT id FROM public.papeis WHERE nome = 'administracao_comercial');
  v_compras_entregas uuid := (SELECT id FROM public.papeis WHERE nome = 'compras_e_entregas');
  v_equipe_projetos uuid := (SELECT id FROM public.papeis WHERE nome = 'equipe_projetos');
  v_equipe_entrega uuid := (SELECT id FROM public.papeis WHERE nome = 'equipe_entrega');

  v_hub uuid := (SELECT id FROM public.systems WHERE slug = 'hub');
  v_financeiro uuid := (SELECT id FROM public.systems WHERE slug = 'financeiro');
  v_cadastro uuid := (SELECT id FROM public.systems WHERE slug = 'cadastro');
  v_crm uuid := (SELECT id FROM public.systems WHERE slug = 'crm');
  v_orcamentos uuid := (SELECT id FROM public.systems WHERE slug = 'orcamentos');
  v_compras uuid := (SELECT id FROM public.systems WHERE slug = 'necessidade-de-compra');
  v_logistica uuid := (SELECT id FROM public.systems WHERE slug = 'logistica');
  v_rh uuid := (SELECT id FROM public.systems WHERE slug = 'rh');
  v_dashboard uuid := (SELECT id FROM public.systems WHERE slug = 'dashboard-financeiro');
BEGIN
  IF v_admin_geral IS NULL OR v_rh_admin IS NULL OR v_adm_comercial IS NULL
     OR v_compras_entregas IS NULL OR v_equipe_projetos IS NULL OR v_equipe_entrega IS NULL THEN
    RAISE EXCEPTION 'SPEC-069: papel novo não encontrado após insert — abortando seed.';
  END IF;
  IF v_hub IS NULL OR v_financeiro IS NULL OR v_cadastro IS NULL OR v_crm IS NULL
     OR v_orcamentos IS NULL OR v_compras IS NULL OR v_logistica IS NULL
     OR v_rh IS NULL OR v_dashboard IS NULL THEN
    RAISE EXCEPTION 'SPEC-069: system slug esperado não encontrado em public.systems — abortando seed.';
  END IF;

  -- admin_geral: TOTAL em todos os 9 sistemas já resolvidos
  INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
  SELECT v_admin_geral, s, NULL, NULL
  FROM unnest(ARRAY[v_hub, v_financeiro, v_cadastro, v_crm, v_orcamentos, v_compras, v_logistica, v_rh, v_dashboard]) AS s
  ON CONFLICT (papel_id, system_id, modulo_id, acao) DO NOTHING;

  -- rh_administracao: TOTAL só em RH
  INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
  VALUES (v_rh_admin, v_rh, NULL, NULL)
  ON CONFLICT (papel_id, system_id, modulo_id, acao) DO NOTHING;

  -- administracao_comercial: EDITAR em cadastro/orcamentos/compras + aprovar em orcamentos
  INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
  SELECT v_adm_comercial, s, NULL, a
  FROM unnest(ARRAY[v_cadastro, v_orcamentos, v_compras]) AS s
  CROSS JOIN unnest(ARRAY['criar','editar','visualizar']) AS a
  ON CONFLICT (papel_id, system_id, modulo_id, acao) DO NOTHING;

  INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
  VALUES (v_adm_comercial, v_orcamentos, NULL, 'aprovar')
  ON CONFLICT (papel_id, system_id, modulo_id, acao) DO NOTHING;

  -- compras_e_entregas: CONSULTAR em cadastro; EDITAR em compras e logistica
  INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
  VALUES (v_compras_entregas, v_cadastro, NULL, 'visualizar')
  ON CONFLICT (papel_id, system_id, modulo_id, acao) DO NOTHING;

  INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
  SELECT v_compras_entregas, s, NULL, a
  FROM unnest(ARRAY[v_compras, v_logistica]) AS s
  CROSS JOIN unnest(ARRAY['criar','editar','visualizar']) AS a
  ON CONFLICT (papel_id, system_id, modulo_id, acao) DO NOTHING;

  -- equipe_projetos: EDITAR em crm/compras/logistica; EDITAR SEM CADASTRAR em cadastro/orcamentos
  INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
  SELECT v_equipe_projetos, s, NULL, a
  FROM unnest(ARRAY[v_crm, v_compras, v_logistica]) AS s
  CROSS JOIN unnest(ARRAY['criar','editar','visualizar']) AS a
  ON CONFLICT (papel_id, system_id, modulo_id, acao) DO NOTHING;

  INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
  SELECT v_equipe_projetos, s, NULL, a
  FROM unnest(ARRAY[v_cadastro, v_orcamentos]) AS s
  CROSS JOIN unnest(ARRAY['editar','visualizar']) AS a
  ON CONFLICT (papel_id, system_id, modulo_id, acao) DO NOTHING;

  -- equipe_entrega: CONSULTAR em orcamentos; EDITAR em logistica
  INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
  VALUES (v_equipe_entrega, v_orcamentos, NULL, 'visualizar')
  ON CONFLICT (papel_id, system_id, modulo_id, acao) DO NOTHING;

  INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
  SELECT v_equipe_entrega, v_logistica, NULL, a
  FROM unnest(ARRAY['criar','editar','visualizar']) AS a
  ON CONFLICT (papel_id, system_id, modulo_id, acao) DO NOTHING;
END $$;

-- 3) Atribuição de papel aos usuários já confirmados (usuarios.id) — Carol
-- não tem linha em `usuarios` ainda (só em `funcionarios`, id
-- 9e1873cf-3932-42fa-9189-204211137d21), fica pendente até ela ter login
-- (fluxo de cadastro de usuário da Central, SPEC-059).

DO $$
DECLARE
  v_admin_geral uuid := (SELECT id FROM public.papeis WHERE nome = 'admin_geral');
  v_rh_admin uuid := (SELECT id FROM public.papeis WHERE nome = 'rh_administracao');
  v_compras_entregas uuid := (SELECT id FROM public.papeis WHERE nome = 'compras_e_entregas');
  v_equipe_projetos uuid := (SELECT id FROM public.papeis WHERE nome = 'equipe_projetos');
BEGIN
  INSERT INTO public.usuario_papeis (usuario_id, papel_id)
  VALUES ('935f1eb3-b18a-4b08-936d-b11313f6bff6', v_admin_geral) -- Vinicius
  ON CONFLICT (usuario_id, papel_id) DO NOTHING;

  INSERT INTO public.usuario_papeis (usuario_id, papel_id)
  VALUES ('8bb35a84-22e7-40e3-b4c5-f1aecf1f3879', v_rh_admin) -- Lana
  ON CONFLICT (usuario_id, papel_id) DO NOTHING;

  INSERT INTO public.usuario_papeis (usuario_id, papel_id)
  VALUES ('78c716d7-9ca2-4449-8ac6-50c1905d21ef', v_compras_entregas) -- Debora
  ON CONFLICT (usuario_id, papel_id) DO NOTHING;

  INSERT INTO public.usuario_papeis (usuario_id, papel_id)
  VALUES ('64ca0580-3391-4758-8c7f-1e9051017f73', v_equipe_projetos) -- Mariane
  ON CONFLICT (usuario_id, papel_id) DO NOTHING;
END $$;
