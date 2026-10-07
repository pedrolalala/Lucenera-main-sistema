---
titulo: "SPEC-165 — Memória Lucenera: importação de reuniões de projeto com decisões vinculadas e fila de revisão"
status: concluído
data_ultima_modificacao: 2026-09-29
sistemas_envolvidos:
  - Memória Lucenera (Skip 57204)
  - Supabase (schema memoria + Edge Function interpretar-reuniao)
---

# SPEC-165 — Reuniões de projeto: importação, decisões e fila de revisão

## Checklist de Ação

- [x] Migration `20260929_165_memoria_reunioes_revisao`: `kb_decisoes`, `kb_sugestoes`, guardas de aprovação e de solução excepcional, RLS.
- [x] Edge Function `interpretar-reuniao` (Gemini): lê o texto (ou .docx) e devolve uma **proposta** — não grava nada.
- [x] Tela "Importar reunião" (colar texto ou enviar .txt/.docx; também a partir dos Pendentes antigos).
- [x] Template da reunião: campo "Andamento do projeto"; decisões estruturadas (uma por linha, com marca de solução excepcional); código do projeto obrigatório quando houver decisão.
- [x] Fila "Revisão": curador aprova (abre o template do tema de destino pré-preenchido, editável) ou rejeita (com motivo).
- [x] Página "Histórico do projeto" (`/projeto/:codigo`): reuniões em ordem + todas as decisões do projeto.
- [x] Teste ponta a ponta (importar, decisões, sugestão, aprovar, rejeitar, excepcional bloqueado).
- [x] Publicar.

### Passos manuais do usuário

- [ ] Se quiser que outros papéis (além de admin/admin_geral) aprovem sugestões: conceder `aprovar` no sistema `memoria` pela Central.

## Objetivo

Reunião de projeto é **histórico**: resumo, andamento, próximos passos e decisões vinculadas ao projeto. Conhecimento reaproveitável que aparecer na reunião vira **sugestão** numa fila separada; só entra num tema de referência depois que uma pessoa aprova. Solução excepcional para um projeto nunca vira padrão.

## Decisões

- Requisitos do usuário (2026-09-29): aprovação humana obrigatória, fila separada da reunião, solução excepcional permanece só como histórico.
- **Quem aprova: curador** (`hub_pode_executar(uid,'memoria',NULL,'aprovar')`, hoje admin e admin_geral) — escolha de implementação alinhada à SPEC-164, ajustável pela Central.
- IA: Gemini (decisão da SPEC-129), chamada só no servidor (Edge Function); a chave nunca vai ao navegador.

## Definição

### Banco

- `kb_decisoes`: `reuniao_id` (FK `kb_itens`, cascade), `project_code` NOT NULL, `decisao`, `contexto`, `excepcional`, `ordem`. Visível para quem vê a reunião; editável por quem edita a reunião.
- `kb_sugestoes`: `reuniao_id`, `tipo_destino` (qualquer tipo exceto reunião), `titulo`, `campos`, `tags`, `justificativa`, `trecho_origem`, `status` (pendente/aprovada/rejeitada), `item_criado_id`, revisor e data, motivo.
  - Criar: quem pode editar a reunião, sempre `pendente`.
  - Mudar status: só curador, só a partir de `pendente`; `aprovada` exige `item_criado_id` de um item existente do mesmo tipo de destino (trigger).
- Nenhum item entra num tema por conta da IA: a aprovação cria o item pelo caminho normal (autor = revisor, origem manual).

### Solução excepcional

- A IA marca decisões que atendem só aquele projeto como `excepcional` e não gera sugestão a partir delas (filtro também no servidor).
- A pessoa que importa pode marcar/desmarcar "solução excepcional" em cada decisão antes de salvar.
- Na revisão, a sugestão mostra de qual trecho veio; o curador pode rejeitar como "solução excepcional".

## Realizado

### 2026-09-29

- Migration `20260929_165_memoria_reunioes_revisao` testada em dry-run (18 regras: decisão sem projeto, sugestão já aprovada, aprovação sem item/por não curador/com item de outro tipo, sugestão de decisão excepcional, reverter revisão, alterar conteúdo — todas bloqueadas) e aplicada.
- Edge Function `interpretar-reuniao` implantada. Gemini instável no dia (503 "high demand" em quase todos os flash; `gemini-2.5-flash` aposentado = 404): lista de modelos com reserva (`gemini-3.6-flash` → `3.8-flash` → `3.5-flash-lite` → `flash-lite-latest`), 45 s por tentativa, 2 rodadas.
- Testada com as recapitulações reais (Neoside 23.249: 2 decisões, 1 excepcional, sem sugestão; Luiz 26.255: 3 decisões, sem sugestão) e com texto de teste (regra IP67 → sugestão de Regra de material; trilho só nesta obra → excepcional, sem sugestão).
- Frontend publicado (`2b5bb48`). Teste ponta a ponta no navegador (preview, cliques e digitação): importar → proposta com decisões e sugestão → marcar excepcional bloqueia a sugestão → salvar → histórico do projeto → aprovar (item criado pelo curador em Regras de materiais) → rejeitar com motivo → não-curadora só acompanha. Dados de teste removidos (base segue com 54 itens).
- Achado e corrigido no teste: contador "Revisão" do cabeçalho não atualizava ao rejeitar.

### 2026-09-29 (ajuste pedido pelo usuário)

- A reunião importada passa a ir **direto para o histórico do projeto**, sem o passo de conferência: ao terminar a interpretação, grava a reunião (publicada), as decisões vinculadas ao projeto, o arquivo original e envia as sugestões para a Revisão (`src/lib/reuniao.ts`). Só as sugestões dependem de aprovação.
- Exceção: se não houver código de projeto (nem no texto nem informado), abre o formulário pedindo o código — sem ele não há histórico onde registrar.
- Correções continuam possíveis editando a reunião depois (autor ou curador).
- Publicado `7cfe5ec`; testado no navegador (importar → cai direto na reunião registrada → histórico do projeto → sugestão pendente na Revisão, nenhum item criado em tema). Dados de teste removidos.

### 2026-09-29 (segundo ajuste pedido pelo usuário)

- Importação centralizada dentro de "Reunião de projeto" (importar no topo, preenchimento manual abaixo); o card separado "Importar reunião" saiu e `/importar-reuniao` redireciona.
- Depois de interpretar, a reunião continua indo direto para o histórico, e a pessoa cai na **edição** (`/item/:id/editar?importada=1`) para corrigir resumo, andamento, decisões e próximos passos, e **corrigir ou descartar as sugestões** antes da Revisão. Resumo da reunião movido para o topo do formulário.
- Migration `002_sugestao_editavel_enquanto_pendente.sql` (aplicada): quem pode editar a reunião corrige o conteúdo de sugestão **pendente**; status continua só com curador; revisada fica imutável. Testado em dry-run (10 regras).
- Publicado `44088bd`; teste no navegador (preview): importar → edição → corrigir resumo e sugestão → sugestão segue pendente e ligada à decisão → descartar tira da fila → decisões preservadas.
- Observação: a reunião "Fachada Iluminada – Edifício Aurora" (26.181, importada pelo usuário em produção) foi preservada.

## Pendências

- [ ] Tempo de interpretação depende da carga do Gemini (10 s a ~70 s observados; até 2 min no pior caso com reserva).
