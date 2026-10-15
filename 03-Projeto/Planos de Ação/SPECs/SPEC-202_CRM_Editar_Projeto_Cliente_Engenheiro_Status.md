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

## Critérios de aceite
1. Na edição do projeto, digitar parte do nome no Cliente e no Engenheiro encontra qualquer contato do tipo.
2. Salvar com status Finalizado, Ajustes finais e afins, num projeto sem itens, salva sem erro.
3. Funciona com conta da equipe (ex.: Marina).
4. Escolher "Entrega materiais" não mexe no estoque nem cria separação.

## Checklist
- [x] A — componente de busca + ProjectDetail (build ok; tsc com os mesmos 55 erros antigos)
- [ ] B — aplicar a migration 215 em SP (PENDENTE: bloqueada pela proteção automática; precisa de autorização do usuário)
- [x] CRM publicado 37924dc (crm-lucenera.pages.dev, conferido no bundle)
- [ ] Teste pela tela com conta da equipe
