-- Migration 20260707_028 - SPEC-008 Parte 1
-- Conciliacao de Retorno Bancario e Baixa Automatica de Parcelas.
--
-- Correcao em relacao ao desenho original da SPEC: public.transacao_tipo real
-- e ('receita','despesa','transferencia'), nao inclui 'entrada' (placeholder
-- da SPEC). Usamos 'receita' para o recebimento de boleto.

CREATE TABLE public.retorno_bancario_arquivos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome_arquivo text NOT NULL,
  hash_conteudo text NOT NULL UNIQUE,
  conta text,
  processado_por uuid REFERENCES public.usuarios(id),
  processado_em timestamptz NOT NULL DEFAULT now(),
  total_registros integer NOT NULL DEFAULT 0,
  total_aplicados integer NOT NULL DEFAULT 0,
  total_divergentes integer NOT NULL DEFAULT 0,
  total_nao_encontrados integer NOT NULL DEFAULT 0,
  forcado boolean NOT NULL DEFAULT false
);

COMMENT ON TABLE public.retorno_bancario_arquivos IS
'SPEC-008. Um registro por arquivo de retorno CNAB processado, com hash do conteudo para bloquear reprocessamento acidental.';

CREATE TABLE public.retorno_bancario_registros (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  arquivo_id uuid NOT NULL REFERENCES public.retorno_bancario_arquivos(id) ON DELETE CASCADE,
  nosso_numero text NOT NULL,
  boleto_id uuid REFERENCES public.boletos(id),
  parcela_id uuid REFERENCES public.projeto_parcelas(id),
  transacao_id uuid REFERENCES public.transacoes(id),
  valor_esperado numeric(12,2),
  valor_recebido numeric(12,2),
  data_pagamento date,
  ocorrencia_codigo text,
  status_aplicacao text NOT NULL CHECK (status_aplicacao IN ('aplicado','divergente','nao_encontrado','ja_processado')),
  motivo_divergencia text
);

COMMENT ON TABLE public.retorno_bancario_registros IS
'SPEC-008. Um registro por linha do CNAB de retorno, com o resultado da aplicacao contra boletos/projeto_parcelas.';

CREATE INDEX idx_rbr_arquivo ON public.retorno_bancario_registros (arquivo_id);
CREATE INDEX idx_rbr_nosso_numero ON public.retorno_bancario_registros (nosso_numero);

ALTER TABLE public.retorno_bancario_arquivos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.retorno_bancario_registros ENABLE ROW LEVEL SECURITY;

-- Leitura ampla para authenticated (mesmo padrao ja usado em boletos:
-- authenticated_select_boletos ... USING (true)). Escrita exclusiva via RPC
-- SECURITY DEFINER (002_rpc.sql).
CREATE POLICY authenticated_select_retorno_bancario_arquivos
  ON public.retorno_bancario_arquivos
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

CREATE POLICY authenticated_select_retorno_bancario_registros
  ON public.retorno_bancario_registros
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.retorno_bancario_arquivos TO authenticated;
GRANT SELECT ON TABLE public.retorno_bancario_registros TO authenticated;
