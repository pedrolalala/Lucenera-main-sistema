-- SPEC-298 (13/11/2026, pedido da Carol na Central): devolucao, casa cor entrada/saida, uso e consumo e bonificacao
-- passam a ter NUMERO DE VENDA proprio ao efetivar (como a venda normal), com sequencia por tipo:
--   DEV-0001 (devolucao / troca dev), CSCE-0001 (casa cor entrada), CSCS-0001 (casa cor saida), USC-0001 (uso e consumo), BR-0001 (bonificacao).
-- Decisao do usuario em 13/11/2026 (formato e retroativo). Reverte SPEC-136 (devolucao sem numero) e a parte "sem numero de venda" da SPEC-255
-- SO para estes tipos; GARANTIA, DESCARTE, EMPRESTIMO e demais continuam sem numero de venda.
-- Nao mexe em financeiro, estoque nem titulos. As funcoes grandes de aprovacao NAO foram alteradas: um gatilho BEFORE UPDATE preenche
-- orcamentos.numero_venda na hora em que o status vira 'Orcamento Aprovado' (qualquer caminho de aprovacao).
-- A sequencia das vendas (VENDA-NNNN, MAX+1 sobre 'VENDA-%') nao e afetada: os prefixos novos nao casam com 'VENDA-%'.
BEGIN;

CREATE SCHEMA IF NOT EXISTS backup;
CREATE TABLE IF NOT EXISTS backup.spec298_numero_venda_por_tipo (
  orcamento_id uuid PRIMARY KEY, numero_orcamento text, tipo text, numero_venda_novo text NOT NULL, atribuido_em timestamptz NOT NULL DEFAULT now(), origem text NOT NULL
);
REVOKE ALL ON backup.spec298_numero_venda_por_tipo FROM PUBLIC, anon, authenticated;

CREATE SEQUENCE IF NOT EXISTS public.seq_numero_venda_dev;
CREATE SEQUENCE IF NOT EXISTS public.seq_numero_venda_csce;
CREATE SEQUENCE IF NOT EXISTS public.seq_numero_venda_cscs;
CREATE SEQUENCE IF NOT EXISTS public.seq_numero_venda_usc;
CREATE SEQUENCE IF NOT EXISTS public.seq_numero_venda_br;
REVOKE ALL ON SEQUENCE public.seq_numero_venda_dev, public.seq_numero_venda_csce, public.seq_numero_venda_cscs,
                     public.seq_numero_venda_usc, public.seq_numero_venda_br FROM PUBLIC, anon, authenticated;

-- prefixo do numero conforme o tipo (NULL = tipo que nao recebe numero de venda)
CREATE OR REPLACE FUNCTION public.prefixo_numero_operacao(p_natureza text, p_subgrupo text)
RETURNS text LANGUAGE sql IMMUTABLE AS $f$
  SELECT CASE
    WHEN p_subgrupo = 'CASA COR ENTRADA' THEN 'CSCE'
    WHEN p_subgrupo = 'CASA COR SAIDA'   THEN 'CSCS'
    WHEN p_subgrupo = 'USO E CONSUMO'    THEN 'USC'
    WHEN p_subgrupo = 'BONIFICACAO'      THEN 'BR'
    WHEN p_natureza = 'devolucao'        THEN 'DEV'
  END
$f$;

CREATE OR REPLACE FUNCTION public.proximo_numero_venda_operacao(p_prefixo text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE v bigint;
BEGIN
  v := CASE p_prefixo
         WHEN 'DEV'  THEN nextval('public.seq_numero_venda_dev')
         WHEN 'CSCE' THEN nextval('public.seq_numero_venda_csce')
         WHEN 'CSCS' THEN nextval('public.seq_numero_venda_cscs')
         WHEN 'USC'  THEN nextval('public.seq_numero_venda_usc')
         WHEN 'BR'   THEN nextval('public.seq_numero_venda_br')
       END;
  IF v IS NULL THEN RAISE EXCEPTION 'Prefixo de numero de venda desconhecido: %', p_prefixo; END IF;
  RETURN p_prefixo || '-' || lpad(v::text, 4, '0');
END $f$;
REVOKE ALL ON FUNCTION public.proximo_numero_venda_operacao(text) FROM PUBLIC, anon, authenticated;

-- gatilho: ao virar 'Orcamento Aprovado' sem numero de venda, recebe o do tipo
CREATE OR REPLACE FUNCTION public.trg_numero_venda_por_tipo()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE v_pref text; v_num text;
BEGIN
  IF NEW.numero_venda IS NOT NULL THEN RETURN NEW; END IF;
  v_pref := public.prefixo_numero_operacao(NEW.natureza_operacao, NEW.subgrupo);
  IF v_pref IS NULL THEN RETURN NEW; END IF;
  v_num := public.proximo_numero_venda_operacao(v_pref);
  NEW.numero_venda := v_num;
  INSERT INTO backup.spec298_numero_venda_por_tipo (orcamento_id, numero_orcamento, tipo, numero_venda_novo, origem)
  VALUES (NEW.id, NEW.numero, v_pref, v_num, 'aprovacao') ON CONFLICT (orcamento_id) DO NOTHING;
  RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION public.trg_numero_venda_por_tipo() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_3_numero_venda_por_tipo ON public.orcamentos;
CREATE TRIGGER trg_3_numero_venda_por_tipo
  BEFORE UPDATE OF status ON public.orcamentos
  FOR EACH ROW
  WHEN (NEW.status = 'Orçamento Aprovado' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.numero_venda IS NULL)
  EXECUTE FUNCTION public.trg_numero_venda_por_tipo();

-- retroativo: ja efetivados (na ordem da efetivacao; sem data de aprovacao usa a criacao do orcamento)
DO $b$
DECLARE r record; v_num text;
BEGIN
  FOR r IN
    SELECT o.id, o.numero, o.numero_venda, public.prefixo_numero_operacao(o.natureza_operacao, o.subgrupo) AS pref,
           coalesce((SELECT min(h.created_at) FROM public.historico_status_orcamentos h
                      WHERE h.orcamento_id = o.id AND h.status_novo = 'Orçamento Aprovado'), o.created_at) AS quando
      FROM public.orcamentos o
     WHERE o.status = 'Orçamento Aprovado' AND o.numero_venda IS NULL
       AND public.prefixo_numero_operacao(o.natureza_operacao, o.subgrupo) IS NOT NULL
     ORDER BY quando, o.created_at, o.id
  LOOP
    v_num := public.proximo_numero_venda_operacao(r.pref);
    UPDATE public.orcamentos SET numero_venda = v_num WHERE id = r.id;
    INSERT INTO backup.spec298_numero_venda_por_tipo (orcamento_id, numero_orcamento, tipo, numero_venda_novo, origem)
    VALUES (r.id, r.numero, r.pref, v_num, 'retroativo') ON CONFLICT (orcamento_id) DO NOTHING;
  END LOOP;
END $b$;

COMMIT;
