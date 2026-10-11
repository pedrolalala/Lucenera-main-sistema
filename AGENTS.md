# Instrucao Geral para IA e Desenvolvedor

Este arquivo define o fluxo padrao para qualquer pessoa ou agente que trabalhe no ecossistema Lucenera.

## Objetivo

Manter a mesma memoria entre cliente, desenvolvedor, IA, repositorios dos sistemas e repositorio central.

O repositorio central `Lucenera - ADAPTA PASS` guarda o contexto do ecossistema. Cada sistema continua tendo seu repositorio proprio para codigo e deploy.

Os sistemas com repositorio proprio devem ser carregados como submodules dentro de `04-Sistemas/`.

Clone recomendado:

```bash
git clone --recurse-submodules <URL_DO_REPO_CENTRAL> "Lucenera - ADAPTA PASS"
cd "Lucenera - ADAPTA PASS"
./scripts/submodules-clone-all.sh
```

## Arquivo .env local

O acesso ao Supabase deve usar o arquivo `.env` geral, criado manualmente na raiz do repositorio central `Lucenera - ADAPTA PASS`.

O `.env` nao deve ser commitado no GitHub. O arquivo versionado e apenas `.env.example`, sem valores reais.

Variaveis esperadas:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_DB_URL`

Usar essas variaveis quando precisar consultar o Supabase real, gerar snapshot, validar schema, aplicar migration ou rodar scripts administrativos. Nunca imprimir valores reais em logs, commits, PRs ou respostas.

## Antes de alterar qualquer coisa

1. Leia `README.md`.
2. Leia `00-Contexto/FLUXO_DE_TRABALHO.md`.
3. Leia `04-Sistemas/00 - Sumario Sistemas.md`.
4. Identifique quais sistemas serao afetados.
5. Leia a SPEC relacionada em `03-Projeto/Planos de Ação/SPECs/`.
6. Se nao existir SPEC, crie uma antes de implementar usando `03-Projeto/Planos de Ação/SPECs/_TEMPLATE_SPEC.md` e siga `00-Contexto/COMO_CRIAR_SPEC.md`.

## Antes de alterar banco

1. Leia `supabase/README.md`.
2. Leia `supabase/docs/ai_context_global.md`.
3. Leia `supabase/docs/relationships.md`.
4. Leia o dominio afetado em `supabase/db/domains/`.
5. Consulte `supabase/db/current/` para nomes reais de tabelas, colunas, views, funcoes, triggers, storage e RLS.
6. Confirme que o `.env` local existe quando for acessar o Supabase real.
7. Crie alteracoes em `supabase/db/migrations/YYYYMMDD_NNN_nome_do_grupo/`.
8. Atualize o contexto local do sistema afetado em `04-Sistemas/<sistema>/supabase/AI_DB_CONTEXT.md` quando a decisao impactar aquele app.

Nunca invente tabela, coluna, funcao ou policy sem verificar o snapshot central.

### Seguranca do banco (SPEC-196, 11/10/2026)

A chave `anon` vai dentro de todo site; quem protege os dados e o banco, nao a tela.

1. Tabela nova: sempre `ENABLE ROW LEVEL SECURITY` e `REVOKE ALL ... FROM anon` (o Supabase da grant para `anon` por padrao).
2. Nunca `USING (true)` / `WITH CHECK (true)` para `authenticated` em dado financeiro, de RH ou pessoal. Use `(SELECT public.pode_acessar_sistema('<slug>'))` (Acesso a Sistemas) — sempre dentro de `(SELECT ...)`, nunca chamada por linha.
3. View de dono `postgres` pula o RLS das tabelas de baixo: view com dado sensivel precisa de portao no `WHERE` (ex.: `pode_acessar_sistema`) e nunca grant para `anon`.
4. Pagina publica (sem login) le dados so por RPC `SECURITY DEFINER` que filtra o necessario. Hoje o unico acesso `anon` liberado e o site do Showroom (`vw_showroom_publico`, `showroom_import_pecas`).
5. Mais de uma politica permissiva para o mesmo comando = vale a mais aberta. Ao trocar uma politica, apague as antigas.
6. Depois de mexer em permissao, testar como `anon` e como um usuario sem o sistema (ex.: auxiliar de estoque), em ROLLBACK.

## Fluxo de implementacao

1. Atualize ou crie a SPEC no repo central.
2. Implemente no repositorio proprio do sistema afetado.
3. Rode as verificacoes cabiveis do sistema.
4. Atualize o contexto local do sistema, se a mudanca alterar banco, regras ou fluxo.
5. Atualize `CHANGELOG.md` no repo central.
6. Atualize relatorios, escopos, reunioes ou pendencias quando a mudanca alterar entendimento do negocio.
7. Commit e push no repositorio do sistema.
8. Atualize o ponteiro do submodule no repo central.
9. Commit no repositorio central.

## Quando a mudanca envolver varios sistemas

Criar uma SPEC unica no repo central com:

- sistemas afetados;
- tabelas, views, funcoes e relacionamentos envolvidos;
- ordem de implementacao;
- criterio de aceite por sistema;
- plano de rollback;
- lista de documentos que precisam ser atualizados.

## Changelog obrigatorio

Toda mudanca relevante deve registrar em `CHANGELOG.md`:

- data;
- sistema ou area afetada;
- resumo objetivo;
- documentos/specs alterados;
- impacto no banco, se houver;
- repositorios que precisam receber commit.

## Nao fazer

- Nao tratar migrations antigas dentro de `04-Sistemas/*/supabase/migrations` como fonte final do banco.
- Nao duplicar o banco inteiro dentro de cada sistema.
- Nao alterar codigo de sistema sem verificar o impacto no ecossistema.
- Nao criar regra de permissao hardcoded se ela deveria vir do Hub/TI.
- Nao usar arquivos de reuniao como unica fonte se ja houver decisao consolidada em SPEC, escopo ou `supabase/`.
- Nao atualizar ponteiro de submodule para commit local que ainda nao foi enviado ao GitHub.
- Nao commitar `.env` ou qualquer segredo do Supabase.
