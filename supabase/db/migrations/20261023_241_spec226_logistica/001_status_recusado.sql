-- SPEC-226 C: status novo para o pedido de separação recusado pelo estoque.
-- Fica sozinho (sem BEGIN) porque ADD VALUE não pode ser usado na mesma transação em que foi criado.
ALTER TYPE public.separacao_status ADD VALUE IF NOT EXISTS 'recusado';
