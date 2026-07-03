# Estratégia de contexto por sistema

## Problema

Cada sistema tem sua própria pasta `supabase`, mas as migrations estão dispersas e não representam uma fonte de verdade confiável.

Se copiarmos o banco completo para dentro de todos os sistemas, a IA ganha contexto demais, repetido demais e com alto risco de divergência.

## Decisão

Usar três camadas:

1. Fonte central de verdade em `/supabase`.
2. Pacote local autocontido em `Sistema/<sistema>/supabase/`.
3. Migrations locais apenas como legado, histórico ou necessidade pontual do projeto.

## Pacote local por sistema

Cada sistema deve carregar um pacote mínimo de contexto dentro da própria pasta `supabase`.

Estrutura padrão:

```text
supabase/
  README.md
  ECOSSISTEMA_LUCENERA.md
  AI_DB_CONTEXT.md
  DB_CHANGE_REQUEST_TEMPLATE.md
```

Responsabilidade de cada arquivo:

- `README.md`: explica que o projeto é um módulo de um ecossistema maior e orienta a ordem de leitura.
- `ECOSSISTEMA_LUCENERA.md`: replica o contexto global mínimo necessário para um projeto aberto isoladamente.
- `AI_DB_CONTEXT.md`: traz o recorte real de banco e regras daquele sistema.
- `DB_CHANGE_REQUEST_TEMPLATE.md`: padroniza como registrar uma necessidade de alteração estrutural de banco.

## Decisão para projetos abertos isoladamente

Um sistema pode ser aberto sem acesso à pasta central do workspace.

Por isso, os documentos locais não devem depender de caminhos externos para serem úteis.

Eles devem explicar:

- qual é o ecossistema maior;
- qual é a responsabilidade do sistema;
- quais objetos reais do Supabase aquele sistema usa;
- quais decisões de negócio afetam aquele módulo;
- como registrar uma solicitação de mudança de banco quando o schema atual não atende.

O comportamento esperado quando faltar estrutura de banco é produzir uma solicitação clara usando `DB_CHANGE_REQUEST_TEMPLATE.md`, não inventar tabela/coluna/função no código.

## Como a IA deve começar em um sistema específico no workspace completo

Ao codar direto dentro de um sistema com acesso ao workspace completo, a IA deve ler nesta ordem:

1. `Sistema/<sistema>/supabase/README.md`
2. `Sistema/<sistema>/supabase/AI_DB_CONTEXT.md`
3. `/supabase/docs/ai_context_global.md`
4. Domínios citados no `AI_DB_CONTEXT.md`
5. `/supabase/docs/relationships.md`, se a alteração envolver relacionamento entre sistemas
6. `/supabase/db/current/`, apenas se a alteração depender de nomes exatos de tabela/coluna
7. `/supabase/db/migrations/`, apenas se for criar ou revisar alteração de banco

## Sobre “começar com Users e depois DB completo”

A ideia está correta, mas não deve virar uma cópia gigante dentro de cada sistema.

O melhor formato é central:

```text
supabase/db/migrations/20260625_001_snapshot_db_atual/
  001_auth_users_base.sql
  002_core_cadastros.sql
  003_orcamentos.sql
  004_financeiro.sql
  005_estoque_compras.sql
  006_logistica.sql
  007_rh.sql
  008_hub_ti.sql
  009_functions.sql
  010_views_triggers_storage.sql
```

Assim a IA entende a ordem lógica do banco sem precisar abrir um arquivo enorme ou duplicado em cada projeto.

## Quando copiar SQL para o sistema

Só copiar SQL para `Sistema/<sistema>/supabase/migrations` quando:

- o projeto precisar subir isolado em um ambiente próprio;
- a migration for temporária e específica do projeto;
- a equipe decidir que aquele sistema terá um banco independente.

Caso contrário, a alteração deve nascer na pasta central.

## Quando não copiar SQL para o sistema

Não copiar SQL para o sistema apenas para ajudar uma IA em um projeto isolado.

Para projetos isolados, o melhor é copiar contexto em Markdown, não migrations. Isso evita que uma alteração estrutural seja feita sem visão completa do ecossistema.

## Benefício prático

Cada sistema fica com contexto suficiente para uma IA trabalhar bem:

- o que este sistema faz;
- qual é o ecossistema maior;
- quais objetos reais de banco importam;
- quais relações de banco importam;
- como registrar necessidade de banco quando o schema atual não atende.

E o banco completo continua em um lugar só.
