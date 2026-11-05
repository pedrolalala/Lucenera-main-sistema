-- Cadastro das empresas do grupo (conferido com a tela "Editar empresa" do emissor de NF, 05/11/2026).
-- empresas ja tem cnpj, razao_social, cidade, regime_tributario, inscricao_estadual; faltavam nome fantasia e inscricao municipal.
BEGIN;

ALTER TABLE public.empresas ADD COLUMN IF NOT EXISTS nome_fantasia text;
ALTER TABLE public.empresas ADD COLUMN IF NOT EXISTS inscricao_municipal text;

UPDATE public.empresas SET nome_fantasia = 'Foco Iluminação' WHERE cnpj = '24.090.967/0001-70';
UPDATE public.empresas SET nome_fantasia = 'Manoella'        WHERE cnpj = '11.258.465/0001-63';
UPDATE public.empresas SET nome_fantasia = 'ISLIGHT'         WHERE cnpj = '21.585.885/0001-08';

-- Regimes: FOCO e MANOELLA = Simples Nacional (ja gravado). ISLIGHT = Regime Normal (hoje 'Lucro Presumido', que e Regime Normal; mantido).
-- inscricao_estadual segue vazia nas 3 (vazia tambem no emissor). inscricao_municipal fica NULL: o emissor mostra "RibeiroPreto" nesse campo (provavel erro de cadastro).

COMMIT;
