---
titulo: "SPEC-233 — Regra própria para cada Tipo de Operação do orçamento (Outros / SAC deixam de virar venda)"
status: não iniciado
data_ultima_modificacao: 2026-10-27
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — Novo Orçamento, campo Tipo de Operação / Tipo
  - Banco (Supabase SP) — orcamentos, aprovar_orcamento_financeiro, estoque/setores
  - Vendas — emissão de NF por tipo (SPEC-154 / SPEC-231 F1)
  - Logística / Separação — o que sai fisicamente
  - Estoque / Movimentação (SPEC-206 / SPEC-224) — baixa e entrada sem venda
  - Controle de Garantia (SPEC-156) — tipo GARANTIA
  - Compras — DEV COMPRA / DEV EM GARANTIA (saída para fornecedor)
---

# SPEC-233 — Regra própria para cada Tipo de Operação do orçamento

> Origem: pergunta do usuário em 26/10/2026 ("o que cada tipo de venda faz no sistema") → levantamento mostrou que
> só Venda, Devolução e Empréstimo têm regra; todo o resto vira venda na aprovação financeira.
> **27/10/2026: a matriz foi respondida na reunião com o Vinicius — ver SPEC-234 (seção A).** A coluna "Confirmado"
> abaixo fica como histórico; vale a tabela da SPEC-234.
> Relacionadas: SPEC-071 (Devolução), SPEC-074 (Outros/SAC, só interface), SPEC-223 (Empréstimo),
> SPEC-231 F1 (NF por tipo com configuração fiscal própria), SPEC-195 (vínculo Connect).

## Checklist de Ação

- [ ] Fase 0 — Trava: `aprovar_orcamento_financeiro` recusa `outros` (exceto EMPRESTIMO, que já tem regra) e `sac`
      com mensagem clara ("Tipo X ainda não tem regra — não pode ser aprovado"). Na tela, o botão de aprovar
      financeiro fica desabilitado com o mesmo aviso.
- [ ] Fase 1 — Usuário/Vinicius preenche a matriz da seção "Matriz a confirmar" (o que cada Tipo faz).
- [ ] Fase 2 — Criar a configuração por Tipo (tabela ou lista fixa — decidir na Fase 1) com: mexe no estoque? gera
      financeiro? precisa de venda de origem? tem retorno previsto? destinatário (cliente/fornecedor/empresa)?
      tipo de NF.
- [ ] Fase 3 — Implementar cada comportamento novo na aprovação (ver "Comportamentos propostos"), um por vez.
- [ ] Fase 4 — Vendas: NF com a natureza/CFOP do Tipo (amarrar com SPEC-231 F1 / SPEC-154).
- [ ] Fase 5 — Tirar da lista os Tipos que não devem ser orçamento (ex.: INVENTARIO, ACERTO CITEL), se confirmado.

### Passos manuais do usuário

- [ ] Responder as perguntas da seção "Pendências" (com o Vinicius / contabilidade para a parte fiscal).
- [ ] Aplicar a migration da Fase 0 depois do revisor.
- [ ] Testar um orçamento de cada comportamento novo antes de liberar.

## Objetivo

Hoje o Novo Orçamento oferece 4 Tipos de Operação (Venda, Devolução, Outros, SAC) e um campo **Tipo** com ~20 opções,
mas o banco só conhece **Venda**, **Devolução** e **Outros → EMPRÉSTIMO**. Qualquer outro Tipo (bonificação,
garantia, remessa, descarte, SAC...) **é aprovado como venda**: gera número de venda, reserva estoque, abre entrega
futura/necessidade de compra, cria parcelas e boletos. Uma bonificação aprovada hoje cobraria o cliente.

Resultado esperado: cada Tipo faz o que o nome diz (mexe ou não no estoque, gera ou não financeiro, emite a nota
certa), e o que ainda não tem regra fica **bloqueado** em vez de virar venda.

## Decisões aprovadas

- Abrir a SPEC (usuário, 26/10/2026). Nenhuma regra de negócio da matriz está decidida ainda.

## Definição da SPEC

### Estado atual (conferido no código e no banco em 26/10)

- `orcamentos.natureza_operacao` ∈ `venda | devolucao | outros | sac` (CHECK, migration 097).
- `orcamentos.subgrupo` = campo **Tipo**, lista fixa no frontend (`BudgetFormPage.tsx` `SUBGRUPOS_POR_TIPO`):

| Tipo de Operação | Tipos (subgrupo) |
|---|---|
| Venda | VENDAS |
| Devolução | TROCA DEV, CASA COR ENTRADA |
| Outros | EMPRESTIMO, CASA COR SAIDA, REMESSA TRANSP, RETORNO, TRANSFERENCIA, GARANTIA, OUTRAS ENTRADAS, OUTRAS SAIDAS, ACERTO CITEL, INVENTARIO, SAIDA INDUSTRIALIZACAO, BONIFICACAO, USO E CONSUMO, DESCARTE, REMESSA CONSERTO, DEV EM GARANTIA, DEV COMPRA |
| SAC | SAC |

- `aprovar_orcamento_financeiro` (versão atual: migration 247):
  - `vinculo_connect` → bloqueia (SPEC-195).
  - `outros` + `EMPRESTIMO` → bloqueia; empréstimo segue fluxo próprio (SPEC-223).
  - `devolucao` → crédito: exige venda efetivada do mesmo projeto/empresa, devolve do setor de origem, parcela
    negativa, sem número de venda (SPEC-071/178/182).
  - **todo o resto → ramo venda.**
- O subgrupo **não é olhado** em nenhum outro lugar do banco; no frontend só EMPRESTIMO muda a tela.
- **CASA COR ENTRADA** está em Devolução, então hoje exige item de uma venda de origem — provavelmente não é o que se
  quer (peça voltando da exposição não é devolução de venda). Ver pendências.
- `notas_fiscais` só tem `tipo_operacao` (CR/CP); não existe natureza/CFOP por tipo.
- Dados no banco SP hoje: 3 orçamentos `venda/VENDAS` aprovados, 1 `devolucao/TROCA DEV` aprovado, **nenhum**
  `outros`/`sac`. A trava da Fase 0 não afeta nada existente.

### Comportamentos propostos (agrupar os Tipos em poucos comportamentos)

Proposta para discussão — **nada aqui está decidido**.

| Comportamento | Estoque | Financeiro | NF (a confirmar com contabilidade) | Situação |
|---|---|---|---|---|
| A. Venda | reserva/baixa | parcelas + boletos | venda | existe |
| B. Devolução de venda | volta ao setor de origem | crédito (parcela negativa) | devolução | existe |
| C. Empréstimo (sai e volta) | não muda; mostra "Amostra / Emprestado" | nenhum | ? | existe (SPEC-223) |
| D. Saída sem cobrança | baixa definitiva | nenhum | bonificação / remessa em garantia / nenhuma | novo |
| E. Remessa com retorno | sai para setor "fora", volta depois | nenhum | simples remessa / remessa p/ conserto / industrialização | novo |
| F. Entrada sem venda | entra no estoque | nenhum | retorno / entrada | novo |
| G. Saída para fornecedor | baixa | crédito com fornecedor? | devolução de compra | novo (Compras) |
| H. Transferência entre empresas | sai de uma empresa, entra na outra (SPEC-175) | nenhum? | transferência | novo |
| I. Ajuste de estoque | acerta saldo | nenhum | nenhuma | já existe em Movimentação — tirar do orçamento? |

### Matriz a confirmar (Tipo → comportamento)

Sugestão inicial; a coluna "Confirmado" é preenchida com o usuário/Vinicius.

| Tipo | Comportamento sugerido | Confirmado |
|---|---|---|
| VENDAS | A | sim (atual) |
| TROCA DEV | B | sim (atual) |
| CASA COR ENTRADA | F (hoje está em B) | |
| EMPRESTIMO | C | sim (SPEC-223) |
| CASA COR SAIDA | C ou E | |
| REMESSA TRANSP | E? (o que é exatamente?) | |
| RETORNO | F | |
| TRANSFERENCIA | H | |
| GARANTIA | D (liga ao Controle de Garantia?) | |
| OUTRAS ENTRADAS | F | |
| OUTRAS SAIDAS | D | |
| ACERTO CITEL | I | |
| INVENTARIO | I | |
| SAIDA INDUSTRIALIZACAO | E | |
| BONIFICACAO | D | |
| USO E CONSUMO | D (sem cliente) | |
| DESCARTE | D (sem cliente, sem NF?) | |
| REMESSA CONSERTO | E | |
| DEV EM GARANTIA | G | |
| DEV COMPRA | G | |
| SAC | ? (atendimento pós-venda: troca? peça grátis? cobrança?) | |

### Fase 0 — trava (pode ir já, independe das respostas)

- `aprovar_orcamento_financeiro`: depois do bloco do empréstimo, `IF natureza_operacao IN ('outros','sac') THEN
  RAISE EXCEPTION 'Tipo "<subgrupo>" ainda não tem regra definida (SPEC-233) — não pode ser aprovado.'`.
  Mudar só o corpo, **sem mudar a assinatura** (evitar overload — ver memória de CREATE OR REPLACE).
- Orçamentos: esconder/desabilitar "Aprovar financeiro" para esses tipos, com o mesmo texto.
- Rollback: voltar o corpo da função da migration 247.

### Análise de ecossistema

- Depende de `orcamentos`, `orcamento_itens`, `projeto_itens`, `projeto_parcelas`, `boletos`, estoque por setor/empresa.
- Afeta Orçamentos, Financeiro (Contas a Receber/Pagar), Estoque/Movimentação, Logística, Vendas (NF), Compras,
  Controle de Garantia.
- Risco de duplicar o que a Movimentação (SPEC-206/224) já faz para ajustes de estoque — por isso o comportamento I
  sugere sair do orçamento.

### Critérios de aceite

- Nenhum orçamento Outros/SAC gera parcela, boleto, reserva ou número de venda sem regra explícita.
- Cada Tipo confirmado: aprovar um orçamento de teste e conferir estoque, financeiro e (quando houver) a NF.
- Venda, Devolução e Empréstimo continuam iguais (teste de regressão nos três).

## Realizado

(nada ainda)

## Pendências

- [ ] Definir com o Vinicius o comportamento de cada Tipo da lista Outros (matriz acima) — sem isso não dá para implementar a Fase 3.
- [ ] Definir o que é o Tipo de Operação SAC na prática (troca, peça grátis, visita cobrada?) e se ele cobra o cliente.
- [ ] Confirmar se CASA COR ENTRADA deve sair de Devolução (hoje exige uma venda de origem, o que não combina com peça voltando de exposição).
- [ ] Confirmar se INVENTARIO e ACERTO CITEL devem sair do orçamento e ficar só na Movimentação de estoque.
- [ ] Confirmar com a contabilidade a natureza de operação / CFOP de cada tipo de NF (remessa em garantia, simples remessa, bonificação, conserto, industrialização, transferência, devolução de compra) — liga com SPEC-231 F1 e SPEC-154.
- [ ] Decidir se GARANTIA no orçamento passa a criar/registrar caso no Controle de Garantia (SPEC-156).
- [ ] Decidir se DEV COMPRA / DEV EM GARANTIA nascem no orçamento (destinatário fornecedor) ou em Compras.
