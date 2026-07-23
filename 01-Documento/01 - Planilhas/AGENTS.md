# Cruzamento de Dados — instruções para IA e desenvolvedor

Este arquivo é a fonte de verdade para quem continuar o projeto de "Cruzamento de Dados" nesta pasta. Leia antes de mexer em qualquer planilha ou rodar qualquer cruzamento novo.

## O que é este projeto

`Cruzamento de dados.xlsx` (raiz de `Lucenera - ADAPTA PASS/`) é uma planilha com fórmulas (`XLOOKUP`, exportadas do Google Sheets) que tenta achar, para cada projeto/venda/responsável antigo, o cadastro real correspondente no Supabase — e assim preencher `cliente_id`, `responsavel_id` e ligar o histórico de vendas aos projetos certos.

Abas principais da planilha:
- `Financeiro` — export bruto de Contas a Pagar/Receber do sistema legado (cod_pessoa, razao_pessoa, cod_venda...). **Está desatualizada** — usar sempre a versão mais recente da subpasta `Atualização DD.MM.AAAA/` (ver abaixo).
- `projetos` — export do sistema de projetos legado (Código, Projeto, Responsável, Status, Data Entrada).
- `venda` — export do sistema de vendas legado (22 mil+ linhas históricas). Ainda não importado para `public.vendas` (que hoje só tem as vendas recentes, 2024+).
- `Cliente` — export de cadastro de clientes legado (codCliente, docCliente, nmCliente, rzCliente...).
- `projetos_supabase`, `contatos_supabase`, `usuarios_supabase` — dumps das tabelas reais do Supabase (`projetos`, `contatos`, `usuarios`) no momento da exportação. **Sempre revalidar contra o banco real antes de qualquer cruzamento** — esses dumps ficam desatualizados rápido.
- `Consolidação` — onde o cruzamento de fato acontece: liga `projetos` (legado) ↔ `projetos_supabase` pelo código, resolve `responsavel_id` (nome → `usuarios_supabase`) e `contato.id` (código legado + tipo → `contatos_supabase`).
- `Base de vendas` / `Página10` — cruzam cada venda com o `projeto_id` certo (via código embutido no nome do cliente da venda) e, a partir daí, com o cliente certo.

### Pasta `Atualização DD.MM.AAAA/`

Contém exports mais recentes de Contas a Pagar/Receber, Pedido de Compra e Produtos (mesma estrutura da aba `Financeiro`/relacionadas). **Sempre usar a versão mais recente disponível** como fonte para os cruzamentos, em vez das abas estáticas da planilha original — a planilha original é só o protótipo das fórmulas, não a fonte de dados definitiva.

## Regras aprendidas (não repetir a investigação)

1. **Sempre confirmar contra o banco real antes de aplicar qualquer cruzamento.** Os dumps `*_supabase` da planilha são um retrato antigo. Use `SUPABASE_DB_URL` do `.env` da raiz (`Lucenera - ADAPTA PASS/.env`) com `psycopg2` para consultar o Supabase ao vivo. Nunca imprimir a chave/URL em logs ou respostas.
2. **Duplicidade em `contatos.codigo_legado`: checar sempre por (código + tipo), nunca só pelo código.** É normal e esperado a mesma pessoa aparecer como `cliente` e `arquiteto` com o mesmo código legado (241 casos confirmados, 0 deles com ambiguidade real dentro do mesmo tipo). O cruzamento deve sempre filtrar `tipo` junto do código.
3. **`usuarios` tem só 9 contas reais.** `responsavel_id` só pode ser preenchido automaticamente para projetos cujo "Responsável" (nome livre) bate com um desses 9 nomes. Os demais nomes históricos (Ricardo, Thais, Bender, Angélica, Ligia, Rianne, Amanda, Vilber, Mary, Eduardo, Terezinha, Lais...) não têm usuário — decidir com o cliente se criam login histórico ou deixam só o nome em `responsavel_nome`.
4. **`public.vendas` está quase vazia (263 linhas, só 2024+).** O histórico de 22 mil+ vendas da aba `venda` ainda não foi importado — esse é o objetivo real do cruzamento 3/4 do backlog, não apenas "conferência".
5. **`projetos.client_id` foi removido em 2026-07-23** (ver `DECISOES.md` e `supabase/db/migrations/20260723_061_remove_projetos_client_id/`). Só existe `cliente_id` agora. Se algum dump antigo da planilha ainda tiver a coluna `client_id`, ignore — não existe mais no banco.
6. **Nunca implementar um cruzamento sem antes reportar o achado em texto simples para o cliente aprovar.** Este projeto tem o hábito de rodar aos poucos, um cruzamento por vez, com validação antes de cada um.

## Backlog dos 9 cruzamentos (ordem de execução)

1. **Projeto → Cliente** — preencher `cliente_id` dos projetos que só têm nome de cliente escrito (código do projeto → `Cliente`/`Financeiro` → `contatos.codigo_legado` + tipo=cliente). *(Em andamento — pré-requisito `client_id` já resolvido.)*
2. **Projeto → Responsável** — preencher `responsavel_id` via nome do responsável → `usuarios` (só cobre os 9 usuários ativos).
3. **Vendas → Projeto** — importar o histórico de vendas (planilha `venda`, 22 mil+ linhas) para `public.vendas`, preenchendo `projeto_id` via código embutido no nome do cliente da venda.
4. **Vendas → Cliente** — a partir do projeto já ligado (passo 3), completar a ligação da venda com o cliente certo.
5. **Financeiro → Projeto** — ligar contas a pagar/receber ao projeto de origem.
6. **Projeto → Arquiteto / Responsável de Obra** — mesmo processo do passo 2, para os outros dois papéis do projeto.
7. **Completar cadastro do cliente** — preencher telefone/e-mail faltantes usando as planilhas antigas.
8. **Detecção de clientes duplicados** — apontar cadastros que parecem ser a mesma pessoa/empresa escrita de formas diferentes.
9. **Ranking de responsável/vendedor** — depois de 2+3+4 prontos, gerar ranking automático de resultado por pessoa/período.

## Processo obrigatório para cada cruzamento novo

1. Ler este arquivo e `DECISOES.md` inteiros antes de começar.
2. Revalidar as suposições contra o banco real (não confiar só na planilha).
3. Rodar em uma transação (`psycopg2`, `autocommit=False`), com `SELECT` de verificação antes do `COMMIT`. Fazer `ROLLBACK` se qualquer checagem falhar.
4. Se a mudança envolver schema (coluna, view, índice, constraint), seguir o fluxo de `supabase/db/migrations/YYYYMMDD_NNN_nome/` do `AGENTS.md` da raiz do repositório central, com README explicando contexto/verificação.
5. Atualizar `supabase/db/current/01_schema_full.sql` se o schema mudar.
6. Atualizar `CHANGELOG.md` do repositório central.
7. Registrar a decisão em `DECISOES.md` (nesta pasta) com data, o que foi feito, e por quê.
8. Nunca aplicar um cruzamento em massa sem antes rodar numa amostra pequena e conferir manualmente alguns casos.
