-- Migration 20260821_122 — SPEC-119
-- Coluna nova pra guardar o Código IBGE do Município do cliente, capturado
-- automaticamente na busca de CEP (SPEC-075) -- hoje a ViaCEP já devolve
-- esse dado e o front descartava. Sem esse código, a emissão de nota
-- fiscal no sistema legado falha (achado ao vivo na reunião 21/08).
-- Nullable, sem default: preenchimento é best-effort via CEP, nunca
-- bloqueia o cadastro quando não vier.

ALTER TABLE public.contatos
  ADD COLUMN IF NOT EXISTS ibge_cidade text;

COMMENT ON COLUMN public.contatos.ibge_cidade IS
'Código IBGE do município (7 dígitos), capturado automaticamente na busca de CEP quando a fonte (ViaCEP) devolve o campo. Usado para emissão de nota fiscal (SPEC-119). Nulo quando o CEP não veio da ViaCEP ou não foi preenchido.';
