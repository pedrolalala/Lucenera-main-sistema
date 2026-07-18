-- Migration 20260718_050 — Parte 1 (SPEC-031)
-- Registra o modulo novo no Hub (SPEC-006) para a permissao granular de
-- "Aprovacao da Equipe" em Orcamentos. Reaproveita a acao 'editar' ja
-- existente (CHECK constraint de modulo_acoes/papel_permissoes so aceita
-- 'criar'|'editar'|'deletar'|'visualizar' — nao ha acao 'aprovar' hoje, e
-- estender esse CHECK e uma mudanca maior, fora do escopo desta SPEC).
--
-- Este INSERT so cadastra o modulo no catalogo — NAO concede a permissao a
-- nenhum papel. A concessao (quem pode aprovar/devolver nesta etapa) e feita
-- depois, pela tela de administracao de papeis/permissoes que a SPEC-006 ja
-- construiu no Hub (Pedro/Filippo decidem quem recebe o modulo).

INSERT INTO public.modulos (system_id, chave, nome, descricao, ordem)
SELECT s.id, 'aprovacao_equipe', 'Aprovação da Equipe (Orçamentos)',
       'Aprovar ou devolver ao cliente um orçamento na etapa pós-aprovação do cliente / pré-financeiro (SPEC-031).',
       10
FROM public.systems s
WHERE s.slug = 'orcamentos'
ON CONFLICT DO NOTHING;

COMMENT ON TABLE public.modulos IS
'Módulos por sistema para permissão granular do Hub (SPEC-006). O módulo
"aprovacao_equipe" do sistema "orcamentos" (SPEC-031) usa a ação genérica
"editar" já existente — não introduz ação nova no CHECK constraint.';
