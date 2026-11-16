---
titulo: "SPEC-309 — Editar (Contas a Pagar/Receber) abre o formulário completo também para contas do financeiro novo"
status: 16/11 — migration 369 e telas implementadas; ver Realizado
data_ultima_modificacao: 2026-11-16
sistemas_envolvidos:
  - Contas a Pagar / Contas a Receber (04-Sistemas/retorno-bancario-bradesco-5392a) — Consultar Duplicatas e Cadastrar Duplicatas (modo edição)
  - Banco (financeiro_titulos, financeiro_parcelas, auditoria; migration 369)
---

# SPEC-309

## Checklist de Ação
- [x] Migration `20261116_369_spec309_editar_conta_completa`: `financeiro_conta_para_edicao(parcela)` e `financeiro_editar_conta(titulo, dados, parcelas, motivo)`.
- [x] Cadastrar Duplicatas ganha o modo `?parcela=<id>` (carrega a conta do financeiro, edita e salva pela função nova, com justificativa).
- [x] Consultar Duplicatas: o Editar abre esse formulário no lugar da janelinha da SPEC-297.
- [ ] Teste da Caroline/Débora com uma conta da Connect (Pagar e Receber).

## Problema
Em 14/11 o deploy do Retorno Bancário levou junto a SPEC-297: o Editar de conta sem grupo de conta (as ~10 mil contas da Connect e as do financeiro novo) passou a abrir uma janelinha com só vencimento, valor e descrição. O esperado (relato do usuário e da Caroline, 16/11): o Editar abre o **formulário completo**, igual ao Cadastrar Duplicatas, com todas as informações. A correção `21d1095` só cobria contas com `conta_grupo_id` (lançadas pelo Cadastrar, que vivem em `boletos`).

## Decisão
O Cadastrar Duplicatas passa a editar também uma conta do financeiro novo, identificada pela parcela (`?parcela=<uuid>`). A janelinha da SPEC-297 deixa de ser usada pelo Editar (o arquivo fica, sem uso).

## Regras
- Editável: origem `legado_connect` ou `manual`, conta não cancelada. Outras origens (NF, pedido, venda): mensagem dizendo onde alterar (regra herdada da SPEC-297).
- Campos do título editáveis: empresa, perfil, responsável, pessoa (contato), grupo/sub grupo/apropriação (plano de contas), NF/documento e referência (descrição).
- Parcelas abertas e sem baixa: vencimento, valor, emissão, descrição e observação editáveis. Parcela paga/baixada fica intacta (só leitura).
- Não troca o sinal do valor; valor e vencimento seguem as travas da SPEC-297 (venda/devolução do sistema, boleto já registrado/pago).
- Nesta versão **não** adiciona nem remove parcelas, e não troca a situação (cancelar/estornar continuam nos botões próprios).
- Justificativa obrigatória; uma linha em `auditoria` (`editou_conta`) com antes/depois do título e de cada parcela.

## Banco
Só funções (nenhuma tabela/coluna): `SECURITY DEFINER`, `search_path public`, `REVOKE … FROM PUBLIC, anon`, `GRANT EXECUTE … TO authenticated`, `financeiro_exige(especie)` como trava de papel.

## Rollback
`rollback.sql` da migration 369 remove as duas funções. Código: reverter o commit do Retorno Bancário.

## Realizado
Ensaio em ROLLBACK com o usuário da Caroline na conta 5504: leitura, edição (documento e vencimento) e bloqueio sem justificativa funcionaram; view refletiu o novo vencimento.

## Pendências
- [ ] Teste real da Caroline.
- [ ] Adicionar/remover parcelas e trocar situação pelo formulário (decisão do usuário).
