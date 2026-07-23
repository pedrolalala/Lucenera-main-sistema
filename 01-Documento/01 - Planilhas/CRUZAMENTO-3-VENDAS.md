# Cruzamento 3 (Vendas) — estado da investigação, decisões exploradas e pendências

**Status: pausado a pedido do usuário em 2026-07-23.** As decisões técnicas registradas aqui foram exploradas nesta sessão mas **não estão confirmadas** — retomar do zero, revisando cada ponto, antes de continuar.

Este arquivo existe pra não perder o raciocínio e os números já levantados. Ver também `AGENTS.md` (backlog geral dos 9 cruzamentos) e `DECISOES.md` (decisões já fechadas dos cruzamentos 1 e 2, esses sim aplicados e confirmados).

---

## 1. O que é a planilha `venda`

Aba `venda` de `Cruzamento de dados.xlsx` (hoje em `Backup v1/`): **22.171 linhas, item por item** (um produto por linha), não uma linha por venda. Colunas: `CodEmpresa, CodPerfil, CodVenda, NomeCliente, DtVenda, CodProduto, Referencia, DescProduto, VlUnitario, QtdProduto, VlTotal, GrupoCFOP`.

Agrupando por `CodVenda`: **3.795 vendas distintas** (média ~5,8 itens por venda). `DtVenda` vem sempre no formato texto `"D DD/MM/AAAA"` (100% dos casos, prefixo "D " confirmado).

`NomeCliente` costuma vir com o código do projeto embutido no início (ex: `"17151 MARCELO STEFANI"`, `"15.191 JOSÉ LUIZ E GABI"`) — mesmo padrão usado no cruzamento 1.

### GrupoCFOP — 16 valores distintos, nunca misturados dentro do mesmo CodVenda

| GrupoCFOP | Linhas |
|---|---|
| VENDAS | 16.621 |
| TROCA DEV | 2.068 |
| REMESSA TRANSP | 1.491 |
| GARANTIA | 722 |
| CASA COR SAIDA | 348 |
| BONIFICACAO | 344 |
| USO E CONSUMO | 141 |
| CASA COR ENTRADA | 110 |
| DEV EM GARANTIA | 100 |
| INVENTARIO | 100 |
| SAIDA INDUSTRIALIZACAO | 58 |
| SAC | 45 |
| REMESSA CONSERTO | 15 |
| DEV COMPRA | 5 |
| DESCARTE | 2 |
| RETORNO | 1 |

Confirmado por checagem direta: **nenhum `CodVenda` tem mais de um `GrupoCFOP`** — é sempre um valor único por venda, nunca por item.

Usuário confirmou (2026-07-23): tratar só **GrupoCFOP = "VENDAS"** por enquanto para o cruzamento de orçamento/estoque. Os outros 15 tipos ficam de fora dessa parte.

---

## 2. Arquitetura real do sistema (descoberta durante a investigação)

A primeira hipótese (preencher direto a tabela `vendas` como "cabeçalho de venda") estava **errada** — o usuário corrigiu: o fluxo real de negócio é

```
CodVenda (agrupado)  →  orcamentos + orcamento_itens  →  aprovar_orcamento_financeiro()  →  projeto_itens + projeto_parcelas + boletos + reserva de estoque (estoque_itens.quantidade_reservada)
```

`aprovar_orcamento_financeiro(p_orcamento_id)` é a função real que o sistema usa quando um orçamento é aprovado (lida integralmente em `supabase/db/current/01_schema_full.sql` linha ~714 — **atenção: essa cópia local está desatualizada**, a versão viva no banco é maior e também mexe em `estoque_saldos_projeto_item`/`estoque_movimentos_projeto_item`, que a cópia local não menciona; confirmar sempre com `pg_get_functiondef` direto no banco, não confiar no arquivo).

Exigências **NOT NULL** da função pra aprovar um orçamento: `empresa_id`, `cliente_id`, `projeto_id`, `valor_total > 0`, `forma_pagamento`, `frete_tipo`, `orcamento_itens` com quantidade/preço válidos, e `condicoes_pagamento`/`prazo_pagamento_dias` parseável em pelo menos 1 parcela. Nenhuma dessas colunas tem fonte direta na planilha `venda` — todas precisaram de resolução via outras fontes (ver seção 3).

Recomendação (não aplicada): em vez de reescrever essa lógica na mão, criar `orcamentos`+`orcamento_itens` e **chamar a função real via RPC** (`supabase-py`, service role — mesmo padrão dos scripts em `scripts/`), pra não duplicar/divergir da regra de negócio oficial.

---

## 3. Fontes de resolução testadas, por campo

### `projeto_id`
Código no início do `NomeCliente` (texto) → `projetos.codigo`. Único método disponível. Cobertura: **17.559 de 22.171 linhas totais** (79%, todos os GrupoCFOP); para o subconjunto GrupoCFOP=VENDAS agrupado (2.042 vendas), **1.393 resolvem** (2.042 − 649 sem projeto).

### `cliente_id` (pro orçamento)
Duas fontes, testadas separadas e depois combinadas:
- **Via texto do `NomeCliente`** (mesmo método do cruzamento 1) → fraca sozinha.
- **Via `cod_venda → negociacoes.cod_pessoa → contatos.codigo_legado`** (sugerida pelo usuário) → **muito mais forte**: 1.492 de 2.042 (73%) resolvem sozinha, porque `cod_pessoa` é um campo estruturado no financeiro já importado, não texto livre.
- Combinando as duas (preferindo a via `negociacoes`, caindo pra `projetos.cliente_id` do cruzamento 1 quando a primeira falha): só **50 de 2.042** ficam sem nenhuma fonte de cliente.

### `empresa_id`
Quatro fontes testadas, nenhuma forte sozinha:
- `projetos.empresa_id` direto: só 995 de 3.701 projetos (27%).
- `contatos.empresa_id`: péssima cobertura, só 82 de 2.638 clientes (3%) — **não usar como fonte principal**.
- Outro projeto do mesmo cliente que já tem empresa (moda): baixo volume adicional (~35 casos), mas 0 conflitos quando existe (um cliente nunca aparece em duas empresas diferentes nos dados testados).
- **`negociacoes.empresa_id` pego direto na mesma linha usada pra resolver `cod_pessoa`** (via `cod_venda`): a melhor fonte, "de graça" junto com a resolução de cliente acima.
- Combinando tudo: só **42 de 2.042** ficam com cliente resolvido mas sem empresa.

### `forma_pagamento` / `frete_tipo`/`frete_valor`
Via `transacoes.tipo_pagamento` / `transacoes.vl_frete`, casando por `cod_venda`. Cobertura: **~1.739 de 2.042** vendas têm transação casada (303 não têm).
Distribuição real de `tipo_pagamento` (só nas transações com `cod_venda`): Pix 5.722, Duplicata Gerada 1.590, Dinheiro 1.241, Boleto 1.181, Carteira 825, DEV TROCA 497, Acordo Valor Zerado 305, Acordo 219, Cartão 170, Cheque 24, Banco 8, Antecipação Gerada 2, nulo 224 — **só Pix/Boleto/Dinheiro/Cartão/Cheque mapeiam limpo pro enum do sistema** (`pagamento_forma`: pix, cartao, boleto, transferencia, cheque, dinheiro); os demais (Duplicata Gerada, Carteira, DEV TROCA, Acordo...) precisariam de uma regra de fallback, **não decidida**.
Frete: **quase inexistente** — só 18 de 12.008 transações com `cod_venda` têm `vl_frete > 0`. Praticamente sempre seria "sem frete".

### Número final de cobertura (GrupoCFOP=VENDAS, 2.042 vendas agrupadas)

| Etapa | Perdidas | Restantes |
|---|---|---|
| Total | — | 2.042 |
| Sem projeto_id | 649 | 1.393 |
| Sem cliente (nenhuma fonte) | 50 | 1.343 |
| Sem empresa | 42 | 1.301 |
| Sem transação (forma pagto/frete) | 303 | **998** |

**998 de 2.042 (49%) ficariam prontas pra virar orçamento aprovado** com as fontes testadas. Esse número **não foi aplicado** — ficou só na simulação.

---

## 4. Pedido separado: as 22.171 linhas completas em `vendas`

Depois de fechar a lógica acima, o usuário pediu, à parte: **as 22.171 linhas (todos os 16 GrupoCFOP, não só "VENDAS") precisam existir em `vendas`**, item por item, com o campo `GrupoCFOP` preservado — como registro histórico completo, sem necessariamente passar pela lógica de orçamento/aprovação.

### Bloqueios encontrados nessa parte

1. **`vendas` é desenhada como "1 linha por venda"**: tinha uma constraint `UNIQUE(cod_venda)` (`vendas_cod_venda_key`), incompatível com gravar várias linhas de item pro mesmo `CodVenda`. Também não tinha colunas pra CFOP nem pra dado de item (`CodProduto`, `DescProduto`, `VlUnitario`, `QtdProduto`).
2. **Risco de duplicidade financeira**: 4 views (`vw_projetos_pipeline`, `vw_projetos_por_status`, `vw_financeiro_projetos`, `vw_dashboard_crm_fechamento`) somam `vendas.valor_total` por projeto. Se as 22 mil linhas entrassem em `vendas` **e** os orçamentos da seção 3 também fossem criados (parcelas/boletos), o financeiro dos mesmos projetos contaria duas vezes.

### Decisão tomada sobre a duplicidade (única parte desta seção que foi de fato aplicada no banco)

Usuário escolheu: **`vendas` = só histórico, nunca soma no financeiro**. Implementado via uma coluna `historico_legado boolean`, e as 4 views acima foram ajustadas pra somar `vendas.valor_total` só onde `historico_legado = false`.

---

## 5. Estado real do banco agora (2026-07-23, verificado)

**Aplicado e commitado:**
- `vendas` ganhou as colunas: `grupo_cfop`, `produto_id` (FK `produtos.id`), `descricao_produto`, `vl_unitario`, `qtd_produto`, `historico_legado boolean NOT NULL DEFAULT false`.
- As 4 views (`vw_projetos_pipeline`, `vw_projetos_por_status`, `vw_financeiro_projetos`, `vw_dashboard_crm_fechamento`) foram recriadas somando `vendas.valor_total` só onde `historico_legado = false`.
- **Nenhum dado foi inserido** — `vendas` continua com as mesmas 263 linhas de sempre, todas com `historico_legado = false`. O comportamento das 4 views hoje é idêntico ao de antes (o filtro não muda nada ainda, porque não existe nenhuma linha `historico_legado = true`).
- Migration documentada em `supabase/db/migrations/20260723_062_vendas_historico_legado_cfop/`.

**NÃO aplicado (usuário interrompeu antes de confirmar):**
- A constraint `vendas_cod_venda_key` (`UNIQUE(cod_venda)`) **ainda existe** — bloqueia inserir mais de uma linha por `CodVenda`. Removê-la é pré-requisito pra gravar as 22.171 linhas item a item.
- Nenhuma das 22.171 linhas da planilha `venda` foi inserida em `vendas`.
- Nenhum orçamento (`orcamentos`/`orcamento_itens`) foi criado pros 998 casos da seção 3 — a chamada de `aprovar_orcamento_financeiro` nunca foi feita.

---

## 6. Pendências / decisões em aberto pra retomar

1. **Confirmar (ou revisar) se a arquitetura de duas partes ainda faz sentido**: (A) as 22.171 linhas cruas em `vendas` como histórico, com `GrupoCFOP`; (B) só o subconjunto "VENDAS" virando orçamento aprovado de verdade. O usuário pediu pra desconsiderar as decisões técnicas específicas tomadas aqui — vale reabrir essa pergunta do zero.
2. Se a parte (A) for confirmada: falta decidir se remove mesmo a `UNIQUE(cod_venda)` (ação que precisa de aprovação explícita — o classificador de permissão do Claude Code bloqueia `DROP CONSTRAINT` por padrão).
3. Os outros 15 tipos de `GrupoCFOP` (5.550 linhas) continuam sem nenhum tratamento definido — trocas/devoluções (`TROCA DEV`, `DEV EM GARANTIA`, `DEV COMPRA`) provavelmente deveriam **entrar** estoque em vez de sair; `INVENTARIO` é ajuste de contagem, não venda; `REMESSA TRANSP`/`REMESSA CONSERTO` talvez nem devessem virar orçamento. Nenhum desses mapeamentos foi definido.
4. Regra de fallback pra `forma_pagamento` quando `transacoes.tipo_pagamento` é algo fora do enum (Duplicata Gerada, Carteira, DEV TROCA, Acordo...) — 43% das transações casadas caem nesse caso.
5. Confirmar se faz sentido mesmo chamar `aprovar_orcamento_financeiro` (função de produção, com efeitos colaterais em parcelas/boletos/estoque) pra dado histórico, ou se um caminho mais simples/direto seria melhor pra esse caso de importação retroativa.
