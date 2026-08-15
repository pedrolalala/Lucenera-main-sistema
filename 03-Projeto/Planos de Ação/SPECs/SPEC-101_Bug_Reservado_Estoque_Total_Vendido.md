---
titulo: "SPEC-101 — Bug: \"Reservado\" no card de peça mostra total vendido, não o setor Reserva"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Cadastro Lucenera (cadastro-lucenera-b86fe, Skip 36668) — `PecaDetailsPanel.tsx`
  - Supabase (banco central) — `estoque_itens.quantidade_reservada`
dependencias:
  - SPEC-010 (estoque_saldos_projeto_item — fonte real de q_reserva por setor)
  - SPEC-049 (card lateral de peça onde esse bug aparece)
---

# SPEC-101 — Bug: "Reservado" no card de peça mostra total vendido, não o setor Reserva

> Origem: reunião Vinícius 14/08/2026 ([53:07]-[56:54]) — bug reproduzido ao vivo com números reais.

## Objetivo

Corrigir o card "Estoque por Local" (painel lateral de peça, Cadastro Lucenera) pra que a métrica "Reservado" mostre só a quantidade que está de fato no setor Reserva — hoje mostra a soma de Reserva + Entrega Futura (o total vendido/comprometido).

## Decisões aprovadas

Regra de negócio, citada literalmente pelo Vinícius ([54:07]-[55:31]):

> "O reserva é o que está reservado para um cliente em específico... Total é o total que está disponível para a venda e o total que está reservado para o cliente. Esse é um total, o reservado é o que está no setor reserva e o disponível é a diferença do reserva para o total."

Exemplo real usado por ele pra confirmar o bug: produto com `q_reserva = 3` e `q_entrega_futura = 2` (venda total = 5) — o card mostrava "Reservado: 5" (errado); devia mostrar "Reservado: 3".

## Definição da SPEC

### Causa raiz confirmada (código + banco)

**Frontend** — `04-Sistemas/cadastro-lucenera-b86fe/src/components/pecas/PecaDetailsPanel.tsx:198`:
```js
const totalReservado = estoquePorSetor.reduce((s, i) => s + (i.quantidade_reservada || 0), 0)
```
Isso soma `estoque_itens.quantidade_reservada` (via `getEstoqueItens`, `produtos.ts:161`, `SELECT * FROM estoque_itens WHERE produto_id = ...`).

**Backend** — `estoque_itens.quantidade_reservada` é incrementada, na aprovação do orçamento (`03_functions.sql:969`), pela quantidade **total vendida do item**, não só a parte que entrou em Reserva:
```sql
UPDATE public.estoque_itens
SET quantidade_reservada = quantidade_reservada + v_item.quantidade,  -- quantidade TOTAL do item, não só q_reserva
...
```
Onde `v_item.quantidade` é a quantidade vendida inteira (a mesma que depois é dividida entre `q_reserva`/`q_entrega_futura` na tabela mais granular `estoque_saldos_projeto_item`, SPEC-010). Ou seja: `estoque_itens.quantidade_reservada` é, por desenho, o **total comprometido** (reserva + entrega futura) — não "só o que está no setor Reserva". Esse é o mesmo conceito que a view `vw_necessidade_compra` já chama corretamente de `qtd_comprometida` (achado ao investigar Necessidade de Compra nesta mesma sessão).

**Não é um bug isolado de exibição** — `quantidade_reservada` é usada por várias outras RPCs (`cancelar_orcamento`, `registrar_devolucao_projeto_item`, entre outras) com o significado de "total comprometido". Mudar o que essa coluna significa é arriscado e quebraria essas outras rotinas.

### Proposta (não implementar sem aprovação)

**Não alterar `estoque_itens.quantidade_reservada`** (significado certo pro resto do sistema). Corrigir só a exibição: trocar a fonte de dado do card "Estoque por Local" pra somar `estoque_saldos_projeto_item.q_reserva` por `produto_id` (via join com `projeto_itens`), em vez de `estoque_itens.quantidade_reservada`. Isso dá exatamente a métrica que o Vinícius descreveu — "o que está no setor reserva", separado de "entrega futura".

Precisa também revisar a fórmula de "Total" e "Disponível" no mesmo card (linhas 197 e 199 do `PecaDetailsPanel.tsx`) pra continuar batendo com a regra dele: Total = tudo que existe fisicamente pro produto; Disponível = Total − Reservado (só a parte em setor Reserva, não a comprometida inteira).

## Análise de ecossistema

- **Depende de**: `estoque_saldos_projeto_item` (SPEC-010), `estoque_itens`, `projeto_itens`.
- **Afeta**: só a exibição no card de peça do Cadastro Lucenera. Não muda nenhuma RPC nem o significado de `estoque_itens.quantidade_reservada` pro resto do sistema — risco baixo.
- **Dado duplicado que deveria ser derivado por relacionamento**: o card já deveria estar lendo de `estoque_saldos_projeto_item` (fonte granular correta, SPEC-010) em vez de `estoque_itens.quantidade_reservada` (agregado, mistura setores).

## Realizado

### 2026-08-15

- Resolvida a pendência sem precisar perguntar: a tabela "Reservado por Cliente/Projeto" (SPEC-049), já na mesma tela, já quebra Reserva (`q_reserva`) e Entrega Futura (`q_entrega_futura`) lado a lado por projeto/cliente — então o badge do topo só precisa mostrar o agregado de `q_reserva`, sem duplicar a quebra.
- `PecaDetailsPanel.tsx`: os badges do cabeçalho ("Reservado"/"Disponível") passaram a somar `q_reserva` vindo de `reservasData` (já carregado pra tabela "Reservado por Cliente/Projeto", fonte `vw_cadastro_produto_reserva_detalhe`, SPEC-049) em vez de `estoque_itens.quantidade_reservada`. A tabela "Estoque por Local" (distribuição física por depósito) foi mantida com a métrica antiga (`totalComprometido`/`totalDisponivelPorLocal`), já que ali é uma visão por local, não por setor de negócio — nenhuma migration nova foi necessária, a view certa já existia (SPEC-049).
- Drift encontrado e corrigido antes de publicar: o arquivo local estava desatualizado em relação ao Skip (faltava um fallback `peca.referencia ||` já em produção) — sincronizado antes de aplicar o fix, sem perder a mudança já publicada.
- Testado com dado real: produto 10289 tinha `estoque_itens.quantidade_reservada` somando 816 (comprometido total) mas `q_reserva` real = 0 (tudo em entrega futura). Publicado Skip 36668 v0.0.61 — QA limpo. Testado ao vivo no navegador: card do produto 10289 agora mostra "Reservado: 0", antes mostrava 816.

## Pendências

Nenhuma.
