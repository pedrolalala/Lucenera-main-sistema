-- SPEC-246 (05/11, pedido do usuário): "o que está em aberto e o que está pago hoje fica em uma planilha separada no Supabase".
--  * financeiro_posicao_diaria: RETRATO congelado do Contas a Receber e do Contas a Pagar em uma data — uma linha por parcela (duplicata) em aberto ou paga, com todos os dados
--    legíveis (empresa, pessoa, plano de contas, projeto, venda, nota, datas, valores, forma, conta bancária, origem Connect/sistema). Cancelada não entra.
--    IMUTÁVEL: um gatilho recusa alterar ou apagar. Serve de ponto de partida para comparar com o que o sistema novo registrar daqui em diante.
--  * congelar_posicao_financeira(data): tira o retrato do momento (idempotente por data+parcela). Só service_role/administração executa.
--  * vw_financeiro_posicao_resumo: totais por data, Receber/Pagar, situação e empresa.
--  * Esta migration já tira o retrato de HOJE (05/11/2026).
-- Não altera transacoes, negociacoes, boletos nem valores.
BEGIN;

CREATE TABLE IF NOT EXISTS public.financeiro_posicao_diaria (
  id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  data_posicao         date        NOT NULL,
  tirado_em            timestamptz NOT NULL DEFAULT now(),
  tipo_conta           text        NOT NULL CHECK (tipo_conta IN ('receber', 'pagar')),
  situacao             text        NOT NULL CHECK (situacao IN ('aberto', 'pago')),
  vencida              boolean     NOT NULL DEFAULT false,
  origem               text        NOT NULL CHECK (origem IN ('connect', 'sistema')),
  transacao_id         uuid        NOT NULL,
  negociacao_id        uuid,
  empresa              text,
  empresa_id           uuid,
  cod_duplicata        integer,
  cod_itens_duplicata  integer,
  num_parc             integer,
  total_parc           integer,
  pessoa               text,
  contato_id           uuid,
  cod_pessoa           integer,
  plano_de_contas      text,
  projeto_codigo       text,
  projeto_id           uuid,
  cod_venda            integer,
  num_nota             bigint,
  descricao            text,
  dt_emissao           date,
  dt_vencimento        date,
  dt_pagamento         date,
  vl_parcela           numeric(14,2),
  vl_desconto          numeric(14,2),
  vl_juros             numeric(14,2),
  vl_pago              numeric(14,2),
  forma_pagamento      text,
  conta_bancaria       text,
  perfil               text,
  UNIQUE (data_posicao, transacao_id)
);
CREATE INDEX IF NOT EXISTS ix_fin_posicao_data ON public.financeiro_posicao_diaria (data_posicao, tipo_conta, situacao);
CREATE INDEX IF NOT EXISTS ix_fin_posicao_cod ON public.financeiro_posicao_diaria (data_posicao, cod_itens_duplicata);

ALTER TABLE public.financeiro_posicao_diaria ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.financeiro_posicao_diaria FROM anon, authenticated;
GRANT SELECT ON public.financeiro_posicao_diaria TO authenticated;
GRANT ALL ON public.financeiro_posicao_diaria TO service_role;
DROP POLICY IF EXISTS financeiro_posicao_diaria_select ON public.financeiro_posicao_diaria;
CREATE POLICY financeiro_posicao_diaria_select ON public.financeiro_posicao_diaria FOR SELECT TO authenticated
  USING ((SELECT public.pode_acessar_sistema('financeiro')));

CREATE OR REPLACE FUNCTION public.trg_financeiro_posicao_imutavel()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $f$
BEGIN
  RAISE EXCEPTION 'A posição financeira diária é um retrato congelado: não pode ser alterada nem apagada. Tire um novo retrato com congelar_posicao_financeira().' USING ERRCODE = 'P0001';
END $f$;
DROP TRIGGER IF EXISTS trg_financeiro_posicao_imutavel ON public.financeiro_posicao_diaria;
CREATE TRIGGER trg_financeiro_posicao_imutavel BEFORE UPDATE OR DELETE ON public.financeiro_posicao_diaria
  FOR EACH ROW EXECUTE FUNCTION public.trg_financeiro_posicao_imutavel();

CREATE OR REPLACE FUNCTION public.congelar_posicao_financeira(p_data date DEFAULT current_date)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE v_n bigint;
BEGIN
  INSERT INTO public.financeiro_posicao_diaria
    (data_posicao, tipo_conta, situacao, vencida, origem, transacao_id, negociacao_id, empresa, empresa_id, cod_duplicata, cod_itens_duplicata, num_parc, total_parc,
     pessoa, contato_id, cod_pessoa, plano_de_contas, projeto_codigo, projeto_id, cod_venda, num_nota, descricao, dt_emissao, dt_vencimento, dt_pagamento,
     vl_parcela, vl_desconto, vl_juros, vl_pago, forma_pagamento, conta_bancaria, perfil)
  SELECT p_data,
         CASE t.tipo::text WHEN 'receita' THEN 'receber' ELSE 'pagar' END,
         CASE t.status_pago WHEN 1 THEN 'pago' ELSE 'aberto' END,
         (t.status_pago = 0 AND t.dt_vencimento < p_data),
         CASE WHEN t.cod_itens_duplicata IS NOT NULL THEN 'connect' ELSE 'sistema' END,
         t.id, t.negociacao_id, e.nome, n.empresa_id, n.cod_duplicata, t.cod_itens_duplicata, t.num_parc, n.total_parc,
         coalesce(nullif(btrim(n.nome_pessoa), ''), nullif(btrim(n.razao_pessoa), ''), k.nome, CASE WHEN n.cod_pessoa IS NOT NULL THEN 'Pessoa ' || n.cod_pessoa END),
         n.contato_id, n.cod_pessoa, pc.nome, pr.codigo::text, n.projeto_id, n.cod_venda, n.num_nota, t.descricao,
         t.dt_emissao::date, t.dt_vencimento::date, t.dt_pagamento::date,
         t.vl_parcela, t.vl_desconto, t.vl_juros, t.vl_pago, t.tipo_pagamento, cb.nome, t.perfil
    FROM public.transacoes t
    JOIN public.negociacoes n ON n.id = t.negociacao_id
    LEFT JOIN public.empresas e ON e.id = n.empresa_id
    LEFT JOIN public.contatos k ON k.id = n.contato_id
    LEFT JOIN public.plano_de_contas pc ON pc.id = n.plano_contas_id
    LEFT JOIN public.projetos pr ON pr.id = n.projeto_id
    LEFT JOIN public.contas_bancarias cb ON cb.id = t.conta_id
   WHERE t.status_pago IN (0, 1)
  ON CONFLICT (data_posicao, transacao_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $f$;
REVOKE ALL ON FUNCTION public.congelar_posicao_financeira(date) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.congelar_posicao_financeira(date) TO service_role;

CREATE OR REPLACE VIEW public.vw_financeiro_posicao_resumo WITH (security_invoker = true) AS
SELECT data_posicao, tipo_conta, situacao, empresa, origem,
       count(*)::bigint AS parcelas, coalesce(sum(vl_parcela), 0)::numeric AS valor_parcelas, coalesce(sum(vl_pago), 0)::numeric AS valor_pago,
       count(*) FILTER (WHERE vencida)::bigint AS vencidas, coalesce(sum(vl_parcela) FILTER (WHERE vencida), 0)::numeric AS valor_vencido
  FROM public.financeiro_posicao_diaria
 GROUP BY 1, 2, 3, 4, 5;
GRANT SELECT ON public.vw_financeiro_posicao_resumo TO authenticated;

-- retrato de HOJE
SELECT public.congelar_posicao_financeira(DATE '2026-11-05');

COMMIT;
