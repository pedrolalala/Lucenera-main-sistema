# 20260831_127_spec125_showroom_curadoria

**Status: APLICADO no Supabase real em 2026-08-31** (Management API, com autorização do usuário).

## O que faz

Suporte à tela `/admin` do site do showroom (curadoria manual: vincular peça do PPT → produto).

- `showroom_import_pecas` — staging das 167 peças do PowerPoint (nome, foto no bucket
  `showroom-lucenera/import/`, candidatos, `codigo_produto_vinculado`). RLS: SELECT liberado
  para `anon` (só nome + foto + candidatos, nada sensível). Escrita só via RPC.
- `showroom_config` — guarda `admin_pin`. RLS on, sem policy → **ninguém lê por PostgREST**.
- `showroom_vincular_peca(p_pin, p_slide, p_codigo_produto)` — SECURITY DEFINER. Confere o
  PIN, grava `produtos.imagem_showroom_url` = foto da peça e `estoque_showroom` (mantém o
  valor atual se > 0; senão `qtd_ppt` ou 1). Marca a peça como vinculada.
- `showroom_desvincular_peca(p_pin, p_slide)` — limpa `imagem_showroom_url` do produto e o
  vínculo.
- `showroom_buscar_produto(p_termo)` — autocomplete por código/nome/SKU/referência.

## Segurança / pós-uso

- As 3 RPCs são `EXECUTE TO anon` e mexem em `produtos` (só `imagem_showroom_url` +
  `estoque_showroom`). A proteção é o PIN em `showroom_config`. Blast radius se o PIN vazar:
  trocar fotos/estoque_showroom do showroom entre produtos — reversível, sem tocar
  preço/nome/fiscal.
- **Trocar o PIN** (default `TROCAR-ESTE-PIN`):
  `update public.showroom_config set valor = '<novo-pin>' where chave = 'admin_pin';`
- **Depois de concluir a curadoria**, revogar o acesso:
  `revoke execute on function public.showroom_vincular_peca(text,int,int) from anon;`
  (idem desvincular/buscar) — a vitrine pública não depende dessas RPCs.

## Rollback

```sql
drop function if exists public.showroom_vincular_peca(text,int,int);
drop function if exists public.showroom_desvincular_peca(text,int);
drop function if exists public.showroom_buscar_produto(text);
drop table if exists public.showroom_import_pecas;
drop table if exists public.showroom_config;
```
