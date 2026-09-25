---
titulo: "SPEC-164 — PDF de orçamento aprovado sai com o número da venda"
status: "CONCLUÍDA e PUBLICADA (25/09/2026) — Edge Function generate-report v99 no Supabase; Orçamentos
  (Skip 32554) publicado 8594ad5; submodule 95f136c."
data_ultima_modificacao: 2026-09-25
sistemas_envolvidos:
  - Orçamentos (`gestao-financeira-clone-544cb (1)`, Skip 32554) — Edge Function `generate-report` + `BudgetTableRow.tsx`
relacionado: [SPEC-136 (numero_venda), SPEC-152, SPEC-158]
---

## Pedido (usuário, 25/09/2026)

> "quando o orçamento for aprovado e eu exportar ele na aba de orçamento aprovado, ele deve vir com o número da
> venda e não com o número do orçamento, porque ele já foi aprovado. [...] no canto superior direito deveria ter
> o número da venda, que é atualmente no sistema que a gente tem da Connect, ele faz desse jeito."

## Solução

- `generate-report` (PDF do orçamento): se `orcamentos.numero_venda` existe (gerado na aprovação financeira,
  SPEC-136), o bloco do canto superior direito mostra rótulo **"Venda"** + `numero_venda` (ex.: VENDA-0002) em
  vez de "Orçamento" + `numero`. Orçamento não aprovado e revenda Ubiqua (sem `numero_venda`) não mudam.
- `BudgetTableRow.tsx`: arquivo baixado vira `Venda_VENDA-0002.pdf` quando há `numero_venda`.
- Sem mudança de banco.

## Verificação

PDF gerado de verdade pela função publicada (usuário temporário criado e apagado): ORC-0034 → "Venda
VENDA-0002"; ORC-0010 (não aprovado) → "Orçamento ORC-0010".

## Achados

1. **A função publicada estava desatualizada**: a v98 (antes desta SPEC) NÃO tinha a tabela de parcelas com
   vencimento (SPEC-152 item 7) nem o "Digitador" (SPEC-158 P2.3), apesar de o código estar no Skip. A v99
   (esta SPEC) publicou tudo junto — o PDF passa a sair também com parcelas e digitador.
2. **Etapa "integrations" do Skip 32554 falha** ao publicar qualquer mudança em `supabase/`: ela revalida as
   migrations legadas da pasta `supabase/migrations` do próprio sistema (3 falham: `20260625113000`,
   `20260704160000`, `20260707150000`). Conferido: nenhuma foi aplicada de fato (histórico
   `supabase_migrations.schema_migrations` inalterado, `aprovar_orcamento_financeiro`/`replace_orcamento_itens`
   seguem nas versões atuais, dados do ORC-0034 intactos). A Edge Function foi publicada mesmo assim.
   Pendência: limpar/arquivar essas migrations legadas do Skip (a fonte oficial do banco é
   `supabase/db/migrations/` no repo central).
