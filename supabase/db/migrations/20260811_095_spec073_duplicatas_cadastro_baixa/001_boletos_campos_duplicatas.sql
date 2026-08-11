-- SPEC-073: telas "Cadastrar Duplicatas" e "Baixar Duplicata" replicam o
-- modulo de Duplicatas do sistema legado Connect (confirmado comparando
-- com as tabelas de staging de importacao staging_conta_pagar/
-- staging_conta_receber, que tem exatamente estes campos: desc_apropriacao,
-- tipo_pagamento, vl_juros, vl_desconto etc.). public.boletos nao tinha
-- onde gravar boa parte desses campos -- adicionados aqui, todos aditivos
-- e nullable/com default, sem tocar em nenhuma linha existente.
--
-- Apropriacao/Grupo/Sub-grupo: plano_de_contas ja e hierarquico em 3
-- niveis (nivel 1 = Grupo, nivel 2 = Sub Grupo, nivel 3 = Apropriacao,
-- confirmado via consulta direta) -- por isso so precisa de UMA FK
-- (apropriacao_id aponta pro registro folha, nivel 3); Grupo/Sub Grupo na
-- tela sao derivados subindo o parent_id, nao precisam de coluna propria.
--
-- Conta: contas_bancarias ja existe e ja tem os campos certos (nome,
-- banco, agencia, conta) -- so precisava da FK em boletos.

ALTER TABLE public.boletos
  ADD COLUMN IF NOT EXISTS apropriacao_id uuid REFERENCES public.plano_de_contas(id),
  ADD COLUMN IF NOT EXISTS conta_bancaria_id uuid REFERENCES public.contas_bancarias(id),
  ADD COLUMN IF NOT EXISTS forma_pagamento text,
  ADD COLUMN IF NOT EXISTS bandeira text,
  ADD COLUMN IF NOT EXISTS linha_digitavel text,
  ADD COLUMN IF NOT EXISTS juros_multa numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS desconto numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS responsavel_id uuid REFERENCES public.usuarios(id),
  ADD COLUMN IF NOT EXISTS referencia text,
  ADD COLUMN IF NOT EXISTS conta_grupo_id uuid,
  ADD COLUMN IF NOT EXISTS observacao text;

COMMENT ON COLUMN public.boletos.conta_grupo_id IS
  'SPEC-073: agrupa as parcelas geradas juntas em "Cadastrar Duplicatas > Gerar Conta" -- todas as parcelas da mesma conta compartilham este id (gerado no frontend, gen_random_uuid()).';
COMMENT ON COLUMN public.boletos.apropriacao_id IS
  'SPEC-073: FK para plano_de_contas.id (nivel 3 = folha/Apropriacao). Grupo e Sub Grupo (niveis 1 e 2) sao derivados subindo parent_id, nao duplicados aqui.';

CREATE INDEX IF NOT EXISTS idx_boletos_conta_grupo_id ON public.boletos(conta_grupo_id);
