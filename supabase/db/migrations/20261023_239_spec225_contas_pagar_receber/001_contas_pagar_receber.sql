-- SPEC-225: Administração Bancária vira 2 sistemas no Hub (Contas a Pagar e
-- Contas a Receber), mesmo código e MESMA permissão.
--
-- O slug 'financeiro' continua sendo a chave de permissão (40 policies de RLS,
-- reservar_remessa_cnab, lancar/cancelar_pagamento_antecipado e o app usam
-- ele) -- nenhuma policy muda. Os 2 cards novos têm acesso espelhado com
-- 'financeiro': dar ou tirar qualquer um dos três vale para os três.
--
-- O card antigo ('financeiro') só sai do Hub depois do teste do usuário:
-- ver 002_esconder_card_antigo.sql (aplicar à parte).

BEGIN;

-- 1. Cards novos no Hub
INSERT INTO public.systems (name, description, link, icon_name, display_order, slug, visivel_no_hub)
SELECT v.name, v.description, v.link, v.icon_name, v.display_order, v.slug, true
FROM (VALUES
  ('Contas a Pagar',
   'Duplicatas, notas fiscais e contas em aberto a pagar, baixas e pagamentos antecipados a fornecedores.',
   'https://contas-pagar-lucenera.pages.dev/', 'ArrowUpCircle', 6, 'contas-pagar'),
  ('Contas a Receber',
   'Duplicatas, notas fiscais e contas em aberto a receber, baixas, boletos, remessa e retorno Bradesco.',
   'https://contas-receber-lucenera.pages.dev/', 'ArrowDownCircle', 7, 'contas-receber')
) AS v(name, description, link, icon_name, display_order, slug)
WHERE NOT EXISTS (SELECT 1 FROM public.systems s WHERE s.slug = v.slug);

-- 2. Acesso espelhado entre financeiro / contas-pagar / contas-receber
CREATE OR REPLACE FUNCTION public.espelhar_acesso_financeiro()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_slugs constant text[] := ARRAY['financeiro', 'contas-pagar', 'contas-receber'];
  v_system_id uuid;
  v_user_id uuid;
BEGIN
  -- só reage ao gesto original (o espelho não dispara outro espelho)
  IF pg_trigger_depth() > 1 THEN
    RETURN NULL;
  END IF;

  IF TG_OP = 'INSERT' THEN
    v_system_id := NEW.system_id;
    v_user_id := NEW.user_id;
  ELSE
    v_system_id := OLD.system_id;
    v_user_id := OLD.user_id;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM systems WHERE id = v_system_id AND slug = ANY (v_slugs)) THEN
    RETURN NULL;
  END IF;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO user_system_access (user_id, system_id)
    SELECT v_user_id, s.id
    FROM systems s
    WHERE s.slug = ANY (v_slugs) AND s.id <> v_system_id
    ON CONFLICT (user_id, system_id) DO NOTHING;
  ELSE
    DELETE FROM user_system_access a
    USING systems s
    WHERE a.system_id = s.id
      AND s.slug = ANY (v_slugs)
      AND s.id <> v_system_id
      AND a.user_id = v_user_id;
  END IF;

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.espelhar_acesso_financeiro() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_espelhar_acesso_financeiro ON public.user_system_access;
CREATE TRIGGER trg_espelhar_acesso_financeiro
AFTER INSERT OR DELETE ON public.user_system_access
FOR EACH ROW EXECUTE FUNCTION public.espelhar_acesso_financeiro();

-- 3. Carga inicial: quem tem 'financeiro' ganha os 2 cards novos
INSERT INTO public.user_system_access (user_id, system_id)
SELECT a.user_id, novo.id
FROM public.user_system_access a
JOIN public.systems fin ON fin.id = a.system_id AND fin.slug = 'financeiro'
CROSS JOIN public.systems novo
WHERE novo.slug IN ('contas-pagar', 'contas-receber')
ON CONFLICT (user_id, system_id) DO NOTHING;

COMMIT;
