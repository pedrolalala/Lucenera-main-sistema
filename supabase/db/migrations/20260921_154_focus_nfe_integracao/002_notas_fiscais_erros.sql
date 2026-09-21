-- SPEC-154: histórico completo de pendências/erros de emissão via Focus
-- NFe -- uma linha por tentativa que voltou com problema, nunca sobrescrita
-- (regra 4/8 do briefing). Cobre tanto rejeição real de SEFAZ (erro_codigo/
-- status_sefaz preenchidos) quanto pré-validação da própria Focus (400/422,
-- nunca chegou na SEFAZ) e erro de configuração (401/403 -- token/CNPJ não
-- habilitado).
--
-- RASCUNHO -- NÃO aplicar sem execução manual do usuário.

BEGIN;

CREATE TABLE IF NOT EXISTS public.notas_fiscais_erros (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_fiscal_id uuid NOT NULL REFERENCES public.notas_fiscais(id) ON DELETE CASCADE,
  ref text NOT NULL,
  numero_tentativa integer NOT NULL,
  status_sefaz text,
  mensagem_sefaz text,
  erro_codigo text,
  erro_campo text,
  resposta_bruta jsonb NOT NULL,
  data_hora timestamptz NOT NULL DEFAULT now(),
  resolvido boolean NOT NULL DEFAULT false,
  data_resolucao timestamptz
);

COMMENT ON TABLE public.notas_fiscais_erros IS
  'SPEC-154. Histórico completo de pendências de emissão via Focus NFe -- uma linha por tentativa com problema (rejeição SEFAZ, pré-validação 400/422 ou erro de configuração 401/403), nunca sobrescrita. Sistema "Vendas" é o dono do CRUD (leitura pela tela "Pendências de Nota Fiscal", fora do escopo desta migration).';
COMMENT ON COLUMN public.notas_fiscais_erros.ref IS
  'Ref da tentativa que gerou este erro -- pode não bater mais com notas_fiscais.ref atual se já houve reemissão desde então (ref é sobrescrita na tabela pai a cada nova tentativa; aqui fica o valor histórico real).';
COMMENT ON COLUMN public.notas_fiscais_erros.numero_tentativa IS
  'Snapshot de notas_fiscais.tentativa_atual no momento do erro.';
COMMENT ON COLUMN public.notas_fiscais_erros.erro_codigo IS
  'Código de erro cru da resposta da Focus quando informado (não inventado) -- também usado para os marcadores internos de config (focus_config_401/focus_config_403) e limite de taxa (focus_rate_limit), ver emitir-nota-fiscal/index.ts.';
COMMENT ON COLUMN public.notas_fiscais_erros.erro_campo IS
  'Nome do campo do JSON enviado que causou o erro, quando a API informar (pré-validação 400/422). NULL para rejeição real de SEFAZ (erro não é de um campo específico do payload).';
COMMENT ON COLUMN public.notas_fiscais_erros.resposta_bruta IS
  'Corpo cru completo da resposta de erro da Focus, sempre preservado -- nunca resumido/reinterpretado.';
COMMENT ON COLUMN public.notas_fiscais_erros.resolvido IS
  'Marcado true automaticamente quando uma tentativa POSTERIOR da mesma nota_fiscal_id é autorizada (ver emitir-nota-fiscal/focus-nfe-webhook/verificar-notas-pendentes). Nunca marcado por trigger -- sempre pela mesma lógica que grava o sucesso.';

CREATE INDEX IF NOT EXISTS idx_notas_fiscais_erros_nota_fiscal_id
  ON public.notas_fiscais_erros (nota_fiscal_id);
CREATE INDEX IF NOT EXISTS idx_notas_fiscais_erros_pendentes
  ON public.notas_fiscais_erros (resolvido) WHERE resolvido = false;

ALTER TABLE public.notas_fiscais_erros ENABLE ROW LEVEL SECURITY;

-- Mesmo padrão permissivo já usado em notas_fiscais_itens (SPEC-153,
-- 20260917_153_notas_fiscais_parcial_multipagador/001) -- controle de
-- acesso real do ecossistema ainda depende de hub_pode_executar dentro das
-- Edge Functions/RPCs, não de RLS granular por linha.
DROP POLICY IF EXISTS authenticated_all_notas_fiscais_erros ON public.notas_fiscais_erros;
CREATE POLICY authenticated_all_notas_fiscais_erros ON public.notas_fiscais_erros
  AS PERMISSIVE FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

NOTIFY pgrst, 'reload schema';

COMMIT;
