Você vai continuar um trabalho crítico no projeto Lucenera ADAPTA PASS
(repositório C:\script python\ADAPTA-PASS-Lucenera-main): o REDESENHO DO FINANCEIRO do banco
Supabase (SPEC-258). Sou o dono do negócio, não programador de banco: explique em português claro,
com tabelas simples, e diga quando tiver incerteza.

LEIA PRIMEIRO, NESTA ORDEM
1. CLAUDE.md e AGENTS.md (raiz, supabase/, scripts/, 03-Projeto/).
2. Memória do projeto: MEMORY.md e os arquivos "spec258-financeiro-modelo-definitivo" e
   "reuniao-43-specs-249-257-estado".
3. 03-Projeto/Planos de Ação/SPECs/SPEC-258_Financeiro_Modelo_Definitivo_Titulos_Parcelas_Baixas.md
   (a SEÇÃO 0 é o seu plano de trabalho) e a SPEC-246.
4. O anexo visual 03-Projeto/Planos de Ação/SPECs/SPEC-258_anexo_relatorio_visual_financeiro.html.
5. scripts/financeiro/baseline_spec258.sql (medições de 06/11 nos comentários).

CONTEXTO EM POUCAS LINHAS
Hoje o dinheiro está em 12 lugares do banco (negociacoes, transacoes, projeto_parcelas, boletos,
pedido_compra_parcelas, nota_fiscal_compra_parcelas, custos_recorrentes_lancamentos, folha_pagamento,
vendas, pedido_compra, staging_pedido_compra, remessas/retornos/projeto_sinal/pagamentos_antecipados),
cada um com o seu "pago" e quase sem vínculo por id. Uma venda aprovada fica em 3 lugares. A proposta
aprovada em princípio por mim: 4 tabelas (títulos, parcelas, baixas, cobranças) + 2 de apoio (regras de
repasse e fila de pendências), com natureza (a receber/a pagar) x situação (prevista/firme/liquidada/
cancelada), porta única por funções do banco, TODA ligação como chave estrangeira real e ids da Connect só
como "legado" imutável. Desde 05/11/2026 19h01 o financeiro é 100% do sistema novo (a Connect não alimenta
mais). Exijo: tudo com id, tudo sincronizado, nenhuma ponta solta, nada aberto, migração sem erro, incluindo
contas a receber, a pagar, histórico de pagas, RT dos arquitetos e RT/comissão dos funcionários.

O QUE QUERO NESTA SESSÃO (é ANÁLISE, não implementação)
1. Rode o baseline e compare com os números de 06/11. Se algo mudou, explique por quê antes de seguir.
2. Refaça a análise do banco DE FORMA INDEPENDENTE, sem confiar cegamente na SPEC: procure se existe mais
   algum lugar com dinheiro (tabelas, views, funções, gatilhos, FKs, colunas de valor/vencimento/pago) e
   todas as origens e dependências, no banco e nos sistemas em 04-Sistemas/.
3. Critique o modelo proposto: aponte falhas, riscos e casos não cobertos (renegociação/acordo, pagamento
   parcial, juros/multa, antecipação, devolução, permuta, cancelamento, multi-empresa e perfil, concorrência,
   idempotência, performance, RLS, migração do legado). Se achar um desenho melhor, proponha e justifique.
4. Me entreviste sobre as decisões da seção 9 da SPEC, COMEÇANDO PELO RT (percentual; por arquiteto, venda
   ou projeto; base de cálculo; quando paga; devolução; nota fiscal). O banco não guarda isso e o histórico
   não permite deduzir: NÃO chute regra de negócio, pergunte. Depois comissão e folha.
5. Só depois: entregue a SPEC-258 versão final e rascunhos das migrations da FASE 1 (tabelas vazias) com
   up.sql, rollback.sql e dry_run.sql (termina em ROLLBACK). Próximo número de migration livre: 302.

REGRAS INEGOCIÁVEIS
- NÃO aplique nada no banco sem a minha autorização EXPLÍCITA, migration por migration.
- NÃO faça push para o GitHub nem publique nada (Cloudflare) sem eu pedir.
- Nunca apague dado: cancele ou estorne. Backup no schema "backup". Ensaios sempre em ROLLBACK, com
  usuário real, e confira antes x depois. Se um número divergir, PARE e me avise.
- Tabela nova: RLS ligado e REVOKE de anon; função nova: REVOKE de PUBLIC e anon. Folha, comissão e
  "salário por fora" só para o RH.
- Não imprima segredos do .env. Confirme comigo antes de qualquer ação irreversível.
- Seja honesto: não diga que está tudo certo sem ter verificado; relate falhas e limitações.

PARA SABER (NÃO MEXER AGORA)
- O commit 671e777 (SPEC-258) está só local, sem push, por pedido meu.
- SPEC-250 espera um PDF de lista de entrega da Connect; SPEC-253 espera a definição de item especial por
  medida; SPEC-248 item 3 espera o desenho da coluna de previsão. A migration 301 (transacoes.previsao) já
  está aplicada e é intermediária.
- Dicas operacionais estão na seção 0 da SPEC (psql com PGCLIENTENCODING=UTF8, sem acento em literal de
  linha de comando, push do GitHub lento: rodar em segundo plano).

ENTREGAS ESPERADAS (nesta ordem)
(a) relatório de divergências e achados novos; (b) lista fechada de perguntas de negócio; (c) SPEC-258
v3; (d) rascunho das migrations da Fase 1 com dry-run. Comece por (a) e me mostre antes de seguir.
