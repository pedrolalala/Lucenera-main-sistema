---
titulo: "SPEC-284 — Dashboard (Estoque) e Compras (Pedido Avulso) passam a ler o estoque real"
status: concluído
data_ultima_modificacao: 2026-11-11
sistemas_envolvidos:
  - Banco (Supabase SP) — views v_estoque_produtos e vw_estoque_produtos
  - Dashboard (página Estoque) — sem mudança de código
  - Compras (Pedido Avulso) — sem mudança de código
---

# SPEC-284 — Dashboard (Estoque) e Compras (Pedido Avulso) passam a ler o estoque real

## Checklist de Ação

- [x] Diagnóstico com números do banco e conferência do código e da tela no ar (11/11)
- [x] Migration `20261111_337_spec284_estoque_telas_leem_estoque_real` (up, rollback, dry_run)
- [x] Ensaio em ROLLBACK no Supabase SP
- [x] Aplicar no Supabase SP (autorizado pelo Filippo em 11/11)
- [ ] Conferir as duas telas no ar (Dashboard → Estoque; Compras → Pedido Avulso): exige login, fica com o usuário
- [ ] Parte B (decisão): desligar o gatilho `trg_sync_estoque_itens_from_produtos`

### Passos manuais do usuário

- [x] Autorizar a aplicação da migration 337 (11/11)
- [ ] Decidir a Parte B (gatilho antigo)

## Objetivo

Duas telas mostram estoque **congelado em 05/11**, porque leem as colunas `produtos.estoque_total` e `produtos.estoque_disponivel`:

| Tela | View | Efeito |
|---|---|---|
| Dashboard → **Estoque** | `v_estoque_produtos` | quantidades e valores (custo/venda, disponível, negativo) de 05/11 |
| Compras → **Pedido Avulso** (colunas Estoque e Disponível) | `vw_estoque_produtos` | a compradora decide a compra sem venda olhando número velho |

Essas colunas só eram atualizadas pela importação da planilha de Produtos da Connect. A gravação de estoque nessa importação foi suspensa em 22/10 (SPEC-222), porque o gatilho `fn_sync_estoque_itens_from_produtos` sobrescrevia o estoque real. Desde então o sistema grava direto em `estoque_itens` (entrada de nota, reserva na aprovação, separação, entrega, ajustes) e nada atualiza as colunas antigas.

Medido em 11/11 (Pedido Avulso, 4.571 peças): disponível diferente em **391**; a tela diz que **tem** e não tem em **282**; diz que **falta** e tem em 5; estoque físico diferente em 20. Exemplos: 13587 tela −43 × real 17; 12395 tela −18 × real 17; 12135 tela 0 × real −31.

Resultado esperado: as duas telas mostram o estoque real, em tempo real, sem mudar código nos sistemas.

## Decisões aprovadas

- Filippo (11/11): "preparar" a correção; aplicar só com autorização.
- Corrigir no banco (views), não nas telas: as telas já leem `estoque_total`/`estoque_disponivel`, e só muda a origem.
- Estoque Geral = `estoque_itens` com `local = 'Estoque'`. Mesmo critério da aprovação de orçamento, da re-reserva e das conferências. Hoje só existem linhas em `Estoque` e `Showroom` (Showroom com quantidade 0).
- Disponível = `quantidade − quantidade_reservada` do local `Estoque`. É a mesma conta que a aprovação de orçamento usa para decidir reserva × entrega futura (inclui a herança Connect e a entrega futura no reservado).
- Showroom continua vindo de `produtos.estoque_showroom`, mantido pelo sistema Movimentação de Peças (SPEC-224). Não muda.

## Definição da SPEC

### Parte A — migration 337 (só as duas views)

- `v_estoque_produtos`: `estoque_total` e `estoque_disponivel` passam a vir de `estoque_itens` (local `Estoque`), com o mesmo tipo `numeric(15,3)`. Os valores derivados (`valor_custo_total`, `valor_venda_total`, `valor_*_disponivel`, `valor_*_negativo`) passam a usar esses números. Mesmas colunas, mesma ordem, mesmo filtro (`ativo`), mesmas permissões e comentário.
- `vw_estoque_produtos`: `estoque_total` e `estoque_disponivel` passam a vir de `estoque_itens` (local `Estoque`). As outras colunas (`qtd_estoque_itens`, `qtd_reservada` etc.) e o `security_invoker` não mudam.
- Nenhuma tabela, função, permissão ou tela muda.
- Rollback: recria as duas views exatamente como estavam em 11/11.

### Parte B — decisão pendente: gatilho antigo

O gatilho `trg_sync_estoque_itens_from_produtos` (em `produtos`, `AFTER INSERT OR UPDATE OF estoque_total, estoque_disponivel`) copia as colunas antigas para `estoque_itens`. Hoje nenhum sistema grava nessas colunas. Mas se alguém rodar `importar_produtos_estoque.py --incluir-estoque`, ou editar essas colunas à mão, o estoque real é sobrescrito com o número da planilha, e se perdem entradas de nota, reservas e ajustes. Recomendação: desligar (`ALTER TABLE produtos DISABLE TRIGGER ...`). Fica fora da migration 337 até a decisão.

### Critérios de aceite

- Depois de aplicar, para todas as peças ativas: `estoque_total` e `estoque_disponivel` das duas views = `estoque_itens` (local `Estoque`). O `dry_run.sql` confere isso: 0 diferenças.
- Totais do Dashboard (valor a custo/venda) recalculados com o estoque real.
- Conferência visual nas duas telas no ar (ex.: peça 13587 com disponível 17).

## Realizado

### 2026-11-11

- Diagnóstico e conferência do código (`compras-lucenera-3o23t98ee`: `services/estoque-produtos.ts` → `vw_estoque_produtos`; `pages/PedidoAvulso.tsx` mostra `estoque_total`/`estoque_disponivel`; bundle no ar `PedidoAvulso-B7mEgJYI.js` confirmado) e do Dashboard (`services/estoque.ts` → `v_estoque_produtos`).
- Migration 337 escrita. **Ensaio no Supabase SP** (as duas views recriadas dentro de um bloco que termina em erro proposital, então tudo é desfeito):
  - Dashboard: 4.571 linhas, 0 diferenças de estoque e de disponível.
  - Compras: 4.571 linhas, 0 diferenças.
  - Exemplos: 12135 = 123 / −31; 12395 = 598 / 17; 13587 = 289 / 17; 8952 = 858 / 63.
  - `vw_estoque_produtos` mantém `security_invoker=true`.
  - Conferido depois: as views no banco continuam as antigas (12135 = 155 / 0). **Não aplicada.**

### 2026-11-11 (noite) — aplicada

- Migration 337 **APLICADA** no Supabase SP (`apply_migration`, registrada em `supabase_migrations.schema_migrations`), com autorização do Filippo.
- Conferido depois:
  - Dashboard: 4.571 linhas, 0 diferenças com `estoque_itens`; valor a custo do estoque R$ 4.249.279, dos quais R$ 1.475.695 disponíveis.
  - Compras: 4.571 linhas, 0 diferenças.
  - 13587 = 289 / 17; 12135 = 123 / −31.
  - `security_invoker=true` mantido.
- A Parte B (gatilho antigo) segue pendente de decisão.
