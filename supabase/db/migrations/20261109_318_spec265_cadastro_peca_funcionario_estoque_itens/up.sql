-- SPEC-265: funcionario (ex.: Debora) nao conseguia cadastrar peca nova. O trigger que cria a linha de estoque em
-- estoque_itens rodava com as permissoes de quem salva e a politica estoque_insert so aceita admin/gerente/operador.
-- A funcao so e chamada pelo trigger de produtos e escreve apenas a partir da linha NEW: roda como dono (SECURITY DEFINER).
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_sync_estoque_itens_from_produtos()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
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

REVOKE ALL ON FUNCTION public.fn_sync_estoque_itens_from_produtos() FROM PUBLIC, anon;

COMMIT;
