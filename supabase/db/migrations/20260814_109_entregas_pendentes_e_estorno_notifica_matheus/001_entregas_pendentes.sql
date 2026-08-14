-- Pedido do usuário (14/08, continuação do teste de ponta a ponta): quando uma
-- separação já registrada (Ag Separar ou além) for estornada, tem que aparecer
-- um card avisando o Matheus, com o motivo do cancelamento — mesmo padrão
-- descrito pelo Vinícius na reunião de 11/08 ("[09:57] Enquanto estiver aqui,
-- aguardando separar, tem que ter a notificação. Se estiver aqui e precisar
-- mudar alguma coisa, tem que avisar ele.").
--
-- Achado ao investigar onde esse card deveria aparecer: a aba "Pendentes" do
-- app de Logística (lucenera-logistics-b7cd1) já tem exatamente esse formato
-- de card ("Motivo da Pendência" em destaque), mas está completamente sem
-- função — o hook `useEntregasPendentes` lê da tabela `entregas_pendentes`,
-- que nunca existiu no banco real (nem local, nem produção). A tela sempre
-- mostrava "Nenhuma pendência! Tudo em dia" — na verdade um erro de query
-- silencioso, não um estado vazio de verdade.
--
-- Esta migration cria a tabela de verdade (destravando a aba Pendentes pro
-- uso normal dela também, não só para este caso) e conecta o estorno de
-- separação parcial pra criar uma pendência aqui.

CREATE TABLE public.entregas_pendentes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  separacao_id uuid REFERENCES public.separacoes(id) ON DELETE SET NULL,
  codigo_obra text NOT NULL,
  cliente text NOT NULL,
  endereco text,
  responsavel text,
  telefone text,
  tipo_problema text NOT NULL,
  descricao_problema text NOT NULL,
  fotos_urls jsonb,
  registrado_por text NOT NULL,
  registrado_por_user_id uuid,
  data_registro timestamptz NOT NULL DEFAULT now(),
  status_pendencia text NOT NULL DEFAULT 'aguardando_resolucao'
    CHECK (status_pendencia IN ('aguardando_resolucao', 'em_analise', 'resolvido', 'cancelado')),
  resolved_at timestamptz,
  resolved_by text,
  resolved_by_user_id uuid,
  fotos_resolucao jsonb,
  observacoes_resolucao text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_entregas_pendentes_separacao ON public.entregas_pendentes(separacao_id);
CREATE INDEX idx_entregas_pendentes_status ON public.entregas_pendentes(status_pendencia);

ALTER TABLE public.entregas_pendentes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "entregas_pendentes_select_auth" ON public.entregas_pendentes
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "entregas_pendentes_insert_auth" ON public.entregas_pendentes
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "entregas_pendentes_update_auth" ON public.entregas_pendentes
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "entregas_pendentes_delete_auth" ON public.entregas_pendentes
  FOR DELETE TO authenticated USING (true);

-- Atualiza estornar_separacao_parcial (SPEC-090) pra também criar a
-- pendência visível em Logística — além de continuar anotando nas
-- observações da entrega vinculada (quando já existir), que é onde a tela
-- de Logística deveria ter lido desde a SPEC-089 mas nunca leu.
CREATE OR REPLACE FUNCTION public.estornar_separacao_parcial(p_separacao_id uuid, p_observacao text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_status text;
  v_item record;
  v_registrado_por text;
BEGIN
  IF p_observacao IS NULL OR btrim(p_observacao) = '' THEN
    RAISE EXCEPTION 'Informe o motivo do estorno.' USING ERRCODE = 'P0001';
  END IF;

  SELECT status INTO v_status FROM public.separacoes WHERE id = p_separacao_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Separação % não encontrada.', p_separacao_id USING ERRCODE = 'P0001';
  END IF;
  IF v_status = 'Cancelado' THEN
    RAISE EXCEPTION 'Essa separação já foi estornada.' USING ERRCODE = 'P0001';
  END IF;

  FOR v_item IN
    SELECT projeto_item_id, quantidade
    FROM public.separacao_itens
    WHERE separacao_id = p_separacao_id
  LOOP
    UPDATE public.estoque_saldos_projeto_item
    SET q_reserva = q_reserva + v_item.quantidade,
        q_ag_separar = GREATEST(q_ag_separar - v_item.quantidade, 0),
        atualizado_em = now()
    WHERE projeto_item_id = v_item.projeto_item_id;

    INSERT INTO public.estoque_movimentos_projeto_item
      (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
    VALUES
      (v_item.projeto_item_id, 'cancelamento', v_item.quantidade, 'separacao_parcial',
       p_separacao_id, p_observacao, auth.uid());
  END LOOP;

  UPDATE public.separacoes
  SET status = 'Cancelado',
      observacoes = trim(both E'\n' from coalesce(observacoes || E'\n', '') || 'Estornado: ' || p_observacao),
      alterado_apos_registro = true,
      alterado_em = now(),
      alterado_por = auth.uid()
  WHERE id = p_separacao_id;

  -- Aviso ao logístico: se já existir uma entrega vinculada (a separação
  -- tinha completado a venda via SPEC-089), anota o estorno nas
  -- observações dela — visível na tela de Logística sem precisar de
  -- infraestrutura de notificação nova.
  UPDATE public.entregas
  SET observacoes = trim(both E'\n' from coalesce(observacoes || E'\n', '') ||
    '⚠ Separação de origem estornada em ' || to_char(now(), 'DD/MM/YYYY HH24:MI') ||
    ' — revisar antes de entregar. Motivo: ' || p_observacao)
  WHERE separacao_id = p_separacao_id
    AND status <> 'Cancelado';

  -- Card visível na aba "Pendentes" do app de Logística — cobre qualquer
  -- estágio (Ag Separar ou além), já que o Matheus pode ter começado a
  -- separar fisicamente mesmo antes do sistema marcar "Pronto".
  SELECT nome INTO v_registrado_por FROM public.usuarios WHERE id = auth.uid();

  INSERT INTO public.entregas_pendentes (
    separacao_id, codigo_obra, cliente, endereco, responsavel, telefone,
    tipo_problema, descricao_problema, registrado_por, registrado_por_user_id
  )
  SELECT
    s.id,
    coalesce(s.codigo_obra, s.numero_venda, 'Sem código'),
    coalesce(s.cliente, 'Cliente não identificado'),
    s.endereco_entrega,
    s.responsavel_recebimento,
    s.telefone,
    'separacao_estornada',
    'Separação (venda ' || coalesce(s.numero_venda, '?') || ') foi estornada. Motivo: ' || p_observacao,
    coalesce(v_registrado_por, 'Sistema'),
    auth.uid()
  FROM public.separacoes s
  WHERE s.id = p_separacao_id;

  RETURN jsonb_build_object('separacao_id', p_separacao_id, 'status', 'Cancelado');
END;
$function$;
