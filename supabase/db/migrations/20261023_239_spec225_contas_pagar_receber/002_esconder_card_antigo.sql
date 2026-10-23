-- SPEC-225: aplicar SÓ depois que o pessoal da administração testar os 2
-- sistemas novos. Tira o card "Administração Bancária" do Hub; o slug
-- 'financeiro' continua existindo como chave de permissão (não apagar).
BEGIN;
UPDATE public.systems SET visivel_no_hub = false WHERE slug = 'financeiro';
COMMIT;
