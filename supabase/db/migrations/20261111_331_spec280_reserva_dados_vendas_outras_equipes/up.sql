-- SPEC-280 (complemento, 11/11/2026): na lista "de onde puxar" do Transferir (Separação Parcial), reservas de OUTRAS equipes
-- apareciam sem equipe e sem número de venda para quem é de equipe de projetos: a tela completava esses dados lendo
-- `orcamentos`, e a regra de equipe (SPEC-200) esconde os orçamentos das outras equipes. A transferência entre equipes é
-- regra mantida (pode puxar de qualquer equipe); só faltava o dado para identificar de onde se está puxando.
-- Função nova, só ADICIONA: devolve apenas número da venda, origem e nome da equipe (nada de cliente, valor ou itens)
-- para quem tem acesso ao sistema separacao-parcial. Não altera RLS nem nenhuma função existente.
-- Sem BEGIN/COMMIT de propósito (o dry_run abre a transação e termina em ROLLBACK).
CREATE OR REPLACE FUNCTION public.reserva_dados_vendas(p_orcamento_ids uuid[])
 RETURNS TABLE (orcamento_id uuid, numero_venda text, origem text, equipe_nome text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT o.id, o.numero_venda::text, o.origem::text, e.equipes::text
  FROM public.orcamentos o
  LEFT JOIN public.equipes_projetos e ON e.id = o.equipe_id
  WHERE (SELECT public.pode_acessar_sistema('separacao-parcial'))
    AND o.id = ANY (p_orcamento_ids[1:500]);
$function$;

REVOKE ALL ON FUNCTION public.reserva_dados_vendas(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reserva_dados_vendas(uuid[]) TO authenticated;
