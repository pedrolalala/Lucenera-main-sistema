-- SPEC-293 (12/11/2026): Compras - editar o numero do pedido de compra (temporario), com auditoria e financeiro em dia.
-- A) RPC renomear_numero_pedido_compra(p_pedido, p_novo_numero, p_motivo) + pode_editar_numero_pedido_compra() (para a tela).
-- B) permissao em compras_config (tabela de uma linha so: duas colunas novas, nao ha chave/valor):
--    numero_pedido_editavel_por uuid[] (Debora) + administradores (public.usuarios.role); numero_pedido_edicao_ativa (liga/desliga o "temporario").
-- D) de/para em backup.spec293_renumeracao_pedidos_compra (uma linha por troca) + evento em auditoria com o motivo.
-- E) textos do financeiro ligados por id ao pedido: titulo do pedido (documento/descricao), parcelas previstas ("Previsao do pedido N (parcela k)"),
--    titulos de NF do pedido ("NF x (pedido N)"), pagamento_existente_vinculos.pedido_numero, pagamentos_antecipados.observacao (so se citar o numero).
--    financeiro_ponte_pedido monta os textos com pedidos_compra.numero ATUAL e o gatilho trg_fin_ponte_pedido nao reage a UPDATE de numero
--    (so status/cancelado_em/empresa_id/fornecedor_id): nada volta ao numero antigo.
-- H) pedidos_compra_numero_seq passa a continuar do maior numero que comeca por digitos (inclui "NNNN CONNECT"), uma vez, sem retroceder.
-- O indice unico pedidos_compra_numero_uniq (exato) continua; a RPC compara sem diferenciar caixa e sem espacos nas pontas.
-- Numero 347: a 346 e da SPEC-292 (outra sessao).
BEGIN;

-- ===== B. configuracao =====
ALTER TABLE public.compras_config
  ADD COLUMN IF NOT EXISTS numero_pedido_editavel_por uuid[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS numero_pedido_edicao_ativa boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.compras_config.numero_pedido_editavel_por IS 'SPEC-293: usuarios (alem dos administradores) que podem editar o numero do pedido de compra.';
COMMENT ON COLUMN public.compras_config.numero_pedido_edicao_ativa IS 'SPEC-293: liga/desliga a edicao do numero do pedido (temporario). Desligada, ninguem edita.';

UPDATE public.compras_config
   SET numero_pedido_editavel_por = (SELECT coalesce(array_agg(u.id), '{}') FROM public.usuarios u WHERE u.email = 'debora@lucenera.com.br'),
       numero_pedido_edicao_ativa = true;

-- ===== D. de/para =====
CREATE SCHEMA IF NOT EXISTS backup;
CREATE TABLE IF NOT EXISTS backup.spec293_renumeracao_pedidos_compra (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  pedido_id     uuid NOT NULL,
  numero_antigo text NOT NULL,
  numero_novo   text NOT NULL,
  motivo        text NOT NULL,
  alterado_por  uuid,
  alterado_em   timestamptz NOT NULL DEFAULT now(),
  seq_antes     bigint
);
ALTER TABLE backup.spec293_renumeracao_pedidos_compra ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON backup.spec293_renumeracao_pedidos_compra FROM PUBLIC, anon, authenticated;

-- ===== H. sequencia (uma vez, nunca retrocede) =====
DO $$
DECLARE v_antes bigint; v_max bigint;
BEGIN
  SELECT last_value INTO v_antes FROM public.pedidos_compra_numero_seq;
  SELECT coalesce(max((substring(numero from '^[0-9]+'))::bigint), 0) INTO v_max
    FROM public.pedidos_compra
   WHERE numero ~ '^[0-9]+' AND numero NOT LIKE 'PC-LEGADO%' AND length(substring(numero from '^[0-9]+')) <= 9;
  IF v_max > v_antes THEN PERFORM setval('public.pedidos_compra_numero_seq', v_max, true); END IF;
  -- guarda o valor de antes para o rollback (linha marcador, sem pedido)
  INSERT INTO backup.spec293_renumeracao_pedidos_compra (pedido_id, numero_antigo, numero_novo, motivo, seq_antes)
  VALUES ('00000000-0000-0000-0000-000000000000', '(sequencia)', '(sequencia)', 'SPEC-293: ajuste da sequencia na migration', v_antes);
END $$;

-- ===== permissao =====
CREATE OR REPLACE FUNCTION public.pode_editar_numero_pedido_compra()
 RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $f$
DECLARE v_uid uuid := auth.uid(); v_cfg public.compras_config; v_role public.usuario_role;
BEGIN
  IF v_uid IS NULL THEN RETURN false; END IF;
  SELECT * INTO v_cfg FROM public.compras_config LIMIT 1;
  IF NOT FOUND OR v_cfg.numero_pedido_edicao_ativa IS DISTINCT FROM true THEN RETURN false; END IF;
  SELECT role INTO v_role FROM public.usuarios WHERE id = v_uid AND ativo IS NOT DISTINCT FROM true;
  IF v_role IS NULL THEN RETURN false; END IF;
  RETURN v_uid = ANY (v_cfg.numero_pedido_editavel_por) OR v_role IS NOT DISTINCT FROM 'admin'::public.usuario_role;
END $f$;
REVOKE ALL ON FUNCTION public.pode_editar_numero_pedido_compra() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_editar_numero_pedido_compra() TO authenticated;

-- ===== nucleo (sem checagem de permissao; so a RPC e o rollback chamam) =====
CREATE OR REPLACE FUNCTION public._pedido_compra_aplicar_numero(p_pedido uuid, p_novo text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $f$
DECLARE
  v_ant text;
BEGIN
  SELECT numero INTO v_ant FROM public.pedidos_compra WHERE id = p_pedido;
  IF v_ant IS NULL OR v_ant IS NOT DISTINCT FROM p_novo THEN RETURN; END IF;

  UPDATE public.pedidos_compra SET numero = p_novo WHERE id = p_pedido;

  -- titulo do pedido (origem pedido_compra): numero no documento e na descricao
  UPDATE public.financeiro_titulos t
     SET documento = CASE WHEN t.documento IS NOT DISTINCT FROM v_ant THEN p_novo ELSE t.documento END,
         descricao = CASE WHEN t.descricao IS NOT DISTINCT FROM ('Pedido de compra ' || v_ant) THEN 'Pedido de compra ' || p_novo ELSE t.descricao END
   WHERE t.pedido_compra_id = p_pedido AND t.origem_tipo = 'pedido_compra'
     AND (t.documento IS NOT DISTINCT FROM v_ant OR t.descricao IS NOT DISTINCT FROM ('Pedido de compra ' || v_ant));

  -- parcelas (previstas, substituidas, canceladas): "Previsao do pedido <n> (parcela k)"
  UPDATE public.financeiro_parcelas p
     SET observacao = 'Previsão do pedido ' || p_novo || substr(p.observacao, length('Previsão do pedido ' || v_ant) + 1)
    FROM public.financeiro_titulos t
   WHERE p.titulo_id = t.id AND t.pedido_compra_id = p_pedido AND t.origem_tipo = 'pedido_compra'
     AND left(p.observacao, length('Previsão do pedido ' || v_ant || ' (')) = 'Previsão do pedido ' || v_ant || ' (';

  -- titulos de NF do pedido: "NF x (pedido <n>)" (a nota aponta o pedido por id)
  UPDATE public.financeiro_titulos t
     SET descricao = replace(t.descricao, '(pedido ' || v_ant || ')', '(pedido ' || p_novo || ')')
    FROM public.notas_fiscais_compra n
   WHERE t.nota_fiscal_compra_id = n.id AND n.pedido_compra_id = p_pedido
     AND position('(pedido ' || v_ant || ')' IN t.descricao) > 0;

  -- rotulo gravado no vinculo de pagamento existente (SPEC-290)
  UPDATE public.pagamento_existente_vinculos v SET pedido_numero = p_novo
   WHERE v.pedido_compra_id = p_pedido AND v.pedido_numero IS DISTINCT FROM p_novo;

  -- adiantamento: so se a observacao citar o numero do pedido
  UPDATE public.pagamentos_antecipados a
     SET observacao = replace(a.observacao, '(pedido ' || v_ant || ')', '(pedido ' || p_novo || ')')
   WHERE a.pedido_compra_id = p_pedido AND position('(pedido ' || v_ant || ')' IN a.observacao) > 0;
END $f$;
REVOKE ALL ON FUNCTION public._pedido_compra_aplicar_numero(uuid, text) FROM PUBLIC, anon, authenticated;

-- ===== A. RPC =====
CREATE OR REPLACE FUNCTION public.renomear_numero_pedido_compra(p_pedido uuid, p_novo_numero text, p_motivo text)
 RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $f$
DECLARE
  v_uid uuid := auth.uid(); v_ant text; v_status text; v_novo text := btrim(coalesce(p_novo_numero, ''));
  v_motivo text := btrim(coalesce(p_motivo, '')); v_seq bigint;
BEGIN
  IF v_uid IS NULL OR NOT public.pode_editar_numero_pedido_compra() THEN
    RAISE EXCEPTION 'Voce nao tem permissao para editar o numero do pedido (ou a edicao esta desligada).' USING ERRCODE = '42501';
  END IF;
  IF v_novo = '' THEN RAISE EXCEPTION 'Informe o novo numero do pedido.' USING ERRCODE = '22023'; END IF;
  IF length(v_novo) > 40 THEN RAISE EXCEPTION 'O numero do pedido pode ter no maximo 40 caracteres.' USING ERRCODE = '22023'; END IF;
  IF v_motivo = '' THEN RAISE EXCEPTION 'Informe o motivo da troca do numero.' USING ERRCODE = '22023'; END IF;
  -- "PC-LEGADO-..." e a marca de pedido legado cancelado (financeiro_ponte_pedido ignora esses numeros): ninguem pode ser renomeado PARA ela
  IF upper(v_novo) LIKE 'PC-LEGADO%' THEN
    RAISE EXCEPTION 'O numero nao pode comecar com "PC-LEGADO": esse prefixo e reservado aos pedidos legados cancelados.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('pedidos_compra_numero'));
  SELECT numero, status::text INTO v_ant, v_status FROM public.pedidos_compra WHERE id = p_pedido FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pedido de compra nao encontrado.' USING ERRCODE = 'P0002'; END IF;
  -- pedido PC-LEGADO que nao esta cancelado: sair do prefixo faria o financeiro passar a trata-lo como pedido normal
  IF upper(v_ant) LIKE 'PC-LEGADO%' AND v_status IS DISTINCT FROM 'cancelado' THEN
    RAISE EXCEPTION 'O pedido % e legado e nao esta cancelado (status %): nao pode ser renomeado.', v_ant, v_status USING ERRCODE = '22023';
  END IF;
  IF v_novo IS NOT DISTINCT FROM v_ant THEN
    RAISE EXCEPTION 'O novo numero e igual ao atual.' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM public.pedidos_compra x WHERE x.id <> p_pedido AND lower(btrim(x.numero)) = lower(v_novo)) THEN
    RAISE EXCEPTION 'Ja existe um pedido com o numero "%".', v_novo USING ERRCODE = '23505';
  END IF;

  PERFORM public._pedido_compra_aplicar_numero(p_pedido, v_novo);

  -- numero puramente numerico (ate 9 digitos) maior que a sequencia: a sequencia acompanha, para o proximo pedido novo nao colidir. Nunca retrocede.
  IF v_novo ~ '^[0-9]{1,9}$' THEN
    SELECT last_value INTO v_seq FROM public.pedidos_compra_numero_seq;
    IF v_novo::bigint > v_seq THEN PERFORM setval('public.pedidos_compra_numero_seq', v_novo::bigint, true); END IF;
  END IF;

  INSERT INTO backup.spec293_renumeracao_pedidos_compra (pedido_id, numero_antigo, numero_novo, motivo, alterado_por)
  VALUES (p_pedido, v_ant, v_novo, v_motivo, v_uid);
  PERFORM auditoria.inserir(v_uid, auditoria.sistema_atual(), 'alterou', 'pedidos_compra', p_pedido::text, 'Pedido ' || v_novo,
         jsonb_build_object('numero', jsonb_build_array(v_ant, v_novo), 'motivo_troca_numero', v_motivo), NULL, NULL, NULL);
  RETURN v_novo;
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'Ja existe um pedido com o numero "%".', v_novo USING ERRCODE = '23505';
END $f$;
REVOKE ALL ON FUNCTION public.renomear_numero_pedido_compra(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renomear_numero_pedido_compra(uuid, text, text) TO authenticated;

COMMIT;
