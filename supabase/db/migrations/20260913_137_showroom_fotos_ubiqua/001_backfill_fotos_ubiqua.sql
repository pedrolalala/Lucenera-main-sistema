-- SPEC-137 — Showroom: peças Ubiqua marcadas como pronta-entrega sem foto.
--
-- Contexto: produtos com marca UBIQUA e estoque_showroom > 0 (ja sinalizados
-- pela equipe como pronta-entrega) nao aparecem em vw_showroom_publico porque
-- nenhum tem imagem_showroom_url preenchido. O catalogo Ubiqua (revenda_ubiqua,
-- tabela isolada do sistema catalogo-pecas-ubiqua-e6fa0) ja tem foto pronta
-- (imagem_catalogo_url, bucket publico revenda-ubiqua-images) para quase todas
-- essas pecas.
--
-- Escopo (decisao do usuario em SPEC-137):
--   - So corrige as pecas JA marcadas como showroom (estoque_showroom > 0).
--     Nao promove peca nova a showroom a partir do estoque de revenda_ubiqua.
--   - produtos continua a UNICA fonte de verdade de estoque do showroom.
--     revenda_ubiqua e usada so como origem pontual da foto (backfill unico,
--     sem trigger/sincronizacao continua).
--   - Reaproveita a URL publica existente (sem re-upload de arquivo).
--
-- Chave de cruzamento: produtos.referencia = revenda_ubiqua.referencia
-- (case/trim-insensitive). Testado no banco real 2026-09-13: afeta 33 linhas.
--
-- Reversao: os 33 codigo_produto afetados ficam no SELECT de verificacao
-- abaixo antes do UPDATE — guardar esse resultado para poder reverter com
--   update produtos set imagem_showroom_url = null where codigo_produto in (...);

begin;

-- Verificacao pre-UPDATE (aparece no log da migration para conferencia/rollback)
do $$
declare
  v_count int;
begin
  select count(*) into v_count
  from public.produtos p
  join public.marcas m on m.id = p.marca_id
  join public.revenda_ubiqua ru on lower(trim(ru.referencia)) = lower(trim(p.referencia))
  where m.nome ilike 'ubiqua'
    and coalesce(p.estoque_showroom, 0) > 0
    and (p.imagem_showroom_url is null or p.imagem_showroom_url = '')
    and ru.imagem_catalogo_url is not null
    and ru.imagem_catalogo_url <> '';

  raise notice 'SPEC-137: % produtos Ubiqua vao receber imagem_showroom_url', v_count;

  if v_count = 0 then
    raise exception 'SPEC-137: nenhuma linha corresponde ao criterio esperado (esperava ~33) — abortando para revisao manual';
  end if;
end $$;

update public.produtos p
set imagem_showroom_url = ru.imagem_catalogo_url
from public.revenda_ubiqua ru, public.marcas m
where m.id = p.marca_id
  and lower(trim(ru.referencia)) = lower(trim(p.referencia))
  and m.nome ilike 'ubiqua'
  and coalesce(p.estoque_showroom, 0) > 0
  and (p.imagem_showroom_url is null or p.imagem_showroom_url = '')
  and ru.imagem_catalogo_url is not null
  and ru.imagem_catalogo_url <> '';

commit;
