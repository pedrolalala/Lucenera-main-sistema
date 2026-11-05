-- SPEC-245 (05/11, pedido do usuário): "a planilha tem que ser um ESPELHO" — o nome da pessoa do Contas a Receber/Pagar aparecia vazio ("null").
--  * connect_contas_espelho: cópia 1:1, linha a linha, das planilhas ContaReceber/ContaPagar do dia (as 50 colunas, com a chave da Connect:
--    tipo + cod_itens_duplicata). É recarregada por scripts/carregar_espelho_contas_connect.py a cada carga e é a resposta a "onde está a planilha no Supabase".
--    Só leitura para quem tem o sistema financeiro liberado; só a carga (service_role) grava.
--  * negociacoes.nome_pessoa / razao_pessoa: nome da pessoa COMO A PLANILHA DIZ, para as telas nunca mostrarem vazio (ordem: planilha > cadastro > "Pessoa <código>").
-- Não mexe em transações, valores, estoque, vendas nem nos contatos.
BEGIN;

CREATE TABLE IF NOT EXISTS public.connect_contas_espelho (
  tipo                text    NOT NULL CHECK (tipo IN ('receita', 'despesa')),
  cod_itens_duplicata integer NOT NULL,
  tipo_operacao       text,
  cod_empresa         integer,
  nm_empresa          text,
  desc_perfil_empresa text,
  cod_duplicata       integer,
  acordo              integer,
  tipo_nota           integer,
  cod_venda           integer,
  num_nota            integer,
  n_documento         text,
  antecipacao         numeric(14,2),
  dev_troca           integer,
  cod_saida_pgto      integer,
  cod_apropriacao     integer,
  desc_apropriacao    text,
  cod_grupo           integer,
  desc_grupo          text,
  cod_sub_grupo       integer,
  desc_sub_grupo      text,
  cod_conta           integer,
  desc_conta          text,
  desc_condpagto      text,
  tipo_pagamento      text,
  num_parc            integer,
  total_parc          integer,
  cod_pessoa          integer,
  nome_pessoa         text,
  razao_pessoa        text,
  tel_pessoa          text,
  email_financeiro    text,
  nm_funcionario      text,
  dt_emissao          date,
  dt_vencimento       date,
  dt_pagamento        timestamp,
  data_baixa          timestamp,
  dt_ultimo_pgto      date,
  vl_duplicata        numeric(14,2),
  vl_parcela          numeric(14,2),
  vl_desconto         numeric(14,2),
  vl_juros            numeric(14,2),
  vl_pago             numeric(14,2),
  pago                integer,
  vl_frete            numeric(14,2),
  vl_ipi              numeric(14,2),
  vl_st               numeric(14,2),
  lancamento          integer,
  layout_boleto       text,
  nosso_numero        text,
  observacao          text,
  arquivo_origem      text,
  carregado_em        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tipo, cod_itens_duplicata)
);
CREATE INDEX IF NOT EXISTS idx_connect_contas_espelho_dup ON public.connect_contas_espelho (tipo, cod_duplicata);
CREATE INDEX IF NOT EXISTS idx_connect_contas_espelho_pessoa ON public.connect_contas_espelho (cod_pessoa);
COMMENT ON TABLE public.connect_contas_espelho IS
  'SPEC-245: espelho 1:1 das planilhas ContaReceber (tipo=receita) e ContaPagar (tipo=despesa) da Connect; recarregado a cada carga. Chave = tipo + cod_itens_duplicata (igual a transacoes.cod_itens_duplicata).';

ALTER TABLE public.connect_contas_espelho ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.connect_contas_espelho FROM anon, authenticated;
GRANT SELECT ON public.connect_contas_espelho TO authenticated;
GRANT ALL ON public.connect_contas_espelho TO service_role;
DROP POLICY IF EXISTS connect_contas_espelho_select ON public.connect_contas_espelho;
CREATE POLICY connect_contas_espelho_select ON public.connect_contas_espelho
  FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('financeiro'::text)));

ALTER TABLE public.negociacoes ADD COLUMN IF NOT EXISTS nome_pessoa text, ADD COLUMN IF NOT EXISTS razao_pessoa text;
COMMENT ON COLUMN public.negociacoes.nome_pessoa IS 'SPEC-245: nome da pessoa como a planilha da Connect diz (atualizado a cada carga do espelho).';
COMMENT ON COLUMN public.negociacoes.razao_pessoa IS 'SPEC-245: razão social da pessoa como a planilha da Connect diz.';

COMMIT;
