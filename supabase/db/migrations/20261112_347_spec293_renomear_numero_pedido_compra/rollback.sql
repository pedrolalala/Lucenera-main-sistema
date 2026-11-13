-- Rollback SPEC-293 (migration 347): devolve os numeros alterados pelo de/para (do mais recente para o mais antigo), remove as funcoes e as
-- colunas de configuracao e devolve a sequencia ao valor de antes SEM nunca ficar abaixo do maior numero puramente numerico existente.
-- O de/para (backup.spec293_renumeracao_pedidos_compra) e MANTIDO. Se um numero antigo ja foi tomado por outro pedido, a devolucao
-- daquele pedido e pulada com aviso (nao quebra).
BEGIN;

DO $$
DECLARE r record; v_seq bigint; v_max bigint;
BEGIN
  FOR r IN SELECT * FROM backup.spec293_renumeracao_pedidos_compra WHERE pedido_id <> '00000000-0000-0000-0000-000000000000' ORDER BY id DESC LOOP
    IF EXISTS (SELECT 1 FROM public.pedidos_compra WHERE numero = r.numero_antigo AND id <> r.pedido_id) THEN
      RAISE WARNING 'Pedido % nao voltou para "%": numero em uso por outro pedido.', r.pedido_id, r.numero_antigo;
    ELSE
      PERFORM public._pedido_compra_aplicar_numero(r.pedido_id, r.numero_antigo);
    END IF;
  END LOOP;

  SELECT seq_antes INTO v_seq FROM backup.spec293_renumeracao_pedidos_compra WHERE pedido_id = '00000000-0000-0000-0000-000000000000' ORDER BY id LIMIT 1;
  SELECT coalesce(max(numero::bigint), 0) INTO v_max FROM public.pedidos_compra WHERE numero ~ '^[0-9]{1,9}$';
  IF v_seq IS NOT NULL THEN PERFORM setval('public.pedidos_compra_numero_seq', greatest(v_seq, v_max, 1), true); END IF;
END $$;

DROP FUNCTION IF EXISTS public.renomear_numero_pedido_compra(uuid, text, text);
DROP FUNCTION IF EXISTS public.pode_editar_numero_pedido_compra();
DROP FUNCTION IF EXISTS public._pedido_compra_aplicar_numero(uuid, text);
ALTER TABLE public.compras_config DROP COLUMN IF EXISTS numero_pedido_editavel_por, DROP COLUMN IF EXISTS numero_pedido_edicao_ativa;

COMMIT;
