-- SPEC-282 Parte A: regras do orcamento (validade e aviso de preco) em tabela editavel, em vez do "10" fixo no codigo.
-- Leitura: quem acessa o sistema Orcamentos. Escrita: so admin, pela funcao orcamento_regra_salvar.
BEGIN;

CREATE TABLE IF NOT EXISTS public.orcamento_regras (
  chave            text PRIMARY KEY,
  valor            jsonb NOT NULL,
  valor_anterior   jsonb,
  vigente_desde    timestamptz NOT NULL DEFAULT now(),
  descricao        text,
  atualizado_em    timestamptz NOT NULL DEFAULT now(),
  atualizado_por   uuid,
  atualizado_por_nome text
);

ALTER TABLE public.orcamento_regras ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.orcamento_regras FROM anon, authenticated;
GRANT SELECT ON public.orcamento_regras TO authenticated;
CREATE POLICY orcamento_regras_select ON public.orcamento_regras
  FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('orcamentos')));

INSERT INTO public.orcamento_regras (chave, valor, valor_anterior, descricao) VALUES
 ('validade_dias', '10'::jsonb, '10'::jsonb,
  'Validade padrao do orcamento = data de emissao + N dias. Vale para orcamentos novos; os antigos sem validade gravada usam o valor anterior.'),
 ('aviso_preco_dias', '10'::jsonb, NULL,
  'Ao abrir para editar um orcamento com mais de N dias de emissao (ou com a validade vencida), pergunta se quer atualizar os precos.'),
 ('aviso_preco_quando_mudou', 'true'::jsonb, NULL,
  'Tambem pergunta quando alguma peca do orcamento teve o preco de venda reajustado no cadastro.'),
 ('status_que_avisam', '["rascunho","Aprovação da Equipe","enviado_cliente","Aprovação Financeira"]'::jsonb, NULL,
  'Em quais status o aviso de preco aparece. Orcamento aprovado e devolucao nunca avisam.')
ON CONFLICT (chave) DO NOTHING;

CREATE OR REPLACE FUNCTION public.pode_editar_regras_orcamento()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT COALESCE(auth.role(), '') = 'service_role'
      OR EXISTS (SELECT 1 FROM public.usuarios u
                 WHERE u.id = auth.uid() AND u.role::text = 'admin' AND COALESCE(u.ativo, true));
$$;
REVOKE ALL ON FUNCTION public.pode_editar_regras_orcamento() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_editar_regras_orcamento() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.orcamento_regra_salvar(p_chave text, p_valor jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_nome text; v_atual jsonb; v_status_ok text[] := ARRAY['rascunho','Aprovação da Equipe','enviado_cliente','Aprovação Financeira'];
BEGIN
  IF NOT public.pode_editar_regras_orcamento() THEN
    RAISE EXCEPTION 'Somente administrador altera as regras do orcamento.' USING ERRCODE = 'P0001';
  END IF;
  SELECT valor INTO v_atual FROM public.orcamento_regras WHERE orcamento_regras.chave = p_chave FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Regra desconhecida: %', p_chave USING ERRCODE = 'P0001';
  END IF;

  IF p_chave IN ('validade_dias', 'aviso_preco_dias') THEN
    IF jsonb_typeof(p_valor) <> 'number' OR (p_valor #>> '{}')::numeric <> trunc((p_valor #>> '{}')::numeric)
       OR (p_valor #>> '{}')::numeric < 1 OR (p_valor #>> '{}')::numeric > 365 THEN
      RAISE EXCEPTION 'Informe um numero inteiro de dias entre 1 e 365.' USING ERRCODE = 'P0001';
    END IF;
  ELSIF p_chave = 'aviso_preco_quando_mudou' THEN
    IF jsonb_typeof(p_valor) <> 'boolean' THEN
      RAISE EXCEPTION 'Valor deve ser ligado ou desligado.' USING ERRCODE = 'P0001';
    END IF;
  ELSIF p_chave = 'status_que_avisam' THEN
    IF jsonb_typeof(p_valor) <> 'array' OR EXISTS (
         SELECT 1 FROM jsonb_array_elements_text(p_valor) s WHERE s <> ALL (v_status_ok)) THEN
      RAISE EXCEPTION 'Lista de status invalida.' USING ERRCODE = 'P0001';
    END IF;
  END IF;

  SELECT COALESCE(u.nome, u.email) INTO v_nome FROM public.usuarios u WHERE u.id = auth.uid();
  IF v_atual IS DISTINCT FROM p_valor THEN
    UPDATE public.orcamento_regras
       SET valor_anterior = v_atual, valor = p_valor, vigente_desde = now(),
           atualizado_em = now(), atualizado_por = auth.uid(), atualizado_por_nome = v_nome
     WHERE orcamento_regras.chave = p_chave;
  END IF;
  RETURN jsonb_build_object('chave', p_chave, 'valor', p_valor);
END $$;
REVOKE ALL ON FUNCTION public.orcamento_regra_salvar(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.orcamento_regra_salvar(text, jsonb) TO authenticated, service_role;

COMMIT;
