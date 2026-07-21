-- Migration 20260723_057 - SPEC-040 - Item 1/4
--
-- Pré-requisito estrutural do Fluxo B ("Por Item de Orçamento") da tela
-- Necessidade de Compra. projeto_itens já é gravada 1 linha por linha de
-- orcamento_itens (INSERT ... SELECT set-based, sem GROUP BY, dentro de
-- aprovar_orcamento_financeiro) — só faltava o vínculo explícito com a
-- origem e o snapshot de "L Fixo" (orcamento_itens.custom_id).
--
-- orcamento_item_id: FK para rastreabilidade real (join formal).
-- l_fixo: snapshot de texto (mesma lógica das demais colunas de
-- projeto_itens, que já duplicam quantidade/preco_unitario/desconto/
-- descricao no momento da aprovação em vez de fazer JOIN ao vivo).
--
-- Nullable nas duas colunas: linhas legadas (aprovadas antes desta
-- migration) ficam NULL até o backfill best-effort (003) e, nos casos
-- ambíguos, ficam NULL para sempre (decisão do usuário P-05).

ALTER TABLE public.projeto_itens
  ADD COLUMN IF NOT EXISTS orcamento_item_id uuid REFERENCES public.orcamento_itens(id),
  ADD COLUMN IF NOT EXISTS l_fixo text;

CREATE INDEX IF NOT EXISTS idx_projeto_itens_orcamento_item
  ON public.projeto_itens (orcamento_item_id);

COMMENT ON COLUMN public.projeto_itens.orcamento_item_id IS
'SPEC-040 (Fluxo B — Necessidade de Compra por Item de Orçamento). FK para
orcamento_itens.id: identifica de qual linha específica do orçamento este
projeto_item veio, permitindo granularidade por
[orcamento_id + produto_id + L Fixo] em vez de agregação por produto_id.
Gravada por aprovar_orcamento_financeiro (SPEC-016) a partir de 20260723;
linhas aprovadas antes disso foram preenchidas via backfill best-effort
(003_backfill_orcamento_item_id_best_effort.sql) apenas nos casos
inequívocos — casos ambíguos (mesmo produto em 2+ posições do mesmo
orçamento) permanecem NULL permanentemente (decisão do usuário, P-05).';

COMMENT ON COLUMN public.projeto_itens.l_fixo IS
'SPEC-040 (Fluxo B). Snapshot de orcamento_itens.custom_id ("L Fixo" — a
posição/linha do orçamento de origem) no momento da aprovação financeira,
seguindo o mesmo padrão de snapshot já usado pelas demais colunas de
projeto_itens (quantidade, preco_unitario, desconto, descricao). Pode ser
NULL quando o item de orçamento de origem não tinha custom_id preenchido
(decisão do usuário P-04: a linha aparece normalmente no Fluxo B, com "—" na
coluna L Fixo) ou quando orcamento_item_id é NULL (legado/ambíguo).';
