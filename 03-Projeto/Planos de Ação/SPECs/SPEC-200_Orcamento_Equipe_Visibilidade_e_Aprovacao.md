# SPEC-200 — Orçamento por equipe: visibilidade, aprovação e quem digitou

- **Data:** 14/10/2026
- **Origem:** apresentação do sistema (14/10). Com a conta de uma pessoa da equipe não foi possível aprovar, e cada
  equipe (Marina, Thairine, Thais) deve ver só os próprios orçamentos.
- **Status:** CONCLUÍDA — migration 211 aplicada em SP; Orçamentos publicado na Cloudflare.
- **Sistemas:** Orçamentos (`gestao-financeira-clone-544cb`). Banco: `orcamentos`, `modulos`, `papel_permissoes`.

## Causa

1. **Aprovação:** a equipe tem role legado `funcionario`. O botão "Aprovar Manualmente" (aba Aprovação do Cliente) e
   as RPCs `aprovar_orcamento_cliente(_manual)` só aceitavam `admin/gerente/operador`: na tela o botão aparecia
   desativado. A aba Aprovação da Equipe já funcionava (módulo `aprovacao_equipe` no Hub).
2. **Visibilidade:** a leitura de `orcamentos` (`spec196_orcamentos_select`) libera todos os orçamentos para quem tem
   o sistema. Nada filtrava por equipe, e `orcamentos` não tinha equipe própria.

## Decisões do usuário (14/10)

- A equipe aprova **Cliente** ("Aprovar Manualmente") e **Equipe**. A Aprovação Financeira não muda.
- Ficam filtrados **projetistas e assistentes** (papel `equipe_projetos`). Admin, gerente e quem tem outro papel
  (ex.: Administração/Lana) veem tudo.
- **Não pode existir orçamento sem equipe.**
- **Quem fez o orçamento** é gravado pelo login (quem digitou) e aparece na tela.

## O que foi feito

### Banco — `20261014_211_spec200_orcamento_equipe_aprovacao`
- `orcamentos.equipe_id` (FK `equipes_projetos`). Os 2 orçamentos existentes foram preenchidos (Marina).
- Trigger `trg_1_orcamento_equipe_digitador`: na criação, `digitado_por = auth.uid()`, que depois não pode ser
  trocado. Sem equipe informada, pega a do projeto, depois a do vendedor, depois a de quem digitou; se faltar, recusa
  ("Informe a equipe do orçamento.") quando há usuário logado (scripts com service role não são barrados).
- `orcamentos_equipe_restrita()`: equipe do usuário quando ele é só da Equipe de Projetos (papel `equipe_projetos` e
  nenhum outro, role ≠ admin/gerente); NULL = vê tudo.
- Política **RESTRICTIVE** `spec200_orcamentos_equipe` (SELECT): vê se não é restrito, ou se o orçamento é da equipe
  dele, ou se ele digitou. Também vale para UPDATE/DELETE.
- Módulo novo no Hub `orcamentos/aprovacao_cliente` ("Aprovação do Cliente"), com `editar` dado ao papel
  `equipe_projetos`. As RPCs `aprovar_orcamento_cliente`, `aprovar_orcamento_cliente_manual`,
  `equipe_aprovar_orcamento` e `equipe_devolver_orcamento_cliente` aceitam esse módulo (as duas primeiras) e só agem
  em orçamento da própria equipe (`orcamento_da_minha_equipe`).

### Tela (Orçamentos)
- `use-auth`: `canApproveClient` (Hub `aprovacao_cliente/editar`). Aba Aprovação do Cliente e linha da lista usam
  esse valor junto com o role.
- Formulário: campo obrigatório **Equipe** (preenchido sozinho pelo projeto/vendedor/login; a escolha manual
  prevalece) e "Digitado por" ao editar.
- Lista: abaixo da empresa, "Equipe X · Digitado por Y".

## Teste (ROLLBACK e depois real)
- Marina: vê 2 (da equipe dela), aprova manualmente. Thais: vê 0 e recebe "Orçamento não encontrado" ao tentar
  aprovar o da Marina. Lana: vê tudo. `anon`: bloqueado. `digitado_por` não muda em UPDATE.

## Não coberto
- Tabelas filhas (`orcamento_itens`, parcelas) e views de outros sistemas não filtram por equipe; o filtro é na
  tabela `orcamentos` (listas e aprovações). Quem não é da equipe (ex.: estoque) continua vendo como antes.
- "Voltar para Rascunho" continua só admin/gerente/quem aprova financeiro.

## Rollback
`rollback.sql` e depois `rollback_funcoes_originais.sql` (mesma pasta da migration); reverter o commit do Orçamentos.
