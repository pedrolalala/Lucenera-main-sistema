-- Dry-run da 267: aplica a nova view, testa 3 casos e DESFAZ. Termina em ROLLBACK.
BEGIN;
-- SPEC-243 — corrige vw_connect_reserva_ambiente.sem_vinculo.
-- Defeito: sem_vinculo era "motivo_sem_vinculo IS NOT NULL", mas linhas JÁ vinculadas a um orçamento podem ter motivo só
-- informativo (digitador_nao_encontrado, projeto_por_codigo_legado) e apareciam como "sem vínculo" na Venda Parcial.
-- Correção: sem_vinculo = a linha NÃO virou orçamento (orcamento_id IS NULL). O motivo continua visível em motivo_sem_vinculo.
-- Mesmas colunas e mesma ordem da view da 264 (CREATE OR REPLACE exige isso). Nada além da expressão muda.

CREATE OR REPLACE VIEW public.vw_connect_reserva_ambiente
WITH (security_invoker = true) AS
SELECT r.id, r.tipo, r.cod_orcamento_connect, r.cod_venda_connect, r.cod_cliente_connect,
       r.projeto_codigo, coalesce(c.nome, r.nome_cliente) AS cliente_nome,
       r.produto_codigo, r.referencia, r.descricao, r.quantidade, r.ambiente, r.data_entrega, r.aviso_data,
       r.vendedor_nome, r.venda_antiga, r.observacao, r.adicional,
       r.empresa_id, r.equipe_id, r.projeto_id, r.cliente_id, r.produto_id, r.orcamento_id, r.projeto_item_id,
       r.motivo_sem_vinculo,
       (r.orcamento_id IS NULL) AS sem_vinculo,
       EXISTS (SELECT 1 FROM public.connect_reserva_tratamento t WHERE t.chave = r.chave) AS tratada,
       r.chave, r.lote_importacao
  FROM public.connect_reserva_ambiente r
  LEFT JOIN public.contatos c ON c.id = r.cliente_id;

REVOKE ALL ON public.vw_connect_reserva_ambiente FROM anon;
GRANT SELECT ON public.vw_connect_reserva_ambiente TO authenticated;


-- 3 casos: (a) sem orçamento e com motivo, (b) COM orçamento e com motivo só informativo, (c) COM orçamento e sem motivo
INSERT INTO public.orcamentos (id, empresa_id, status, numero, origem)
SELECT '22222222-2222-2222-2222-222222222222', id, 'Orçamento Aprovado', 'CNX-TESTE', 'connect' FROM public.empresas LIMIT 1;
INSERT INTO public.connect_reserva_ambiente (tipo, lote_importacao, linha_planilha, cod_venda_connect, produto_codigo, ambiente, quantidade, motivo_sem_vinculo, orcamento_id)
VALUES ('reserva', '33333333-3333-3333-3333-333333333333', 1, 1, 1, 'L01', 1, 'cliente_nao_cadastrado', NULL),
       ('reserva', '33333333-3333-3333-3333-333333333333', 2, 2, 1, 'L01', 1, 'digitador_nao_encontrado', '22222222-2222-2222-2222-222222222222'),
       ('reserva', '33333333-3333-3333-3333-333333333333', 3, 3, 1, 'L01', 1, NULL, '22222222-2222-2222-2222-222222222222');
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT cod_venda_connect AS v, motivo_sem_vinculo AS m, sem_vinculo AS s FROM public.vw_connect_reserva_ambiente
            WHERE lote_importacao = '33333333-3333-3333-3333-333333333333' ORDER BY 1 LOOP
    RAISE NOTICE 'caso %: motivo=% -> sem_vinculo=%  (esperado: caso1 true, caso2 false, caso3 false)', r.v, coalesce(r.m, '(nenhum)'), r.s;
  END LOOP;
  RAISE NOTICE 'colunas da view: %', (SELECT count(*) FROM information_schema.columns WHERE table_name = 'vw_connect_reserva_ambiente');
  RAISE NOTICE 'anon le a view? %', has_table_privilege('anon', 'public.vw_connect_reserva_ambiente', 'SELECT');
END $$;
ROLLBACK;
