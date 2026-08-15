-- Migration 20260815_115 (SPEC-107)
-- Adiciona 'permuta' ao ENUM pagamento_forma. Reunião Vinícius 14/08/2026:
-- "Vou te pedir outra: Permuta." — cheque e transferência já existiam no
-- enum (nunca liberados na UI, ver 002_liberar_formas_pagamento_ui.md nesta
-- pasta pra referência do fix de frontend), só permuta precisava ser criado.
--
-- ALTER TYPE ... ADD VALUE não pode rodar dentro de uma transação junto com
-- outros comandos que usam o valor novo — arquivo isolado, sem BEGIN/COMMIT
-- explícito (psql roda cada statement em autocommit por padrão fora de -1).

ALTER TYPE public.pagamento_forma ADD VALUE IF NOT EXISTS 'permuta';
