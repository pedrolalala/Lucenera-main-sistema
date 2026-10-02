-- SPEC-174 N10 — Controle de Produção: aba "Log" visível só para
-- administrador, com o histórico de quem fez o quê (criação, alteração de
-- campos, mudança de status).
--
-- O que já existe e é reaproveitado (sem migration nova):
--   - producao_pedido_ocorrencias: quem registrou/resolveu cada ocorrência
--     (registrado_por/registrado_em, resolvido_por/resolvida_em).
--   - producao_pedido_handoffs: quem entregou/recebeu (entregue_por_nome,
--     recebido_por_nome, data_hora).
--   - producao_pedido_prazo_alteracoes: motivo da mudança de prazo.
--   - producao_pedido_edicoes: só "quem editou e quando" (SEM diff de
--     campos) — cobre edição pelo formulário completo, mas NÃO cobre a
--     troca de status pelo modal rápido ("Status" na listagem /
--     ModalAtualizarStatusProducao), que hoje faz um UPDATE direto em
--     producao_pedidos sem deixar rastro de quem mudou.
--
-- O que falta (motivo desta migration): nenhuma tabela registra o diff
-- completo (old/new) de producao_pedidos nem cobre o UPDATE feito pelo
-- modal de status. Esta migration cria uma trilha de auditoria genérica
-- (AFTER INSERT/UPDATE em producao_pedidos) que cobre os dois casos de uma
-- vez, com auth.uid() (autor real do UPDATE, não o `created_by`/
-- `editado_por` que a aplicação passa manualmente) e o diff completo em
-- jsonb.
--
-- Triggers já existentes em producao_pedidos (conferido antes de somar
-- esta): producao_pedidos_updated_at (BEFORE UPDATE, set_updated_at). Não
-- há conflito: o novo trigger é AFTER INSERT OR UPDATE, outra fase de
-- execução, outra tabela de destino.
--
-- NUNCA aplicada no Supabase real por este agente — passo manual do
-- usuário (ver SPEC-174 "Passos manuais do usuário").

BEGIN;

CREATE TABLE public.producao_pedidos_log (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    producao_pedido_id  uuid NOT NULL REFERENCES public.producao_pedidos(id) ON DELETE CASCADE,
    acao                text NOT NULL CHECK (acao IN ('criado', 'atualizado', 'status_alterado')),
    usuario_id          uuid REFERENCES public.usuarios(id),
    dados_antigos       jsonb,
    dados_novos         jsonb,
    criado_em           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.producao_pedidos_log IS
  'SPEC-174 N10: trilha de auditoria genérica de producao_pedidos (todo INSERT/UPDATE, incluindo a troca de status pelo modal rápido, que antes não deixava rastro de autor). Alimenta a aba "Log" (só administrador) do Controle de Produção.';
COMMENT ON COLUMN public.producao_pedidos_log.acao IS
  '''criado'' no INSERT; ''status_alterado'' quando o UPDATE muda a coluna status; ''atualizado'' para qualquer outro UPDATE.';
COMMENT ON COLUMN public.producao_pedidos_log.usuario_id IS
  'auth.uid() de quem fez o INSERT/UPDATE (gravado pelo trigger, não pela aplicação) — pode ser NULL se a operação não tiver um JWT de usuário associado (ex.: script administrativo).';

CREATE INDEX idx_producao_pedidos_log_pedido ON public.producao_pedidos_log USING btree (producao_pedido_id);
CREATE INDEX idx_producao_pedidos_log_criado_em ON public.producao_pedidos_log USING btree (criado_em DESC);

ALTER TABLE public.producao_pedidos_log ENABLE ROW LEVEL SECURITY;

-- Só administrador lê (decisão do usuário, SPEC-174 N10: "visível só para
-- administrador"). Mesmo critério de admin já usado no restante do
-- ecossistema (usuarios.role = 'admin', ver
-- cadastro-lucenera-b86fe/src/lib/usuario-role-cache.ts e as policies
-- "u.role = 'admin'::usuario_role" em supabase/db/current/07_rls_policies.sql).
-- Sem policy de INSERT/UPDATE/DELETE para authenticated: só a função
-- SECURITY DEFINER do trigger grava nesta tabela.
CREATE POLICY producao_pedidos_log_select_admin ON public.producao_pedidos_log
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios u
      WHERE u.id = auth.uid() AND u.role = 'admin'::usuario_role
    )
  );

CREATE OR REPLACE FUNCTION public.registrar_log_producao_pedidos()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.producao_pedidos_log (producao_pedido_id, acao, usuario_id, dados_antigos, dados_novos)
        VALUES (NEW.id, 'criado', auth.uid(), NULL, to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.producao_pedidos_log (producao_pedido_id, acao, usuario_id, dados_antigos, dados_novos)
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

COMMENT ON FUNCTION public.registrar_log_producao_pedidos() IS
  'SPEC-174 N10: grava producao_pedidos_log a cada INSERT/UPDATE de producao_pedidos, com auth.uid() e diff completo (old/new em jsonb). SECURITY DEFINER porque producao_pedidos_log só aceita INSERT por esta função (sem policy de INSERT para authenticated).';

CREATE TRIGGER producao_pedidos_log_trigger
    AFTER INSERT OR UPDATE ON public.producao_pedidos
    FOR EACH ROW EXECUTE FUNCTION public.registrar_log_producao_pedidos();

COMMIT;
