-- SPEC-200 (14/10, pedido do usuário após a apresentação):
-- A) Equipe de Projetos consegue "Aprovar Manualmente" (aprovação do cliente). Antes só role admin/gerente/operador;
--    agora também quem tem o módulo novo "aprovacao_cliente" (editar) no Hub — dado ao papel equipe_projetos.
--    Aprovação Financeira não muda.
-- B) Todo orçamento tem equipe (orcamentos.equipe_id). Sem equipe informada, pega do projeto, depois do vendedor,
--    depois de quem digitou; se ainda faltar, o banco recusa (só quando é um usuário logado gravando).
-- C) digitado_por = quem estava logado ao criar (o banco grava, não dá para trocar depois).
-- D) Quem é só da Equipe de Projetos (papel equipe_projetos e nenhum outro, role não admin/gerente) vê apenas os
--    orçamentos da própria equipe e os que digitou. Admin, gerente e quem tem outro papel (ex.: Administração) veem tudo.

BEGIN;

-- B) coluna equipe ---------------------------------------------------------------------------------------------
ALTER TABLE public.orcamentos
  ADD COLUMN IF NOT EXISTS equipe_id uuid REFERENCES public.equipes_projetos(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_orcamentos_equipe_id ON public.orcamentos (equipe_id);

UPDATE public.orcamentos o
SET equipe_id = COALESCE(
  (SELECT p.equipe_id FROM public.projetos p WHERE p.id = o.projeto_id),
  (SELECT f.equipe_id FROM public.funcionarios f WHERE f.id = o.vendedor_id),
  (SELECT f.equipe_id FROM public.funcionarios f WHERE f.usuario_id = o.digitado_por AND f.equipe_id IS NOT NULL LIMIT 1)
)
WHERE o.equipe_id IS NULL;

-- D) de qual equipe o usuário logado está "preso" -------------------------------------------------------------
-- NULL = vê todos. Membro da equipe sem equipe cadastrada recebe um id que não existe (vê só o que digitou).
CREATE OR REPLACE FUNCTION public.orcamentos_equipe_restrita()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT f.equipe_id FROM public.funcionarios f
      WHERE f.usuario_id = u.id AND f.equipe_id IS NOT NULL
      ORDER BY (f.status = 'Ativo') DESC LIMIT 1),
    '00000000-0000-0000-0000-000000000000'::uuid)
  FROM public.usuarios u
  WHERE u.id = auth.uid()
    AND u.role::text NOT IN ('admin', 'gerente')
    AND EXISTS (SELECT 1 FROM public.usuario_papeis up JOIN public.papeis p ON p.id = up.papel_id
                WHERE up.usuario_id = u.id AND p.nome = 'equipe_projetos')
    AND NOT EXISTS (SELECT 1 FROM public.usuario_papeis up JOIN public.papeis p ON p.id = up.papel_id
                    WHERE up.usuario_id = u.id AND p.nome <> 'equipe_projetos');
$$;
REVOKE ALL ON FUNCTION public.orcamentos_equipe_restrita() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.orcamentos_equipe_restrita() TO authenticated;

-- Usada pelas RPCs SECURITY DEFINER (que pulam o RLS) para não agir em orçamento de outra equipe.
CREATE OR REPLACE FUNCTION public.orcamento_da_minha_equipe(p_equipe_id uuid, p_digitado_por uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.orcamentos_equipe_restrita() IS NULL
      OR p_equipe_id = public.orcamentos_equipe_restrita()
      OR p_digitado_por = auth.uid();
$$;
REVOKE ALL ON FUNCTION public.orcamento_da_minha_equipe(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.orcamento_da_minha_equipe(uuid, uuid) TO authenticated;

-- RESTRICTIVE: soma (E) com a política de leitura que já existe (spec196_orcamentos_select).
-- Vale também para UPDATE/DELETE, que só enxergam linhas visíveis no SELECT.
DROP POLICY IF EXISTS spec200_orcamentos_equipe ON public.orcamentos;
CREATE POLICY spec200_orcamentos_equipe ON public.orcamentos
  AS RESTRICTIVE
  FOR SELECT
  TO authenticated
  USING (
    (SELECT public.orcamentos_equipe_restrita()) IS NULL
    OR equipe_id = (SELECT public.orcamentos_equipe_restrita())
    OR digitado_por = (SELECT auth.uid())
  );

-- B + C) trigger: digitador pelo login e equipe obrigatória ---------------------------------------------------
CREATE OR REPLACE FUNCTION public.orcamento_definir_equipe_digitador()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF v_uid IS NOT NULL THEN
      NEW.digitado_por := v_uid;
    END IF;
  ELSIF OLD.digitado_por IS NOT NULL THEN
    NEW.digitado_por := OLD.digitado_por;
  END IF;

  IF NEW.equipe_id IS NULL AND NEW.projeto_id IS NOT NULL THEN
    SELECT p.equipe_id INTO NEW.equipe_id FROM public.projetos p WHERE p.id = NEW.projeto_id;
  END IF;
  IF NEW.equipe_id IS NULL AND NEW.vendedor_id IS NOT NULL THEN
    SELECT f.equipe_id INTO NEW.equipe_id FROM public.funcionarios f WHERE f.id = NEW.vendedor_id;
  END IF;
  IF NEW.equipe_id IS NULL AND NEW.digitado_por IS NOT NULL THEN
    SELECT f.equipe_id INTO NEW.equipe_id FROM public.funcionarios f
    WHERE f.usuario_id = NEW.digitado_por AND f.equipe_id IS NOT NULL LIMIT 1;
  END IF;

  IF NEW.equipe_id IS NULL AND v_uid IS NOT NULL THEN
    RAISE EXCEPTION 'Informe a equipe do orçamento.' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_1_orcamento_equipe_digitador ON public.orcamentos;
CREATE TRIGGER trg_1_orcamento_equipe_digitador
  BEFORE INSERT OR UPDATE ON public.orcamentos
  FOR EACH ROW EXECUTE FUNCTION public.orcamento_definir_equipe_digitador();

-- A) módulo "Aprovação do Cliente" no Hub, dado à Equipe de Projetos ------------------------------------------
INSERT INTO public.modulos (system_id, chave, nome, descricao, ordem)
SELECT s.id, 'aprovacao_cliente', 'Aprovação do Cliente (Orçamentos)',
       'Aprovar manualmente o orçamento em nome do cliente (aba Aprovação do Cliente).', 0
FROM public.systems s WHERE s.slug = 'orcamentos'
ON CONFLICT (system_id, chave) DO NOTHING;

INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, m.system_id, m.id, 'editar'
FROM public.papeis p
CROSS JOIN public.modulos m
JOIN public.systems s ON s.id = m.system_id AND s.slug = 'orcamentos'
WHERE p.nome = 'equipe_projetos' AND m.chave = 'aprovacao_cliente'
ON CONFLICT (papel_id, system_id, modulo_id, acao) DO NOTHING;

-- RPCs de aprovação: permissão + só orçamento da própria equipe -----------------------------------------------
CREATE OR REPLACE FUNCTION public.aprovar_orcamento_cliente(p_orcamento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero_orcamento text;
  v_user_role text;
BEGIN
  SELECT u.role INTO v_user_role
  FROM public.usuarios u
  WHERE u.id = auth.uid();

  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'Usuário não encontrado ou não autenticado.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    v_user_role IN ('admin', 'gerente', 'operador')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', 'aprovacao_cliente', 'editar')
  ) THEN
    RAISE EXCEPTION 'Permissão negada. Peça ao administrador o acesso "Aprovação do Cliente" no Hub. Role atual: %', v_user_role
      USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento
  FROM public.orcamentos
  WHERE id = p_orcamento_id
  FOR UPDATE;

  IF NOT FOUND OR NOT public.orcamento_da_minha_equipe(v_orcamento.equipe_id, v_orcamento.digitado_por) THEN
    RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id
      USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status NOT IN ('enviado_cliente', 'recusado_cliente', 'aguardando_cliente', 'rascunho') THEN
    RAISE EXCEPTION 'Orçamento % não pode ser aprovado no status atual: %', v_numero_orcamento, v_status_anterior
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação Financeira',
      aprovado_cliente_em = now(),
      aprovado_cliente_origem = 'manual',
      requer_revisao_financeira = true,
      token_aprovacao_cliente = null
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', auth.uid()::text, 'Aprovação do cliente finalizada — aguardando aprovação financeira');

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status_anterior', v_status_anterior,
    'status_novo', 'Aprovação Financeira',
    'sucesso', true
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.aprovar_orcamento_cliente_manual(p_orcamento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero_orcamento text;
  v_user_role text;
  v_prazos integer[];
BEGIN
  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();
  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'Usuário não encontrado ou não autenticado.' USING ERRCODE = 'P0001';
  END IF;
  IF NOT (
    v_user_role IN ('admin', 'gerente', 'operador')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', 'aprovacao_cliente', 'editar')
  ) THEN
    RAISE EXCEPTION 'Permissão negada. Peça ao administrador o acesso "Aprovação do Cliente" no Hub.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND OR NOT public.orcamento_da_minha_equipe(v_orcamento.equipe_id, v_orcamento.digitado_por) THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status NOT IN ('enviado_cliente', 'recusado_cliente', 'aguardando_cliente', 'rascunho') THEN
    RAISE EXCEPTION 'Orçamento % não pode ser aprovado manualmente no status atual: %', v_numero_orcamento, v_status_anterior
      USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.frete_tipo IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui condição de frete definida.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF v_orcamento.forma_pagamento IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui forma de pagamento estruturada.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF coalesce(v_orcamento.valor_total, 0) <= 0 THEN
    RAISE EXCEPTION 'Orçamento % possui valor total inválido.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.orcamento_itens oi
    WHERE oi.orcamento_id = p_orcamento_id AND oi.produto_id IS NULL AND coalesce(oi.preco_unitario, 0) <= 0
  ) THEN
    RAISE EXCEPTION 'Orçamento % possui item especial sem preço definido.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;

  v_prazos := public._lucenera_parse_prazo_pagamento(v_orcamento.condicoes_pagamento, v_orcamento.prazo_pagamento_dias);
  IF coalesce(array_length(v_prazos, 1), 0) = 0 THEN
    RAISE EXCEPTION 'Orçamento % não possui prazo de pagamento interpretável.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação Financeira',
      aprovado_cliente_em = now(),
      aprovado_cliente_origem = 'manual',
      requer_revisao_financeira = true,
      token_aprovacao_cliente = null
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', auth.uid()::text, 'Aprovação manual do cliente — aguardando aprovação financeira');

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id,
    'status', 'Aprovação Financeira',
    'sucesso', true
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.equipe_aprovar_orcamento(p_orcamento_id uuid, p_observacao text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
  v_user_role text;
BEGIN
  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  IF NOT (
    v_user_role IN ('admin', 'gerente')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', 'aprovacao_equipe', 'editar')
  ) THEN
    RAISE EXCEPTION 'Permissão negada para aprovar como equipe.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND OR NOT public.orcamento_da_minha_equipe(v_orcamento.equipe_id, v_orcamento.digitado_por) THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status <> 'Aprovação da Equipe' THEN
    RAISE EXCEPTION 'Orçamento % não está em Aprovação da Equipe. Status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação Financeira',
      requer_revisao_financeira = true
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', auth.uid()::text,
          COALESCE(p_observacao, 'Aprovado pela equipe após visita à obra — encaminhado para revisão financeira'));

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero', v_numero, 'status', 'Aprovação Financeira');
END;
$function$;

CREATE OR REPLACE FUNCTION public.equipe_devolver_orcamento_cliente(p_orcamento_id uuid, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
  v_user_role text;
BEGIN
  IF p_motivo IS NULL OR btrim(p_motivo) = '' THEN
    RAISE EXCEPTION 'Informe o motivo da alteração antes de devolver ao cliente.' USING ERRCODE = 'P0001';
  END IF;

  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  IF NOT (
    v_user_role IN ('admin', 'gerente')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', 'aprovacao_equipe', 'editar')
  ) THEN
    RAISE EXCEPTION 'Permissão negada para devolver orçamento ao cliente.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND OR NOT public.orcamento_da_minha_equipe(v_orcamento.equipe_id, v_orcamento.digitado_por) THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status <> 'Aprovação da Equipe' THEN
    RAISE EXCEPTION 'Orçamento % não está em Aprovação da Equipe. Status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.orcamentos
  SET status = 'enviado_cliente',
      token_aprovacao_cliente = public.gen_token_hex(),
      enviado_cliente_em = now(),
      enviado_cliente_por = auth.uid(),
      aprovado_cliente_em = NULL,
      aprovado_cliente_origem = NULL,
      requer_revisao_financeira = false
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'enviado_cliente', auth.uid()::text, p_motivo);

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero', v_numero, 'status', 'enviado_cliente');
END;
$function$;

NOTIFY pgrst, 'reload schema';

COMMIT;
