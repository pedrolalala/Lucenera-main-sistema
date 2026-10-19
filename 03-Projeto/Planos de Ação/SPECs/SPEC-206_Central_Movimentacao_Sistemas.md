---
titulo: "SPEC-206 — Central: Movimentação de todos os sistemas (quem fez o quê, quando e onde)"
status: pendente
data_ultima_modificacao: 2026-10-19
sistemas_envolvidos:
  - Central (Hub) — tela nova em Administração
  - Banco SP (schema novo `auditoria`)
  - Os 16 sistemas (fase 2: registro de telas abertas)
---

# SPEC-206 — Central: Movimentação de todos os sistemas

## Checklist de Ação

**Fase 1 — banco (sem mexer nos 16 sistemas)**
- [x] Schema `auditoria`, fora do `public`, e tabela `auditoria.eventos` (migration `20261019_221_spec206_auditoria_movimentacao`, APLICADA 19/10 com autorização do usuário: 28 triggers + cron)
- [x] Função `auditoria.fn_registrar()`: trigger genérico que grava quem, o quê, antes/depois e de qual sistema
- [x] Triggers nas tabelas de negócio (lista em "O que entra")
- [x] Logins: trigger em `auth.sessions` (cada login novo = 1 evento)
- [x] Senha: trigger em `auth.users` quando a senha muda (evento "senha alterada", sem guardar a senha)
- [x] Função `auditoria.usa_senha_padrao()`: diz só sim/não se a pessoa ainda usa a senha padrão
- [x] RPCs de leitura só para admin: `auditoria_listar(...)` e `auditoria_resumo_usuarios(...)`
- [x] Limpeza automática (pg_cron `auditoria-retencao-12-meses`, 06:30 UTC) de eventos mais velhos que o prazo de retenção

**Fase 1 — tela (Central › Administração › Movimentação)**
- [x] Aba "Movimentação": linha do tempo com filtros (`MovimentacaoTab.tsx`, Central 70f56c4 publicada e conferida no bundle)
- [x] Aba "Pessoas": resumo por usuário
- [x] Detalhe de um evento: o que mudou, campo a campo (antes → depois)

**Fase 2 — telas abertas ("no que ela mexe" além de gravar)**
- [x] Migration `20261019_223_spec206_fase2_telas` (APLICADA 19/10):
  - RPC `auditoria_registrar_tela`: ignora a mesma tela em menos de 1 min, e a primeira tela depois do login preenche o sistema do login;
  - RPC `auditoria_registrar_acao`: para gravações via Edge Function com service role;
  - aprovação do cliente pelo link público (anon) entra em orcamentos como "Cliente (link de aprovação)";
  - `auditoria_listar(p_incluir_telas)` e `telas_periodo` no resumo.
- [x] `src/lib/registro-tela.ts` igual nos 17 sistemas, ligado no `main.tsx`. Escuta pushState/replaceState/popstate, vale para qualquer roteador, guarda só o caminho (sem ?parâmetros) e só registra quem está logado.
- [x] CRM: Novo Projeto chama `auditoria_registrar_acao('criou','projetos',id)` depois do `salvar-projeto`.
- [x] Central: tipo "Abriu tela", chave "Mostrar telas abertas" (começa desligada) e coluna "Telas abertas" em Pessoas.
- [ ] Publicar os 17 sistemas e conferir

### Passos manuais do usuário
- [x] Aprovar esta SPEC e as escolhas da seção "Decisões" (19/10: 12 meses, só admin, fase 2 depois)
- [x] Avisar a equipe de que o uso dos sistemas é registrado (o usuário confirmou que a equipe já foi avisada)

## Objetivo

Ter um lugar na Central onde o administrador vê tudo que acontece nos sistemas: logins do dia, orçamentos criados e alterados, quem aprovou e quando, troca de senha, quem ainda usa a senha padrão, quantas vezes a pessoa entra e no que mexe. A tela filtra por sistema, por pessoa, por período e por tipo de ação.

## Situação atual (levantada no banco SP em 19/10)

| O que existe | Situação |
|---|---|
| `auth.audit_log_entries` (log de login do Supabase) | **Vazio.** O Supabase não grava mais nessa tabela |
| `auth.users.last_sign_in_at` | Só o **último** login de cada pessoa, sem histórico |
| `public.logs_auditoria` | 53 linhas; trigger só em `fornecedores` e `remessas`, **sem o usuário** (`usuario_id` vazio) e sem o sistema |
| `historico_status_orcamentos` | 3 linhas; preenchido só por alguns caminhos |
| `auditoria_permissoes` | 291 linhas; só mudanças de papel e permissão |
| `garantia_*_log`, `producao_pedidos_log` | Logs próprios de 2 sistemas |
| `erros_tela` | Só o RH grava erros de tela |

Conclusão: não existe histórico de login nem registro geral com usuário e sistema. É preciso criar.

## Como funciona

### 1. Um registro só: `auditoria.eventos`
| coluna | conteúdo |
|---|---|
| `criado_em` | data e hora |
| `usuario_id`, `usuario_nome` | quem fez (`auth.uid()`; nome copiado na hora, para não sumir se a conta for apagada) |
| `sistema` | slug de `systems` (crm, orcamentos, vendas...) |
| `tipo` | `login`, `senha_alterada`, `criou`, `alterou`, `apagou`, `aprovou`, `mudou_status`, `abriu_tela` |
| `entidade`, `registro_id`, `referencia` | tabela, id e um texto legível (ex.: "ORC-0012", "Projeto 26.319", "Cliente LAFONTTI") |
| `mudancas` | só os campos que mudaram: `{campo: [antes, depois]}` |
| `ip`, `navegador` | quando vierem na requisição |

A tabela fica no schema `auditoria`, fora do `public`, pelo mesmo motivo do schema `backup`. Ninguém lê direto: a tela usa RPCs que exigem admin.

### 2. Como sabe de qual sistema veio, sem mexer nos 16 sistemas
Todo navegador manda o cabeçalho `Origin` (ex.: `https://crm-lucenera.pages.dev`), e o banco lê esse cabeçalho com `current_setting('request.headers')`. A função cruza o endereço com `systems.link` e acha o slug. Edge Functions e scripts não têm esse cabeçalho e ficam como `sistema = 'automacao'`.

### 3. O que entra (triggers)
Grava **só ação de pessoa logada** (`auth.uid()` preenchido). Importações da Connect, sync do SharePoint e scripts mexem em dezenas de milhares de linhas (transacoes, negociacoes, notas_fiscais_connect_*, staging_*) e ficariam de fora. Sem isso, o registro vira lixo.

Tabelas com trigger na fase 1:
- **Orçamentos/Vendas:** `orcamentos` (status, aprovação, aprovação financeira, quem aprovou), `orcamento_itens`, `vendas`, `notas_fiscais`, `boletos`
- **CRM:** `projetos`, `contatos`, `projeto_arquitetos`, `projeto_parcelas`
- **Estoque/Separação/Entregas:** `separacoes`, `estoque_itens`, `devolucoes_estoque`, `entregas`
- **Compras:** `cotacoes_compra`, `pedidos_compra`
- **Produção/Garantia:** `producao_pedidos`, `garantia_itens`, `garantia_protocolos`
- **Cadastros:** `produtos` (sem os campos de custo, que são restritos), `fornecedores`, `funcionarios`
- **Acessos:** `usuarios`, `usuario_papeis`, `user_system_access`

Mudança de `status` vira o tipo `mudou_status`. `aprovado`, ou aprovação financeira, vira `aprovou`. Assim "quem aprovou e quando" sai direto do filtro.

Campos ignorados nas mudanças: `updated_at` e similares. Também ficam de fora os campos sensíveis: custo, salário, dados bancários. Para eles, o registro diz só "alterou salário", sem os valores.

### 4. Login, senha e senha padrão
- **Login:** cada login cria uma linha em `auth.sessions`. Um trigger grava `tipo = login` com o IP e o navegador. Renovação automática do token não cria sessão, então não conta como login. Daí saem "quantas vezes por dia" e "quando entra".
- **Senha alterada:** um trigger em `auth.users` registra quando o hash da senha muda. Ele grava só o fato, nunca a senha.
- **Usa senha padrão?** Uma função do banco testa o hash de cada conta contra a senha padrão (`Lucenera2026!`, SPEC-187) e devolve só **sim/não**. Nada sai do banco além disso. Só admin chama.

### 5. A tela (Central › Administração › Movimentação)
- **Filtros:** período (hoje, 7 dias, 30 dias, de/até), sistema, pessoa, tipo de ação, busca por referência (ex.: "ORC-0012").
- **Linha do tempo:** hora · pessoa · sistema · ação · referência. Clicar abre o "antes → depois".
- **Aba Pessoas:** uma linha por usuário com:
  - logins hoje e nos últimos 7 dias, e o último login;
  - sistemas mais usados;
  - nº de ações no período;
  - se **ainda usa a senha padrão** (alerta vermelho);
  - data da última troca de senha.

  Clicar na pessoa filtra a linha do tempo.
- Paginação de 100 em 100, porque o PostgREST corta em 1000 linhas.

### 6. Fase 2: telas abertas
Para saber "no que mexe" mesmo quando a pessoa só consulta, sem gravar nada, cada sistema precisa avisar a tela aberta: 1 linha por mudança de rota, com intervalo mínimo para não inflar. Isso mexe nos 16 sistemas, por isso fica separado.

## Decisões (propostas, aguardando aprovação)
1. **Retenção:** guardar **12 meses**; depois apaga automaticamente.
2. **Fase 2 (telas abertas):** fazer depois da fase 1 estar no ar.
3. **Quem vê:** só `role = admin`.
4. **Histórico anterior:** a tela começa vazia no dia em que for ligada. Não existe histórico de login antigo para recuperar. Os 53 registros de `logs_auditoria` ficam onde estão.

## Implementação (19/10)
- Dry-run com rollback no banco SP:
  - alteração de projeto feita como Marina com Origin do CRM → evento `alterou`, sistema `crm`, campo antes/depois;
  - itens de orçamento (testados numa tabela temporária com o mesmo trigger) → 1 evento por orçamento: "5 itens incluídos", "2 alterados", "5 removidos"; update sem mudança real não gera evento;
  - login (insert em `auth.sessions`) → evento `login` com IP e navegador;
  - troca de senha → `senha_alterada` com `voltou_para_senha_padrao`;
  - update sem usuário (script) → nenhum evento;
  - Marina chamando a RPC → "Apenas administradores"; ler `auditoria.eventos` direto → sem permissão.
- Em 19/10, 21 das 35 contas ainda usam a senha padrão.
- Limitações da fase 1:
  - o **login** não sabe de qual sistema veio, porque o Auth do Supabase não repassa o endereço; aparece como "—";
  - ações feitas por **Edge Function com service role** não têm usuário e ficam fora. Exemplo: criar projeto pelo CRM usa `salvar-projeto`. A alteração seguinte do projeto entra normalmente;
  - os dois casos foram resolvidos na fase 2 (migration 223).
- Achado fora do escopo, corrigido em 19/10 pela migration `20261019_222_orcamento_data_inicio_pagamento_so_ao_mudar` (aplicada a pedido do usuário):
  - o CHECK `orcamentos_data_inicio_pagamento_check` comparava com `now()` e é reavaliado em todo UPDATE, então **todo** orçamento travava no dia seguinte ao início do pagamento (ORC-0001: início em 15/10, travou em 16/10);
  - virou um trigger que valida só no INSERT ou quando a data muda;
  - teste: ORC-0001 volta a salvar, e data no passado continua recusada.

## Riscos
- **Volume:** só ações de pessoas, estimadas em poucos milhares por dia. Índices em (`criado_em`), (`usuario_id`, `criado_em`) e (`sistema`, `criado_em`).
- **Lentidão ao salvar:** o trigger faz 1 insert por linha alterada. Atualizações em massa feitas por pessoa (ex.: aprovar orçamento com 200 itens) geram 200 eventos de item. Nesse caso, agrupar itens por orçamento numa linha só.
- **Trigger em `auth.*`:** permitido no Supabase, mas, se der erro, pode impedir o login. A função vai em `EXCEPTION WHEN OTHERS THEN RETURN NEW`, nunca bloqueia.
- **Privacidade:** registrar uso de sistema da empresa é legítimo, mas a equipe deve saber.

## Critérios de aceite
1. Fazer login no CRM aparece na Movimentação com sistema = CRM, em segundos.
2. Aprovar um orçamento mostra "aprovou · ORC-xxxx · pessoa · hora".
3. Filtrar por pessoa mostra só ela; filtrar por sistema mostra só ele.
4. Aba Pessoas indica quem ainda usa a senha padrão; depois de trocar a senha em "Minha senha", o alerta some e aparece "senha alterada".
5. Importação da Connect não gera eventos.
6. Usuário não admin não acessa a tela nem as RPCs.
