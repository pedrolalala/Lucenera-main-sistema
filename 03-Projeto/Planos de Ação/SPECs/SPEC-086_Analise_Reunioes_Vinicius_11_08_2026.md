---
titulo: "SPEC-086 — Análise das reuniões com Vinícius de 11/08/2026 (o que já foi alterado x o que segue em aberto)"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - CRM
  - Orçamentos
  - Compras / Necessidade de Compra
  - Separação Parcial
  - Logística
---

# SPEC-086 — Análise das reuniões com Vinícius de 11/08/2026

> Esta SPEC é um **relatório de investigação**, não uma feature nova. Ela cruza
> o que foi falado nas 3 gravações da reunião de 11/08/2026 com Vinícius
> (`02-Reunioes/17. Lucenera (vinicius) - 11.08.2026_ estruturas falhas do
> sistema/`) contra o estado real do código publicado (Skip) hoje. Não decide
> prioridade nem implementa nada — só separa "já resolvido" de "ainda em
> aberto", com evidência de código para cada item.

---

## Checklist de Ação

Não há implementação nesta SPEC — o "checklist" é o que foi investigado.

- [x] Ler as 3 gravações da reunião 17 (`Reunião.01`, `Reunião.02.txt`, `Reunião.03`)
- [x] Cruzar cada ponto levantado com as SPECs já publicadas nesta sessão (077 a 085) e com o código ao vivo no Skip
- [x] Ler `src/pages/SeparacaoParcialPage.tsx` + `src/services/separacaoParcialService.ts` (projeto Skip 48801) para confirmar o que a tela de Separação Parcial já faz e o que não faz
- [x] Ler `src/pages/EntradaNotaFiscal.tsx` (projeto Skip 40326) para confirmar se já existe entrada de NF sem pedido de compra vinculado
- [x] Ler `BudgetFormPage.tsx` (Orçamentos) para confirmar o estado do campo "Validade"

### Passos manuais do usuário

- [ ] Decidir quais itens da seção "Não alterado" viram SPEC de implementação, e em que ordem
- [ ] Confirmar com o Vinícius os 2 itens da seção "Levantado mas sem decisão fechada" antes de qualquer um deles virar SPEC (a reunião registrou a dúvida, não uma decisão)

---

## Objetivo

A reunião de 11/08 com o Vinícius (3 gravações, contexto: CRM/Orçamentos na
primeira metade, Compras/Separação Parcial/Logística na segunda) foi um teste
ao vivo do sistema, ponto a ponto, com vários bugs e pedidos de ajuste
levantados na hora. Boa parte já virou SPEC nos dois dias seguintes (12 e
13/08) sem que a reunião em si tivesse sido documentada formalmente. Esta SPEC
fecha esse registro: lista cada ponto levantado, diz se já foi resolvido (com
qual SPEC) ou se continua em aberto (com evidência do código atual).

---

## Definição da SPEC

### 1. Já alterado (confirmado no código publicado)

| # | O que foi pedido/relatado na reunião | Onde | Resolvido por |
|---|---|---|---|
| 1 | CNPJ/CEP devem preencher nome, endereço e inscrição estadual automaticamente no cadastro de cliente | Reunião.02 [00:46]-[01:25], Reunião.03 [02:09] | **SPEC-075** (CEP/CNPJ autofill) |
| 2 | Perfil "Ribeirão/São Paulo" deve aparecer em todos os lugares com essa população | Reunião.02 [02:11], Reunião.03 [02:51][25:12] | **SPEC-064** (Perfil Ribeirão/São Paulo) |
| 3 | Selecionar 1 produto e replicá-lo em vários L's de uma vez, sem "jogar pra baixo" numa sequência sem controle — abrir uma seleção de quantos L's antes de cair no orçamento | Reunião.03 [36:13]-[49:35] | **SPEC-079** (múltiplos L's por peça) + **SPEC-080** (múltiplos L's dentro do Buscar Produtos) |
| 4 | "Não me puxou" o projeto ao criar; campo Responsável vem vazio mesmo tendo responsável; cliente some da busca | Reunião.03 [19:44]-[26:08] | **SPEC-081** (fix cliente/vendedor autopreenchimento — causa raiz era o cap de 1000 linhas do PostgREST) |
| 5 | Campo "vendedor" devia reaproveitar o campo antigo de "pessoas do trabalho" / linkar de verdade; permitir mais de 1 arquiteto no projeto | Reunião.03 [29:52]-[30:47] | **SPEC-077** (Arquitetos múltiplos + Responsável = Funcionário) |
| 6 | "Isso aqui tem que bloquear. Por exemplo, quantos tem? Não pode deixar fazer oito" — travar quantidade separada acima do disponível | Reunião.02 [05:05]-[05:34] | Já implementado — `SeparacaoParcialPage.tsx` limita o input a `max={item.q_reserva}` e a função `handleSeparar` rejeita com toast ("Quantidade maior que a reserva disponível") se algum item exceder a reserva |
| 7 | Poder continuar buscando produtos antes de confirmar a seleção de um já escolhido | Reunião.03 [49:35]-[49:57] | Confirmado ao vivo na própria reunião que já funcionava ("Consegue" / "Depois você vê que continua") — não era um bug |

### 2. Não alterado (confirmado ausente no código atual)

| # | O que foi pedido/relatado | Onde | Evidência de que continua em aberto |
|---|---|---|---|
| 1 | Entrada de nota fiscal de compra **sem** pedido de compra vinculado ("pode ser que seja uma entrada que não tenha pedido... tem que deixar adicionar a entrada") | Reunião.01 [11:52]-[12:54] | `EntradaNotaFiscal.tsx` (Skip 40326) só renderiza o formulário de registrar NF depois de `buscarPedidoPorNumero` achar um pedido (`{pedido && (...)}`); se não encontrar, só mostra "Nenhum pedido encontrado", sem opção de seguir sem pedido |
| 2 | Gerar PDF automaticamente ao clicar em "Separar", e já mandar direto pra separação | Reunião.01 [05:37]-[06:35] | `SeparacaoParcialPage.tsx` → `handleSeparar` só chama `criarSeparacaoParcial` (grava no banco); não há geração de PDF em nenhum lugar do arquivo |
| 3 | Integração automática Compras/Separação ↔ Logística — status "separado"/"entregue" devia se propagar sozinho pro sistema de entregas, sem o Matheus reentrar em outro sistema | Reunião.01 [06:35]-[07:41] | Não encontrado nenhum código em `lucenera-logistics-b7cd1` (Skip 24039) lendo a tabela `separacoes`/`separacao_itens` — os dois sistemas seguem operando cada um por conta própria |
| 4 | Estorno ou edição de uma lista já separada, com 2 opções (estornar inteira / editar), observação obrigatória, log de quem alterou, e notificação pro logístico quando a lista mudar depois de já estar em separação | Reunião.01 [07:41]-[10:38] | `SeparacaoParcialPage.tsx` só tem o botão "Separar" (criação); não existe fluxo de estorno, edição pós-criação, campo de observação obrigatória nem qualquer mecanismo de notificação |
| 5 | Layout de impressão da lista de entrega ("friar o layout") | Reunião.01 [10:38]-[10:47] | Nenhum componente de impressão/relatório de lista de entrega encontrado em `lucenera-logistics-b7cd1` nem em `separacao-parcial` |
| 6 | Unificar o "código" — hoje existem 3 códigos diferentes pro mesmo fluxo (venda, parcial, baixa) e devia ser 1 só | Reunião.01 [04:38]-[05:03] | `criarSeparacaoParcial` grava cada separação com seu próprio `id` (uuid, truncado na tela como "código") independente de `numero_venda` — os 3 códigos citados na reunião continuam distintos |
| 7 | Validade do orçamento fixa em 10 dias a partir da data de emissão, renovando automaticamente sempre que o orçamento for reeditado antes de enviar | Reunião.03 [30:47]-[31:25] | Campo `validade` em `BudgetFormPage.tsx` continua rotulado "Validade (Opcional)", um date-picker manual sem nenhum cálculo automático a partir da emissão nem lógica de renovação |
| 8 | Busca de produto por fornecedor (nome/SKU/referência/marca/categoria já cobertos — ver correção 2026-08-13 abaixo) | Reunião.03 [46:23]-[48:48] | `ProductSearchModal.tsx` busca por `nome/sku/referencia/codigo_produto` e filtra por marca e categoria via dropdown, mas não tem nenhum campo/filtro de fornecedor |
| 9 | Layout do cadastro de cliente no CRM: juntar RG/IE com CPF/CNPJ visualmente, e mover "tipo de cliente" pra antes do "regime de apuração" | Reunião.03 [02:09]-[02:37] | Sem SPEC cobrindo reordenação/agrupamento visual desses campos entre 077 e 085 |
| 10 | Projeto sem empresa vinculada trava a criação ("Projeto sem empresa vinculada não existe. Selecione no nome"); e vender uma peça de um perfil (ex. São Paulo) por vendedor de outro perfil (ex. Manoela) não pode travar — tem que ser flexível | Reunião.03 [25:24]-[28:34] | Sem SPEC cobrindo flexibilização de empresa/vendedor no cadastro do projeto entre 077 e 085 |

### 2.1 Correção desta investigação (2026-08-13)

Ao começar a implementar os itens 8-10 originais, a leitura direta de
`ProductSearchModal.tsx` (Orçamentos) mostrou que dois deles já estavam
resolvidos — a SPEC-086 original tinha classificado como "não alterado" só
com base na ausência de uma SPEC numerada cobrindo o assunto, sem ter lido
esse arquivo especificamente. Correção:

- **Marca e quantidade na lista de busca**: já implementado. A tabela de
  resultados tem colunas `Marca`, `Categoria`, `Estoque Total` e
  `Disponível`, além de filtros dedicados de marca e categoria (dropdowns
  acima da busca). Não vira SPEC nova.
- **Busca ampliada (nome+SKU+marca+categoria)**: parcialmente já
  implementado — nome/SKU/referência/código são full-text, marca e
  categoria já são filtros estruturados (equivalente ou melhor que busca
  livre). Só **fornecedor** continua fora — vira SPEC-094, com escopo bem
  menor do que o item original da SPEC-086.
- **UX de seleção em 2 cliques**: o fluxo mudou desde a reunião — hoje é
  checkbox por linha (`toggleSelect`) + 1 botão "Confirmar" único pro lote
  inteiro, não mais "1 clique seleciona, 1 clique pega quantidade" por item.
  Não bate 100% com a queixa original, mas é uma reformulação completa do
  fluxo, provavelmente pós-SPEC-079/080. Fica como item a confirmar com o
  usuário ao vivo antes de decidir se ainda precisa de ajuste — não teve
  SPEC de implementação aberta agora por falta de evidência de que ainda é
  um problema.

### 3. Levantado em reunião, mas sem decisão fechada

Por regra da pasta (`02-Reunioes/AGENTS.md`: "reunião é evidência, não
necessariamente decisão final"), os itens abaixo não entram na lista de
pendências — a própria reunião registra a dúvida, não uma decisão pronta pra
virar SPEC:

- **Sinal de pagamento automático vindo do financeiro**: ideia de puxar
  automaticamente pro orçamento um sinal já lançado antes dele existir
  (ex.: contrato de sinal fechado meses antes da venda rolar). O próprio
  Vinícius fecha o assunto com "a gente precisa conversar, ver se tem como" —
  não é um pedido fechado, e exige decidir de onde exatamente puxar (múltiplos
  lançamentos manuais no financeiro, sem padrão hoje) antes de virar SPEC.
- **Lentidão/cache do navegador no CRM**: relatado como problema durante o
  teste ("limpar o cachê do navegador", "F5 resolve"), mas é comportamento do
  navegador/máquina do usuário, não um bug identificado no código.

---

## Pendências

- [ ] Entrada de nota fiscal de compra sem pedido de compra vinculado (item 2.1) — hoje `EntradaNotaFiscal.tsx` exige localizar um pedido antes de liberar o formulário de registro da NF; precisa de um caminho alternativo pra lançar a entrada avulsa e linkar manualmente com a peça depois.
- [ ] Geração automática de PDF da lista de separação ao clicar em "Separar" (item 2.2) — hoje `SeparacaoParcialPage.tsx` só grava no banco, sem gerar nenhum arquivo.
- [ ] Integração automática entre Compras/Separação Parcial e Logística (item 2.3) — status "separado"/"entregue" não se propaga hoje entre os dois sistemas; cada um exige entrada manual separada.
- [ ] Estorno ou edição de lista já separada, com observação obrigatória, log de autor e notificação ao logístico (item 2.4) — não existe hoje nenhum fluxo pós-criação em `SeparacaoParcialPage.tsx`.
- [ ] Layout de impressão da lista de entrega (item 2.5) — nenhum componente de impressão encontrado em Logística nem em Separação Parcial.
- [ ] Unificar os 3 códigos (venda / parcial / baixa) num só identificador visível pro usuário (item 2.6).
- [ ] Validade do orçamento calculada automaticamente (10 dias da emissão) com renovação ao reeditar antes do envio (item 2.7) — hoje é campo manual opcional.
- [ ] Adicionar fornecedor como filtro/busca em `ProductSearchModal.tsx` (item 2.8 — marca/categoria/quantidade já existiam, corrigido em 2026-08-13, ver seção 2.1).
- [ ] Reorganizar layout do cadastro de cliente no CRM: RG/IE junto de CPF/CNPJ, tipo de cliente antes do regime de apuração (item 2.9).
- [ ] Flexibilizar projeto sem empresa vinculada e venda cruzada entre perfis/vendedores (item 2.10).
- [ ] Confirmar ao vivo com o usuário se o fluxo de checkbox+Confirmar do `ProductSearchModal.tsx` já resolve a queixa de UX de seleção em 2 cliques (ver seção 2.1) — sem SPEC de implementação até essa confirmação.
