---
titulo: "SPEC-242 — Segurança: correções da rodada 01 do roteiro"
status: código pronto (A1–A4, C1, E); nada aplicado/publicado em produção
data_ultima_modificacao: 2026-11-04
origem: "03-Projeto/Seguranca/rodadas/2026-11-03_rodada_01.md + pedido do usuário 04/11 ('deixar o sistema seguro')"
roteiro: 03-Projeto/Seguranca/ROTEIRO_ANALISE_SEGURANCA_DADOS.md
sistemas_envolvidos:
  - Supabase SP (bgtfrcbipuxnsexbppsh) e Ohio (vcvcwzmbiftcawncibke)
  - Edge Functions do repo central (supabase/functions)
  - Orçamentos (gestao-financeira-clone-544cb) — tira /signup
  - Os 19 sistemas Cloudflare — public/_headers
relacionadas: [SPEC-069, SPEC-183, SPEC-196, SPEC-198, SPEC-238]
---

# SPEC-242 — Segurança: correções da rodada 01

## Por quê
A rodada 01 do roteiro (03/11) e a continuação (04/11) mostraram que o banco protege bem as **tabelas** contra
visitante, mas existem portas laterais: funções de banco, Edge Functions, storage, cadastro aberto, cópias antigas
(Ohio/Skip) e repositórios públicos.

## Achados e correções

| # | Nível | Achado | Correção | Estado |
|---|---|---|---|---|
| A1 | **CRÍTICO** | `admin_update_user_password`, `admin_update_user_role`, `admin_update_user_status`, `criar_usuario`: `IF v_caller_role != 'admin'` com `v_caller_role` NULL (visitante/conta sem linha em `usuarios`) **não bloqueia**. Se `anon` tem EXECUTE (padrão do Supabase), visitante troca a senha do admin. **Não confirmado ao vivo** (chamada bloqueada pelo modo automático). | migration **262**: troca só a linha do IF por `IS DISTINCT FROM` na definição do banco + `REVOKE ... FROM PUBLIC, anon` | pronta, dry-run escrito |
| A2 | **CRÍTICO** | storage: `orcamentos` público, visitante lista 15 PDFs e tem política de upload (`Anon can upload`); visitante lista `producao_pedidos`; `notas_fiscais*`, `garantia_anexos` públicos | migration **263**: `orcamentos` privado + apaga as políticas dele; leitura/listagem dos outros só logado (links gravados continuam abrindo) | pronta, dry-run escrito |
| A3 | **CRÍTICO** | Edge Functions com service_role sem conferir quem chama: `update-project`, `salvar-projeto`, `process-budget-pdf`, `classificar_solicitacao` | `_shared/exigir-usuario.ts` (login real + `pode_acessar_sistema`): CRM nas 2 de projeto; `process-budget-pdf` exige que o orçamento seja visível pelo RLS de quem chama e manda link com prazo (7 dias) | código pronto, falta publicar |
| A4 | **CRÍTICO** | Publicadas sem nenhuma tela usar: `process-remittance` (marca boletos como enviados), `process-billing-automation` (cria NF/altera boleto), `sync-fechamentos-automatica`, `sync-teams` (simulação), `welcome-email` (manda e-mail para qualquer endereço) | **despublicar** em SP e Ohio | falta executar |
| B | ALTO | `notas_fiscais`, `notas_fiscais_compra`, `producao_pedidos`, `garantia_anexos` continuam públicos (link aberto para quem tiver a URL; nomes com uuid+data, difíceis de adivinhar) | fase B: bucket privado + `createSignedUrl` na hora de abrir (Compras `notas-fiscais-compra.ts:315`, Adm. Bancária `NotasFiscais.tsx:178`, Produção `producao.ts:262`, Garantia) + converter os links gravados para caminho | a fazer |
| C1 | ALTO | `/signup` aberto no Orçamentos | rota vira redirect para `/login`, link "Cadastrar" sai | código pronto, build ok |
| C2 | ALTO | signup nativo ligado (SP e Ohio). Ubiqua usa `cadastro-ubiqua` (Admin API) e a Central usa `criar_usuario` → nenhum dos dois depende do signup nativo | desligar "Allow new users to sign up" no painel Auth de SP | **usuário** (painel) |
| C3 | ALTO | `cadastro-ubiqua` cria conta confirmada para qualquer um (de propósito): toda política "qualquer logado" vale para o público | etapa 5 do roteiro como "conta nova" e fechar o que aparecer (SPEC-238 `somente_ubiqua`) | depende de liberar leitura do banco |
| D | ALTO | Ohio com dados de 14/10 + mesmas falhas; 17 sites `*.goskip.app` no ar | backup final, pausar Ohio, despublicar/cancelar Skip (SPEC-198) | **usuário** (decisão) |
| G | ALTO | 12 repositórios GitHub **públicos** (Adm. Bancária, Cadastro, Catálogo Ubiqua, Central, Compras, Dashboard, RH, Logística, Power Point, CRM, Orçamentos). Histórico sem segredo (só chave anon), mas o código mostra cada furo | tornar privados (`gh repo edit --visibility private`); Cloudflare continua buildando (o app já lê os privados) | **usuário** (confirmar) |
| E | MÉDIO | sites sem `X-Frame-Options`/HSTS/nosniff | `public/_headers` em 19 sistemas (sem CSP de script por enquanto) | criado, falta commit/push |
| F | MÉDIO | `produto_caixa_editores` com grant para anon | na 262 | pronta |

## Ordem de aplicação
1. **262** (dry-run → aplicar) — mais urgente.
2. Publicar as 4 Edge Functions corrigidas em SP (`supabase functions deploy <nome> --project-ref bgtfrcbipuxnsexbppsh`)
   e despublicar as 5 da A4 (`supabase functions delete`). Repetir a despublicação em Ohio.
3. **263** (dry-run → aplicar) — depois do deploy da `process-budget-pdf` (senão o link do e-mail quebra).
4. Push do Orçamentos (C1) e dos `_headers` (E) — Cloudflare publica sozinho.
5. Painel: desligar signup (C2). Decidir D e G.
6. Rodar de novo as etapas 2–4 do roteiro e a etapa 5 completa.

## Critérios de aceite
- Visitante: `rpc/criar_usuario`, `rpc/admin_update_user_*` → 401/403; `update-project`, `salvar-projeto`,
  `process-budget-pdf`, `classificar_solicitacao` com a chave anon → 401; funções da A4 → 404;
  `storage/v1/object/list/<bucket>` dos buckets de documento → 0 itens; `object/public/orcamentos/...` → "Bucket not found".
- Logado: Central cria usuário e troca senha (admin); CRM cria e edita projeto; Catálogo Ubiqua gera orçamento e o
  e-mail chega com PDF anexo e link que abre; Central de Solicitações classifica e avisa no Teams; Compras/Adm.
  Bancária/Produção ainda abrem os arquivos antigos.
- `curl -I` em qualquer `*.pages.dev` mostra `X-Frame-Options: DENY`.

## Rollback
- 262 e 263 têm `rollback.sql`. Edge Functions: `git revert` + deploy de novo. `_headers`: apagar o arquivo.

## Documentos a atualizar
- `03-Projeto/Seguranca/rodadas/2026-11-03_rodada_01.md` (o que foi corrigido), `CHANGELOG.md`, AGENTS.md (regra nova:
  Edge Function com service_role sempre usa `_shared/exigir-usuario.ts`; função de banco com trava de papel usa
  `IS DISTINCT FROM`/`IS NOT TRUE`, nunca `!=` em variável que pode ser NULL).

## Realizado
### 2026-11-04
- Migrations 262 e 263 escritas (up/rollback/dry_run, nada aplicado). Edge Functions corrigidas (A3) no repo central.
  Orçamentos: `/signup` removido, build ok. `public/_headers` criado em 19 sistemas. Varredura do histórico git dos
  12 repositórios públicos: sem segredo (script `scripts/seguranca/04_segredos_historico_git.py`).

## Pendências
- [ ] SPEC-242 — aplicar 262 (precisa de autorização para conexão no banco)
- [ ] SPEC-242 — `supabase login` para publicar/despublicar Edge Functions (token do .env vencido)
- [ ] SPEC-242 — aplicar 263 depois do deploy da process-budget-pdf
- [ ] SPEC-242 — commit/push Orçamentos + `_headers` nos 19 repositórios
- [ ] SPEC-242 — desligar signup nativo no painel (SP)
- [ ] SPEC-242 — decidir: repositórios privados (G); pausar Ohio/derrubar Skip (D)
- [ ] SPEC-242 B — buckets de documento privados + link com prazo nas telas
- [ ] SPEC-242 — etapa 5 do roteiro (conta nova/auxiliar; RPCs SECURITY DEFINER executáveis por anon)
