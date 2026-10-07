---
titulo: "SPEC-157 — Reconciliação/espelho nos imports Connect (ContaPagar/ContaReceber, Produtos, PedidoCompra)"
status: pendente
data_ultima_modificacao: 2026-09-22
sistemas_envolvidos:
  - scripts (importação Connect)
  - Financeiro (transacoes/negociacoes)
  - Estoque/Compras (produtos, pedido_compra)
---

# SPEC-157 — Reconciliação/espelho nos imports Connect

> `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.

## Checklist de Ação

- [x] Biblioteca compartilhada `scripts/sync_connect_common.py` (descoberta de arquivo mais recente, pré-validações obrigatórias, relatório estruturado + log em arquivo).
- [x] `importar_contas_pagar_receber.py`: pré-validações (cabeçalho, mínimo de linhas, unicidade de `cod_itens_duplicata` por planilha) abortando sem tocar o banco; fase de gravação movida para uma única transação `psycopg2` com `INSERT ... ON CONFLICT` nas chaves já únicas no banco (`uq_negociacoes_empresa_cod_dup_tipo`, `uq_transacoes_connect`).
- [x] `importar_produtos_estoque.py`: pré-validações; soft delete (`produtos.ativo=false`) para `codigo_produto` que saiu do export; reativação (`ativo=true`) para produto que volta a aparecer. Mantém os 2 triggers de preço desligados durante toda a transação (comportamento pré-existente).
- [x] `importar_produtos_novos.py`: pré-validações; insert vira `ON CONFLICT (codigo_produto) DO NOTHING`.
- [x] `importar_pedido_compra.py`: pré-validações (chave `(codigo_pedido, num_parc)`, `num_parc` vazio normalizado para 1); nova coluna `pedido_compra.vigente` (nunca DELETE); `staging_pedido_compra` recebe `UNIQUE(codigo_pedido, num_parc)`.
- [x] Migration `20260922_159_sync_connect_reconciliacao` (aplicada no Supabase real em 2026-10-07).
- [x] Atualizar `scripts/AGENTS.md` com os novos invariantes.
- [x] `CHANGELOG.md` atualizado.
- [x] Testado em `--dry-run` contra o Supabase real (os 4 scripts, 2026-09-22) — nenhuma gravação real.

### Passos manuais do usuário

- [x] (2026-10-07) Aplicar a migration `20260922_159_sync_connect_reconciliacao` no Supabase real (ela é só aditiva: 1 coluna nova com default e 1 constraint nova; não deveria dar conflito, mas roda como qualquer outra migration deste repo — revisão antes de aplicar).
- [ ] Rodar cada script com `--dry-run` após a próxima exportação e comparar o resumo com o Dashboard antes de gravar.

## Objetivo

Os 4 scripts de import Connect (`ContaPagar`/`ContaReceber`, `Produtos`, `PedidoCompra`) já espelhavam a planilha de forma ad-hoc, cada um com sua lógica própria (documentada em `scripts/AGENTS.md`). Faltava: (1) pré-validação formal que aborta a importação inteira sem tocar no banco quando a planilha vem vazia/truncada/com chave duplicada; (2) soft delete de produtos que saíram do estoque (nunca existia — o script só atualizava produto já cadastrado); (3) marcação de "não vigente" para pedidos de compra que saíram do export (nunca existia); (4) relatório estruturado por execução, com log em arquivo, para revisão do gestor; (5) descoberta automática do arquivo mais recente (antes era preciso editar uma constante de caminho a cada exportação nova).

## Decisões aprovadas

Confirmadas com o usuário em 2026-09-22 (via pergunta direta, antes de qualquer implementação — ver motivo em `feedback_confirmar_sistema_novo_vs_modulo_com_usuario` na memória):

- **Contas a pagar/receber**: "ausente na planilha" continua sendo **CANCELADO** (`status_pago=2`), não DELETE físico. Motivo: `retorno_bancario_registros.transacao_id` referencia `transacoes(id)` sem `ON DELETE CASCADE` (um DELETE físico falharia nessas linhas), e apagar destruiria o histórico de conciliação bancária. Esse comportamento já existia e está documentado em `scripts/AGENTS.md` como invariante que "não pode ser removida" — esta SPEC só formaliza as pré-validações em volta dele, não muda a semântica de remoção.
- **Pedido de compra**: a tabela `pedido_compra` continua **1 linha por `codigo_pedido`** (decisão de 2026-07-22, documentada no próprio script) — não foi redesenhada para granularidade por parcela. A chave composta `(codigo_pedido, num_parc)` pedida na especificação original é aplicada como `UNIQUE` em `staging_pedido_compra` (que já guarda 1 linha por parcela), e o header (`pedido_compra`) ganha uma coluna `vigente` (nunca DELETE) em vez de virar uma tabela por parcela.
- **Produtos**: espelho com soft delete via `produtos.ativo` (coluna que já existia, só não era usada pelo import) — sem mudança de schema.

## Definição da SPEC

### Estado atual → depois

| Módulo | Antes | Depois |
|---|---|---|
| ContaPagar/ContaReceber | Sem pré-validação formal; gravação via múltiplas chamadas REST (supabase-py) em sequência, sem transação única | Pré-validação (cabeçalho/mínimo/unicidade) aborta sem tocar o banco; gravação em transação única `psycopg2` com `ON CONFLICT` nas 2 unique keys já existentes |
| Produtos (estoque) | Só `UPDATE` de produto existente; produto que sai do estoque fica com dado desatualizado para sempre | Idem + soft delete (`ativo=false`) / reativação (`ativo=true`), na mesma transação que já desliga os triggers de preço |
| Produtos (novos) | `INSERT` simples | `INSERT ... ON CONFLICT (codigo_produto) DO NOTHING` (idempotente de verdade) |
| Pedido de compra | Upsert por `codigo_pedido`; pedido que sai do export fica órfão sem sinalização | Idem + coluna `vigente` (nunca DELETE); `staging_pedido_compra` ganha `UNIQUE(codigo_pedido, num_parc)`, `num_parc` normalizado para 1 quando vazio |
| Todos | Caminho do arquivo hardcoded (editar constante a cada exportação) | Descoberta automática do arquivo `<Prefixo>_*.xlsx` mais recente na pasta |
| Todos | Sem relatório estruturado | `RelatorioModulo` (inseridos/atualizados/removidos ou inativados/cancelados/ignorados/erros) + log JSON em `scripts/logs/sync_connect/` |

### Migration (rascunho, não aplicada)

`supabase/db/migrations/20260922_159_sync_connect_reconciliacao/`:
- `001_pedido_compra_vigente.sql` — `ALTER TABLE pedido_compra ADD COLUMN vigente boolean NOT NULL DEFAULT true`.
- `002_staging_pedido_compra_unique.sql` — normaliza `num_parc` nulo para 1 nas linhas já existentes e cria `UNIQUE(codigo_pedido, num_parc)`.

### Pré-validações (mínimos por módulo, piso de segurança — não expectativa de volume)

| Módulo | Mínimo de linhas | Chave natural validada |
|---|---|---|
| ContaReceber | > 500 | `cod_itens_duplicata` |
| ContaPagar | > 1.000 | `cod_itens_duplicata` |
| Produtos | > 500 | `codigo_produto` |
| PedidoCompra | > 10 | `(codigo_pedido, num_parc)` |

## Pendências

- [ ] Atualizar `scripts/AGENTS.md` com os invariantes novos (soft delete produtos, vigente pedido_compra, pré-validações) — depende desta SPEC estar com o código já revisado.
- [x] (2026-10-07, aplicada; 1º run marcou 155 pedidos como não vigentes) Migration `20260922_159` precisava ser aplicada manualmente no Supabase real antes do próximo run de `importar_pedido_compra.py` (sem a coluna `vigente` o script quebra).
- [ ] Nenhum teste ao vivo contra o Supabase real foi executado nesta sessão (só leitura de schema) — primeira execução real deve ser `--dry-run` em todos os 4 scripts.
