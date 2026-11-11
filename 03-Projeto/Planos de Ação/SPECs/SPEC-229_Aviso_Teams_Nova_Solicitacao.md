---
titulo: "SPEC-229 — Aviso no Teams quando entra solicitação nova na Central"
status: concluído
data_ultima_modificacao: 2026-10-27
sistemas_envolvidos:
  - Central de Solicitações
  - Supabase (coluna solicitacoes.avisado_teams_em, Edge Function classificar_solicitacao)
  - Teams (fluxo "Workflows" com webhook, criado pelo usuário)
---

# SPEC-229 — Aviso no Teams quando entra solicitação nova na Central

## Checklist de Ação

- [x] Migration 245: coluna `solicitacoes.avisado_teams_em` (rascunho em `supabase/db/migrations/20261026_245_spec229_aviso_teams_solicitacoes/`)
- [x] Edge Function `classificar_solicitacao`: depois de classificar, manda o cartão no Teams (uma vez por pedido)
- [x] Aplicar migration 245 no Supabase SP
- [x] Gravar secret `TEAMS_WEBHOOK_SOLICITACOES` e publicar a função
- [x] Teste: criar pedido de teste → cartão chega no Teams → editar o pedido → **não** chega outro → apagar o pedido de teste

### Passos manuais do usuário

- [x] No Teams: Apps → **Workflows** → modelo **"Enviar alertas de webhook para um chat"** (*Send webhook alerts to a chat*) → escolher o chat consigo mesmo (ou com o Flow bot) → copiar a URL gerada e passar para a IA (é segredo: não colar em documento).

## Objetivo

O usuário não abre a Central de Solicitações todo dia e pedido novo fica parado sem ninguém ver. Quando alguém cria uma solicitação, chega na hora uma mensagem no Teams do usuário com quem pediu, o título, o sistema, a classificação da IA e o botão "Abrir na Central".

## Decisões aprovadas

- Canal: **Teams** (usuário, 26/10/2026). E-mail, contador no Hub e resumo diário ficaram de fora.
- Quem recebe: **só o usuário** (26/10/2026).
- Avisa só pedido **novo**. Editar pedido não avisa de novo.

## Definição da SPEC

### Como funciona

1. A tela cria o pedido e chama `classificar_solicitacao` (já era assim, SPEC-121).
2. A função classifica com a IA e, logo depois, faz `UPDATE solicitacoes SET avisado_teams_em = now() WHERE id = … AND avisado_teams_em IS NULL AND criado_em >= now() - 1 hora`. Só se essa linha mudar ela manda o cartão. Assim:
   - editar o pedido (SPEC-225 chama a mesma função) não reenvia;
   - pedido antigo nunca vai pro Teams (não precisa preencher as linhas velhas);
   - duas chamadas juntas mandam um aviso só.
3. O cartão (Adaptive Card) vai por POST para a URL do fluxo do Teams (secret `TEAMS_WEBHOOK_SOLICITACOES`). Sem o secret, a função não faz nada de diferente.
4. Falha no Teams só gera log; nunca trava o pedido nem a classificação.

### Cartão

Título "Nova solicitação na Central", título do pedido, Quem pediu, Tipo (Bug / Pedido de alteração), Sistema, IA (Estrutural / Pontual, se a IA respondeu), os primeiros 300 caracteres da descrição e o botão "Abrir na Central" (`https://solicitacoes-lucenera.pages.dev`).

### Banco

- `solicitacoes.avisado_teams_em timestamptz` (nulo = ainda não avisado). Só a função grava (service role). Sem mudança de RLS.
- Rollback: `rollback.sql` apaga a coluna. Para desligar o aviso sem rollback, basta apagar o secret.

### Limitações

- Se a pessoa fechar a tela no instante em que cria o pedido, a função pode não ser chamada e o aviso não sai (mesma limitação da classificação da IA hoje).
- O fluxo do Teams roda na conta do usuário; se ele for desligado ou a conta mudar, os avisos param sem erro na tela.

## Realizado

### 2026-10-26

- Rascunho da migration 245 e da mudança na Edge Function `classificar_solicitacao`.
- Usuário criou o fluxo "Enviar alertas de webhook para um chat" no Power Automate (make.powerautomate.com — o app Workflows não aparecia no Teams). Teste direto na URL: 202.
- Migration 245 aplicada no SP; secret `TEAMS_WEBHOOK_SOLICITACOES` gravado; função publicada (antes, conferido que a versão no ar era igual à do repositório).
- Teste: pedido "TESTE aviso Teams (SPEC-229)" → classificado, `avisado_teams_em` gravado; 2ª chamada (simula edição) não reenviou. Pedido apagado.

### 2026-10-27

- O cartão não chegava: as execuções do fluxo falhavam com "Invalid ThreadId" — o modelo deixou a ação "Postar cartão" em **Chat em grupo** sem chat escolhido. Corrigido no ramo usado (Falso → For each): **Postar em = Conversar com o bot do Flow**, destinatário pedro@lucenera.com.br, cartão = `items('For_each')?['content']`. URL do gatilho não mudou. Novo teste: execução com **Êxito**.

## Pendências

- [x] SPEC-229: usuário confirmou (27/10) que o cartão de teste chegou no chat do "Workflows"/bot do Flow no Teams.
- [ ] SPEC-229: o ramo "Verdadeiro" do fluxo (corpo sem attachments, nunca usado pelo sistema) ainda está em "Chat em grupo" vazio — só importa se alguém mandar outro formato para a URL.
