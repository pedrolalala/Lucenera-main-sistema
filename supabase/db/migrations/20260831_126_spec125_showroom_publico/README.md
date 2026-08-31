# 20260831_126_spec125_showroom_publico

**Status: APLICADO no Supabase real em 2026-08-31** (via Management API `/database/query`,
com autorização explícita do usuário). Verificado: coluna, view, grants (anon/authenticated
só SELECT), bucket e policy criados; `GET /rest/v1/vw_showroom_publico` responde `200` para
`anon`; `GET /rest/v1/produtos` para `anon` continua `200 []` (sem vazamento).

## O que faz

1. `produtos.imagem_showroom_url text` (nullable, sem default) + índice parcial da vitrine.
2. `vw_showroom_publico` — view somente-leitura com whitelist de colunas
   (`codigo_produto, nome, marca, categoria, estoque_showroom, valor_venda,
   descricao_tecnica, imagem_showroom_url, atualizado_em`). Já filtra
   `ativo AND imagem_showroom_url IS NOT NULL AND estoque_showroom > 0`.
3. `GRANT SELECT ON vw_showroom_publico TO anon` — **nenhum** grant/policy novo em `produtos`.
4. Bucket de Storage público `showroom-lucenera` (5 MB, jpeg/jpg/png/webp) + policy de
   leitura `anon`.

## Pontos de revisão antes de aplicar

- A view é **SECURITY DEFINER** (sem `security_invoker`) de propósito: é o que permite o
  `anon` ler sem abrir `produtos`. O linter do Supabase vai apontar `security_definer_view` —
  aceito nesta SPEC. Alternativa discutida (não escolhida): Edge Function pública.
- Conferir se `updated_at` existe em `produtos` (usado como `atualizado_em`). Se o nome real
  for outro, ajustar.
- `categorias_produto` e `marcas` — confirmar nomes de coluna (`nome`) contra
  `supabase/db/current/01_schema_full.sql`.
- Rollback: `drop view public.vw_showroom_publico; alter table public.produtos drop column
  imagem_showroom_url; delete from storage.buckets where id = 'showroom-lucenera';` (só se o
  bucket estiver vazio) + `drop policy "showroom_lucenera_public_read" on storage.objects;`.

## Verificação pós-aplicação

Hoje, com a chave anônima, `GET /rest/v1/produtos` já responde `200 []` (RLS filtra tudo,
nenhuma linha vaza) e `GET /rest/v1/vw_showroom_publico` responde `404` (view não existe).
Depois de aplicar, o esperado é:

```
GET /rest/v1/vw_showroom_publico?select=*   -> 200 com as peças (whitelist de colunas)
GET /rest/v1/produtos?select=preco_custo    -> 200 [] (continua sem vazar nada)
```

Rollback rápido: ver seção acima.
