-- SPEC-165 (ajuste 2026-09-30, pedido do usuário): quem registrou a reunião
-- pode corrigir o conteúdo de uma sugestão ENQUANTO ela está pendente, antes
-- de o curador avaliar. Depois de aprovada/rejeitada, nada muda.
-- Continua valendo: só curador muda o status; sugestão não pode se apoiar em
-- decisão excepcional; origem (reunião, autor, data) nunca muda.

BEGIN;

CREATE OR REPLACE FUNCTION memoria.kb_sugestoes_guardar()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = memoria, public
AS $$
BEGIN
  IF NEW.decisao_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM memoria.kb_decisoes d WHERE d.id = NEW.decisao_id AND d.excepcional
  ) THEN
    RAISE EXCEPTION 'Solução excepcional não pode virar padrão: sugestão bloqueada';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'pendente' OR NEW.item_criado_id IS NOT NULL THEN
      RAISE EXCEPTION 'Sugestão nasce pendente, sem item criado';
    END IF;
    NEW.revisado_por := NULL;
    NEW.revisado_em := NULL;
    RETURN NEW;
  END IF;

  -- Origem nunca muda.
  IF (NEW.reuniao_id, NEW.criado_por, NEW.created_at) IS DISTINCT FROM (OLD.reuniao_id, OLD.criado_por, OLD.created_at) THEN
    RAISE EXCEPTION 'A origem de uma sugestão não pode ser alterada';
  END IF;

  -- Conteúdo: editável só enquanto pendente.
  IF OLD.status <> 'pendente'
     AND (NEW.tipo_destino, NEW.titulo, NEW.campos, NEW.tags, NEW.justificativa, NEW.trecho_origem)
         IS DISTINCT FROM
         (OLD.tipo_destino, OLD.titulo, OLD.campos, OLD.tags, OLD.justificativa, OLD.trecho_origem) THEN
    RAISE EXCEPTION 'Sugestão já revisada não pode ser alterada';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF OLD.status <> 'pendente' THEN
      RAISE EXCEPTION 'Sugestão já revisada';
    END IF;
    IF NEW.status = 'aprovada' AND NOT EXISTS (
      SELECT 1 FROM memoria.kb_itens i WHERE i.id = NEW.item_criado_id AND i.tipo = NEW.tipo_destino
    ) THEN
      RAISE EXCEPTION 'Aprovação exige o item criado pelo revisor no tema de destino';
    END IF;
    IF NEW.status = 'rejeitada' THEN
      NEW.item_criado_id := NULL;
    END IF;
    NEW.revisado_por := auth.uid();
    NEW.revisado_em := now();
  END IF;
  RETURN NEW;
END;
$$;

-- Quem pode editar a reunião corrige a sugestão pendente, sem poder mudar o
-- status (o WITH CHECK exige que continue pendente). Curador segue com a
-- policy kb_sugestoes_revisar (as policies se somam).
CREATE POLICY kb_sugestoes_corrigir_pendente ON memoria.kb_sugestoes
  FOR UPDATE TO authenticated
  USING (status = 'pendente' AND memoria.kb_pode_editar(reuniao_id))
  WITH CHECK (status = 'pendente' AND memoria.kb_pode_editar(reuniao_id));

COMMIT;
