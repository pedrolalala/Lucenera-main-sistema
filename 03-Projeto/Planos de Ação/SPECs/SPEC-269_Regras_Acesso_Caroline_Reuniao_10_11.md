---
titulo: "SPEC-269 — Regras de acesso da Caroline (reunião 10/11): consulta de produto, sem LT/comissão"
status: aplicada e no ar em 10/11/2026 (migration 323 + front); falta teste real da Caroline
---

# SPEC-269 — Regras de acesso da Caroline

> Pedido (10/11/2026): fechar o que a Caroline (administrativo) pode e não pode no sistema. Ajusta o papel `assistente_administrativa` da SPEC-260 (migration 311).

## Decisões da reunião
| Sistema | Pode? | Observação |
|---|---|---|
| Contas a Pagar / Contas a Receber / Financeiro | sim, tudo | inclui acordos (a desenvolver) e vendas |
| Orçamentos / aprovação financeira | sim | |
| Vendas | sim | |
| Venda Parcial (`separacao-parcial`) | sim | **novo** |
| Cadastro / consulta de produto | só consultar | **cai de "tudo" para `visualizar`** |
| Showroom | sim (consulta de peça) | **novo**, `visualizar` |
| Central de Solicitações | ver + criar, sem aprovar | igual hoje |
| Necessidade de Compra | não | **sai** |
| Controle de Garantia / Produção | não | **saem** (hoje `visualizar`) |
| CRM, RH, Entregas, Fichas Técnicas, Dashboard, Memória, Movimentação de Peças | não | já sem acesso — conferir |
| **LT e comissão** | **não emite** | título de comissão que cai no Contas a Pagar ela vê normal |

## O ponto difícil: LT/comissão
O motor do RT (migration 321) e as funções `financeiro_rt_lancar_manual` / `financeiro_rt_definir_ativo` só exigiam o sistema `financeiro`, que ela precisa. Decisão do usuário: **acesso novo `financeiro-rt-comissao`** (chave em Acesso a Sistemas, sem card no Hub).

- Nova `financeiro_exige_rt()` (exige `financeiro` **e** `financeiro-rt-comissao`) entra em `financeiro_rt_lancar_manual`, `financeiro_rt_definir_ativo`, `financeiro_definir_rt` e na criação de título RT de `financeiro_criar_titulo`. `financeiro_exige` não mudou: ela **continua baixando/pagando** RT já gerado (achado do revisor).
- `vw_financeiro_rt_arquitetos`, `vw_financeiro_rt_relatorio`, `vw_financeiro_rt_previsto_venda` e a política `rt_config_leitura` trocam o portão para o acesso novo.
- Quem já tem `financeiro` (exceto a Caroline) recebe o acesso novo, então nada muda para Filippo/Vinicius/Pedro/Lana.
- **Não muda:** o gatilho automático do RT ao receber uma parcela continua rodando (é do banco, não da usuária). Os títulos `rt_arquiteto` seguem visíveis na lista do Contas a Pagar. Salário/comissão de folha continuam exigindo `rh`.

## Papel `administracao_comercial` sai da Caroline (achado no dry-run)
Ela tinha também esse papel (Filippo e financeiro@ também), que soma Cadastro criar/editar, Necessidade de Compra e Garantia/Produção, anulando o "só consultar". Decisão do usuário: **tirar o papel só dela**. Consequência: ela perde a edição de caixa fechada (`pode_editar_caixa_fechada` olha esse papel); se precisar, entra em `produto_caixa_editores`.

**Limite conhecido:** as políticas de `produtos` (INSERT/UPDATE) também aceitam `orcamentos` criar/editar, e ela tem tudo em Orçamentos. Decisão do usuário: aceitar; o bloqueio de editar produto fica **só na tela do Cadastro** (mexer na RLS pode quebrar o fluxo de orçamento das equipes).

## Migration 323 (APLICADA 10/11/2026)
`supabase/db/migrations/20261110_323_spec269_carol_acessos_reuniao_10_11/` (`up.sql` + `rollback.sql`). Sem BEGIN/COMMIT, para dry-run em ROLLBACK.

## Pendências antes de aplicar
- [x] Dry-run em ROLLBACK 10/11: up.sql roda; `user_id` = `usuarios.id` confirmado; Caroline recebe 42501 ao lançar RT, Pedro passa da trava; relatório/previsão de RT vazios para ela.
- [x] Rollback completo (views coladas, funções revertidas) e testado no dry-run.
- Snapshot do estado anterior da Caroline guardado no scratchpad da sessão (`snapshot_antes_323.json`).
- Limite aceito: `financeiro_regras_repasse` segue legível por `financeiro`/`rh` (percentuais de RT); separar por tipo mexeria na leitura do RH.
- [x] Testado em transação: Caroline barrada nas 4 portas de RT; Pedro/Filippo/Vinicius/financeiro@ passam da trava; view de arquitetos e relatório vazios para ela.
- [ ] Teste real da Caroline na tela (Contas a Pagar normal, pagar RT já existente).
- [x] "Cadastro só visualizar" no banco: só vale depois de tirar `administracao_comercial`; ainda editável via `orcamentos` (limite aceito acima).
- [x] Front (10/11, commit 001a6da, NO AR em contas-pagar-lucenera.pages.dev, deploy 8d7209fe): `retorno-bancario-bradesco-5392a` — hook `use-pode-emitir-rt` (RPC `pode_acessar_sistema('financeiro-rt-comissao')`), menu "Regras de RT" some e a rota `/regras-rt` mostra "Acesso restrito" para quem não tem o acesso. É a única tela de RT/comissão do app.
- [ ] Revisor antes de aplicar; CHANGELOG ao concluir.

## Rollback
`rollback.sql` da pasta da migration.
