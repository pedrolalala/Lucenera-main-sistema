---
titulo: "SPEC-234 — Reunião 27/10: regra de cada Tipo de Operação, NF de remessa/venda parcial pela separação, setores visuais e acesso do Matheus"
status: não iniciado
data_ultima_modificacao: 2026-10-27
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — Tipo de Operação / Tipo (subgrupo), aprovação
  - Banco (Supabase SP) — aprovar_orcamento_financeiro, estoque_itens, produtos, setores
  - Separação Parcial — NF de remessa para transporte e NF de venda parcial a partir da separação
  - Vendas — várias NF de venda por venda, abatimento do sinal (SPEC-231 F1/F4, SPEC-154)
  - Logística — acesso do Matheus/Vitória à Separação Parcial
  - Movimentação de Peças (SPEC-224) — setores Empréstimo, Estoque Garantia, Casa Cor
  - Compras — devolução de compra amarrada à chave da NF de compra
  - Cadastro / Consulta de peças — disponível somando Showroom
---

# SPEC-234 — Reunião 27/10: Tipos de Operação, NF de remessa, setores e acessos

> Origem: reunião "39. Lucenera (Vinicius) - 27.10.2026_ andamento do sistema / Reunião.01".
> Esta SPEC **responde a matriz da SPEC-233** (o que cada Tipo faz) e registra os pedidos novos da mesma reunião.
> A implementação da regra por Tipo continua seguindo as fases da SPEC-233; aqui ficam as decisões.
> Relacionadas: SPEC-223 (Empréstimo), SPEC-224 (Movimentação de Peças/setores), SPEC-231 F1–F5 (NF no Vendas,
> sinal no boleto), SPEC-231 G (kardex, migration 251), SPEC-156 (Controle de Garantia), SPEC-154 (Focus NFe).

## Checklist de Ação

- [ ] A — Tipos de Operação: aplicar a matriz decidida (seção A) na aprovação do orçamento, um comportamento por vez (fases 2–4 da SPEC-233).
- [ ] A1 — Limpar a lista de Tipos: tirar RETORNO, TRANSFERENCIA, OUTRAS ENTRADAS, ACERTO CITEL e INVENTARIO de "Outros".
- [ ] A2 — Mover REMESSA CONSERTO, DEV EM GARANTIA e DEV COMPRA de "Outros" para "SAC".
- [ ] A3 — DEV COMPRA: vincular à NF de compra (chave de acesso) e gerar saída de estoque + contrapartida no Contas a Pagar.
- [ ] B — NF de remessa para transporte / simples remessa a partir de uma separação (Separação Parcial), só dos itens separados.
- [ ] C — Venda com NF parcial: permitir mais de uma NF de venda por venda, cada uma só com os itens enviados, abatendo o sinal.
- [ ] D — Setores visuais Empréstimo, Estoque Garantia e Casa Cor; saída deles sem "gap" de reserva.
- [ ] E — Matheus e Vitória com acesso à Separação Parcial (consultar a venda inteira, tirar/corrigir lista de entrega, emitir NF de remessa).
- [ ] F — Disponível = Estoque geral + Showroom − reservado, sem o "reservado negativo" herdado da Connect.
- [ ] G — Inventário vira sistema próprio (balanço) — abrir SPEC separada.

### Passos manuais do usuário

- [ ] Confirmar com o contador CFOP/natureza de cada NF nova: remessa para transporte, simples remessa, remessa para demonstração (Casa Cor saída) e retorno de demonstração, saída para industrialização, bonificação, remessa para conserto, devolução em garantia, devolução de compra.
- [ ] Responder as pendências abaixo (principalmente Casa Cor e a NF de entrada de importação).
- [ ] Aplicar as migrations de cada fase depois do revisor e testar um orçamento por Tipo.

## Objetivo

Cada Tipo de Operação do orçamento passa a fazer o que o nome diz: mexer ou não no estoque, gerar ou não financeiro
e emitir a NF certa. A logística passa a emitir a NF que acompanha a mercadoria (remessa ou venda parcial) a partir da
separação, sem o "orçamento fake" que o Matheus faz hoje na Connect.

## Decisões aprovadas (reunião 27/10/2026, Vinicius)

### A. O que cada Tipo faz

| Tipo de Operação / Tipo | Estoque | Financeiro | NF | Observação |
|---|---|---|---|---|
| Venda / VENDAS | regra atual (S na aprovação) | gera | venda | já definido |
| Devolução / TROCA DEV | regra atual | crédito | devolução | já definido |
| Outros / EMPRESTIMO | **não sai**; peça vai para o setor **Empréstimo** e continua contando como disponível | não | — | ao virar venda (editado ou aprovado integralmente) segue a regra de venda. Ver D. |
| Outros / CASA COR SAIDA | sai do estoque (geral ou showroom) | não | **remessa para demonstração** | o retorno é CASA COR ENTRADA (retorno de demonstração); peça vendida lá: retorno + NF de venda |
| Outros / REMESSA TRANSP | não mexe | não | remessa para transporte | na prática nasce da separação (ver B), não de orçamento |
| Outros / RETORNO | — | — | — | **tirar** (não se usa mais) |
| Outros / TRANSFERENCIA | — | — | — | **tirar** |
| Outros / GARANTIA | **sai do estoque geral** (pode negativar) | não | — | peça nova entregue ao cliente; a garantia é tratada depois com o fornecedor. Se faltar, abre necessidade/compra antecipada |
| Outros / OUTRAS ENTRADAS | — | — | — | **tirar** (orçamento é saída) |
| Outros / OUTRAS SAIDAS | sai | não | — | |
| Outros / ACERTO CITEL | — | — | — | **tirar** |
| Outros / INVENTARIO | — | — | — | **tirar**; vira sistema próprio de inventário (G) |
| Outros / SAIDA INDUSTRIALIZACAO | não mexe | não | **saída para industrialização** (permitir emitir) | fechamento mensal da pintura terceirizada. A NF de retorno da industrialização **não** entra no estoque nem no sistema; financeiro lançado à mão |
| Outros / BONIFICACAO | sai | não | bonificação (eventualmente) | |
| Outros / USO E CONSUMO | sai | não | — | fica registrado no histórico da peça (kardex) |
| Outros / DESCARTE | sai | não | — | peça quebrada na separação, acrílico danificado etc. |
| SAC / REMESSA CONSERTO | não mexe | não | remessa para conserto | cliente já foi atendido; manda ao fornecedor (ex.: Interlight) num protocolo com várias peças |
| SAC / DEV EM GARANTIA | não mexe | não | devolução em garantia | mesmo princípio da remessa para conserto, classificação fiscal diferente (ex.: Stella, que reembolsa) |
| SAC / DEV COMPRA | **sai** | **contrapartida no Contas a Pagar** (abate/liquida parcela; pode ser parcial) | devolução de compra, com a **chave de acesso da NF de compra** | fornecedor mandou peça errada. Ver A3 |

- A1: RETORNO, TRANSFERENCIA, OUTRAS ENTRADAS, ACERTO CITEL e INVENTARIO saem da lista.
- A2: REMESSA CONSERTO, DEV EM GARANTIA e DEV COMPRA saem de "Outros" e vão para "SAC". Ao abrir SAC aparecem essas opções.
- A3: em DEV COMPRA, abrir campo para amarrar a NF de compra (chave de acesso), que a Focus exige na NF de devolução.

### B. NF de remessa para transporte a partir da separação

- Caso comum: venda com **NF de venda cheia já emitida**, material sai em partes para fora da cidade. A NF de venda
  cheia não pode acompanhar a mercadoria parcial. Da separação (lista de entrega) o sistema emite **NF de remessa para
  transporte / simples remessa** só com os itens daquela entrega. Uma por entrega.
- Não mexe em estoque nem financeiro (a tributação já foi na NF de venda).
- Fica na **Separação Parcial**: entra no número da separação, seleciona e emite.
- O Matheus pode emitir **só** remessa / simples remessa. NF de venda só administração (Vinicius, Carol, Débora, Lana).

### C. Venda com NF de venda parcial (caso Clara Resort)

- Venda fechada sem NF emitida, cliente paga sinal (ex.: 30% de R$ 90 mil) e o resto conforme envio (28 dias).
- Sem NF de venda não existe simples remessa: a cada envio emite-se uma **NF de venda só dos itens enviados**, que já
  acompanha a mercadoria.
- Em cada NF parcial abate-se a parte do sinal (30% do valor da nota), e o restante vira boleto de 28 dias.
- A venda pode ter **várias NF de venda** enquanto houver item sem nota. Se a venda já tem NF de venda cheia, **não**
  pode emitir outra NF de venda (só remessa, item B).
- Venda enviada inteira sem NF: emite pela rotina normal de venda no Vendas.
- Liga com SPEC-231 F4 (regra do sinal no boleto).

### D. Setores visuais (Empréstimo, Estoque Garantia, Casa Cor)

- **Empréstimo:** a peça emprestada muda para o setor Empréstimo para se saber que está fora, mas continua disponível.
- **Estoque Garantia:** peças que voltaram **consertadas** do fornecedor. Não podem ser vendidas como novas. Peça que
  o fornecedor troca por nova entra no estoque geral normal.
- **Estoque Casa Cor:** peças que voltaram da exposição com sinais de uso, para negociar de forma diferente.
- Garantia e Casa Cor são meramente visuais e **não** contam como disponível.
- Para dar saída de um desses setores, move-se a peça para o estoque geral e faz a saída. **Sem gap**: a movimentação
  de setor e a saída (garantia ou venda) acontecem juntas, para uma venda normal não reservar a peça usada nesse meio
  tempo.

### E. Acesso do Matheus (e da Vitória)

- Matheus é o líder da logística e **precisa** da Separação Parcial. Ali ele consulta a venda inteira do cliente
  (transferir reserva ↔ entrega futura, conferir o que falta) e tira/corrige lista de entrega sozinho (brinde, presente,
  algo já entregue). A Logística sozinha não basta: ela mostra só o que mandaram ele entregar.
- Dar o mesmo acesso para a Vitória.

### F. Disponível soma o Showroom

- Disponível = estoque geral + showroom − reservado (exemplos da reunião: 13442 "44 geral + 2/3 showroom", 13454
  "40 + 5", 12956 "disponível 0 com 1 no showroom": tem que somar).

### G. Inventário

- Inventário sai do orçamento e vira um sistema próprio de balanço de peças. SPEC separada.

## Definição da SPEC

### Achado no banco: como o Showroom entra no disponível hoje (27/10)

- O import da Connect grava `estoque_itens.quantidade_reservada = estoque_total − Disponivel`. Como o "Disponivel" da
  Connect já soma o Showroom, a reserva fica **negativa**, com valor igual ao Showroom.
- **290** linhas do setor Estoque têm reservado negativo, e em **286** ele é igual a `−produtos.estoque_showroom`
  (soma −405). Exemplos: 13442 quantidade 45, reservado −2, disponível 46, showroom 1; 13454 = 40 / −3 / 43, showroom
  3; 12956 = 0 / −1 / 1, showroom 1.
- Ou seja, para as peças importadas o Showroom já entra no disponível, mas por um "reservado negativo". Peça que entrou
  no Showroom depois (pela Movimentação de Peças) não entra. Por isso as telas divergem.
- **Afeta o kardex (migration 251, ainda não aplicada):** o saldo do Estoque é `quantidade − quantidade_reservada`, o
  que contaria o Showroom duas vezes (no Estoque e no setor Showroom). **Corrigir a 251 antes de aplicar**:
  reservado negativo tratado como 0 no saldo do Estoque, ou corrigir os dados primeiro (F1).

### F1 — proposta (a confirmar)

- Migration de dados: zerar o reservado negativo das 286 linhas, onde ele é exatamente −showroom. As 4 que não batem
  vão para conferência manual.
- Disponível passa a ser calculado sempre como `quantidade − reservado + estoque_showroom`, num só lugar (view/função),
  e as telas (Cadastro de peças, Orçamentos, Consulta) leem dali.
- Import da Connect (`scripts/importar_produtos_estoque.py`) deixa de derivar reservado do Disponivel.

### Análise de ecossistema

- Banco: `aprovar_orcamento_financeiro` (sem mudar assinatura), `estoque_itens`, `produtos`, setores da Movimentação,
  `notas_fiscais`, `contas_pagar`/parcelas (DEV COMPRA), `estoque_kardex` (SPEC-231 G).
- Edge `emitir-nota-fiscal`: novas naturezas (remessa, simples remessa, demonstração, industrialização, bonificação,
  conserto, devolução em garantia, devolução de compra com chave referenciada) e NF de venda parcial por itens.
- Sistemas: Orçamentos, Separação Parcial, Logística, Vendas, Movimentação de Peças, Compras, Cadastro.
- Acesso: Separação Parcial para Matheus e Vitória (Central → Acesso a Sistemas).

### Critérios de aceite

- Um orçamento de cada Tipo confirmado: estoque, financeiro e NF conforme a tabela A. Venda, Devolução e Empréstimo
  continuam iguais.
- Os Tipos retirados não aparecem mais no Novo Orçamento.
- Da separação de uma venda com NF cheia, emitir NF de remessa só com os itens separados. O Matheus não vê o botão de NF
  de venda.
- Venda sem NF: duas NF de venda parciais sobre itens diferentes, com o sinal abatido proporcionalmente. A terceira
  tentativa sobre item já faturado é bloqueada.
- Saída de peça do Estoque Garantia ou Casa Cor numa só operação, sem a peça ficar disponível no meio.
- 13442, 13454 e 12956 mostram o mesmo disponível em todas as telas, somando o Showroom.

## Realizado

- 27/10/2026: SPEC criada a partir da reunião. Conferidos no banco os dados de estoque das peças citadas (seção
  "Achado no banco").

## Pendências

- [ ] Começo da reunião (00:00): NF de **entrada de importação** (nacionalização da mercadoria importada, com impostos
      pagos). Hoje quem faz é o Sérgio no sistema dele. Definir se o sistema vai fazer e como.
- [ ] CASA COR SAIDA: confirmar se é o mesmo fluxo do Empréstimo (setor visual) ou saída de estoque com remessa para
      demonstração (a reunião disse "sai do estoque"). E se CASA COR ENTRADA sai de "Devolução" (hoje exige venda de origem).
- [ ] GARANTIA: escolher de qual setor sai (geral, Estoque Garantia ou Casa Cor) ou adotar a regra "move para o geral e
      sai junto" (D).
- [ ] Sinal na NF parcial (C): abater 30% de cada nota ou outra regra. Fecha junto com SPEC-231 F4.
- [ ] F1: confirmar que pode zerar o reservado negativo e o disponível único, e corrigir a migration 251 antes de aplicar.
- [ ] CFOP/natureza de cada NF nova com o contador.
- [ ] SPEC do sistema de Inventário (G).
