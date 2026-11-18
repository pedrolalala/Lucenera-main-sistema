# Prompt: relatório de atividade de um usuário (para colar no Claude)

Antes de colar, troque os três campos entre colchetes na primeira linha (usuário, data e horário). O resto fica igual.

````
Quero um relatório de tudo que o usuário [NOME EXATO, ex.: Vinicius] fez no dia [DD/MM/AAAA] entre [HH:MM] e [HH:MM] (horário de Brasília).

REGRAS
- Use o acesso ao banco Supabase SÓ PARA LEITURA: apenas SELECT. Nunca faça INSERT, UPDATE, DELETE, DDL, nem altere nada.
- Não mostre senhas, chaves ou a string de conexão em nenhuma resposta.
- Todo horário que eu der é de Brasília. A coluna criado_em está em UTC: sempre use (criado_em at time zone 'America/Sao_Paulo').
- Antes de tudo, confirme o usuário: select id, nome, role from usuarios where nome ilike '%NOME%'; Se houver mais de uma conta parecida (ex.: "Vinicius" admin e "vinicius_bortolin" visualizador), me pergunte qual é antes de continuar.

ONDE ESTÁ O LOG
- auditoria.eventos: criado_em, usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, mudancas (jsonb), ip, navegador.
  tipo: login, abriu_tela, criou, alterou, apagou, aprovou, mudou_status. entidade: boletos, orcamentos, pedidos_compra, produtos, estoque_itens, contatos, sessions (login) etc.
  sistema: contas-pagar, contas-receber, hub e os demais sistemas.
- financeiro_eventos: criado_em, usuario_id, tabela, operacao, registro_id, antes, depois (financeiro novo: títulos, parcelas e baixas).
- Em tipo = 'mudou_status', mudancas traz pares [antes, depois]: {"status":["Aberto","Pago"],"valor_pago":[null,4000],"data_pagamento":[null,"2026-09-25"],"forma_pagamento":[null,"PIX"]}.
- Em tipo = 'criou' e entidade = 'boletos', mudancas traz a conta: valor, vencimento, nome_pagador, tipo_operacao (CP = a pagar, CR = a receber), status, empresa_id.

CONSULTAS (troque usuario, ini e fim no bloco params; vale para todas)
1) Resumo:
with params as (select 'NOME'::text usuario, timestamp 'AAAA-MM-DD HH:MM' ini, timestamp 'AAAA-MM-DD HH:MM' fim)
select e.sistema, e.tipo, e.entidade, count(*) qtd from auditoria.eventos e, params p
where e.usuario_nome=p.usuario and (e.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim
group by 1,2,3 order by qtd desc;

2) Contas criadas:
(mesmo params) select (e.criado_em at time zone 'America/Sao_Paulo') quando, e.sistema, e.referencia, e.mudancas->>'tipo_operacao' tipo_operacao, e.mudancas->>'nome_pagador' favorecido, (e.mudancas->>'valor')::numeric valor, e.mudancas->>'vencimento' vencimento, e.mudancas->>'status' status_ao_criar, e.registro_id
from auditoria.eventos e, params p where e.usuario_nome=p.usuario and e.tipo='criou' and e.entidade='boletos'
and (e.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim order by e.criado_em;

3) Baixas e mudanças de status:
(mesmo params) select (e.criado_em at time zone 'America/Sao_Paulo') quando, e.sistema, e.entidade, e.referencia, e.mudancas->'status'->>0 de, e.mudancas->'status'->>1 para, (e.mudancas->'valor_pago'->>1)::numeric valor_pago, e.mudancas->'data_pagamento'->>1 data_pagamento, e.mudancas->'forma_pagamento'->>1 forma
from auditoria.eventos e, params p where e.usuario_nome=p.usuario and e.tipo='mudou_status'
and (e.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim order by e.criado_em;

4) Linha do tempo (sem abrir tela; para incluir telas, retire o filtro de tipo):
(mesmo params) select (e.criado_em at time zone 'America/Sao_Paulo') quando, e.sistema, e.tipo, e.entidade, e.referencia, e.mudancas
from auditoria.eventos e, params p where e.usuario_nome=p.usuario and e.tipo<>'abriu_tela'
and (e.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim order by e.criado_em;

5) Logins e telas abertas:
(mesmo params) select e.sistema, e.tipo, count(*) qtd, min(e.criado_em at time zone 'America/Sao_Paulo') primeiro, max(e.criado_em at time zone 'America/Sao_Paulo') ultimo
from auditoria.eventos e, params p where e.usuario_nome=p.usuario and e.tipo in ('login','abriu_tela')
and (e.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim group by 1,2 order by 1,2;

6) Financeiro novo:
(mesmo params) select (f.criado_em at time zone 'America/Sao_Paulo') quando, f.tabela, f.operacao, f.registro_id, f.antes, f.depois
from financeiro_eventos f join usuarios u on u.id=f.usuario_id, params p where u.nome=p.usuario
and (f.criado_em at time zone 'America/Sao_Paulo') between p.ini and p.fim order by f.criado_em;

7) O que foi feito por script no banco na mesma janela (NÃO é ação do usuário):
select (e.criado_em at time zone 'America/Sao_Paulo') quando, e.usuario_nome, e.tipo, e.entidade, e.referencia from auditoria.eventos e
where e.usuario_nome like 'SQL direto%' and (e.criado_em at time zone 'America/Sao_Paulo') between timestamp 'AAAA-MM-DD HH:MM' and timestamp 'AAAA-MM-DD HH:MM' order by e.criado_em;

8) Quem mais mexeu na mesma janela:
select e.usuario_nome, e.tipo, e.entidade, count(*) qtd from auditoria.eventos e where e.tipo<>'abriu_tela'
and (e.criado_em at time zone 'America/Sao_Paulo') between timestamp 'AAAA-MM-DD HH:MM' and timestamp 'AAAA-MM-DD HH:MM' group by 1,2,3 order by 1, qtd desc;

COMO ENTREGAR
- Gere um Excel com as abas: Resumo, Contas lançadas (consulta 2 com o que foi pago, cruzando por registro_id com a consulta 3), Linha do tempo (consulta 4) e Por sistema e ação (consulta 1).
- No Resumo, escreva em linguagem simples: quantas contas criou, quantas baixou, valor total das baixas, em quais sistemas atuou, quantos logins e telas abertas.
- Aponte o que merece atenção: conta criada já como "Pago" sem valor e sem data (tentativa errada, em geral recriada depois); baixas com data de pagamento antiga lançadas em sequência (retroativas: só o Financeiro confirma se o pagamento foi feito por fora); exclusões (tipo apagou).
- Separe registros "SQL direto" (consulta 7): são alterações feitas por script no banco, não pelo usuário.
- Avise o que o log NÃO cobre: importações e automações com chave de serviço, e leitura de dados (só abertura de tela é registrada).
- IP e navegador identificam pessoas: não inclua no relatório, a menos que eu peça.
````
