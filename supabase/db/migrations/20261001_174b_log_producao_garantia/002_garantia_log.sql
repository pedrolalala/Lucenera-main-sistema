-- SPEC-174 N10 — Controle de Garantia: mesma aba "Log" do item 001
-- (producao_pedidos_log), decisão do usuário de estender para a Garantia
-- também ("Produção e Garantia").
--
-- Garantia não tem hoje nenhuma tabela de histórico/auditoria (diferente
-- da Produção, que já tinha ocorrências/handoffs/prazo_alteracoes de
-- SPECs anteriores) — nem para garantia_itens, nem para garantia_protocolos
-- (só created_by/created_at e updated_at via trigger set_updated_at, sem
-- diff nem autor do UPDATE). Por isso aqui são 2 tabelas de log novas, uma
-- por tabela de origem, mesmo desenho do item 001.
--
-- Triggers já existentes (conferido antes de somar estas):
--   - garantia_protocolos_updated_at (BEFORE UPDATE, set_updated_at)
--   - garantia_itens_updated_at (BEFORE UPDATE, set_updated_at)
-- Sem conflito: os novos triggers são AFTER INSERT OR UPDATE, outra fase,
-- outra tabela de destino.
--
-- NUNCA aplicada no Supabase real por este agente — passo manual do
-- usuário (ver SPEC-174 "Passos manuais do usuário").

BEGIN;

-- ---------------------------------------------------------------------
-- garantia_protocolos_log
-- ---------------------------------------------------------------------

CREATE TABLE public.garantia_protocolos_log (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garantia_protocolo_id  uuid NOT NULL REFERENCES public.garantia_protocolos(id) ON DELETE CASCADE,
    acao                   text NOT NULL CHECK (acao IN ('criado', 'atualizado', 'status_alterado')),
    usuario_id             uuid REFERENCES public.usuarios(id),
    dados_antigos          jsonb,
    dados_novos            jsonb,
    criado_em              timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.garantia_protocolos_log IS
  'SPEC-174 N10: trilha de auditoria genérica de garantia_protocolos (todo INSERT/UPDATE, incluindo mudança de status e finalização/desfecho). Alimenta a aba "Log" (só administrador) do Controle de Garantia.';

CREATE INDEX idx_garantia_protocolos_log_protocolo ON public.garantia_protocolos_log USING btree (garantia_protocolo_id);
CREATE INDEX idx_garantia_protocolos_log_criado_em ON public.garantia_protocolos_log USING btree (criado_em DESC);

ALTER TABLE public.garantia_protocolos_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY garantia_protocolos_log_select_admin ON public.garantia_protocolos_log
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios u
      WHERE u.id = auth.uid() AND u.role = 'admin'::usuario_role
    )
  );

CREATE OR REPLACE FUNCTION public.registrar_log_garantia_protocolos()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.garantia_protocolos_log (garantia_protocolo_id, acao, usuario_id, dados_antigos, dados_novos)
        VALUES (NEW.id, 'criado', auth.uid(), NULL, to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.garantia_protocolos_log (garantia_protocolo_id, acao, usuario_id, dados_antigos, dados_novos)
        VALUES (
            NEW.id,
            CASE WHEN NEW.status IS DISTINCT FROM OLD.status THEN 'status_alterado' ELSE 'atualizado' END,
            auth.uid(),
            to_jsonb(OLD),
            to_jsonb(NEW)
        );
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.registrar_log_garantia_protocolos() IS
  'SPEC-174 N10: grava garantia_protocolos_log a cada INSERT/UPDATE de garantia_protocolos, com auth.uid() e diff completo (old/new em jsonb).';

CREATE TRIGGER garantia_protocolos_log_trigger
    AFTER INSERT OR UPDATE ON public.garantia_protocolos
    FOR EACH ROW EXECUTE FUNCTION public.registrar_log_garantia_protocolos();

-- ---------------------------------------------------------------------
-- garantia_itens_log
-- ---------------------------------------------------------------------

CREATE TABLE public.garantia_itens_log (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garantia_item_id  uuid NOT NULL REFERENCES public.garantia_itens(id) ON DELETE CASCADE,
    acao              text NOT NULL CHECK (acao IN ('criado', 'atualizado')),
    usuario_id        uuid REFERENCES public.usuarios(id),
    dados_antigos     jsonb,
    dados_novos       jsonb,
    criado_em         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.garantia_itens_log IS
  'SPEC-174 N10: trilha de auditoria genérica de garantia_itens (criação do item e qualquer UPDATE, ex.: devolução da peça antiga de um adiantamento, agrupamento num protocolo). Alimenta a aba "Log" (só administrador) do Controle de Garantia.';

CREATE INDEX idx_garantia_itens_log_item ON public.garantia_itens_log USING btree (garantia_item_id);
CREATE INDEX idx_garantia_itens_log_criado_em ON public.garantia_itens_log USING btree (criado_em DESC);

ALTER TABLE public.garantia_itens_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY garantia_itens_log_select_admin ON public.garantia_itens_log
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios u
      WHERE u.id = auth.uid() AND u.role = 'admin'::usuario_role
    )
  );

CREATE OR REPLACE FUNCTION public.registrar_log_garantia_itens()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.garantia_itens_log (garantia_item_id, acao, usuario_id, dados_antigos, dados_novos)
        VALUES (NEW.id, 'criado', auth.uid(), NULL, to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.garantia_itens_log (garantia_item_id, acao, usuario_id, dados_antigos, dados_novos)
        VALUES (NEW.id, 'atualizado', auth.uid(), to_jsonb(OLD), to_jsonb(NEW));
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.registrar_log_garantia_itens() IS
  'SPEC-174 N10: grava garantia_itens_log a cada INSERT/UPDATE de garantia_itens, com auth.uid() e diff completo (old/new em jsonb).';

CREATE TRIGGER garantia_itens_log_trigger
    AFTER INSERT OR UPDATE ON public.garantia_itens
    FOR EACH ROW EXECUTE FUNCTION public.registrar_log_garantia_itens();

COMMIT;
