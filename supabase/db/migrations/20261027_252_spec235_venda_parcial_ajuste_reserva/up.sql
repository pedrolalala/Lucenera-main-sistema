-- SPEC-235 (reunião 27/10 parte 2)
--  A: "Separação Parcial" passa a se chamar "Venda Parcial" (só o nome; slug igual).
--  B: ajuste Reserva <-> Entrega Futura dentro da MESMA venda, pela Venda Parcial, só para o Matheus e admin.
--     Permissão própria: módulo "ajuste_reserva_venda" do sistema separacao-parcial + exceção individual "conceder"
--     (gerenciável na Central -> Exceções). Papel NÃO concede: quem tem só o acesso ao sistema (vendedoras) não passa.
--     A troca de reserva ENTRE vendas (pode_trocar_reserva, SPEC-098/149) não muda.
--  H: "GRUPO CONVERSAO" (veio da Connect) desativado — some do filtro; a única peça dele (13549) não muda.
BEGIN;

UPDATE public.systems SET name = 'Venda Parcial' WHERE slug = 'separacao-parcial';

UPDATE public.categorias_produto SET ativo = false WHERE nome = 'GRUPO CONVERSAO';

INSERT INTO public.modulos (system_id, chave, nome, descricao, ordem)
SELECT s.id, 'ajuste_reserva_venda', 'Ajuste Reserva ⇄ Entrega Futura (Venda Parcial)',
       'SPEC-235 B: mover quantidade entre Reserva e Entrega Futura dentro da mesma venda. Só exceção individual (conceder) ou admin.',
       100
  FROM public.systems s WHERE s.slug = 'separacao-parcial'
ON CONFLICT (system_id, chave) DO NOTHING;

-- Matheus (líder da logística)
INSERT INTO public.usuario_permissao_excecoes (usuario_id, system_id, modulo_id, acao, tipo, justificativa)
SELECT 'af3035fd-266b-4b3a-952b-cb8866096c49', s.id, m.id, 'editar', 'conceder',
       'SPEC-235 B: só o Matheus ajusta Reserva/Entrega Futura dentro da venda (reunião 27/10)'
  FROM public.systems s JOIN public.modulos m ON m.system_id = s.id AND m.chave = 'ajuste_reserva_venda'
 WHERE s.slug = 'separacao-parcial'
   AND NOT EXISTS (SELECT 1 FROM public.usuario_permissao_excecoes e
                    WHERE e.usuario_id = 'af3035fd-266b-4b3a-952b-cb8866096c49' AND e.modulo_id = m.id);

CREATE OR REPLACE FUNCTION public.pode_ajustar_reserva_venda()
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    public.is_admin()
    OR coalesce((
      SELECT e.tipo = 'conceder'
        FROM public.usuario_permissao_excecoes e
        JOIN public.modulos m ON m.id = e.modulo_id AND m.chave = 'ajuste_reserva_venda'
        JOIN public.systems s ON s.id = m.system_id AND s.slug = 'separacao-parcial'
       WHERE e.usuario_id = auth.uid()
         AND (e.valido_até IS NULL OR e.valido_até > now())
       ORDER BY e.criado_em DESC
       LIMIT 1), false)
  )
$$;

-- Reaproveita movimentar_peca_venda (SPEC-224/227: valida saldo, peça livre no Geral, registra o movimento).
-- Ela também exige _mov_pode() (admin ou acesso à Movimentação de Peças) — o Matheus tem.
CREATE OR REPLACE FUNCTION public.ajustar_reserva_venda(
  p_projeto_item_id uuid, p_acao text, p_quantidade numeric, p_motivo text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.pode_ajustar_reserva_venda() THEN
    RAISE EXCEPTION 'Só o Matheus ou um administrador pode ajustar Reserva/Entrega Futura.' USING ERRCODE = '42501';
  END IF;
  IF p_acao NOT IN ('reserva_para_entrega_futura', 'entrega_futura_para_reserva') THEN
    RAISE EXCEPTION 'Ajuste inválido: %', p_acao USING ERRCODE = 'P0001';
  END IF;
  RETURN public.movimentar_peca_venda(p_projeto_item_id, p_acao, p_quantidade, p_motivo, false);
END;
$$;

REVOKE ALL ON FUNCTION public.pode_ajustar_reserva_venda() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.ajustar_reserva_venda(uuid, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_ajustar_reserva_venda() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ajustar_reserva_venda(uuid, text, numeric, text) TO authenticated;

COMMIT;
