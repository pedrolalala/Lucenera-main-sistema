---
titulo: "SPEC-143 — \"Dar Baixa\": ação separada de \"Separar\" na tela de Separação"
status: "REVERTIDO (2026-09-14) — usuário esclareceu que \"Dar Baixa\" = Registro de Entrega, já existente em lucenera-logistica; não deve ser duplicado aqui"
data_ultima_modificacao: 2026-09-14
sistemas_envolvidos:
  - Separação (separacao-parcial) — `SeparacaoParcialPage.tsx`, `separacaoParcialService.ts`
dependencias:
  - SPEC-138 (Prompt 7 do documento Light Design — origem do conceito de "área de baixa", antes implementado como sinônimo de "Separar")
---

# SPEC-143 — "Dar Baixa": ação separada de "Separar" (REVERTIDO)

> **REVERTIDO em 2026-09-14, poucas mensagens depois de publicado.** O usuário esclareceu: "o Dar baixa é o Registro de entrega que está em lucenera-logistica! não precisa desse dar baixa aqui Só a opção de separar!!" — ou seja, o "Dar Baixa" descrito abaixo (2ª correção do dia) já existe como a tela "Registrar Entrega" (`RegistrarEntregaPage.tsx`) do sistema Logística, e não deveria ter sido reconstruído aqui. A tela de Separação Parcial volta a ter só a ação "Separar"; "Parciais desta venda" é de novo um histórico simples (Parcial/Funcionário/Data/Status/Estornar), sem card de baixa. Ver seção "Reversão" no fim deste documento.
>
> Origem original (mantida como histórico): instrução do usuário (2026-09-14), com referência visual detalhada de uma tela do Connect legado: "Parcial: 4646 / Funcionário: MOARA / Data Parcial: 23/04/2026" (quem pediu) — uma divisória — "Código: 4227 / Data Baixa: 27/04/2026 13:29:19 / Funcionário: ALEXANDRE GUILHERME / Responsável Retirou: LENILDO" (quem fez a entrega). Revoga a assunção da SPEC-138 (Prompt 7) de que "dar baixa" era sinônimo de "Separar" — confirmado com o usuário que são duas ações distintas, tipicamente feitas por pessoas diferentes.

## Checklist de Ação

- [x] Investigar se já existia algo equivalente no ecossistema antes de criar do zero.
- [x] **Achado**: a Logística (`lucenera-logistics-b7cd1`) já tem uma tela "Registrar Entrega" (`RegistrarEntregaPage.tsx`) que escreve em `entregas_finalizadas` (`recebido_por` = Responsável Retirou; `data_entrega_real` = timestamp com hora) — estrutura parecida, mas **sem** captura de "Funcionário" (quem registrou a baixa) e **sem** código sequencial. Achado adicional, mais sério: o `handleSubmit` daquela página chama `finalizarEntrega({ separacao, recebidoPor, fotos, observacoes, dataEntrega })`, mas o hook `useFinalizarEntrega` espera `{ separacao_id, cliente, codigo_obra, endereco, recebido_por, ... }` — **os nomes de campo não batem**, o que sugere um bug pré-existente nesse fluxo (não confirmado com teste ao vivo, não corrigido — fora do escopo desta SPEC, reportado como achado).
- [x] Decisão: **não reaproveitar** o fluxo da Logística (por causa do achado acima) — construir "Dar Baixa" de forma independente, inteiramente dentro do sistema de Separação.
- [x] Nova tabela `separacao_baixas` — 1 baixa por parcial (`separacao_id` com índice UNIQUE), `codigo bigserial` (sequência própria, sequencial e global), `funcionario_id` (sempre quem está logado ao confirmar a baixa), `responsavel_retirou` (texto livre), `data_baixa` (timestamptz, captura data **e hora** automaticamente).
- [x] RLS espelhando o padrão já usado em `separacoes` (SPEC-069): `hub_pode_executar(..., 'separacao-parcial', NULL, 'criar'/'deletar')`, com fallback pra `'logistica'` (mesma permissão que já cria/deleta separações também pode dar baixa).
- [x] Migration testada com dry-run (`BEGIN; ...; ROLLBACK;`) antes de aplicar de verdade.
- [x] Frontend: nova função `registrarBaixaSeparacao()`; `listarParciaisPorVenda()` passou a trazer a baixa (se existir) via embed.
- [x] UI: cada linha de "Parciais desta venda" virou um card com **divisória visual** — registro da parcial (Parcial/Funcionário/Data Parcial) acima, área de baixa abaixo. Se não há baixa ainda, mostra um botão "Dar Baixa" (abre diálogo pedindo só "Responsável Retirou" — funcionário e data são automáticos). Se a parcial está cancelada, não mostra nem o botão.
- [x] Aplicada em produção (migration rodada com sucesso, sem bloqueio do classificador desta vez — é `CREATE TABLE`, não `ALTER FUNCTION` em objeto compartilhado).
- [x] Publicado em produção: `https://separacao-parcial-dff01.goskip.app` (Skip `48801` v0.0.34, QA 100% verde).
- [ ] Teste ao vivo: dar baixa numa parcial real, conferir que Código/Data/Funcionário/Responsável Retirou aparecem certos.

## Achado fora do escopo — bug na Logística

`04-Sistemas/lucenera-logistics-b7cd1/src/pages/RegistrarEntregaPage.tsx` (`handleSubmit`, chamada a `finalizarEntrega`) manda um objeto com chaves `{separacao, recebidoPor, fotos, observacoes, dataEntrega}`, mas `04-Sistemas/lucenera-logistics-b7cd1/src/hooks/useFinalizarEntrega.ts` declara `FinalizarData` como `{separacao_id, cliente, codigo_obra, endereco, recebido_por, observacoes?, gestora_equipe?, numero_entrega?}` — nomes de campo incompatíveis, os campos obrigatórios (`cliente`, `codigo_obra`, `endereco`) nunca são passados. Esse sistema não tinha um `tsc` local configurado pra confirmar se isso é de fato um erro de tipo silencioso ou runtime — **não investigado a fundo, não corrigido**, é um achado colateral desta SPEC. Recomendação: abrir uma SPEC própria pra investigar/corrigir se esse fluxo de "Registrar Entrega" da Logística estiver de fato quebrado em produção.

## Critérios de aceite (da versão revertida — não mais aplicáveis)

- [ ] Uma parcial sem baixa mostra o botão "Dar Baixa"; ao confirmar, aparece a tabela com Código/Data Baixa (com hora)/Funcionário/Responsável Retirou.
- [ ] Parcial cancelada não mostra nem o botão nem a tabela de baixa.
- [ ] O Funcionário da baixa é sempre quem confirmou a ação (pode ser diferente do Funcionário da parcial).
- [ ] `pnpm run lint`/`vite build` passam.

## Reversão (2026-09-14)

- [x] `SeparacaoParcialPage.tsx`: removido o card com divisória (Parcial acima / área de baixa abaixo), o botão "Dar Baixa", o Dialog de confirmação e os estados/handlers associados (`baixaAlvo`, `baixaResponsavelRetirou`, `registrandoBaixa`, `handleAbrirBaixa`, `handleFecharBaixa`, `handleConfirmarBaixa`). "Parciais desta venda" voltou a ser uma tabela simples: Parcial/Funcionário/Data/Status/Estornar.
- [x] `separacaoParcialService.ts`: removida a interface `BaixaParcial`, `ParcialHistorico` voltou à forma anterior (`id/criadoEm/responsavelNome/status/itens`), `listarParciaisPorVenda()` voltou à query simples sem embed de baixa, `registrarBaixaSeparacao()` removida por completo.
- [x] QA no Skip (projeto 48801) 100% verde — v0.0.37, publicado em produção (`https://separacao-parcial-dff01.goskip.app`, ref `37a3b0b`).
- [x] Commitado no submodule `separacao-parcial` (`cfbea2a`).
- [ ] **Pendente, não destrutivo**: a tabela `separacao_baixas` (migration 20260914_143) continua existindo no Supabase, agora inerte (sem nenhum código lendo/escrevendo nela). Não foi dropada — é uma ação destrutiva que requer confirmação explícita do usuário antes de executar.
- Nota: o achado de bug em `RegistrarEntregaPage.tsx`/`useFinalizarEntrega.ts` (nomes de campo incompatíveis entre o que a página envia e o que o hook espera) documentado abaixo **fica mais relevante agora** — é o fluxo real de "Dar Baixa"/registro de entrega que o usuário quer usar. Recomenda-se abrir uma SPEC própria para investigar e corrigir, já que pode estar quebrado em produção.
