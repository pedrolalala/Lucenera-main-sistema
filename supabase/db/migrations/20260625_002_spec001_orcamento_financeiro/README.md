# Migration group 20260625_002 — SPEC-001 Orçamento -> Administração Bancária

Objetivo: centralizar a mudança que faz orçamento aprovado gerar itens de projeto e pendências financeiras usando `orcamento_id`.

## Já aplicado nos sistemas

As migrations funcionais foram aplicadas pelo usuário no Supabase.

Referências de origem:

- `Sistema/gestao-financeira-clone-544cb (1)/supabase/migrations/20260625110000_aprovacao_orcamento_financeiro.sql`
- `Sistema/gestao-financeira-clone-544cb (1)/supabase/migrations/20260625113000_spec001_refinamentos_financeiro.sql`
- `Sistema/retorno-bancario-bradesco-5392a/supabase/migrations/20260625110100_spec001_orcamento_id_financeiro.sql`
- `Sistema/retorno-bancario-bradesco-5392a/supabase/migrations/20260625113000_spec001_refinamentos_financeiro.sql`

## Decisões consolidadas

- Usar `orcamento_id` como vínculo principal.
- Não usar `venda_id`.
- Financeiro mostra orçamento, projeto e cliente por relacionamento.
- `projeto_id` fica onde pertence ao projeto; não deve ser dependência principal do financeiro.
- Nota fiscal fica pendente de API/ferramenta futura.
- Uploads de boleto/NF devem futuramente migrar para OneDrive/SharePoint.

## Ação a ser realizada

Promover o SQL aprovado para os arquivos centrais deste grupo, removendo duplicações entre sistemas e deixando uma versão canônica.

