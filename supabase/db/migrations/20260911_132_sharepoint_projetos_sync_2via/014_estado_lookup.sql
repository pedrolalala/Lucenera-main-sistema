-- SPEC-130 — mapa de Estado (campo de lookup no SharePoint, `EstadoLookupId`, aponta pra
-- lista "Estados" do mesmo site — id `946a5bd0-0e6e-4da2-9cce-3e1067a4bf47`). Achado
-- 2026-09-11: a automação de criação de grupo/pasta provavelmente exige Estado preenchido
-- (a lista mostra "Informações necessárias" pro item sem isso) — nenhum dos 3 testes até
-- agora (7151/7152/7154) tinha Estado, nenhum criou grupo. Lookup ≠ texto: precisa do ID
-- numérico do item na lista "Estados", não da sigla. Dados conferidos direto via Graph
-- (28 itens, sem paginação).

create table public.sharepoint_estado_map (
  estado varchar(2) primary key,
  sharepoint_item_id text not null
);

alter table public.sharepoint_estado_map enable row level security;

insert into public.sharepoint_estado_map (estado, sharepoint_item_id) values
  ('SP', '1'), ('PR', '2'), ('SC', '3'), ('RS', '4'), ('MS', '5'),
  ('RO', '6'), ('AC', '7'), ('AM', '8'), ('RR', '9'), ('PA', '10'),
  ('AP', '11'), ('TO', '12'), ('MA', '13'), ('RN', '14'), ('PB', '15'),
  ('PE', '16'), ('AL', '17'), ('SE', '18'), ('BA', '19'), ('MG', '20'),
  ('RJ', '21'), ('MT', '22'), ('GO', '23'), ('DF', '24'), ('PI', '25'),
  ('CE', '26'), ('ES', '27');

comment on table public.sharepoint_estado_map is
  'De-para entre projetos.estado (sigla, 2 letras) e o ID do item correspondente na lista SharePoint "Estados" (lookup, EstadoLookupId). SPEC-130, 2026-09-11.';
