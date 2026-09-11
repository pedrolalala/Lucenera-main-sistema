-- SPEC-132 Fase B — grupos fiscais do export Connect de Produtos.
-- Duas colunas de texto novas em public.produtos, populadas pelo
-- scripts/importar_produtos_estoque.py a partir de Produtos__AAAA-MM-DD.xlsx
-- (colunas GrupoFiscalNContribuinte / GrupoFiscalRevenda).
--
-- Não mexe em preço, não cria/altera trigger. Operação segura (ADD COLUMN NULL).

alter table public.produtos
  add column if not exists grupo_fiscal_nao_contribuinte text,
  add column if not exists grupo_fiscal_revenda text;

comment on column public.produtos.grupo_fiscal_nao_contribuinte is
  'Classificação fiscal do Connect (coluna GrupoFiscalNContribuinte): Nacional / Nacional Nao Contribuinte / Nacional Revenda. SPEC-132.';
comment on column public.produtos.grupo_fiscal_revenda is
  'Classificação fiscal do Connect (coluna GrupoFiscalRevenda): Nacional / Nacional Revenda. SPEC-132.';
