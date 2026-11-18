# Como consultar o log de atividade (quem fez o quê, e quando)

Guia para quem tem acesso de leitura ao banco (Supabase SP) e quer, pelo próprio Claude, levantar o que um usuário fez em um dia e horário. Não precisa de nenhuma mudança no banco: tudo sai de `auditoria.eventos` e `financeiro_eventos`. As consultas abaixo foram testadas em 16/11/2026 com o caso "Vinicius, 13/11, 17:30 às 19:00" e dão o mesmo resultado do relatório que foi entregue (8 contas criadas, 7 baixas, R$ 24.500,00).

## Pedido pronto para colar no Claude

> Use o acesso ao banco só para LEITURA (nenhum INSERT, UPDATE, DELETE ou DDL). Consulte `auditoria.eventos` seguindo `03-Projeto/Auditoria/COMO_CONSULTAR_O_LOG_DE_ATIVIDADE.md`. Quero um relatório do que o usuário **[NOME]** fez em **[DD/MM/AAAA]** entre **[HH:MM]** e **[HH:MM]** (horário de Brasília): resumo por sistema e ação, contas criadas e baixadas (com valores), linha do tempo completa, e o que mais aparecer. Gere um Excel com as abas Resumo, Contas lançadas, Linha do tempo e Por sistema e ação.

## Onde está cada coisa

| Tabela | O que guarda | Colunas que importam |
|---|---|---|
| `auditoria.eventos` | Log de tudo que foi feito nos sistemas | `criado_em` (UTC), `usuario_nome`, `usuario_id`, `sistema`, `tipo`, `entidade`, `registro_id`, `referencia`, `mudancas` (jsonb), `ip`, `navegador` |
| `financeiro_eventos` | Histórico do financeiro novo (títulos, parcelas, baixas) | `criado_em`, `usuario_id`, `tabela`, `operacao`, `registro_id`, `antes`, `depois` |
| `usuarios` | Cadastro de quem entra no sistema | `id`, `nome`, `role` |

Valores de `tipo` mais comuns: `login`, `abriu_tela`, `criou`, `alterou`, `apagou`, `aprovou`, `mudou_status`. Valores de `entidade` mais comuns: `boletos`, `orcamentos`, `pedidos_compra`, `pedido_compra_parcelas`, `produtos`, `estoque_itens`, `separacoes`, `contatos`, `sessions` (login).
Valores de `sistema`: `contas-pagar`, `contas-receber`, `hub`, `separacao-parcial` e os demais sistemas.

## Cuidados (leia antes)

1. **Fuso horário.** `criado_em` está em UTC. Sempre converta com `at time zone 'America/Sao_Paulo'`. As consultas abaixo já fazem isso.
2. **Quem é o usuário.** Pesquise pelo nome exato em `usuarios` antes. Existem contas parecidas (por exemplo "Vinicius" admin e "vinicius_bortolin" visualizador). Confira `role`.
3. **"SQL direto".** Alterações feitas por script ou editor SQL aparecem com `usuario_nome` começando por `SQL direto (...)`, e o comando em `mudancas`. Isso NÃO é ação de um usuário do sistema: é quem mexeu no banco (às vezes o próprio Claude, a pedido). Separe esses registros do relatório do usuário.
4. **O que o log não cobre.** Importações e automações com chave de serviço e funções do cron ficam fora do log. O log não registra leitura de dados, só abertura de tela.
5. **Dados pessoais.** `ip` e `navegador` identificam pessoas. Use só se o relatório precisar e não compartilhe fora da empresa.
6. **Valores de baixa.** Em `mudou_status`, `mudancas` traz pares `[antes, depois]`, por exemplo `{"status": ["Aberto","Pago"], "valor_pago": [null, 4000], "forma_pagamento": [null,"PIX"]}`.

## Consultas (troque só o bloco `params`)

Em todas, o bloco `params` é a única coisa a editar.

### 0. Descobrir o usuário

```sql
select id, nome, role from usuarios where nome ilike '%vinicius%' order by nome;
```

### 1. Resumo por sistema e ação

```sql
with params as (select 'Vinicius'::text as usuario,
  timestamp '2026-11-13 17:30' as ini, timestamp '2026-11-13 19:00' as fim)
select e.sistema, e.tipo, e.entidade, count(*) as qtd
from auditoria.eventos e, params p
where e.usuario_nome = p.usuario
  and (e.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim
group by 1,2,3 order by qtd desc;
```

### 2. Contas criadas (boletos / Contas a Pagar e a Receber)

```sql
with params as (select 'Vinicius'::text as usuario,
  timestamp '2026-11-13 17:30' as ini, timestamp '2026-11-13 19:00' as fim)
select (e.criado_em at time zone 'America/Sao_Paulo') as quando, e.sistema, e.referencia,
       e.mudancas->>'tipo_operacao' as tipo_operacao,   -- CP = a pagar, CR = a receber
       e.mudancas->>'nome_pagador' as favorecido,
       (e.mudancas->>'valor')::numeric as valor,
       e.mudancas->>'vencimento' as vencimento,
       e.mudancas->>'status' as status_ao_criar,
       e.registro_id
from auditoria.eventos e, params p
where e.usuario_nome = p.usuario and e.tipo = 'criou' and e.entidade = 'boletos'
  and (e.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim
order by e.criado_em;
```

### 3. Baixas e mudanças de status

```sql
with params as (select 'Vinicius'::text as usuario,
  timestamp '2026-11-13 17:30' as ini, timestamp '2026-11-13 19:00' as fim)
select (e.criado_em at time zone 'America/Sao_Paulo') as quando, e.sistema, e.entidade, e.referencia,
       e.mudancas->'status'->>0 as de, e.mudancas->'status'->>1 as para,
       (e.mudancas->'valor_pago'->>1)::numeric as valor_pago,
       e.mudancas->'data_pagamento'->>1 as data_pagamento,
       e.mudancas->'forma_pagamento'->>1 as forma
from auditoria.eventos e, params p
where e.usuario_nome = p.usuario and e.tipo = 'mudou_status'
  and (e.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim
order by e.criado_em;
```

### 4. Linha do tempo completa (sem abrir tela)

```sql
with params as (select 'Vinicius'::text as usuario,
  timestamp '2026-11-13 17:30' as ini, timestamp '2026-11-13 19:00' as fim)
select (e.criado_em at time zone 'America/Sao_Paulo') as quando, e.sistema, e.tipo, e.entidade,
       e.referencia, e.mudancas
from auditoria.eventos e, params p
where e.usuario_nome = p.usuario and e.tipo <> 'abriu_tela'
  and (e.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim
order by e.criado_em;
```

Para incluir as telas abertas, tire a linha `and e.tipo <> 'abriu_tela'`.

### 5. Logins e telas abertas

```sql
with params as (select 'Vinicius'::text as usuario,
  timestamp '2026-11-13 17:30' as ini, timestamp '2026-11-13 19:00' as fim)
select e.sistema, e.tipo, count(*) as qtd, min(e.criado_em at time zone 'America/Sao_Paulo') as primeiro,
       max(e.criado_em at time zone 'America/Sao_Paulo') as ultimo
from auditoria.eventos e, params p
where e.usuario_nome = p.usuario and e.tipo in ('login','abriu_tela')
  and (e.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim
group by 1,2 order by 1,2;
```

### 6. Financeiro novo (títulos, parcelas e baixas)

```sql
with params as (select 'Vinicius'::text as usuario,
  timestamp '2026-11-13 17:30' as ini, timestamp '2026-11-13 19:00' as fim)
select (f.criado_em at time zone 'America/Sao_Paulo') as quando, f.tabela, f.operacao, f.registro_id, f.antes, f.depois
from financeiro_eventos f join usuarios u on u.id = f.usuario_id, params p
where u.nome = p.usuario
  and (f.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim
order by f.criado_em;
```

### 7. O que foi feito por script no banco na mesma janela (para separar do usuário)

```sql
with params as (select timestamp '2026-11-13 17:30' as ini, timestamp '2026-11-13 19:00' as fim)
select (e.criado_em at time zone 'America/Sao_Paulo') as quando, e.usuario_nome, e.tipo, e.entidade, e.referencia
from auditoria.eventos e, params p
where e.usuario_nome like 'SQL direto%'
  and (e.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim
order by e.criado_em;
```

### 8. Todos os usuários na janela (quem mais mexeu)

```sql
with params as (select timestamp '2026-11-13 17:30' as ini, timestamp '2026-11-13 19:00' as fim)
select e.usuario_nome, e.tipo, e.entidade, count(*) as qtd
from auditoria.eventos e, params p
where e.tipo <> 'abriu_tela'
  and (e.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim
group by 1,2,3 order by 1, qtd desc;
```

## Como ler o resultado

- Conta criada já com `status_ao_criar = 'Pago'` e sem valor pago é tentativa errada: costuma ser recriada logo depois com status Aberto e a baixa feita depois.
- Várias baixas em sequência, todas com `data_pagamento` antiga, são lançamentos retroativos: confirme com o Financeiro se o pagamento foi feito por fora.
- Baixas feitas nas telas antigas (`boletos`) não geram linha no financeiro novo (consulta 6 vem vazia): isso é esperado enquanto o boleto não tem parcela no financeiro novo.

## Pela tela (SPEC-318)

Quando o sistema Log de Atividade (`04-Sistemas/log-atividade/`) estiver publicado e a migration 377 aplicada, a consulta pode ser feita por ele: filtros de usuario, data e hora (Brasilia), sistema, acao, busca e SQL direto; detalhe antes -> depois; exportar Excel. Acesso somente Pedro e Filippo (lista `auditoria.log_visualizadores`). As consultas SQL acima continuam validas.
