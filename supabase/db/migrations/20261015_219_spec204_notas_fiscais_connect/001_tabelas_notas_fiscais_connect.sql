-- SPEC-204 (15/10/2026): notas fiscais emitidas pela Connect, importadas dos XMLs (NF-e 4.00).
-- Separadas de notas_fiscais (essa é das notas que o Vendas emite pela Focus NFe).
-- Leitura: quem tem o sistema Vendas em Acesso a Sistemas. Gravação: só o script
-- scripts/importar_nfe_connect.py (conexão direta) — a tela é só consulta.
-- O XML original fica guardado na linha (xml) para conferência e reimportação.
BEGIN;

CREATE TABLE public.notas_fiscais_connect (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chave_nfe text NOT NULL UNIQUE CHECK (chave_nfe ~ '^\d{44}$'),
  empresa_id uuid REFERENCES public.empresas(id),
  numero integer NOT NULL,
  serie integer,
  modelo text,
  data_emissao timestamptz NOT NULL,
  data_saida timestamptz,
  natureza_operacao text,
  tipo_nf smallint,                 -- 0 entrada, 1 saída
  finalidade smallint,              -- 1 normal, 2 complementar, 3 ajuste, 4 devolução
  cfop_principal text,
  emitente_cnpj text NOT NULL,
  emitente_nome text,
  destinatario_tipo text CHECK (destinatario_tipo IN ('CPF', 'CNPJ', 'ESTRANGEIRO')),
  destinatario_documento text,
  destinatario_nome text,
  destinatario_ie text,
  destinatario_email text,
  destinatario_municipio text,
  destinatario_uf text,
  cliente_id uuid REFERENCES public.contatos(id) ON DELETE SET NULL,
  orcamento_id uuid REFERENCES public.orcamentos(id) ON DELETE SET NULL,
  valor_produtos numeric(14,2),
  valor_desconto numeric(14,2),
  valor_frete numeric(14,2),
  valor_seguro numeric(14,2),
  valor_outros numeric(14,2),
  valor_ipi numeric(14,2),
  valor_icms numeric(14,2),
  valor_st numeric(14,2),
  valor_total numeric(14,2) NOT NULL,
  forma_pagamento text,             -- tPag do primeiro detPag (01 dinheiro, 14 duplicata, 90 sem pagamento...)
  modalidade_frete smallint,
  informacoes_complementares text,
  protocolo text,
  data_autorizacao timestamptz,
  status_sefaz text,
  situacao text NOT NULL DEFAULT 'autorizada' CHECK (situacao IN ('autorizada', 'cancelada')),
  cancelada_em timestamptz,
  arquivo_nome text,
  xml text NOT NULL,
  importado_em timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notas_fiscais_connect_emissao_idx ON public.notas_fiscais_connect (empresa_id, data_emissao DESC);
CREATE INDEX notas_fiscais_connect_cliente_idx ON public.notas_fiscais_connect (cliente_id);
CREATE INDEX notas_fiscais_connect_orcamento_idx ON public.notas_fiscais_connect (orcamento_id);

CREATE TABLE public.notas_fiscais_connect_itens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_id uuid NOT NULL REFERENCES public.notas_fiscais_connect(id) ON DELETE CASCADE,
  numero_item integer NOT NULL,
  codigo_produto text,              -- cProd (código da peça na Connect)
  produto_id uuid REFERENCES public.produtos(id) ON DELETE SET NULL,
  descricao text,
  ncm text,
  cest text,
  cfop text,
  unidade text,
  quantidade numeric(15,4),
  valor_unitario numeric(20,10),
  valor_total numeric(14,2),
  valor_desconto numeric(14,2),
  valor_frete numeric(14,2),
  valor_outros numeric(14,2),
  valor_icms numeric(14,2),
  valor_st numeric(14,2),
  valor_ipi numeric(14,2),
  UNIQUE (nota_id, numero_item)
);
CREATE INDEX notas_fiscais_connect_itens_produto_idx ON public.notas_fiscais_connect_itens (produto_id);

CREATE TABLE public.notas_fiscais_connect_duplicatas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_id uuid NOT NULL REFERENCES public.notas_fiscais_connect(id) ON DELETE CASCADE,
  numero text NOT NULL,
  vencimento date,
  valor numeric(14,2),
  UNIQUE (nota_id, numero)
);

-- Carta de correção (110110), cancelamento (110111)... O evento pode chegar antes da nota,
-- por isso guarda a chave; nota_id é preenchido quando a nota existe.
CREATE TABLE public.notas_fiscais_connect_eventos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chave_nfe text NOT NULL CHECK (chave_nfe ~ '^\d{44}$'),
  nota_id uuid REFERENCES public.notas_fiscais_connect(id) ON DELETE CASCADE,
  tipo_evento text NOT NULL,
  descricao text,
  sequencia integer NOT NULL DEFAULT 1,
  data_evento timestamptz,
  correcao text,
  justificativa text,
  protocolo text,
  status_sefaz text,
  arquivo_nome text,
  xml text NOT NULL,
  importado_em timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chave_nfe, tipo_evento, sequencia)
);
CREATE INDEX notas_fiscais_connect_eventos_nota_idx ON public.notas_fiscais_connect_eventos (nota_id);

ALTER TABLE public.notas_fiscais_connect ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_fiscais_connect_itens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_fiscais_connect_duplicatas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_fiscais_connect_eventos ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.notas_fiscais_connect, public.notas_fiscais_connect_itens,
  public.notas_fiscais_connect_duplicatas, public.notas_fiscais_connect_eventos FROM anon, authenticated;
GRANT SELECT ON public.notas_fiscais_connect, public.notas_fiscais_connect_itens,
  public.notas_fiscais_connect_duplicatas, public.notas_fiscais_connect_eventos TO authenticated;

CREATE POLICY notas_fiscais_connect_select ON public.notas_fiscais_connect
  FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('vendas')));
CREATE POLICY notas_fiscais_connect_itens_select ON public.notas_fiscais_connect_itens
  FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('vendas')));
CREATE POLICY notas_fiscais_connect_duplicatas_select ON public.notas_fiscais_connect_duplicatas
  FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('vendas')));
CREATE POLICY notas_fiscais_connect_eventos_select ON public.notas_fiscais_connect_eventos
  FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('vendas')));

COMMENT ON TABLE public.notas_fiscais_connect IS
  'SPEC-204: NF-e emitidas pela Connect, importadas dos XMLs por scripts/importar_nfe_connect.py. Leitura: sistema Vendas.';

COMMIT;
