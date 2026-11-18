-- SPEC-320 (18/11/2026): registra o sistema "Escoar reserva sem venda" no Hub e libera o card para Matheus e Vitoria.
-- A trava real continua no banco (pode_escoar_reserva_connect, migration 385); o card so controla quem ve o atalho.
-- Administracao ve todos os sistemas pelo papel. Nao mexe em nenhum outro acesso.
BEGIN;

INSERT INTO public.systems (name, description, link, icon_name, display_order, slug, visivel_no_hub)
SELECT 'Escoar Reserva sem Venda',
       'SPEC-320: lanca por lista de entrega da Connect as pecas que saem da reserva sem venda (heranca) e do Estoque Geral.',
       'https://escoar-lucenera.pages.dev/', 'PackageSearch', 101, 'escoar-reserva', true
WHERE NOT EXISTS (SELECT 1 FROM public.systems WHERE slug = 'escoar-reserva');

INSERT INTO public.user_system_access (user_id, system_id)
SELECT u.id, s.id FROM public.usuarios u JOIN public.systems s ON s.slug = 'escoar-reserva'
 WHERE lower(u.email) IN ('matheus@lucenera.com.br', 'vitoria@lucenera.com.br')
ON CONFLICT (user_id, system_id) DO NOTHING;

COMMIT;
