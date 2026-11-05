-- SPEC-243 (RASCUNHO, NÃO APLICADA) — Herança Connect por cliente: base de dados.
-- Cria só a BASE: espelho das planilhas ReservaxAmbiente / EntregaFuturaxAmbiente, tabela de tratamento ("matar"),
-- colunas de vínculo Connect no orçamento, permissão do Matheus/admin e as views de leitura.
-- NÃO cria a função de carga (gera orçamento + projeto_itens + saldos): vem na migration 266, depois do ensaio com ROLLBACK.
-- Nada aqui toca estoque_itens, transacoes, projeto_parcelas, boletos nem vendas.
-- Regras: AGENTS.md (RLS sempre, REVOKE anon, sem USING(true) em dado financeiro, pode_acessar_sistema dentro de SELECT,
-- valor só admin, funções novas com REVOKE de PUBLIC/anon).
BEGIN;

-- ---------------------------------------------------------------------------------------------------------------
-- 1) Orçamento: origem e vínculos Connect (todos opcionais; orçamentos do sistema ficam como estão)
-- ---------------------------------------------------------------------------------------------------------------
ALTER TABLE public.orcamentos
  ADD COLUMN IF NOT EXISTS origem text NOT NULL DEFAULT 'sistema',
  ADD COLUMN IF NOT EXISTS connect_lote uuid,
  ADD COLUMN IF NOT EXISTS vendas_vinculadas_connect integer[] NOT NULL DEFAULT '{}';

ALTER TABLE public.orcamentos DROP CONSTRAINT IF EXISTS orcamentos_origem_check;
ALTER TABLE public.orcamentos
  ADD CONSTRAINT orcamentos_origem_check CHECK (origem IN ('sistema', 'connect'));

COMMENT ON COLUMN public.orcamentos.origem IS
  'SPEC-243: connect = orçamento gerado da planilha de Reserva/Entrega Futura da Connect (histórico, fora da lista normal). sistema = feito aqui.';
COMMENT ON COLUMN public.orcamentos.connect_lote IS
  'SPEC-243: lote de importação que gerou este orçamento (permite remover o lote inteiro no rollback).';
COMMENT ON COLUMN public.orcamentos.vendas_vinculadas_connect IS
  'SPEC-243: números de venda da Connect ligados a este orçamento/venda (Vendas vinculadas Connect). Uma obra pode ter mais de uma.';
-- origem_connect_cod_orcamento (SPEC-195) continua sendo o "Orçamento vinculado Connect".

CREATE INDEX IF NOT EXISTS idx_orcamentos_origem_connect ON public.orcamentos (origem) WHERE origem = 'connect';
CREATE INDEX IF NOT EXISTS idx_orcamentos_vendas_vinculadas_connect ON public.orcamentos USING gin (vendas_vinculadas_connect);

-- ---------------------------------------------------------------------------------------------------------------
-- 2) Espelho bruto das planilhas (uma linha por linha da planilha, mesmo sem vínculo)
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.connect_reserva_ambiente (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo                   text NOT NULL CHECK (tipo IN ('reserva', 'entrega_futura')),
  lote_importacao        uuid NOT NULL,
  linha_planilha         integer NOT NULL,
  -- como veio da Connect
  cod_orcamento_connect  integer,
  cod_venda_connect      integer,
  cod_cliente_connect    integer,
  nome_bruto             text,
  projeto_codigo         text,
  nome_cliente           text,
  produto_codigo         integer,
  referencia             text,
  descricao              text,
  quantidade             numeric(12,3) NOT NULL CHECK (quantidade >= 0),
  ambiente               text,
  data_entrega           date,
  aviso_data             boolean NOT NULL DEFAULT false,   -- reserva sem data de entrega (provável erro da Connect)
  vendedor_nome          text,                             -- coluna Funcionario = digitador do orçamento
  valor_venda            numeric(14,2),                    -- total da linha; SÓ ADMINISTRAÇÃO (grants e view abaixo)
  observacao             text,
  adicional              text,
  venda_antiga           boolean NOT NULL DEFAULT false,   -- cod_venda_connect <= limite (hoje 2477 = 30/06/2025)
  -- vínculos resolvidos na importação (NULL quando não casa; motivo em motivo_sem_vinculo)
  empresa_id             uuid REFERENCES public.empresas (id),
  funcionario_id         uuid REFERENCES public.funcionarios (id) ON DELETE SET NULL,
  digitado_por           uuid REFERENCES public.usuarios (id) ON DELETE SET NULL,
  equipe_id              uuid REFERENCES public.equipes_projetos (id) ON DELETE SET NULL,
  projeto_id             uuid REFERENCES public.projetos (id) ON DELETE SET NULL,
  cliente_id             uuid REFERENCES public.contatos (id) ON DELETE SET NULL,
  produto_id             uuid REFERENCES public.produtos (id) ON DELETE SET NULL,
  orcamento_id           uuid REFERENCES public.orcamentos (id) ON DELETE SET NULL,
  projeto_item_id        uuid REFERENCES public.projeto_itens (id) ON DELETE SET NULL,
  motivo_sem_vinculo     text,   -- venda_sem_titulo | peca_nao_cadastrada | cliente_nao_cadastrado | projeto_nao_encontrado |
                                 -- nome_sem_codigo_projeto | digitador_nao_encontrado | digitador_sem_equipe |
                                 -- empresa_nao_deduzida | empresa_ambigua  (pode haver mais de um, separados por vírgula)
  -- chave natural usada pelo tratamento ("matar"): resiste a reimportar a planilha
  chave                  text GENERATED ALWAYS AS (
                           tipo || ':' || coalesce(cod_venda_connect::text, '') || ':' ||
                           coalesce(produto_codigo::text, '') || ':' || coalesce(ambiente, '')) STORED,
  created_at             timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tipo, lote_importacao, linha_planilha)
);

COMMENT ON TABLE public.connect_reserva_ambiente IS
  'SPEC-243: espelho das planilhas ReservaxAmbiente e EntregaFuturaxAmbiente da Connect. Só histórico/visualização: nunca altera estoque, Contas a Pagar/Receber, parcelas nem boletos.';

CREATE INDEX IF NOT EXISTS idx_cra_venda     ON public.connect_reserva_ambiente (cod_venda_connect);
CREATE INDEX IF NOT EXISTS idx_cra_projeto   ON public.connect_reserva_ambiente (projeto_id);
CREATE INDEX IF NOT EXISTS idx_cra_produto   ON public.connect_reserva_ambiente (produto_id);
CREATE INDEX IF NOT EXISTS idx_cra_cliente   ON public.connect_reserva_ambiente (cliente_id);
CREATE INDEX IF NOT EXISTS idx_cra_orcamento ON public.connect_reserva_ambiente (orcamento_id);
CREATE INDEX IF NOT EXISTS idx_cra_lote      ON public.connect_reserva_ambiente (lote_importacao);
CREATE INDEX IF NOT EXISTS idx_cra_chave     ON public.connect_reserva_ambiente (chave);

-- ---------------------------------------------------------------------------------------------------------------
-- 3) Tratamento ("matar"): o que o Matheus/admin decidiu sobre uma linha da herança. Sobrevive à reimportação.
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.connect_reserva_tratamento (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chave          text NOT NULL,                       -- = connect_reserva_ambiente.chave
  acao           text NOT NULL CHECK (acao IN ('mantida_confirmada', 'entregue_sem_estoque',
                                               'entregue_voltou_ao_estoque', 'cancelada_volta_ao_estoque', 'observacao')),
  mexe_estoque   boolean NOT NULL DEFAULT false,      -- o "check" da reunião de 04/11
  quantidade     numeric(12,3),
  observacao     text NOT NULL CHECK (length(btrim(observacao)) > 0),   -- obrigatória (log: por que foi baixada)
  usuario_id     uuid NOT NULL DEFAULT auth.uid(),
  criado_em      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.connect_reserva_tratamento IS
  'SPEC-243 fase 2: log do que foi feito com cada linha da herança Connect (quem, quando, por quê). Só Matheus e administração gravam.';
CREATE INDEX IF NOT EXISTS idx_crt_chave ON public.connect_reserva_tratamento (chave);

-- ---------------------------------------------------------------------------------------------------------------
-- 4) Permissão "tratar herança Connect": só Matheus + administração (mesmo desenho do ajuste de reserva, SPEC-235 B)
-- ---------------------------------------------------------------------------------------------------------------
INSERT INTO public.modulos (system_id, chave, nome, descricao, ordem)
SELECT s.id, 'tratar_heranca_connect', 'Tratar herança Connect (Venda Parcial)',
       'SPEC-243: dar como entregue / voltar ao estoque / manter linha da reserva e entrega futura herdadas da Connect. Só exceção individual (conceder) ou admin.',
       110
  FROM public.systems s WHERE s.slug = 'separacao-parcial'
ON CONFLICT (system_id, chave) DO NOTHING;

-- Matheus (mesmo usuário da SPEC-235 B)
INSERT INTO public.usuario_permissao_excecoes (usuario_id, system_id, modulo_id, acao, tipo, justificativa)
SELECT 'af3035fd-266b-4b3a-952b-cb8866096c49', s.id, m.id, 'editar', 'conceder',
       'SPEC-243: só o Matheus e a administração tratam a herança Connect (reunião 04/11)'
  FROM public.systems s JOIN public.modulos m ON m.system_id = s.id AND m.chave = 'tratar_heranca_connect'
 WHERE s.slug = 'separacao-parcial'
   AND NOT EXISTS (SELECT 1 FROM public.usuario_permissao_excecoes e
                    WHERE e.usuario_id = 'af3035fd-266b-4b3a-952b-cb8866096c49' AND e.modulo_id = m.id);

CREATE OR REPLACE FUNCTION public.pode_tratar_heranca_connect()
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  -- coalesce final: usuário sem linha em usuarios (is_admin NULL) vira false, nunca NULL (AGENTS.md, regra 9)
  SELECT coalesce(auth.uid() IS NOT NULL AND (
    coalesce(public.is_admin(), false)
    OR coalesce((
      SELECT e.tipo = 'conceder'
        FROM public.usuario_permissao_excecoes e
        JOIN public.modulos m ON m.id = e.modulo_id AND m.chave = 'tratar_heranca_connect'
        JOIN public.systems s ON s.id = m.system_id AND s.slug = 'separacao-parcial'
       WHERE e.usuario_id = auth.uid()
         AND (e.valido_até IS NULL OR e.valido_até > now())
       ORDER BY e.criado_em DESC
       LIMIT 1), false)
  ), false)
$$;
REVOKE ALL ON FUNCTION public.pode_tratar_heranca_connect() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_tratar_heranca_connect() TO authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 5) RLS e grants
--    Leitura: quem tem Venda Parcial, Cadastro, Orçamentos, Necessidade de Compra ou Logística (ou admin).
--    valor_venda NÃO é legível por authenticated: só a view restrita (admin). Escrita: só funções SECURITY DEFINER
--    (carga/tratamento) e service_role; nenhuma política de INSERT/UPDATE/DELETE para authenticated.
-- ---------------------------------------------------------------------------------------------------------------
ALTER TABLE public.connect_reserva_ambiente   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connect_reserva_tratamento ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.connect_reserva_ambiente   FROM anon, authenticated;
REVOKE ALL ON public.connect_reserva_tratamento FROM anon, authenticated;

-- authenticated lê tudo MENOS valor_venda (grant por coluna, como em produtos / SPEC-193)
GRANT SELECT (id, tipo, lote_importacao, linha_planilha, cod_orcamento_connect, cod_venda_connect, cod_cliente_connect,
              nome_bruto, projeto_codigo, nome_cliente, produto_codigo, referencia, descricao, quantidade, ambiente,
              data_entrega, aviso_data, vendedor_nome, observacao, adicional, venda_antiga, empresa_id, funcionario_id,
              digitado_por, equipe_id, projeto_id, cliente_id, produto_id, orcamento_id, projeto_item_id,
              motivo_sem_vinculo, chave, created_at)
  ON public.connect_reserva_ambiente TO authenticated;
GRANT SELECT ON public.connect_reserva_tratamento TO authenticated;
GRANT ALL ON public.connect_reserva_ambiente, public.connect_reserva_tratamento TO service_role;

DROP POLICY IF EXISTS cra_leitura ON public.connect_reserva_ambiente;
CREATE POLICY cra_leitura ON public.connect_reserva_ambiente FOR SELECT TO authenticated
USING (
  (SELECT public.is_admin())
  OR (SELECT public.pode_acessar_sistema('separacao-parcial'))
  OR (SELECT public.pode_acessar_sistema('cadastro'))
  OR (SELECT public.pode_acessar_sistema('orcamentos'))
  OR (SELECT public.pode_acessar_sistema('necessidade-de-compra'))
  OR (SELECT public.pode_acessar_sistema('logistica'))
);

DROP POLICY IF EXISTS crt_leitura ON public.connect_reserva_tratamento;
CREATE POLICY crt_leitura ON public.connect_reserva_tratamento FOR SELECT TO authenticated
USING (
  (SELECT public.is_admin())
  OR (SELECT public.pode_acessar_sistema('separacao-parcial'))
  OR (SELECT public.pode_acessar_sistema('cadastro'))
  OR (SELECT public.pode_acessar_sistema('necessidade-de-compra'))
  OR (SELECT public.pode_acessar_sistema('logistica'))
);

-- ---------------------------------------------------------------------------------------------------------------
-- 6) Views
-- ---------------------------------------------------------------------------------------------------------------
-- 6a) Leitura geral (SEM valor). security_invoker = o RLS acima vale para quem consulta.
CREATE OR REPLACE VIEW public.vw_connect_reserva_ambiente
WITH (security_invoker = true) AS
SELECT r.id, r.tipo, r.cod_orcamento_connect, r.cod_venda_connect, r.cod_cliente_connect,
       r.projeto_codigo, coalesce(c.nome, r.nome_cliente) AS cliente_nome,
       r.produto_codigo, r.referencia, r.descricao, r.quantidade, r.ambiente, r.data_entrega, r.aviso_data,
       r.vendedor_nome, r.venda_antiga, r.observacao, r.adicional,
       r.empresa_id, r.equipe_id, r.projeto_id, r.cliente_id, r.produto_id, r.orcamento_id, r.projeto_item_id,
       r.motivo_sem_vinculo,
       (r.motivo_sem_vinculo IS NOT NULL) AS sem_vinculo,
       EXISTS (SELECT 1 FROM public.connect_reserva_tratamento t WHERE t.chave = r.chave) AS tratada,
       r.chave, r.lote_importacao
  FROM public.connect_reserva_ambiente r
  LEFT JOIN public.contatos c ON c.id = r.cliente_id;
REVOKE ALL ON public.vw_connect_reserva_ambiente FROM anon;
GRANT SELECT ON public.vw_connect_reserva_ambiente TO authenticated;

-- 6b) Valor de venda: SÓ administração. View de dono com portão no WHERE (AGENTS.md, regra 3).
CREATE OR REPLACE VIEW public.vw_connect_reserva_ambiente_valor AS
SELECT r.id, r.chave, r.cod_venda_connect, r.valor_venda
  FROM public.connect_reserva_ambiente r
 WHERE (SELECT public.is_admin());
REVOKE ALL ON public.vw_connect_reserva_ambiente_valor FROM anon;
GRANT SELECT ON public.vw_connect_reserva_ambiente_valor TO authenticated;

COMMIT;
