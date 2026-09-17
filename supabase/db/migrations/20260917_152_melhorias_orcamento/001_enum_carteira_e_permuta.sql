-- SPEC-152 (reunião Vinícius 16/09/2026, decisões de negócio 17/09)
--
-- Adiciona 'carteira' ao ENUM public.pagamento_forma (forma de pagamento
-- nova, pedida na reunião) e garante 'permuta' (já tinha uma migration
-- redigida em 20260815_115_spec107_forma_pagamento_permuta, mas a
-- investigação desta SPEC (checando `src/lib/supabase/types.ts`, gerado do
-- banco) achou que o valor NÃO está no enum real hoje, apesar da SPEC-107
-- ter sido marcada "concluído" -- provável caso de "Skip drift"/migration
-- nunca de fato aplicada. `ADD VALUE IF NOT EXISTS` é idempotente: seguro
-- rodar aqui de novo mesmo que 115 já tenha sido aplicada.
--
-- ALTER TYPE ... ADD VALUE não pode rodar dentro de uma transação/BEGIN
-- junto de outros comandos que dependam do valor novo (erro
-- "unsafe use of new value of enum type") -- por isso este arquivo só tem
-- os dois ALTER TYPE, sem BEGIN/COMMIT explícito, e nenhum outro DDL. As
-- migrations seguintes desta pasta (que já usam 'carteira'/'permuta' em
-- CHECK/lógica de função) só podem ser aplicadas DEPOIS que este arquivo
-- for confirmado (commitado) no banco.

ALTER TYPE public.pagamento_forma ADD VALUE IF NOT EXISTS 'carteira';
ALTER TYPE public.pagamento_forma ADD VALUE IF NOT EXISTS 'permuta';
