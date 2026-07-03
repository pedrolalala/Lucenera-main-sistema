# Migration 20260630_010 — Reserva de Estoque na Aprovação do Orçamento

## Problema resolvido

Ao aprovar um orçamento, os `projeto_itens` eram criados mas o estoque não era
reservado. O trigger legado `trg_reserva_estoque` em `projetos` reservava no
evento errado (`status → 'Proposta Sinal'`) e sem rastreabilidade por orçamento.

## O que esta migration faz

### Arquivo 001 — Remove trigger legado

Remove `trg_reserva_estoque` (trigger em `projetos`) e sua função
`trigger_reserva_estoque()`. Esse trigger disparava no evento errado (mudança
de status do projeto, não aprovação do orçamento) e seria conflitante com a
nova lógica.

### Arquivo 002 — Reserva dentro da aprovação

Atualiza `aprovar_orcamento_financeiro_base_spec001` adicionando o passo 8:
após inserir `projeto_itens`, para cada item com `produto_id` preenchido,
incrementa `estoque_itens.quantidade_reservada` na linha `(produto_id, 'Estoque')`.

## Regras de negócio aplicadas

- **Quantidade reservada = quantidade aprovada no orçamento.** Determinada uma
  única vez, na aprovação.
- **Boletos não alteram a reserva.** Um orçamento com 3 parcelas gera 3 boletos,
  mas a reserva é feita uma única vez. Pagar ou não pagar um boleto não muda
  `quantidade_reservada`.
- **Estoque negativo é permitido.** Se `quantidade_reservada` superar `quantidade`
  física, o saldo disponível fica negativo — representa venda futura/necessidade
  de compra (SPEC-EST-07).
- **Itens sem `produto_id` (descrições livres) são ignorados** na reserva.
- **Idempotência preservada.** A função já detecta processamento anterior
  (`ja_processado: true`) e retorna cedo sem duplicar itens, parcelas, boletos
  ou reservas.

## Tabelas afetadas

| Tabela | Operação |
|---|---|
| `estoque_itens` | UPSERT: incrementa `quantidade_reservada` |
| `projeto_itens` | sem mudança de estrutura |
| `projeto_parcelas` | sem mudança |
| `boletos` | sem mudança |
| `projetos` | trigger removido (nenhuma escrita nova) |

## Como aplicar

```sql
-- Executar no banco remoto (vcvcwzmbiftcawncibke) como role postgres:
\i 001_remove_trigger_legado_projetos.sql
\i 002_reserva_na_aprovacao.sql
```

Ou via Supabase SQL Editor, um arquivo por vez, na ordem numérica.

## Como verificar após aplicar

```sql
-- 1. Confirmar que o trigger foi removido
SELECT trigger_name FROM information_schema.triggers
WHERE event_object_table = 'projetos' AND trigger_name = 'trg_reserva_estoque';
-- Deve retornar 0 linhas.

-- 2. Aprovar um orçamento de teste (em transação segura):
BEGIN;
SELECT public.aprovar_orcamento_financeiro('<uuid-do-orcamento>');
-- Verificar resultado: deve conter "reservas_estoque_aplicadas" > 0
SELECT produto_id, quantidade_reservada FROM estoque_itens
WHERE produto_id IN (SELECT produto_id FROM orcamento_itens WHERE orcamento_id = '<uuid>');
ROLLBACK; -- não confirmar em teste

-- 3. Confirmar que segunda chamada retorna ja_processado: true sem alterar reserva
```

## Pendência futura (não bloqueante)

Criar tabela `estoque_reservas` (SPEC-EST-06) para rastreabilidade por projeto/cliente.
Hoje `quantidade_reservada` é um contador total; não é possível saber quais
projetos compõem esse total sem recalcular por `projeto_itens`.
