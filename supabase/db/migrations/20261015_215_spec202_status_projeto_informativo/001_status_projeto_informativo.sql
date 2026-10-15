-- SPEC-202: status do projeto no CRM passa a ser só informativo.
-- trg_proteger_fechamento barrava salvar o projeto ("Não é possível fechar o
-- projeto sem nenhum item cadastrado") ao escolher Projeto executivo /
-- Entrega materiais / Ajustes finais / Finalizado. trg_fechar_projeto, em
-- "Entrega materiais", baixava estoque e criava separação — fluxo legado,
-- hoje isso vem do orçamento aprovado (Separação/Vendas). Nenhum projeto está
-- nesses status (15/10/2026). Triggers e funções ficam no banco, só desligados.
BEGIN;
ALTER TABLE public.projetos DISABLE TRIGGER trg_proteger_fechamento;
ALTER TABLE public.projetos DISABLE TRIGGER trg_fechar_projeto;
COMMIT;
