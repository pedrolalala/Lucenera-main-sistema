---
titulo: "SPEC-163 — Registrar Controle de Produção e Controle de Garantia na Central (Hub)"
status: "CONCLUÍDA (24/09/2026) — migration aplicada no Supabase real (dry-run+COMMIT); verificado via hub_sistemas_permitidos para usuários não-admin (Debora, Mariane, Caroline veem os 2 sistemas)."
data_ultima_modificacao: 2026-09-24
sistemas_envolvidos:
  - Central Lucenera / Hub (`central-lucenera-dashboard-1c9ba`) — só dados, sem código
  - Controle de Produção (Skip 60535) e Controle de Garantia (Skip 60545) — criados na SPEC-156
relacionado: [SPEC-156, SPEC-120, SPEC-153]
---

## Pedido (usuário, 24/09/2026)

> "adicione o controle de produção e garantia dentro do sistema central!!"

## Solução

Os dois sistemas foram criados (SPEC-156) sem registro em `public.systems`, então não aparecem no Hub nem
no menu lateral (SystemSwitcher, SPEC-120). Migration
`supabase/db/migrations/20260924_162_registro_producao_garantia_hub/001_registro_producao_garantia_hub.sql`:

- 2 linhas em `systems`: `controle-producao` (ícone Factory, ordem 14) e `controle-garantia`
  (ícone ShieldCheck, ordem 15), com as URLs de produção do Skip.
- Acesso: **todos os 13 papéis** recebem `visualizar` em `papel_permissoes` (decisão do usuário) — é o que
  `hub_sistemas_permitidos` lê. Admin já vê tudo por bypass.
- Sem mudança de código no Hub: `Dashboard.tsx`/`SystemSwitcher.tsx` leem `systems` e resolvem qualquer
  ícone do lucide-react pelo nome.

## Fora de escopo

- Os dois sistemas continuam exigindo só login (não chamam `hub_pode_executar`) e não têm o SystemSwitcher
  próprio — só aparecem no menu dos outros sistemas.

## Rollback

`DELETE FROM papel_permissoes WHERE system_id IN (SELECT id FROM systems WHERE slug IN
('controle-producao','controle-garantia')); DELETE FROM systems WHERE slug IN ('controle-producao','controle-garantia');`
