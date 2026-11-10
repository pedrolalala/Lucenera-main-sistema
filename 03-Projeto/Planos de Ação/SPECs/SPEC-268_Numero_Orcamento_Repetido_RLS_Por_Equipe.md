---
titulo: "SPEC-268 — Número de orçamento repetido (RLS por equipe)"
status: pendente
data_ultima_modificacao: 2026-11-10
sistemas_envolvidos:
  - Orçamentos
  - Banco (Supabase São Paulo)
---

# SPEC-268 — Número de orçamento repetido (RLS por equipe)

## Checklist de Ação

- [x] Causa confirmada e reproduzida com ROLLBACK (10/11).
- [x] Migration **321** redigida: `set_orcamento_numero()` passa a `SECURITY DEFINER` com `pg_advisory_xact_lock`.
- [x] Ensaio com ROLLBACK: antes, a Marina (projetista) gerou ORC-0010 com o maior real em ORC-0014; depois, gerou ORC-0015. Número informado à mão continua respeitado; anon barrado.
- [ ] Aplicar a migration 321 no banco de São Paulo (autorização do usuário).
- [ ] Decidir o que fazer com os 19 orçamentos com número repetido (9 números) (ver Pendências).
- [ ] Depois de resolver os repetidos: índice único em `orcamentos(numero)` onde `origem = 'sistema'` (ou por empresa, conforme decisão).

### Passos manuais do usuário

- [ ] Autorizar a aplicação da migration 321.
- [ ] Decidir a regra dos duplicados existentes.

## Objetivo

Acabar com orçamentos do sistema com o mesmo número (hoje MANOELLA tem ORC-0004 ×2 e ORC-0005 ×3; ORC-0001 a ORC-0009 se repetem). Isso confunde quem fala só pelo número e quebra qualquer relatório ou exportação que use `orcamentos.numero`.

## Decisões aprovadas

- Nenhuma ainda além do pedido do usuário (10/11) de corrigir o erro apontado pela análise do Filippo.

## Definição da SPEC

- **Causa:** o gatilho `trigger_set_orcamento_numero` chama `set_orcamento_numero()`, que faz `MAX(numero)+1` **como o usuário que insere**. A RLS por equipe (SPEC-200, política `spec200_orcamentos_equipe`) esconde os orçamentos de outras equipes, então o máximo visto é parcial. Exemplo reproduzido: a Marina enxerga 94 orçamentos com máximo ORC-0009 e gera ORC-0010, enquanto o máximo real é ORC-0014. Sem `LOCK`, dois cadastros simultâneos também podem pegar o mesmo número.
- **Todas as repetições** aparecem entre 05 e 10/11 (depois da limpeza de teste de outubro e da entrada de equipes com RLS).
- **Correção (migration 321):** função como dono do banco (enxerga tudo) + `pg_advisory_xact_lock(hashtext('orcamentos_numero_orc'))`. Formato `ORC-NNNN` inalterado. Só os números vazios são gerados; número informado é respeitado.
- **Não faz:** renumerar os duplicados existentes; criar índice único (não dá enquanto houver repetidos).
- **Rollback:** `rollback.sql` devolve a função anterior.

## Realizado

### 2026-11-10

- SPEC criada; causa reproduzida; migration 321 redigida e ensaiada com ROLLBACK (nada aplicado).

## Pendências

- [ ] Aplicar a migration 321 — aguarda autorização.
- [ ] Os orçamentos já repetidos (19 orçamentos em 9 números, ORC-0001 a ORC-0009): renumerar os mais novos (o número aparece em PDF, XML e exportações) ou manter e só impedir novos? Decisão do usuário.
- [ ] Índice único depois da decisão acima.
