-- SPEC-130 — trigger BEFORE que garante `last_sync_source`/`last_synced_by` sempre corretos
-- em toda escrita normal de `projetos` (feita por usuário via CRM ou por qualquer outro
-- processo comum): marca 'sistema' + auth.uid(). A ÚNICA exceção é a RPC de pull
-- `aplicar_pull_sharepoint()` (009), que liga a flag de sessão `app.sync_em_andamento` antes
-- de escrever — só nesse caso a stamp preserva o que a RPC gravou ('sharepoint', sem usuário).
--
-- É esse comportamento que faz o anti-eco da trigger de push (006) funcionar sem precisar
-- comparar hash: `last_sync_source` é sempre confiável, nunca um valor "herdado" por acaso
-- de uma escrita anterior.

create or replace function public.trg_projetos_stamp_sync_meta_fn()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.sync_em_andamento', true), 'off') <> 'on' then
    new.last_sync_source := 'sistema';
    new.last_synced_by := auth.uid();
  end if;
  return new;
end;
$$;

comment on function public.trg_projetos_stamp_sync_meta_fn() is
  'Garante last_sync_source/last_synced_by corretos em toda escrita normal de projetos; só não age quando a RPC de pull liga a flag de sessão app.sync_em_andamento. SPEC-130.';

create trigger trg_projetos_stamp_sync_meta
before insert or update on public.projetos
for each row
execute function public.trg_projetos_stamp_sync_meta_fn();
