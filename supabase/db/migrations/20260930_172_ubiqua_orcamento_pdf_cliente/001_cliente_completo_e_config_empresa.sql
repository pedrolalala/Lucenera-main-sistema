-- Migration 20260930_172 - SPEC-172
--
-- 1) Cadastro completo do cliente do Catálogo Ubiqua (informacoes_cliente_ubiqua):
--    endereço principal, IE, regime tributário, e-mails comercial/financeiro,
--    transportadora e endereços de entrega/cobrança. Nomes de coluna iguais aos
--    de public.contatos (cadastro de cliente da Lucenera), para reaproveitar o
--    mesmo modelo. Só ADD COLUMN IF NOT EXISTS, nullable — as 7 linhas atuais
--    não mudam. RLS da tabela continua a mesma (vale por linha, não por coluna).
--
-- 2) configuracao_empresa_ubiqua: dados da PRÓPRIA Ubiqua usados no PDF/e-mail
--    do orçamento. empresa_ubiqua NÃO serve: é a tabela das empresas parceiras
--    dos representantes (laghi, Lucenera, Vinicius Representa...). Linha única
--    (id = 1). Os dados reais ainda serão informados pelo usuário — a migration
--    só cria a linha com o nome; nada de dado inventado.
--
-- Rollback:
--   DROP TABLE public.configuracao_empresa_ubiqua;
--   ALTER TABLE public.informacoes_cliente_ubiqua DROP COLUMN tipo_pessoa, ... (colunas abaixo);

BEGIN;

ALTER TABLE public.informacoes_cliente_ubiqua
  ADD COLUMN IF NOT EXISTS tipo_pessoa text,
  ADD COLUMN IF NOT EXISTS cep text,
  ADD COLUMN IF NOT EXISTS endereco text,
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS complemento text,
  ADD COLUMN IF NOT EXISTS bairro text,
  ADD COLUMN IF NOT EXISTS cidade text,
  ADD COLUMN IF NOT EXISTS estado text,
  ADD COLUMN IF NOT EXISTS inscricao_estadual text,
  ADD COLUMN IF NOT EXISTS regime_tributario text,
  ADD COLUMN IF NOT EXISTS email_comercial text,
  ADD COLUMN IF NOT EXISTS email_financeiro text,
  ADD COLUMN IF NOT EXISTS transportadora text,
  ADD COLUMN IF NOT EXISTS entrega_igual_principal boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS cep_entrega text,
  ADD COLUMN IF NOT EXISTS endereco_entrega text,
  ADD COLUMN IF NOT EXISTS numero_entrega text,
  ADD COLUMN IF NOT EXISTS complemento_entrega text,
  ADD COLUMN IF NOT EXISTS bairro_entrega text,
  ADD COLUMN IF NOT EXISTS cidade_entrega text,
  ADD COLUMN IF NOT EXISTS estado_entrega text,
  ADD COLUMN IF NOT EXISTS cobranca_igual_principal boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS cep_cobranca text,
  ADD COLUMN IF NOT EXISTS endereco_cobranca text,
  ADD COLUMN IF NOT EXISTS numero_cobranca text,
  ADD COLUMN IF NOT EXISTS complemento_cobranca text,
  ADD COLUMN IF NOT EXISTS bairro_cobranca text,
  ADD COLUMN IF NOT EXISTS cidade_cobranca text,
  ADD COLUMN IF NOT EXISTS estado_cobranca text;

ALTER TABLE public.informacoes_cliente_ubiqua
  DROP CONSTRAINT IF EXISTS informacoes_cliente_ubiqua_tipo_pessoa_check,
  ADD CONSTRAINT informacoes_cliente_ubiqua_tipo_pessoa_check
    CHECK (tipo_pessoa IS NULL OR tipo_pessoa IN ('PF', 'PJ')),
  DROP CONSTRAINT IF EXISTS informacoes_cliente_ubiqua_regime_tributario_check,
  ADD CONSTRAINT informacoes_cliente_ubiqua_regime_tributario_check
    CHECK (regime_tributario IS NULL OR regime_tributario IN
      ('simples_nacional', 'mei', 'lucro_presumido', 'lucro_real', 'outro'));

-- Classifica os clientes já cadastrados pelo tamanho do documento.
UPDATE public.informacoes_cliente_ubiqua
   SET tipo_pessoa = CASE length(regexp_replace(cpf_cnpj, '\D', '', 'g'))
                       WHEN 14 THEN 'PJ' WHEN 11 THEN 'PF' END
 WHERE tipo_pessoa IS NULL AND cpf_cnpj IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.configuracao_empresa_ubiqua (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  nome_fantasia text NOT NULL,
  razao_social text,
  cnpj text,
  inscricao_estadual text,
  cep text,
  endereco text,
  numero text,
  complemento text,
  bairro text,
  cidade text,
  estado text,
  telefone text,
  email text,
  site text,
  logo_url text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.configuracao_empresa_ubiqua IS
  'SPEC-172: dados da própria Ubiqua (linha única id=1) usados no PDF e no e-mail do orçamento do Catálogo Ubiqua. Não confundir com empresa_ubiqua (parceiros).';

INSERT INTO public.configuracao_empresa_ubiqua (id, nome_fantasia)
VALUES (1, 'UBIQUA')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.configuracao_empresa_ubiqua ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS configuracao_empresa_ubiqua_select ON public.configuracao_empresa_ubiqua;
CREATE POLICY configuracao_empresa_ubiqua_select
  ON public.configuracao_empresa_ubiqua
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS configuracao_empresa_ubiqua_update_admin ON public.configuracao_empresa_ubiqua;
CREATE POLICY configuracao_empresa_ubiqua_update_admin
  ON public.configuracao_empresa_ubiqua
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.usuarios_ubiqua u
                  WHERE u.id = auth.uid() AND u.nivel_acesso = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.usuarios_ubiqua u
                       WHERE u.id = auth.uid() AND u.nivel_acesso = 'admin'));

GRANT SELECT, UPDATE ON public.configuracao_empresa_ubiqua TO authenticated;

COMMIT;
