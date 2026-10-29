---
titulo: "SPEC-239 — CPF/CNPJ dos clientes a partir das notas fiscais da Connect"
status: migration pronta (dry-run ok), aplicação pendente
data_ultima_modificacao: 2026-10-29
sistemas_envolvidos:
  - Banco (Supabase SP) — contatos (cpf, cnpj, tipo_pessoa, inscricao_estadual), notas_fiscais_connect
---

# SPEC-239 — CPF/CNPJ dos clientes a partir das notas fiscais da Connect

> Origem: pendência do usuário de 28/10 ("preencher CPF/CNPJ dos clientes a partir de `staging_conta_receber`") e
> resposta de 29/10 "vamos fazer o que for necessário!". Motivo: a nota de venda (SPEC-231 F) precisa do documento do
> destinatário, e só 71 dos 2.641 clientes tinham.

## Checklist de Ação

- [x] Levantar as fontes de CPF/CNPJ.
- [x] Migration 259 com backup e dry-run.
- [ ] Aplicar a 259 em produção (precisa da frase do usuário).
- [ ] Decidir o que fazer com os clientes que dividem documento (lista abaixo).

## Estado encontrado (29/10)

- `staging_conta_receber.cpf_cnpj` está **vazio em todas as 4.357 linhas**, e a planilha
  `ContaReceber_2026-10-14.xlsx` não tem a coluna. A fonte prevista não serve.
- `notas_fiscais_connect` (599 notas importadas dos XML) tem o documento do destinatário em 596. Só 19 notas têm
  `cliente_id`. O casamento é pelo nome do destinatário contra o nome ou a razão social do cliente.
- O documento fica em três colunas: `cpf` (59 clientes), `cnpj` (7) e `cpf_cnpj` (5). As telas leem
  `cpf_cnpj || cnpj || cpf`.
- Unicidade: `cpf_cnpj` é UNIQUE; `cpf` e `cnpj` são únicos entre os contatos sem `canonical_id`, **de qualquer tipo**.
  Na Connect, cada obra é um cliente ("25.139 CLARA RESORTS…") e várias obras faturam no mesmo CPF/CNPJ, o que esse
  modelo não aceita.

## Definição

- **Migration 259** `20261029_259_spec239_cliente_cpf_cnpj_notas_connect`. Preenche **177 clientes** (133 CPF, 44 CNPJ),
  sob estas condições:
  - o cliente não tem nenhum documento;
  - as notas mostram um único documento para ele;
  - nenhum outro contato usa esse documento;
  - os dígitos verificadores conferem.
- Grava `cpf` ou `cnpj` no formato com pontuação que o cadastro já usa. `tipo_pessoa` só onde está vazio. A IE da nota
  entra só para CNPJ e só onde a IE está vazia (25). `cpf_cnpj` não é alterado.
- Backup em `backup._bkp_259_contatos_documento`; o rollback devolve as colunas a partir dele.
- Dry-run em 29/10: 177 no backup; clientes com documento passam de 71 para 248; nenhum ficou sem documento; nada
  persistiu.

## Ficam de fora (decisão do usuário)

- **55 clientes que dividem 25 documentos.** São obras do mesmo pagador (ex.: Debora Caramuru, Apto Riviera e Gabriel e
  Maria Ivone com o CNPJ da Caramuru Construções). Para gravar seria preciso:
  - ou marcar as obras como duplicata (`canonical_id`), o que muda como aparecem nas listas;
  - ou tirar a exigência de documento único.
- **11 clientes cujo documento já está num fornecedor ou arquiteto** (Lumini, Lemca, OEG Design, Studio 3, Bruno
  Castanhari…).
- **9 clientes do grupo Clara**, com mais de um documento nas notas.
- A lista dos 66 primeiros está em
  `C:\Users\pedro\AppData\Local\Temp\claude\C--script-python-ADAPTA-PASS-Lucenera-main\a14f1cd7-d7de-4f97-b572-7faefda83e30\scratchpad\clientes_doc_compartilhado.csv`.
- Os outros ~2.150 clientes não aparecem em nenhuma nota de 2026. Para eles é preciso uma exportação do cadastro de
  clientes da Connect com CPF/CNPJ.
