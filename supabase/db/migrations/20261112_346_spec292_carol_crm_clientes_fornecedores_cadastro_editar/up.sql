-- SPEC-292 (12/11/2026): ajuste do papel assistente_administrativa (Carol)
--  1) CRM: ver SO Clientes e Fornecedores (visualizar). Novo modulo 'clientes' no CRM; acesso ao sistema crm (card).
--  2) Cadastro/Consultar Produtos: volta a poder CRIAR e EDITAR peca (a SPEC-269 tinha deixado so consulta).
-- Nao muda RLS: contatos so grava com 'crm' editar (ela nao tem); produtos ja aceita 'cadastro' criar/editar.
BEGIN;

-- 1. modulo 'clientes' do CRM
INSERT INTO public.modulos (system_id, chave, nome, descricao, ordem)
SELECT s.id, 'clientes', 'Clientes (CRM)', 'SPEC-292: so a aba Clientes do CRM.', 2
  FROM public.systems s
 WHERE s.slug = 'crm'
   AND NOT EXISTS (SELECT 1 FROM public.modulos m WHERE m.system_id = s.id AND m.chave = 'clientes');

-- 2. papel: crm/clientes + crm/fornecedores (visualizar) e cadastro criar/editar
INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, s.id, m.id, 'visualizar'
  FROM public.papeis p
  JOIN public.systems s ON s.slug = 'crm'
  JOIN public.modulos m ON m.system_id = s.id AND m.chave IN ('clientes', 'fornecedores')
 WHERE p.nome = 'assistente_administrativa'
   AND NOT EXISTS (SELECT 1 FROM public.papel_permissoes x
                    WHERE x.papel_id = p.id AND x.system_id = s.id AND x.modulo_id = m.id AND x.acao = 'visualizar');

INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, s.id, NULL, v.acao
  FROM public.papeis p
  JOIN public.systems s ON s.slug = 'cadastro'
  CROSS JOIN (VALUES ('criar'), ('editar')) AS v(acao)
 WHERE p.nome = 'assistente_administrativa'
   AND NOT EXISTS (SELECT 1 FROM public.papel_permissoes x
                    WHERE x.papel_id = p.id AND x.system_id = s.id AND x.modulo_id IS NULL AND x.acao = v.acao);

UPDATE public.papeis SET descricao =
  'SPEC-260/269/292: Assistente administrativa — Financeiro (Contas a Pagar/Receber, acordos), Orcamentos, Vendas e Venda Parcial; Cadastro de pecas: consulta, cria e edita; CRM: so ve Clientes e Fornecedores; Showroom so consulta; Central de Solicitacoes sem aprovar; NAO emite LT/comissao.'
 WHERE nome = 'assistente_administrativa';

-- 3. Acesso a Sistemas (card/portao do hub_pode_executar): CRM para a Carol
INSERT INTO public.user_system_access (user_id, system_id)
SELECT u.id, s.id FROM public.usuarios u JOIN public.systems s ON s.slug = 'crm'
 WHERE lower(u.email) = 'caroline@lucenera.com.br'
ON CONFLICT (user_id, system_id) DO NOTHING;

NOTIFY pgrst, 'reload schema';
COMMIT;
