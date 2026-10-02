-- Migration 20261001_174c (SPEC-174, item N7) -- RASCUNHO, NÃO APLICADA.
--
-- N7 implementou no frontend do Cadastro (cadastro-lucenera-b86fe) o
-- mecanismo de permissão por ação: Editar/Copiar/Excluir peça e o duplo
-- clique que abre a edição só aparecem para quem passa em
-- hub_pode_executar(auth.uid(), 'cadastro', NULL, 'editar'). Consulta
-- continua liberada para todo mundo com acesso ao sistema (sem mudança).
--
-- Esta migration NÃO foi aplicada no banco real -- nem em dry-run com
-- ROLLBACK (regra do agente implementador: nenhum SQL de escrita é
-- executado contra o Supabase real, nem revertido depois). A matriz
-- definitiva papel x ação do Cadastro será fechada com o Vinícius na
-- ligação de 02/10/2026 (pendência registrada na SPEC-174). Até lá, NÃO
-- aplicar esta migration sem confirmação explícita, porque ela concede uma
-- permissão nova (risco inverso ao problema que resolve).
--
-- ACHADO (consulta só leitura ao Supabase real em 01/10/2026, função viva
-- public.hub_pode_executar): se o frontend passar a checar a ação 'editar'
-- HOJE, com o seed atual de papel_permissoes, pelo menos 1 papel que edita
-- peça na prática perderia a capacidade:
--
--   Papel 'compras_e_entregas' (Débora, debora@lucenera.com.br) tem hoje
--   SÓ a ação 'visualizar' em papel_permissoes para o sistema 'cadastro'
--   (sem linha com acao IS NULL nem acao = 'editar') -> passaria a FALHAR
--   em hub_pode_executar(..., 'cadastro', NULL, 'editar') e perderia
--   Editar/Copiar/Excluir/duplo-clique, mesmo editando peça hoje na
--   prática (SPEC-174, pedido do usuário: "a Débora/compras" não pode
--   perder acesso).
--
-- Quem JÁ passaria hoje (nenhuma ação necessária, listado só para registro
-- da conferência "sem regressão silenciosa" pedida na SPEC-174):
--   - papéis 'admin', 'admin_geral', 'funcionario', 'gerente', 'operador' e
--     'viewer' têm hoje uma única linha em papel_permissoes para
--     'cadastro' com acao IS NULL (== "todas as ações" pela regra
--     documentada em supabase/db/domains/hub_ti.md) -> PASSAM em 'editar'.
--     Nota: isso inclui 'viewer', o que é inconsistente com o nome do papel
--     (provável sobra da SPEC-006/069, fora do escopo desta SPEC -- só
--     registrado aqui para o Vinícius decidir na ligação de 02/10, junto
--     com a matriz).
--   - papel 'administracao_comercial' (Caroline) já tem linha explícita
--     acao = 'editar' -> PASSA.
--   - papel 'equipe_projetos' (Mariane "Mari", Marina, Lana, Thairine) já
--     tem linha explícita acao = 'editar' -> PASSA (nenhuma das duas "Mari"
--     citadas no pedido do usuário perde acesso).
--   - papel 'estoque' tem hoje só 'visualizar' (mesma situação de
--     'compras_e_entregas'), mas NENHUM usuário ativo está com esse papel
--     em 01/10/2026 -- sem regressão concreta hoje; incluído no INSERT
--     abaixo por paridade, a confirmar com o Vinícius.
--
-- Usuários ativos sem papel nenhum (erp.lucenera@gmail.com,
-- marianelighting@outlook.com, vinicius_bortolin@hotmail.com) já não
-- editam hoje (hasAccess também falharia) -- sem mudança de comportamento.
--
-- Proposta (a aplicar só depois da ligação de 02/10): acrescentar a ação
-- 'editar' para os papéis que hoje só têm 'visualizar' no Cadastro, para
-- quem já edita peça na prática não perder a capacidade quando o frontend
-- passar a checar a ação. ON CONFLICT DO NOTHING -- idempotente, não
-- duplica nem sobrescreve linhas existentes (ex.: se algum desses papéis já
-- tiver outra permissão compatível amanhã).

BEGIN;

-- WHERE NOT EXISTS em vez de ON CONFLICT: com modulo_id NULL o unique index
-- trata NULL como distinto e o ON CONFLICT nunca dispara (achado do revisor
-- em 01/10 -- reexecutar duplicaria as linhas).
INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, s.id, NULL, 'editar'
FROM public.papeis p
CROSS JOIN public.systems s
WHERE s.slug = 'cadastro'
  AND p.nome IN ('compras_e_entregas', 'estoque')
  AND NOT EXISTS (
    SELECT 1 FROM public.papel_permissoes pp
    WHERE pp.papel_id = p.id
      AND pp.system_id = s.id
      AND pp.modulo_id IS NULL
      AND pp.acao = 'editar'
  );

NOTIFY pgrst, 'reload schema';

COMMIT;

-- Rollback (se um dia for preciso desfazer, depois de aplicada):
-- DELETE FROM public.papel_permissoes pp
-- USING public.papeis p, public.systems s
-- WHERE pp.papel_id = p.id AND pp.system_id = s.id
--   AND s.slug = 'cadastro' AND p.nome IN ('compras_e_entregas', 'estoque')
--   AND pp.acao = 'editar' AND pp.modulo_id IS NULL;
