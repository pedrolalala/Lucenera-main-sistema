# 20260831_128_spec125_showroom_admin_login

**Status: APLICADO no Supabase real em 2026-08-31** (Management API, com autorização do usuário).
Após aplicar rodou-se `NOTIFY pgrst, 'reload schema'` (o PostgREST não pegou as novas
assinaturas de função sozinho).

## O que muda em relação à 127

A tela `/admin` deixa de usar PIN único e passa a **usuário + senha**:

- `showroom_config`: remove `admin_pin`; adiciona `admin_user` = `Lucenera` e
  `admin_pass_hash` = bcrypt de `Lucenera123` (`extensions.crypt` / `gen_salt('bf')`).
- `showroom_cred_ok(p_user, p_senha)` — helper interno; **revogado de anon** (não executável
  por PostgREST).
- `showroom_login(p_user, p_senha)` — valida a credencial na hora (a tela dá feedback no
  submit). Retorna `{ok:true}` ou `raise` `28000`.
- `showroom_vincular_peca` / `showroom_desvincular_peca` — recriadas com assinatura
  `(p_user text, p_senha text, …)` no lugar de `(p_pin text, …)`. Gravam `vinculado_por = p_user`.
- `showroom_buscar_produto(text)` — inalterada.

## Trocar a senha depois

```sql
update public.showroom_config
   set valor = extensions.crypt('<nova-senha>', extensions.gen_salt('bf'))
 where chave = 'admin_pass_hash';
-- e/ou o usuário:
update public.showroom_config set valor = '<novo-usuario>' where chave = 'admin_user';
```

## Ao terminar a curadoria

```sql
revoke execute on function public.showroom_login(text,text)                   from anon, authenticated;
revoke execute on function public.showroom_vincular_peca(text,text,int,int)   from anon, authenticated;
revoke execute on function public.showroom_desvincular_peca(text,text,int)    from anon, authenticated;
revoke execute on function public.showroom_buscar_produto(text)              from anon, authenticated;
```

## Rollback

Recriar as RPCs 127 com assinatura `(p_pin …)` e restaurar `admin_pin` em `showroom_config`
(ver `../20260831_127_spec125_showroom_curadoria/001_curadoria.sql`).
