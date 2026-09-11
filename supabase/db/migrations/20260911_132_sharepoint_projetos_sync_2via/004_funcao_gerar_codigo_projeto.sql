-- SPEC-130 — gerar_codigo_projeto(): fonte única de geração do código do projeto (formato
-- AA.NNN, ex. "26.267", confirmado por amostra real da lista SharePoint em 2026-09-11).
-- A partir da virada operacional (SPEC-131), o SharePoint para de gerar código e passa a
-- receber o que o sistema já gerou.
--
-- Auto-corretiva de propósito: em vez de confiar cegamente em projeto_codigo_sequencia,
-- toda chamada confere o maior número já usado em projetos.codigo pro ano corrente e nunca
-- gera abaixo disso — protege contra a sequência ficar desatualizada (ex. código criado
-- direto na lista SharePoint e trazido pelo pull antes da sequência ser avisada).
-- security definer: permite chamar via RPC autenticado sem dar UPDATE direto na tabela de
-- sequência pro usuário comum.

create or replace function public.gerar_codigo_projeto()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ano text := to_char(now(), 'FMYY');
  v_max_existente integer;
  v_numero integer;
begin
  select coalesce(max(nullif(split_part(codigo, '.', 2), '')::integer), 0)
    into v_max_existente
  from public.projetos
  where codigo like v_ano || '.%';

  insert into public.projeto_codigo_sequencia (ano, ultimo_numero)
  values (v_ano, greatest(v_max_existente, 0) + 1)
  on conflict (ano) do update
    set ultimo_numero = greatest(
      public.projeto_codigo_sequencia.ultimo_numero,
      v_max_existente
    ) + 1
  returning ultimo_numero into v_numero;

  return v_ano || '.' || v_numero;
end;
$$;

comment on function public.gerar_codigo_projeto() is
  'Gera o próximo código de projeto no formato AA.NNN (ano corrente). Fonte única a partir da virada da SPEC-131 — o SharePoint deixa de gerar código. SPEC-130.';

revoke all on function public.gerar_codigo_projeto() from public;
grant execute on function public.gerar_codigo_projeto() to authenticated, service_role;
