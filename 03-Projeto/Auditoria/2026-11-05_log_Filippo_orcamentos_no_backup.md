# Registro de 05/11/2026 — o que o Filippo fez, o desfazer da venda e o site de Orçamentos no banco de backup

Levantado por leitura do banco (nada foi alterado). Horários em **Brasília**. Fontes: `auditoria.eventos` e `historico_status_orcamentos` (São Paulo, `bgtfrcbipuxnsexbppsh`); `auth.users` e tabelas do backup (Ohio, `vcvcwzmbiftcawncibke`); código publicado dos sites `*-lucenera.pages.dev`.

## 1. Resumo em 6 linhas
1. O site de Orçamentos (`financeiro-lucenera.pages.dev/budgets`, link oficial do Hub) está **publicado apontando para o banco de backup (Ohio)** e não para São Paulo. Os outros 18 sites que respondem estão em São Paulo. Por isso a lista de orçamentos aparece vazia (o backup tem 1 orçamento, de 15/10).
2. **Nada foi gravado no backup hoje:** nenhuma tabela com linha criada ou alterada. O único login lá é `pedro@lucenera.com.br`, às 18:06.
3. Os 351 orçamentos e todo o resto estão **intactos em São Paulo**.
4. A troca do banco do site (variável de ambiente + novo deploy) **não aparece em nenhum log do banco**: ela acontece na Cloudflare. O registro está no **Audit Log da Cloudflare** (seção 5).
5. A aprovação financeira da venda do Paulo Gouveia (ORC-0001 / VENDA-8503) foi **desfeita às 17:52 sem usuário** e com o motivo "datas erradas" (seção 3).
6. O Filippo teve **15 alterações** hoje, todas em São Paulo e todas registradas (seção 2).

## 2. Tudo que o Filippo alterou hoje em São Paulo (sem logins e telas)
| Hora | Sistema | Ação | O quê |
|---|---|---|---|
| 11:55 | CRM | mudou status | Projeto 26.290 ANA SILVIA: "Elaboração Orçamento" → "Estudo Inicial" |
| 11:55 | CRM | criou | Arquiteto do projeto 26.290 — ANDRÉ CALIL DE SALLES (100%) |
| 11:55 | CRM | alterou | Projeto 26.290: arquiteto definido |
| 12:26 | Orçamentos | aprovou | ORC-0001: "Aprovação manual do cliente — aguardando aprovação da equipe" |
| 12:27 | Orçamentos | mudou status | ORC-0001 voltou a "enviado_cliente"; **empresa trocada de LUCE NERA para ISLIGHT**; plano de parcelas alterado |
| 12:28 | Orçamentos | mudou status | ORC-0001: nova aprovação manual do cliente |
| 12:29 | Orçamentos | mudou status | ORC-0001 → "Aprovação Financeira" ("Previsão de entrega confirmada: 23/11/2026") |
| 12:30 | Orçamentos | aprovou | ORC-0003: aprovação manual do cliente |
| 12:30 | Orçamentos | mudou status | ORC-0003 → "Aprovação Financeira" ("Previsão de entrega: 09/11/2026") |
| 12:34 | Orçamentos | alterou | ORC-0003: **empresa trocada de LUCE NERA para ISLIGHT**; observações "Envio por nossa conta" → "recebemos do cliente"; plano de parcelas |
| 12:34 | Orçamentos | alterou | ORC-0003: arquiteto removido |
| 16:53 | Vendas | criou | Nota fiscal "A DEFINIR" (ambiente **homologação**) do ORC-0001 |
| 16:53 | Vendas | alterou | mesma NF: valor 0 → R$ 44.192,22 (desconto R$ 9.192,22) |
| 16:53 | Vendas | alterou | mesma NF: frete/desconto |
| 16:53 | Vendas | apagou | a NF "A DEFINIR" (8 segundos depois) |

Fora isso: 40 logins em 17 sistemas (11:41 a 17:40), vindos do IP 177.139.72.199 e de IPs da própria nuvem, e telas abertas (Orçamentos 28, Hub 26, CRM 20, Contas a Receber 18, Vendas 13, entre outras).

## 3. O desfazer da aprovação da venda (ORC-0001 / VENDA-8503, Paulo Gouveia, R$ 35.000,00)
- 14:36 — **Vinicius** aprova financeiramente: criam-se 2 parcelas de projeto, 2 boletos e a reserva de estoque.
- **17:52 — status volta de "Orçamento Aprovado" para "Aprovação Financeira"; usuário vazio; observação: "datas erradas".**
- "Usuário vazio" significa que a função `desfazer_aprovacao_financeira` foi executada **direto no banco** (editor SQL do Supabase ou script com chave de serviço), não pela tela do sistema; a tela grava o nome de quem fez. Quem tem acesso ao painel do Supabase de São Paulo consegue dizer quem foi.
- Efeito: as 2 parcelas de projeto e os 2 boletos foram apagados e as 2 transações em aberto ficaram canceladas (o orçamento saiu do Contas em Aberto).
- Essa execução **não** gerou eventos em `auditoria.eventos` (o log ignora chamadas sem usuário, por desenho).

## 4. Banco de backup (Ohio) — o que aconteceu hoje
- Logins: apenas `pedro@lucenera.com.br`, 18:06.
- Tabelas com linhas criadas ou alteradas hoje: **nenhuma**.
- Orçamentos no backup: 1 (de 15/10); 35 usuários. O backup não tem o esquema de auditoria; não há log de ações nele além do login acima.

## 5. O que NÃO está no log do banco e onde buscar
| O que | Onde está o registro |
|---|---|
| Quem trocou as variáveis `VITE_SUPABASE_*` do projeto `financeiro-lucenera` na Cloudflare, e quando | Cloudflare → Manage Account → **Audit Log** (mostra usuário, ação, horário e IP) |
| Quem disparou o novo deploy e a partir de qual commit | Cloudflare → Workers & Pages → `financeiro-lucenera` → **Deployments** |
| Quem executou comandos direto no banco (editor SQL) | Supabase São Paulo → **Logs** / Postgres Logs e a tela de Query Performance; o painel não grava o nome do operador nas tabelas |
| Quem acessou o painel do Supabase / mudou projeto | Supabase → Organization → **Audit Logs** (planos pagos) |

## 6. O que foi feito para o futuro (SPEC-246)
- Migration 288 (aplicada): o log passou a cobrir `transacoes`, `negociacoes`, plano de contas, contas bancárias, empresas, parcelas do pedido de compra, NF da Connect, equipes e outras 5 tabelas, com texto legível ("Parcela 2 a Pagar da duplicata …"). Agora são 43 tabelas auditadas.
- Limite que continua: ações com chave de serviço / editor SQL não identificam a pessoa. Para fechar isso, o caminho é parar de usar o editor SQL para operações de negócio e registrar a execução em uma tabela própria (posso desenhar).

## 7. Correção do site de Orçamentos
Cloudflare → Pages → `financeiro-lucenera` → Settings → Environment variables (Production): `VITE_SUPABASE_URL = https://bgtfrcbipuxnsexbppsh.supabase.co` e `VITE_SUPABASE_PUBLISHABLE_KEY =` chave pública de São Paulo; depois **Retry deployment**. Depois disso, rodar a varredura dos sites para confirmar (feita nesta sessão).
