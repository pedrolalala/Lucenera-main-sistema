-- SPEC-234 F (reunião 27/10; regra provisória registrada pelo usuário até falar com o Vinicius):
--   Disponível = Estoque Geral + Showroom − Reservado, somado NA HORA (dois saldos separados, como a Connect).
-- Hoje o import da Connect gravou o Showroom DENTRO do reservado (reserva negativa = −Showroom em 286 peças), o que conta
-- a peça duas vezes quando ela passa do Showroom para o Geral (13442: 47 em vez de 46) e deixa o "livre no Geral" maior
-- do que existe fisicamente.
--  1. Cópia do reservado atual em backup._bkp_255_estoque_itens_reservado.
--  2. Reservado novo = maior(reservado + Showroom, vendas do sistema) nas peças com Showroom (conferido: 300 de 302
--     batem com a planilha da Connect de 14/10; 13653 tem venda do sistema; 13442 fica 0). O disponível com Showroom
--     não muda em nenhuma, menos a 13442 (47 → 46).
--  3. fn_sync_estoque_itens_from_produtos (só roda no import com --incluir-estoque): reservado = Total + Showroom − Disponível.
--  4. vw_consulta_estoque: estoque_disponivel passa a somar o Showroom.
-- A reserva na aprovação continua só do Estoque Geral: peça do Showroom precisa ser movida para o Geral antes.
BEGIN;

CREATE TABLE backup._bkp_255_estoque_itens_reservado AS
SELECT ei.id, ei.produto_id, ei.local, ei.quantidade, ei.quantidade_reservada, ei.quantidade_disponivel,
       p.estoque_showroom, now() AS copiado_em
  FROM public.estoque_itens ei JOIN public.produtos p ON p.id = ei.produto_id
 WHERE ei.local = 'Estoque' AND (coalesce(p.estoque_showroom, 0) > 0 OR ei.quantidade_reservada < 0);
REVOKE ALL ON backup._bkp_255_estoque_itens_reservado FROM PUBLIC, anon, authenticated;

WITH sis AS (
  SELECT pi.produto_id, sum(s.q_reserva + s.q_entrega_futura + s.q_ag_separar + s.q_separado) AS sistema
    FROM public.estoque_saldos_projeto_item s JOIN public.projeto_itens pi ON pi.id = s.projeto_item_id
   GROUP BY pi.produto_id
), novo AS (
  SELECT ei.id, greatest(ei.quantidade_reservada + coalesce(p.estoque_showroom, 0), coalesce(sis.sistema, 0)) AS reservado
    FROM public.estoque_itens ei
    JOIN public.produtos p ON p.id = ei.produto_id
    LEFT JOIN sis ON sis.produto_id = ei.produto_id
   WHERE ei.local = 'Estoque' AND coalesce(p.estoque_showroom, 0) > 0
)
UPDATE public.estoque_itens ei
   SET quantidade_reservada = novo.reservado,
       quantidade_disponivel = ei.quantidade - novo.reservado,
       atualizado_em = now()
  FROM novo
 WHERE novo.id = ei.id AND ei.quantidade_reservada IS DISTINCT FROM novo.reservado;

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
    COALESCE(NEW.estoque_disponivel, 0) - COALESCE(NEW.estoque_showroom, 0),
    -- SPEC-234 F: o "Disponível" da Connect já soma o Showroom; o reservado real é Total + Showroom − Disponível
    COALESCE(NEW.estoque_total, 0) + COALESCE(NEW.estoque_showroom, 0) - COALESCE(NEW.estoque_disponivel, 0)
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
    ((estoque_total + (estoque_showroom)::numeric) - estoque_reservado) AS estoque_disponivel,
    estoque_showroom,
    has_estoque,
    ((estoque_total <> (0)::numeric) OR (((estoque_total + (estoque_showroom)::numeric) - estoque_reservado) <> (0)::numeric) OR (estoque_showroom <> 0) OR algum_local_com_saldo) AS tem_saldo,
    status_comercial,
    fornecedor_nome
   FROM base b;

COMMIT;
