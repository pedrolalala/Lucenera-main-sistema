-- SPEC-056: tabela de feriados cadastrados manualmente (nacional/estadual/
-- municipal/ponto facultativo/emenda), mesclada em memória com os feriados
-- nacionais vindos ao vivo da BrasilAPI (use-feriados.ts) para alimentar o
-- calculo de dias uteis / Vale Transporte (vale-transporte.ts).
--
-- Decisoes do usuario (2026-08-05):
-- - Global: um feriado cadastrado vale para todos os funcionarios/empresas
--   (mesmo comportamento do hardcode SP_HOLIDAYS que esta substituindo).
-- - Permissao: RLS permissiva para authenticated (qualquer usuario logado
--   pode ler/escrever), controle de quem pode criar/editar/remover feito
--   na UI (admin/gerente), mesmo padrao ja usado em outras tabelas do RH
--   (ex: funcionarios_beneficios_empresas).
-- - Sem historico retroativo: a tabela so passa a valer a partir do
--   primeiro cadastro, sem backfill de 2024/2025.

CREATE TABLE public.feriados (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    data date NOT NULL,
    descricao text NOT NULL,
    tipo text NOT NULL,
    observacao text,
    ativo boolean DEFAULT true NOT NULL,
    criado_por uuid REFERENCES public.usuarios(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT feriados_tipo_check CHECK (tipo IN ('nacional', 'estadual', 'municipal', 'ponto_facultativo', 'emenda')),
    CONSTRAINT feriados_data_descricao_key UNIQUE (data, descricao)
);

COMMENT ON TABLE public.feriados IS
  'Feriados cadastrados manualmente (SPEC-056), mesclados com a BrasilAPI no frontend para o calculo de dias uteis/Vale Transporte. Global: vale para todos os funcionarios/empresas.';

CREATE INDEX idx_feriados_data ON public.feriados USING btree (data);

CREATE TRIGGER feriados_updated_at
    BEFORE UPDATE ON public.feriados
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.feriados ENABLE ROW LEVEL SECURITY;

-- RLS permissiva para authenticated (mesmo padrao de funcionarios_beneficios_empresas)
-- — o controle de quem pode criar/editar/remover feriado (admin/gerente) e
-- feito na UI do RH, nao no banco.
CREATE POLICY select_feriados ON public.feriados
  FOR SELECT TO authenticated USING (true);

CREATE POLICY insert_feriados ON public.feriados
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY update_feriados ON public.feriados
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY delete_feriados ON public.feriados
  FOR DELETE TO authenticated USING (true);
