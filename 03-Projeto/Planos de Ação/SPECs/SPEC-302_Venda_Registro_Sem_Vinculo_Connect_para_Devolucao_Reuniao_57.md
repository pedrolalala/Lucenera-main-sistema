---
titulo: "SPEC-302 — Tipo de devolução 'TROCA DEV SEM VINCULO CONNECT' (peça entregue antes da virada) — reunião 57 com o Vinicius"
status: migration 359 e código prontos e ensaiados; NADA aplicado/publicado — aguardando autorização
data_ultima_modificacao: 2026-11-13
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone)
  - Banco (Supabase) — aprovar_orcamento_financeiro, orcamento_itens
substitui: SPEC-300 (banner/linha com origem Connect). A migration 357 já está aplicada, sem nenhuma linha usando; fica dormente.
---

# SPEC-302 — Tipo de devolução "TROCA DEV SEM VINCULO CONNECT"

## Decisão (reunião 57, 13/11/2026, Vinicius) e respostas do usuário

Para peça **entregue antes da importação (virada do dia 5)**, que não existe como item de venda no sistema, cria-se um **tipo novo de devolução**: `TROCA DEV SEM VINCULO CONNECT` (natureza `devolucao`, ao lado de `TROCA DEV` e `CASA COR ENTRADA`).

- **Não se cria nenhum orçamento/venda de registro.** Só a devolução. (A ideia da "venda fake" da conversa foi descartada pelo usuário.)
- O XML da devolução importa como hoje; as linhas ficam **sem item de origem**.
- **Ao efetivar a devolução:** gera o **valor negativo** (crédito/parcela negativa) como em qualquer devolução e a **peça volta ao Estoque Geral** (confirmado pelo usuário).
- Devolução com peça entregue **e** peça em reserva = **duas devoluções**: a de reserva é uma `TROCA DEV` normal; a entregue-antes-da-virada é deste tipo novo. Não se mistura numa só.
- A usuária sempre sabe quais peças foram entregues antes da virada.

## Regras

- R1. O tipo vale só para `natureza_operacao = 'devolucao'`; exige projeto e empresa (como toda devolução).
- R2. Todas as linhas do tipo novo: produto do cadastro (`produto_id`), quantidade > 0, preço > 0, **sem** `projeto_item_origem_id`. Se alguma linha trouxer origem, a aprovação recusa (mistura proibida).
- R3. **Venda de registro automática (decisão do usuário 13/11):** na efetivação, o sistema cria sozinho uma venda (`origem='connect'`, natureza venda, número `REG-<nº da devolução>`, cliente/projeto/empresa da devolução), **já Aprovada**, com as peças como **entregues** no projeto (`projeto_itens` + saldo `q_entregue`). Sem reserva, sem parcela/boleto/NF, sem baixa de estoque. As linhas da devolução só **vinculam** nela (`projeto_item_origem_id`, setor `entregue`) e rodam o caminho normal: a peça volta ao Estoque Geral e a devolução aparece na Venda Parcial ligada a essa venda. O usuário não cria venda nenhuma.
- R4. Crédito/parcelas/boletos saem normais. Limite conhecido: sem item de origem o título de crédito não é compensado contra o título da venda original (ex.: CNX-2451); fica como crédito de devolução do projeto.
- R5. Devolução comum (qualquer outro tipo) continua exatamente igual: item sem origem segue barrado.
- R6. Desfazer aprovação de devolução já não é suportado, então não há reversão de estoque a tratar.

## Checklist de Ação

- [x] A0 — Usuário confirmou: sem orçamento extra, peça volta ao estoque, valor negativo na efetivação.
- [x] A1 — Migration 359 (up + rollback) — escrita e ensaiada com ROLLBACK: `aprovar_orcamento_financeiro` aceita o tipo novo sem origem e devolve ao Estoque Geral.
- [x] B1 — Orçamentos (código local, tsc ok, não publicado): opção do tipo na lista de Devolução, texto da regra, zod/validação sem origem para o tipo, esconder o banner Connect da SPEC-300.
- [x] C1 — Ensaio com ROLLBACK (13/11, rascunho ORC-0067 como base, 6 linhas das 5 peças): Estoque Geral subiu 8→9, 172→173, 111→112, 269→273, 339→340; reservado igual; parcela −1.343,89; 5 movimentações; tipo comum continua barrado; rollback.sql devolveu a função idêntica. (ORC-0064 do caso real já não existe.)
- [x] C1b — Ensaio v2 (venda de registro automática): registro REG-ORC-0067 Aprovado, 6 peças, 0 parcelas; 6 linhas vinculadas no setor entregue; Estoque Geral +1/+1/+1/+4/+1, reservado igual; parcela −1.343,89; rollback.sql devolve a função idêntica.
- [ ] C2 — `AI_DB_CONTEXT.md` do sistema; auditar telas/relatórios que listam vendas `origem='connect'` (faturamento/Venda Parcial) para confirmar que o registro se comporta como a herança.
- [ ] Passo manual: autorizar aplicar a 359 e publicar Orçamentos; decidir se reverte a 357 (sem uso).
