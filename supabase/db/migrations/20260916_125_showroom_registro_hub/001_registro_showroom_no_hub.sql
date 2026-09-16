-- SPEC-125 (pendência residual) — Registrar o Showroom em public.systems para
-- aparecer como card na Central Lucenera (Hub).
--
-- Decisão do usuário (2026-09-16):
--   - Link aponta para /admin (curadoria: fotos do estoque + composição,
--     SPEC-125/148/149) — a ferramenta de trabalho interna, não a vitrine
--     pública. Mesmo padrão dos demais cards da Central (todos apontam
--     pra ferramentas internas, não sites públicos).
--   - visivel_no_hub = true, mas SEM entrada em papel_permissoes — só o
--     admin (que já enxerga todo `visivel_no_hub = true` via bypass em
--     Dashboard.tsx) vê o card por enquanto. Se decidirem liberar pra mais
--     gente depois, é um INSERT em papel_permissoes (SPEC-006/069), não
--     precisa alterar esta linha.
--
-- RASCUNHO — não aplicar sem aprovação.

begin;

insert into public.systems (name, description, link, icon_name, display_order, slug, visivel_no_hub)
values (
  'Showroom Lucenera',
  'Curadoria do showroom: vincular peças do PowerPoint, subir fotos do estoque e montar conjuntos (peça composta).',
  'https://tela-showroom-522b1.goskip.app/admin',
  'Store',
  12,
  'showroom',
  true
)
on conflict (slug) do nothing;

commit;
