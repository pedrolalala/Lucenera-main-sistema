-- SPEC-231 G1 (reunião 26/10): relatório "Movimentação do item" (kardex) — o que acontece no estoque da empresa,
-- igual ao relatório da Connect: venda aprovada já é saída (S), mesmo com a peça ainda reservada na prateleira;
-- a entrega não aparece. Decisões do usuário (27/10): saída na venda; histórico a partir da implantação, com
-- "Saldo inicial".
--
-- Saldo do setor:
--   Estoque (e os demais locais de estoque_itens) = quantidade − quantidade_reservada (pode ficar negativo:
--     vendeu sem ter peça). quantidade_disponivel NÃO é usada (não é mantida em todas as rotinas).
--   Showroom = produtos.estoque_showroom.
--
-- Como grava: gatilho em estoque_itens e em produtos.estoque_showroom anota cada mudança do saldo (sem mexer nas 16
-- rotinas que alteram estoque). O histórico (Venda 0003, Entrada NF 123, MOV 7...) é descoberto no fim da transação
-- por um gatilho adiado, olhando o que a mesma transação gravou (mesmo now()) em movimentacoes_peca,
-- notas_fiscais_compra, estoque_movimentos_projeto_item e showroom_import_pecas.

BEGIN;

CREATE TABLE public.estoque_kardex (
  id          bigserial PRIMARY KEY,
  produto_id  uuid NOT NULL REFERENCES public.produtos(id) ON DELETE CASCADE,
  setor       text NOT NULL,
  tipo        text NOT NULL CHECK (tipo IN ('E', 'S', 'T', 'I')),  -- I = saldo inicial
  quantidade  numeric NOT NULL,                                     -- com sinal: + entra, − sai
  saldo_apos  numeric NOT NULL,
  historico   text,
  origem      text,       -- venda | nf_compra | devolucao | movimentacao | showroom | ajuste | importacao | saldo_inicial
  usuario_id  uuid,
  usuario_nome text,
  sistema     text,
  tx_em       timestamptz NOT NULL DEFAULT now(),            -- início da transação (casa com os registros irmãos)
  criado_em   timestamptz NOT NULL DEFAULT clock_timestamp()  -- ordem real dentro da transação
);
CREATE INDEX estoque_kardex_produto_idx ON public.estoque_kardex (produto_id, criado_em, id);

COMMENT ON TABLE public.estoque_kardex IS
  'SPEC-231 G1: movimentação do estoque da empresa por peça e setor (kardex). Gravada só pelos gatilhos; leitura pela RPC relatorio_movimentacao_item.';

ALTER TABLE public.estoque_kardex ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.estoque_kardex FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.estoque_kardex_id_seq FROM anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- Gravação
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.kardex_anotar(p_produto uuid, p_setor text, p_delta numeric, p_saldo numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF coalesce(p_delta, 0) = 0 THEN RETURN; END IF;
  INSERT INTO public.estoque_kardex (produto_id, setor, tipo, quantidade, saldo_apos, usuario_id, usuario_nome, sistema)
  VALUES (p_produto, p_setor, CASE WHEN p_delta > 0 THEN 'E' ELSE 'S' END, p_delta, p_saldo,
          v_uid, CASE WHEN v_uid IS NOT NULL THEN auditoria.nome_usuario(v_uid) END, auditoria.sistema_atual());
END $$;
REVOKE ALL ON FUNCTION public.kardex_anotar(uuid, text, numeric, numeric) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.trg_kardex_estoque_itens()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_antes numeric := 0;
  v_depois numeric := 0;
BEGIN
  -- a linha "Showroom" de estoque_itens é sempre zerada (o Showroom mora em produtos.estoque_showroom)
  IF NEW.local::text = 'Showroom' THEN RETURN NULL; END IF;
  v_depois := coalesce(NEW.quantidade, 0) - coalesce(NEW.quantidade_reservada, 0);
  IF TG_OP = 'UPDATE' THEN
    v_antes := coalesce(OLD.quantidade, 0) - coalesce(OLD.quantidade_reservada, 0);
  END IF;
  PERFORM public.kardex_anotar(NEW.produto_id, NEW.local::text, v_depois - v_antes, v_depois);
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  -- o registro nunca pode travar uma operação de estoque
  RAISE WARNING 'kardex (estoque_itens): %', SQLERRM;
  RETURN NULL;
END $$;

CREATE TRIGGER kardex_estoque_itens
  AFTER INSERT OR UPDATE OF quantidade, quantidade_reservada ON public.estoque_itens
  FOR EACH ROW EXECUTE FUNCTION public.trg_kardex_estoque_itens();

CREATE OR REPLACE FUNCTION public.trg_kardex_showroom()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM public.kardex_anotar(NEW.id, 'Showroom',
    coalesce(NEW.estoque_showroom, 0) - CASE WHEN TG_OP = 'UPDATE' THEN coalesce(OLD.estoque_showroom, 0) ELSE 0 END,
    coalesce(NEW.estoque_showroom, 0));
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'kardex (showroom): %', SQLERRM;
  RETURN NULL;
END $$;

CREATE TRIGGER kardex_showroom
  AFTER INSERT OR UPDATE OF estoque_showroom ON public.produtos
  FOR EACH ROW EXECUTE FUNCTION public.trg_kardex_showroom();

-- ---------------------------------------------------------------------------------------------------------------
-- Histórico, no fim da transação
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kardex_num(p text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$ SELECT nullif(regexp_replace(coalesce(p, ''), '^[A-Za-z]+-', ''), '') $$;

CREATE OR REPLACE FUNCTION public.trg_kardex_resolver()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_hist text;
  v_origem text;
  v_tipo text := NEW.tipo;
  r record;
BEGIN
  IF NEW.historico IS NOT NULL THEN RETURN NULL; END IF;

  -- 1) Movimentação de Peças (troca de setor, baixa de peça faltando, Reserva ↔ Entrega Futura)
  SELECT m.numero, m.tipo, m.origem, m.destino, m.motivo INTO r
    FROM public.movimentacoes_peca m
   WHERE m.produto_id = NEW.produto_id AND m.criado_em = NEW.tx_em AND m.quantidade = abs(NEW.quantidade)
   ORDER BY m.numero LIMIT 1;
  IF FOUND THEN
    v_hist := format('MOV %s: %s → %s', r.numero, r.origem, r.destino) || coalesce(' — ' || nullif(btrim(r.motivo), ''), '');
    v_origem := 'movimentacao';
    -- troca entre dois setores físicos = transferência
    IF r.tipo = 'setor' AND r.destino NOT ILIKE 'Baixa%' THEN v_tipo := 'T'; END IF;
  END IF;

  -- 2) Entrada / cancelamento de NF de compra
  IF v_hist IS NULL THEN
    SELECT n.numero_nf, n.criado_em = NEW.tx_em AS entrada, coalesce(c.nome_empresa, c.nome) AS fornecedor INTO r
      FROM public.notas_fiscais_compra n
      LEFT JOIN public.contatos c ON c.id = n.fornecedor_id
     WHERE n.criado_em = NEW.tx_em OR n.cancelada_em = NEW.tx_em OR n.estoque_somado_em = NEW.tx_em
     ORDER BY n.criado_em DESC LIMIT 1;
    IF FOUND THEN
      v_hist := CASE WHEN NEW.quantidade < 0 THEN 'Cancelamento da NF ' ELSE 'Entrada NF ' END
                || coalesce(r.numero_nf, '?') || coalesce(' — ' || r.fornecedor, '');
      v_origem := 'nf_compra';
    END IF;
  END IF;

  -- 3) O que aconteceu na venda (aprovação, cancelamento, devolução...)
  IF v_hist IS NULL THEN
    SELECT em.tipo, o.numero, o.numero_venda INTO r
      FROM public.estoque_movimentos_projeto_item em
      JOIN public.projeto_itens pi ON pi.id = em.projeto_item_id
      LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
     WHERE em.criado_em = NEW.tx_em AND pi.produto_id = NEW.produto_id
     ORDER BY CASE em.tipo WHEN 'aprovacao_orcamento' THEN 1 WHEN 'devolucao_recebida' THEN 2 WHEN 'devolucao' THEN 3
                           WHEN 'cancelamento' THEN 4 WHEN 'estorno_aprovacao_orcamento' THEN 5 ELSE 9 END
     LIMIT 1;
    IF FOUND THEN
      v_hist := CASE r.tipo
        WHEN 'aprovacao_orcamento' THEN 'Venda ' || coalesce(_kardex_num(r.numero_venda), r.numero)
        WHEN 'entregue' THEN 'Empréstimo ' || coalesce(r.numero, '')
        WHEN 'devolucao' THEN 'Devolução da venda ' || coalesce(_kardex_num(r.numero_venda), r.numero)
        WHEN 'devolucao_recebida' THEN 'Devolução recebida — venda ' || coalesce(_kardex_num(r.numero_venda), r.numero)
        WHEN 'cancelamento' THEN 'Cancelamento do orçamento ' || coalesce(r.numero, '')
        WHEN 'estorno_aprovacao_orcamento' THEN 'Aprovação desfeita — orçamento ' || coalesce(r.numero, '')
        ELSE initcap(replace(r.tipo, '_', ' ')) || ' — ' || coalesce(_kardex_num(r.numero_venda), r.numero, '')
      END;
      v_origem := CASE WHEN r.tipo LIKE 'devolucao%' THEN 'devolucao' ELSE 'venda' END;
    END IF;
  END IF;

  -- 4) Peça vinculada ao Showroom pela apresentação
  IF v_hist IS NULL AND NEW.setor = 'Showroom' THEN
    SELECT s.slide INTO r FROM public.showroom_import_pecas s WHERE s.vinculado_em = NEW.tx_em LIMIT 1;
    IF FOUND THEN
      v_hist := 'Showroom: peça vinculada (slide ' || r.slide || ')';
      v_origem := 'showroom';
    END IF;
  END IF;

  -- 5) Sem pista: ajuste
  IF v_hist IS NULL THEN
    IF NEW.usuario_id IS NULL THEN
      v_hist := 'Importação / ajuste automático';
      v_origem := 'importacao';
    ELSE
      v_hist := 'Ajuste de estoque' || coalesce(' (' || NEW.sistema || ')', '');
      v_origem := 'ajuste';
    END IF;
  END IF;

  UPDATE public.estoque_kardex SET historico = v_hist, origem = v_origem, tipo = v_tipo WHERE id = NEW.id;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'kardex (histórico): %', SQLERRM;
  RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER kardex_resolver
  AFTER INSERT ON public.estoque_kardex
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION public.trg_kardex_resolver();

REVOKE ALL ON FUNCTION public.trg_kardex_estoque_itens() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trg_kardex_showroom() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trg_kardex_resolver() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- Saldo inicial (implantação): uma linha por peça/setor com saldo diferente de zero
-- ---------------------------------------------------------------------------------------------------------------
INSERT INTO public.estoque_kardex (produto_id, setor, tipo, quantidade, saldo_apos, historico, origem, sistema)
SELECT ei.produto_id, ei.local::text, 'I', ei.quantidade - ei.quantidade_reservada, ei.quantidade - ei.quantidade_reservada,
       'Saldo inicial (implantação do relatório)', 'saldo_inicial', 'implantacao'
  FROM public.estoque_itens ei
 WHERE ei.local::text <> 'Showroom' AND coalesce(ei.quantidade, 0) - coalesce(ei.quantidade_reservada, 0) <> 0;

INSERT INTO public.estoque_kardex (produto_id, setor, tipo, quantidade, saldo_apos, historico, origem, sistema)
SELECT p.id, 'Showroom', 'I', p.estoque_showroom, p.estoque_showroom,
       'Saldo inicial (implantação do relatório)', 'saldo_inicial', 'implantacao'
  FROM public.produtos p
 WHERE coalesce(p.estoque_showroom, 0) <> 0;

-- ---------------------------------------------------------------------------------------------------------------
-- Leitura: Relatórios (Dashboard) → Estoque → Movimentação do item
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.relatorio_movimentacao_item(
  p_codigo text,
  p_inicio date DEFAULT NULL,
  p_fim date DEFAULT NULL,
  p_setor text DEFAULT NULL
)
RETURNS TABLE (
  ordem bigint,
  data timestamptz,
  codigo_produto integer,
  produto text,
  historico text,
  tipo text,
  quantidade numeric,
  saldo_setor numeric,
  saldo_geral numeric,
  setor text,
  usuario text,
  sistema text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
#variable_conflict use_column
DECLARE
  v_prod record;
  v_ini timestamptz := (coalesce(p_inicio, DATE '2000-01-01')::timestamp AT TIME ZONE 'America/Sao_Paulo');
  v_fim timestamptz := ((coalesce(p_fim, (now() AT TIME ZONE 'America/Sao_Paulo')::date) + 1)::timestamp AT TIME ZONE 'America/Sao_Paulo');
  v_setor text := nullif(btrim(coalesce(p_setor, '')), '');
BEGIN
  IF NOT public.pode_acessar_algum(ARRAY['dashboard-financeiro']) THEN
    RAISE EXCEPTION 'Sem acesso ao relatório de movimentação.' USING ERRCODE = '42501';
  END IF;

  SELECT pr.id, pr.codigo_produto, pr.nome INTO v_prod
    FROM public.produtos pr
   WHERE pr.codigo_produto::text = btrim(p_codigo)
   LIMIT 1;
  IF NOT FOUND THEN RETURN; END IF;

  RETURN QUERY
  WITH anterior AS (
    -- saldo de cada setor no começo do período
    SELECT DISTINCT ON (k.setor) k.setor, k.saldo_apos
      FROM public.estoque_kardex k
     WHERE k.produto_id = v_prod.id AND k.criado_em < v_ini AND (v_setor IS NULL OR k.setor = v_setor)
     ORDER BY k.setor, k.criado_em DESC, k.id DESC
  ),
  linhas AS (
    SELECT 0::bigint AS id, v_ini AS criado_em, 'Saldo anterior'::text AS historico, ''::text AS tipo,
           NULL::numeric AS quantidade, a.saldo_apos AS saldo_setor, a.setor,
           NULL::text AS usuario, NULL::text AS sistema, a.saldo_apos AS delta_geral
      FROM anterior a
    UNION ALL
    SELECT k.id, k.criado_em, k.historico, k.tipo, k.quantidade, k.saldo_apos, k.setor, k.usuario_nome, k.sistema,
           k.quantidade
      FROM public.estoque_kardex k
     WHERE k.produto_id = v_prod.id AND k.criado_em >= v_ini AND k.criado_em < v_fim
       AND (v_setor IS NULL OR k.setor = v_setor)
  )
  SELECT row_number() OVER w, l.criado_em, v_prod.codigo_produto, v_prod.nome, l.historico, l.tipo, l.quantidade,
         l.saldo_setor, sum(l.delta_geral) OVER w, l.setor, l.usuario, l.sistema
    FROM linhas l
  WINDOW w AS (ORDER BY l.id = 0 DESC, l.criado_em, l.id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
   ORDER BY 1;
END $$;

REVOKE ALL ON FUNCTION public.relatorio_movimentacao_item(text, date, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.relatorio_movimentacao_item(text, date, date, text) TO authenticated;

COMMIT;
