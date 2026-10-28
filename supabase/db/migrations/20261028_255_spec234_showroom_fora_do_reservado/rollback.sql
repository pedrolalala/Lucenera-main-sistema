-- Rollback da 255 (SPEC-234 F): volta o reservado da cópia, a função de sincronização e a consulta.
BEGIN;

UPDATE public.estoque_itens ei
   SET quantidade_reservada = b.quantidade_reservada, quantidade_disponivel = b.quantidade_disponivel, atualizado_em = now()
  FROM backup._bkp_255_estoque_itens_reservado b
 WHERE b.id = ei.id;

CREATE OR REPLACE FUNCTION public.fn_sync_estoque_itens_from_produtos()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_disponivel, quantidade_reservada)
  VALUES (
    NEW.id,
    'Estoque',
    COALESCE(NEW.estoque_total, 0),
    COALESCE(NEW.estoque_disponivel, 0),
    COALESCE(NEW.estoque_total, 0) - COALESCE(NEW.estoque_disponivel, 0)
  )
  ON CONFLICT (produto_id, local) DO UPDATE
  SET quantidade = EXCLUDED.quantidade,
      quantidade_disponivel = EXCLUDED.quantidade_disponivel,
      quantidade_reservada = EXCLUDED.quantidade_reservada,
      atualizado_em = now();

  -- Zera qualquer linha de Showroom remanescente deste produto (quantidade,
  -- disponível e reservada), para não inflar somas que agregam todos os locais.
  UPDATE public.estoque_itens
  SET quantidade = 0, quantidade_disponivel = 0, quantidade_reservada = 0, atualizado_em = now()
  WHERE produto_id = NEW.id AND local = 'Showroom'
    AND (quantidade <> 0 OR quantidade_disponivel IS DISTINCT FROM 0 OR quantidade_reservada <> 0);

  RETURN NEW;
END;
$function$;

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
            COALESCE(NULLIF(btrim(p.status_comercial), ''::text), 'Normal'::text) AS status_comercial,
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

COMMIT;
-- A cópia backup._bkp_255_estoque_itens_reservado fica (apagar à mão depois de conferir).
