# Como Criar ou Atualizar uma SPEC

Use SPEC sempre que uma mudanca alterar comportamento, banco, fluxo operacional, permissao, integracao, relatorio ou mais de um sistema.

## Onde criar

Criar em:

```text
03-Projeto/Planos de Ação/SPECs/
```

Usar o template:

```text
03-Projeto/Planos de Ação/SPECs/_TEMPLATE_SPEC.md
```

Nome padrao:

```text
SPEC-XXX_Titulo_Curto_Em_Snake_Case.md
```

## Antes de escrever

1. Ler `03-Projeto/00_INDICE.md`.
2. Ler os escopos dos sistemas afetados em `03-Projeto/Escopos/`.
3. Ler `04-Sistemas/00 - Sumario Sistemas.md`.
4. Se envolver banco, ler `supabase/docs/ai_context_global.md`, `supabase/docs/relationships.md` e o dominio em `supabase/db/domains/`.
5. Se veio de reuniao, ler a ata, fluxos e pendencias relacionados em `02-Reunioes/`.

## Conteudo minimo

A SPEC precisa deixar claro:

- objetivo;
- sistemas envolvidos;
- estado atual;
- mudanca proposta;
- impacto no banco;
- impacto em telas, relatorios ou automacoes;
- regras de permissao;
- criterios de aceite;
- testes/verificacoes obrigatorias;
- passos manuais do usuario;
- pendencias conhecidas.

## Analise obrigatoria de ecossistema

Antes de aprovar a SPEC, responder dentro dela:

- Esta mudanca depende de `projetos`, `orcamentos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios`, `systems` ou `user_system_access`?
- A mudanca afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logistica, RH ou Hub/TI?
- Existe dado duplicado que deve ser derivado por relacionamento?
- Existe migration antiga em algum sistema que contradiz o snapshot central?
- A mudanca exige atualizacao de `AI_DB_CONTEXT.md` em algum sistema?

## Durante a implementacao

Atualizar a SPEC conforme o trabalho avanca:

- marcar checklist apenas quando concluido;
- adicionar novos itens descobertos;
- registrar decisoes aprovadas;
- registrar o que foi realizado por data;
- manter pendencias autocontidas.

## Depois da implementacao

Atualizar:

- `CHANGELOG.md`;
- docs de `supabase/`, se houver impacto tecnico;
- escopo ou relatorio afetado, se a regra de negocio mudou;
- contexto local do sistema afetado.

