---
titulo: "SPEC-149 — Trocar peça reservada: inverter lógica origem/destino (pedir a partir de quem precisa)"
status: pendente
data_ultima_modificacao: 2026-09-15
sistemas_envolvidos:
  - Separação Parcial (04-Sistemas/separacao-parcial)
---

# SPEC-149 — Trocar peça reservada: inverter lógica origem/destino (pedir a partir de quem precisa)

> Preencher o frontmatter acima antes de escrever o resto. `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Origem

Reunião gravada em 2026-09-15: `02-Reunioes/23. Lucenera (Vinicius) - 15.09.2026_ Ubiqua/Reunião- sobre separação parcial troca de peça`. Vinícius testou ao vivo a ação "Trocar" (SPEC-098, publicada 2026-08-14) tentando puxar uma peça reservada do projeto de Vinícius Bortolin (26.1109) para o projeto da Mariane de Moraes Ribeiro (15150) e identificou que a lógica de origem/destino está invertida em relação ao fluxo real de uso.

## Checklist de Ação

- [x] Trocar a origem do clique: o botão "Trocar" passa a aparecer na linha do item com `q_entrega_futura > 0` (quem precisa da peça), não mais em `q_reserva > 0` (quem já tem a peça)
- [x] Inverter os papéis no modal: o item da venda atual (onde o usuário clicou "Trocar") vira **destino** (`p_destino_projeto_item_id`); o item escolhido na lista "Reservado por Cliente/Projeto" vira **origem** (`p_origem_projeto_item_id`) — RPC `trocar_reserva_projetista` e a função `aprovar_transferencia_estoque` já têm essa semântica correta no banco (origem perde reserva e ganha entrega futura; destino perde entrega futura e ganha reserva), o bug estava só no mapeamento feito pelo frontend
- [x] Trocar a validação de quantidade: antes comparava com `trocaAlvo.q_reserva` (item atual/futuro destino); agora compara com a reserva do item selecionado na lista (origem, `trocaOrigemEscolhida.qReserva`)
- [x] Mostrar no cabeçalho do modal a quantidade que falta para esta venda (`q_entrega_futura` do item atual), não a reserva do item atual — texto trocado para "Falta atender nesta venda: N"
- [x] Ajustar `max` do campo Quantidade para o limite correto (reserva de quem está cedendo a peça, `trocaOrigemEscolhida.qReserva`)
- [x] Renomear variáveis/props do componente (`trocaAlvo` → `trocaVendaAtual`, sempre destino; `trocaDestino` → `trocaOrigemEscolhida`, sempre origem) — feito em todo o componente (estado, handlers, JSX)
- [x] Revisar `getReservasOutrosProjetos`: confirmado que continua correta como fonte da lista (traz outros projetos com a mesma peça); não foi alterada, só o papel que ela representa no fluxo

### Passos manuais do usuário

- [ ] Testar ao vivo com um caso real (ex.: puxar peça reservada de um projeto para outro que está com saldo em "Entrega futura") depois do fix publicado, confirmando que o saldo final bate: origem perde reserva, destino zera (ou reduz) a entrega futura e ganha reserva
- [ ] Publicar a nova versão no Skip do sistema Separação Parcial (o build/typecheck local passou, mas nada foi publicado)
- [ ] Reproduzir o cenário exato da reunião (projeto 26.1109 → 15150) e conferir "Log de Trocas" após o teste

## Objetivo

A ação "Trocar peça reservada" (SPEC-098) foi construída com a lógica de origem/destino ao contrário do fluxo real de uso. Hoje o usuário precisa entrar na venda que **já tem** a peça reservada e, de lá, "empurrar" para outro projeto. Na prática, o vendedor/projetista sempre parte da necessidade: ele está numa venda que está com peça pendente em **Entrega futura** (não tem reserva suficiente) e precisa escolher de qual outro projeto puxar a peça já reservada. O resultado do fluxo invertido é confuso e gera troca com efeito parcial (saldo fica errado nas duas pontas), como reproduzido ao vivo na reunião.

## Decisões aprovadas

- O clique em "Trocar" parte sempre da venda que **precisa** da peça (tem `q_entrega_futura > 0`), nunca da venda que já tem a peça reservada — confirmado por Vinícius: *"eu vou na venda que eu preciso atender e aí lá eu vou selecionar, eu seleciono de quem eu quero pegar (...) Ao contrário. Eu acho que fica mais fácil."*
- Não há mudança de banco/schema — `trocar_reserva_projetista`, `aprovar_transferencia_estoque` e `pode_trocar_reserva` (migration `20260814_110_spec098_troca_reserva_projetista`) já implementam a semântica correta (origem cede reserva e recebe entrega futura; destino recebe reserva e abate entrega futura). O bug é só de mapeamento no frontend.

## Definição da SPEC

### Estado atual (bug)

Arquivo: `04-Sistemas/separacao-parcial/src/pages/SeparacaoParcialPage.tsx`

1. Botão "Trocar" só aparece quando `item.q_reserva > 0` (linha ~924) — ou seja, só em quem **já tem** a peça, ao contrário do que deveria (quem precisa).
2. `handleAbrirTroca(item)` (linha ~619) guarda o item clicado em `trocaAlvo` e busca outros projetos com a mesma peça via `getReservasOutrosProjetos`, que populam a lista de seleção (`trocaDestino`).
3. `handleConfirmarTroca` (linha ~647) chama:
   ```ts
   trocarReserva({
     origemProjetoItemId: trocaAlvo.projeto_item_id,       // item clicado (deveria ser destino)
     destinoProjetoItemId: trocaDestino.projetoItemId,     // item escolhido na lista (deveria ser origem)
     quantidade,
   })
   ```
   Isso está invertido: o item clicado (venda que precisa) está sendo tratado como quem cede a peça.
4. Validação de quantidade (linha ~654) compara com `trocaAlvo.q_reserva` — errado pelo mesmo motivo.
5. Modal mostra "Reserva disponível para troca: {trocaAlvo.q_reserva}" (linha ~1166) — não existe nenhuma indicação de quanto falta (`q_entrega_futura`) na venda atual, que era exatamente a informação que faltava no teste ao vivo: *"eu tô cego, eu não sei quanto que eu tenho para transferir (...) não tem a informação quanto eu tenho que transferir para ele."*

Backend (`supabase/db/migrations/20260814_110_spec098_troca_reserva_projetista/001_troca_reserva_projetista.sql`), já correto e sem necessidade de alteração:

- `aprovar_transferencia_estoque`: origem `q_reserva -= quantidade` e `q_entrega_futura += quantidade`; destino `q_entrega_futura -= LEAST(quantidade, q_entrega_futura)` e `q_reserva += quantidade`.

### Mudança proposta (frontend apenas)

| Papel | Antes | Depois |
|---|---|---|
| Item clicado (venda atual, "Trocar") | origem (cede peça) | **destino** (recebe peça, tem `q_entrega_futura > 0`) |
| Item escolhido na lista "Reservado por Cliente/Projeto" | destino (recebe peça) | **origem** (cede peça, tem `q_reserva > 0`) |
| Gatilho do botão "Trocar" na linha | `q_reserva > 0` | `q_entrega_futura > 0` |
| Validação de quantidade máxima | `trocaAlvo.q_reserva` (item atual) | reserva do item escolhido na lista (quem cede) |
| Texto de contexto no modal | "Reserva disponível para troca" (item atual) | "Falta atender nesta venda" (`q_entrega_futura` do item atual) |

Nenhuma mudança de RPC, tabela, coluna ou policy — só reorganização dos parâmetros já existentes e da condição de exibição do botão.

## Impacto no banco

Nenhum. RPCs e migration existentes já têm a semântica correta.

## Impacto em telas, relatórios ou automações

- Tela de Separação Parcial (`SeparacaoParcialPage.tsx`): botão "Trocar" por linha, modal de troca, texto de contexto.
- Log de Trocas (mesma tela, seção "Log de Trocas") não muda — já lê `origem_projeto_item_id`/`destino_projeto_item_id` direto de `transferencias_estoque`, que vai passar a receber os IDs no papel correto.

## Regras de permissão

Sem mudança — continua restrito a quem `pode_trocar_reserva()` retorna `true` (Projetista/gerente/admin), regra decidida no banco.

## Critérios de aceite

- Ao abrir uma venda com item em "Entrega futura" (`q_entrega_futura > 0`), o botão "Trocar" aparece nessa linha.
- Ao clicar em "Trocar", a lista mostra outros projetos com a mesma peça e sua reserva disponível; ao escolher um, o modal mostra quanto será puxado dali para a venda atual.
- Quantidade máxima permitida = reserva do projeto escolhido (origem), não da venda atual.
- Após confirmar: projeto escolhido (origem) perde `q_reserva` e ganha `q_entrega_futura` na mesma quantidade; venda atual (destino) ganha `q_reserva` e reduz `q_entrega_futura` até zerar (ou até o limite transferido).
- Log de Trocas mostra corretamente quem cedeu (origem) e quem recebeu (destino).

## Testes/verificações obrigatórias

- Reproduzir o cenário exato da reunião: puxar peça do projeto 26.1109 (Vinícius Bortolin) para o projeto 15150 (Mariane de Moraes Ribeiro), conferindo saldo final nas duas pontas (reserva/entrega futura) antes e depois.
- Conferir que o botão "Trocar" não aparece mais em item que só tem `q_reserva` (sem `q_entrega_futura` pendente).
- Conferir Log de Trocas após o teste (origem/destino corretos).

## Realizado

**2026-09-15** — Implementado por agente `implementador`, escopo restrito a `04-Sistemas/separacao-parcial/src/pages/SeparacaoParcialPage.tsx` (único arquivo alterado; não tocado nenhum arquivo do trabalho não relacionado já sujo no submódulo — `src/App.tsx`, `src/lib/cross-system-auth.ts`, `src/components/SystemSwitcher.tsx`, `src/hooks/useSistemasPermitidos.ts`).

Mudanças:
- Botão "Trocar" na linha da tabela agora exige `item.q_entrega_futura > 0` (antes `item.q_reserva > 0`).
- Estado renomeado: `trocaAlvo` → `trocaVendaAtual` (item clicado, sempre **destino**); `trocaDestino` → `trocaOrigemEscolhida` (item escolhido na lista "Reservado por Cliente/Projeto", sempre **origem**).
- `handleConfirmarTroca` agora chama `trocarReserva({ origemProjetoItemId: trocaOrigemEscolhida.projetoItemId, destinoProjetoItemId: trocaVendaAtual.projeto_item_id, ... })` — antes estava invertido.
- Validação de quantidade máxima agora compara com `trocaOrigemEscolhida.qReserva` (reserva de quem cede), não mais com a reserva do item clicado.
- Cabeçalho do modal trocado de "Reserva disponível para troca" (`trocaAlvo.q_reserva`) para "Falta atender nesta venda" (`trocaVendaAtual.q_entrega_futura`).
- `max` do campo Quantidade ajustado para `trocaOrigemEscolhida.qReserva`.
- `getReservasOutrosProjetos` não foi alterada (segue correta como fonte da lista); só mudou o papel do resultado no fluxo (de "destino" para "origem").
- Nenhuma mudança de banco/RPC/schema, conforme já confirmado na SPEC.

Verificação:
- `npx tsc --noEmit` — sem erros.
- `npx oxlint src/pages/SeparacaoParcialPage.tsx` — 1 warning pré-existente e não relacionado (`numeroVenda` declarado e não usado, linha 237, já existia antes desta mudança).
- Build (`vite build`) não executado nesta rodada; typecheck + lint específico do arquivo alterado passaram limpos.
- Nenhum commit feito — fica a cargo do usuário revisar e commitar separadamente do resto do submódulo (que já tem mudanças não relacionadas pendentes).

Pendente (usuário): testar ao vivo o golden path (puxar peça reservada de um projeto — ex. 26.1109 — para outro com saldo em "Entrega futura" — ex. 15150), conferir saldo final nas duas pontas e o "Log de Trocas", publicar no Skip, e rodar o agente `revisor` antes de qualquer commit.

## Pendências

- [ ] Confirmar com Vinícius, durante o teste ao vivo pós-fix, se a quantidade sugerida no campo deve vir pré-preenchida com o valor de `q_entrega_futura` da venda atual (não foi decidido na reunião, só que essa informação precisa aparecer).
