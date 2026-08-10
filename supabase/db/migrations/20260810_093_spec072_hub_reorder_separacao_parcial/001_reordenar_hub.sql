-- SPEC-072: usuário pediu que o card "Separação Parcial" no Hub apareça
-- logo depois de "Administração Bancária" (display_order 6) e antes de
-- "Sistema de Entregas" (display_order 7). O sistema já estava registrado
-- em public.systems (visivel_no_hub = true), só no fim da lista
-- (display_order 10) — aqui é só reordenação, sem inserir linha nova.

UPDATE public.systems SET display_order = 8 WHERE slug = 'logistica';
UPDATE public.systems SET display_order = 9 WHERE slug = 'ubiqua';
UPDATE public.systems SET display_order = 10 WHERE slug = 'dashboard-financeiro';
UPDATE public.systems SET display_order = 7 WHERE slug = 'separacao-parcial';

-- Achado à parte: a própria linha "hub" tinha a URL errada
-- (central-lucenera.goskip.app, nunca publicada) que corrigimos em todos os
-- 8 sistemas satélite nesta mesma sessão — mesmo não aparecendo como card
-- (visivel_no_hub = false), corrige aqui por consistência.
UPDATE public.systems SET link = 'https://central-lucenera-dashboard-1c9ba.goskip.app/dashboard' WHERE slug = 'hub';
