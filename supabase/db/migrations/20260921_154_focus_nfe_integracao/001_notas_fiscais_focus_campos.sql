-- SPEC-154: Integração Focus NFe — emissão real de Nota Fiscal a partir do
-- sistema Vendas. Estende `public.notas_fiscais` (SPEC-153, já existe e já
-- aplicada) com os campos de controle de emissão assíncrona.
--
-- RASCUNHO -- NÃO aplicar sem execução manual do usuário.
--
-- Colunas atuais de `notas_fiscais` confirmadas direto no banco em
-- 2026-09-21 (não pelo snapshot desatualizado de supabase/db/current/):
-- id, numero_nf, serie, data_emissao, valor, arquivo_url, fornecedor,
-- arquiteto, boleto_id, orcamento_id, tipo_operacao, perfil, cliente_id,
-- nome_destinatario. Nada abaixo recria essas colunas.
--
-- Decisão de implementação (documentada por pedido explícito da SPEC-154):
-- o item do Checklist menciona `notas_fiscais.caminho_xml` mas o próprio
-- parênteses do item resolve a dúvida ("arquivo_url, já existente ...
-- sem duplicar coluna"). Optamos por NÃO criar `caminho_xml` -- o link do
-- documento autorizado (DANFE/XML) devolvido pela Focus é gravado em
-- `arquivo_url`, que já existe e já é usado nesse sentido em telas
-- anteriores de nota fiscal. Evita duas colunas concorrentes para a mesma
-- informação.

BEGIN;

ALTER TABLE public.notas_fiscais
  ADD COLUMN IF NOT EXISTS ambiente text NOT NULL DEFAULT 'homologacao',
  ADD COLUMN IF NOT EXISTS ref text,
  ADD COLUMN IF NOT EXISTS status_emissao text NOT NULL DEFAULT 'nao_emitida',
  ADD COLUMN IF NOT EXISTS status_sefaz text,
  ADD COLUMN IF NOT EXISTS mensagem_sefaz text,
  ADD COLUMN IF NOT EXISTS chave_nfe text,
  ADD COLUMN IF NOT EXISTS payload_enviado jsonb,
  ADD COLUMN IF NOT EXISTS tentativa_atual integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS ultima_consulta_em timestamptz;

ALTER TABLE public.notas_fiscais
  DROP CONSTRAINT IF EXISTS notas_fiscais_ambiente_check;
ALTER TABLE public.notas_fiscais
  ADD CONSTRAINT notas_fiscais_ambiente_check
  CHECK (ambiente IN ('homologacao', 'producao'));

ALTER TABLE public.notas_fiscais
  DROP CONSTRAINT IF EXISTS notas_fiscais_status_emissao_check;
ALTER TABLE public.notas_fiscais
  ADD CONSTRAINT notas_fiscais_status_emissao_check
  CHECK (status_emissao IN (
    'nao_emitida',
    'processando_autorizacao',
    'autorizado',
    'erro_autorizacao',
    'cancelado'
  ));

-- `ref` é única e imutável por tentativa (regra 5.2/5 do briefing da
-- SPEC-154): reemissão após erro real de SEFAZ = nova ref, nunca reenvia a
-- mesma ref com payload diferente. NULLs múltiplos são permitidos por
-- padrão em UNIQUE do Postgres (nota ainda não emitida não tem ref).
ALTER TABLE public.notas_fiscais
  DROP CONSTRAINT IF EXISTS notas_fiscais_ref_key;
ALTER TABLE public.notas_fiscais
  ADD CONSTRAINT notas_fiscais_ref_key UNIQUE (ref);

CREATE INDEX IF NOT EXISTS idx_notas_fiscais_status_emissao
  ON public.notas_fiscais (status_emissao);

COMMENT ON COLUMN public.notas_fiscais.ambiente IS
  'SPEC-154. homologacao|producao -- toda emissão desta SPEC roda em homologacao até validar CFOP/IBGE com contador (ver Pendências da SPEC).';
COMMENT ON COLUMN public.notas_fiscais.ref IS
  'SPEC-154. Referência única e imutável da tentativa atual na Focus NFe (formato VENDA-{numero_venda}-N{tentativa}). Reemissão real (pós-rejeição SEFAZ) gera nova ref; histórico de tentativas anteriores fica em notas_fiscais_erros, nunca sobrescrito.';
COMMENT ON COLUMN public.notas_fiscais.status_emissao IS
  'SPEC-154. Estado do fluxo de emissão (nosso, derivado das respostas da Focus): nao_emitida|processando_autorizacao|autorizado|erro_autorizacao|cancelado.';
COMMENT ON COLUMN public.notas_fiscais.status_sefaz IS
  'SPEC-154. Código cStat cru da SEFAZ (ex. 100, 532), gravado sempre como veio -- mesmo quando o código não é reconhecido pelo nosso código (regra 5.1 do briefing: nunca inventar).';
COMMENT ON COLUMN public.notas_fiscais.mensagem_sefaz IS
  'SPEC-154. Texto oficial devolvido pela Focus/SEFAZ -- fonte da verdade para exibição ao usuário.';
COMMENT ON COLUMN public.notas_fiscais.chave_nfe IS
  'SPEC-154. Chave de acesso real de 44 dígitos, preenchida só quando status_emissao = autorizado.';
COMMENT ON COLUMN public.notas_fiscais.payload_enviado IS
  'SPEC-154. Snapshot do JSON de fato enviado no POST /nfe da tentativa atual -- auditoria/reemissão, nunca reescrito retroativamente mesmo que a lógica de montagem do payload mude depois.';
COMMENT ON COLUMN public.notas_fiscais.tentativa_atual IS
  'SPEC-154. Número da tentativa atual de emissão via Focus NFe. Só incrementa quando a tentativa anterior chegou a ser de fato submetida e rejeitada pela SEFAZ (erro real) -- rejeição de pré-validação (400/422, nunca chegou na SEFAZ) reusa a mesma tentativa, ver comentário em emitir-nota-fiscal/index.ts.';
COMMENT ON COLUMN public.notas_fiscais.ultima_consulta_em IS
  'SPEC-154. Usado pelo job de fallback (verificar-notas-pendentes, pg_cron) para saber quais notas em processando_autorizacao já estão "velhas" o suficiente pra consultar de novo (regra: mais de 10 minutos).';
COMMENT ON COLUMN public.notas_fiscais.arquivo_url IS
  'SPEC-154 (decisão de implementação): também guarda o link do documento autorizado (DANFE/XML) devolvido pela Focus quando status_emissao = autorizado. Não existe coluna caminho_xml separada -- ver comentário no topo da migration 20260921_154_focus_nfe_integracao/001.';

NOTIFY pgrst, 'reload schema';

COMMIT;
