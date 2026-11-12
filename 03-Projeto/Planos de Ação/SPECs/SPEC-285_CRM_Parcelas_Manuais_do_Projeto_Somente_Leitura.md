---
titulo: "SPEC-285 — CRM: parcelas do projeto só nascem do orçamento aprovado (editor manual vira somente leitura)"
status: pendente
data_ultima_modificacao: 2026-11-12
sistemas_envolvidos:
  - Banco (Supabase SP) — projeto_parcelas
  - CRM (lucenera-crm) — página de detalhe do projeto
---

# SPEC-285 — CRM: parcelas do projeto só nascem do orçamento aprovado

## Checklist de Ação

- [x] Diagnóstico com o código do CRM e o banco (12/11)
- [x] Migration `20261112_339_spec285_bloquear_parcela_manual` (up, rollback, dry_run)
- [x] Ensaio em ROLLBACK no Supabase SP
- [ ] Aplicar a migration (com autorização)
- [x] CRM: alteração pronta em `SPEC-285_patch_crm_ProjectDetail.diff` (nesta pasta)
- [ ] CRM: aplicar o patch e publicar (Pedro; a conta do Filippo só tem leitura no repositório do CRM)
- [ ] Publicar o CRM e conferir a página do projeto

### Passos manuais do usuário

- [ ] Autorizar a aplicação da migration 339
- [ ] Pedro: mudança no CRM e publicação

## Objetivo

A página de detalhe do projeto no CRM tem um **editor manual de parcelas a receber** (`ProjectDetail.tsx`, que chama `saveProjetoParcelas` em `services/projetos.ts`). Ele cria, altera e apaga parcelas **sem orçamento** em `projeto_parcelas`.

Problema: a parcela manual vai só para o modelo financeiro antigo (`trg_projeto_parcela_financeiro` → `transacoes`). A ponte para o financeiro novo (`financeiro_ponte_transacao`) aceita só parcelas com `orcamento_id`. Então uma parcela manual:
- não aparece em Contas a Receber nem no Fluxo Futuro do Dashboard;
- não gera RT do arquiteto quando é paga.

O caminho certo para o dinheiro de uma venda é o **orçamento aprovado**: ele gera a parcela (com `orcamento_id`), o título a receber e o boleto, tudo ligado.

Uso medido em 12/11:

| | Parcelas | Valor | Quando |
|---|---|---|---|
| Sem orçamento (manuais) | 387 | R$ 8,1 mi | todas em 04/05/2026 (carga antiga), nenhuma em `transacoes` |
| Com orçamento | 22 | R$ 50,5 mil | 10 e 11/11 |

Nenhum uso do editor nos últimos 30 dias (auditoria). Só o CRM grava parcela sem orçamento. No banco, só `aprovar_orcamento_financeiro` insere em `projeto_parcelas`, e sempre com orçamento.

## Decisões aprovadas

- Filippo (12/11): preparar a correção para tirar ou travar o editor.
- Regra: parcela de venda **só nasce do orçamento aprovado**.
- As 387 parcelas antigas (04/05) ficam como estão, para consulta: **não se apaga nada**. Também deixam de poder ser alteradas pelas telas; correção pontual, se necessária, só pelo administrador no banco.

## Definição da SPEC

### Banco — migration 339

- Novo gatilho `trg_bloquear_parcela_manual` (`BEFORE INSERT OR UPDATE OR DELETE` em `projeto_parcelas`). Recusa, com mensagem clara, qualquer criação, alteração ou exclusão de parcela **sem orçamento** feita pelas telas (`authenticated`). Mensagem: "Parcelas de venda nascem do orçamento aprovado (SPEC-285). Para registrar uma venda, use o Orçamentos."
- Não afeta:
  - parcelas com orçamento (aprovação, desfazer aprovação, devolução);
  - `service_role` e o administrador no banco (para correção pontual).
- O gatilho antigo `trg_proteger_parcelas` (que só aceitava em "Ajustes finais"/"Finalizado") continua; o novo é mais restrito.
- Rollback: remove o gatilho e a função novos.

### CRM — mudança na tela (Pedro)

- `src/pages/ProjectDetail.tsx`, card "Parcelas do Projeto": no modo edição, mostrar a mesma tabela **somente leitura** do modo visualização. Tirar os campos editáveis, o botão de adicionar e o de remover. Acrescentar a frase: "As parcelas vêm do orçamento aprovado (Orçamentos)."
- Na gravação do projeto, não chamar mais `saveProjetoParcelas`. Pode remover a função de `services/projetos.ts` ou deixá-la sem uso.
- Sem a mudança na tela, a trava do banco já impede a gravação: o usuário vê a mensagem de erro ao salvar parcelas.

### Critérios de aceite

- Inserir, alterar ou excluir parcela sem orçamento como usuário logado: recusado com a mensagem.
- Aprovar um orçamento e desfazer a aprovação continuam funcionando (parcelas com orçamento).
- As 387 parcelas antigas continuam visíveis no CRM.

## Realizado

### 2026-11-12

- Diagnóstico e migration 339 escritos.
- **Ensaio no Supabase SP**, desfeito no fim. Simulando usuário logado:
  - inserir parcela sem orçamento: **recusado**, com a mensagem;
  - alterar uma das 387 antigas: **recusado**;
  - alterar parcela com orçamento: **permitido**;
  - `service_role` alterar parcela antiga: **permitido**.
- Conferido depois: nenhum gatilho, função ou parcela de teste ficou no banco. **Não aplicada.**
- Conferido também quem mais mexe em `projeto_parcelas`: `criar_transacao_da_parcela_projeto`, `cancelar_orcamento`, `desfazer_aprovacao_financeira` e `processar_retorno_bancario`. Todas trabalham com parcelas de orçamento; 0 boletos e 0 retornos ligados a parcela manual.
- Patch do CRM (`ProjectDetail.tsx`):
  - tira o import e a chamada de `saveProjetoParcelas` e as validações de parcela;
  - mostra sempre a tabela somente leitura, com a frase "As parcelas vêm do orçamento aprovado (Orçamentos) e não são editadas aqui";
  - +10 / −44 linhas.
  - Não compilado aqui (sem Node no ambiente): conferir o build ao aplicar.
