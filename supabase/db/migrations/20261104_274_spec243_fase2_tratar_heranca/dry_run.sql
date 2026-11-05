-- Dry-run da 274: cria a função, trata itens reais como Matheus, confere estoque/saldos/log e DESFAZ. Termina em ROLLBACK.
BEGIN;
-- SPEC-243 FASE 2 (RASCUNHO, NÃO APLICADA) — "matar" a herança da Connect: só Matheus e administração.
--
-- Reunião de 04/11: peça reservada/em entrega futura da Connect que já saiu ou que não sai mais precisa ser baixada, com OBSERVAÇÃO e LOG, e o
-- estoque tem que acompanhar. A conta é a MESMA da SPEC-232 (venda do sistema): ao entregar, o saldo sai da Reserva, o Estoque Geral físico baixa e o
-- reservado é liberado na mesma medida; ao cancelar, o saldo sai e só o reservado é liberado (a peça volta a ficar disponível).
-- Em TODAS as ações vale o invariante da SPEC-232: variação do `quantidade_reservada` = variação de (Reserva + Entrega Futura + Separação), então a
-- "Reserva sem venda (herança Connect)" de OUTROS clientes nunca muda.
--
--   Ação                           Saldo do item                     Estoque Geral (quantidade)   Reservado (quantidade_reservada)
--   entregue_baixa_estoque         Reserva −q, Entregue +q           −q  (a peça saiu e a Connect ainda a contava)   −q
--   entregue_estoque_ja_ajustado   Reserva −q, Entregue +q           0   (o físico já foi corrigido, ex.: contagem)  −q   <- o "check não mexe no estoque"
--   nao_sera_entregue              Reserva ou E.Futura −q, Devolvida +q   0  (a peça está no estoque: volta a ficar disponível)   −q
--   mantida_confirmada / observacao  nenhuma                         0                             0   (só registra e tira da fila)
--
-- Entrega Futura não tem peça física: só `nao_sera_entregue` ou `mantida_confirmada`.
-- NÃO cria crédito, NÃO gera financeiro, NÃO é devolução (é só baixar a herança). Reimportar as planilhas (remover_connect_lote) passa a ser recusado
-- nos orçamentos tratados (já recusava quando há Entregue/Devolvida): por isso a fase 2 só deve ser usada DEPOIS da importação final da Connect (07/11).

-- Os nomes de ação do rascunho da 264 viram os definitivos (a tabela está vazia).
ALTER TABLE public.connect_reserva_tratamento DROP CONSTRAINT IF EXISTS connect_reserva_tratamento_acao_check;
ALTER TABLE public.connect_reserva_tratamento
  ADD CONSTRAINT connect_reserva_tratamento_acao_check CHECK (acao IN
    ('mantida_confirmada', 'entregue_baixa_estoque', 'entregue_estoque_ja_ajustado', 'nao_sera_entregue', 'observacao'));
ALTER TABLE public.connect_reserva_tratamento
  ADD COLUMN IF NOT EXISTS projeto_item_id uuid REFERENCES public.projeto_itens (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS setor text CHECK (setor IS NULL OR setor IN ('reserva', 'entrega_futura'));

CREATE OR REPLACE FUNCTION public.tratar_heranca_connect(
  p_projeto_item_id uuid, p_acao text, p_setor text, p_quantidade numeric, p_observacao text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_item   record;
  v_saldo  record;
  v_chave  text;
  v_q      numeric := 0;
  v_disp   numeric;
  v_baixa  boolean := false;
  v_mov    text;
  v_tid    uuid;
BEGIN
  IF NOT public.pode_tratar_heranca_connect() THEN
    RAISE EXCEPTION 'Só o Matheus ou um administrador pode tratar a herança da Connect.' USING ERRCODE = '42501';
  END IF;
  IF p_acao NOT IN ('mantida_confirmada', 'entregue_baixa_estoque', 'entregue_estoque_ja_ajustado', 'nao_sera_entregue', 'observacao') THEN
    RAISE EXCEPTION 'Ação inválida: %', p_acao USING ERRCODE = 'P0001';
  END IF;
  IF p_setor IS NULL OR p_setor NOT IN ('reserva', 'entrega_futura') THEN
    RAISE EXCEPTION 'Informe o setor: reserva ou entrega_futura.' USING ERRCODE = 'P0001';
  END IF;
  IF p_observacao IS NULL OR length(btrim(p_observacao)) = 0 THEN
    RAISE EXCEPTION 'A observação é obrigatória (registra por que a peça foi baixada).' USING ERRCODE = 'P0001';
  END IF;

  -- só item de orçamento da Connect
  SELECT pi.id, pi.produto_id, pi.orcamento_id, pi.quantidade, o.origem, o.numero AS orc_numero
    INTO v_item
    FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id
   WHERE pi.id = p_projeto_item_id;
  IF NOT FOUND OR v_item.origem IS DISTINCT FROM 'connect' THEN
    RAISE EXCEPTION 'Este item não é herança da Connect.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_saldo FROM public.estoque_saldos_projeto_item WHERE projeto_item_id = p_projeto_item_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item sem saldo.' USING ERRCODE = 'P0001';
  END IF;

  -- chave da linha da planilha (sobrevive à reimportação)
  SELECT r.chave INTO v_chave FROM public.connect_reserva_ambiente r
   WHERE r.projeto_item_id = p_projeto_item_id AND r.tipo = p_setor LIMIT 1;

  IF p_acao IN ('mantida_confirmada', 'observacao') THEN
    v_q := 0;
  ELSE
    v_q := coalesce(p_quantidade, 0);
    IF v_q <= 0 THEN
      RAISE EXCEPTION 'Informe a quantidade.' USING ERRCODE = 'P0001';
    END IF;
    IF p_setor = 'entrega_futura' AND p_acao <> 'nao_sera_entregue' THEN
      RAISE EXCEPTION 'Entrega Futura não tem peça física: só dá para marcar "não será entregue" ou manter.' USING ERRCODE = 'P0001';
    END IF;
    v_disp := CASE WHEN p_setor = 'reserva' THEN v_saldo.q_reserva ELSE v_saldo.q_entrega_futura END;
    IF v_q > v_disp THEN
      RAISE EXCEPTION 'Quantidade maior que o saldo em % deste item.', p_setor USING ERRCODE = 'P0001';
    END IF;

    IF p_acao LIKE 'entregue_%' THEN
      v_baixa := (p_acao = 'entregue_baixa_estoque');
      UPDATE public.estoque_saldos_projeto_item
         SET q_reserva = q_reserva - v_q, q_entregue = q_entregue + v_q, atualizado_em = now()
       WHERE projeto_item_id = p_projeto_item_id;
      v_mov := 'entregue';
    ELSE
      IF p_setor = 'reserva' THEN
        UPDATE public.estoque_saldos_projeto_item
           SET q_reserva = q_reserva - v_q, q_devolvida = q_devolvida + v_q, atualizado_em = now()
         WHERE projeto_item_id = p_projeto_item_id;
      ELSE
        UPDATE public.estoque_saldos_projeto_item
           SET q_entrega_futura = q_entrega_futura - v_q, q_devolvida = q_devolvida + v_q, atualizado_em = now()
         WHERE projeto_item_id = p_projeto_item_id;
      END IF;
      v_mov := 'cancelamento';
    END IF;

    -- Estoque: o reservado sempre é liberado (invariante SPEC-232); o físico só baixa quando a peça realmente saiu e a Connect ainda a contava.
    UPDATE public.estoque_itens
       SET quantidade_reservada = GREATEST(quantidade_reservada - v_q, 0),
           quantidade = CASE WHEN v_baixa THEN GREATEST(quantidade - v_q, 0) ELSE quantidade END,
           atualizado_em = now()
     WHERE produto_id = v_item.produto_id AND local = 'Estoque'::public.estoque_local;

    INSERT INTO public.estoque_movimentos_projeto_item (projeto_item_id, tipo, quantidade, origem, observacao, criado_por)
    VALUES (p_projeto_item_id, v_mov, v_q, 'tratar_heranca_connect', left(p_observacao, 500), auth.uid());
  END IF;

  INSERT INTO public.connect_reserva_tratamento (chave, acao, mexe_estoque, quantidade, observacao, projeto_item_id, setor)
  VALUES (coalesce(v_chave, 'sem_chave:' || p_projeto_item_id::text), p_acao, v_baixa, nullif(v_q, 0), btrim(p_observacao), p_projeto_item_id, p_setor)
  RETURNING id INTO v_tid;

  RETURN jsonb_build_object('tratamento_id', v_tid, 'orcamento', v_item.orc_numero, 'acao', p_acao, 'setor', p_setor, 'quantidade', v_q, 'baixou_estoque_fisico', v_baixa);
END
$fn$;

REVOKE ALL ON FUNCTION public.tratar_heranca_connect(uuid, text, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tratar_heranca_connect(uuid, text, text, numeric, text) TO authenticated;


CREATE TEMP TABLE _ctx (k text PRIMARY KEY, v text);
-- 4 itens Connect de peças DIFERENTES: dois com Reserva >= 3 e um com Entrega Futura >= 2, mais um para a negativa
INSERT INTO _ctx
SELECT 'r' || row_number() OVER (), x.pi FROM (
  SELECT DISTINCT ON (pi.produto_id) pi.id::text AS pi
    FROM public.estoque_saldos_projeto_item s JOIN public.projeto_itens pi ON pi.id = s.projeto_item_id JOIN public.orcamentos o ON o.id = pi.orcamento_id
   WHERE o.origem = 'connect' AND s.q_reserva >= 3 ORDER BY pi.produto_id, pi.id LIMIT 3) x;
INSERT INTO _ctx SELECT 'ef1', pi.id::text FROM public.estoque_saldos_projeto_item s JOIN public.projeto_itens pi ON pi.id = s.projeto_item_id JOIN public.orcamentos o ON o.id = pi.orcamento_id
 WHERE o.origem = 'connect' AND s.q_entrega_futura >= 2 AND pi.produto_id NOT IN (SELECT pi2.produto_id FROM public.projeto_itens pi2 WHERE pi2.id::text IN (SELECT v FROM _ctx)) LIMIT 1;

-- foto do estoque/saldo de uma peça (físico, reservado, reserva, EF, entregue, devolvida) + herança "sem cliente" da peça
CREATE FUNCTION pg_temp.foto(p_pi uuid) RETURNS text LANGUAGE sql SECURITY DEFINER AS $f$
  SELECT concat_ws(' | ',
    'geral ' || coalesce((SELECT quantidade::text FROM public.estoque_itens ei WHERE ei.produto_id = pi.produto_id AND ei.local = 'Estoque'), '-'),
    'reservado ' || coalesce((SELECT quantidade_reservada::text FROM public.estoque_itens ei WHERE ei.produto_id = pi.produto_id AND ei.local = 'Estoque'), '-'),
    'saldo res ' || s.q_reserva || ' ef ' || s.q_entrega_futura || ' ent ' || s.q_entregue || ' dev ' || s.q_devolvida,
    'HERANCA_SEM_CLIENTE ' || (coalesce((SELECT quantidade_reservada FROM public.estoque_itens ei WHERE ei.produto_id = pi.produto_id AND ei.local = 'Estoque'), 0)
        - coalesce((SELECT sum(s2.q_reserva + s2.q_entrega_futura + s2.q_ag_separar + s2.q_separado) FROM public.estoque_saldos_projeto_item s2
                      JOIN public.projeto_itens p2 ON p2.id = s2.projeto_item_id WHERE p2.produto_id = pi.produto_id AND s2.status_operacional = 'ativo'), 0)))
  FROM public.projeto_itens pi JOIN public.estoque_saldos_projeto_item s ON s.projeto_item_id = pi.id WHERE pi.id = p_pi
$f$;

GRANT SELECT ON _ctx TO authenticated;
GRANT EXECUTE ON FUNCTION pg_temp.foto(uuid) TO authenticated;
-- 1) usuário comum (Marina, projetista) é barrado
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"438d37e0-ae72-4226-83c7-15d501a49dd4"}', true);
DO $$ BEGIN
  PERFORM public.tratar_heranca_connect((SELECT v::uuid FROM _ctx WHERE k = 'r1'), 'nao_sera_entregue', 'reserva', 1, 'teste');
  RAISE NOTICE 'FALHOU: projetista tratou herança';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'projetista barrada com a mensagem: %', SQLERRM;
END $$;

-- 2) Matheus
SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"af3035fd-266b-4b3a-952b-cb8866096c49"}', true);
DO $$
DECLARE a uuid := (SELECT v::uuid FROM _ctx WHERE k = 'r1'); b uuid := (SELECT v::uuid FROM _ctx WHERE k = 'r2'); c uuid := (SELECT v::uuid FROM _ctx WHERE k = 'r3');
        e uuid := (SELECT v::uuid FROM _ctx WHERE k = 'ef1'); r jsonb;
BEGIN
  -- sem observação
  BEGIN PERFORM public.tratar_heranca_connect(a, 'nao_sera_entregue', 'reserva', 1, '   '); RAISE NOTICE 'FALHOU: aceitou observação vazia';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'OK: observação vazia recusada'; END;
  -- quantidade acima do saldo
  BEGIN PERFORM public.tratar_heranca_connect(a, 'nao_sera_entregue', 'reserva', 999999, 'x'); RAISE NOTICE 'FALHOU: aceitou acima do saldo';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'OK: acima do saldo recusado'; END;
  -- entregar entrega futura
  BEGIN PERFORM public.tratar_heranca_connect(e, 'entregue_baixa_estoque', 'entrega_futura', 1, 'x'); RAISE NOTICE 'FALHOU: entregou entrega futura';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'OK: entrega futura não pode ser entregue'; END;

  RAISE NOTICE 'A antes : %', pg_temp.foto(a);
  r := public.tratar_heranca_connect(a, 'entregue_baixa_estoque', 'reserva', 2, 'Peça saiu em maio, sem lista (teste)');
  RAISE NOTICE 'A depois: % -> %', pg_temp.foto(a), r;
  RAISE NOTICE 'B antes : %', pg_temp.foto(b);
  r := public.tratar_heranca_connect(b, 'entregue_estoque_ja_ajustado', 'reserva', 1, 'Estoque já contado (teste)');
  RAISE NOTICE 'B depois: %', pg_temp.foto(b);
  RAISE NOTICE 'C antes : %', pg_temp.foto(c);
  r := public.tratar_heranca_connect(c, 'nao_sera_entregue', 'reserva', 1, 'Obra acabou (teste)');
  RAISE NOTICE 'C depois: %', pg_temp.foto(c);
  RAISE NOTICE 'E antes : %', pg_temp.foto(e);
  r := public.tratar_heranca_connect(e, 'nao_sera_entregue', 'entrega_futura', 1, 'Não vem mais (teste)');
  RAISE NOTICE 'E depois: %', pg_temp.foto(e);
  r := public.tratar_heranca_connect(a, 'mantida_confirmada', 'reserva', NULL, 'Cliente deve, entrega segurada (teste)');
  RAISE NOTICE 'A mantida (nada muda): %', pg_temp.foto(a);
END $$;
RESET ROLE;

-- 3) log, movimentos e reimportação recusada
DO $$ BEGIN
  RAISE NOTICE 'tratamentos gravados: % | com observação: %', (SELECT count(*) FROM public.connect_reserva_tratamento), (SELECT count(*) FROM public.connect_reserva_tratamento WHERE length(btrim(observacao)) > 0);
  RAISE NOTICE 'ações: %', (SELECT string_agg(acao || ' q=' || coalesce(quantidade::text, '-') || ' baixa=' || mexe_estoque, '; ' ORDER BY criado_em) FROM public.connect_reserva_tratamento);
  RAISE NOTICE 'movimentos do tipo entregue/cancelamento criados: %', (SELECT count(*) FROM public.estoque_movimentos_projeto_item WHERE origem = 'tratar_heranca_connect');
  RAISE NOTICE 'kardex registrou o estoque: % linhas novas', (SELECT count(*) FROM public.estoque_kardex WHERE criado_em > now() - interval '5 minutes') ;
  BEGIN
    PERFORM public.remover_connect_lote((SELECT connect_lote FROM public.orcamentos WHERE origem = 'connect' LIMIT 1));
    RAISE NOTICE 'FALHOU: reimportação do lote tratado foi permitida';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'OK: reimportar o lote tratado é recusado (%)', left(SQLERRM, 80);
  END;
END $$;
ROLLBACK;
