# Fluxo de Trabalho Lucenera

Este fluxo deve ser seguido por desenvolvedor, IA ou qualquer pessoa que altere sistemas, banco, documentos ou specs.

## 1. Orientacao inicial

Antes de agir, identificar:

- pedido do usuario;
- sistemas afetados;
- tipo de mudanca: codigo, banco, relatorio, documento, planilha, reuniao, spec ou processo;
- se existe SPEC relacionada;
- se a mudanca pode afetar outros sistemas pelo banco.

Leitura minima:

1. `README.md`
2. `AGENTS.md`
3. `04-Sistemas/00 - Sumario Sistemas.md`
4. `03-Projeto/00_INDICE.md`
5. `supabase/README.md`

## 2. Mudanca simples de documento

1. Editar o documento central afetado.
2. Atualizar `CHANGELOG.md` se a mudanca altera entendimento, decisao, pendencia ou fluxo.
3. Referenciar reuniao, SPEC ou fonte quando houver.

## 3. Mudanca em sistema/app

1. Verificar qual repositorio proprio do sistema deve receber o codigo.
2. Confirmar que o submodule esta clonado em `04-Sistemas/<sistema>/`.
3. Ler o contexto central do banco se o app usa Supabase.
4. Atualizar ou criar SPEC em `03-Projeto/Planos de Ação/SPECs/`.
5. Implementar no repositorio do sistema.
6. Rodar verificacoes cabiveis.
7. Atualizar o contexto central afetado.
8. Registrar em `CHANGELOG.md`.
9. Commitar e enviar o sistema para o GitHub.
10. Atualizar o ponteiro do submodule no repo central.
11. Commitar o repo central, ou abrir PRs equivalentes.

## 4. Mudanca de banco

1. Confirmar que a necessidade esta descrita em SPEC.
2. Ler `supabase/docs/ai_context_global.md`.
3. Ler `supabase/docs/relationships.md`.
4. Ler `supabase/docs/table_index.md`.
5. Ler o dominio em `supabase/db/domains/`.
6. Consultar `supabase/db/current/` para nomes reais.
7. Confirmar que o `.env` local existe se for acessar o Supabase real.
8. Criar migration central em `supabase/db/migrations/YYYYMMDD_NNN_nome/`.
9. Atualizar `supabase/db/current/` depois que a mudanca for aplicada no banco real.
10. Atualizar docs de dominio, relacionamentos, status ou funcoes se necessario.
11. Atualizar `AI_DB_CONTEXT.md` do sistema afetado.

## 4.1 Arquivo `.env` geral

O arquivo `.env` deve ser criado manualmente na raiz do repositorio central e nunca deve ser commitado.

Use `.env.example` como modelo:

```bash
cp .env.example .env
```

Variaveis esperadas:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_DB_URL`

Use o `.env` para scripts que acessam o Supabase real, como consulta de schema, geracao de snapshot, validacao de migration e scripts administrativos.

## 5. Mudanca que cruza sistemas

Criar uma SPEC unica, mesmo que a implementacao aconteca em varios repositorios.

A SPEC deve responder:

- qual problema esta sendo resolvido;
- quais sistemas entram no fluxo;
- qual e o dado central compartilhado;
- quais tabelas, views, funcoes e storage sao afetados;
- qual e a ordem de implementacao;
- o que precisa ser testado em cada app;
- como reverter se uma parte falhar.

## 6. Registro final obrigatorio

Ao terminar, atualizar:

- SPEC: checklist, realizado e pendencias.
- `CHANGELOG.md`: resumo da mudanca.
- `supabase/`: se houve banco, relacionamento, funcao, RLS, storage ou decisao estrutural.
- `04-Sistemas/00 - Sumario Sistemas.md`: se mudou repo, pasta, prioridade ou status de sistema.
- Documento/escopo/relatorio afetado, se mudou regra de negocio.

## 7. Regra de commits

Para trabalho com codigo:

1. Commit e push no repositorio do sistema com a implementacao.
2. Commit no repositorio central com SPEC, changelog, contexto atualizado e ponteiro do submodule atualizado.

Para trabalho apenas de memoria/documentacao:

1. Commit apenas no repositorio central.

Quando houver PRs separados, a descricao do PR do sistema deve citar a SPEC central.

## 8. Regra de submodules

Para clonar tudo:

```bash
git clone --recurse-submodules <URL_DO_REPO_CENTRAL> "Lucenera - ADAPTA PASS"
cd "Lucenera - ADAPTA PASS"
./scripts/submodules-clone-all.sh
```

Para atualizar submodules depois de um `git pull` no repo central:

```bash
git submodule sync --recursive
git submodule update --init --recursive --jobs 8
```

Nunca commitar no repo central um ponteiro de submodule para commit que ainda nao foi enviado ao GitHub do sistema.
