---
titulo: "SPEC-224 — Sistema novo \"Movimentação de Peças\": mudar a peça de setor (físico e de venda) com registro de quem, quando, de onde, para onde e por quê"
status: pendente (decisões principais tomadas em 23/10; falta OK para implementar)
data_ultima_modificacao: 2026-10-23
sistemas_envolvidos:
  - Sistema NOVO "Movimentação de Peças" (React + Supabase SP, Cloudflare Pages, registrado no Hub)
  - Banco (Supabase SP) — estoque_itens, produtos.estoque_showroom, estoque_saldos_projeto_item, tabela nova de movimentos
  - Cadastro (cadastro-lucenera-b86fe) — Setores da peça já leem estoque_itens + estoque_showroom (muda sozinho)
  - Showroom (showroom-qtq8er2dk) — vitrine lê produtos.estoque_showroom (muda sozinho)
  - scripts/importar_produtos_estoque.py — a Connect para de gravar o Showroom
---

# SPEC-224 — Sistema "Movimentação de Peças" (troca de setor com registro)

> Origem: pedido do usuário (23/10/2026), a partir da SPEC-223 (setor empréstimo):
> "a gente vai precisar fazer um sistema, mais um, que nada mais nada menos mexe no setor daquela peça em específico
> [...] uma peça que tá no estoque, ela tá vindo para o showroom, ou vice-versa, ou até mesmo uma peça que tá em
> entrega futura, mas por algum motivo ela teve que voltar [...] fique registrado qualquer tipo de movimentação com
> login da pessoa que fez [...] quem fez, para onde foi e como, quando foi. Porque hoje em dia a gente não tem isso."
> Já citada como pendência na SPEC-220 (E2), SPEC-221 e SPEC-223.

## Decisões do usuário (23/10)

1. **Sistema novo** (não é aba de outro sistema) — pedido explícito: "fazer um sistema, mais um".
2. **Movimentos:** setores **físicos** e também os de **venda** (reserva / entrega futura / separação de um L).
3. **Sem aprovação:** quem tem acesso move na hora; fica o registro (quem, quando, peça, quantidade, de onde, para onde,
   motivo obrigatório).
4. **Showroom:** o sistema passa a mandar no número do Showroom (`produtos.estoque_showroom`); a importação da Connect
   **para de gravar o Showroom** (como já foi feito com o estoque na SPEC-222).

## Como está hoje (conferido no banco em 23/10)

- **Setores físicos** = `estoque_itens` por `local` (enum `estoque_local`: Estoque, Showroom, Em trânsito, Estoque
  Geral, Estoque Luce Nera/Islight/Foco, Estoque Garantia, Estoque Casa Cor, Estoque Defeito, Amostra / Emprestado,
  Estoque Citel, …). **Na prática só existe `Estoque`** (4.918 peças, 32.937 un.) e linhas `Showroom` zeradas (337).
- **Showroom** vive em `produtos.estoque_showroom` (302 peças com saldo), vindo da Connect. A linha `Showroom` de
  `estoque_itens` é zerada pelo trigger `fn_sync_estoque_itens_from_produtos`.
- **Setores de venda** (por L) = `estoque_saldos_projeto_item` (q_reserva, q_entrega_futura, q_ag_separar, q_separado,
  q_entregue). Já existem: `re_reservar_projeto_item` (entrega futura → reserva, se houver físico livre),
  `estornar_item_separacao` (separação → reserva), troca de reserva entre L (`trocar_reserva_projetista`, SPEC-098/222),
  devolução de entregue pelo orçamento (SPEC-178/181).
- **Registro:** não existe tabela de movimentação interna de peça. `auditoria.eventos` (SPEC-206) guarda a mudança de
  linha, mas não "de onde → para onde e por quê".
- **Risco técnico:** `produtos` tem o trigger `trg_calculo_preco_venda` **sem filtro de coluna** — qualquer UPDATE
  (inclusive só `estoque_showroom`) recalcula `preco_venda` (incidente de 10/09). Precisa ser corrigido antes de o
  sistema mexer em `produtos`.

## Definição

### Banco (migration nova)
- Tabela `public.movimentacoes_peca` (RLS ligado, `REVOKE ALL FROM anon`, leitura só por RPC):
  `numero` (MOV-000001), `produto_id`, `quantidade`, `tipo` (`setor` | `venda`), `origem` e `destino` (texto do setor:
  Estoque Geral, Showroom, Estoque Garantia, Estoque Casa Cor, Estoque Defeito, Amostra / Emprestado, Reserva,
  Entrega Futura, Separação, Livre), `projeto_item_id` (quando é de venda), `motivo` (obrigatório), `criado_por`,
  `criado_em`, saldos antes/depois da origem e do destino (para conferir depois). Trigger de auditoria (SPEC-206).
- RPC `movimentar_peca_setor(p_produto_id, p_origem, p_destino, p_quantidade, p_motivo)`:
  - Estoque Geral = `estoque_itens` local `Estoque`; Showroom = `produtos.estoque_showroom`; demais = `estoque_itens`
    do local (cria a linha se não existir);
  - não deixa a origem ficar negativa; Estoque Geral não pode ficar abaixo do que está **reservado em peça física**
    (para não "roubar" peça de cliente — mensagem clara: "x peças estão reservadas para vendas");
  - grava o movimento na mesma transação.
- RPC `movimentar_peca_venda(p_projeto_item_id, p_acao, p_quantidade, p_motivo)` com as ações:
  - **Reserva → Entrega Futura** ("liberar a peça": a peça física fica livre no Estoque Geral e a necessidade de compra
    do L volta);
  - **Entrega Futura → Reserva** (usa a regra do `re_reservar_projeto_item`: só se houver físico livre);
  - **Separação → Reserva** (estorno da separação — usa a regra do `estornar_item_separacao`);
  - devolução de peça **entregue** continua pelo orçamento de devolução (fora deste sistema).
- RPCs de leitura: `movimentacoes_peca_listar(filtros)` (peça, pessoa, setor, período, tipo) e `peca_setores(produto_id)`
  (quantidade em cada setor + os L de venda da peça).
- Permissão: `hub_pode_executar(auth.uid(), 'movimentacao-pecas', NULL, 'editar')` para mover; `NULL` para ver.
- **Correção do trigger de preço:** `trg_calculo_preco_venda` só recalcula no INSERT ou quando muda campo de custo
  (igual ao `trg_atualizar_preco_venda`).

### Script
- `importar_produtos_estoque.py`: `estoque_showroom` também só com `--incluir-estoque` (hoje grava sempre).

### Sistema novo (React, mesmo modelo dos outros: login Supabase, SystemSwitcher, `registro-tela.ts` no `main.tsx`)
- **Movimentar:** busca a peça (código, referência, nome) → quadro com a quantidade em cada setor e os L de venda →
  escolhe origem, destino, quantidade e motivo → confirma. Atalhos: "Estoque → Showroom", "Showroom → Estoque".
- **Histórico:** lista de movimentos com filtros (peça, pessoa, setor, período, tipo) e exportação em Excel/PDF.
- Registrar no Hub (`systems`, slug `movimentacao-pecas`), Cloudflare Pages `movimentacao-lucenera.pages.dev`, repositório
  GitHub próprio como submodule em `04-Sistemas/`.

### Outros sistemas
- Cadastro: os Setores já leem `estoque_itens` + `estoque_showroom` — passam a mostrar o que for movido. Botão
  "Ver movimentações" na peça (link para o histórico filtrado) — opcional.
- SPEC-223 (empréstimo) usa o mesmo registro quando a peça vai para "Amostra / Emprestado".

## Checklist de Ação
- [ ] A1. Migration: tabela `movimentacoes_peca` + RLS + auditoria; RPCs de setor, de venda, de leitura; correção do
      trigger de preço; dry-run em ROLLBACK + rollback.sql
- [ ] A2. Script: Showroom fora da importação padrão da Connect
- [ ] B1. Sistema novo: repositório, projeto React (template de um sistema existente), login, SystemSwitcher,
      registro-tela
- [ ] B2. Tela Movimentar (peça → setores → origem/destino/qtd/motivo)
- [ ] B3. Tela Histórico (filtros + exportar)
- [ ] B4. Cloudflare Pages + registro no Hub (`systems`) + acessos por usuário
- [ ] C1. Docs: AI_DB_CONTEXT do sistema, `supabase/docs/relationships.md`, CHANGELOG

### Passos manuais do usuário
- [ ] Criar o projeto no Cloudflare Pages ligado ao repositório novo (se a IA não conseguir pelo `wrangler`)
- [ ] Liberar o sistema no Hub para quem vai usar
- [ ] Testar: mover 1 peça Estoque → Showroom e conferir Setores no Cadastro e a vitrine

## Pontos para confirmar (com recomendação)
1. **Nome do sistema:** "Movimentação de Peças" (recomendado) ou outro.
2. **Setores físicos liberados:** Estoque Geral, Showroom, Estoque Garantia, Estoque Casa Cor, Estoque Defeito, Amostra /
   Emprestado (recomendado). Os por empresa (Luce Nera/Islight/Foco), Citel e Em trânsito ficam de fora até alguém usar.
3. **Estoque Geral abaixo do reservado:** bloquear (recomendado) ou só avisar.
4. **Quem acessa:** liberado no Hub por pessoa (recomendado: Vinicius, Débora, Mateus e o pessoal do showroom).

## Rollback
- Migration: `rollback.sql` (remove tabela/RPCs, volta o trigger de preço). Os saldos movidos não voltam sozinhos —
  usar o histórico (`movimentacoes_peca`) para desfazer movimento a movimento.
- Sistema: tirar do Hub (`systems`) e desligar o projeto no Cloudflare.

## Realizado

(vazio)
