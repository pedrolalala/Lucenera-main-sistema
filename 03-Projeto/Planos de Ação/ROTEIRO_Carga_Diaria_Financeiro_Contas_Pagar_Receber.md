# ROTEIRO — Carga diária do financeiro (Contas a Pagar e Contas a Receber)

**Origem:** SPEC-245 (reunião 42 com o Filippo, 05/11/2026). **Objetivo:** todo dia o Contas a Receber e o Contas a Pagar do sistema novo têm que mostrar o mesmo que a Connect mostra naquele dia. A fonte é a planilha que a Connect exporta; o sistema novo não dá baixa por conta própria nas duplicatas da Connect.

> Quem executa: quem recebe as planilhas (Pedro/administração). Tempo: cerca de 5 a 10 minutos. Todos os comandos são rodados na **pasta raiz do projeto** (`ADAPTA-PASS-Lucenera-main`), no terminal.

---

## 0. O que é e o que NÃO é

- **É:** carregar as duas planilhas do dia, alinhar empresa, pessoa e campos de cadastro das duplicatas e conferir o resultado.
- **NÃO é:** carga de estoque, herança (Reserva/Entrega Futura) nem pedido de compra. Esses ficaram **travados** desde a operação em paralelo (SPEC-244, marco de 05/11/2026) e os scripts recusam gravar. **Só o financeiro continua sendo carregado todo dia.**
- Os scripts do financeiro **não mexem em estoque, vendas, orçamentos nem saldos**. Eles têm uma trava interna: se qualquer contagem ou soma de valores mudar além do esperado, a operação se desfaz sozinha.

## 1. Antes de começar

1. Na Connect, exporte as duas planilhas do dia:
   - **Conta a Receber** → salve como `ContaReceber_AAAA-MM-DD.xlsx`
   - **Conta a Pagar** → salve como `ContaPagar_AAAA-MM-DD.xlsx`
2. Coloque as duas em `01-Documento/01 - Planilhas/` (o nome com a data é o que faz o script achar a mais recente).
3. As planilhas precisam ser a **exportação completa** (todos os períodos, pagos, abertos e cancelados), igual à de 05/11 (Receber ≈ 5 mil linhas, Pagar ≈ 14 mil). Planilha parcial pode cancelar duplicatas que não vieram. O importador recusa planilha com muito menos linhas que o esperado.
4. Confirme que o arquivo `.env` existe na raiz (tem a conexão com o banco). Nunca copie o conteúdo dele para lugar nenhum.

## 2. A ordem (não pule nem troque)

Cada passo abaixo **primeiro em ensaio** (mostra o que faria e desfaz) e **depois gravando**. Só passe para o próximo quando o anterior terminar sem erro.

### Passo 1 — Carregar as planilhas
```
python scripts/importar_contas_pagar_receber.py --dry-run     # ensaio: nada é gravado
python scripts/importar_contas_pagar_receber.py                # grava
```
**O que faz:** cria as duplicatas novas, atualiza status/pagamento/valores das existentes e **cancela** o que saiu da exportação (nunca apaga).
**Confira no ensaio:** "Transações novas" e "a atualizar" com números parecidos com o dia anterior (dezenas, não milhares); "Linhas sem negociação (não roteadas): 0".
**Pare e avise** se aparecer "Transações ABERTAS a CANCELAR" com número alto (centenas): provavelmente a planilha veio incompleta.

### Passo 1b — Espelho da planilha no Supabase (nome da pessoa como a planilha diz)
```
python scripts/carregar_espelho_contas_connect.py            # ensaio
python scripts/carregar_espelho_contas_connect.py --aplicar  # grava
```
**O que faz:** copia as duas planilhas, linha a linha e com as 50 colunas, para a tabela `connect_contas_espelho` e atualiza o nome da pessoa (`negociacoes.nome_pessoa/razao_pessoa`) que as telas mostram. **Confere antes de gravar** que linhas, soma da parcela, soma em aberto e soma paga do espelho são IGUAIS às da planilha; se diferir, nada é gravado. **Esperado:** "confere com a planilha: IGUAL" nas duas.

### Passo 2 — Empresa de cada duplicata
```
python scripts/corrigir_empresa_negociacoes_financeiro.py            # ensaio
python scripts/corrigir_empresa_negociacoes_financeiro.py --aplicar  # grava
```
**O que faz:** alinha a empresa (ISLIGHT, FOCO, MANOELLA; "LUCE NERA" = MANOELLA) à da planilha. **Esperado em dias normais:** 0 ou poucas negociações. Ambíguas e colisões ficam de fora e aparecem no Excel.

### Passo 3 — Pessoa (cliente/fornecedor) de cada duplicata
```
python scripts/corrigir_pessoas_financeiro.py            # ensaio
python scripts/corrigir_pessoas_financeiro.py --aplicar  # grava
```
**O que faz:** liga cada duplicata ao cadastro pelo **nome** da planilha e cria **pré-cadastro** (com observação "PRÉ-CADASTRO … completar CPF/CNPJ, contato e endereço") de quem ainda não existe. **Esperado:** só as duplicatas novas do dia, e poucos pré-cadastros. Depois disso, a equipe deve **completar os pré-cadastros** (filtrar contatos pela observação que começa com "PRÉ-CADASTRO").

### Passo 4 — Campos de cadastro da duplicata
```
python scripts/corrigir_campos_financeiro_planilha.py            # ensaio
python scripts/corrigir_campos_financeiro_planilha.py --aplicar  # grava
```
**O que faz:** conta (plano de contas), número da venda, total de parcelas e forma de pagamento (a planilha muda de "Duplicata Gerada" para "Pix" quando paga). **Esperado:** dezenas de alterações (as parcelas que mudaram de forma de pagamento no dia).

### Passo 5 — Conferência final (só leitura)
```
python scripts/conferir_contas_pagar_receber.py
python scripts/auditar_financeiro_vs_planilha.py
```
**Critério de aceite do dia (SPEC-245):**
- `conferir_contas_pagar_receber.py` termina com **"as listas EM ABERTO FECHAM com a planilha, no total e por empresa (diferença zero)"**. Se disser "NÃO fecham", **o dia não está fechado**: ver a seção 4.
- `auditar_financeiro_vs_planilha.py`: **0 linhas ausentes**; **0 diferenças** em status, valor da parcela, valor pago, desconto, juros, vencimento, emissão e pagamento; linhas 100% iguais **em torno de 94% ou mais** (hoje restam as duplicatas repetidas entre empresas e as contas que não existem no plano, ver SPEC-245 D10/D11).

**Referência de 05/11/2026:** Receber em aberto 459 · R$ 2.851.487,96; Pagar em aberto 1.238 · R$ 4.082.025,35.

## 3. Onde ver o resultado

- **Contas a Receber / Contas a Pagar** (os dois sistemas da Cloudflare): **Contas em Aberto** (o que está a pagar/receber) e **Consultar Duplicatas** (abre em "Aberto"; "Todos"/"Pago" carregam as pagas). As duplicatas da Connect são **só consulta** (a baixa vem da planilha do dia).
- **Supabase:** o arquivo `.xlsx` não fica lá. **A planilha inteira (50 colunas, linha a linha) fica em `public.connect_contas_espelho`** (`tipo` = `receita`/`despesa` + `cod_itens_duplicata`). As parcelas de trabalho ficam em `public.transacoes` (uma por parcela; `tipo = 'receita'` é ContaReceber e `'despesa'` é ContaPagar; `cod_itens_duplicata` é o mesmo da planilha) e `public.negociacoes` (uma por duplicata: empresa, pessoa, venda, conta).
- **Excel de cada rodada:** `scripts/logs/conferencia_financeiro/` (conferência, auditoria e o que cada corretor mudou ou pulou).

## 4. Se algo der errado

| Sintoma | O que fazer |
|---|---|
| O importador recusa ("planilha com poucas linhas") | A exportação veio incompleta. Exporte de novo. **Não** rode o passo 1 com planilha parcial. |
| "Transações ABERTAS a CANCELAR" com número alto | Pare. Compare as linhas da planilha com a anterior; provável exportação parcial. |
| Em aberto **não fecha** no total | Rode o passo 1 de novo no ensaio e veja "Linhas sem negociação". Se persistir, avise o responsável antes de mexer em qualquer coisa. |
| Em aberto fecha no total mas **não por empresa** | Rode o passo 2 e a conferência de novo. |
| Aparece "Pessoa 123" na tela | Rode o passo 3. Se for duplicata antiga fora da planilha, é esperado (hoje 501 pagas/canceladas). |
| Um corretor aborta com "contagens ou valores mudaram" | Nada foi gravado (a trava desfez). Avise o responsável com a mensagem completa. |

**Desfazer uma rodada (só o responsável, com autorização):** cada corretor grava backup no schema `backup` com a data/hora no nome:
- empresa: `backup._bkp_negociacoes_empresa_<data_hora>`
- pessoa: `backup._bkp_negociacoes_contato_<data_hora>` e `backup._bkp_contatos_precadastro_financeiro_<data_hora>`
- campos: `backup._bkp_financeiro_campos_<data_hora>` (tabela, id, coluna, antes, depois)

Rodar um corretor de novo **não apaga** o backup da rodada anterior.

## 5. O que NÃO fazer

- **Não** rodar `importar_produtos_estoque.py --incluir-estoque`, `importar_reserva_entrega_futura_connect.py --aplicar` nem `importar_pedido_compra.py` (travados pela operação em paralelo; recusam sozinhos).
- **Não** apagar nem editar à mão linhas de `transacoes`/`negociacoes`: a próxima carga as recria ou cancela.
- **Não** dar baixa em duplicata da Connect pelo sistema novo: a planilha do dia manda e sobrescreve.
- **Não** rodar os passos 2 a 4 sem ter feito o passo 1 do dia (eles usam a planilha mais recente para decidir).

## 6. Pendências conhecidas (SPEC-245)

- **D10:** criar no plano de contas "Aluguel São Paulo", "Condomínio - São Paulo" e "Manutenção conta".
- **D11:** reprocessar caso a caso as ~804 duplicatas de Receber com o mesmo número em mais de uma empresa (com o Vinícius).
- **Pré-cadastros** de pessoas criados pelo passo 3 precisam ser completados pela equipe.
- **Nota fiscal da Connect:** a planilha não traz o status; fica para decisão (SPEC-245 D4).
- Registrar pagamento feito fora do sistema (caso do Pix da venda 8502) e confirmação nas aprovações: ver SPEC-245, fase B.
