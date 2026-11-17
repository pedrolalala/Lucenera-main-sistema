---
titulo: "SPEC-319 — Histórico geral de movimentação da peça: ajustes sobre o kardex existente (D de devolução, só admin, transferência junto) — Reunião 61"
status: pendente
data_ultima_modificacao: 2026-11-17
sistemas_envolvidos:
  - Dashboard (Estoque › Movimentação do item)
  - Cadastro / Consulta de Peças (atalho para o histórico)
  - Separação Parcial (log de transferência na venda — só validar)
  - Banco (RPC relatorio_movimentacao_item)
---

# SPEC-319 — Histórico geral de movimentação da peça (Reunião 61, 16/11/2026)

Fonte: `02-Reunioes/61. Lucenera (Vinicius) - 16.11.2026_ Reunião/Reunnião.01` (a transcrição termina em 08:57, no meio de outro assunto).

## Descoberta importante (16/11, banco real)

**O histórico geral que a reunião descreve já existe**: SPEC-231 G / migration 251 (27/10). Tabela `public.estoque_kardex` (2.774 linhas desde 28/10; tipos E/S/T/I, saldo por setor, usuário, sistema, histórico textual como "Venda 0003", "Entrada NF 123 — fornecedor", "MOV 7: A → B"), gravada por gatilhos, e tela **Dashboard › Estoque › Movimentação do item** via RPC `relatorio_movimentacao_item(p_codigo, p_inicio, p_fim, p_setor)` (filtro de data e de setor, saldo do setor e saldo geral, só quantidade). Portanto **não se cria tabela nem tela nova**: esta SPEC ajusta o que existe ao que o usuário pediu.

## Checklist de Ação

- [ ] Confirmar com o usuário as decisões em aberto abaixo
- [x] **Devolução como "D"**: a RPC passa a devolver `tipo = 'D'` quando a linha do kardex tem `origem = 'devolucao'` (hoje vem `E`, 38 linhas), somando no saldo (ex.: 309 → +3 → 312). Sem mudar a tabela (o CHECK de `estoque_kardex.tipo` fica como está; o mapeamento é só na leitura)
- [x] **Só Administração**: trocar o portão da RPC, hoje `pode_acessar_algum(['dashboard-financeiro'])`, por papel Administração (`IF v_role IS DISTINCT FROM 'admin'`, AGENTS.md item 9) e esconder o item do menu para os demais
- [x] **Filtro de setor** na tela: opções Estoque Geral e Showroom (os que mexem estoque) mais "Todos" (os outros setores seguem acessíveis)
- [x] **Coluna de nota e fornecedor** separada (hoje vem dentro do texto de `historico`): expor `numero_nf` e fornecedor para entradas de NF
- [x] **Transferência no mesmo histórico**: já entra como `T` com texto "MOV n: origem → destino — motivo"; exibir também a **venda** e o **cliente** quando a movimentação for de venda (`movimentacoes_peca.projeto_item_id`)
- [x] Atalho "Ver histórico" na consulta de peças (Cadastro › Peças) abrindo `/movimentacao-item?codigo=<código>` — a reunião disse "dentro da consulta de produtos"
- [ ] Testar o log de transferência dentro da venda parcial (SPEC-251/252): aparece na venda de origem e na de destino, com visual que diferencie "pegou de" / "cedeu para"
- [x] RLS/grants da RPC: `REVOKE ALL ... FROM PUBLIC, anon` ao recriar a função
- [x] Atualizar `CHANGELOG.md`, `04-Sistemas/00 - Sumario Sistemas.md`, contexto do Dashboard

### Passos manuais do usuário

- [ ] Responder as decisões em aberto
- [ ] Aplicar a migration (se a alteração da RPC virar migration nova — sim, será `CREATE OR REPLACE FUNCTION`)
- [ ] Testar com uma peça que tenha entrada de NF, venda, devolução e transferência e conferir o saldo

## Objetivo

Quando o estoque não bate, bater peça a peça (ex.: lâmpada 22625/30 x 22625/27, "no mínimo 50% de chance de separar errado"): extrato com data e hora, quem fez, quantidade e saldo, incluindo transferências, visível só para Administração.

## O que foi falado (resumo fiel)

1. Registrar só o que mexe de fato no estoque: entrada de nota, venda e devolução. Fica dentro da consulta de produtos, sem outra rotina. Log geral: o que foi feito, quando, por quem.
2. Log de transferência na venda parcial: agora mostra de qual venda a peça saiu (ex.: venda 8523) e o que foi feito dentro dela; nas outras vendas deve aparecer também ("precisa testar") e **com visualização diferente**; o nome tem que ser dentro da venda. Pesquisa por pessoa funciona.
3. Histórico geral: código, data e hora, nota e fornecedor, tipo (E entrada de nota, S saída de venda), quantidade e saldo em **quantidade** (sem valor); setor = onde foi feito.
4. Devolução: na Connect vem como "S" negativo; aqui pode ser **D** e somar (309 → 312).
5. **Só administrador**. Filtro de **data** e de **setor** (Estoque Geral e Showroom; ou todos, para busca específica).
6. Visual mais bonito, com quem fez, quando fez, o que mudou e se saiu por transferência; **juntar o log de transferência** ao histórico geral, tudo em um lugar só.

## Decisões em aberto

1. **Aproveitar a tela "Movimentação do item" do Dashboard** (recomendado) e só acrescentar atalho na consulta de peças, ou o usuário quer a aba dentro de Cadastro › Peças?
2. **D de devolução** só no relatório (recomendado, sem mexer na tabela) — de acordo?
3. **Acesso**: só papel Administração (como foi falado) — hoje quem tem o Dashboard Financeiro já vê; esses usuários perderão o acesso. Ok?
4. **Histórico anterior a 28/10**: o kardex começa com "Saldo inicial" na implantação (decisão de 27/10). Manter assim?
5. Há algo a mais no trecho da reunião que não foi transcrito (após 08:57)?

## Regras

- Nunca mostrar valor/custo nessa tela.
- Alterar a RPC com `CREATE OR REPLACE` mantendo a assinatura (não criar overload) e testar como `anon` e como usuário não-admin, em ROLLBACK.
- Migration em `supabase/db/migrations/AAAAMMDD_NNN_spec319_...` com dry-run (sem COMMIT embutido).

## Critérios de aceite

- Peça com entrada de NF, venda, devolução e transferência: as 4 linhas aparecem em ordem, a devolução como D somando, e o saldo final = estoque atual.
- Não-admin não vê o menu e a RPC devolve 42501.
- Filtros de data e de setor funcionam; "Todos" mostra tudo.
- Transferência aparece com venda, cliente, quem e quando.

## Plano de rollback

Reaplicar a versão anterior da RPC (migration 251). Sem alteração de tabela.

## Realizado

16/11/2026: SPEC criada a partir da Reunião 61 e corrigida após conferir o banco real (o kardex já existe).

### 2026-11-17

- Decisões adotadas (recomendação da SPEC): tela do Dashboard + atalho no Cadastro; D só na leitura; só admin; histórico mantém "Saldo inicial" de 27/10.
- Migration 378 aplicada (RPC recriada: tipo D, nota, fornecedor, venda, cliente, portão admin). Testada em dry-run como admin, não-admin e anon; peça 11150 (devolução D soma), 12771 (NF 123 ILUMINAR), 12130 (transferência T).
- Dashboard a4b0662: colunas novas, setor "Estoque Geral", cores de D/T, `?codigo=` abre já buscando, menu só admin. Cadastro 040c87e: botão "Histórico da peça".

- 17/11 (pedido do usuário): botão do Cadastro sempre habilitado; sem peça selecionada mostra o histórico de **todas as peças em ordem cronológica** (migration 379, dashboard f64b45b, cadastro 1d7f4fb).

## Pendências

- [ ] Responder as 5 decisões em aberto antes de implementar.
- [ ] Obter o restante da transcrição da Reunião 61 (termina em 08:57).
- [ ] Testar a transferência nas duas vendas envolvidas (venda parcial).
