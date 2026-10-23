---
titulo: "SPEC-225 — Separar a Administração Bancária em Contas a Pagar e Contas a Receber"
status: pendente
data_ultima_modificacao: 2026-10-23
sistemas_envolvidos:
  - Administração Bancária (retorno-bancario-bradesco-5392a) — vira a base dos 2 sistemas novos
  - Central Lucenera (Hub) — 2 cards novos, card antigo some
  - Banco (systems / user_system_access)
---

# SPEC-225 — Separar a Administração Bancária em Contas a Pagar e Contas a Receber

## Checklist de Ação

- [x] A1. Migration `systems`: criar `contas-pagar` e `contas-receber` (visíveis no Hub); `financeiro` fica `visivel_no_hub = false` (continua sendo a chave de permissão)
- [x] A2. Migration `user_system_access`: trigger que espelha o acesso entre `financeiro`, `contas-pagar` e `contas-receber` (dar/tirar um = dar/tirar os três) + carga inicial dos 4 usuários atuais
- [x] B1. Código: constante de modo `VITE_MODO_SISTEMA = pagar | receber` (`src/lib/modo-sistema.ts`) lida no build
- [x] B2. Menu (`Layout.tsx`) por modo; nome do sistema e `SystemSwitcher currentSlug` por modo; rotas que não pertencem ao modo redirecionam
- [x] B3. Consultar Duplicatas, Contas em Aberto, Cadastrar Duplicata, Baixar Duplicata, Notas Fiscais: tipo fixo pelo modo, sem botão/seleção Pagar|Receber, consultas sempre filtradas por `tipo_operacao` (CP/CR) ou `transacoes.tipo` (despesa/receita)
- [x] B4. Boletos, Remessa, Retorno de Boletos, Retorno antigo: só no modo `receber`
- [x] B5. Pagamentos antecipados (SPEC-215): só no modo `pagar`
- [x] B6. Exportar Excel, títulos, textos de "Acesso negado" por modo
- [x] C1. Cloudflare Pages: projetos `contas-pagar-lucenera` e `contas-receber-lucenera` (mesmo repositório, build com a variável de modo)
- [x] C2. `adm-bancaria-lucenera.pages.dev` vira página de redirecionamento com 2 botões (Contas a Pagar / Contas a Receber)
- [ ] C3. Auth SP: incluir os 2 endereços novos nos redirects permitidos
- [x] C4. Links que apontam para `adm-bancaria-lucenera.pages.dev` passam para Contas a Receber (são de boleto/recebimento): `FINANCEIRO_URL` em `gestao-financeira-clone-544cb (1)/src/components/budgets/FinanceResultModal.tsx` (Orçamento) e `vendas-lucenera/src/pages/Vendas.tsx` (Vendas)
- [x] D. CHANGELOG, `04-Sistemas` sumário/AI_DB_CONTEXT, ponteiro do submodule

### Passos manuais do usuário

- [x] Aprovar a SPEC
- [ ] Testar os 2 sistemas com o pessoal da administração antes de esconder o card antigo
- [ ] (Se faltar espaço) conferir no painel do Supabase Auth que os 2 endereços novos entraram nos redirects

## Objetivo

Hoje a Administração Bancária mistura Contas a Pagar e Contas a Receber: cada tela tem um botão "Pagar | Receber" e
dá para lançar, consultar ou baixar o tipo errado sem perceber. O pessoal da administração quer **dois sistemas
separados**, cada um só com as funções que precisa, sem possibilidade de misturar.

## Decisões aprovadas (23/10/2026)

1. **2 sistemas, 1 código.** Dois sistemas no Hub ("Contas a Pagar" e "Contas a Receber"), cada um com endereço e
   card próprios, gerados do mesmo repositório (`retorno-bancario-bradesco-5392a`), cada build travado em CP ou CR.
   Correção comum vale para os dois.
2. **Mesma permissão.** Quem tem acesso a um tem aos dois (é o mesmo grupo da Adm. Bancária hoje).
3. **Administração Bancária sai do Hub** depois que os dois estiverem no ar e testados; o endereço antigo redireciona.
4. **Cobrança Bradesco (Controle de Boletos, Gerar Remessa, Retorno de Boletos) fica só em Contas a Receber.**

## Definição da SPEC

### Estado atual

- Sistema `adm-bancaria-lucenera.pages.dev`, slug Hub `financeiro`, 4 usuários com acesso.
- A permissão `financeiro` é usada por **40 policies** de RLS e pelas funções `reservar_remessa_cnab`,
  `lancar_pagamento_antecipado`, `cancelar_pagamento_antecipado`, e pelo `use-auth.tsx` do app
  (`hub_pode_executar(..., 'financeiro')`). **Por isso o slug `financeiro` não muda**: só o card some.
- Dados: `boletos.tipo_operacao` (CP/CR; hoje 10 boletos, todos CR), `notas_fiscais.tipo_operacao`,
  `transacoes.tipo` (despesa = Pagar, receita = Receber).

### Divisão das telas

| Tela | Contas a Pagar | Contas a Receber |
|---|---|---|
| Notas Fiscais | só CP (tipo fixo) | só CR (tipo fixo) |
| Consultar Duplicatas | só CP | só CR |
| Contas em Aberto | só Pagar + Pagamentos antecipados | só Receber |
| Cadastrar Duplicata | grava sempre CP | grava sempre CR |
| Baixar Duplicata | só CP | só CR |
| Controle de Boletos | — | sim |
| Gerar Remessa | — | sim |
| Retorno de Boletos (+ retorno antigo) | — | sim |

Regras:
- Nenhum seletor Pagar/Receber em nenhuma tela; o tipo vem do modo do build.
- Abrir um registro do outro tipo por link direto (ex.: `?ids=` do Exportar em Baixar Duplicata, edição em
  Cadastrar) **não carrega**: mostra aviso "Este lançamento é de Contas a Receber/Pagar".
- Rota de tela que não pertence ao modo → redireciona para a tela inicial do sistema.

### Banco (migration `20261023_239_spec225_contas_pagar_receber` — conferir número livre na hora)

1. `INSERT INTO systems` — `contas-pagar` ("Contas a Pagar", ícone `ArrowUpCircle`, link `https://contas-pagar-lucenera.pages.dev/`)
   e `contas-receber` ("Contas a Receber", ícone `ArrowDownCircle`, link `https://contas-receber-lucenera.pages.dev/`),
   `display_order` 6 e 7, `visivel_no_hub = true`.
2. Função `espelhar_acesso_financeiro()` + trigger `AFTER INSERT OR DELETE ON user_system_access`: se o sistema é um
   dos três, insere/apaga os outros dois para o mesmo usuário (`ON CONFLICT DO NOTHING`; guarda contra recursão por
   `pg_trigger_depth()`).
3. Carga inicial: dar `contas-pagar` e `contas-receber` aos 4 usuários que têm `financeiro`.
4. **Só depois do teste do usuário:** `UPDATE systems SET visivel_no_hub = false WHERE slug = 'financeiro'`
   (pode ir na mesma migration comentado, ou numa segunda).
5. Nenhuma policy nem RPC muda (todas continuam em `financeiro`).

### Código (repo `retorno-bancario-bradesco-5392a`)

- `src/lib/modo-sistema.ts`: `MODO = import.meta.env.VITE_MODO_SISTEMA` (`'pagar' | 'receber'`; build sem a variável
  falha, para não publicar um sistema "misturado" por engano), mais `TIPO_OPERACAO` (CP/CR), `TIPO_TRANSACAO`
  (despesa/receita), `NOME_SISTEMA`, `SLUG_HUB`.
- Scripts `build:pagar` e `build:receber` no `package.json`.
- Mexe em `Layout.tsx`, `App.tsx` e nas 9 telas listadas acima; a lógica de cada tela não muda, só o filtro fixo.

### Rollback

- Banco: apagar as 2 linhas de `systems` (cascata em `user_system_access`), dropar trigger/função,
  `visivel_no_hub = true` em `financeiro`.
- Sites: republicar o build atual (sem modo) em `adm-bancaria-lucenera`.

### Critérios de aceite

- Em Contas a Pagar não aparece nenhum CR (duplicata, NF, conta em aberto) nem as telas de boleto/remessa/retorno; em
  Contas a Receber, nenhum CP nem Pagamentos antecipados.
- Cadastrar/baixar em um sistema nunca grava o outro tipo.
- Dar ou tirar acesso a qualquer um dos três no Acesso a Sistemas reflete nos três.
- Usuário sem `financeiro` continua barrado (RLS) nos dois sistemas.

## Realizado

### 2026-10-23

- Código (`retorno-bancario-bradesco-5392a` d92974d + 6fa3d3c): `src/lib/modo-sistema.ts`, `.env.pagar`/`.env.receber`,
  `build:pagar`/`build:receber`; seletor Pagar/Receber removido de Consultar Duplicatas, Contas em Aberto (KPIs e
  aging só do próprio tipo), Cadastrar, Baixar e Notas Fiscais (todas consultam e gravam só o tipo do modo; lançamento
  do outro tipo por link mostra aviso e não abre). Boletos/remessa/retorno só no modo receber (Boletos travado em CR);
  pagamentos antecipados só no modo pagar. SSO do Hub com o slug do card. Build sem modo = página de escolha.
- Banco: migration 239 (`001_contas_pagar_receber.sql`) APLICADA em SP após dry-run com teste do espelho (dar
  contas-pagar → ganha os 3; tirar financeiro → perde os 3). 4 usuários com os 3 acessos. `002_esconder_card_antigo.sql`
  ainda NÃO aplicada (espera o teste).
- Cloudflare: projetos `contas-pagar-lucenera` e `contas-receber-lucenera` criados pela API ligados ao GitHub
  (`pedrolalala/administra--o-bancaria`, build `vite build --mode pagar|receber`, mesmas variáveis do projeto antigo).
  Push no main publica os 3. `adm-bancaria-lucenera` agora publica a página de escolha. Bundles conferidos (SP,
  menu sem boletos no Pagar).
- Orçamento (`gestao-financeira-clone-544cb (1)` 93fdb80) e Vendas (`vendas-lucenera` e9bb328): links de NF/boletos
  apontam para Contas a Receber (SSO `contas-receber`).

## Pendências

- [ ] SPEC-225 — pessoal da administração testar Contas a Pagar e Contas a Receber; depois aplicar `20261023_239_spec225_contas_pagar_receber/002_esconder_card_antigo.sql` para tirar o card "Administração Bancária" do Hub.
- [ ] SPEC-225 — incluir contas-pagar-lucenera.pages.dev e contas-receber-lucenera.pages.dev nos redirects do Supabase Auth (SP) se algum fluxo por e-mail (link mágico/recuperação) precisar voltar direto para eles; o token da Management API no `.env` está inválido, fazer pelo painel.
