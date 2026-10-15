# SPEC-202 — CRM: editar projeto (cliente, engenheiro e salvar com qualquer status)

- **Data:** 2026-10-15
- **Status:** em andamento
- **Origem:** relato do usuário em 15/10 (CRM › Projetos › Editar Projeto), na mesma linha da apresentação de 14/10 (SPEC-200/201).
- **Sistema:** CRM (`04-Sistemas/lucenera-crm-3bd29 (1)`), banco SP.

## Problemas

| # | Sintoma | Causa |
|---|---|---|
| 1 | O campo Engenheiro não lista ninguém e não deixa digitar | O Select usava `useProjectStore().contacts`, que é `contatos ... order(nome).limit(5000)`. O PostgREST corta em 1000 linhas (3.870 contatos), então os 6 engenheiros ficavam de fora |
| 2 | O campo Cliente só mostra parte dos clientes e não deixa digitar | Mesma causa: só os ~1000 primeiros nomes em ordem alfabética |
| 3 | Salvar dá "Erro ao atualizar — Não é possível fechar o projeto sem nenhum item cadastrado" (também com a equipe) | O trigger `trg_proteger_fechamento` barra a troca de status para Projeto executivo, Entrega materiais, Ajustes finais ou Finalizado quando o projeto não tem itens ou tem item não validado |

## Decisão do usuário

O status do projeto (junto com responsável, perfil e nível estratégico) é **informativo**. Salvar a edição precisa funcionar sempre, para o admin e para a equipe de projetos.

## Solução

**A. Tela (CRM)**
- Novo `src/components/ContactSearchCombobox.tsx`: busca no banco conforme a pessoa digita (`contatos` por `tipo`, `ilike`, 50 resultados), no mesmo padrão do `ArchitectSplitPicker`. Também tem a opção "Nenhum".
- `ProjectDetail.tsx`: Cliente e Engenheiro Responsável passam a usar esse componente. A dependência de `useProjectStore().contacts` foi removida.

**B. Banco** — migration `20261015_215_spec202_status_projeto_informativo`
- `DISABLE TRIGGER trg_proteger_fechamento`: tira o bloqueio de salvar.
- `DISABLE TRIGGER trg_fechar_projeto`: em "Entrega materiais", esse trigger baixava estoque, movia reservas para entregue e criava uma separação automaticamente. Esse fluxo é legado; hoje separação e venda saem do orçamento aprovado. Com o status só informativo, escolher esse status não pode mexer no estoque.
- Nenhum projeto está hoje nesses 4 status. As funções continuam no banco e o `rollback.sql` religa os triggers.

**Permissão da equipe:** já existia. As RLS `spec069_projetos_update` (Hub crm/editar), `replace_projeto_arquitetos` e `spec196_parcelas_*` liberam a equipe (Marina, Thais e outros com crm/editar = true). O bloqueio era só o trigger.

## C. Eletricista no projeto (pedido 15/10)
- Migration `20261015_216_spec202_projeto_eletricista` (APLICADA): `projetos.eletricista_id uuid` → `contatos(id)` ON DELETE SET NULL, com índice.
- CRM: campo "Eletricista" com busca em Editar Projeto e em Novo Projeto. No Novo Projeto, o eletricista é gravado com um update depois do `salvar-projeto`, para não precisar republicar a Edge Function. `getProjeto` traz `eletricista:eletricista_id(nome)`.
- Hoje não existe nenhum contato do tipo eletricista; cadastre pelo CRM ou pelo Orçamento (migration 214).

## D. Achado — Engenheiro não salvava (RESOLVIDO 15/10)
`projetos.responsavel_obra_id` tem FK para `usuarios`, mas as telas (CRM e Orçamentos) oferecem contatos do tipo engenheiro, e escolher um dá erro de FK. Nenhum projeto tem o campo preenchido. A sincronização com o SharePoint (`sharepoint-projetos-pull`/`-push` e os scripts `sincronizar_planilha_projetos.py`/`backfill_sharepoint_projetos.py`) mapeia a coluna "Responsável Obra" para `usuarios`. O usuário recebeu `violates foreign key constraint "projetos_responsavel_obra_id_fkey"` ao salvar. A correção não mexe na sincronização com o SharePoint, porque as Edge Functions não podiam ser republicadas (token da CLI inválido):
- Migration `20261015_217_spec202_projeto_engenheiro_contato` (APLICADA): nova `projetos.engenheiro_id` → `contatos`.
- CRM (Editar e Novo Projeto, `getProjeto`/lista) e Orçamentos (`ProjectCreateModal`) gravam e leem o engenheiro em `engenheiro_id`. `responsavel_obra_id` fica só para a sincronização com o SharePoint (usuarios).
- Teste como Marina, desfeito no fim: salvou engenheiro SCALA ENGENHARIA com status Finalizado.
- Pendente opcional: levar `engenheiro_id` para a coluna "Responsável da Obra" do SharePoint. Exige republicar `sharepoint-projetos-push/pull`.

## E. Responsável = equipe (pedido 15/10)
O campo Responsável listava funcionários e gravava o nome completo em `responsavel_nome` (ex.: "Thairine Cristina da Silva"). O trigger `fn_sync_equipe_por_responsavel` só casa pelo nome da equipe, então o projeto ficava sem `equipe_id` e a visibilidade por equipe (SPEC-200) falhava.
- CRM (Editar e Novo Projeto) e Orçamentos (Criar Projeto) listam `equipes_projetos`: Administração, Estoque, Marina, Thais e Thairine.
- Ao escolher uma equipe, grava `equipe_id`, `responsavel_nome` = nome da equipe (o mesmo valor que o SharePoint já usa) e `responsavel_funcionario_id` = líder da equipe (preenche o Vendedor no Orçamento).
- "Novo Funcionário" saiu desse campo.
- Teste como Marina, desfeito no fim: 26.319 com a equipe Thairine resolveu `equipe_id` = Thairine e líder = Thairine Cristina da Silva.
- Dado antigo: o 26.319 está gravado com "Thairine Cristina da Silva" e sem equipe. Ao editar e escolher a equipe, corrige.

## Critérios de aceite
1. Na edição do projeto, digitar parte do nome no Cliente e no Engenheiro encontra qualquer contato do tipo.
2. Salvar com status Finalizado, Ajustes finais e afins, num projeto sem itens, salva sem erro.
3. Funciona com conta da equipe (ex.: Marina).
4. Escolher "Entrega materiais" não mexe no estoque nem cria separação.

## Checklist
- [x] A — componente de busca + ProjectDetail (build ok; tsc com os mesmos 55 erros antigos)
- [x] B — migration 215 aplicada em SP 15/10 (autorizada pelo usuário); teste como Marina: status Finalizado sem itens salvou (rollback)
- [x] CRM publicado 37924dc (crm-lucenera.pages.dev, conferido no bundle)
- [x] C — eletricista (migration 216 aplicada + CRM)
- [x] D — engenheiro em engenheiro_id (migration 217)
- [x] E — Responsável = equipe (CRM + Orçamentos)
- [ ] Teste pela tela com conta da equipe
