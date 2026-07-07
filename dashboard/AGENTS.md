# Instrucao da Pasta dashboard

Esta pasta e um dashboard administrativo em Streamlit (Python) que le views do Supabase central para dar visao consolidada de projetos, financeiro, estoque, logistica, CRM e RH.

Ver `COMO_USAR.md` para instalacao, configuracao e lista de views usadas por pagina.

## Regras

- So ler dados via views ja existentes no Supabase (`vw_*`, `v_*`) listadas em `COMO_USAR.md`. Nao criar tabela ou logica de negocio nova aqui.
- Se uma pagina precisar de um dado que nenhuma view expoe, resolver criando/alterando a view no `../supabase/` do repo central (com SPEC), nao com query ad-hoc duplicando regra de negocio.
- Usar a service role key do Supabase apenas no `.env` local deste dashboard; nunca commitar `.env` nem imprimir a chave.
- Ao adicionar pagina nova em `pages/`, atualizar a tabela de paginas em `COMO_USAR.md`.

## Antes de alterar

1. Ler `COMO_USAR.md`.
2. Confirmar a view/tabela real em `../supabase/db/current/` ou `../supabase/docs/table_index.md`.
3. Rodar localmente (`streamlit run app.py`) para validar antes de dar como concluido.
