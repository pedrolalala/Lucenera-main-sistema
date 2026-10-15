-- migration 218 (15/10): as cópias _bkp_* foram movidas para o schema backup.
-- Rollback da migration 208: remove só os acessos que não existiam antes (compara com o backup).
DELETE FROM public.user_system_access usa
WHERE NOT EXISTS (
  SELECT 1 FROM backup._bkp_user_system_access_20261014 b
  WHERE b.user_id = usa.user_id AND b.system_id = usa.system_id
)
AND usa.system_id IN (SELECT id FROM public.systems
  WHERE slug IN ('orcamentos', 'crm', 'cadastro', 'separacao-parcial', 'logistica', 'ubiqua', 'showroom', 'memoria'));
