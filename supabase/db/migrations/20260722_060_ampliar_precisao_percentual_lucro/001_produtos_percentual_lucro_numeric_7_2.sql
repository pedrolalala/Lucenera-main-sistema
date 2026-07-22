-- SPEC: import pontual de 22/07/2026 (Produtos__2026-07-22.xlsx)
-- Achado: produtos.percentual_lucro é numeric(5,2) (máx 999,99), e
-- scripts/importar_produtos_estoque.py falhou com "numeric field overflow"
-- em 2 produtos de custo quase zero (codigo_produto 8656 "SINAL" e 10864
-- "PINTURA ELETROSTATICA MARROM MICRO", custo R$0,10 / venda R$1,25 ->
-- lucro 1150%, valor legítimo da planilha, não erro de cadastro).
-- Amplia a precisão para não perder atualizações futuras de itens de
-- custo residual com margem percentual alta.
ALTER TABLE produtos
  ALTER COLUMN percentual_lucro TYPE numeric(9, 2);
