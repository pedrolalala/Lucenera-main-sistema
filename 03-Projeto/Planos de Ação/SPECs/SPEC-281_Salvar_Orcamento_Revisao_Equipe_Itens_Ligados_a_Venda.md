---
titulo: "SPEC-281 — Salvar orçamento em Revisão da Equipe quando os itens já estão ligados à venda"
status: pendente
data_ultima_modificacao: 2026-11-11
sistemas_envolvidos:
  - Orçamentos (gestao-financeira)
  - Banco (Supabase)
---

# SPEC-281 — Salvar orçamento em Revisão da Equipe quando os itens já estão ligados à venda

## Checklist de Ação

- [x] Redigir migration 332 (`replace_orcamento_itens` atualiza no lugar em vez de apagar e recriar)
- [x] Dry-run da migration 332 em ROLLBACK (inclui os 3 ensaios do `dry_run.sql`)
- [x] Aplicar migration 332 em SP (com autorização do usuário)
- [x] Total certo confirmado: R$ 12.650,26 (venda = 2 peças); LUC91 é peça nova em cotação, fora da venda
- [ ] Descobrir por que o LUC91 aparece na edição do CNX-5154
- [ ] Atualizar `supabase/db/current/03_functions.sql` (snapshot) e CHANGELOG depois de aplicar

### Passos manuais do usuário

- [x] Autorizar a aplicação da migration 332 em SP
- [ ] Testar: abrir CNX-5154 em Aprovação da Equipe, ajustar forma de pagamento e salvar

## Objetivo

Hoje, ao salvar um orçamento que já tem venda (ex.: CNX-5154 → venda CNX-6007), o banco recusa com
`update or delete on table "orcamento_itens" violates foreign key constraint "projeto_itens_orcamento_item_id_fkey"` e **nada é gravado**. O objetivo é permitir salvar (forma de pagamento, desconto etc.) sem quebrar os vínculos, e dar mensagem clara quando o usuário tenta remover um item que já está na venda.

## Causa (confirmada pelo código; dados do CNX-5154 NÃO conferidos no banco)

- O formulário reenvia **todos** os itens em qualquer salvamento (`useBudgetStore.updateBudget` → RPC `replace_orcamento_itens`).
- A função só não mexe na tabela quando o conjunto enviado é **idêntico** ao salvo (SPEC-135). Se o usuário apagou um item na tela, o conjunto difere e a função faz `DELETE` de todos os itens + `INSERT`.
- O `DELETE` bate nos itens ligados a `projeto_itens.orcamento_item_id` (e `notas_fiscais_itens.orcamento_item_id`), que têm FK sem `ON DELETE` → erro, transação desfeita.
- A trava `trg_0_proteger_vinculo_connect` (SPEC-195) só barra orçamento com `vinculo_connect` **e** status "Orçamento Aprovado"; o CNX-5154 está em Revisão da Equipe, então passa por ela e cai na FK.

## Mudança proposta

Migration `20261111_332_spec281_replace_orcamento_itens_preserva_vinculos`:

- Mesma assinatura, mesma regra de permissão (não-admin não altera valor/produto) e mesma regra "conjunto idêntico = não mexe".
- Parear itens antigos × novos por (produto, descrição, preço, n-ésima ocorrência):
  - pareados → `UPDATE` no lugar (mantém o `id` e os vínculos com venda/nota);
  - só novos → `INSERT`;
  - só antigos (removidos pelo usuário) → `DELETE`, **exceto** se tiverem venda/nota ligada: `RAISE EXCEPTION` com mensagem em português e nenhuma alteração fica gravada.
- Rollback: restaura a função da migration 238.

## Fato confirmado pelo usuário (11/11)

A venda CNX-6007 é só de **2 peças**: 13795 LUC89-AL (68 × 165 = 11.220,00) e 10172 STH8536/30 (68 × 37,21 = 2.530,28). Subtotal 13.750,28 − desconto global 1.100,02 = **R$ 12.650,26**, que é o total correto.

O terceiro item ("LUC91 – SPOT GERRY COM ARTICULACAO", sem código, R$ 12.518,80) é uma **peça nova em cotação** (a Débora cadastra depois) e **não pertence à venda 6007**. O usuário o removeu do rascunho. Com ele a tela mostra R$ 25.169,06; sem ele volta a R$ 12.650,26.

Consequência para o erro: o item removido não está ligado à venda. Quem está ligado a `projeto_itens` são os 2 itens da venda, que o `DELETE` em massa tenta apagar junto. Com a migration 332 os 2 itens da venda são só atualizados no lugar e o item removido é apagado normalmente, então o salvamento deve funcionar. (Ainda não confirmado no banco.)

Fica em aberto de onde o item LUC91 entra no orçamento ao abrir a edição (se já está gravado em `orcamento_itens` ou se a tela o adiciona), porque o usuário precisou removê-lo à mão.

## Impacto no ecossistema

- Depende de `orcamentos`, `orcamento_itens`, `projeto_itens`, `notas_fiscais_itens`; não toca financeiro, boletos nem estoque.
- Afeta só a tela de edição de Orçamentos; Cadastro/Compras/Logística não mudam.
- Triggers de `orcamento_itens` (auditoria, proteção Connect, reset de aprovação) passam a disparar `UPDATE` em vez de `DELETE+INSERT` nos itens que continuam. A auditoria registra a atualização; o reset de aprovação do cliente (SPEC-111) deve ser conferido no dry-run, pois mudança real de item continua precisando resetar.
- `AI_DB_CONTEXT.md` do sistema: atualizar só se a decisão B for escolhida.

## Critérios de aceite

- Salvar o CNX-5154 com os 2 itens da venda, sem o LUC91, e com a forma de pagamento ajustada: salva sem erro, itens e vínculos intactos, total R$ 12.650,26.
- Tentar remover o item ligado à venda: mensagem clara, nada gravado.
- Orçamento rascunho sem venda: adicionar, remover e editar item funciona e os demais itens mantêm o `id`.
- `anon` sem execução; usuário não-admin continua sem poder alterar valor/produto.

## Testes obrigatórios

- Dry-run (`dry_run.sql`) em ROLLBACK no banco SP, incluindo os 3 ensaios descritos no arquivo.
- Conferir se o `UPDATE` dispara o reset de aprovação só quando algo mudou de fato.
- Testar como usuário de equipe e como admin.

## Realizado

### 2026-11-11

- Diagnóstico pelo código e redação da migration 332 (`up.sql`, `rollback.sql`, `dry_run.sql`). **Não aplicada.** Banco não consultado (conexão direta do `.env` não resolve o host; usar session pooler).

### 2026-11-11 (correção do dado)

- Conferido em SP: CNX-5154 em Aprovação da Equipe, valor_total 12.650,26; 3 itens em `orcamento_itens`; os 2 da venda ligados a `projeto_itens`, o LUC91 (sem produto, 68 × 184,10, gravado em 05/11) sem vínculo.
- Removido só o LUC91 de `orcamento_itens` (autorizado pelo usuário), em transação com conferência: status, total e desconto idênticos antes/depois, 2 itens restantes, 2 `projeto_itens` intactos. Cópia do item em `backup._bkp_spec281_orcamento_itens_cnx5154`.
- Migration 332 APLICADA em SP (autorizada pelo usuário) após ensaio em ROLLBACK: itens idênticos = no-op; remover item ligado = erro claro; adicionar/remover item novo mantém os ids; `anon` sem execução.

## Pendências

- [ ] Rodar o dry-run da migration 332 em ROLLBACK e aplicar em SP com autorização do usuário.
- [ ] Descobrir se o LUC91 já está gravado em `orcamento_itens` do CNX-5154 ou se a tela o adiciona ao abrir (precisa de acesso ao banco); se for a tela, corrigir para não reinserir.
- [ ] Atualizar snapshot `supabase/db/current/03_functions.sql` e `CHANGELOG.md` após aplicar.
