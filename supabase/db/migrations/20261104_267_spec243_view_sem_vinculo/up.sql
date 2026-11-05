-- SPEC-243 — corrige vw_connect_reserva_ambiente.sem_vinculo.
-- Defeito: sem_vinculo era "motivo_sem_vinculo IS NOT NULL", mas linhas JÁ vinculadas a um orçamento podem ter motivo só
-- informativo (digitador_nao_encontrado, projeto_por_codigo_legado) e apareciam como "sem vínculo" na Venda Parcial.
-- Correção: sem_vinculo = a linha NÃO virou orçamento (orcamento_id IS NULL). O motivo continua visível em motivo_sem_vinculo.
-- Mesmas colunas e mesma ordem da view da 264 (CREATE OR REPLACE exige isso). Nada além da expressão muda.
BEGIN;

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

COMMIT;
