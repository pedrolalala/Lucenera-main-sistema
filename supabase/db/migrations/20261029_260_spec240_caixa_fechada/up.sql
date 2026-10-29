-- SPEC-240: "Itens por caixa" (caixa fechada) = produtos.multiplo_compra, coluna que já existe (SPEC-026, todas = 1).
-- O pedido de compra arredonda a quantidade para cima até fechar a caixa (feito na tela do Compras).
-- Aqui só a regra de quem pode alterar: Débora (lista produto_caixa_editores) e a administração
-- (role admin ou papel administracao_comercial). Contas de serviço/scripts (sem auth.uid()) continuam podendo.
BEGIN;

COMMENT ON COLUMN public.produtos.multiplo_compra IS
  'Itens por caixa (caixa fechada). O pedido de compra arredonda a quantidade para cima até o múltiplo deste valor '
  '(ex.: precisa 38, caixa 10 → compra 40). 1 = sem regra. SPEC-026/SPEC-240: só a Débora e a administração alteram.';

ALTER TABLE public.produtos DROP CONSTRAINT IF EXISTS produtos_multiplo_compra_positivo;
ALTER TABLE public.produtos ADD CONSTRAINT produtos_multiplo_compra_positivo
  CHECK (multiplo_compra IS NULL OR multiplo_compra >= 1);

-- Quem fora da administração pode alterar (mesmo padrão de produto_custo_visualizadores).
CREATE TABLE IF NOT EXISTS public.produto_caixa_editores (
  email text PRIMARY KEY,
  nome text NOT NULL,
  observacao text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.produto_caixa_editores ENABLE ROW LEVEL SECURITY;
COMMENT ON TABLE public.produto_caixa_editores IS
  'SPEC-240: quem, além da administração, pode alterar Itens por caixa (produtos.multiplo_compra).';
INSERT INTO public.produto_caixa_editores (email, nome, observacao)
VALUES ('debora@lucenera.com.br', 'Débora', 'Compras — reunião Filippo 29/10')
ON CONFLICT (email) DO NOTHING;

CREATE OR REPLACE FUNCTION public.pode_editar_caixa_fechada()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.usuarios u
     WHERE u.id = auth.uid()
       AND (u.role::text = 'admin'
            OR lower(u.email) IN (SELECT lower(e.email) FROM public.produto_caixa_editores e)
            OR EXISTS (SELECT 1 FROM public.usuario_papeis up JOIN public.papeis p ON p.id = up.papel_id
                        WHERE up.usuario_id = u.id AND p.nome = 'administracao_comercial'))
  );
$function$;
REVOKE ALL ON FUNCTION public.pode_editar_caixa_fechada() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_editar_caixa_fechada() TO authenticated;

CREATE OR REPLACE FUNCTION public.trg_produtos_multiplo_compra_editor()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  IF (TG_OP = 'UPDATE' AND NEW.multiplo_compra IS DISTINCT FROM OLD.multiplo_compra)
     OR (TG_OP = 'INSERT' AND COALESCE(NEW.multiplo_compra, 1) <> 1) THEN
    IF NOT public.pode_editar_caixa_fechada() THEN
      RAISE EXCEPTION 'Só a Débora e a administração podem alterar Itens por caixa.'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_produtos_multiplo_compra_editor ON public.produtos;
CREATE TRIGGER trg_produtos_multiplo_compra_editor
  BEFORE INSERT OR UPDATE OF multiplo_compra ON public.produtos
  FOR EACH ROW EXECUTE FUNCTION public.trg_produtos_multiplo_compra_editor();

COMMIT;
