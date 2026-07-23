# Decisões — Projeto Cruzamento de Dados

Registro cronológico das decisões tomadas neste projeto (preenchimento de `cliente_id`/`responsavel_id` em projetos e ligação do histórico de vendas). Ver `AGENTS.md` nesta pasta para o contexto completo e o backlog.

## 2026-07-23

### Cruzamento 1 (Projeto → Cliente) aplicado — 546 de 3.182 projetos

Antes de aplicar, o usuário pediu uma estimativa de impacto. Simulação contra o banco real (usando `Cliente`/`Financeiro` da planilha + nomes já cadastrados em `contatos`) mostrou que só uma fração dos projetos sem cliente tem pista rastreável:

- **546 com match seguro** (código do projeto embutido no nome/razão do cliente em alguma fonte, ou nome do projeto batendo exatamente com o nome de um cliente — ambos únicos, sem ambiguidade).
- **7 em conflito** (código e nome apontam para clientes diferentes) — não aplicados. Ao menos um caso investigado (projeto 22.017, "SOLANGE BIAGI") revelou que é o mesmo cliente cadastrado duas vezes (`SOLANGE BIAGI` e `22017 SOLANGE BIAGI`) — sinaliza que os 7 conflitos são candidatos fortes para o cruzamento 8 (detecção de duplicados), não erro de lógica.
- **2.629 sem nenhuma pista** em nenhuma fonte disponível (nem planilha, nem cadastro já migrado) — ampliar o regex para aceitar códigos de 4 a 6 dígitos (não só o padrão de 5) e incluir `contatos.nome` como fonte adicional só resolveu +2 casos, confirmando que a ausência é real, não uma limitação da busca.

**Aplicado:** os 546 em uma transação (`psycopg2`, `autocommit=False`), com verificação de amostra e contagem exata antes do commit. `projetos.cliente_id` foi de 519 → 1.065 preenchidos (de 3.701 projetos totais — 1 projeto novo, `26.180 FACHADA CASACOR 2026`, foi criado ao vivo pela equipe durante esta sessão, fora do escopo do cruzamento).

**Nota de segurança:** a primeira tentativa de aplicar falhou por um bug na query de verificação (`uuid = text` sem cast) — a transação inteira foi revertida automaticamente pelo Postgres antes de qualquer escrita permanente, confirmando que o padrão "transação + verificação antes do commit" do `AGENTS.md` funciona como esperado.

**Pendente:** os 2.629 sem pista e os 7 conflitos ficam para uma rodada futura, com outra fonte de dados ou revisão manual — não fazem parte deste cruzamento.

### Cruzamento 7 (Completar cadastro do cliente) aplicado — só 14 clientes, planilha já era a fonte original

Tentativa de completar telefone/email/endereço via planilha `Cliente` (match por `codigo_legado`), preenchendo só onde `contatos` estava `NULL`. Resultado bem menor que os outros cruzamentos: **14 clientes** afetados no total (9 telefone, 9 email, 9 email_financeiro, 9 endereço, 11 bairro, 9 cidade, 9 estado). A cobertura já estava em ~82-90% antes de mexer — indício de que essa planilha `Cliente` já foi a fonte original usada pra importar `contatos` (bate com o comentário do schema: `razao_social` "Equivale ao campo rzCliente da planilha de importação"). Aplicado direto (baixo risco, só preenche nulo, nunca sobrescreve).

### Cruzamento 6 (Projeto → Arquiteto) aplicado — 1.610 de 3.039 projetos; Responsável de Obra sem dado aproveitável

- `arquiteto_id` preenchido via `projetos."Nome Arquiteto"` (já 71% preenchido no banco, sem precisar da planilha) → nome exato contra `contatos` tipo=`arquiteto`. 1.970 candidatos, 1.610 com match único e seguro (0 ambíguos), 360 sem contato correspondente. `arquiteto_id`: 662 → 2.272.
- `responsavel_obra_id` (aponta pra `usuarios`, só 9 pessoas) — testado contra a coluna "Responsável da Obra" da planilha legado: **0 de 814 batem**. Os valores são nomes de arquitetos/escritórios (ex: "MF+", "A+L", nomes de terceiros), não um dos 9 usuários internos do sistema — não há como resolver automaticamente com o dado disponível. Não aplicado.
- `equipe_responsavel_obra_id` já estava 44% preenchido (1.635/3.701) por outro processo, fora do escopo desta investigação.

### Cruzamento 5 (Financeiro → Projeto) aplicado — 2.132 de 12.750 negociações

Preenchido `negociacoes.projeto_id` via `cod_venda` (já presente em `negociacoes`) → planilha `venda` → `NomeCliente` com código do projeto embutido → `projetos.codigo`. Mesma lógica de resolução de projeto usada nos cruzamentos 1/3.

- 12.750 negociações totais; 309 sem `cod_venda` (sem via de resolução); das 12.441 com `cod_venda`, só 2.132 (17%) batem com um `CodVenda` que aparece na planilha `venda` E resolve um projeto único.
- Cobertura baixa é o mesmo gargalo recorrente: falta o código do projeto rastreável na maioria das transações antigas.
- Aplicado em transação com verificação de amostra antes do commit. `negociacoes.projeto_id`: 0 → 2.132 preenchidos.
- `transacoes` não tem coluna `projeto_id` própria — herda o vínculo via `negociacao_id`, não precisou de UPDATE separado.

### Cruzamento 3 (Vendas) — pausado, ver arquivo dedicado

Investigação extensa feita (arquitetura real via `aprovar_orcamento_financeiro`, cobertura de 998/2.042 pra GrupoCFOP=VENDAS, colunas novas em `vendas` já aplicadas). Usuário pediu pra desconsiderar as decisões técnicas tomadas e pausar — ver **`CRUZAMENTO-3-VENDAS.md`** (mesma pasta) pra estado completo, números e pendências antes de retomar.

### Cruzamento 2 (Projeto → Responsável) aplicado — 1.774 de 2.901 projetos

Usuário pediu para aplicar direto, sem etapa de estimativa em separado — mesmo assim rodei com a mesma disciplina (transação + verificação de amostra antes do commit).

- 2.901 projetos tinham `responsavel_nome` preenchido e `responsavel_id` vazio.
- **1.774 com match seguro** (nome bate, case-insensitive/trim, com um dos 9 usuários reais: Marina, Lana, Vinicius, Filippo, Thairine, Pedro, pedrollaghi, Mariane, kimberly).
- **1.127 sem match** — nomes históricos sem usuário correspondente (Ricardo, Thais, Bender, Angélica, Ligia, Rianne, Amanda, Vilber, Mary, Eduardo, Terezinha, Lais e variações de acentuação/maiúsculas). Continuam só com `responsavel_nome` (texto), sem `responsavel_id`.
- `projetos.responsavel_id`: 394 → 2.168 preenchidos.
- Nenhum nome de usuário duplicado (checagem de segurança antes de aplicar).

### Backlog aprovado: 9 cruzamentos, em ordem, um de cada vez

Depois de analisar `Cruzamento de dados.xlsx` e validar contra o Supabase real, o usuário aprovou subir os cruzamentos aos poucos, nesta ordem:

1. Projeto → Cliente
2. Projeto → Responsável
3. Vendas → Projeto
4. Vendas → Cliente
5. Financeiro → Projeto
6. Projeto → Arquiteto / Responsável de Obra
7. Completar cadastro do cliente (telefone/e-mail)
8. Detecção de clientes duplicados
9. Ranking de responsável/vendedor

Cada item só é implementado com autorização explícita, um por vez.

### Achados de validação (antes do cruzamento 1)

- **`projetos.cliente_id`**: só 518 de 3.700 projetos (14%) preenchidos.
- **`projetos.responsavel_id`**: só 394 de 3.700 (11%) preenchidos; 3.294 (89%) têm só `responsavel_nome` (texto livre). Só 9 usuários reais existem em `usuarios` — nem todo nome histórico tem correspondência.
- **`contatos.codigo_legado`**: 2.881 de 3.859 preenchidos. 241 códigos aparecem em mais de um registro, mas **sempre em tipos diferentes** (ex: mesma pessoa como `cliente` e `arquiteto`) — 0 casos de duplicidade real (mesmo código + mesmo tipo). Cruzamento seguro desde que sempre filtre por código + tipo.
- **`public.vendas`**: só 263 linhas (vendas de 2024 em diante), `cod_venda` e `cod_cliente` 100% vazios. A planilha `venda` tem 22.172 linhas históricas — confirma que o cruzamento 3 é uma importação de histórico, não só uma conferência.

### Decisão: `projetos.client_id` removido

`client_id` era uma segunda coluna de referência a cliente em `projetos`, duplicada de `cliente_id`, nunca preenchida (0 de 3.700). Antes de remover, validado:

- **Nenhum sistema (dos 11) usa `client_id` no código de aplicação.** As únicas ocorrências da string `client_id` encontradas eram falsos positivos (client_id OAuth do SharePoint; chave `ubiqua_client_id` do carrinho do Ubiqua no localStorage).
- **Mas o banco usava, sim** — 10 views dependiam de `client_id`. 4 delas (`vw_projetos_pipeline`, `vw_projetos_por_status`, `vw_financeiro_projetos`, `vw_dashboard_crm_fechamento` — telas de Pipeline, Status, Financeiro por Projeto e Fechamento do CRM) usavam **só** `client_id`, sem fallback — como a coluna nunca foi preenchida, essas 4 telas mostravam cliente/contagem vazios para **100% dos projetos**, um bug pré-existente descoberto por esta validação. As outras 6 views (estoque/compras) já usavam `client_id` só como último fallback num `COALESCE`, então já toleravam a ausência.

**Ação tomada:** as 10 views foram recriadas para usar `cliente_id`; índice e FK de `client_id` removidos; coluna `client_id` removida de `projetos`. Aplicado em produção em 2026-07-23. Detalhes técnicos e verificação em `supabase/db/migrations/20260723_061_remove_projetos_client_id/README.md`.

**Efeito colateral positivo:** as 4 telas que estavam sempre vazias para cliente agora mostram dados reais (ex: `vw_projetos_por_status` passou a retornar contagens reais de cliente por status, como 129 clientes em "Obra Finalizada", antes sempre 0).

### Fonte de dados para os próximos cruzamentos: usar a pasta `Atualização DD.MM.AAAA/`, não a planilha original

A planilha `Cruzamento de dados.xlsx` tem os dados de `Financeiro` desatualizados. A pasta `01-Documento/01 - Planilhas/Atualização 23.07.2026/` tem exports mais recentes (`ContaPagar_2026-07-23.xlsx`, `ContaReceber_2026-07-23.xlsx` — mesma estrutura da aba `Financeiro`; `PedidoCompra_2026-07-23.xlsx`; `Produtos__2026-07-23.xlsx`). Os cruzamentos que dependem da aba `Financeiro` (resolução de `cod_pessoa`/`razao_pessoa`) devem usar essa versão mais nova antes de rodar o cruzamento 1 em produção.
