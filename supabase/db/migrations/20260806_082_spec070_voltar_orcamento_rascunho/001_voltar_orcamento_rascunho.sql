-- Migration 20260806_082 (SPEC-070)
-- Nova RPC public.voltar_orcamento_rascunho: permite que admin/gerente
-- volte um orçamento de enviado_cliente ou recusado_cliente para rascunho,
-- invalidando o token de aprovação do cliente e registrando o motivo em
-- historico_status_orcamentos.
--
-- Modelada em public.equipe_devolver_orcamento_cliente
-- (supabase/db/migrations/20260718_050_spec031_aprovacao_equipe_orcamentos/003_rpcs_equipe_aprovar_devolver.sql,
-- linhas 70-133), com duas diferenças de propósito (ver SPEC-070,
-- "Decisões aprovadas" P-1/P-2/P-3/P-4):
--   1. Guarda de status de entrada: enviado_cliente/recusado_cliente (não
--      "Aprovação da Equipe").
--   2. Permissão: apenas admin/gerente, sem fallback via hub_pode_executar
--      (decisão literal do usuário — mais restrita que o modelo).
--
-- Efeito: status -> rascunho, token_aprovacao_cliente -> NULL. Os campos
-- enviado_cliente_em/enviado_cliente_por/recusado_cliente_em NÃO são
-- apagados (ficam como registro histórico de que o envio/recusa
-- aconteceu; a transição completa fica em historico_status_orcamentos).

CREATE OR REPLACE FUNCTION public.voltar_orcamento_rascunho(
  p_orcamento_id uuid,
  p_motivo text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
  v_user_role text;
BEGIN
  IF p_motivo IS NULL OR btrim(p_motivo) = '' THEN
    RAISE EXCEPTION 'Informe o motivo antes de voltar o orçamento para rascunho.' USING ERRCODE = 'P0001';
  END IF;

  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  IF v_user_role NOT IN ('admin', 'gerente') THEN
    RAISE EXCEPTION 'Apenas admin ou gerente podem voltar um orçamento para rascunho.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status NOT IN ('enviado_cliente', 'recusado_cliente') THEN
    RAISE EXCEPTION 'Orçamento % não pode voltar para rascunho a partir do status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.orcamentos
  SET status = 'rascunho',
      token_aprovacao_cliente = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'rascunho', auth.uid()::text, p_motivo);

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero', v_numero, 'status', 'rascunho');
END;
$function$;

COMMENT ON FUNCTION public.voltar_orcamento_rascunho(uuid, text) IS
'SPEC-070. Transição enviado_cliente|recusado_cliente -> rascunho, disparada
manualmente por admin/gerente quando o cliente pede alteração antes de
aprovar. Invalida token_aprovacao_cliente (link antigo deixa de funcionar).
Não gera token novo — isso só volta a acontecer quando o orçamento for
reenviado via enviar_orcamento_para_cliente. p_motivo é obrigatório e fica
registrado em historico_status_orcamentos.observacao. Sem fallback via
hub_pode_executar (diferente de equipe_devolver_orcamento_cliente) —
decisão literal do usuário: só admin/gerente.';

GRANT EXECUTE ON FUNCTION public.voltar_orcamento_rascunho(uuid, text) TO authenticated;
