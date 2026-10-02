---
titulo: "SPEC-175 — Estoque por empresa nos bastidores (Manoela, Foco, ISLIGHT)"
status: não iniciado
data_ultima_modificacao: 2026-10-01
sistemas_envolvidos:
  - Cadastro (cadastro-lucenera-b86fe)
  - Compras (compras-lucenera-3o23t98ee)
  - Orçamentos (gestao-financeira-clone-544cb)
  - Logística / Separação
  - Vendas / NF-e (vendas-lucenera)
  - Catálogo Ubiqua (catalogo-pecas-ubiqua-e6fa0)
  - Banco central (produtos, estoque_itens, pedidos_compra, orcamentos, empresas)
dependencias:
  - SPEC-174 (item N9, origem deste levantamento)
  - SPEC-039 / SPEC-057 (empresa em pedidos_compra)
  - SPEC-103 (empresa visível na Necessidade de Compra, só informativa)
  - SPEC-147 / SPEC-171 (Catálogo Ubiqua, divisão por empresa isolada no domínio)
  - SPEC-010 (padrão de saldo vivo + movimentos + agregado de compatibilidade)
---

# SPEC-175 — Estoque por empresa nos bastidores (Manoela, Foco, ISLIGHT)

> Origem: item N9 da `03-Projeto/Planos de Ação/SPECs/SPEC-174_Conferencia_Reuniao_01_10_e_Novos_Pedidos.md`.
> Trecho da reunião: `02-Reunioes/26. Lucenera (Vinicius) - 01.10.2026_Reunião revisão do sistema/Reunião.01.txt`,
> [40:32]-[54:41]. Na transcrição, "Slide" = **ISLIGHT**, "Lutineira" = **Lucenera** e "Manuela" = **Manoela**
> (confirmado pelo usuário em 01/10).
>
> Esta SPEC é **só levantamento + proposta de modelagem**. Não há implementação, migration ou código. A decisão
> de qual alternativa adotar é do usuário/Vinícius; a implementação vira uma SPEC nova, derivada desta.

## Checklist de Ação

- [ ] Decidir com o usuário/Vinícius qual das 3 alternativas de modelagem (seção 4) será adotada.
- [ ] Reextrair `supabase/db/current/` para o domínio de Compras antes de qualquer migration real (confirmar a
  estrutura de `pedidos_compra`/`pedido_compra_itens`, ausentes do snapshot atual).
- [ ] Confirmar os nomes exatos das 3 empresas em `empresas.nome`/`empresas.codigo` antes de qualquer migration.
- [ ] Depois da decisão, abrir a SPEC de implementação com a migration, o backfill do balanço inicial e as
  mudanças em `aprovar_orcamento_financeiro` e no recebimento de compra.

### Passos manuais do usuário

- [ ] Pedir ao Sérgio as 3 planilhas de balanço de estoque, uma por empresa (Manoela, Foco, ISLIGHT).
- [ ] Responder as perguntas abertas (seção 5) antes de abrir a SPEC de implementação.
- [ ] Validar com o Vinícius se Garantia/Casa Cor (N8 da SPEC-174) precisam da mesma granularidade por empresa.

## Objetivo

Registrar o requisito fiscal e operacional dito pelo Vinícius em 01/10 (rastrear o estoque por empresa do
grupo — Manoela, Foco e ISLIGHT — "nas entrelinhas" do banco, sem mudar a tela, que continua mostrando a soma
como "estoque Lucenera"), mapear o que já existe no banco, propor alternativas de modelagem com prós e contras,
recomendar uma e deixar perguntas abertas e fases para quando a implementação for decidida.

## Decisões aprovadas

Fechadas na reunião de 01/10 e na SPEC-174:

- **Requisito fiscal:** por mudança de regime tributário (Simples → Lucro Presumido/Real) e risco de
  fiscalização da Secretaria da Fazenda, o estoque precisa ser rastreável por empresa: **Manoela, Foco e ISLIGHT**.
- **Regra de movimento:** vendeu pela empresa X, sai do estoque de X; comprou pela empresa X, entra no estoque
  de X (ex.: importação Ubiqua é sempre pela ISLIGHT).
- **Visualização não muda:** a tela mostra a soma ("estoque Lucenera"); a granularidade é só interna.
- **Não bloquear venda:** vender 15 pela Manoela tendo 10 na Manoela e 5 na Foco é permitido.
- **Carga inicial por balanço:** 3 planilhas do Sérgio, uma por empresa (ainda não recebidas).
- **Fora de escopo agora, mas a modelagem não pode impedir** ([51:00]-[53:29]):
  - marca presa a uma única empresa (ex.: Interlight sempre pela ISLIGHT, por causa do crédito de ICMS);
  - uma venda com 2 ou 3 notas fiscais de empresas diferentes do grupo.

## Definição da SPEC

### 1. Requisito dito na reunião (resumo do trecho [40:32]-[54:41])

- [40:32]-[45:02]: motivo fiscal (fiscalização; empresa do Simples vs. lucro presumido/real). Hoje a tela mostra
  só o estoque geral somado; "na visualização não muda nada... lá intrínseco no banco de dados ele vai
  trabalhando o estoque de empresa por empresa".
- [45:02]-[49:25]: o Catálogo Ubiqua já tem essa divisão (SPEC-147/171). Hoje o Vinícius faz o controle
  manualmente ao abrir pedidos de compra por empresa, olhando o negativo de cada uma (ex.: 195 negativo dividido
  entre ISLIGHT, Foco e Manoela → 3 pedidos).
- [49:30]-[50:37]: carga inicial por balanço ("100 positivo... 50 da Foco, 20 da ISLIGHT, 30 da Manoela"),
  pedido das 3 planilhas ao Sérgio.
- [51:00]-[53:42]: futuro fora de escopo (marca presa a empresa; venda com várias notas).

### 2. Estado atual confirmado em `supabase/db/current/`

**Estoque hoje é único, sem quebra por empresa:**

- `produtos` tem `estoque_total`, `estoque_showroom`, `estoque_disponivel` — valores únicos por produto.
- `estoque_itens`: `(id, produto_id, local estoque_local, quantidade, quantidade_reservada, atualizado_por,
  atualizado_em)`, com **`UNIQUE(produto_id, local)`** — 1 linha por produto por "local", sem empresa.

**Achado 1 — o enum já está preparado para empresa, mas nunca foi ligado a código:**

```sql
CREATE TYPE public.estoque_local AS ENUM (
    'Estoque', 'Showroom', 'Em trânsito', 'Reservado', 'Estoque Geral',
    'Estoque Luce Nera', 'Estoque Islight', 'Estoque Foco',
    'Estoque Garantia', 'Estoque Casa Cor',
    'Reserva', 'Separação', 'Entrega Futura', 'Devolução',
    'Estoque Defeito', 'Amostra / Emprestado', 'Estoque Citel'
);
```

Em `03_functions.sql` e `05_views.sql` só `'Estoque'`, `'Showroom'`, `'Em trânsito'` e `'Reservado'` são usados.
Os valores por empresa (e `'Estoque Garantia'`/`'Estoque Casa Cor'`) existem no enum, mas nenhuma
function/trigger/view os referencia.

**Achado 2 — `orcamentos.empresa_id` promete herança para o estoque, mas só cumpre no financeiro:**

```sql
COMMENT ON COLUMN public.orcamentos.empresa_id IS
  'ÂNCORA: Define se a venda é Foco, Manoella ou Islight. Todo o fluxo financeiro e de estoque herdará este ID.';
```

Em `aprovar_orcamento_financeiro` (e `aprovar_orcamento_financeiro_base_spec001`), `v_orcamento.empresa_id` é
usado para gravar `boletos.empresa_id`, mas a reserva de estoque na mesma transação (`INSERT/UPDATE estoque_itens
... local = 'Estoque'`) nunca usa `empresa_id`.

**Achado 3 — outras tabelas já segregam por empresa (fora do estoque):** `projetos.empresa_id`,
`transacoes.empresa_id`, `boletos.empresa_id`, `contas_bancarias.empresa_id`, `remessas.empresa_id`,
`retornos_processados.empresa_id`, `funcionarios.empresa_id`, `usuarios.empresa_id`. `empresas` já tem
`regime_tributario`. `pedidos_compra.empresa_id` é citado em `supabase/db/domains/estoque_compras.md`
(SPEC-039/057), mas `pedidos_compra` **não aparece** em `supabase/db/current/` (reextração do domínio Compras é
pendência crônica) — revalidar contra o Supabase real antes de qualquer migration.

**Achado 4 — a divisão por empresa que já existe está isolada no Ubiqua:** na SPEC-171, cada empresa tem uma
referência diferente em `revenda_ubiqua` (ex.: `339104` = Manoella, `339104-IS` = ISLIGHT) e
`ubiqua_estoque_atual()` soma por referência. Não generaliza para `produtos`/`estoque_itens`. A SPEC-103 mostra
`empresa_id`/`empresa_nome` em `vw_necessidade_compra_detalhe`, mas é a empresa da venda de origem, não saldo
físico por empresa.

### 3. Onde o estoque é movimentado hoje

| Movimento | Função/trigger | Observação |
|---|---|---|
| Reserva na aprovação do orçamento | `aprovar_orcamento_financeiro` / `..._base_spec001` | Tem `v_orcamento.empresa_id` disponível, mas não usa. |
| Devolução | `registrar_devolucao_projeto_item` (SPEC-015) / `registrar_devolucao_projeto_item_setor` (SPEC-054) | Não recebe nem grava empresa. |
| Reserva legada ligada a projeto | `trigger_reserva_estoque()` (trigger em `projetos`) | Agnóstica de empresa. |
| Criação de pedido de compra | `criar_pedido_compra_lote` / `criar_pedido_compra_de_necessidade` | Grava `empresa_id` no pedido (quem compra), não no estoque. |
| Recebimento de compra | Sem RPC hoje (SPEC-EST-12 do escopo, "a definir") | Ponto natural para gravar a entrada por empresa. |
| Separação/entrega | `separacoes` / `separacao_itens` / `entregas` | Sem empresa; a baixa real já acontece na aprovação. |
| Catálogo Ubiqua | `ubiqua_estoque_atual()` (SPEC-171) | Caminho próprio e isolado. |

### 4. Alternativas de modelagem

**A — Coluna `empresa_id` em `estoque_itens` (muda a chave para `UNIQUE(produto_id, local, empresa_id)`).**
- Prós: mesma tabela/colunas do fluxo vivo; uma fonte de verdade; `SUM()` mantém a tela igual.
- Contras: toda query/função que filtra `local = 'Estoque'` (≥10 pontos, incluindo `aprovar_orcamento_financeiro`
  e views de Necessidade de Compra) precisa agrupar por empresa; maior risco de regressão nas RPCs mais críticas;
  decidir o que fazer com saldo "sem empresa" que o balanço não resolver.

**B — Reaproveitar os valores do enum (`'Estoque Luce Nera'`, `'Estoque Islight'`, `'Estoque Foco'`).**
- Prós: sem migration de estrutura; chave atual mantida.
- Contras: mistura "onde fisicamente" com "de qual empresa" no mesmo campo; não representa "Showroom da ISLIGHT"
  ou "Reservado pela Foco". **Desencorajada.**

**C — Tabela/ledger de saldo por empresa paralela a `estoque_itens`** (ex.: `(produto_id, empresa_id, quantidade,
tipo_movimento, origem, referencia_id, criado_em)`), no padrão da SPEC-010 (movimentos + saldo + agregado de
compatibilidade).
- Prós: não altera `estoque_itens` (sem regressão imediata); separa local físico de empresa fiscal; comporta os
  dois casos futuros (marca presa a empresa; venda com N notas = N linhas de ledger).
- Contras: mais uma estrutura para reconciliar com `estoque_itens`/`produtos.estoque_total` — exige conferência
  periódica `SUM(por empresa) = agregado`.

**Recomendação:** alternativa **C** (menor risco no código crítico, padrão já usado no domínio). A é válida mas
mais invasiva. **A decisão final é do usuário/Vinícius.**

### 5. Perguntas abertas

1. Compra de reposição sem venda vinculada: a entrada vai para a empresa de `pedidos_compra.empresa_id` (escolhida
   no pedido)? Basta esse campo como fonte?
2. As 3 planilhas do balanço virão como produto × empresa × quantidade, ou vão exigir conciliação de
   referência/código (problema já visto no Ubiqua, SPEC-147/171)?
3. Devoluções, Garantia/Casa Cor e ajustes de inventário também carregam empresa?
4. Saldo negativo de uma empresa (não bloqueia) deve gerar alerta/relatório de "comprar pela empresa certa"? Já na
   Fase 1 ou em painel futuro?
5. Grafia exata das empresas em `empresas` ("Manoela" vs. "Manoella"; "ISLIGHT") — conferir com
   `SELECT codigo, nome FROM empresas ORDER BY codigo` ao abrir a implementação.
6. Showroom/Garantia/Casa Cor precisam de granularidade por empresa ou só o estoque geral?
7. Confirmar que a alternativa C comporta 2-3 linhas de ledger por venda (venda com N notas) antes de descartar A/B.

### 6. Ordem sugerida (depois da decisão)

1. Decidir a alternativa (bloqueante).
2. Receber e conferir as 3 planilhas do Sérgio.
3. Reextrair `supabase/db/current/` do domínio Compras.
4. Migration da estrutura + carga inicial (dry-run com ROLLBACK antes do COMMIT).
5. `aprovar_orcamento_financeiro`/`..._base_spec001` passam a gravar o movimento por empresa (`v_orcamento.empresa_id`).
6. Recebimento de compra grava a entrada na empresa de `pedidos_compra.empresa_id`.
7. Conferir que nenhuma tela muda (continua a soma).
8. Reconciliação periódica (soma por empresa = agregado).
9. (Futuro) marca presa a uma empresa + venda com notas de 2-3 empresas.

### 7. Impacto por sistema

- **Cadastro:** nada muda nesta fase; uma quebra por empresa no card seria leitura de view nova.
- **Compras:** maior impacto futuro (recebimento decide a empresa da entrada); manter o padrão de `services/*.ts`
  lendo views e escrevendo por RPC `SECURITY DEFINER`.
- **Orçamentos:** `aprovar_orcamento_financeiro` é o ponto central de saída por venda.
- **Logística/Separação:** provavelmente fora desta fase (baixa real já acontece na aprovação).
- **Vendas/NF-e:** empresa emissora já definida no fluxo fiscal; vincular movimento e nota por
  `orcamento_id`/`pedido_compra_id`, sem campo novo.
- **Catálogo Ubiqua:** sem mudança; serve de contraexemplo de solução pontual.

### 8. Plano de rollback (para a implementação futura)

- Migrations aditivas (tabela/coluna nova), sem alterar função crítica na mesma migration que cria a estrutura.
- Reversão: `DROP` da estrutura nova; a ligação em `aprovar_orcamento_financeiro` em migration própria,
  revertível separadamente.
- Dry-run com ROLLBACK obrigatório antes de qualquer COMMIT.

### 9. Documentos a atualizar quando implementar

- `supabase/db/domains/estoque_compras.md` (seção "Estoque por empresa").
- `supabase/docs/relationships.md` (eixo empresa↔estoque; registrar `pedidos_compra`).
- `03-Projeto/Escopos/05_ESCOPO_ESTOQUE_COMPRAS.md` (entrada `SPEC-EST-XX`).
- `CHANGELOG.md`, esta SPEC e a SPEC de implementação derivada.

## Realizado

### 2026-10-01

- Levantamento feito pelo agente `planner` a partir da SPEC-174 (N9), da reunião de 01/10 e do snapshot
  `supabase/db/current/`. Dois achados novos: enum `estoque_local` com valores por empresa nunca usados, e
  `orcamentos.empresa_id` prometendo herança para o estoque que nunca foi implementada. Nenhuma migration, nenhum código.

## Pendências

- [ ] Decidir com o Vinícius a alternativa de modelagem (A/B/C, seção 4) — bloqueante para a implementação.
- [ ] Receber do Sérgio as 3 planilhas de balanço por empresa (Manoela, Foco, ISLIGHT).
- [ ] Confirmar a grafia exata das 3 empresas em `empresas.nome`/`codigo`.
- [ ] Decidir se Garantia/Casa Cor precisam da mesma granularidade por empresa.
- [ ] Reextrair `supabase/db/current/` para o domínio de Compras antes da migration real.
- [ ] Responder as perguntas abertas 1 a 7 (seção 5).
- [ ] Abrir a SPEC de implementação só depois da decisão de modelagem.
