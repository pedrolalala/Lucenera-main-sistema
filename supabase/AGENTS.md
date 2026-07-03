# Instrucao da Pasta Supabase

Esta pasta e a fonte de verdade tecnica do banco Lucenera dentro do repositorio central.

## Antes de qualquer mudanca

1. Ler `README.md`.
2. Ler `docs/ai_context_global.md`.
3. Ler `docs/relationships.md`.
4. Ler `docs/table_index.md`.
5. Ler o dominio afetado em `db/domains/`.
6. Consultar `db/current/` para nomes reais de objetos.

## Acesso ao Supabase real

Quando precisar consultar o banco real, gerar snapshot, validar schema, aplicar migration ou rodar script administrativo, usar o `.env` geral da raiz do repositorio central.

O `.env` deve ser criado manualmente e nao deve ser commitado.

Variaveis esperadas:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_DB_URL`

Nunca imprimir nem copiar valores reais dessas variaveis para documentos, commits, logs ou respostas.

## Regras

- Migrations novas devem ficar em `db/migrations/YYYYMMDD_NNN_nome_do_grupo/`.
- Snapshot aplicado deve ser refletido em `db/current/`.
- Decisao estrutural deve atualizar `docs/ai_context_global.md` ou o documento de dominio.
- Relacionamento novo ou alterado deve atualizar `docs/relationships.md`.
- Status/enums devem atualizar `docs/status_enums.md`.
- Mudanca que afete um sistema deve atualizar o `AI_DB_CONTEXT.md` local daquele sistema.

## Nao fazer

- Nao usar migrations antigas dos sistemas como fonte final.
- Nao criar objeto novo sem verificar se ja existe no snapshot.
- Nao duplicar chave ou dado que pode ser derivado por relacionamento aprovado.
- Nao alterar RLS/policies sem registrar risco e criterio de teste.
