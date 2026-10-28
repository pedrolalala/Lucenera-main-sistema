-- SPEC-235 C/D/E (reunião 27/10 parte 2)
--  C: situação da peça no orçamento (trava no banco, além da tela):
--     - desativada (produtos.ativo = false) não entra;
--     - "Fora de Linha" só entra com saldo e até o disponível (soma da peça no orçamento <= disponível).
--     Vale para orçamento que não é devolução, só ao incluir ou aumentar quantidade/trocar a peça, e só para usuário
--     logado (imports/serviço não passam por aqui). Disponível = o mesmo da Consulta (vw_consulta_estoque).
--  D/E: vw_consulta_estoque ganha status_comercial (nulo = Normal) e fornecedor_nome (fornecedor da peça; se vazio,
--     o fornecedor da marca — só 2 peças têm fornecedor próprio). Colunas novas no fim; security_invoker mantido.
BEGIN;

CREATE OR REPLACE VIEW public.vw_consulta_estoque WITH (security_invoker = true) AS
WITH itens AS (
         SELECT ei.produto_id,
            sum(ei.quantidade) FILTER (WHERE (ei.local <> ALL (ARRAY['Showroom'::estoque_local, 'Estoque Garantia'::estoque_local, 'Estoque Casa Cor'::estoque_local]))) AS geral,
            sum(COALESCE(ei.quantidade_reservada, (0)::numeric)) FILTER (WHERE (ei.local <> ALL (ARRAY['Showroom'::estoque_local, 'Estoque Garantia'::estoque_local, 'Estoque Casa Cor'::estoque_local]))) AS reservado_connect,
            count(*) FILTER (WHERE (ei.local <> ALL (ARRAY['Estoque Garantia'::estoque_local, 'Estoque Casa Cor'::estoque_local]))) AS n_itens_geral,
            bool_or((COALESCE(ei.quantidade, (0)::numeric) <> (0)::numeric)) AS algum_local_com_saldo
           FROM estoque_itens ei
          GROUP BY ei.produto_id
        ), base AS (
         SELECT p.id AS produto_id,
            p.codigo_produto,
            p.referencia,
            p.nome,
            p.ativo,
            COALESCE(NULLIF(btrim(p.status_comercial), ''), 'Normal') AS status_comercial,
            COALESCE(fp.nome, fm.nome) AS fornecedor_nome,
            p.preco_venda,
            p.valor_venda,
            p.marca_id,
            m.nome AS marca_nome,
            p.categoria_id,
            cp.nome AS categoria_nome,
            COALESCE(i.geral, (0)::numeric) AS estoque_total,
            COALESCE(s.q_reserva, (0)::numeric) AS q_reserva,
            COALESCE(s.q_separacao, (0)::numeric) AS q_separacao,
            COALESCE(s.q_entrega_futura, (0)::numeric) AS q_entrega_futura,
            COALESCE(i.reservado_connect, (0)::numeric) AS reservado_connect,
            GREATEST((COALESCE(s.q_reserva, (0)::numeric) + COALESCE(s.q_separacao, (0)::numeric)), COALESCE(i.reservado_connect, (0)::numeric)) AS estoque_reservado,
            COALESCE(p.estoque_showroom, 0) AS estoque_showroom,
            (COALESCE(i.n_itens_geral, (0)::bigint) > 0) AS has_estoque,
            COALESCE(i.algum_local_com_saldo, false) AS algum_local_com_saldo
           FROM ((((((produtos p
             LEFT JOIN marcas m ON ((m.id = p.marca_id)))
             LEFT JOIN categorias_produto cp ON ((cp.id = p.categoria_id)))
             LEFT JOIN itens i ON ((i.produto_id = p.id)))
             LEFT JOIN vw_cadastro_produto_setores s ON ((s.produto_id = p.id)))
             LEFT JOIN contatos fp ON ((fp.id = p.fornecedor_principal_id)))
             LEFT JOIN contatos fm ON ((fm.id = m.fornecedor_id)))
        )
 SELECT produto_id,
    codigo_produto,
    referencia,
    nome,
    ativo,
    preco_venda,
    valor_venda,
    marca_id,
    marca_nome,
    categoria_id,
    categoria_nome,
    estoque_total,
    q_reserva,
    q_separacao,
    q_entrega_futura,
    reservado_connect,
    estoque_reservado,
    (estoque_total - estoque_reservado) AS estoque_disponivel,
    estoque_showroom,
    has_estoque,
    ((estoque_total <> (0)::numeric) OR ((estoque_total - estoque_reservado) <> (0)::numeric) OR (estoque_showroom <> 0) OR algum_local_com_saldo) AS tem_saldo,
    status_comercial,
    fornecedor_nome
   FROM base b;

CREATE OR REPLACE FUNCTION public.trg_orcamento_itens_situacao_peca()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_p        record;
  v_natureza text;
  v_disp     numeric;
  v_total    numeric;
BEGIN
  IF auth.uid() IS NULL OR NEW.produto_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.produto_id IS NOT DISTINCT FROM OLD.produto_id
     AND coalesce(NEW.quantidade, 0) <= coalesce(OLD.quantidade, 0) THEN
    RETURN NEW;
  END IF;
  SELECT natureza_operacao INTO v_natureza FROM public.orcamentos WHERE id = NEW.orcamento_id;
  IF v_natureza = 'devolucao' THEN
    RETURN NEW;
  END IF;

  SELECT codigo_produto, nome, ativo, coalesce(nullif(btrim(status_comercial), ''), 'Normal') AS status
    INTO v_p FROM public.produtos WHERE id = NEW.produto_id;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  IF v_p.ativo IS FALSE THEN
    RAISE EXCEPTION 'A peça % (%) está desativada e não pode entrar no orçamento.', v_p.codigo_produto, v_p.nome
      USING ERRCODE = 'P0001';
  END IF;

  IF v_p.status = 'Fora de Linha' THEN
    SELECT coalesce(estoque_disponivel, 0) INTO v_disp FROM public.vw_consulta_estoque WHERE produto_id = NEW.produto_id;
    SELECT coalesce(sum(quantidade), 0) INTO v_total
      FROM public.orcamento_itens
     WHERE orcamento_id = NEW.orcamento_id AND produto_id = NEW.produto_id
       AND (TG_OP = 'INSERT' OR id <> NEW.id);
    v_total := v_total + coalesce(NEW.quantidade, 0);
    IF coalesce(v_disp, 0) <= 0 THEN
      RAISE EXCEPTION 'A peça % (%) está fora de linha e sem saldo disponível — não pode entrar no orçamento.',
        v_p.codigo_produto, v_p.nome USING ERRCODE = 'P0001';
    END IF;
    IF v_total > v_disp THEN
      RAISE EXCEPTION 'A peça % (%) está fora de linha: só % disponível (no orçamento: %).',
        v_p.codigo_produto, v_p.nome, v_disp, v_total USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_orcamento_itens_situacao_peca() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_orcamento_itens_situacao_peca ON public.orcamento_itens;
CREATE TRIGGER trg_orcamento_itens_situacao_peca
  BEFORE INSERT OR UPDATE OF produto_id, quantidade ON public.orcamento_itens
  FOR EACH ROW EXECUTE FUNCTION public.trg_orcamento_itens_situacao_peca();

COMMIT;
