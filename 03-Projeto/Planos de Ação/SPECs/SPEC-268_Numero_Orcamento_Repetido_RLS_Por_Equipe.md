---
titulo: "SPEC-268 — Número de orçamento repetido (RLS por equipe)"
status: concluído
data_ultima_modificacao: 2026-11-11
sistemas_envolvidos:
  - Orçamentos
  - Banco (Supabase São Paulo)
---

# SPEC-268 — Número de orçamento repetido (RLS por equipe)

## Checklist de Ação

- [x] Causa confirmada e reproduzida com ROLLBACK (10/11).
- [x] Migration **321** redigida: `set_orcamento_numero()` passa a `SECURITY DEFINER` com `pg_advisory_xact_lock`.
- [x] Ensaio com ROLLBACK: antes, a Marina (projetista) gerou ORC-0010 com o maior real em ORC-0014; depois, gerou ORC-0015. Número informado à mão continua respeitado; anon barrado.
- [x] Aplicar a migration 321 no banco de São Paulo (autorizada e aplicada em 10/11).
- [x] Decisão (11/11, revista no mesmo dia): numerar TODOS os orçamentos ORC-… pela data e hora de criação, todas as equipes juntas (o mais antigo é ORC-0001). Substitui a ideia de manter o mais antigo e renumerar só os 10 repetidos.
- [x] Migration **330** redigida (`20261111_330_spec268_renumerar_orcamentos_repetidos`, up/rollback) e ensaiada em ROLLBACK. **APLICADA em 11/11** (autorizada pelo usuário).
- [x] Aplicar a migration 330 em São Paulo (feito em 11/11, uma transação com conferências antes do COMMIT).
- [x] Índice único `orcamentos_numero_uidx` em `orcamentos(numero)`: criado pela migration 330 (vale para todas as origens: os números CNX-… também são únicos).

### Passos manuais do usuário

- [x] Autorizar a aplicação da migration 321.
- [x] Decidir a regra dos duplicados existentes (renumerar; decidido em 11/11).
- [x] Autorizar a aplicação da migration 330 ("vamos renomear tudo", 11/11).

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

- SPEC criada; causa reproduzida; migration 321 ensaiada com ROLLBACK e APLICADA (autorizada). Conferido: função SECURITY DEFINER com search_path; inserção da Marina (ROLLBACK) gerou o máximo real + 1 (ORC-0016, depois de alguém criar o ORC-0015 no meio). Duplicados existentes não alterados.

### 2026-11-11

- Reunião 49 (Carol): a Venda Parcial misturava vendas com o mesmo número (SPEC-280). Decisão do usuário: o número de orçamento é um só para todas as equipes (Administração, estoque e logística tratam como uma coisa só); os repetidos antigos serão renumerados.
- Migration 330 (rascunho): renumera por id TODOS os ORC-… na ordem de criação (ORC-0001, 0002, … de todas as equipes juntas) e atualiza o que é ligado por id: boletos (3 documentos pendentes de registro), título financeiro, parcelas do legado, negociações, separações/entregas e histórico de estoque do item; de/para guardado em `backup.spec268_renumeracao_orcamentos`; índice único no fim.
- Ensaio em ROLLBACK em SP: **39 dos 40 orçamentos mudam de número** (VENDA-8508 passa de ORC-0002 para ORC-0007), 0 duplicados e 0 fora da ordem cronológica depois, parciais coerentes (10 separações, 7 boletos, 8 títulos atualizados), inserção com número repetido barrada pelo índice, `rollback.sql` devolve o estado idêntico, produção intacta. Relatório com o de/para completo: `03-Projeto/Auditoria/Relatorio_Numero_Orcamento_e_Venda_Parcial_2026-11-11.html` (local, fora do GitHub).
- Não altera: `estoque_kardex.historico` (3 linhas em texto livre sem ligação por id) e PDFs/XML já enviados ao cliente ou à Connect com o número antigo.

- **Migration 330 APLICADA em SP (11/11 ~12:00):** 40 dos 41 orçamentos ORC-… trocaram de número (de/para em `backup.spec268_renumeracao_orcamentos`, 40 linhas); 0 repetidos, 0 fora da ordem cronológica, parciais coerentes, índice único `orcamentos_numero_uidx` ativo, tabela de backup com RLS e sem acesso `anon`. VENDA-8508 = ORC-0007. Visibilidade por equipe confirmada em teste como membro de cada equipe (já era por `equipe_id`, independente do número). Relatório final: `03-Projeto/Auditoria/Relatorio_Numero_Orcamento_e_Venda_Parcial_2026-11-11.html`.

## Pendências

- [x] (feito) Migration 321 aplicada em 10/11.
- [ ] Os orçamentos já repetidos (19 orçamentos em 9 números, ORC-0001 a ORC-0009): renumerar os mais novos (o número aparece em PDF, XML e exportações) ou manter e só impedir novos? Decisão do usuário.
- [ ] Índice único depois da decisão acima.
