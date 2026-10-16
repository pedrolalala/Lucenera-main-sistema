# Changelog

Registro cronologico das mudancas no repositorio central `Lucenera - ADAPTA PASS`.

## 2026-10-16

- Vendas (SPEC-204): importadas as notas da Connect da Manoella de fev a set/2026 (236 notas no total com jan,
  nº 4579–4814). Só grava em `notas_fiscais_connect*` — nada do financeiro alterado (conferido pelos contadores
  do banco). Total da aba passa a somar só nota de VENDA (CFOP de venda); remessa, devolução, retorno e
  industrialização não somam. Vendas `bea828a`. `scripts/importar_nfe_connect.py` lê subpastas e pula evento de nota de terceiro.

## 2026-10-15

- Vendas (SPEC-204): aba "Notas Fiscais Connect" (`/notas-fiscais-connect`, só consulta) com as NF-e emitidas pela
  Connect, importadas dos XMLs por `scripts/importar_nfe_connect.py` (idempotente pela chave; cancelamento marca a nota
  como cancelada). Banco: migration 219 APLICADA (`notas_fiscais_connect` + `_itens`/`_duplicatas`/`_eventos`, leitura
  só com o sistema Vendas, sem escrita pela API). 1ª carga: Manoella jan/2026 — 19 notas (4579–4597), 4590 cancelada,
  R$ 783.135,28 autorizadas. Vendas `8b0e933`. XMLs não vão para o Git (têm CPF de clientes).
- Catálogo Ubiqua: peça Manoella/Islight (`-IS`) com a quantidade somada no orçamento e a origem de cada parte
  (`b3164be`); "Meus Orçamentos" do representante + acompanhamento por representante no admin (`092a5ec`); descrição
  com a cor da referência selecionada (`1a55605`). Banco: migration 215 APLICADA — orçamento/itens da Ubiqua só para
  quem enxerga o cliente (representante dono, admin/interno Ubiqua, admin/gerente Lucenera); numeração via função
  SECURITY DEFINER. Base de orçamentos/clientes/representantes Ubiqua zerada pelo usuário (limpeza intencional).

## 2026-10-14

- Orçamentos — ESTADO FINAL a pedido do usuário: módulo restaurado para `9a67172` (revert `aad2290`), o escopo das 3
  tarefas (dropdown de status sem Recusado pelo Cliente, peça da Ubiqua ligada ao cadastro, rascunho) + SPEC-200.
  Sem as colunas extras; abas originais. Os itens de tela de Orçamentos de 14/10 abaixo que vieram depois do
  `9a67172` ficam sem efeito. Banco: migrations 211 e 212 aplicadas.
- Orçamentos — novo ROLLBACK a pedido do usuário (`18eddbe`, volta ao `0c8822d`) e depois `6c491e5`: busca +
  dropdown de status (mesmo bloco de antes) sempre visíveis no topo, acima das abas; dropdown com 7 opções (sem
  Recusado pelo Cliente e obsoletos); escolher status leva à aba Todos; tabela com todas as colunas de negócio e
  rolagem horizontal. Abas voltaram ao original. Substitui os itens de tela de Orçamentos de 14/10 abaixo.
- Orçamentos (pedido do usuário, depois do rollback): lista SEM abas — só busca + dropdown de status com 7 opções
  (sem Recusado pelo Cliente). Ações que só existiam na aba Aprovação da Equipe ("Aprovar e Enviar ao Financeiro",
  "Devolver ao Cliente") passaram para os botões da linha (`TeamApprovalRowActions.tsx`, mesma lógica: aviso de
  vencido, previsão de entrega obrigatória, motivo). As demais ações das abas já existiam na linha. Orçamentos `20eddf8`.
- Orçamentos — ROLLBACK a pedido do usuário: todas as alterações de tela da sessão de 14/10 desfeitas (`5a2da22`
  reverte 95f7caa, 9a67172, a3120b4, 8ec2c2d, 8b6c1db, 0eb94ce; volta ao `0c8822d`). Depois só `Budgets.tsx`
  (`b7b7683`): 5 abas (Todos, Rascunho, Aprovação do cliente, Aprovação da Equipe, Aprovados) e dropdown de status com
  7 opções (sem Recusado pelo Cliente/Finalizado/Obra Finalizada/Recusado/Expirado). Banco NÃO revertido
  (migrations 211 e 212 seguem aplicadas). Os itens abaixo sobre telas de Orçamentos de 14/10 ficam sem efeito.
- Orçamentos: lista com todos os campos de negócio em colunas (tabela rola na horizontal). Novas: Validade,
  Nº Orçamento, Projeto, Tipo, Perfil, Vendedor, Equipe, Digitado por, Pagamento (forma + condições), Prazo Entrega,
  Frete, Desconto e Sinal. Ficam fora os campos técnicos (token, datas internas do fluxo, ids, plano de parcelas).
  Orçamentos `a3120b4`, sem mudança no banco. **DESFEITO** no mesmo dia a pedido do usuário (revert `8ec2c2d`):
  a lista voltou às 9 colunas de antes. Depois, pela especificação final do usuário: colunas reaplicadas
  (`8b6c1db`), lista com exatamente 5 abas (sai "Revisão Financeira Pendente"; aprovação financeira pela aba Todos
  + filtro + botão da linha) e peça da Ubiqua com o valor do cadastro (`0eb94ce`).
- Orçamentos (pedido do usuário, 3 correções). (1) Filtro de status da lista sem "Recusado pelo Cliente" (e sem
  Finalizado/Obra Finalizada/Recusado/Expirado, que nenhum orçamento usa). (2) Peça da Ubiqua (`revenda_ubiqua`)
  escolhida na busca agora é ligada ao produto do cadastro pelo código/referência — antes entrava sem `produto_id`,
  sem código e referência, como item sem cadastro (ORC-0002/0003); o valor da linha escolhida é mantido.
  (3) Migration 212 (aplicada em SP): `handle_orcamento_workflow()` não promove mais sozinho rascunho →
  `enviado_cliente` — o bloco tirado na SPEC-051 tinha voltado na 158. Orçamentos `9a67172`.
- SPEC-200: Orçamento por equipe. Migration 211 (aplicada em SP): `orcamentos.equipe_id` obrigatória (vem do projeto,
  do vendedor ou de quem digitou), `digitado_por` gravado pelo banco com o login, política RESTRICTIVE: quem é só da
  Equipe de Projetos vê apenas os orçamentos da própria equipe (Marina/Thairine/Thais) e os que digitou. Módulo novo
  no Hub "Aprovação do Cliente" dado à Equipe de Projetos: agora ela consegue "Aprovar Manualmente" (antes só
  admin/gerente/operador). Orçamentos `95f7caa`: campo Equipe no formulário, "Digitado por" e equipe na lista.
- SPEC-183: migration 210 aplicada e DESFEITA (rollback) no mesmo dia — Moara saiu da empresa; ela segue sem papel e
  sem sistema. Conferidos os 33 usuários: nenhuma outra pessoa de equipe sem acesso. Login da Moara bloqueado (ban no Auth de SP, sem prazo) — conta e histórico mantidos.
- SPEC-199: Orçamento aceita quantidade com vírgula (peça por metro, ex.: 4,5 m) — ao abrir/editar não arredonda mais
  para inteiro; peça com unidade MT ou quantidade quebrada aparece com o campo Qtd em âmbar e selo "m". Orçamentos
  `0c8822d`, no ar na Cloudflare.
- Limpeza dos dados de TESTE antes do uso em paralelo com a Connect (`scripts/limpar_dados_teste_orcamento_separacao.py`,
  aplicado em SP): apagados os 21 orçamentos (todos teste, inclusive ORC-0038/0039 do XML), 317 itens, 149
  `projeto_itens`, 83 movimentos e 23 saldos de estoque por item, 17 separações de jul–out (Separação Parcial) com 21
  itens e entregas, 23 parcelas, 17 boletos, 3 notas de homologação, transferências/devoluções — 748 linhas, cópia em
  `_bkp_limpeza_20261014_*`. Reservas de teste devolvidas (6 produtos). Ficam as 424 separações de fev–jun (histórico).
  Em seguida import de Produtos com `Produtos__2026-10-14.xlsx`: os 4.536 produtos da planilha ficam com estoque
  idêntico ao da Connect; 7 produtos novos da Connect cadastrados (`importar_produtos_novos.py`, códigos
  13765–13771). `_supabase_client.py` troca o host direto (só IPv6) pelo pooler da região do projeto.
- SPEC-192/198 VIRADA: banco oficial passa a ser o Supabase de São Paulo (`bgtfrcbipuxnsexbppsh`). Estrutura, dados,
  usuários e migrations copiados de Ohio e conferidos (134.014 linhas, tudo igual); 485 links de arquivo trocados;
  vault/cron/segredo do SharePoint em SP; os 17 sistemas da Cloudflare republicados apontando para SP; `.env` central
  em SP (Ohio comentado). Memória: `index.html` do Skip restaurado no GitHub.
- SPEC-198: Memória e Central de Solicitações na Cloudflare (`memoria-lucenera.pages.dev`,
  `solicitacoes-lucenera.pages.dev`). Central de Solicitações ganhou repositório no GitHub (submodule
  `04-Sistemas/central-de-solicitacoes`). Migration 209 (aplicada em SP): links do Hub dos dois.
- SPEC-183: migration 208 (aplicada) — as 13 pessoas da Equipe de Projetos (papel `equipe_projetos`) veem na
  Central Orçamentos, CRM, Consultar Produtos, Separação Parcial, Sistema de Entregas, Fichas Técnicas, Showroom e
  Memória (44 acessos acrescentados, nenhum removido; backup `_bkp_user_system_access_20261014`).
- SPEC-198: os 15 sistemas no ar na Cloudflare Pages (`*-lucenera.pages.dev`, banco de Ohio), iguais ao Skip.
  Links entre sistemas no código passam a apontar para `*.pages.dev` (13 repositórios). Migration 207 (aplicada): links da lista
  do Hub (`systems.link`) para `*.pages.dev`. Vendas: `pnpm-lock.yaml` atualizado.

## 2026-10-13

- SPEC-197: "Vínculo Connect" virou opção do Tipo de Operação no Novo Orçamento (ao lado de Venda/Devolução/Outros/
  SAC). Número da Connect só pelo XML; "Salvar e vincular" salva e já vincula (sem estoque, financeiro ou nota).
  Também ao editar uma venda importada do XML e ainda não vinculada. Migration 206: `vincular_orcamento_connect`
  aceita quem pode criar orçamento (antes só quem aprova); desfazer continua só para quem aprova. Orçamentos 32554
  v0.0.389.

## 2026-10-12

- SPEC-193 B3 etapa 2 (aprovada): migration 205 aplicada — `codigo_legado`, `percentual_lucro` e `categoria` (texto)
  removidas de `produtos`; `sku` virou coluna gerada = `referencia` (só leitura; PDF do orçamento e NF-e seguem
  funcionando). Funções e views mantêm o formato. Cadastro 36668 v0.0.105 (Salvar sem `sku`). Imports da Connect
  sem `percentual_lucro`. Cópia de segurança em `_bkp_spec193_produtos_colunas`; rollback testado.
- SPEC-193 C1/C3/C4: migration 204 (`vw_consulta_estoque`, consulta de estoque enxuta com saldos calculados no
  banco). Consulta de Produtos (Cadastro 36668 v0.0.104) abre em ~1,7 s (antes ~6,1 s); busca de peça do Orçamento
  (32554 v0.0.388) passa a mostrar o mesmo Disponível do Cadastro (292 peças mudam).
- SPEC-193 B2: `scripts/conferencia_marca_fornecedor.py` (roda também no fim do import de Produtos) gera a lista de
  conferência marca × fornecedor da planilha, sem gravar nada. Planilha 07/10: 45 marcas sem fornecedor, 9 marcas
  com fornecedor diferente na planilha, 944 peças divergentes.
- SPEC-193 B1/B3 etapa 1: telas passam a usar só `referencia` (sem `sku`/`codigo_legado` de produtos) e a categoria
  pelo `categoria_id`. O campo "Referência" do Cadastro grava em `referencia` (antes ia para `sku`). Publicados:
  Cadastro 36668 v0.0.103, Orçamentos 32554 v0.0.387, Showroom 54698 v0.0.20, Compras 40326 v0.0.84, Garantia 60545
  v0.0.13, Vendas 59346 v0.0.21.
- SPEC-193 C2/A1/B4: custo e impostos da peça só para a Administração (Lana, Débora, Carol, Matheus, Vinícius +
  Pedro/Filippo). Migration 202 (lista `produto_custo_visualizadores`, `pode_ver_custo_produto()`,
  `vw_produtos_custo`, coluna `produtos.tem_st`) e 203 (colunas de custo fechadas em `produtos` para `authenticated`;
  8 views de estoque/compra/vendas passam a ler `vw_produtos_custo_restrito`, custo nulo para quem não é da lista).
  Publicados: Cadastro 36668 v0.0.102 (bloco de custo escondido e não gravado para quem não vê; textos de ajuda de
  % ST / % IPI / % Frete / % Outras Despesas e "% Lucro (sobre o custo total)"), Orçamentos 32554 v0.0.386
  (Gerenciamento e resumo fiscal), Vendas 59346 v0.0.20 (DANFE), Compras 40326 v0.0.83 (pedido). Testado por perfil.

## 2026-10-11

- SPEC-194: 5 logins dos auxiliares de estoque criados e ligados ao funcionário (sem duplicado); login testado.
- SPEC-195 F1: área Estoque (Separação Parcial, Consultar Produtos, Sistema de Entregas) liberada para Vitória,
  Matheus, Alexandre e os 5 auxiliares; papel `estoque` para quem não tinha.
- SPEC-195 B: Consulta de Produtos (Cadastro 36668 v0.0.101) — filtro "Só com estoque", desativadas marcadas,
  coluna Categoria, linhas pretas, aviso "não disponível" ao lado do número.
- SPEC-196 Fase 2b: migration 201 aplicada — orçamentos, histórico, separações, entregas, garantia, projetos fechados,
  tipos de contato e empresas só para quem usa o sistema correspondente (representantes Ubiqua deixam de ver os
  orçamentos da Lucenera). Testado com login real.
- SPEC-196 Fase 2a: migration 200 aplicada — nada do banco legível sem login exceto o site do Showroom (146 objetos
  fechados: funcionários, faltas, backups do RH, auditoria, projetos, orçamentos, Ubiqua, estoque); RLS ligado em
  funcionarios; detalhes/benefícios só RH; permissões da Separação só admin. Regra de segurança no AGENTS.md.
- Login da Kimberly (adapta.org) bloqueado a pedido do usuário (ban no Auth + usuário inativo; reversível).
- SPEC-196 Fase 1: migration 199 aplicada — financeiro por sistema liberado (Acesso a Sistemas): transações só Adm.
  Bancária/Dashboard; dados de funcionários e comissões só RH; folha = RH ou a própria; Dashboard só Vinícius, Pedro e
  Filippo. Testado com login real do auxiliar.
- SPEC-196 Fase 0: migration 198 aplicada — contas a pagar/receber, duplicatas, transações completas, funcionários e
  comissões deixaram de ser legíveis sem login (antes: até 22.649 linhas pela chave pública). Conferido de fora: 401.
- SPEC-195 A: orçamento de **vínculo** de venda já aprovada na Connect — migration 197 aplicada (vincular/desvincular,
  proteções, correção do recálculo do valor do projeto); Orçamentos 32554 v0.0.385 e Vendas 59346 v0.0.19 publicados.
- SPEC-195 F1 (Projetos): Orçamentos, Entregas, Fichas Técnicas e Showroom para as 3 equipes de projetos.
- SPEC-195 F2: migration 196 aplicada — Distribuição de Lucro no Dashboard só para Filippo, Pedro e Vinícius (filtro no
  banco + cartão escondido, Skip 41135 v0.0.46); views financeiras fechadas para `anon`.

## 2026-10-09

### Contatos: novos tipos "Escritório de Arquitetura" e "Incorporadora"

- Migration `20261009_195` APLICADA: enum `contato_tipo` + check `contato_tipos_tipo_check` aceitam
  `escritorio_arquitetura` e `incorporadora` (mesmo padrão da 173/construtora). Teste com rollback: inserir contato com
  esses tipos cria a linha em `contato_tipos` pelo trigger. Nenhum sistema exibe os novos tipos ainda.

### SPEC-191: reunião 08/10 — Controle de Produção e Disponível da Consulta de Produtos

- Migration `20261009_194`: pedido de produção é inativado (não apagado); `producao_editores` + `producao_pode_alterar()`
  — todos veem, só Vinícius/Débora/Matheus/Vitória (+ suporte) alteram; `vw_cadastro_produto_movimentos.data_venda`.
- Controle de Produção Skip 60535 v0.0.16: abas Em aberto/Concluídos/Inativos, Inativar/Reativar, filtros "Empresas"/
  "Prioridade", coluna de ação fixa (Editar não sai mais da tela), "Somente visualização" para quem não altera.
- Cadastro Skip 36668 v0.0.100: Disponível = Geral − maior(reserva+separação do sistema, reservado da Connect), igual na
  lista e no painel (6654 = 19); data da venda nas abas; setores compactos; sem a faixa "Pendente".
- Pedido de compra de teste nº 1771 (10 un. da 6654) cancelado.

## 2026-10-08

### SPEC-190: Cadastro — custo da peça na lógica da Connect (reunião Vinícius 08/10)

- Regra: preço de custo (tabela do fornecedor) − % desconto = custo c/ desconto; + BDI (% frete + % ST + % IPI + % outras
  despesas sobre o custo c/ desconto) = custo total; × (1 + % lucro) = preço de venda. Confere com a Connect (custo total
  4.537/4.537).
- Cadastro Skip 36668 v0.0.99: Editar Peça com campo "% Desconto (fornecedor)", tela na ordem do negócio; ao abrir mostra
  o preço da Connect (12895 = R$ 142,29, não mais 155,36). v0.0.97 (derivava o custo) estava errada e foi substituída.
- `importar_produtos_estoque.py` grava `vlCusto → preco_custo` e `Lucro → margem_lucro`; 3.643 produtos corrigidos
  (preço de custo antigo, ex.: 10539 564,55 → 601,00). 21 produtos em que a Connect não segue a regra ficaram para o Sérgio.

### Todos os sistemas: página em pt-BR e sem tradução automática do navegador

- `index.html` com `lang="pt-BR" translate="no"` + meta `notranslate` em 12 sistemas (os outros 3 já eram pt-BR). Evita o
  erro "removeChild" que o tradutor do Edge/Chrome causava (caso da Lana no RH).

### RH: erro "removeChild" ao salvar férias no Edge da Lana

- Causa (registrada em `erros_tela`, migration `20261008_193_erros_tela`): tradutor automático do navegador alterando o DOM do
  React — a página se declarava `lang="en"`. RH v0.0.235: `lang="pt-BR" translate="no"` + meta `notranslate`.

### SPEC-189: RH — faltas de 2026 da planilha e fim da tela branca

- Tela branca (Lana): recarrega sozinho quando a página antiga some após publicação + `ErrorBoundary` com "Recarregar".
  RH Skip 23919 v0.0.233.
- `Controle de Faltas.xlsx` (2026 até 08/10): 164 registros novos lidos pela cor da legenda (falta, folga, atestado,
  licença-maternidade da Thairine e da Thais); 135 existentes mantidos.

### SPEC-188 (ajuste): férias sem período não descontavam o saldo

- Migration `20261008_192_ferias_periodo_automatico`: trigger liga a férias ao período do próprio funcionário; views de saldo
  com `security_invoker` (fecha leitura de saldos de todos). RH Skip 23919 v0.0.232 sem o campo "Período Aquisitivo Base".

### SPEC-188: RH — controle de férias importado da planilha da Lana

- Migration `20261008_191_ferias_controle_planilha`: lançamentos sem data (`ferias_lancamentos`), saldo por período
  (`vw_ferias_periodos`), saldo total pela regra da planilha e geração automática de períodos (pg_cron diário).
- Importados 24 funcionários (51 períodos, 95 férias, 43 lançamentos); admissões de Thais, Giovanna Nori, Lana e Vitória
  corrigidas; Teresinha inativa. RH Skip 23919 v0.0.231: período base mostra saldo.
- Correção: 14 funcionários duplicados criados pelo gatilho `handle_new_user` (contas da SPEC-187) — contas ligadas ao
  cadastro real e duplicados apagados.

### SPEC-187: contas novas da equipe e página "Minha senha" na Central

- 14 contas criadas com a senha padrão via `criar_usuario` (Terezinha não; Marina, Thairine, Mariane e Filippo já tinham).
- Central (Skip 37750 v0.0.49): `/minha-conta` com botão "Minha senha" no cabeçalho; confere a senha atual antes de trocar.

### SPEC-186: RH — saldo de férias zerado para quase todos

- `vw_controle_ferias_clt` passa a calcular pelo último período aquisitivo completo desde a admissão (30 dias − férias
  aprovadas iniciadas depois do fim dele); antes dependia de `periodos_aquisitivos` cadastrados à mão (7 pessoas).
  Regra provisória até o PDF de controle. Migration `20261008_190_saldo_ferias_ultimo_periodo`; nova coluna
  `data_limite_gozo` reativa o aviso "férias a vencer" da página inicial.

### SPEC-185: RH — férias sem etapa de aprovação

- Nova solicitação nasce `Aprovado`; botões Aprovar/Rejeitar removidos; `ferias.status` default `Aprovado` e a única
  pendente (Isabella, 07/09–11/09) virou Aprovado (migration `20261008_189_ferias_sem_aprovacao`). RH Skip 23919 v0.0.230.

### RH: salvar funcionário sem empresa dava erro (`funcionarios_beneficios_empresas.empresa` NOT NULL)

- `updateEmployee`/`createEmployee` gravavam sempre a linha de benefício com `empresa: data.empresa || null`;
  sem empresa no cadastro, o salvar quebrava depois de já ter gravado `funcionarios_novo` (por isso a Teresinha
  já aparecia desativada). Agora o benefício só é gravado quando há empresa. Afetava também Giovana, Isabella e
  Vitória (sem empresa).
- RH Skip 23919 v0.0.229 (`acd9d55`) publicado. Antes, com autorização do usuário, as 14 migrations legadas não
  registradas (mar–abr) foram retiradas da working tree do Skip (continuam no git do RH); conferido depois do
  apply: `schema_migrations` (241), policies (402) e Edge Functions inalteradas.

### SPEC-184: Showroom — tirar peça da vitrine e trazer de volta

- Migration `20261008_187_showroom_ocultar_peca` + Showroom Skip 54698 v0.0.18.

## 2026-10-07

### GitHub sincronizado com o código publicado no Skip

- O código de `src/` dos 16 sistemas (e `public/app/` da Memória Lucenera) foi copiado da versão no ar e
  commitado/enviado em cada repositório. Fonte: source maps de um build de prévia novo gerado em cada projeto
  (`skip_project_apply_changes` em modo development, sem mudança de código) — o build de prévia anterior estava
  desatualizado e não serve de fonte. Antes de cada build: migrations da working tree conferidas contra
  `schema_migrations` (só a `seed_admin_user` da Logística segue pendente e falha sem efeito); depois: nenhuma
  Edge Function republicada e `schema_migrations` inalterada. O RH não passou pelo build (14 migrations antigas
  pendentes na working tree); a prévia dele foi conferida contra `skip_file_read`.
- Fora da sincronização: imagens, `package.json`/configs e `supabase/` das working trees. Mudanças locais que
  não estavam commitadas ficaram num `git stash` ("backup antes do sync com o Skip 2026-10-07") em cada repo.

### SPEC-183: Acesso a Sistemas define o que a pessoa vê; papel define o que ela faz

- Migration `20261007_186_spec183_acesso_sistemas_visibilidade` aplicada (dry-run com ROLLBACK antes):
  `hub_sistemas_permitidos` passa a ler só `user_system_access`; `hub_pode_executar` ganhou o portão de acesso
  (admin passa direto); policy `user_insert_usa` removida. Cada pessoa ficou com o que via antes; a Mariane
  com a lista marcada pelo usuário (sem Adm. Bancária, com Showroom e Memória).
- Central (Skip 37750 v0.0.47): textos e aviso nas abas Acesso a Sistemas, Matriz de Acesso, Papéis e Exceções.

### Sync Connect (planilhas de 07/10), migration 159 e DEV TROCA

- 4 imports gravados (via session pooler: o host direto do banco só resolve IPv6); dry-run pós-gravação zero;
  conferência planilha × `v_financeiro_realizado` = R$ 0,00.
- Migration `20260922_159_sync_connect_reconciliacao` aplicada: 155 pedidos de compra marcados `vigente=false`.
- DEV TROCA = DEVOLUÇÃO (2020028): regra no import + backfill de 505 negociações (R$ 1.793.930,18).

### Relatório de alterações 07/08 a 07/10

- `03-Projeto/08_RELATORIO_ALTERACOES_07_08_a_07_10_2026.pdf` (usabilidade × sistêmica, solicitante e datas).

## 2026-10-06

### Vendas e impressão da separação: pedidos da reunião de 05/10 que tinham ficado de fora

- **Vendas** (Skip 59346 v0.0.16), reunião [00:00]–[01:10]: lista em largura total, uma linha por venda (cliente e
  projeto cortados com "…", completos ao passar o mouse), letra um pouco menor, sem a coluna Orçamento (fica só o
  número da venda) e status da nota sem repetir "Nota": Pendente / Parcial / Emitida.
- **Separação Parcial** (48801 v0.0.49), reunião [10:00]: a primeira coluna da impressão passa de "L" para "ID".
- Repositórios: Separação Parcial `b4188d7`, Vendas `4872ce0` (ponteiros atualizados).

### Separação Parcial: janela "Ver itens" e impressão do Pedido em Separação (ajuste da SPEC-182)

- **Separação Parcial** (Skip 48801 v0.0.48): a janela "Ver itens" ficou maior, com os dados da venda (número,
  empresa, cliente, projeto, vendedor, endereço, telefone) e da parcial (data, funcionário, previsão de entrega,
  totais separado/estornado/na parcial), e Referência e Descrição em colunas separadas.
- **Impressão**: colunas L · Cód. · Ref. · Descrição · Quant.; descrição em letra menor e quebrando linha (não corta
  mais); itens em ordem de L (reunião de 05/10); volta a declaração "Assumo total responsabilidade pelas mercadorias
  correspondentes a esta entrega, bem como declaro correto o conteúdo e as quantidades mencionadas acima" (texto da
  SPEC-144). A reimpressão usa a previsão de entrega da venda.
- Pendente: endereço de entrega próprio na impressão (hoje sai o endereço do cliente).
- Repositórios: Separação Parcial `57d8624` (ponteiro atualizado).

### SPEC-182: revisão de 05/10 — devolução pelo código do projeto, números sem prefixo e consulta de peça com abas

- SPEC nova (`SPEC-182_Revisao_05_10_Devolucao_por_Cliente_e_Ajustes.md`), a partir da reunião de 05/10 com o
  Vinícius; desfaz partes das SPECs 179/180/181.
- **Banco** (migration `20261006_184_devolucao_por_projeto`, dry-run com ROLLBACK antes; `rollback.sql` na pasta):
  coluna `estoque_saldos_projeto_item.q_devolvida_entregue` — Entregue não baixa na devolução, só a devolvida sobe;
  `fn_validar_saldo_projeto_item` não conta o entregue devolvido duas vezes; `registrar_devolucao_projeto_item_setor`
  recusa "em separação", grava sempre `registrada` e libera a reserva (fim da etapa "Recebida");
  `aprovar_orcamento_financeiro` confere cada item contra venda efetivada do mesmo projeto e empresa
  (`venda_origem_id` sem uso); `vw_estoque_saldos_projeto_item` expõe `q_devolvida_entregue` e `empresa_id`.
- **Orçamentos** (Skip 32554 v0.0.382): devolução pelo código do projeto (janela "Vincular venda" removida); aviso
  quando o projeto tem vendas em mais de uma empresa; busca de itens por projeto + empresa com "Em separação"
  bloqueada; preço líquido sem %; Carteira e frete opcional na devolução; datas digitáveis; botão "Salvar orçamento";
  números sem "ORC-/VENDA-" nas telas.
- **Separação Parcial** (48801 v0.0.47): sem "Devoluções a receber"; "Ver itens" + "Reimprimir" por parcial; texto
  explicando "Estornar".
- **Logística** (24039 v0.0.98, só no Skip — o git local tem o rollout do SystemSwitcher pendente): pop-up
  "Separação cancelada" (pendência `separacao_estornada`, "Ciente" por navegador) e números sem prefixo. O apply rodou
  as 2 migrations legadas do projeto: `seed_admin_user` falhou sem efeito e `fix_foreign_key_entregas_finalizadas`
  registrou sem mudar nada; retirar a seed do Skip continua pendente.
- **Vendas** (59346 v0.0.15) e **Compras** (40326 v0.0.80): números sem prefixo.
- **Cadastro** (36668 v0.0.93 e v0.0.94): busca de peças não é mais sobrescrita pela carga inicial em lotes (C1);
  consulta de peça no modelo do Connect (C2) — área larga abaixo da lista, cabeçalho com Disponível em destaque e
  abas Setores / Reserva / Entrega Futura / Separação / Entregue / Compras (migration
  `20261006_185_cadastro_peca_abas_setores`: view `vw_cadastro_produto_movimentos`; pedidos de compra com data de
  emissão e perfil).
- Nenhuma Edge Function redeployada. Pendentes: T1/T2 (vendas de teste, ORC-0037) e PDF da Edge Function com prefixo.
- Repositórios: Orçamentos `da1efb1`, Separação Parcial `51e6721`, Vendas `6d387a0`, Compras `973d178`,
  Cadastro `276858b` (ponteiros atualizados).

## 2026-10-05

### SPEC-181: devolução/troca vinculada obrigatoriamente a uma venda efetivada

- SPEC nova (`SPEC-181_Devolucao_Troca_Vinculada_a_Venda.md`), regra combinada com o administrador.
- **Orçamentos** (Skip 32554 v0.0.381): escolher Devolução abre na hora a janela "Vincular venda de origem"; ao
  vincular, Empresa, Código do Projeto e Cliente vêm da venda e ficam travados (vendedor e arquitetos copiados);
  "Buscar itens da venda" só libera com a venda vinculada e mostra só os itens dela; salvar sem venda, com item de
  outra venda ou empresa diferente é bloqueado. Vale para TROCA DEV e CASA COR ENTRADA. Substitui o "aviso sem
  trava" de empresa de 03/10 (decisão do usuário).
- **Banco** (migration `20261005_183_devolucao_venda_origem`, dry-run com ROLLBACK antes; `rollback.sql` na pasta):
  coluna `orcamentos.venda_origem_id` (sem FK, evita embed ambíguo no PostgREST) e `aprovar_orcamento_financeiro`
  recusa devolução sem venda, com empresa/cliente/projeto diferentes da venda ou com item de outra venda.
- Testado na tela sem salvar (VENDA-0001). Nenhuma Edge Function redeployada.
- Repositórios: Orçamentos `24b5554` (pushado; ponteiro atualizado).

## 2026-10-03

### SPEC-180: etapa Recebida na devolução, aviso de empresa, correções da rodada de testes e desempenho do banco

- SPEC nova (`SPEC-180_Devolucao_Recebida_Aviso_Empresa_e_Desempenho.md`), após a rodada de testes das SPECs 176–179.
- **Etapa "Recebida"** (migration `20261003_182_devolucao_recebimento`): devolução de material **Entregue** fica
  `aguardando_recebimento` na aprovação, sem liberar a reserva; na **Separação Parcial** (Skip 48801 v0.0.46), botão
  "Devoluções a receber" com "Confirmar recebimento" (RPC `confirmar_recebimento_devolucao`) — só então o disponível
  sobe e o status vira `recebida`. Reserva / Em separação / Entrega futura continuam com efeito na aprovação.
- **Empresa diferente:** a devolução continua herdando empresa/equipe da venda, mas sem trava — linha de venda de outra
  empresa entra com aviso (toast) ao escolher e ao salvar (decisão do usuário). Orçamentos Skip 32554 v0.0.380.
- **Correções da rodada de testes:** arquiteto vazio ao abrir o orçamento por link direto/F5 (salvar podia apagar o
  vínculo); barra de totais não ficava fixa (`Layout.tsx` com `overflow-x-clip`); L da venda renumerado na devolução;
  previsão de entrega 1 dia antes na impressão da separação.
- **Limpeza de teste** (migration `20261003_180_limpar_transferencia_teste`): apagadas as 2 trocas de reserva de teste
  entre os aros da VENDA-0001 e VENDA-0002 e seus 4 movimentos; `q_transferida_saida` zerado; saldos inalterados.
- **Desempenho** (migration `20261003_181_rls_hub_pode_executar_uma_vez_por_consulta`): 51 políticas RLS chamavam
  `hub_pode_executar` por linha; agora 1 vez por consulta (função `STABLE` + `(SELECT …)`). Produtos: 3 páginas
  1.099 ms → 26 ms (5 páginas ≈ 50 ms no ar); mesmas linhas, usuário sem permissão continua sem acesso.
  `rollback.sql` com as 51 políticas originais. Ficam como pontos de decisão: banco em us-east-2, instância pequena,
  orçamento baixando catálogos inteiros ao abrir.
- Todas as migrations testadas com ROLLBACK antes de aplicar. Nenhuma Edge Function redeployada.
- Repositórios: Orçamentos `e5ad289`, Separação Parcial `026ae37` (pushados; ponteiros atualizados).

## 2026-10-02

### SPEC-177/178/179: Orçamento em abas e rotina de devolução (valor líquido, empresa da venda, setores)

- **SPEC-177 — Orçamento em 3 abas** (Skip 32554 v0.0.378): "Dados do Cliente / Arquiteto", "Produtos" e
  "Condição de Pagamento"; resumo do que já está preenchido no topo (cliente, projeto, arquiteto, vendedor,
  empresa, previsão); totais em barra fixa no rodapé (mesmos cálculos); destaque do preenchido no padrão do
  Cadastro; arquiteto vinculado em destaque no `ArchitectSplitPicker` (caso Cacau Ribeiro / ORC-0036); listagem
  mostra todos os arquitetos da divisão.
- **SPEC-178 — Devolução** (v0.0.379): busca da venda de origem com colunas L / Código / Referência / Descrição /
  Nº da Venda / Qtd. da Venda / A Devolver; preço líquido com o desconto da venda (R$ 4.031,21 com 8% =
  R$ 3.708,71); a devolução herda empresa, vendedor e arquitetos da venda e trava a empresa; só venda efetivada
  (com número de venda); conferência ao salvar. ORC-0036 (teste MANOELLA × venda FOCO) cancelado.
- **SPEC-179 — Saldo e setores**: disponível para devolução = vendido − já devolvido (reserva, entrega futura,
  em separação e entregue); uma linha por setor (`orcamento_itens.setor_origem`); reserva / em separação /
  entregue liberam a reserva do produto (entregue volta ao estoque na aprovação); entrega futura reduz a
  necessidade de compra.
- **Banco:** migration `20261002_178_devolucao_por_setor` aplicada (dry-run com ROLLBACK antes; `rollback.sql`
  na pasta): coluna `setor_origem`, `replace_orcamento_itens`, `registrar_devolucao_projeto_item_setor`
  (setor em_separacao; entregue baixa `q_entregue`), ramo de devolução de `aprovar_orcamento_financeiro`, e os 3
  triggers da separação passam a mover só `quantidade − quantidade_estornada` (corrige também o estorno
  parcial). Nenhuma Edge Function redeployada.
- Impacto em outros sistemas: a aba de devolução do Compras usa a mesma RPC por setor.
- Repositórios: Orçamentos `b67b6ac` (pushado; ponteiro atualizado).

### SPEC-176: impressão da separação, listagem da Separação Parcial e empresa/busca em Vendas

- SPEC nova (`SPEC-176_Impressao_Separacao_Listagem_Separacao_Vendas_Empresa.md`), pedido do administrador.
- **Separação Parcial** (Skip 48801 v0.0.45): impressão "Pedido em Separação" com logo, sem a coluna "Conf.",
  referência + descrição em linha única, Cód. Ref./Quantidade centralizados e rodapé só com Entregador e Recebedor;
  número `ORC-0032-P3 / VENDA-0001` virou `Venda 0001-P3`. Listagem sem a coluna de orçamento, venda sem prefixo,
  cliente — projeto na mesma linha, empresa, data da venda (`aprovado_cliente_em`) e previsão de entrega. Sem valor
  em dinheiro (SPEC-072 mantida, decisão do usuário).
- **Vendas** (Skip 59346 v0.0.14): coluna Empresa Faturada, busca (venda, orçamento, cliente, projeto, empresa) e
  filtro por empresa combinados.
- Sem impacto no banco. Nenhuma Edge Function redeployada.
- Repositórios: Separação Parcial `9affcef`, Vendas `7c621d6` (pushados; ponteiros atualizados).

### SPEC-172: "Enviar por E-mail" do Catálogo Ubiqua baixa o PDF antes de abrir o e-mail

- Catálogo Ubiqua (Skip 33302 v0.0.98): o botão gera e baixa o PDF (mesma função do "Baixar PDF") e só então abre o
  `mailto:`; o usuário anexa o arquivo. `mailto:` não aceita anexo e o envio por SMTP continua descartado
  (decisão do usuário reconfirmada em 02/10). Erro no PDF = e-mail não abre.
- Repositório: Catálogo Ubiqua `6993419` (pushado; ponteiro atualizado).

### SPEC-174: N2a, N3, N5–N8, N10 e N11 publicados; SPEC-175 (estoque por empresa) criada

- **Orçamentos** (Skip 32554 v0.0.377): N2a — pop-up obrigatório de Previsão de Entrega na aprovação da equipe e em
  toda gravação nessa etapa (grava `orcamentos.previsao_entrega` e registra a data no histórico via
  `equipe_aprovar_orcamento`); N3 — aviso de orçamento vencido (validade de 10 dias) oferecendo atualizar os preços
  pelo preço de venda atual, mantendo descontos, sem salvar sozinho.
- **Cadastro** (Skip 36668 v0.0.90): N5 destaque da peça selecionada, N6a botão Salvar sem corte, N6b estoque
  integrado na vertical com Showroom; N7 Editar/Copiar/Excluir só com a ação "editar" do Hub; N8 Casa Cor/Garantia
  aparecem mas não somam no estoque geral/disponível.
- **Controle de Produção** (Skip 60535 v0.0.14) e **Controle de Garantia** (Skip 60545 v0.0.10): N10 aba Log só para
  admin; N11 status da Produção em Select real (o `<datalist>` não abria dentro do modal).
- **Banco:** migrations `20261001_174b_log_producao_garantia` (tabelas de log + triggers; aplicada por engano durante
  um dry-run em 01/10 — o arquivo tem `COMMIT;` próprio — e mantida), `20261001_174c_cadastro_permissao_editar`
  ("editar" no Cadastro para `compras_e_entregas` e `estoque`) e `20261001_174d_estoque_casa_cor_garantia_fora_do_geral`
  (view `vw_produtos_estoque_detalhado`). Nenhuma Edge Function redeployada nos applies/publishes.
- **Incidente 01/10 (Cadastro v0.0.88):** regravar o `deno.json` raiz das functions redeployou as 13 funções do
  Cadastro; `salvar-projeto` voltou à cópia antiga (sem SPEC-077) por ~5 min e foi restaurado com a cópia do CRM.
- SPEC-175 (`SPEC-175_Estoque_Por_Empresa.md`): levantamento e 3 alternativas de modelagem para estoque por
  empresa (Manoela, Foco, ISLIGHT); recomenda ledger separado. Sem implementação.
- **N7 (decisão 02/10):** só a administração edita e cria peça no Cadastro (`admin`, `admin_geral`,
  `administracao_comercial`, `compras_e_entregas`); migration `20261002_174e_cadastro_editar_criar_so_administracao`
  aplicada; "Nova Peça" escondido sem a ação "criar" (Cadastro Skip 36668 v0.0.91).
- **N6c:** Consultar Produtos mostra sempre os 8 setores obrigatórios na vertical (Estoque Geral, Showroom, Garantia,
  Casa Cor, Reserva, Separação, Entrega Futura, Amostra / Emprestado) — Cadastro Skip 36668 v0.0.92; view nova
  `vw_cadastro_produto_setores` (migration `20261002_174f`).
- Repositórios: central + Compras `8996f34`, Cadastro `43fa8ae`, Orçamentos `2f8b271`, Produção `732ad18`,
  Garantia `dc18683` (todos pushados; ponteiros atualizados).

## 2026-10-01

### SPEC-174: conferência das entregas de 22/09 a 01/10 e novos pedidos da reunião de revisão

- SPEC nova (`SPEC-174_Conferencia_Reuniao_01_10_e_Novos_Pedidos.md`), a partir da reunião de revisão com o
  Vinícius (`02-Reunioes/26. ... 01.10.2026_Reunião revisão do sistema/Reunião.01.txt`). Só documentação, sem
  código e sem banco.
- Parte A: tabela de conferência de tudo que foi entregue desde 22/09 (SPEC-158 a SPEC-173 + Sync Connect),
  marcando o que foi conferido OK, o que teve ajuste pedido e o que ainda não foi conferido (Garantia, Adm.
  Bancária, Memória, entre outros).
- Parte B: 12 pedidos novos. Definidos: cards da Central abrem o sistema em nova aba (o menu lateral continua
  na mesma aba), pop-up obrigatório de Previsão de Entrega na aprovação da equipe com a data levada até a
  Necessidade de Compra, busca da Necessidade de Compra igual à do orçamento, destaque do produto
  selecionado, botão Salvar cortado e estoque integrado na vertical no Cadastro, permissão de edição de
  produto pelo Hub. A definir: atualização de preço após a validade de 10 dias, estoque Casa Cor fora do
  estoque geral, log para admin e status "Pedido de produção". Estoque por empresa (Manoela, Foco, ISLIGHT)
  fica para uma SPEC própria.
- Repositórios: só o central.
- N1 publicado: na Central (Skip 37750 v0.0.46, `7c2bcf9`), o card de sistema abre em nova aba (já logado
  via SSO) e o menu lateral continua trocando a mesma aba. Corrigido `cross-system-auth.ts`: a opção `newTab`
  existia mas nunca funcionava (`window.open` com `noopener` devolve `null`). Sem impacto no banco; nenhuma
  Edge Function redeployada. Testado no preview e conferido no bundle de produção. Submodule local da Central
  não atualizado (rollout SPEC-120 pendente).

## 2026-09-30

### SPEC-172: Catálogo Ubiqua — desconto %, PDF real, cadastro completo de cliente e e-mail via mailto

- Desconto global do orçamento passa a ser em % (0–100): grava `desconto_percentual`, `valor_desconto` e
  `valor_total`; resumo da tela, detalhe do admin, PDF e e-mail usam a mesma conta.
- "Baixar PDF" gera `.pdf` de verdade pela Edge Function nova `gerar-pdf-orcamento-ubiqua` (pdf-lib, layout do
  orçamento Lucenera), só com dados da Ubiqua (tabela nova `configuracao_empresa_ubiqua`; `empresa_ubiqua` é a
  tabela dos parceiros e não é usada). Logo laranja do site ubiqualamps.com em `Logo/ubiqua-logo-orange.png`.
- Cadastro de cliente completo (endereço com busca de CEP, IE e regime só para CNPJ, entrega, cobrança,
  transportadora, e-mails comercial/financeiro), com edição.
- "Enviar por E-mail" abre o programa de e-mail do computador (`mailto:`) com assunto e corpo preenchidos; o
  sistema não envia e-mail (sem SMTP/backend/anexo), igual à Lucenera (SPEC-067).
- Banco: migration `20260930_172_ubiqua_orcamento_pdf_cliente` aplicada.
- Incidente: o apply v0.0.95 do Ubiqua (arquivo novo em `_shared/`) redeployou as 15 Edge Functions da working
  tree; `generate-report`, `salvar-projeto` e `parse-budget-pdf` voltaram a versões antigas. Restauradas na
  v0.0.97 com as cópias do Compras, CRM e Cadastro (conferido baixando o que está no ar).
- Publicado Skip 33302 v0.0.97 (`6d253b3`); submódulo `catalogo-pecas-ubiqua-e6fa0` em `0f48835`.
- Pendente: dados cadastrais da Ubiqua (razão social, CNPJ, endereço, telefone) e decisão sobre a notificação
  Gmail do `process-budget-pdf` no "Finalizar".

## 2026-09-29

### SPEC-165: Memória Lucenera — importar reunião de projeto, decisões por projeto e fila de revisão

- Segundo ajuste: importação dentro de "Reunião de projeto"; após registrar abre a edição para corrigir o que a IA
  preparou e as sugestões pendentes (migration `002_sugestao_editavel_enquanto_pendente`). Publicado `44088bd`.
- Ajuste (mesmo dia, pedido do usuário): a reunião importada vai direto para o histórico do projeto; só as sugestões
  de aproveitamento passam pela Revisão. Publicado `7cfe5ec`.
- Reunião de projeto vira histórico: andamento, próximos passos e decisões estruturadas vinculadas ao código do
  projeto (`kb_decisoes`), com marca de solução excepcional. Página "Histórico do projeto" (`/projeto/:codigo`).
- "Importar reunião" (texto, .txt/.md/.docx ou Pendentes antigos): Edge Function `interpretar-reuniao` (Gemini) propõe o
  registro; a pessoa confere e salva.
- Sugestões de aproveitamento para os demais temas vão para a fila "Revisão" (`kb_sugestoes`); só curador aprova
  (criando o item no tema) ou rejeita. Banco impede aprovação automática e sugestão a partir de solução excepcional.
- Migration `20260929_165_memoria_reunioes_revisao` aplicada; frontend publicado (`2b5bb48`); teste ponta a ponta no navegador.


### Sync Connect (planilhas de 29/09) — primeira execução real da versão SPEC-157

- Produtos novos: 2 criados. Estoque: 632 produtos atualizados (preço de venda conferido, intacto).
  Pedidos de compra: 13 novos, 13 atualizados. Contas: 73 duplicatas novas, 125 parcelas novas,
  110 atualizadas, 14 parcelas órfãs canceladas.
- 3 falsos "alterados" corrigidos nos scripts (NaN em `dt_pagamento`, arredondamento de
  `percentual_lucro` e de `valor_nota`) — dry-run pós-gravação com zero pendências nos 4 scripts.
- Conferência planilha × `v_financeiro_realizado`: R$ 0,00 de diferença (pago jun–set, em aberto set–dez).
- Pendente: migration `20260922_159_sync_connect_reconciliacao` (SPEC-157) segue não aplicada; 14 despesas
  novas com `cod_apropriacao = 1` sem categoria (decisão do usuário).

## 2026-09-28

### SPEC-171: Catálogo Ubiqua — estoque atual de produtos e pedido dividido entre referências

- **Catálogo Ubiqua** — o estoque exibido vinha de `revenda_ubiqua.disponivel`, cópia parada de 03/06; agora
  vem de `produtos` (import do Connect) pela função nova `ubiqua_estoque_atual()` (SECURITY DEFINER, só
  referência + disponível). Cor com 2 referências (Manoella e -IS): o orçamento aceita a soma e divide o
  pedido entre elas. Ex.: FLORA VERDE SALVIA mostrava 14, aceitava 11; agora mostra e aceita 12 (10 + 2).
- Migration `20260928_171_ubiqua_estoque_atual` **aplicada**. Publicado no Skip 33302 v0.0.94 (`be3b4e1`).

### SPEC-170: Catálogo Ubiqua — botões Sair e Excluir conta

- **Catálogo Ubiqua** — "Sair" no topo, no Perfil e no onboarding; "Excluir conta" (confirmação digitando
  EXCLUIR) no Perfil e no onboarding. Edge Function nova `excluir-conta-ubiqua` apaga só a conta de quem chama
  e recusa equipe Lucenera (cascata em `usuarios`/`memoria`), admin e representante com clientes.
- Sem migration. Publicado no Skip 33302 v0.0.92 (`acf7869`).

### SPEC-168 + SPEC-169: Catálogo Ubiqua — foto de toda variante no admin e cadastro sem confirmação

- **Catálogo Ubiqua** — admin: cada card lista todas as variantes do grupo (antes só 1 por cor; 13 variantes
  não tinham como receber foto). Cadastro: Edge Function nova `cadastro-ubiqua` cria a conta já confirmada e o
  site entra direto. A confirmação de e-mail continua ligada no Supabase para os outros sistemas.
- Sem migration. Publicado no Skip 33302 v0.0.91 (`61e0030`); só `cadastro-ubiqua` foi deployada.

### SPEC-164: Memória Lucenera — formulário de item novo travado (correção)

- Os 9 formulários de inserção congelavam a página (loop infinito de renderização causado por um array
  padrão recriado a cada render em `FormularioItem`). Corrigido e publicado (`3371e9f`); digitação
  verificada na produção nos 9 tipos e no fluxo Pendentes → Reunião de projeto. Sem impacto no banco.

## 2026-09-28

### SPEC-167: Previsão de Entrega no orçamento

- **Banco** — migration `20260928_167_orcamento_previsao_entrega` aplicada: `orcamentos.previsao_entrega date` (opcional).
- **Orçamentos** — campo no formulário (ao lado de Validade) e coluna na lista (abas Todos/Aprovados). Editar a
  previsão não reinicia a aprovação. Publicado no Skip 32554 v0.0.375 (`fa4e7e4`); submodule `b130077`. Banco e Edge Functions sem alteração pela publicação.

## 2026-09-28

### SPEC-166: Referência do produto na Necessidade de Compra

- **Banco** — migration `20260928_166_necessidade_compra_referencia` aplicada: `vw_necessidade_compra` ganha
  `referencia` (produtos.referencia) como última coluna; resto da view inalterado (237 linhas antes/depois).
- **Compras** — coluna "Referência" na grade e busca multi-termo passa a casar também pela referência.
  Publicado no Skip 40326 v0.0.78 (`e117587`); submodule `a61f162`.
- **Edge Function** — cópia de `generate-report` no Compras estava velha; trocada pela versão no ar antes de publicar
  (redeploy v100 com mesmo conteúdo da v99, PDF sem regressão).

## 2026-09-28

### SPEC-165: /admin do Showroom acha e edita toda peça da vitrine

- **Showroom** — as 123 peças da página inicial já estavam na lista do /admin, mas escondidas: a aba padrão
  ("Vincular do PPT") não tem as 33 peças Ubiqua, e na aba de fotos elas vinham depois de 158 produtos sem foto.
- Aba renomeada para "Peças e fotos" e aberta por padrão; filtro Na vitrine / Sem foto / Todos (mesma regra de
  `vw_showroom_publico`); badge "Na vitrine"; busca local por nome, marca, referência e códigos.
- Sem mudança de banco. Publicado no Skip 54698 v0.0.16 (`e4713c0`); submodule `11c3df7`.

## 2026-09-28

### SPEC-165: Administração Bancária (CNAB 400, duplicatas) + JSON da NF-e

- **Banco** — migration `20260928_164_adm_bancaria_cnab` aplicada: dados de cobrança por conta, nosso número
  bancário, `reservar_remessa_cnab`, `processar_retorno_bancario` reescrita (status `Pago`, ocorrências 02/03/06/15/17,
  juros, sem baixa duplicada).
- **Adm. Bancária** (Skip 36395 v0.0.75) — remessa e retorno CNAB 400 no layout Bradesco, edição de duplicata sem
  perder baixa, filtros/colunas reais, baixa duplicada bloqueada, erros do banco tratados.
- **Vendas** — JSON Focus NFe com pagamento, destino, consumidor final, regime, CEST e e-mail; bloqueios para dados
  fiscais ausentes. Deploy da Edge Function pendente (manual).
- **Incidente revertido** — publicação reexecutou migration legada (dados de teste + policies abertas); revertido
  por `20260928_165_reverter_reexecucao_billing_automation`. Migrations legadas não registradas ainda existem no
  Skip de RH, CRM e Logística.

## 2026-09-25

### SPEC-164: PDF de orçamento aprovado sai com o número da venda

- **Orçamentos** — Edge Function `generate-report`: com `numero_venda`, o canto superior direito do PDF mostra
  "Venda VENDA-XXXX" (padrão Connect) em vez de "Orçamento ORC-XXXX"; arquivo baixado `Venda_VENDA-XXXX.pdf`.
  Publicado (função v99, Skip 32554 `8594ad5`, submodule `95f136c`). Testado com PDF real.
- Achado: a função publicada antes (v98) não tinha as mudanças de PDF da SPEC-152 (parcelas) e SPEC-158
  (digitador) — foram ao ar agora junto. Etapa "integrations" do Skip falha em 3 migrations legadas do próprio
  sistema (sem efeito no banco, conferido).

### SPEC-162 (revisão): ocorrências com tipo livre, fotos e "resolvida" com data

- **Controle de Produção** — "Outro (escrever)" abre um campo livre para o tipo; fotos opcionais (várias) por
  ocorrência; botão "Marcar como resolvida" com a data em que foi resolvida. Listagem mostra ocorrências em aberto.
- Migration `20260925_163_producao_ocorrencias_fotos_resolvida` **aplicada**: `fotos_urls text[]`,
  `resolvida_em date`, `resolvido_por uuid`; UPDATE do `authenticated` restrito por GRANT de coluna às colunas
  de resolução.
- Publicado no Skip 60535 v0.0.10; submodule `ef31232`.

## 2026-09-24

### SPEC-164: Memória Lucenera readaptada de memória pessoal para base de conhecimento corporativa

- Diagnóstico em `04-Sistemas/memoria-lucenera/DIAGNOSTICO.md` (stack, modelo, telas, classificação
  MANTER/ADAPTAR/REMOVER). Achado crítico: RLS por dono deixava os 54 itens da base invisíveis para
  todo mundo além de quem os importou; `owner_id ON DELETE CASCADE` apagaria o conhecimento de quem
  fosse desligado.
- **Banco (schema `memoria`)** — migration `supabase/db/migrations/20260924_164_memoria_base_corporativa/`
  (**aplicada em 24/09**, 001-005 + `006_correcoes_pos_teste`): `kb_itens` (9 tipos em enum, 5 núcleos derivados,
  campos do template em jsonb, tags, status rascunho/publicado/arquivado, origem manual/importada com
  chave estável, autor com `ON DELETE SET NULL`), `kb_itens_versoes`, `kb_anexos` (prefixo `kb/` no
  bucket existente, pronto para busca por imagem futura), `kb_sinonimos` (21 grupos de jargão de light
  design), RPCs `kb_buscar`/`kb_sugerir`, RLS "todos os internos leem, autor ou curador edita",
  `aprovar` no sistema `memoria` para `admin`/`admin_geral` (curador). Conteúdo existente **copiado**
  (tabelas antigas intactas).
- **Memória Lucenera (Skip 57204)** — interface React nova (home com busca dominante, autocomplete,
  chips por núcleo, atalhos por tema, inserção guiada pelos 9 templates, anexos, pendentes antigos).
  App antigo mantido em `/legado`, sem cadastro aberto nem demonstração. **publicada** (`11d8d24`). Teste ponta a ponta pela API
  real 24/24 (inclui 2 correções achadas no teste: busca por código do projeto e GRANT ao service_role).
- Identidade visual padronizada com a Central (logo Lucenera branca, azul-marinho e dourado da Central) e
  correção de tela em branco ao navegar (efeito devolvia a Promise do `window.scrollTo` do skip.js).
  Publicado `67f3ef1`; teste visual por cliques na produção sem erros.
- Importação das planilhas Connect: fora do escopo por decisão do usuário (coberta pela SPEC-157).
- SPEC: `03-Projeto/Planos de Ação/SPECs/SPEC-164_Memoria_Lucenera_Base_Corporativa.md`.
- Repositórios que precisam de commit: `pedrolalala/memoria-lucenera` (submodule) e o central.

### SPEC-163: Controle de Produção e Controle de Garantia registrados na Central (Hub)

- 2 linhas novas em `public.systems` (`controle-producao`, `controle-garantia`) + `visualizar` para todos os 13
  papéis em `papel_permissoes` (decisão do usuário). Migration
  `supabase/db/migrations/20260924_162_registro_producao_garantia_hub/` **aplicada** (dry-run+COMMIT). Os
  cards aparecem no Hub e no menu lateral (SystemSwitcher) dos outros sistemas, sem mudança de código.
- SPEC: `03-Projeto/Planos de Ação/SPECs/SPEC-163_Registro_Producao_Garantia_no_Hub.md`.

### SPEC-162: Controle de Produção — registro de ocorrências por pedido

- **Controle de Produção** — nova tabela `producao_pedido_ocorrencias` (FK `producao_pedidos`,
  `ON DELETE CASCADE`): `categoria` e `descricao` obrigatórias, `registrado_por` (FK `usuarios`) e
  `registrado_em` preenchidos automaticamente pelo login. Sem checagem de status em nenhuma camada —
  pedido em andamento a "Pronto" aceitam ocorrência igual. Append-only (sem editar/excluir pela
  aplicação), mesmo padrão de RLS aberta (`authenticated` lê/insere) das tabelas da SPEC-161.
- Botão "Ocorrência" (vermelho) em toda linha da listagem, abre modal com tipo (Desenho errado,
  Desenho incompleto, Retrabalho de peça pronta, Outro) + descrição. Contador "N ocorrência(s)" sob o
  status (clicável, abre o painel expansível da linha). Nova seção "Ocorrências" no painel, com quem
  registrou e quando.
- Migration redigida em `supabase/db/migrations/20260924_161_producao_ocorrencias/` — **aplicada no Supabase real em 24/09/2026** (junto com as 7 da SPEC-161,
  dry-run+COMMIT). Depende de `producao_pedidos` (SPEC-156) já existir; independente das migrations da
  SPEC-161 (`20260923_160_*`), mas o frontend só pode ser publicado depois de as duas SPECs terem a
  migration aplicada (a listagem embute `producao_pedido_ocorrencias(count)` junto das contagens da
  SPEC-161).
- Decisões assumidas (pendentes de confirmação do usuário): categorias iniciais = as 3 citadas + Outro;
  sem anexo de foto na ocorrência; sem campo "resolvida/tratativa".
- `tsc --noEmit`, `oxlint src` e `vite build` rodados sem erro no submodule `controle-de-producao`.
- **Aplicado e publicado em 24/09/2026**: migrations SPEC-161 (`20260923_160_*`) + SPEC-162 aplicadas;
  Controle de Produção publicado no Skip (projectId 60535, v0.0.9) com SPEC-161 P2-P8 + SPEC-162; submodule
  `d64bcba`. Testado como `authenticated` (ocorrência em pedido "Pronto" grava; descrição vazia recusada).
  Controle de Garantia (SPEC-161 P9-P13/P15/P16) publicado no Skip 60545 v0.0.9, submodule `1335a36`.
- SPEC: `03-Projeto/Planos de Ação/SPECs/SPEC-162_Ocorrencias_Controle_Producao.md`.

## 2026-09-23

### SPEC-158: correções da reunião de revisão geral (22/09/2026)

- **Orçamentos** — bug crítico corrigido: editar um orçamento em "Aprovação Financeira" (ex.: mudar a
  data de pagamento) devolvia o orçamento para "Aprovação do Cliente", reiniciando o ciclo sem
  necessidade. Trigger `handle_orcamento_workflow()` corrigida — o reset do ciclo de aprovação passa a
  valer só para "Orçamento Aprovado"; correção do financeiro em "Aprovação Financeira" mantém o status
  e só registra em `historico_status_orcamentos`.
- **Orçamentos** — painel "Gerenciamento" (custo/lucro por peça) passou a considerar o desconto POR
  ITEM na margem simulada, além do desconto global — antes só o global entrava na conta, inflando a
  margem exibida para itens com desconto próprio.
- **Orçamentos** — rótulo "Responsável Obra" → "Engenheiro" no modal de criar projeto (o campo já
  listava só engenheiros desde a SPEC-152, faltava o texto).
- **Orçamentos** — botão "Salvar" duplicado no rodapé do formulário (formulário longo, botão do topo
  saía de vista ao rolar).
- **Orçamentos** — modal "Criar novo produto" (dentro de item de orçamento sem cadastro) drasticamente
  simplificado para "Adicionar item sem cadastro": só nome, marca, referência e preço de venda
  (digitado direto, sem cálculo de custo/margem). Categoria deixou de ser obrigatória na RPC
  `criar_produto_orcamento`. Marca passou a aparecer no rótulo do item na linha do orçamento
  (`ProductSelectButton.tsx`, via embed `marca:marcas(nome)`).
- **Cadastro** — nova ação "Copiar" em Peças: a partir de um produto existente, abre um novo cadastro
  pré-preenchido com todos os dados do produto de origem (marca, fornecedor, categoria, NCM/CST/CEST,
  impostos etc.), gerando um `codigo_produto` novo — pedido classificado como urgente pelo usuário
  ("dificilmente vamos criar um produto do zero").
- Migrations aplicadas em produção: `supabase/db/migrations/20260923_158_fix_reset_aprovacao_financeira/`,
  `supabase/db/migrations/20260923_158b_item_sem_cadastro_simplificado/`,
  `supabase/db/migrations/20260923_158c_digitador_orcamento/`.
- **Orçamentos** — P1.4 (achado durante o teste do P1.2, mesma reunião): painel "Gerenciamento" não tinha
  nenhum campo pra editar o desconto de um item específico ("tem ali, mas não tem opção aqui de colocar o
  desconto"). Nova coluna "Desc. item (%)" editável, grava direto em `itens.{index}.desconto` (campo real
  do orçamento, propaga em tempo real pra linha do item).
- **Orçamentos** — P2.3: registra quem digitou o orçamento (`orcamentos.digitado_por`), capturado
  automaticamente do login na criação, nunca editável pela UI — distinto do vendedor (lista fixa de 5
  pessoas, SPEC-140). Exibido no PDF do orçamento (Edge Function `generate-report`), ao lado de Vendedor e
  Arquiteto Externo.
- **Cadastro** — P2.5: "Código" e "Referência" na listagem de Peças (`Pecas.tsx`) estavam em cinza
  (`text-slate-500`) e laranja (`text-primary`), respectivamente, forçando a vista — trocados para
  `text-slate-900` (quase preto), mesmo padrão já usado pelo nome da peça na mesma tela.
- Publicado no Skip: Orçamentos (gestao-financeira-clone-544cb.goskip.app, v0.0.373, inclui a Edge
  Function `generate-report` — confirmado via Management API, não só pelo QA do Skip) e Cadastro
  (cadastro-lucenera-b86fe.goskip.app, v0.0.85).
- SPEC: `03-Projeto/Planos de Ação/SPECs/SPEC-158_Correcoes_Reuniao_22_09.md`.

## 2026-09-22

### SPEC-157: reconciliação/espelho formal nos 4 scripts de import Connect

- Evoluídos `scripts/importar_contas_pagar_receber.py`, `importar_pedido_compra.py`,
  `importar_produtos_estoque.py`, `importar_produtos_novos.py` (não reescritos do zero) com
  biblioteca compartilhada nova `scripts/sync_connect_common.py`: descoberta automática do
  arquivo mais recente, pré-validações obrigatórias (cabeçalho, mínimo de linhas, unicidade da
  chave natural na planilha) que abortam sem tocar no banco, e log estruturado por execução em
  `scripts/logs/sync_connect/`.
- Produtos (estoque): soft delete (`produtos.ativo`) para produto que saiu do export, reativação
  para o que volta. Produtos (novos): insert virou upsert `ON CONFLICT (codigo_produto) DO NOTHING`.
- Pedido de compra: nova coluna `pedido_compra.vigente` (nunca DELETE — planilha não traz
  histórico), `num_parc` vazio normalizado para 1, `staging_pedido_compra` ganha
  `UNIQUE(codigo_pedido, num_parc)`. Migration `20260922_159_sync_connect_reconciliacao`
  (RASCUNHO, **não aplicada** no Supabase real ainda).
- Contas a pagar/receber: fase de gravação (stg_duplicatas_vigentes + negociações novas +
  transações + os 3 cancelamentos) movida para uma única transação `psycopg2` — tudo ou nada.
  Semântica de "ausente na planilha" continua sendo cancelamento (`status_pago=2`), **não**
  DELETE físico — decisão confirmada com o usuário (retorno_bancario_registros referencia
  transacoes sem ON DELETE CASCADE; DELETE físico perderia histórico de conciliação bancária).
- Testado em dry-run contra o Supabase real dos 4 scripts nesta sessão; nenhuma gravação real
  foi executada. Ver `03-Projeto/Planos de Ação/SPECs/SPEC-157_Reconciliacao_Espelho_Import_Connect.md`.

### SPEC-156 Módulo 1 implementado e publicado: Controle de Produção

- Novo módulo dentro do sistema Estoque/Compras (`compras-lucenera-3o23t98ee`, Skip projectId 40326),
  não um sistema novo — réplica digital da planilha real `01-Documento/01 - Planilhas/CONTROLE DE
  PRODUÇÃO (1).xlsx` (3 abas: LINEAS E STECCAS, PEÇAS AVULSAS, CORTES (GAP - SLOT - VISTA)), com
  gestão de status em tempo real e handoff com dupla assinatura (quem entrega / quem recebe),
  resolvendo a "bucha" de responsabilidade descrita pelo Vinícius na reunião de 16/09/2026.
- Banco: migration `supabase/db/migrations/20260922_157_producao_pedidos/001_producao_pedidos.sql`
  criou `producao_pedidos`/`producao_pedido_handoffs` + bucket de Storage `producao_pedidos` (leitura
  pública, escrita `authenticated` — mesmo padrão do bucket `notas_fiscais_compra` já em produção).
  Aplicada no Supabase real (dry-run com ROLLBACK antes do COMMIT real). `empresa_id` é FK real para
  `empresas` (os 5 valores reais da coluna EMPRESA da planilha batem com `empresas.nome`). `status` é
  texto livre sem CHECK — a planilha real tem dado sujo (PRONTO/Pronto/PRONTA + CANCELADO/EXCLUÍDO/
  ENTRADA PARCIAL).
- Frontend: `services/producao.ts`, `pages/Producao.tsx`, 4 componentes em `components/producao/`,
  item de navegação "Produção" — commitado e pushado no submodule local
  (`github.com/pedrolalala/compras-lucenera-3o23t98ee`, commit `cae8341`) **e** publicado direto na
  working tree do Skip (`skip_file_write` + `skip_project_apply_changes` + `skip_project_publish`,
  v0.0.76). Achado: `App.tsx`/`AppNav.tsx` locais estavam desatualizados em relação ao Skip (que já
  tinha lazy-loading por rota, `ProtectedRoute` e `SystemSwitcher` do rollout SPEC-120 aplicados
  direto na working tree) — a rota/nav nova foi enxertada no padrão real do Skip, não sobrescrita pela
  versão local mais simples. Ver [[feedback_skip_deploy_separate_tree]].
- Módulo 2 (Controle de Garantia) da SPEC-156 **não** implementado nesta rodada — tem pendências de
  regra de negócio em aberto (permissão de escrita por fornecedor, origem da data de venda pré-Focus
  NFe). Ver `03-Projeto/Planos de Ação/SPECs/SPEC-156_Controle_Producao_e_Garantia.md`.

### SPEC-156 correção de arquitetura (mesmo dia): Produção e Garantia viram sistemas próprios

- Usuário corrigiu, logo depois do item acima: os dois sistemas deveriam ser separados do Compras, não
  módulos dele. Criou os repositórios GitHub `pedrolalala/Controle-de-producao` e
  `pedrolalala/controle-de-garantia`, os projetos Skip (60535 e 60545) e conectou ambos ao mesmo
  Supabase central. Registrados como submodules novos: `04-Sistemas/controle-de-producao` e
  `04-Sistemas/controle-de-garantia`.
- `controle-de-producao` bootstrapado do zero (login simples via Supabase Auth, sem `hub_pode_executar`
  — sistema ainda não registrado no Hub) e o Módulo 1 (service/página/4 componentes) migrado sem
  alteração de lógica. Publicado (`https://pagina-em-branco-e9c45.goskip.app`, v0.0.5) e commitado
  (`7be80f6`). Tabelas `producao_pedidos`/`producao_pedido_handoffs` no Supabase central não mudaram de
  lugar — só o frontend migrou de projeto.
- Módulo 1 removido de dentro do `compras-lucenera-3o23t98ee` (Skip v0.0.77, commit `363bab7`) depois
  de confirmado funcionando no sistema novo.
- `controle-de-garantia` só com repositório/projeto Skip criados e Supabase conectado — sem código
  ainda, aguardando as mesmas pendências de negócio do Módulo 2.
- Lição registrada em memória: decisão "módulo de sistema existente" vs "sistema novo separado" é do
  usuário, não deveria ter sido implementada sem confirmação explícita, mesmo com justificativa técnica
  sólida. Ver `feedback_confirmar_sistema_novo_vs_modulo_com_usuario` na memória do projeto.

### SPEC-156 Módulo 2 implementado e publicado (mesmo dia): Controle de Garantia

- Usuário respondeu as 3 pendências de negócio: (1) qualquer usuário pode abrir um item de garantia,
  só Vitória/Débora conduzem o processo formal com o fornecedor — sem trava de RLS por usuário porque a
  Vitória não tem cadastro em `usuarios` (achado ao consultar o banco); (2) data de venda resolvida em
  cascata nota fiscal → orçamento → venda legada (Connect) → manual; (3) prazo de garantia editável por
  item, com campo indicando se é da peça específica ou do padrão do fornecedor.
- Banco: `supabase/db/migrations/20260922_158_garantia/` criou `garantia_protocolos`/`garantia_itens`
  (6 status fixos de protocolo), bucket `garantia_anexos`, e duas funções `SECURITY DEFINER`
  (`garantia_resolver_data_venda`, `garantia_buscar_produtos`) — necessárias porque `notas_fiscais` e
  `produtos` têm RLS restrita a papéis do Hub que este sistema novo não tem. Achado: a tabela legada
  `vendas` está com `produto_id`/`descricao_produto` 0% preenchidos (263/263 linhas), então esse
  fallback da cascata não encontra nada na prática hoje.
- Frontend `04-Sistemas/controle-de-garantia` (Skip projectId 60545): login simples (mesmo padrão do
  `controle-de-producao`), 3 abas (itens aguardando protocolo, protocolos, adiantamentos pendentes),
  formulário completo de item com busca de cliente/produto e resolução automática de data de venda.
  Publicado (`https://pagina-em-branco-b044c.goskip.app`, v0.0.6).
- Testado ponta a ponta com um usuário `authenticated` real (script criando conta de teste, logando,
  exercitando toda a API como o app faria, depois apagando tudo) — confirmado funcionando, RLS incluída.
- Achado de git: ao dar push no submodule, o remote já tinha commits que o próprio Skip empurrou
  sozinho pro GitHub quando o usuário conectou o Supabase (antes do clone) — investigado via
  `git diff --stat` (sem sobreposição real com o trabalho feito), resolvido com merge normal preferindo
  o `types.ts`/`client.ts` reais do Skip no lugar dos stubs locais.

## 2026-09-21 (3)

### SPEC-154: migrations aplicadas + Edge Functions deployadas + frontend publicado ("simulação sem conta Focus NFe")

- Usuário perguntou se dava pra aplicar/deployar o código da SPEC-154 antes de criar a conta Focus NFe,
  só pra ter "um momento de simulação". Resposta: sim para migrations+deploy (são independentes da
  conta), mas uma simulação de autorização de verdade exige no mínimo uma conta de homologação (gratuita)
  — sem nenhuma conta, o fluxo vai até a Edge Function real e para com um erro de configuração tratado.
- Migrations 001 (`notas_fiscais` ganha `ambiente`/`ref`/`status_emissao`/`status_sefaz`/`mensagem_sefaz`/
  `chave_nfe`/`payload_enviado`/`tentativa_atual`/`ultima_consulta_em`), 002 (`notas_fiscais_erros`) e 003
  (`empresas.codigo_municipio_ibge`) aplicadas no Supabase real (dry-run com ROLLBACK antes de cada uma).
  Migration 004 (`pg_cron`/`pg_net`) fica pendente de propósito — exige a Edge Function já deployada (ok
  agora) e um secret no Vault do Postgres que ainda não existe.
- As 3 Edge Functions (`emitir-nota-fiscal`, `focus-nfe-webhook`, `verificar-notas-pendentes`) deployadas
  no projeto Supabase real via `supabase functions deploy --use-api` (bundling server-side, sem Docker).
  Achado: o pipeline de QA do Skip tentou fazer esse deploy sozinho e pulou silenciosamente
  ("Supabase redeploy/migrate skipped: connection could not be resolved") — sem checar isso à parte, as
  functions ficariam "publicadas" no Skip mas ausentes no Supabase de verdade. Confirmado no ar via curl
  direto (401/500 esperados, sem secrets configurados).
- Frontend (Vendas.tsx com o 3º passo de emissão, PendenciasNotaFiscal.tsx, Layout.tsx, lib/focus-nfe.ts)
  publicado no Skip (projeto 59346, v0.0.12) via `skip_file_write` direto (auto-sync do Skip não pega
  arquivo novo de forma confiável nesse sistema, mesmo problema já documentado na SPEC-153).
- Estado atual: dá pra testar o fluxo completo (espelho → registrar rascunho → "Confirmar e Emitir via
  Focus NFe") em produção real — a Edge Function roda contra o banco real e responde
  `{tipo: 'configuracao'}` (sem token Focus configurado), que o frontend mostra como aviso de
  configuração, não como erro da venda. Ver SPEC-154 para a lista do que falta (conta Focus, secrets,
  migration 004, teste de homologação).

## 2026-09-17 (implementação)

### SPEC-152 implementada: melhorias no fluxo de Orçamento

- Sistema Orçamentos (`gestao-financeira-clone-544cb`): `ProjectCreateModal.tsx` ganhou ação
  "Novo Cliente" (modal empilhado, mesmo padrão do Cliente do orçamento/CRM) e passou a filtrar
  "Responsável Obra" por `contato_tipos.tipo = 'engenheiro'` (Arquiteto continua sem filtro).
- `BudgetFormPage.tsx`: novo bloco "Plano de Parcelas" (valor/forma de pagamento/fornecedor de
  permuta editáveis por parcela, com validação ao vivo de que a soma bate com o valor a pagar),
  fix do bug de não conseguir apagar "Quantidade de Parcelas" (`z.preprocess` em vez de
  `z.coerce.number()` puro), campo de parcelas liberado pra qualquer forma de pagamento exceto
  pix/dinheiro (antes só boleto/cartão).
- Banco (`supabase/db/migrations/20260917_152_melhorias_orcamento/`): enum `pagamento_forma` ganha
  `'carteira'` e reconfirma `'permuta'` (suspeita de "Skip drift" na SPEC-107 — migration registrada
  "concluído" mas valor ausente do banco real); `orcamentos.plano_parcelas` (jsonb, Opção B decidida
  pelo usuário); `projeto_parcelas.permuta_fornecedor_id`; categoria nova
  `plano_de_contas.nome = 'PERMUTA/CONTRAPARTIDA'`; `aprovar_orcamento_financeiro` reescrita pra usar
  `plano_parcelas` quando presente, pular boleto de carteira/permuta e lançar contrapartida automática
  de Contas a Pagar (reaproveitando o padrão manual `boletos.tipo_operacao = 'CP'` da SPEC-073, sem FK
  nova em `negociacoes`/`transacoes`).
- PDF do orçamento (`supabase/functions/generate-report/index.ts`): troca "condições de pagamento"
  (contagem de dias) por tabela de parcelas com vencimento absoluto + valor.
- `AI_DB_CONTEXT.md` de Orçamentos e Administração Bancária atualizados; seção "SPEC-019" do primeiro
  corrigida (reset por campo de pagamento nunca foi o mecanismo real, só o trigger em `orcamento_itens`
  — SPEC-135).
- Migrations **redigidas, não aplicadas no Supabase real** — aplicação e teste ao vivo (golden path)
  ficam como passo manual do usuário. Ver SPEC-152 para detalhes/pendências.

## 2026-09-21 (2)

### SPEC-154: frontend da emissão real implementado (modal + tela de pendências)

- Modal "Emitir Nota Fiscal" ganhou o 3º passo de emissão real (chama `emitir-nota-fiscal`, trata os
  6 formatos de resultado); tela nova "Pendências de Nota Fiscal"; status em tempo real na listagem.
- Revisado (`revisor`, 2 avisos reais corrigidos antes do commit): (1) rascunho de nota
  rejeitado/abandonado ficava preso pra sempre contando como "já faturado" (a RPC sempre insere nota
  nova) — corrigido com cancelamento automático do rascunho nos 3 pontos de saída do fluxo; (2) erro
  do Supabase não verificado no refetch pós-emissão, mesmo padrão já corrigido no backend.
- **⚠️ Risco ativo**: este sistema (`vendas-lucenera`) sincroniza automaticamente do GitHub pro Skip.
  O frontend novo já depende de colunas (`status_emissao`, `ref`, etc.) que só existem depois das
  migrations desta SPEC serem aplicadas — se o auto-sync publicar antes disso, a tela de Vendas
  (hoje funcionando em produção) quebra. Aplicar as migrations o quanto antes — no momento deste
  commit o Skip ainda estava na versão anterior (v0.0.11), sem ter sincronizado o frontend novo.

## 2026-09-21

### SPEC-154: backend da integração Focus NFe implementado (banco + Edge Functions, não aplicado/deployado)

- Usuário fechou a especificação técnica completa (fluxo assíncrono 201/202/400/422/401/403/429/5xx,
  webhook idempotente com retry da Focus, modelo de erros com histórico por tentativa). SPEC-154
  reescrita com essa política e implementada nesta sessão:
- **Banco** (`supabase/db/migrations/20260921_154_focus_nfe_integracao/`, 4 migrations, não aplicadas):
  estende `notas_fiscais` (`ambiente`, `ref`, `status_emissao`, `status_sefaz`, `mensagem_sefaz`,
  `chave_nfe`, `payload_enviado`, `tentativa_atual`, `ultima_consulta_em`), tabela nova
  `notas_fiscais_erros` (histórico completo, nunca sobrescrito), `empresas.codigo_municipio_ibge`,
  e agendamento do job de fallback via `pg_cron`/`pg_net` (já habilitados no projeto).
- **Edge Functions** (`vendas-lucenera/supabase/functions/`, não deployadas): `emitir-nota-fiscal`
  (monta o payload NF-e 4.00 a partir dos mesmos dados do espelho DANFE, trata todos os casos de
  resposta da política), `focus-nfe-webhook` (idempotente por `ref`), `verificar-notas-pendentes`
  (polling de fallback). Heurística de CFOP compartilhada byte-a-byte com o frontend.
- Revisado (`revisor`, sem achado crítico) — 2 avisos corrigidos antes do commit: erros do Supabase
  não verificados em vários pontos de `emitir-nota-fiscal` (o mais sensível: a emissão agora aborta
  se não conseguir gravar `payload_enviado` antes de chamar a Focus, em vez de transmitir sem
  auditoria). `deno check` confirmado limpo nos 3 entrypoints.
- **Frontend ainda não implementado** (modal de emissão real, tela de pendências) — próxima etapa.
  Gaps de CFOP/pagador sem CPF-CNPJ/multi-empresa continuam pendências de negócio em aberto.

## 2026-09-17 (7)

### SPEC-153: espelho da nota fiscal vira DANFE de verdade (código de barras + dados fiscais reais)

- Pedido do usuário: o espelho deveria "parecer de verdade a estrutura de uma nota fiscal real, com
  código de barras e os campos necessários já completados" — refeito como um DANFE visual completo
  (`DanfePreview.tsx`): selo "ESPELHO — SEM VALOR FISCAL", cabeçalho com identificação/N°/série,
  código de barras Code128 renderizado de verdade (`jsbarcode`, primeiro uso no ecossistema) a partir
  de uma chave de acesso placeholder de 44 dígitos (formato real, dígito verificador mod-11 correto,
  nunca transmitida à SEFAZ), Emitente com dados reais da empresa do orçamento, Destinatário com
  dados reais do cliente, Cálculo do Imposto, e tabela de itens com NCM/CST (`produtos`, SPEC-132) e
  CFOP (mesma heurística provisória já usada em `FiscalSummaryDialog.tsx` de Orçamentos).
- Revisado (`revisor`, sem achado crítico) e **publicado**: `pagina-de-vendas-9549c.goskip.app`,
  v0.0.11 (`154fa4b`), QA 100% verde. Corrigido no processo um bug real: `@supabase/supabase-js`
  duplicado em `package.json` (2 versões) depois de um merge automático do Skip.
- Achado de infra: o sync automático do Skip a partir do GitHub não pegou os arquivos novos a tempo
  (2 tentativas) — publicado via escrita direta na working tree do Skip, mesmo fluxo manual usado
  nos outros 9 sistemas.

## 2026-09-17 (6)

### SPEC-153: espelho da nota fiscal + publicado no Skip

- Pedido do usuário: o botão "Emitir Nota Fiscal" agora abre primeiro um espelho/pré-visualização
  da nota cheia (mesmo processo manual descrito na reunião — "tirar um espelho da nota fiscal cheia"
  e marcar o que já saiu), listando notas já emitidas e todos os itens da venda, com os já cobertos
  esmaecidos/riscados. Só depois o botão "Continuar para emissão" abre o formulário de preenchimento.
- **Publicado**: `pagina-de-vendas-9549c.goskip.app` (projectId 59346), v0.0.8 (`22c6c77`), QA 100%
  verde. Achado: este projeto Skip sincroniza automaticamente a partir de pushes no GitHub (diferente
  do fluxo manual usado nos outros 10 sistemas) — os commits chegaram a ser auto-mesclados/publicados
  pelo próprio Skip antes da confirmação manual.

## 2026-09-17 (5)

### SPEC-153: migrations aplicadas no Supabase real

- As 3 migrations de `supabase/db/migrations/20260917_153_notas_fiscais_parcial_multipagador/` foram
  aplicadas de verdade (dry-run combinado + aplicação real em sequência, tudo verificado por SELECT):
  `notas_fiscais.cliente_id`/`nome_destinatario`, tabela `notas_fiscais_itens`, RPC
  `registrar_nota_fiscal_parcial`, registro do sistema "Vendas" em `public.systems` (visível no Hub),
  e permissão `admin`/`admin_geral` em `papel_permissoes` (sem ela, a RPC negaria acesso a todo
  mundo, inclusive admin — `hub_pode_executar` não tem bypass embutido para essa role).
- **Falta só publicar o código no Skip** (`pagina-de-vendas-9549c.goskip.app` ainda está com o
  scaffold antigo, o código real já commitado no GitHub ainda não foi enviado pra lá) para o sistema
  ficar utilizável de ponta a ponta.

## 2026-09-17 (4)

### SPEC-153: sistema Vendas implementado (código; migrations ainda não aplicadas)

- Usuário criou a infraestrutura (repo `github.com/pedrolalala/Vendas-Lucenera` + projeto Skip
  59346 "Página de Vendas"). Sistema transformado do scaffold padrão pro sistema real: SSO
  (`cross-system-auth.ts`, `use-auth.tsx`, `SystemSwitcher`) copiado do padrão dos sistemas-irmãos;
  `src/pages/Vendas.tsx` lista orçamentos aprovados com status de nota fiscal derivado; modal
  "Emitir Nota Fiscal" com seleção de quantidade parcial por item e 3 modos de pagador (cliente da
  venda / outro contato / nome livre), chamando a RPC `registrar_nota_fiscal_parcial`. Sem nenhuma
  chamada a API fiscal externa (isso é SPEC-154, separada).
- 3 migrations redigidas em `supabase/db/migrations/20260917_153_notas_fiscais_parcial_multipagador/`
  (`notas_fiscais.cliente_id`/`nome_destinatario` + tabela `notas_fiscais_itens` + RPC transacional;
  registro em `public.systems`; permissão admin/admin_geral) — **ainda não aplicadas no Supabase
  real**. Achado importante: `hub_pode_executar` não tem bypass de admin embutido — sem a 3ª
  migration, a RPC nova negaria acesso a todo mundo, inclusive admin.
- Administração Bancária perde a tela/rota `/notas-fiscais` (citação direta da reunião). Orçamentos:
  `FinanceResultModal.tsx` troca os botões de NF/boleto por um único "Ver na tela de Vendas".
- Revisado pelo `revisor`: sem achado crítico. Commits feitos SELETIVAMENTE em Admin Bancária e
  Orçamentos, excluindo o rollout pendente do SystemSwitcher (SPEC-120) e trabalho antigo de
  duplicatas que seguem soltos nas working trees desses 2 sistemas (não tocados por esta SPEC).

## 2026-09-17 (3)

### SPEC-153 reescrita + SPEC-154 (nova): Vendas vira sistema separado, provedor de nota fiscal é Focus NFe

- Usuário decidiu, depois do rascunho inicial da SPEC-153: (1) "Vendas" é um **sistema novo e
  independente**, não uma aba dentro da Administração Bancária; (2) o provedor de emissão de nota
  fiscal é a **Focus NFe** (`doc.focusnfe.com.br`).
- **SPEC-153** reescrita: sistema Vendas novo (banco/contrato de dados only — criação do repositório
  GitHub e do projeto Skip é passo manual do usuário), nota fiscal parcial multi-pagador
  (`notas_fiscais_itens`), remoção da tela `NotasFiscais.tsx` de Administração Bancária (citação
  direta da reunião), Contas a Pagar/Receber/Duplicatas/Boletos/Remessa/Retorno continuam lá.
- **SPEC-154** (nova): integração técnica real com Focus NFe — Edge Functions `emitir-nota-fiscal` e
  `focus-nfe-webhook`, autenticação HTTP Basic (token como usuário, senha vazia), ambientes de
  homologação/produção. Achados: `produtos.ncm` **já existe** (SPEC-132, não é gap); CFOP não existe
  e precisa de validação com contador antes de emissão real; `empresas` não tem código de município
  IBGE (exigido pela Focus NFe); múltiplas empresas emissoras (Foco/Manoella/Islight) vão precisar de
  tokens Focus NFe separados, guardados em Supabase Secrets (nunca em tabela).
- Nenhuma implementação iniciada — aguardando criação da infraestrutura do sistema Vendas (repo +
  projeto Skip) e decisões pendentes (CFOP, política de pagador sem CPF/CNPJ, conta Focus NFe).

## 2026-09-17 (2)

### SPEC-152: implementada, migrations aplicadas no banco real e publicada no Skip

- Código implementado (`implementador`) e revisado (`revisor`, sem achado crítico), commitado em 3 repos:
  Orçamentos (`68c0a50`, depois `77fcd3c` de sincronização), Administração Bancária (`96e4aae`), central (`8b312e9`).
- **Migrations aplicadas de verdade no Supabase** (`supabase/db/migrations/20260917_152_melhorias_orcamento/`,
  5 arquivos, dry-run + aplicação real em sequência): enum `pagamento_forma` ganha `carteira`;
  `orcamentos.plano_parcelas` (jsonb); `projeto_parcelas.permuta_fornecedor_id`; categoria
  `PERMUTA/CONTRAPARTIDA` no plano de contas; `aprovar_orcamento_financeiro` reescrita pra usar
  `plano_parcelas` quando presente, com fallback idêntico ao legado quando ausente.
- **Correção de um achado errado do implementador**: `'permuta'` já existia no enum real antes desta
  SPEC (SPEC-107 foi aplicada corretamente) — confirmado no dry-run direto contra o banco.
- **Achado de dado real**: `ORC-0035` (rascunho, R$4.201,73) já tinha `forma_pagamento='permuta'` sem
  fornecedor associado — vai precisar ser reaberto e completado antes de aprovar, depois desta SPEC.
- **Publicado**: `gestao-financeira-clone-544cb` (Skip 32554), v0.0.368 (`1ed6376`), QA 100% verde.
  Publicar exigiu um **merge de 3 vias** em `BudgetFormPage.tsx` — o Skip já tinha o campo "Perfil"
  reposicionado pro topo (SPEC-146), mudança nunca sincronizada de volta pro git local; o merge
  preservou essa posição e não regrediu nada. O git local foi sincronizado de volta com o publicado
  logo em seguida, fechando esse gap.

## 2026-09-17

### SPEC-152 + SPEC-153 (criadas, não implementadas): reunião "novo sistema de vendas" (16/09)

- A partir da reunião "24. Lucenera (Vinicius) - 16.09.2026_novo sistema de vendas", duas SPECs novas
  em `03-Projeto/Planos de Ação/SPECs/`, ambas com status "não iniciado":
- **SPEC-152** — melhorias no Orçamento: cadastrar cliente sem fechar "Criar Projeto", Responsável
  de Obra restrito a engenheiros, novas formas de pagamento "Carteira" e "Permuta" (com contrapartida
  automática em Contas a Pagar), 2 bugs de UI no plano de pagamento, parcelas com valor customizável
  por parcela (hoje só divide igualmente), PDF do orçamento trocando "X dias" por data+valor real de
  cada parcela.
- **SPEC-153** — sistema de Vendas + Nota Fiscal: nova tela "Vendas" dentro da Administração
  Bancária (layout copiado de lá), removendo emissão de nota/boleto do modal de aprovação do
  orçamento, nota fiscal parcial com pagador diferente do titular (schema com `notas_fiscais_itens`
  pra controlar o que já foi faturado por venda), boleto sem nota permitido como exceção.
- **Achados da investigação (mudam o escopo do que foi discutido na reunião)**: `orcamentos.numero_venda`
  já está implementado e visível na UI (SPEC-136, 14/09) — só precisa confirmação ao vivo; **não existe
  nenhuma integração fiscal automática (API/SEFAZ) em nenhum sistema do repositório** — a tela de Notas
  Fiscais hoje é 100% manual, contradizendo a descrição da reunião de um retorno automático de API —
  vira pendência bloqueante da SPEC-153; o bug de "cliente sem cadastro trava criar projeto" existe no
  Orçamentos mas não foi encontrado no CRM (já tem "Novo Cliente" sem fechar o form).
- Ambas as SPECs têm pendências de decisão de negócio explícitas (semântica da "Carteira", schema de
  parcelas customizadas, categoria financeira da permuta, nomenclatura final do módulo de Vendas,
  provedor de nota fiscal) — nenhuma implementação foi iniciada.

## 2026-09-16

### SPEC-125 (pendência residual): Showroom registrado na Central Lucenera

- `public.systems` ganhou a linha do Showroom (migration `20260916_125_showroom_registro_hub`,
  aplicada no Supabase real): `slug=showroom`, link pra `/admin` (curadoria — fotos do estoque +
  composição, SPEC-125/148/149), `visivel_no_hub=true`, `display_order=12`.
- Decisão do usuário: aponta pra ferramenta interna (`/admin`), não pra vitrine pública — mesmo
  padrão dos demais cards da Central. Só o admin vê o card por enquanto (sem `papel_permissoes`
  ainda); nenhuma mudança de código no Hub, `Dashboard.tsx` já lê a tabela dinamicamente.

## 2026-09-15 (5)

### SPEC-147 + SPEC-150: catálogo Ubiqua unificado por referência e por família de produto — publicado

- **SPEC-147** (a partir da reunião "23. Lucenera (Vinicius) - 15.09.2026_ Ubiqua"): `groupCatalogItems()` (`catalogo-pecas-ubiqua-e6fa0/src/hooks/use-parts.ts`) agrupa por **referência normalizada** em vez de descrição+preço — mesma peça vendida pela Manoella e pela Islight vira 1 card só, com estoque somado. V2 continua separado (código de referência diferente). Peça sem sufixo `-IS`, sem estoque e sem irmã `-IS` some da vitrine (11 hoje). Quando o preço diverge entre as duas empresas (3 pares), usa o **menor valor**. Novo campo "preço sugerido" (`vl_venda_produto`) exibido em `PartCard.tsx`/`ProductDetail.tsx`/`PartDetailSheet.tsx` — confirmado por cruzamento de dados que é cópia estática de `produtos.valor_venda` (tabela central), sem sync automático.
- **SPEC-150** (extensão pedida ao vivo pelo usuário no mesmo dia): cores diferentes da mesma peça física tinham cada uma sua própria referência numérica (ex.: BLOK cimento=`100161`, mármore branco=`100162`), então a unificação por referência da SPEC-147 sozinha não as juntava. Nova função `extractFamilyIdentity()` extrai o nome+forma do produto (ex.: "TORUS DESK", "FLORA MINI") cortando a descrição na primeira palavra de um conjunto fixo (`LUMINARIA`/`LUM`/`LED`/`BATERIA`); vira a chave de agrupamento principal, com `_V2` quando a referência indica variante V2. Cai de volta pro agrupamento por referência quando a descrição não tem nenhuma dessas palavras (acessórios genéricos como cabo/carregador). Resultado: 87 linhas reais → 28 grupos (era 63 só com a SPEC-147).
- **Correção de dado pontual** (não é migration): `revenda_ubiqua.vl_venda_produto` das 4 peças BLOK V2 estava nulo (BLOK V2 nunca foi cadastrado na tabela central `produtos`); atualizado via `UPDATE` direto pro preço do BLOK mais caro (R$1.788,24), decisão do usuário.
- Testado ao vivo (SPEC-147, browser) e validado por script contra os dados reais do Supabase (SPEC-150, sem teste visual — extensão Chrome instável na sessão). Revisado pelo agente `revisor` nas duas rodadas; um achado de "encoding corrompido" na segunda rodada foi investigado e descartado como falso positivo (verificado por `codePointAt`).
- **Publicado**: `catalogo-pecas-ubiqua-e6fa0.goskip.app` v0.0.88 (commit `0842d77` no submodule, push feito pro GitHub).
- Pendências: confirmação do Vinicius sobre a divergência real de R$109,36 na referência `332109`; planilha do Sérgio pra filtro de produto ativo/inativo (fora do escopo).

## 2026-09-15 (4)

### SPEC-148: Showroom /admin — fotos do estoque (upload direto) + peça composta (1 foto, N produtos)

- Duas capacidades novas na tela `/admin` do showroom (`showroom-qtq8er2dk`), na mesma sessão/credencial já existente: **(A)** aba nova "Fotos do estoque" pra subir/trocar a foto de um produto já em estoque direto por upload de arquivo, sem depender do PowerPoint importado; **(B)** "peça composta" — 1 produto principal guarda a foto/nome e N produtos membros contribuem valor e limitam a disponibilidade de um "conjunto" exibido como 1 card só na vitrine (ex.: base + haste + cúpula), acionável a partir de qualquer produto principal nas duas abas de `/admin`.
- Migration (rascunho, **não aplicada**): `supabase/db/migrations/20260915_148_showroom_fotos_estoque/001_fotos_estoque.sql` (tabela `showroom_upload_grants`, função `showroom_upload_permitido`, 3 policies de `storage.objects` restritas a liberação temporária via RPC — Opção B de controle de acesso, confirmada por Pedro — RPCs `showroom_liberar_upload_produto`/`showroom_confirmar_foto_produto`) e `002_peca_composta.sql` (tabela `showroom_grupo_itens` com índice único de 1-conjunto-por-produto, RPCs `showroom_definir_composicao`/`showroom_obter_composicao`, recriação de `showroom_listar_produtos_estoque`/`showroom_buscar_produto` com as 2 colunas novas de composição, redesenho de `vw_showroom_publico` em 2 ramos — avulsa/conjunto — preservando o contrato de 9 colunas desde a SPEC-125).
- Frontend: `Admin.tsx` virou 2 abas (Tabs shadcn/ui); novo service `src/services/curadoriaEstoque.ts` (fluxo completo de upload: liberar → `supabase.storage.upload` → `getPublicUrl` → confirmar → remover arquivo antigo só depois de confirmado); `src/services/curadoria.ts` estendido com `obterComposicao`/`definirComposicao`; novo `src/components/showroom-admin/ComposicaoConjuntoModal.tsx` compartilhado pelas 2 abas; `Thumb`/`PPTTab`/`FotosEstoqueTab` extraídos como componentes próprios.
- Criado `04-Sistemas/showroom-qtq8er2dk/supabase/AI_DB_CONTEXT.md` (gap desde a SPEC-125, não existia) e atualizado `supabase/db/domains/cadastros.md`.
- Build (`vite build`) e `tsc --noEmit` sem erro; `oxlint` limpo. **Migration NÃO aplicada no Supabase real** — fica pendente de autorização do usuário, junto com o teste ao vivo do fluxo de upload e da montagem de um conjunto de teste. Detalhe completo em SPEC-148.

## 2026-09-15 (3)

### SPEC-146: campo Perfil (Ribeirão/São Paulo) movido para o topo do orçamento

- Usuário pediu pra mover o campo "Perfil" de "Pagamento e Totais" (fim do formulário) pra "Informações Gerais", ao lado de "Empresa" (início do formulário) — só reposicionamento, mesma lógica/opções.
- **Achado**: o submodule local (`gestao-financeira-clone-544cb (1)`) tinha ~17 arquivos com mudanças não commitadas alheias a esta SPEC (mesmo `BudgetFormPage.tsx`), provável trabalho em andamento de outra sessão. O fix não foi commitado em cima disso — aplicado direto no Skip via `skip_file_patch` (confirmado antes, por `skip_file_read`, que o trecho relevante batia com a versão limpa do git).
- Publicado: `gestao-financeira-clone-544cb.goskip.app` (v0.0.366) — confirmado ao vivo no bundle de produção. Submodule local segue com o diff alheio não investigado, pendência anotada na SPEC-146. Detalhe completo em SPEC-146.

## 2026-09-15 (2)

### SPEC-145: enquadramento dos cards (fim da rolagem lateral) em Separação Parcial e Projetos (CRM)

- Usuário reportou dois cards que exigiam rolagem horizontal pra ver todo o conteúdo: a tabela de itens da venda (Separação Parcial) e a tabela principal de Projetos (CRM) — confirmado ao vivo, colando a estrutura real de colunas de cada tela.
- Fix: colunas de texto (Descrição/Referência/Local na Separação; Projeto/Responsável/Eng.-Arquiteto/Cidade no CRM) perderam `truncate`/largura fixa e passaram a quebrar linha, crescendo pra ocupar o espaço livre; colunas numéricas/curtas ficaram compactas (`whitespace-nowrap` + padding menor); removido o teto de largura (`max-w-[1400px]`) dos containers principais das duas telas.
- **Achado de drift**: `skip_file_read` mostrou que `Projetos.tsx`/`Layout.tsx` do CRM no Skip já tinham divergido do submodule local (rótulos abreviados "Entrada"/"Fechamento"/"UF", layout `table-auto` mais compacto) — o fix foi aplicado via `skip_file_patch` direto na versão real do Skip, e o submodule local foi sincronizado depois pra bater com o que está no ar.
- Publicado nos dois: `separacao-parcial-dff01.goskip.app` (v0.0.40) e `lucenera-crm-3bd29.goskip.app` (v0.0.313) — confirmado ao vivo via `curl` no bundle JS de produção. Detalhe completo em SPEC-145.

## 2026-09-15

### SPEC-144: layout de impressão do Pedido em Separação no estilo do documento Connect

- Usuário anexou um "Pedido em Separação" real do Connect (PDF) e pediu pra usar como base do nosso layout de impressão, com mais informações.
- `buscarVendaPorNumero()` estendida: empresa real da venda, vendedor, data do orçamento, e dados completos do cliente (CPF/CNPJ, telefone, endereço/bairro/cidade/estado) — antes só buscava o nome do cliente.
- Layout novo: número da parcial+venda no topo (`ORC-XXXX-Pn / VENDA-XXXX`), empresa real, dados do cliente/vendedor, e os 2 blocos de assinatura + declaração de responsabilidade do documento original.
- Achado: "ISLIGHT" no PDF do Connect não é um placeholder — é uma das empresas reais do grupo (`orcamentos.empresa_id` define se a venda é Foco, Manoella ou Islight). O layout mostra a empresa real de cada venda, não um nome fixo.
- Testado com dado real (ORC-0032) via REST API (psql com falha de DNS transitória na hora) + preview local do HTML gerado. Publicado Skip 48801 v0.0.39, `https://separacao-parcial-dff01.goskip.app`. Detalhe completo em SPEC-144.

## 2026-09-14 (8)

### Verificação ao vivo do "Registrar Entrega" (Logística) + fix de payload + achado crítico (foto)

- Pedido do usuário: confirmar se o "Registrar Entrega" da Logística (fluxo real de "Dar Baixa", ver item (7)) funciona, com teste ao vivo.
- Bug confirmado e corrigido em `lucenera-logistics-b7cd1`: `RegistrarEntregaPage.tsx` mandava um payload com nomes de campo errados pro hook `useFinalizarEntrega` — a entrega ficava sem `separacao_id`/`cliente`/`codigo_obra`/`endereco`/`recebido_por`, a separação nunca era marcada `finalizado`, mas o toast avisava sucesso (falso positivo). Também corrigido: a data real da entrega (campo editável na tela) era ignorada, sempre gravava "agora". Publicado Skip 24039 v0.0.97.
- **Achado novo, não corrigido, mais grave**: `PhotoUploader.tsx` é um componente vazio — botão "Adicionar Foto" sem nenhuma ação, sem `<input type="file">`. Como foto é obrigatória pra habilitar "Finalizar Entrega", essa tela nunca funcionou de fato em produção, mesmo antes do bug de payload. Precisa de decisão: implementar upload de verdade (Storage) ou repensar o fluxo.
- Achado adicional: a busca por código de obra só aceita formato antigo de 5-6 dígitos; todo projeto criado hoje usa formato `26.xxxx`, então nenhuma obra real é localizável por código — só por `LUC-NNNN`, que separações vindas de Separação Parcial nunca recebem.
- Teste ao vivo confirmou que o **mecanismo em si funciona**: usando o caminho alternativo (`SeparacaoPage` → "Finalizar", que não exige foto), uma separação de teste foi finalizada e apareceu corretamente em "Entregas Finalizadas" com todos os campos certos. Dados de teste apagados depois. Detalhe completo em SPEC-143.

## 2026-09-14 (7)

### SPEC-143 REVERTIDO: "Dar Baixa" removido da Separação — já existe na Logística

- Poucas mensagens depois de publicar a SPEC-143 (item (6) abaixo), o usuário corrigiu: "o Dar baixa é o Registro de entrega que está em lucenera-logistica! não precisa desse dar baixa aqui Só a opção de separar!!" — o "Dar Baixa" construído era uma duplicação de uma tela que já existe (`RegistrarEntregaPage.tsx` na Logística).
- Revertido em `separacao-parcial`: `SeparacaoParcialPage.tsx` e `separacaoParcialService.ts` voltaram ao estado anterior à SPEC-143 (sem card de baixa, sem `registrarBaixaSeparacao`). "Parciais desta venda" voltou a ser tabela simples (Parcial/Funcionário/Data/Status/Estornar).
- Tabela `separacao_baixas` (migration 20260914_143) **não foi dropada** — segue existindo no Supabase, agora inerte, aguardando decisão do usuário sobre removê-la ou não.
- QA verde, publicado (Skip 48801 v0.0.37, `https://separacao-parcial-dff01.goskip.app`). O achado de bug em `RegistrarEntregaPage.tsx`/`useFinalizarEntrega.ts` (nomes de campo incompatíveis) fica mais relevante agora que esse é de fato o fluxo real de "Dar Baixa" — recomendado abrir SPEC própria para investigar. Detalhe completo em SPEC-143.

## 2026-09-14 (6)

### SPEC-143: "Dar Baixa" vira ação nova, separada de "Separar" — PUBLICADO

- Correção sobre a revisão do Prompt 7 (SPEC-138) do mesmo dia: o usuário mandou referência visual detalhada de uma tela do Connect legado mostrando que "Parcial" (quem pediu) e "Baixa" (quem fez a entrega/retirada) são dois registros distintos, com divisória visual entre eles — não a mesma ação que "Separar", como tinha sido assumido antes.
- Nova tabela `separacao_baixas` (1 por parcial): Código (sequência própria), Funcionário (quem confirma a baixa, pode ser diferente de quem separou), Responsável Retirou (texto livre) e Data Baixa (com hora).
- Achado colateral (não corrigido, reportado): a feature "Registrar Entrega" já existente na Logística (`RegistrarEntregaPage.tsx`) parece ter um bug de assinatura entre a página e o hook `useFinalizarEntrega` — por isso não foi reaproveitada.
- Migration `20260914_143_separacao_baixas` aplicada em produção (testada com dry-run antes). Publicado: `https://separacao-parcial-dff01.goskip.app` (Skip 48801 v0.0.34, QA verde). Detalhe completo em SPEC-143.

## 2026-09-14 (5)

### SPEC-133 revisada: card de Aprovação Financeira volta a ser somente leitura — PUBLICADO

- Instrução do usuário (com referência visual) revogou a edição de parcela adicionada mais cedo hoje na mesma SPEC-133: a confirmação de Aprovação Financeira não pode ter nenhum campo editável. Ajustes de valor/vencimento de parcela passam a ser feitos antes, na tela de condições de pagamento do próprio orçamento.
- `FinancialApprovalDialog.tsx` voltou a ser somente leitura (removidos os inputs editáveis por parcela); `approveBudgetFinancial` voltou ao contrato original da RPC (só `p_orcamento_id`).
- Consequência importante: a migration `20260914_141` (parâmetro `p_valores_parcelas` na RPC) **ficou sem uso** — não precisa ser aplicada. Fica documentada como histórico técnico na SPEC-133, mas marcada como abandonada.
- Publicado em produção: `https://gestao-financeira-clone-544cb.goskip.app` (Skip 32554 v0.0.363, QA verde) — sem nenhuma dependência de migration agora.
- Migration `20260914_140` (fix de nome da Marina + cadastro do Filippo Giorgi, pro filtro de Vendedores da SPEC-140) continua pendente e é a única que falta rodar.

## 2026-09-14 (4)

### Revisão do Prompt 7 (SPEC-138) — Boletos removido, área de baixa reformulada

- Instrução explícita do usuário (com referência visual) revogou a decisão default anterior: "Boletos desta venda" foi **removido por completo** da tela de Separação (nenhuma informação financeira, em nenhuma condição) — antes só ficava oculto até a 1ª baixa.
- "Parciais desta venda" (a área de baixa) agora fica totalmente oculta até a 1ª baixa acontecer (mesma ação de "Separar" já existente, sem fluxo novo) e, quando aparece, mostra só Código, Data Baixa, Funcionário e Responsável Retirou (confirmado com o usuário: reusa o dado de Funcionário, sem coluna nova no banco).
- Publicado em produção: `https://separacao-parcial-dff01.goskip.app` (Skip 48801 v0.0.31, QA verde, sem dependência de migration). Detalhe completo em SPEC-138.

## 2026-09-14 (3)

### Backfill de numero_venda para ORC-0032

- Pedido do usuário: orçamentos já aprovados antes da migration da SPEC-136 ficaram sem `numero_venda` (só gerado no momento da aprovação). Confirmado por query direta que `ORC-0032` era o único caso.
- Migration `20260914_142_backfill_numero_venda_orc0032` aplicada em produção — `ORC-0032` agora tem `numero_venda = VENDA-0001`. Detalhe em SPEC-136.

## 2026-09-14 (2)

### Teste ao vivo da Aprovação Financeira revela SPEC-135 nunca publicada no Skip

- Usuário testou ao vivo criar um orçamento com peça sem cadastro e tentar aprovar financeiramente: o bloqueio funcionou (banco), mas nenhum aviso explicando o motivo apareceu na tela.
- Causa raiz: o frontend do Skip (produção, `gestao-financeira-clone-544cb`, projeto `32554`) rodava uma versão de `FinancialApprovalDialog.tsx` **anterior à SPEC-135 inteira** — sem o banner de "peça sem cadastro" nem tratamento de erro (o `catch` engolia tudo silenciosamente). O código da SPEC-135 só existia no git local, nunca tinha sido publicado.
- Corrigido e publicado: `FinancialApprovalDialog.tsx` completo (banner + agora também um Card vermelho persistente com a mensagem de erro, substituindo o toast que era fácil de perder).
- Achado adicional (investigação, não reportado pelo usuário): `budgetToEdit.itens` só carrega uma vez ao abrir a página — item sem cadastro adicionado na mesma sessão de edição podia escapar do banner. Corrigido: busca os itens direto do banco antes de abrir o diálogo de aprovação (`BudgetFormPage.tsx`, `FinancialApprovalTab.tsx`).
- Pedido do usuário: editar só os campos de "Pagamento e Totais" (forma de pagamento, parcelas, frete, perfil, desconto, sinal, observações) — já negociados com o cliente antes da aprovação financeira — não deve nem avisar sobre reiniciar o ciclo de aprovação do cliente, já que esses campos nunca tocam os itens do orçamento. Corrigido: novo comparador `itensRealmenteMudaram()` só dispara o aviso/reset quando os itens de fato mudam.
- Publicado em produção: `https://gestao-financeira-clone-544cb.goskip.app` (Skip `32554`, versão `0.0.360`, QA 100% verde). Detalhe completo em SPEC-135.

## 2026-09-14

### Prompts 4, 5, 6 e 7 do documento "Conect" Light Design 11/09 — SPEC-138 (Separação Parcial)

- Origem: `01-Documento/01 - Planilhas/LUCENERA — LIGHT DESIGN DEPARTAMENTO DE E.V..docx`, 7 "prompts" de melhoria elaborados em 11/09/2026. Os Prompts 1, 2, 3 e 3A já haviam virado SPEC-135/SPEC-136 no mesmo dia; esta entrega cobre os 4 que ainda não tinham SPEC nenhuma.
- **Prompt 5** (layout/rolagem horizontal): coluna de ação "Trocar" fixa (`sticky right-0`) e truncate em `Referência`/`Local (L)` na tabela de itens da venda.
- **Prompt 6** (lista de separação): impressão (`imprimirListaSeparacao`) ganhou coluna "Local (L)" (mesmo dado da coluna "Classificação" em tela, `projeto_itens.l_fixo`), coluna de marcação em branco por item, totalizador de itens/peças no rodapé e campo de observações.
- **Prompt 7** (boletos antes da hora): bloco "Boletos desta venda" só aparece depois de alguma baixa registrada — decisão default tomada nesta entrega (1ª separação parcial confirmada, não só entrega 100%), já que o documento de origem não fechava esse gatilho.
- **Prompt 4** (contraste): números de orçamento/venda/código de item/produto (busca de vendas, tabela de itens, Log de Trocas) passaram para cor escura (`#333333`), semibold e leve `letter-spacing`.
- Publicado em produção: `https://separacao-parcial-dff01.goskip.app` (Skip `48801`, versão `0.0.30`, QA setup/staticAnalysis/build/integrations/test 100% verde).

### Migrations SPEC-135/SPEC-136 aplicadas em produção — Prompts 1, 2, 3 e 3A concluídos

- As duas migrations represadas desde 11/09 (`aprovar_orcamento_financeiro` com bloqueio de peça sem cadastro + `numero_venda`; `replace_orcamento_itens` com o fix do "reset falso-positivo" do ciclo de aprovação) foram aplicadas no Supabase real em 2026-09-14, rodadas manualmente pelo usuário via `psql` (ação bloqueada para execução automática pelo classificador de modo automático do Claude Code — "Production Deploy").
- **Bug encontrado e corrigido antes de aplicar**: a migration da SPEC-136 inseria a coluna nova `venda_numero` no meio da lista de colunas de `vw_estoque_saldos_projeto_item`; `CREATE OR REPLACE VIEW` no Postgres só aceita coluna nova no final da lista — teria falhado. Corrigida nos 2 arquivos (repo central + submodule) antes de qualquer tentativa de aplicação.
- **Gap encontrado só depois de aplicar a migration da SPEC-136**: ela reescreve `aprovar_orcamento_financeiro` (Prompts 2 e 3) mas nunca tocava `replace_orcamento_itens` (Prompt 1) — apesar de o texto da SPEC dizer que era "superset" da 135. Corrigido com uma migration adicional, `supabase/db/migrations/20260914_139_fix_replace_orcamento_itens_pos_136/`, aplicando só essa função (sem reaplicar a versão antiga de `aprovar_orcamento_financeiro`, que teria revertido `numero_venda`).
- Cada migration foi testada primeiro com dry-run (`BEGIN; ...; ROLLBACK;` contra o Supabase real) antes do `COMMIT` de verdade — nenhum erro em nenhuma das duas.
- Confirmado em produção via `information_schema.columns` e `pg_get_functiondef`: `orcamentos.numero_venda`, `vw_estoque_saldos_projeto_item.venda_numero`, bloqueio de peça sem cadastro e no-op de itens iguais — todos presentes.
- **Com isso, os 7 prompts do documento "LUCENERA — LIGHT DESIGN" (11/09/2026) estão implementados e em produção.** Falta só teste ao vivo end-to-end de cada fluxo (não bloqueia nada, é validação de conforto).

## 2026-09-13

### Peças Ubiqua sem foto na vitrine do Showroom — SPEC-137

- Pedido do usuário: peças da marca Ubiqua já marcadas como pronta-entrega na planilha (`produtos.estoque_showroom > 0`) não apareciam na vitrine pública do Showroom, mesmo já tendo fotos cadastradas no site/catálogo Ubiqua.
- Causa raiz: `vw_showroom_publico` exige `imagem_showroom_url` preenchido; a curadoria de fotos da SPEC-125 só cobriu a lista de decorativos Lucenera, nunca as peças Ubiqua. O catálogo Ubiqua (`revenda_ubiqua`, tabela isolada do sistema `catalogo-pecas-ubiqua-e6fa0`) já tinha foto pronta para 33 das 34 peças Ubiqua marcadas como showroom.
- Migration `20260913_137_showroom_fotos_ubiqua` — backfill único de `produtos.imagem_showroom_url` a partir de `revenda_ubiqua.imagem_catalogo_url`, casando por `referencia`. Aplicada no Supabase real: **33 linhas afetadas**. Vitrine foi de 29 para 62 peças.
- Decisão do usuário: `produtos` continua a única fonte de verdade do estoque do showroom; `revenda_ubiqua` só emprestou a foto, sem sincronização automática nova entre os dois sistemas.
- Conferido ao vivo no site publicado (`tela-showroom-522b1.goskip.app`): 31 das 33 peças Ubiqua aparecem com foto, nome, preço e quantidade corretos.
- Pendências: 1 peça Ubiqua (`370106-IS`) sem correspondência no catálogo, precisa de foto cadastrada manualmente via `/admin` do showroom; 2 peças (`339101`, `339104`) com foto quebrada na origem — `revenda_ubiqua.imagem_catalogo_url` aponta pra arquivo que não existe mais no bucket `revenda-ubiqua-images` (achado pré-existente do catálogo Ubiqua, não causado por esta SPEC).

## 2026-09-11

### Campo Código do Projeto em todos os formulários — SPEC-134 (Memória Lucenera)

- Pedido do usuário: marcar qualquer memória (entidade, conhecimento, experiência, decisão, projeto, fonte, captura, upload, memória por voz) com o código de um projeto operacional Lucenera (ex.: `26.181`), para facilitar a busca depois.
- Coluna `project_code text` (texto livre, sem FK) adicionada em 7 tabelas do schema `memoria` + índice parcial cada — migration `20260911_134_memoria_lucenera_project_code` aplicada no Supabase real.
- Campo adicionado nos 6 formulários genéricos, na captura rápida, no upload de arquivo e na revisão de memória por voz (`public/app/app.js` + `public/app/supabase-adapter.js`, Skip projectId 57204), exibido também na tela de detalhe. Busca global já é full-text sobre o registro inteiro, então o código já fica pesquisável sem filtro dedicado novo.
- QA do Skip verde, publicado em produção (`memoria-lucenera-2e074.goskip.app`, v0.0.8 / `cc8afcf`). Sem teste manual ao vivo no navegador (login/SSO segue como pendência aberta desde a SPEC-129).

### Desativada a function legada sync-sharepoint (tocava outra lista) — SPEC-130

- Usuário perguntou explicitamente se a automação toca alguma lista além de "Organização Projetos". Resposta honesta: a automação NOVA (push/pull), sim, só toca essa lista (auditado no código: `LIST_DISPLAY_NAME` fixo, Estado resolvido contra tabela própria, nunca lê "Estados" ao vivo em produção). Mas a function **antiga** `sync-sharepoint` (de antes desta SPEC) continuava **ativa** e lia "Tabelas de Preços" também, acionável manualmente por um botão em `Sync.tsx` (Dashboard Financeiro, Skip `projectId 41135`).
- Por decisão do usuário: **function apagada do Supabase**; **botão removido de `Sync.tsx`** (Skip aplicado + publicado, produção `dashboard-empresa-40d7d.goskip.app`, versão `0.0.43`/`a24ebab`, QA verde); pasta local `supabase/functions/sync-sharepoint/` removida do repo central; `AUTOMATION_INVENTORY.md` atualizado.
- Resultado: agora nenhuma automação do ecossistema toca outra lista do SharePoint além de "Organização Projetos".

### Investigação dos 6 órfãos antigos + documentação estrutural da trava — SPEC-130

- Usuário pediu pra investigar os 6 projetos antigos sem vínculo e confirmar que nada foi alterado indevidamente na lista real, com destaque pra durabilidade da trava (nova sessão sem contexto desta conversa precisa saber que ela existe).
- `20.265` (CAROL E MATHEUS) era duplicata por troca de dígito — real é `20.065`, já no sistema; **apagado**. Os outros 5 (`15.255`, `24.391`, `24.399`, `24.404`, `24.474`) têm status "Obra Finalizada" e não existem mais em lugar nenhum da lista ativa — projetos concluídos há meses (maio/2026), removidos pelo time depois de finalizados, bem antes desta SPEC. Comportamento correto (exclusão nunca propaga), **mantidos como estão**.
- **Auditoria ao vivo confirmou**: nenhum registro interno (`COM-N`, `PRJ-TESTE`) foi criado na lista real durante o incidente de hoje; itens mais recentes da lista são todos projetos reais. Guarda de código (`018`) confirmada genuinamente ativa no banco via `pg_get_functiondef` (não só no arquivo de migration).
- **`supabase/db/domains/crm.md` atualizado** (arquivo que qualquer sessão é instruída a ler antes de mexer em `projetos`, por regra do `AGENTS.md`) — nova seção "SPEC-130" documenta a trigger de push, o risco de `UPDATE` em massa, e por que a guarda de formato de código existe. Torna a proteção legível por uma sessão futura sem depender do histórico deste chat.
- **Impacto no banco**: 1 DELETE (`20.265`). Nenhuma mudança de schema.

### Checagem completa de saúde da sincronização — achado sério de robustez corrigido

- Usuário pediu uma checagem geral de "está tudo certo" entre SharePoint e CRM. Achados:
- **Cron do pull**: saudável, 24 execuções sem erro nas últimas 2h.
- **🔴 Achado sério, corrigido**: as limpezas em massa de `cidade`/`estado` do mesmo dia dispararam push pra ~800 projetos quase simultaneamente (via `UPDATE` cru, sem passar por RPC com ritmo controlado) — Microsoft Graph limitou (throttling) e 432 pushes falharam. Nenhum dano real aconteceu (0 criações efetivamente ocorreram), mas por **sorte**: entre os afetados estavam registros internos que não são projeto de cliente (`COM-1`...`COM-15` "Projeto Comissão N", `PRJ-TESTE`), que quase viraram itens de verdade na lista real do SharePoint. **Corrigido**: nova guarda na trigger de push (migration `018`) — só dispara push quando `codigo` bate com o formato real (`^\d{2}\.\d+$`).
- **Comparação completa ao vivo** (direto no Graph, não planilha — 20 páginas, 3.963 itens reais): **0 itens sem correspondência no banco**; nome/responsável/cidade/nível **100% batendo**. 7 divergências de status achadas e corrigidas (sincronizados antes do mapa de 17 valores ficar completo mais cedo no mesmo dia, nunca reprocessados depois). Restam 6 projetos antigos (maio/2026, anteriores a esta SPEC) sem vínculo — não é erro desta sincronização, baixa prioridade.
- **Impacto no banco**: migration `018` (fix de trigger) + 7 UPDATEs de correção de status. Nenhuma mudança de schema.

### Resolvidas as 3 duplicatas restantes por busca fuzzy — só 26.1109 fica pendente

- Usuário questionou por que 3 dos 12 casos não tinham duplicata encontrada. Busca fuzzy (não só texto exato) achou os 3, com diferença de grafia: `26.273` MARIA VANTINI → **MARINA VANTINI**/`24.456`; `26.280` EDUARDO MASSOLI - AP → **EDUARDO MASSOLI - APTO CIDADE DE VANCOUVER**/`25.420`; `26.282` FACHADA CASA COR 2026 → **FACHADA CASACOR 2026** (sem espaço)/`26.180`. Confirmados os 3 códigos no sistema, 0 dependência, **apagados** (com reconfirmação do usuário — o DELETE foi bloqueado uma vez pelo classificador automático).
- **`26.1109` (Vinicius Bortolin) identificado**: usuário confirmou que é o Vinícius da administração — o "projeto" é teste mesmo. Achado: tem 1 orçamento vinculado com status "Orçamento Aprovado", R$ 16.271,40 (FK `ON DELETE SET NULL` — apagar o projeto deixaria o orçamento órfão). **Decisão explícita do usuário: não apagar nada** — mantido como está.
- **Achado técnico**: `field_0` (Codigo) é texto simples com `enforceUniqueValues: true` (não lookup, não calculado) — confirmado via `GET /lists/{id}/columns`. Explica por que o time precisa esvaziar o código do item duplicado antes de atribuir o mesmo valor ao corrigido. O endpoint `/versions` do Graph se mostrou **não confiável** pra reconstituir histórico de coluna customizada nesta lista — não usar pra esse tipo de auditoria no futuro.
- **Impacto no banco:** 3 DELETEs. Nenhuma mudança de schema.

### Achadas e removidas 9 duplicatas com código apagado no SharePoint — SPEC-130

- Usuário apontou de novo "CRM não bate com a planilha", citando `26.273`-`283` e `26.1109`/`26.1110`. Investigação achou 2 coisas: (1) a comparação "banco→planilha" anterior tinha 354 "órfãos", mas a maioria era falso positivo — a planilha fornecida é um recorte incompleto da lista real, não um espelho total (confirmado ao vivo via Graph); (2) 12 casos REAIS de itens que continuam existindo no SharePoint mas com o código (`field_0`) esvaziado pelo time — mesmo padrão do vazamento `26.284` anterior (item criado sem código, SharePoint autonumera errado, time cria a versão corrigida e limpa o código da errada em vez de excluir).
- Busca ao vivo por Title exato confirmou **9 de 12 como duplicata com a versão corrigida já existindo no sistema**: `26.274`→`25.048`, `26.275`→`25.061`, `26.276`→`25.086`, `26.277`→`25.134`, `26.278`→`25.252`, `26.279`→`25.279`, `26.281`→`26.169`, `26.283`→`26.231`, `26.1110`→`26.269`. **Apagados do banco** (dado real preservado sob o código correto).
- **3 sem duplicata confirmada, mantidos**: `26.273`, `26.280`, `26.282` (mais `26.1109`, que ainda nem foi corrigido do lado deles). Ficam pendentes de confirmação com o time.
- **Impacto no banco:** 9 DELETEs. Nenhuma mudança de schema.

### Fix de lixo legado (cidade/estado) achado por comparação campo a campo — SPEC-130

- Usuário reportou "CRM não bate com a planilha". Comparação campo a campo (não feita antes — o sync anterior só confirmava gravação, não igualdade final) achou lixo **pré-existente** (não introduzido por esta SPEC): `cidade` com literal `.`/`None` em 108 projetos, `estado` com literal `No` em 693 projetos (resto de "None" cortado em 2 caracteres). O `COALESCE` das RPCs protegia esse lixo de ser limpo (planilha vinha com o campo genuinamente vazio).
- Limpeza direta: `cidade`→NULL onde era `.`/`None` (108), `estado`→NULL onde era `No` (693).
- **Reconferido campo a campo: 3.735 de 3.736 projetos batendo 100%** com a planilha. O único restante (`26.1109`) é proteção funcionando por design (SharePoint zerou Estado/Status depois do backfill inicial; sistema manteve o valor antigo em vez de apagar).
- **Impacto no banco:** 801 UPDATEs de limpeza de dado (nenhuma coluna/schema nova).

### Reconciliação via planilha + limpeza de testes — SPEC-130 (2026-09-14)

- Usuário forneceu `01-Documento/01 - Planilhas/Planilha de projetos.xlsx` (export local, 3.748 linhas, sem ID de item). Criada RPC `aplicar_planilha_projetos` (migration `017`, casa só por `codigo`) + `scripts/sincronizar_planilha_projetos.py`. Resultado: **3.736 atualizados, 0 criados, 0 erros** — confirma que o cron incremental já vinha mantendo tudo sincronizado sozinho nos últimos 3 dias.
- **Limpeza de testes**: apagados `26.268`/`7152`, `26.285`/`7154`, `26.286`/`7157` (banco + lista real via Graph DELETE), e a function temporária `sharepoint-teste-conexao` (Supabase + arquivo local).
- **Achado durante a limpeza**: o item `7151` (1º teste de conectividade) nunca mandava `field_0` — o SharePoint atribuiu um código real sozinho (`26.284`), que o pull trouxe pro banco como projeto de verdade com nome literal de teste. Apagado dos dois lados. Não é bug do push definitivo (sempre manda `field_0`), só da function de teste crua já removida.
- **Achado não resolvido, não é nosso**: `26.230`/"TESTE" (item `7112`, bem mais antigo que qualquer teste desta SPEC) — não mexido, decisão do usuário se apaga.
- **Impacto no banco**: 3.736 UPDATEs de reconciliação + 4 DELETEs de limpeza (`26.268`, `26.284`, `26.285`, `26.286`). Nenhuma mudança de schema.

### Confirmado: Estado era o bloqueio da automação — de-para de status expandido pros 17 valores

- **Usuário confirmou**: o grupo/pasta foi criado no teste `26.286`/item `7157` — Estado era mesmo o bloqueio real da automação de criação de grupo.
- Expandido `sharepoint_status_map` pros 17 valores do enum `projeto_status` (identity mapping — mesmo texto dos dois lados), não só os 3 confirmados manualmente. Resincronizados os 2 testes anteriores (`26.268`/`7152`, `26.285`/`7154`) com `estado='SP'` — ambos gravaram sem erro, confirmado via Graph (`field_10="Estudo Inicial"`, `EstadoLookupId=1`). Aguardando confirmação se o grupo foi criado pros dois também.
- Só 2 dos 17 valores do mapa foram confirmados por escrita real bem-sucedida; os outros 15 são presunção (mesmo texto) não testada — se algum não for uma opção de Choice válida no SharePoint, o push daquele projeto específico falha e fica visível em `sharepoint_sync_log`, sem afetar os demais.

### Implementado Estado (lookup) — SPEC-130, achado que pode ser a causa real da automação não disparar

- Usuário reportou que a automação de criação de grupo/pasta nunca disparou em nenhum dos 3 testes. Investigação: os 3 (`7151`/`7152`/`7154`) tinham Estado vazio — a lista mostra "Informações necessárias" pra campo obrigatório vazio. Teoria de "nome do responsável muito longo" descartada com evidência (teste com nome curto também falhou).
- Achada a lista "Estados" no site SharePoint (28 itens). Criado `sharepoint_estado_map` (migration `014`, seed com os 27 IDs reais). RPC `aplicar_pull_sharepoint` ganhou `p_estado` (`015`, DROP+CREATE por mudar assinatura). Push e pull resolvem `EstadoLookupId` nos dois sentidos. Trigger de push passou a disparar também só com mudança de `estado` (`016`).
- **Teste completo** (`26.286`/item `7157`): nível, status ("Proposta Sinal") e estado ("SP") todos preenchidos — push sem erro, conferido via Graph. Primeiro teste com informação completa, aguardando confirmação se o grupo foi criado.
- Pendência nova: `sharepoint_status_map` só tem 3 de ~17 valores — status fora do mapa ainda não é enviado, pode continuar bloqueando a automação em outros projetos.

### Fix Data Entrada + seed parcial de Status — SPEC-130

- **Bug achado pelo usuário**: `data_entrada` ficava sempre em branco depois de sincronizar — o código do pull/backfill mandava `NULL` sempre, desatualizado em relação à SPEC (que já confirmava ser dado real, não automático). Corrigido em `sharepoint-projetos-pull/index.ts` + `backfill_sharepoint_projetos.py`, function redeployada, backfill reprocessado: **4.087 de 4.087 projetos com Data Entrada preenchida**.
- **Seed parcial de status (decisão do usuário)**: `sharepoint_status_map` recebeu os 3 valores que já batem exatamente (`Proposta Sinal`, `Elaboração Orçamento`, `Contrato de Projeto`). Reprocessado: 602 + 211 + 11 projetos passaram a sincronizar esses status, sem tocar em status pré-existente de outra origem. Resto da tabela segue como pendência do Vinícius.
- Nenhuma mudança de schema além dos dados; nenhuma coluna nova.

### Backfill rodado + pipeline homologado ponta a ponta — SPEC-130 funcional em produção

- `scripts/backfill_sharepoint_projetos.py` criado e rodado: 3.975 itens da lista processados via `/items/delta` (fora do limite de 5s do `pg_net`, mesma RPC do pull incremental). **306 projetos criados, 3.669 atualizados, 0 erros.** Faixa `26.181`–`26.267` foi de 1 para 85 projetos; `projetos` foi de 3.781 para 4.087. `deltaLink` inicial salvo — cron incremental reativado.
- 1ª tentativa de rodar de verdade foi morta pelo SO por pouca memória aos ~2.311 itens (sem dano, RPC idempotente); script ganhou reconexão automática de banco (a 1ª tentativa de dry-run já tinha caído por "server closed the connection" no meio do crawl).
- **Achado extra pós-backfill**: mesmo o pull incremental (0 itens a processar) estourava os mesmos 5s do `pg_net` — corrigido aumentando `timeout_milliseconds` (`013_aumentar_timeout_pg_net.sql`: 20s push / 60s pull; seguro, `pg_net` é assíncrono). Confirmado ao vivo: tick seguinte voltou `200, processados:0, timed_out:false`.
- **Pipeline homologado ponta a ponta**: push automático (com anti-duplicação) e pull automático incremental confirmados funcionando ao vivo, cron limpo. SPEC-130 passou de "não iniciado" para "pendente" (funcional, faltam pendências menores: de-para de status do Vinícius, RLS das tabelas de log, doc `AI_DB_CONTEXT.md`/`domains/crm.md`, commit no Git).
- **Nada disso está commitado no Git ainda** — todo o trabalho de hoje (SPECs, 13 arquivos de migration, 2 Edge Functions, script de backfill, `.env` limpo) existe só no disco local.

### Revisado e corrigido — SPEC-130: revisor achou 2 críticos, corrigidos e reployados; SharePoint vira fonte de verdade temporária

- Rodado o `revisor` na migration + 2 Edge Functions já aplicadas/deployadas. Relatório: `03-Projeto/Auditoria/2026-09-11_auditoria_spec130_sharepoint_projetos_sync.md`.
- **🔴 Corrigido — duplicação no push**: antes de criar item novo, busca por `codigo` na lista primeiro (não se repete), evitando duplicar quando uma tentativa anterior grava no Graph mas falha antes de confirmar no banco. Testado ao vivo: zerei o `sharepoint_item_id` do projeto de teste de propósito e editei de novo — reencontrou o item `7152`, não criou um novo.
- **🔴 Corrigido — filtro do pull com risco de injeção**: `.or()` com string concatenada (`codigo` vindo livre do SharePoint) trocado por duas consultas `.eq()` parametrizadas.
- **🟡 Corrigido — `disparar_pull_sharepoint()` sem REVOKE/GRANT** (`012_fix_grant_disparar_pull.sql`), alinhado com as outras 3 funções da migration.
- **Decisão do usuário**: pra resolver a duplicação por outro ângulo e simplificar, **SharePoint passa a ser fonte de verdade temporária** para todos os campos sincronizados — removida a lógica de conflito por `updated_at` do pull (já marcada como frágil pelo revisor, pois a coluna é tocada por outros sistemas também). É reversível/temporário: detecção de conflito de verdade volta numa fase futura de duas vias simultâneas.
- Achados 🟡/🔵 restantes do revisor (RLS sem policy nas tabelas novas, retry com backoff ausente, `gerar_codigo_projeto()` sem proteção contra código legado fora do padrão, doc `relationships.md` desatualizada) ficaram registrados como pendência, não corrigidos ainda.
- **Impacto no banco**: migration `012` aplicada (revoke/grant). Nenhuma coluna/tabela nova.

### Aplicado e testado ao vivo — SPEC-130: push automático Projetos → SharePoint funcionando; pull pausado por achado de escala

- Migration `20260911_132_sharepoint_projetos_sync_2via/` **aplicada no Supabase real** (10 arquivos + `011` de correção); as 2 Edge Functions (`sharepoint-projetos-push`, `sharepoint-projetos-pull`) **deployadas**; 3 secrets criados no Vault (`sharepoint_sync_secret`, `sharepoint_push_url`, `sharepoint_pull_url`) + `SHAREPOINT_SYNC_SECRET` nos secrets das functions.
- **Fix pós-deploy**: Edge Functions do Supabase exigem `Authorization` (JWT) por padrão da plataforma, além da autenticação própria — `pg_net` recebia 401 antes de chegar no código da function. Corrigido mandando `Authorization: Bearer <anon key>` junto (anon key não é segredo, só satisfaz a plataforma; `x-sync-secret` continua sendo a proteção real). Anon key guardado no Vault (`supabase_anon_key`).
- **Teste real, com sucesso**: criado/editado o projeto "teste" (`26.268`, responsável Mariane) direto no banco → trigger disparou sozinha → item `7152` criado na lista "Organização Projetos" → log confirmou `action=create, resultado=ok`. Push automático funcionando de ponta a ponta.
- **Achado crítico de escala no pull**: a lista tem **3.781 itens**. A 1ª execução (sem `deltaLink`) precisa varrer tudo — estourou o timeout padrão do `pg_net` (5s). **Cron do pull pausado** (`cron.alter_job(active => false)`) até o script de backfill (Item 9, ainda não escrito) rodar em lotes e estabelecer o `deltaLink` inicial — reativar o cron antes disso repetiria a varredura pesada a cada 5 min.
- **Impacto no banco (produção, real)**: 5 colunas novas + 4 tabelas novas em `public`, 2 extensões habilitadas pela 1ª vez neste projeto (`pg_net`, `pg_cron`), 1 cron job criado (pausado), 4 funções novas (`gerar_codigo_projeto`, `confirmar_push_sharepoint`, `aplicar_pull_sharepoint`, `disparar_pull_sharepoint`) + 2 triggers em `projetos`. 1 projeto de teste real criado (`26.268` "teste") e 1 item real na lista SharePoint (`7152`) — ambos marcados pra limpar depois de confirmado.
- **Pendências antes de reativar o pull**: escrever o script de backfill em lotes, seed do de-para de status (Vinícius), atualizar `AI_DB_CONTEXT.md`/`domains/crm.md`, rodar o `revisor`.

### Rascunho — SPEC-130: migration + as 2 Edge Functions definitivas da sync SharePoint (nada aplicado)

- Escritos os 10 arquivos da migration `supabase/db/migrations/20260911_132_sharepoint_projetos_sync_2via/` e as functions `supabase/functions/sharepoint-projetos-push/index.ts` + `supabase/functions/sharepoint-projetos-pull/index.ts`. **Nada aplicado no Supabase real, nenhuma function deployada.**
- Achado que mudou o design: `pg_net`/`pg_cron` não estavam habilitados neste projeto. Anti-eco trocado de "hash comparado entre PL/pgSQL e Deno" (frágil entre linguagens) para uma trigger BEFORE que garante `last_sync_source` sempre correto — mais simples e mais robusto, mesmo comportamento externo prometido ao usuário.
- Correção de schema encontrada: `responsavel_obra_id` referencia `usuarios`, não `contatos` (SPEC-130 tinha isso errado desde a versão original).
- Segredos (URL das functions + `x-sync-secret`) ficam no Supabase Vault, nunca em `.sql` versionado — pipeline fica inerte até alguém criar os 2 secrets manualmente.
- Pendências antes de ir ao ar: habilitar `pg_net`/`pg_cron`, criar os secrets do Vault, deploy das 2 functions, seed do de-para de status (Vinícius), script de backfill (Item 9, ainda não escrito), homologação real da query `delta` do pull (nunca testada ao vivo), e revisão do `revisor` antes de aplicar (extensão de banco + RPCs `security definer`).

### Testado — SPEC-130/131: conectividade real da sync SharePoint confirmada (com incidente de secret)

- App "Lucenera CRM" registrada no Azure/Entra ID (`Sites.Selected`, admin consent, escrita concedida só ao site `LUCENERAPROJETOS345`) — fecha o Item 3 da SPEC-131.
- Criada function temporária `supabase/functions/sharepoint-teste-conexao/index.ts` (fora do escopo definitivo da SPEC-130, só para validar a permissão nova antes de construir o pipeline completo) e deployada no projeto Supabase `vcvcwzmbiftcawncibke` com `supabase functions deploy --use-api` (CLI autenticado via `SUPABASE_ACCESS_TOKEN` do `.env`, sem uso de `supabase login` interativo — não funciona neste ambiente sem TTY).
- **Teste real: sucesso.** `POST` criou o item `7151` na lista "Organização Projetos" (**201**), `lastModifiedBy.application.displayName = "Lucenera CRM"` confirmando a escrita pela app nova. `field_9 = "Mariane"` confirma o campo de responsável/vendedor.
- **Achado que corrige a SPEC-047/130:** `field_6` (suposto "Data de Entrada") veio preenchido sozinho pelo SharePoint com a data/hora da criação, sem envio no payload — indício de campo automático de sistema, não editável. SPEC-130 atualizada para não mapear `data_entrada` nele sem confirmação do Alan.
- **Incidente de segurança:** o `.env` central tinha os 3 nomes `SHAREPOINT_TENANT_ID/CLIENT_ID/CLIENT_SECRET` duplicados (uma integração de Ficha Técnica e o CRM reusando os mesmos nomes) e uma linha corrompida (`""=<secret>`) que quebrava o parser do `supabase functions deploy`. Ao diagnosticar isso, um comando de depuração **imprimiu por engano o valor completo do client secret** nesta conversa. Secret tratado como comprometido; rotação combinada com o usuário mas **ainda pendente** — registrada como bloqueio de segurança na SPEC-131.
- **Repos a receber commit:** central (SPEC-130, SPEC-131, function de teste, CHANGELOG). `.env` não é commitado (correto, mas segue com a duplicação/linha corrompida a limpar — pendência registrada).
- **Pendências abertas:** rotacionar o secret; renomear as chaves `SHAREPOINT_*` no `.env` pra separar Ficha Técnica de CRM; confirmar se a automação de pasta/Teams disparou pro item de teste `7151`; apagar o item de teste e a function temporária; nomes internos reais das colunas da lista (Alan).
- **Complemento (mesmo dia):** usuário passou os nomes de exibição de todas as colunas + 3 linhas de exemplo reais da lista. Fechou o mapa de campos de negócio da SPEC-130 (faltava só confirmação formal do Alan, não bloqueia mais). Achados: formato de código confirmado `AA.NNN`; campo vazio usa o caractere literal `.` (não string vazia); "Tipo de Item" é Content Type de sistema (`"Item"` sempre); **"Caminho" não é o link da pasta por projeto** (é o path da própria lista, igual em todo item) — reabre a pergunta de onde mora o link que a SPEC-046 lia.

### Concluída — SPEC-132: campos fiscais da planilha Produtos (export Connect) + incidente de preço corrigido

- Criada `03-Projeto/Planos de Ação/SPECs/SPEC-132_Campos_Fiscais_Planilha_Produtos_Connect.md`. O export "Estoque" do Connect passou de ~16 para 36 colunas, com campos fiscais (`icmsST`, `ipi`, `frete`, `ncm`, `cest`, 4 pares `GrupoFiscal*`) e a coluna de custo unitário renomeada `CustoTotal` → `vlCustoTotal`.
- **Fase A** (`importar_produtos_estoque.py`): conserto do rename + sincronização de `ncm`/`cest` (colunas já existiam, quase vazias) — backfill de 372→4.715 (`ncm`) e 2→1.099 (`cest`). Sem risco de preço.
- **Fase B** (decisão do Filippo/Pedro, sem recalcular `preco_venda`): sincroniza `icmsST→porc_st`, `ipi→ipi_entrada`, `despesas→porc_despesas`, `desconto→porc_desconto`, `frete→porc_frete`, mais 2 colunas novas `grupo_fiscal_nao_contribuinte`/`grupo_fiscal_revenda` (migration `20260910_131_spec132_grupo_fiscal`).
- **Incidente e correção:** a 1ª execução tentou "grava o campo fiscal, deixa o trigger recalcular, regrava `preco_venda` de volta" — falhou porque `produtos` tem um 2º trigger de preço não documentado (`trg_calculo_preco_venda`, sem filtro de coluna, dispara em qualquer update) além do já conhecido `trg_atualizar_preco_venda`. A própria regravação redisparava o 2º trigger. **~2.120 produtos ficaram com `preco_venda` inflado (5–15%)** até o reparo: script one-off restaurou de um snapshot pré-run com os 2 triggers desligados numa transação — verificado 0 divergências.
- **Fix definitivo:** `importar_produtos_estoque.py` reescrito — a gravação real roda numa transação única via `psycopg2`/`SUPABASE_DB_URL` com os 2 triggers de preço desligados do início ao fim; sem mais grava-e-devolve. Testado com gravação real (51 produtos do ciclo normal), `preco_venda` idêntico antes/depois.
- **Impacto no banco:** migration `20260910_131` (2 colunas novas em `produtos`, sem DDL em trigger/função); dados fiscais preenchidos em ~2.900–4.400 produtos conforme o campo; `preco_venda` inalterado (conferido).
- **Repos a receber commit:** central (SPEC-132, migration, `scripts/importar_produtos_estoque.py`, `scripts/_supabase_client.py`, `scripts/AGENTS.md`, CHANGELOG).

## 2026-09-10

### Criada (não iniciada) — SPEC-130: Sincronização em duas vias Projetos ⇄ Lista SharePoint

- Criada `03-Projeto/Planos de Ação/SPECs/SPEC-130_Sincronizacao_Duas_Vias_Projetos_Sistema_SharePoint.md`. Pedido do usuário (conversa com Alan/M365): criar projeto no sistema e refletir automaticamente na lista "Organização Projetos" do SharePoint (`site LUCENERAPROJETOS345`) — e vice-versa. Substitui e amplia a SPEC-047 (que era pull diário de mão única, nunca implementada).
- **Direção fechada com o usuário: duas vias (opção C).** Sistema → SharePoint em tempo quase real (trigger no `projetos` → Edge Function `sharepoint-projetos-push` via `pg_net`). SharePoint → sistema por `GET /items/delta` no `pg_cron` (proposto 5 min), Edge Function `sharepoint-projetos-pull` substituindo a `sync-sharepoint` atual.
- **Decisões aprovadas:** código do projeto passa a nascer só no sistema (RPC `gerar_codigo_projeto()`; SharePoint para de gerar, com data de virada); criação permitida nos dois lados amarrada por `sharepoint_item_id`; exclusão nunca propaga (só o flag `arquivado`); anti-eco por `sync_hash` + `last_sync_source`; conflito = *last-write-wins* de item **inteiro** com todo conflito registrado em `sharepoint_sync_log` (log de quem alterou dos dois lados — usuário do CRM e `lastModifiedBy` do SharePoint); status sincroniza via tabela de de-para `sharepoint_status_map`; arquiteto/responsável de obra só vinculam de volta com match exato em `contatos` (sem fuzzy).
- **Migration (rascunho, não aplicada)** — pasta proposta `supabase/db/migrations/20260910_131_sharepoint_projetos_sync_2via/`: colunas de controle em `projetos` (`sharepoint_item_id`, `sync_hash`, `last_synced_at`, `last_sync_source`, `last_synced_by`) + tabelas `sharepoint_sync_log`, `sharepoint_status_map` (sem seed), `sharepoint_sync_state` (deltaLink/cache) + RPC de código + trigger de push.
- **Impacto no banco:** nenhum ainda (SPEC não iniciada). Quando implementada: `projetos` (+5 colunas) e 3 tabelas de apoio; sem mudança destrutiva.
- **Repos a receber commit:** central (SPEC-130 + CHANGELOG). Implementação futura no CRM (Skip projectId 24580) + Supabase.
- **Bloqueios (terceiros):** Alan — elevar app do Graph para `Sites.Selected` + admin consent, confirmar que a automação de pasta/Teams dispara em criação app-only, enviar nomes internos das colunas da lista. Vinícius — preencher o de-para de status e a data de virada do código.
- **Escopo de acesso (reforçado pelo usuário):** a integração terá permissão só para a lista "Organização Projetos" do site `LUCENERAPROJETOS345` — nada mais no SharePoint/M365 pode ser alterado; `Sites.ReadWrite.All` descartado.

### Criada (não iniciada) — SPEC-131: Mudanças no SharePoint/M365 e virada operacional da sync de projetos

- Criada `03-Projeto/Planos de Ação/SPECs/SPEC-131_Mudancas_SharePoint_M365_e_Virada_Operacional_Sync_Projetos.md`, companheira da SPEC-130. Separa a parte de ambiente e processo (Azure AD, remoção do controle de código da lista, validação dos fluxos de automação, comunicação com a equipe, plano de freeze/virada e rollback) da parte técnica (SPEC-130). A SPEC-130 não entra em produção antes dos itens da SPEC-131 estarem concluídos.
- Não toca banco. Quase todos os itens são executados por Alan (M365/Azure AD) e Vinícius (processo/equipe), com evidência anexada na própria SPEC.
- Nota técnica registrada: `Sites.Selected` concede acesso no nível de site, não de lista — a restrição "só a planilha 'Organização Projetos'" é garantida pelo código da Edge Function (um `list-id` fixo), não pela permissão do Graph.

### Publicado — SPEC-129: Memória Lucenera integrada ao ecossistema + Central

- Criada `03-Projeto/Planos de Ação/SPECs/SPEC-129_Integrar_Memoria_Lucenera_Ecossistema_Central.md`. Pedido do usuário: trazer o sistema de memória institucional do Filippo (`github.com/filippogiorgibrasil/memoria-lucenera`) pra dentro do ecossistema e registrar na Central, com login único.
- **Banco (produção, autorizado):** o núcleo `supabase.sql` do Filippo já tinha sido aplicado pelo usuário (schema isolado `memoria`, 12 tabelas + RLS, bucket privado `lucenera-memory-files`). Nesta sessão: `ALTER ROLE authenticator SET pgrst.db_schemas = 'public, graphql_public, memoria'` + `NOTIFY pgrst` (schema exposto à API; `anon` segue barrado por design do Filippo, `authenticated` lê sob RLS — verificado). `INSERT` em `public.systems` (`slug='memoria'`, `visivel_no_hub=true`, link `https://memoria-lucenera-2e074.goskip.app/`, id `9463d897-…`). Migrations consolidadas (sem edição de regra) em `supabase/db/migrations/20260909_130_memoria_lucenera_schema/` — scripts 02–04 (organização/ingestão) **não aplicados** (fase 2). Removido o placeholder vazio `supabase/db/migrations/Filippo amarzenamento banco de dados/SQL`.
- **App / Skip (projectId 57204 → `memoria-lucenera-2e074.goskip.app`):** o app do Filippo é site estático sem build; o projeto Skip é scaffold React/Vite. Estratégia **A** (passthrough): `index.html` da raiz = casca React vazia (`#root`; `App.tsx`/`Index.tsx`/`Layout.tsx` renderizam `null`) + markup e scripts do app do Filippo. App em `public/app/` (`app.js`, `supabase-adapter.js`, `memory-organization-core.js`, `long-document-core.js`, `styles.css`) — conferidos byte a byte contra o fonte + `node --check`. `MEMORIA_CONFIG` inline com `%VITE_SUPABASE_URL%` / `%VITE_SUPABASE_PUBLISHABLE_KEY%` (substituição do Vite no build — sem chave commitada; env vars setadas no Skip). `.oxfmtrc.json` passou a ignorar `public/`. `vite.config.ts` é read-only no MCP do Skip.
- **SSO:** `public/app/sso.js` novo — consome `?sso_code=` da Central, troca em `exchange-cross-system-code` (mesmo projeto Supabase; **sem allowlist de destino no Hub → nenhuma mudança no Hub**), aplica a sessão e recarrega sem o parâmetro. Sem `sso_code`, é inerte (login e-mail/senha e demo seguem).
- **Fase 2 (adiada):** `memory-organization.js`, `document-ingestion.js`, `book-ingestion.js` + item "Organização da Memória" do menu — dependem das migrations 02–04 e das 4 Edge Functions, que serão adaptadas de **OpenAI para Gemini** (`GEMINI_API_KEY`; decisão do usuário por custo).
- QA do Skip verde (setup/static/build/integrations/test). **Publicado em produção** — versão 0.0.7 `e270d8e`. Preview e produção servem `/` + `/app/*` (HTTP 200), config substituída.
- **Impacto no banco:** `authenticator.pgrst.db_schemas` (config), `public.systems` (+1 linha). Nada em `public` alterado. `memoria` continua isolado.
- **Repos a receber commit:** central (SPEC-129, CHANGELOG, migration 130, docs). Submodule `04-Sistemas/memoria-lucenera` **ainda não registrado** — o GitHub `pedrolalala/memoria-lucenera` só tem o scaffold; o Skip não sincroniza a árvore pro Git sozinho (pendência).
- **Pendências:** publicar as migrations 02–04 + Edge Functions Gemini; teste ao vivo do SSO pelo Hub; registrar o submodule; `memoria` nos Exposed schemas do painel (durabilidade); acesso restrito/whitelist da IA aos dados operacionais de `public` (fase futura).

## 2026-09-08

### Rodado — Ciclo de sincronização Connect (planilhas `_2026-09-08.xlsx`)

- Constantes de caminho bumpadas nos 3 scripts (`importar_contas_pagar_receber.py`, `importar_pedido_compra.py`, `importar_produtos_estoque.py`) para `_2026-09-08.xlsx`, `--dry-run` conferido, depois gravação real. Todos os 3 imports com 0 erros: **Produtos** 234 atualizados (153 `CodProduto` sem match, mesmo padrão de sempre); **PedidoCompra** 15 pedidos novos + 10 atualizados (138→153 no banco); **ContaPagar/ContaReceber** 112 transações novas, 2.987 atualizadas, 43 parcelas órfãs canceladas, 48 negociações novas (empresa LUCE NERA), 402 combinações ambíguas roteadas para MANOELLA/preferida.
- **Conferência pós-import (contra a tabela crua `transacoes`)**: "Em Aberto A Pagar" bate **exato** com a planilha (R$ 5.235.961,85 nos dois lados). "Em Aberto A Receber" **não bate**: banco R$ 4.872.264,13 × planilha R$ 3.192.121,93 — diferença de **R$ 1.680.142,20**.
- **Investigação corrigiu 2 hipóteses erradas antes de achar a causa real**: (1) exemplos de duplicatas "duplicadas" (`dup 6840` etc.) eram na verdade colisão de número entre `tipo='despesa'` e `tipo='receita'` (não é bug — `cod_duplicata` não é único entre pagar/receber no Connect); (2) a view `v_financeiro_realizado` (o que o Dashboard mostra) **nunca esteve errada** — ela já exclui qualquer `(cod_duplicata,tipo)` ausente do export atual via `JOIN stg_duplicatas_vigentes`, confirmada batendo exato mesmo com a tabela crua desalinhada.
- **Causa real**: 420 `transacoes` (136 `cod_duplicata`, todas receita, quase todas `ISLIGHT`/`FOCO ILUMINACAO`) estavam abertas na tabela **crua** mas a duplicata inteira não aparece em nenhuma forma na planilha atual (nem aberta, nem paga — 109 das 136 já venceram há muito). A view escondia isso, mas `ContasEmAberto.tsx` (`retorno-bancario-bradesco-5392a`, SPEC-117) lê `transacoes` direto e mostraria o valor errado.
- **Bug pego em dry-run antes de gravar**: o primeiro rascunho do fix cancelava também 26 transações já **pagas** (R$ 156.989,14) de negociações duplicadas — corrigido para só cancelar `status_pago=0` antes de rodar de verdade.
- **Decisão do usuário (sem exceção: "a planilha é o real")**: `importar_contas_pagar_receber.py` ganhou a regra `duplicata_ausente_a_cancelar` — duplicata inteira ausente do export atual e ainda aberta no banco → cancelada (`status_pago=2`). Aplicado: **420 canceladas, 0 erros**. Depois disso, tabela crua e view batem exatas com a planilha nos dois lados. Também adicionada (sem impacto hoje, mas útil pra ciclos futuros) a regra `neg_ambigua_perdedora_ids`: quando `(cod_duplicata,tipo)` tem 2+ negociações no banco, cancela as em aberto da negociação "perdedora" (não-preferida).

## 2026-09-04

### Adicionado (QA verde, não publicado) — SPEC-128: Fluxo Futuro desmembrado em Contas a Pagar / Pedidos de Compra / Previsões

- Criada `03-Projeto/Planos de Ação/SPECs/SPEC-128_Dashboard_Fluxo_Futuro_Desmembrar_Pedidos_Compra_Previsoes.md`. Pedido do usuário: desmembrar o bloco único "A Pagar" da aba Fluxo Futuro em 3 fontes — **Contas a Pagar** (`transacoes`, sem mudança), **Pedidos de Compra** (`pedidos_compra`/`pedido_compra_parcelas`, app interno de Compras) e **Previsões** (`pedido_compra`/`staging_pedido_compra`, export Connect "PedidoCompra" — corrigido pelo usuário após o 1º rascunho, que assumia errado que era `pedidos_compra` sem parcela).
- **Achado — dedup determinística (P-03):** 51 dos 138 pedidos do export Connect já tinham sido recriados manualmente dentro de `pedidos_compra` como `numero = 'PC-LEGADO-<codigo_pedido>'` (achado original da SPEC-039, 22/07); excluídos de "Previsões" por chave exata para não duplicar com "Pedidos de Compra".
- **Achado técnico:** `pedidos_compra`/`pedido_compra_parcelas` não existem no `src/lib/supabase/types.ts` gerado do Dashboard — resolvido com cast local, documentado em `AI_DB_CONTEXT.md` novo (esse sistema não tinha nenhum ainda).
- `04-Sistemas/dashboard-lucenera-b02z85wa3`: `src/services/pedidos-compra-futuro.ts` (novo), `src/components/colunasPedidosCompra.ts` (novo), `src/pages/FluxoFuturo.tsx` (2 KPIs novos + banner de aviso de sobreposição + 2 tabelas `<PlanilhaTabela>` novas). **Publicado no Skip 41135 até o QA** — versão **0.0.40** / `70754b9`, setup/static/build/integrations/test tudo verde. **Não publicado em produção** — aguardando confirmação do usuário.
- Simplificação deliberada: os 2 blocos novos não entraram no `ComposedChart` existente (sem suíte de teste visual neste projeto, risco avaliado como desnecessário numa tela de diretoria) — ficaram como cards/tabelas à parte, sem herdar Horizonte/"Incluir vencidos"/cross-filter por mês. Registrado como pendência para decisão futura.
- Conferência contra o Supabase real: Pedidos de Compra em Aberto = 45 parcelas / R$ 142.078,19; Previsões = 87 pedidos elegíveis (138 − 51 legado) / R$ 827.886,04.

## 2026-09-03

### Implementado — SPEC-127 Escopos 1/1B/1C/3/4/5 (Dashboard, reunião Vinícius 03/09)

- **Estoque (v0.0.37 / `6bf3bc4`):** removidos os cards "Valor de Estoque (Custo/Venda)", "Venda em Déficit", "Showroom (Custo/Venda)" e "Marcas no filtro". Ficam os 3 principais (Custo Disponível, Custo em Déficit a comprar, Venda Disponível) + 2 de "De Cliente / Reservado". Nova aba **/showroom** (menu Operações) com as peças do showroom + cards + gráfico + planilha. Filtro de marca agora é **múltiplo** (novo `MarcaMultiSelect`, `filterByMarcas`).
- **Investimento (v0.0.38 / `fcf7a51`):** bloco "Investimento (no período)" abaixo do gráfico Fixo × Variável no Fluxo de Caixa — sem card no topo, sem gráfico. Novo `computeInvestimentoRealizado`.
- **Filtro de mês (v0.0.38):** `MesSelect` novo em Fluxo de Caixa / Recebimentos / Pagamentos (escolher o mês preenche o intervalo De/Até). Corrigido o bug do calendário range no `PeriodFilter` (o 1º clique não "fecha" mais o intervalo; popover fecha ao completar).
- **31/12 / Pendências (v0.0.39 / `271a253`):** nova aba **/pendencias-31-12** (menu Financeiro) listando os títulos em aberto com vencimento em 31/12 de qualquer ano, por ano + planilha. O **Fluxo Futuro passa a excluir** esses títulos de tudo (gráfico/KPI/tabela/pizza/planilha), com aviso no topo. Novo filtro "Vencimento De/Até" no Fluxo Futuro, aceitando data retroativa.
- Pendente: E2 (classificação fixo/variável do Ponto de Equilíbrio — Filippo/Vinícius) e E6 (cheque/RT — Connect).

### Planejado — SPEC-127: ajustes do Dashboard da reunião Vinícius 03/09

- Criada `03-Projeto/Planos de Ação/SPECs/SPEC-127_Dashboard_Reuniao_03_09_Cards_Estoque_Ponto_Equilibrio_Pendencias_31_12.md` a partir da transcrição da Reunião 01.
- Escopos: (1) enxugar cards do Estoque — remover "Valor de Estoque (Custo/Venda)" e "Venda em Déficit", reordenar os 3 principais; (1B) aba `/showroom` própria; (1C) filtro de marca múltiplo; (2) revisar classificação fixo/variável do Ponto de Equilíbrio — BLOQUEADO em Filippo/Vinícius; (3) Investimento destacado abaixo do gráfico fixo×variável, sem card; (4) Select de mês nas telas financeiras + bug do calendário range; (5) aba "31-12 / Pendências" + Fluxo Futuro excluindo `dt_vencimento = 31/12` + filtro De/Até retroativo; (6) proposta de data de baixa estimada (+6 meses) para cheque/RT.
- **Ressalva Estoque** documentada: os cortes de card são layout, não corrigem a causa (peça vendida-não-entregue conta em "estoque geral" e "reserva" no Connect); Estoque só reconcilia após limpeza no Connect + SPEC-126 Escopo 5. Nenhuma linha de código ainda.

### Corrigido + adicionado — Fluxo Futuro: filtro por mês, pizza das despesas, drill do grupo consertado (SPEC-126 E8)

- **Bug reportado pelo chefe:** ao clicar numa despesa (barra de grupo ou linha da tabela) a planilha "buscava do lugar errado" — vinha receita junto ("VENDAS A PRAZO" sob "ADMINISTRATIVAS") e todos os sub-grupos do grupo em vez de só o clicado. Causa: o recorte de grupo filtrava só por `desc_grupo` e não filtrava `tipo`. Corrigido: o drill de grupo/sub-grupo agora é **sempre `tipo = 'despesa'`** e respeita `desc_sub_grupo`. Os 4 KPIs voltaram a ser fixos no nível do mês.
- **Filtro "Mês" (Select)** no cabeçalho, além do clique no gráfico — lista "Vencido", set/2026, out/2026, … Compartilha estado com o gráfico e a tabela mês a mês.
- **Gráfico de pizza "Repartição das despesas em aberto"** (pedido do chefe): rosca da despesa em aberto por grupo (top-8 + "Outros") com legenda e % ao lado; clicar numa fatia abre o grupo nos sub-grupos. A barra "Composição por grupo" da v0.0.35 (que mostrava receita junto) saiu.
- Helper `computeDespesaAbertoPorDimensao` em `cash-flow.ts`. Publicado no Skip **v0.0.36 / `32990c4`**, QA verde.

## 2026-09-02 (5)

### Adicionado — Dashboard: aba "Fluxo Futuro (Projeção)" (SPEC-126 Escopo 8)

- Pedido do usuário: ver dentro do próprio Dashboard os **dados futuros** (o que ainda entra e o que ainda sai), para o chefe e o Vinícius, "com a planilha e o que vai gastar, quais os grupos".
- `04-Sistemas/dashboard-lucenera-b02z85wa3`: nova rota `/fluxo-futuro` + item no menu Financeiro. Consome só `v_financeiro_realizado` (parcelas `status_pago = 0`), agrupa por mês de `dt_vencimento`.
- Mostra: 4 KPIs (A Receber / A Pagar / Saldo Projetado / Vencido líquido); gráfico barras A Receber × A Pagar por mês + linha do saldo acumulado; tabela **mês a mês** (A Receber · A Pagar · Saldo do mês · Saldo acumulado); tabela **"o que vai gastar — por grupo"** (Grupo · Sub-grupo · Parcelas · Total · % do total); e a **planilha** de cada parcela em aberto (com coluna Grupo, que as outras abas não têm) + export CSV. Filtros: Horizonte (6/12/24 meses/Tudo), Perfil (Ribeirão/SP), "Incluir vencidos".
- `cash-flow.ts`: `janelaFuturo`, `computeFluxoFuturoPorMes`, `computeGastoFuturoPorGrupo`, `computeTotaisFluxoFuturo` (append; não alteram as funções existentes).
- **Publicado no Skip 41135** — versão **0.0.33** / `d319d45`, QA (setup/static/build/integrations/test) tudo verde. Números batem com a planilha `_2026-09-02.xlsx`: A Pagar R$ 5.479.292,14 / A Receber R$ 3.104.418,35 por vencimento.
- **v0.0.34 / `4b99af0`** — cross-filter por mês: clicar numa barra do gráfico (ou numa linha da tabela mês a mês) filtra os KPIs, o "o que vai gastar por grupo" e a planilha por aquele mês (ex.: só setembro), com chip para limpar.
- **v0.0.35 / `5846bdc`** — o gráfico também reage: com um mês aberto ele troca para "Composição de \<mês\> por grupo" (barras A Receber × A Pagar por grupo); clicar num grupo desce mais um nível e filtra tudo por mês + grupo. Chips "Mês" e "Grupo" para voltar.
- Submódulo git `dashboard-lucenera-b02z85wa3` **não** sincronizado (checkout local está várias SPECs atrás da produção do Skip) — a aba está no ar só pelo Skip; re-sync do submódulo fica como manutenção à parte.

## 2026-09-02 (4)

### Registrado + testado — padrão do ciclo de sincronização Connect

- `scripts/AGENTS.md` ganhou a seção **"Ciclo de sincronizacao Connect"** com as invariantes que os scripts precisam manter para o Dashboard bater com a planilha: `to_numeric_br` trata BR+US; o import de Contas sincroniza `vl_parcela`/`dt_vencimento`/`dt_emissao` em linha existente; duplicata ambígua vai para MANOELLA (não é pulada); parcela órfã (item fora do export) é cancelada; `LUCE NERA = MANOELLA`. Critério de sucesso: conferência receita/despesa realizadas por `dt_pagamento` e "Em Aberto" por `dt_vencimento` = R$ 0,00.
- **Ciclo 02/09 rodado** com as 4 planilhas `_2026-09-02.xlsx`: Produtos 107 updates; PedidoCompra 80 staging + 9 updates; ContaPagar/Receber 2987 updates de status, **0 parcelas órfãs novas a cancelar** e 0 sem negociação (as correções anteriores seguraram). Constantes de caminho bumpadas nos 3 scripts.

## 2026-09-02 (3)

### Corrigido — 1.158 parcelas "órfãs" (despesa/lucro/imposto marcados como receita) canceladas: Dashboard agora bate 100% com a planilha

- Investigando o resíduo de +R$ 730 da conferência fev→ago: `dup 1916`/`1915` tinham parcelas de **TARIFA BANCARIA** e `dup 1628` de **DARE-ICMS** dentro de negociações `tipo='receita'` — o Dashboard somava como receita recebida.
- Escala real: **1.210 parcelas** cujo `cod_itens_duplicata` não está no export atual, mas a duplicata está (parcela substituída/removida no Connect). 1.157 marcadas como pagas, ~R$ 4 mi, quase todas **despesa em negociação de receita**: `COMPRAS - REVENDA` (873, R$ 3,0 mi), `INDUSTRIALIZAÇÃO` (95), `RETIRADA DE LUCRO FILIPPO` (22, R$ 435k), `DARE-ICMS` (24), `RT` (41), etc. Só 2 linhas de `VENDAS A VISTA` (R$ 11 mil). Resquício de imports antigos.
- Fix: `importar_contas_pagar_receber.py` ganha um passo — para cada duplicata que está no export, **cancela (`status_pago = 2`) as parcelas cujo `cod_itens_duplicata` não está no export**. A planilha é a fonte de verdade. Aplicado: **1.158 parcelas canceladas**, 0 erros.
- Resultado: **conferência fev→ago bate R$ 0,00 em todos os meses** (receita E despesa). **Em Aberto a Pagar e a Receber batem exato com a planilha** (R$ 5.487.019,90 / R$ 3.104.418,35). Receita realizada total no Dashboard: R$ 27,33 mi → **R$ 25,25 mi** (−R$ 2,08 mi de órfãs); Despesa realizada: −R$ 415k.

## 2026-09-02 (2)

### Corrigido — import parava de descartar as ~488 duplicatas "ambíguas": R$ 1,35 mi de receita voltou

- Feedback do usuário (conferência da planilha do Sérgio): as duplicatas que o import pulava por estarem em >1 empresa são **recebimentos reais** — parcelas de datas diferentes do mesmo cliente, ou empresa trocada para acordo de RT com arquiteto. **Não pode sair da soma.**
- Medido: as **402 combinações `(cod_duplicata, tipo)` ambíguas são TODAS receita**, e em **todas** a negociação mais antiga (a que a view `v_financeiro_realizado` usa via `rn=1`) é **MANOELLA** (lote LUCE NERA de 2026-05-07).
- Fix: `importar_contas_pagar_receber.py` deixa de pular e **roteia essas linhas para a negociação MANOELLA/preferida**. Reimportado: **488 transações novas inseridas**, 0 erros.
- Resultado da conferência fev→ago depois disso: **despesa bate exato todos os meses**; **receita bate a menos de R$ 730 no total** (fev +R$ 329,81 na `dup 1916`, mar +R$ 399,73 — 0,009%). Receita realizada total no Dashboard: R$ 25,98 mi → **R$ 27,33 mi**. Em Aberto a Pagar continua exato (R$ 5,49 mi); Em Aberto a Receber R$ 3,11 mi (+R$ 5,4 mil, os 19 abertos ambíguos).
- Pendência menor: `dup 1916` (fev, +R$ 329,81) — conferir linha a linha.

## 2026-09-02

### Corrigido — Em Aberto / fluxo futuro do Dashboard inflado ~R$ 2 mi: import não atualizava `vl_parcela`

- Conferência da planilha ContaPagar/ContaReceber (fev→ago) contra `v_financeiro_realizado`: **despesa realizada bate exato em todos os meses**; **receita realizada R$ 129,8 mil abaixo** (duplicatas ambíguas `ISLIGHT/FOCO + MANOELLA` que o import descarta — decisão pendente); **"Em Aberto (Pagar)" R$ 2.022.644 acima da planilha**, todo concentrado em set–dez/2026.
- Causa: `importar_contas_pagar_receber.py` só sincronizava `status_pago`/`vl_pago`/`dt_pagamento`/`vl_desconto`/`vl_juros` em linha existente — **nunca `vl_parcela` nem `dt_vencimento`**. Duplicata renegociada/corrigida no Connect mantinha o valor antigo em `transacoes`. **`dup 6836`** (4 parcelas em aberto, R$ 550.000 → R$ 55.000 cada — um zero a mais corrigido no Connect) sozinha respondia por R$ 1,98 mi dos R$ 2 mi.
- Fix: o import passa a comparar e atualizar também `vl_parcela`, `dt_vencimento`, `dt_emissao`, `vl_frete`, `vl_ipi`. Reimportado: **3168 updates** (216 corrigem `vl_parcela`, 91 `dt_vencimento`), 0 erros.
- Resultado: fluxo futuro A Pagar (VENCIDO + set/out/nov/dez/2026 + jan/2027) **bate 100%** com a planilha. "Em Aberto (Pagar)" no Dashboard: R$ 7,51 mi → **R$ 5,49 mi**. A Receber ainda −R$ 49 mil = as duplicatas ambíguas.

## 2026-09-01 (3)

### Corrigido — bug de parsing no import de Produtos: ~700 produtos com `custo_total = 0`

- `scripts/importar_produtos_estoque.py` — `to_numeric_br` fazia `.replace(",", ".")` sem tirar o separador de milhar. Na planilha `Produtos__*.xlsx` a coluna `CustoTotal` vem em formato BR ("1.409,76") e o `ValorVenda` em US ("3709.9"), então **todo produto com custo ≥ R$ 1.000 virava "1.409.76" → NaN → 0**. `valor_venda` (sem milhar) importava certo, por isso passou despercebido.
- Fix: se a string tem vírgula é BR (remove '.', troca ',' por '.'); senão assume número já formatado. Só afeta o import de Produtos — os imports de ContaPagar/Receber/PedidoCompra leem números nativos do Excel (`dtype=float64`), sem parsing de string.
- Reimportado: **746 produtos atualizados**, dos quais **695 estavam com `custo_total = 0`**. **Valor de Estoque (Custo)** no banco: R$ 3.960.743 → **R$ 4.273.243** (+R$ 312.500) — bate com o "~R$ 4 mi" que o Vinícius citou na reunião. Corrige também Custo Disponível / Custo em Déficit / MKP no Dashboard de Estoque.
- `estoque_itens` sincronizado pelo trigger.

### Corrigido — Cadastro Lucenera: campo "Preço Custo" em branco ao editar peça/produto

- `PecaForm.tsx` (`src/components/forms/`): produtos que vêm só do import do Connect não têm `produtos.preco_custo` nem `preco_venda` populados — o custo real fica em `custo_total` e a venda em `valor_venda` (o `importar_produtos_estoque.py` não mexe nesses dois de propósito, pra não disparar o trigger `fn_atualizar_preco_venda`). Sem fallback, o campo "Preço Custo (R$)" abria **em branco** na edição, enquanto a venda aparecia (a venda já tinha `valor_venda || preco_venda`).
- Fix: no `form.reset()` da edição, `preco_custo` passa a usar `preco_custo || custo_total || 0` e `preco_venda` passa a usar `preco_venda || valor_venda || 0` — mesmo padrão do `valor_venda`. Para produtos com percentuais de frete/ST/IPI zerados (caso dos importados) não há dupla contagem: o "Custo Total Calc." recalcula igual ao `preco_custo` seed.
- Publicado no Skip 36668 — versão **0.0.80** (`bd5cb48`), QA tudo verde. Submódulo `cadastro-lucenera-b86fe` no git está desatualizado em relação ao Skip (trabalho de SPEC-120 em aberto lá) — sync do git pendente.

## 2026-09-01 (2)

### Revertido — SPEC-126 Escopo 2A: 19 orçamentos de teste cancelados no Supabase real

- Critério do usuário: todo orçamento criado dentro do sistema novo e aprovado é teste (o resto vem do import das planilhas do Connect). Só existiam 22 orçamentos no total — 19 `status='Orçamento Aprovado'` + 3 rascunho.
- Novo `scripts/reverter_orcamentos_teste.py` (dry-run padrão, `--aplicar` grava). O RPC `cancelar_orcamento` não resolvia sozinho: ele só roda a reversão quando `status='aprovado'` literal, e aqui é `'Orçamento Aprovado'`. O script replica os passos do RPC + separação/logística. **Cancela, não apaga** (preserva histórico).
- Aplicado em produção: **19 orçamentos → cancelado** (+19 em `historico_status_orcamentos`); 36 boletos → cancelado (incl. 1 "Pago" + 9 "Remessa Enviada"); 41 `projeto_parcelas` → cancelada (incl. 5 "paga"); 40 `projeto_itens.validado` → false; 32 `estoque_saldos_projeto_item` → cancelado + 30 movimentos 'cancelamento'; 13 reservas de `estoque_itens` liberadas (64 un.); 18 `separacao_itens` estornados; 11 separações → Cancelado; 2 entregas → Cancelado; 6 `entregas_pendentes` removidas. 3 rascunhos intactos.
- Achado: a CHECK `orcamentos_data_inicio_pagamento_check` (NOT VALID, migration 20260814_108) rejeita qualquer UPDATE quando `data_inicio_pagamento` já passou — contornado zerando o campo junto no cancelamento (inócuo num orçamento de teste). 2 orçamentos com data nula/futura foram cancelados na 1ª passada antes de bater na constraint; os outros 17 na 2ª.
- Boletos não têm FK para `negociacoes`/`transacoes`; a "relação bancária" desses orçamentos é a tabela `boletos` (coberta). Dashboard financeiro lê `transacoes` (import), não boletos.
- Pós-reversão: 0 orçamento aprovado no sistema, `vw_necessidade_compra` 232→230 linhas / Gasto Futuro R$811k→R$802k.

## 2026-09-01

### Adicionado — SPEC-126: Escopos 5, 6, 7 (parcial) implementados + migration do Escopo 3 redigida

- **Escopo 5 (Estoque)** — `dashboard-lucenera-b02z85wa3`: cards "De Cliente / Reservado (Custo)" e "(Venda)" + "Showroom (Venda)" na tela de Estoque, com aviso de que "Disponível" já inclui o Showroom. `computeKpisEstoque` + helper `reservadoQtd` (`max(0, estoque_total + estoque_showroom − estoque_disponivel)`) — cálculo client-side, sem migration; a `v_estoque_produtos` só precisará mudar se quiserem a view como fonte de verdade.
- **Escopo 6 (Investimento)** — `cash-flow.ts`: `filterByDescGrupo` + `distinctGrupos` (auto-descobre os grupos). `ContasPagarFoco.tsx`: Select "Grupo" no cabeçalho que filtra KPIs, gráficos e a planilha do fim da aba — pega "INVESTIMENTO" sem hardcode.
- **Escopo 7** — cards "Em Aberto (Pagar/Receber)" ganharam legenda visível "Total acumulado — não muda com o filtro de período". Verificado no Supabase real que `vw_necessidade_compra` está populada (232 produtos, card ~R$ 811 mil): o "não tá pegando" do Vinícius é na tela de Compras / no Excel dele, não no dashboard.
- **Escopo 3 — migration redigida, NÃO aplicada**: `supabase/db/migrations/20260901_129_spec126_natureza_por_codigo_connect/001_natureza_allowlist.sql`. Troca o `CASE` de `natureza` em `v_financeiro_realizado` (`ILIKE '%FILIPPO%'/'%MANOELLA%'` → allowlist de 9 `codigo_connect` de retirada/lucro distribuído). Com isso `ESCOLA` (~R$92k) e `CLUBE MAIS VIAGENS` (~R$50k) deixam de contar como lucro. Aguarda Vinícius confirmar o balde dessas contas antes do apply.
- QA local do submódulo: `tsc --noEmit`, `oxlint src`, `vite build` limpos.
- **PUBLICADO no Skip 41135 (2026-09-01)**: a tela não tinha mudado porque o Skip tem árvore de arquivos própria, não lê do submódulo git. Conferido que o Skip estava em sincronia; escritos os 10 arquivos; `apply_changes` (QA setup/static/build/integrations/test tudo verde) → versão **0.0.32** (`c5a8441`); `publish` → `dashboard-empresa-40d7d.goskip.app`. Commits git (submódulo `d79d704`, central `f2df5f0`) batem com o Skip.
- Continuam bloqueados: Escopo 2 (marca de origem — toca no import da Connect), Escopo 4 (Receita de Serviço / Representação — feature nova, vira SPEC própria), lista de "custo fixo" do Ponto de Equilíbrio (Filippo).

## 2026-08-31 (5)

### Adicionado — SPEC-126: Dashboard Financeiro 100% (reunião Vinícius 31/08) — Escopo 1 (Filtro por Data) implementado

- **SPEC-126 criada** (`03-Projeto/Planos de Ação/SPECs/SPEC-126_...md`), guarda-chuva das duas reuniões de 31/08 sobre Contas a Receber/Pagar. Escopos: (1) filtro por data — LIBERADO e feito; (2) separar dado de teste; (3) classificação `natureza` na view; (4) receita de serviço/representação; (5) bloco "De Cliente/Reservado" no Estoque; (6) recorte "Investimento"; (7) ajustes menores. Escopos 2–7 dependem de decisão do Vinícius.
- **Escopo 1 — Filtro por Data** implementado no submódulo `dashboard-lucenera-b02z85wa3` (local; **não publicado no Skip, não commitado no submódulo**). Substitui os Selects Ano/Mês por intervalo livre De/Até + toggle "por data de pagamento / por vencimento" + presets. `cash-flow.ts`: `filterFinanceiro` passa a receber `Periodo { de, ate, campo }`; novos `rangePreset`/`periodoAnterior`; `distinctAnos`/`MESES` removidos. Novo `src/components/PeriodFilter.tsx` (Popover + Calendar range + ToggleGroup). "Em Aberto (Pagar/Receber)" continua sendo total acumulado; "Previsto por vencimento" passa a respeitar o intervalo pela coluna de vencimento.
- **"Planilha no fim de cada aba"** — `PlanilhaTabela.tsx` (tabela genérica ordenável + export CSV `;`/BOM do conjunto filtrado inteiro, render limitado a 500 linhas) + `colunasFinanceiro.ts`. Adicionada em Fluxo de Caixa, Recebimentos, Pagamentos (com `cod_duplicata` como chave de conferência linha a linha com o Connect) e Estoque. `FinanceiroRow`/`COLUNAS` ganham `id`, `dt_emissao`, `cod_duplicata`; helper `formatarData` em `lib/utils.ts`.
- Achado durante a análise (dados reais do Supabase): as contas `DESP. OPERAC. FILIPPO/MANOELLA` já classificam certo como `despesa_operacional`. O problema de `natureza` é o `ILIKE '%FILIPPO%'/'%MANOELLA%'` varrer `ESCOLA` (R$91k) e `CLUBE MAIS VIAGENS` (R$49k) para `distribuicao_lucro`. Tratado no Escopo 3, depende de confirmação do Vinícius conta a conta.
- QA local do submódulo: `tsc --noEmit`, `oxlint src` e `vite build` limpos.
- Repositórios que precisam receber commit depois: submódulo `dashboard-lucenera-b02z85wa3` (código do Escopo 1) e o central (SPEC-126 + este CHANGELOG + ponteiro do submódulo após publicar).

## 2026-08-31 (4)

### Importado — ciclo de sincronização Connect (ContaPagar/ContaReceber, PedidoCompra, Produtos/Estoque)

- Usuário disponibilizou 4 planilhas novas (`ContaPagar_2026-08-31.xlsx`, `ContaReceber_2026-08-31.xlsx`, `PedidoCompra_2026-08-31.xlsx`, `Produtos__2026-08-31.xlsx`) e pediu pra atualizar o banco. Mesmo ciclo já rodado antes (26/08, 24/08, 17/08 etc.) — constantes de caminho atualizadas nos 3 scripts (`importar_contas_pagar_receber.py`, `importar_pedido_compra.py`, `importar_produtos_estoque.py`), `--dry-run` conferido em cada um (números batendo com a execução real) antes da gravação.
- **ContaPagar/ContaReceber**: 36 negociações novas (empresa MANOELLA, mapeamento LUCE NERA confirmado inalterado), 92 transações novas, 2.977 atualizadas (status/pagamento), 14.254 já sincronizadas, 0 erros. 488 linhas com `(cod_duplicata, tipo)` ambíguo entre empresas puladas por desenho (mesmo padrão de todos os ciclos anteriores).
- **PedidoCompra**: 14 pedidos novos, 8 atualizados, 42 inalterados, 0 erros. `staging_pedido_compra` recarregada (81 linhas).
- **Produtos/Estoque**: 202 produtos atualizados (estoque/custo/valor de venda/lucro), 4.150 já sincronizados, 0 erros. 130 `CodProduto` da planilha sem match no banco (produtos ainda não cadastrados, fora do escopo do script — só atualiza existentes).
- `estoque_itens` sincronizado automaticamente via trigger `fn_sync_estoque_itens_from_produtos`, sem ação manual.

## 2026-08-31 (3)

### Alterado — SPEC-125: /admin passa a usar usuario + senha

- Migration `20260831_128` aplicada no Supabase real: `showroom_config` agora guarda
  `admin_user` = `Lucenera` e `admin_pass_hash` (bcrypt de `Lucenera123`, via `extensions.crypt`).
  Nova RPC `showroom_login(p_user,p_senha)`; `showroom_vincular_peca`/`showroom_desvincular_peca`
  recriadas com assinatura `(p_user, p_senha, …)`; helper `showroom_cred_ok` revogado de anon.
  Rodado `NOTIFY pgrst, 'reload schema'`. Login testado ao vivo no /admin.
- Frontend: `src/pages/Admin.tsx` com form Usuario/Senha (credencial em sessionStorage,
  validada no submit via `showroom_login`); `src/services/curadoria.ts` passa `{user,senha}`.

## 2026-08-31 (2)

### Adicionado — SPEC-125: 19 pecas publicadas + tela de curadoria /admin

- **Migrations `20260831_126` e `20260831_127` APLICADAS no Supabase real** (Management API, com autorizacao explicita do usuario por acao). 126: `produtos.imagem_showroom_url` + view anon `vw_showroom_publico` (whitelist, sem `security_invoker`) + bucket publico `showroom-lucenera`. 127: `showroom_import_pecas` (staging das 167 pecas do PPT), `showroom_config` (PIN), RPCs `showroom_vincular_peca`/`showroom_desvincular_peca`/`showroom_buscar_produto` (SECURITY DEFINER, gated por PIN). RLS de `produtos` (SPEC-069/087) intacta.
- **19 pecas publicadas na vitrine** (`aplicar --semear-estoque`): upload da foto pro bucket + `imagem_showroom_url` + `estoque_showroom` (qtd da lista ou 1). Matcher reescrito brand-aware; auto-confirma so vencedor claro; revisao manual tirou 4 duvidosos.
- **15 pecas do PPT nao encontradas** no catalogo (MAY DAY, HERACLEUM/Moooi, ECLISSE/Artemide, PH5, abajures Cris Bertolucci, etc.) — resolver na tela `/admin`.
- **Tela `/admin`** no site (rota nao listada, PIN): lista peca do PPT nao vinculada com foto + candidatos (1 clique) + busca de produto; "Vincular" grava no produto via RPC; "Desfazer" por peca. Preco no site: `valor_venda` quando > 0, senao "Sob consulta".
- **PIN da /admin ainda e placeholder** `TROCAR-ESTE-PIN` — usuario vai definir via `update showroom_config`. Ao fim da curadoria, `revoke execute` das RPCs `showroom_*` de `anon`.
- Pendente: ~148 pecas a vincular na `/admin`; criar projeto Skip + env + publish; `git push` do central; preencher `src/lib/contato.ts`.

## 2026-08-31

### Adicionado — SPEC-125: site publico do Showroom Lucenera (vitrine de pronta entrega) — implementado, nao publicado

- **SPEC-125 criada** (`03-Projeto/Planos de Acao/SPECs/SPEC-125_...md`) e **sistema novo implementado** em `04-Sistemas/showroom-qtq8er2dk` (submodule novo do repo `github.com/pedrolalala/showroom-qtq8er2dk`). Site publico, sem login, so leitura: Vitrine (`/`), Detalhe da peca (`/peca/:codigo`), Visite o showroom (`/showroom`), 404. Busca + filtros Marca/Categoria + ordenacao + scroll infinito. Preco = `valor_venda` sempre (R$ 0,00 quando nao cadastrado). Identidade Lucenera (laranja/navy/Inter). `pnpm install` + `tsc` + `oxlint` + `vite build` + `vite preview` limpos.
- **Migration REDIGIDA, nao aplicada**: `supabase/db/migrations/20260831_126_spec125_showroom_publico/` — `produtos.imagem_showroom_url text`, view `vw_showroom_publico` (whitelist de colunas, sem `security_invoker`), `GRANT SELECT ... TO anon`, bucket de Storage publico `showroom-lucenera`. `produtos` NAO ganha policy `anon` (SPEC-069/087 intactas). Impacto no banco: 1 coluna nullable + 1 view + 1 bucket; nenhuma RPC/RLS/trigger existente alterada.
- **Script `scripts/importar_fotos_showroom.py`** (extrair/match/aplicar). Le `.odp`/`.pptx`. Rodado no arquivo real `01-Documento/01 - Planilhas/LISTA DECORATIVOS DISPONIVEIS - SHOWROOM.odp` (268 MB, gitignored): 189 slides, 167 com foto; `match` cruzou com 4 726 produtos, ~76 candidatos. CSV de revisao gerado fora do repo.
- **Pendente (ver SPEC-125 Pendencias):** aprovar+aplicar a migration; revisar o CSV de match; rodar `aplicar`; criar projeto Skip + env vars + publish; preencher contato real; corrigir cobertura de `estoque_showroom` (so 266 produtos > 0 hoje). Nenhum commit/push feito nos repos ainda.
- Repos que precisam de commit depois da aprovacao: `showroom-qtq8er2dk` (codigo do sistema) e o central (ponteiro do submodule + `.gitmodules` + SPEC + migration + script + CHANGELOG).

## 2026-08-28

### Corrigido — SPEC-123: itens 1-3 da auditoria de performance de carregamento

- Auditoria de código + banco (sem mudar nada ainda) identificou 3 causas raiz da lentidão relatada: telas de alto volume buscando a tabela inteira sem paginação, checagem de permissão duplicada em toda navegação, e zero code-splitting em 9 dos 10 sistemas (índices do banco já estavam bons — não era o problema).
- **Item 1 (code-splitting por rota)**: aplicado nos 9 sistemas que ainda não tinham (RH já tinha e serviu de referência) — Hub, CRM, Cadastro, Compras, Logística, Admin Bancária, Orçamentos, Dashboard Financeiro, Separação Parcial. `lazy()` + `<Suspense>`, sem mudança de comportamento visível.
- **Item 2**: `.limit(1000)` adicionado em `Arquitetos.tsx` (CRM) — única tela que buscava a tabela inteira sem nenhum teto.
- **Item 3 (cache de `usuarios.role`)**: escopo revisado ao vivo — `useSistemasPermitidos.ts` (SPEC-120) é propositalmente autocontido (não depende do formato de `useAuth()` de cada sistema), então em vez de consolidar os hooks, foi criado um cache leve em memória (`src/lib/usuario-role-cache.ts`) compartilhado só onde a mesma query realmente se repetia — CRM e RH. Aplicado nos outros 8 sistemas (exceto Hub) só no `useSistemasPermitidos.ts`, já que os demais `use-auth.tsx` não duplicavam essa query.
- Todos os 9-10 sistemas passaram no QA automático do Skip (build/lint/test); testado ao vivo em Hub, CRM, Cadastro e Orçamentos sem regressão.
- Itens 4-6 (paginação real em Clientes/Peças/Projetos) continuam só diagnosticados — exigem SPEC própria antes de implementar (risco maior, mexem em filtros dinâmicos existentes).

## 2026-08-27 (2)

### Corrigido — SPEC-122: busca de peças não eliminava por palavra + ordenação por coluna em Peças e Produtos

- Origem: reunião Mariane+Pedro 27/08/2026 — "cada palavra deve filtrar, ou seja, eliminar opções". Medido antes do fix: buscar "KPF12" ou "dicroica geo10 6w" (a reunião tinha "Geo10", transcrição de fala pra "GU10") retornava 4356 de 4726 produtos ativos na RPC `buscar_produtos_fuzzy` — o fallback `word_similarity > 0.3` deixava passar quase qualquer produto, mesmo sem conter a palavra digitada.
- RPC corrigida em produção (migration `20260827_125_spec122_busca_elimina_por_palavra`, 2 arquivos): eliminação agora exige substring literal (normalizada por acento/caixa) em vez de similaridade — `KPF12` → 11 resultados, `dicroica gu10 6w` → 7. Um bug de acento (quebrava "lâmpada" com acento) foi achado e corrigido no mesmo dia, ainda dentro desta migration. Testado ao vivo nos dois consumidores da RPC (Orçamentos → Buscar Produtos, Cadastro → Peças e Produtos/"Consultar Produtos"), sem regressão.
- Ordenação por coluna adicionada em Peças e Produtos (Cadastro, Skip 36668, v0.0.77) — mesmo padrão de cabeçalhos clicáveis já em produção em Orçamentos → Buscar Produtos. Testado ao vivo.
- Item de "Fora de Linha" da mesma reunião fica fora desta rodada por decisão do usuário (dado ainda não é exportado pelo Connect).

## 2026-08-27

### Corrigido — PDF do orçamento: dados do cliente no cabeçalho (SPEC-084) e valores de devolução saindo positivos

- SPEC-084 (bloco NOME/ENDEREÇO/CEP/TEL no cabeçalho do cliente, sem CPF) já existia no código do `generate-report` mas nunca tinha sido publicada — deployada direto em produção (`supabase functions deploy`) e verificada num PDF real.
- Devolução: o sistema já mostrava o valor corretamente negativo, mas o PDF exportava tudo positivo — lógica `signed()` (nega subtotal, total e cada item quando `natureza_operacao = 'devolucao'`, sem alterar o valor armazenado nem o preço unitário) reaplicada e redeployada.
- Verificado ao vivo com um orçamento de devolução real (ORC-0028), nos dois formatos de PDF (cliente e interno): SubTotal, cada item e Valor Total saem negativos; cabeçalho do cliente sem CPF.

## 2026-08-26 (3)

### Corrigido — RBAC: acesso indevido (Mariane) e falta de permissão de aprovar (Pedro)

- Mariane tinha acesso amplo indevido a sistemas/módulos por um papel legado (`gerente`) coexistindo com o papel novo e mais restrito dela — `hub_sistemas_permitidos` faz UNION entre todos os papeis do usuário, então o papel antigo vazava acesso que o novo não devia dar. Removida a atribuição do papel legado, confirmado que o acesso dela ficou só o pretendido e que não afetou o acesso de Lana (que tem `Necessidade de Compra` por outro papel).
- Pedro (e por extensão Vinicius/Filippo, que têm o mesmo papel legado `admin`) não conseguia mudar status de pedidos na Central de Solicitações — a ação `aprovar` só tinha sido concedida ao papel `admin_geral`, não ao `admin` legado que eles de fato têm. Corrigido concedendo `aprovar` também ao papel `admin`; testado ao vivo (dropdown de status apareceu e funcionou).

### Adicionado — histórico de SPECs concluídas na Central de Solicitações

- A pedido do usuário ("meu chefe conseguir ver tudo"), importadas as ~85 SPECs já concluídas do repositório como registros na coluna "Concluído" do board da Central de Solicitações, com descrição resumida e amigável (reescrita numa segunda passada depois do usuário pedir "mais simples" na primeira versão, que estava técnica demais).

## 2026-08-26 (2)

### Adicionado — SPEC-121: Central de Solicitações (11º sistema), triagem de bugs/pedidos por IA (Gemini)

- Sistema novo (Skip 53113, `central-de-solicitacoes-cc2ec.goskip.app`), integrado ao Supabase compartilhado e ao `SystemSwitcher` de todos os 10 sistemas existentes sem precisar editar nenhum deles — cadastro de uma linha nova em `public.systems` basta.
- Toda a equipe pode abrir um pedido (bug ou alteração); uma Edge Function (`classificar_solicitacao`) chama o Gemini (`gemini-3.6-flash`) e classifica automaticamente como estrutural ou pontual, com justificativa — só uma etiqueta informativa, não dispara mais nada sozinha (decisão explícita do usuário: sistema deliberadamente não é "100% automático", é só um lugar pra reportar e estruturar visualmente).
- Board (kanban por status) com filtros por classificação e tipo. Virar SPEC continua sendo manual — usuário aponta pra um pedido específico e a IA (eu) gera o arquivo a partir da descrição já estruturada, sem precisar reexplicar em texto corrido.
- RBAC: todo papel (12 no total) ganhou criar+visualizar no sistema novo; `admin_geral` ganhou também aprovar (controla mudança de status no board).
- **Achado corrigido durante a implementação**: conta `pedrollaghi@gmail.com` (viewer) nunca tinha sido migrada pra `usuario_papeis` — ficava sem nenhum papel, e por isso `hub_pode_executar` negava acesso a QUALQUER sistema pra essa conta, não só a nova. Corrigido inserindo o papel `viewer`.
- Bloqueio conhecido de `.env` corrompido (linha com chave vazia) voltou a aparecer no deploy da Edge Function via CLI — contornado com o mesmo mv temporário já usado em rodadas anteriores.
- Modelo Gemini `gemini-2.0-flash` (usado no desenho inicial do prompt) foi descontinuado pela Google durante a implementação — trocado por `gemini-3.6-flash`, testado e confirmado funcionando.
- Testado ponta a ponta em produção (criar pedido → IA classifica → aparece no board) antes de publicar; pedido de teste removido depois.

## 2026-08-26

### Importado — ciclo de sincronização Connect (ContaPagar/ContaReceber, PedidoCompra, Produtos/Estoque)

- Usuário disponibilizou 4 planilhas novas (`ContaPagar_2026-08-26.xlsx`, `ContaReceber_2026-08-26.xlsx`, `PedidoCompra_2026-08-26.xlsx`, `Produtos__2026-08-26.xlsx`) e pediu pra atualizar o banco. Mesmo ciclo já rodado antes (24/08, 17/08 etc.) — constantes de caminho atualizadas nos 3 scripts (`importar_contas_pagar_receber.py`, `importar_pedido_compra.py`, `importar_produtos_estoque.py`), `--dry-run` conferido em cada um (números batendo com a execução real) antes da gravação.
- **ContaPagar/ContaReceber**: 70 negociações novas (empresa MANOELLA, mapeamento LUCE NERA confirmado inalterado), 99 transações novas, 2.944 atualizadas (status/pagamento), 14.189 já sincronizadas, 0 erros. 488 linhas com `(cod_duplicata, tipo)` ambíguo entre empresas puladas por desenho (mesmo padrão de todos os ciclos anteriores).
- **PedidoCompra**: 3 pedidos novos, 7 atualizados, 44 inalterados, 0 erros. `staging_pedido_compra` recarregada (71 linhas).
- **Produtos/Estoque**: 148 produtos atualizados (estoque/custo/valor de venda/lucro), 4.204 já sincronizados, 0 erros. 128 `CodProduto` da planilha sem match no banco (produtos ainda não cadastrados, fora do escopo do script — só atualiza existentes).
- `estoque_itens` sincronizado automaticamente via trigger `fn_sync_estoque_itens_from_produtos`, sem ação manual.

## 2026-08-24 (6)

### Corrigido — resumo do projeto em Novo Orçamento mostrava "Arquiteto: Não preenchido" mesmo com arquiteto vinculado no CRM

- Reproduzido ao vivo no navegador (Chrome): criado projeto de teste no CRM com arquiteto (AFONSO ALMEIDA) vinculado via `replace_projeto_arquitetos` (confirmado no banco: `projeto_arquitetos` com percentual 100%) — ao selecionar esse projeto em Novo Orçamento, o quadro-resumo dizia "ARQUITETO: Não preenchido", mas o campo real "Arquiteto / Profissional" do formulário **já vinha preenchido corretamente**. Bug era só de exibição no resumo, não na lógica de preenchimento nem no salvamento.
- Causa raiz: `handleProjectSelect` (`BudgetFormPage.tsx`) monta o quadro-resumo lendo só `projeto['Nome Arquiteto']` (texto legado, de import antigo do Connect) — projetos criados pelo CRM depois da SPEC-077 (divisão de arquitetos em `projeto_arquitetos`) nunca preenchem esse campo legado, então o resumo sempre mostrava "Não preenchido" mesmo quando o vínculo real existia e era aplicado certo no formulário.
- Corrigidos os 3 caminhos de preenchimento (`projeto_arquitetos`, `arquiteto_id` singular legado, busca por nome) para sincronizar `arquiteto_nome` do resumo com o(s) arquiteto(s) de fato aplicado(s) ao formulário.
- Publicado em produção (Orçamentos, Skip 32554, v0.0.357) e reconfirmado ao vivo no navegador após o deploy.
- Projeto de teste criado durante a investigação: CRM "26.351 — TESTE ARQUITETO AUTOFILL NAO USAR" — pendente de exclusão manual.

## 2026-08-24 (5)

### Adicionado — SPEC-120: menu lateral de navegação entre sistemas (implementado e publicado nos 10 sistemas)

- Barra retrátil fixa no canto direito, presente em todos os sistemas do Hub (Hub + 9 satélites), listando só os sistemas que o usuário logado tem permissão de acessar (`hub_sistemas_permitidos`, mesma fonte já usada pelo Hub) — Ubiqua sempre excluída (fora do escopo desta SPEC) e cada sistema não lista a si mesmo.
- `useSistemasPermitidos(currentSlug)` (hook) e `SystemSwitcher.tsx` (componente) — versão **autocontida**: resolve o próprio usuário logado via `supabase.auth`, sem depender do formato de `useAuth` de cada um dos 10 repositórios (que variava bastante). Clique reaproveita `redirectWithCode` (SSO, sem login duplicado).
- **Achado corrigido durante a implementação**: `redirectWithCode` (`cross-system-auth.ts`) já tinha divergido entre sistemas — Orçamentos/Admin Bancária/CRM tinham evoluído pra uma versão melhor (mesma aba por padrão, `sistema_origem` correto por sistema); Hub e os demais 6 satélites ainda tinham `sistema_origem: 'hub'` fixo (errado quando o clique parte de outro sistema) e 5 deles abriam em nova aba. Padronizados os 10 para a versão mais evoluída.
- **Achado crítico evitado antes de publicar**: o `use-auth.tsx` real do RH no Skip já tinha a checagem `hasAccess`/`hub_pode_executar` (SPEC-069) que o checkout local (git) do submodule não tinha — publicar em cima da edição feita sobre o checkout desatualizado teria apagado essa proteção de acesso em produção. Reconstruída a edição em cima do conteúdo real do Skip antes de publicar.
- RH ganhou `cross-system-auth.ts` (não existia) e passou a consumir `?sso_code` no bootstrap de autenticação — único sistema do Hub que ainda não era destino SSO válido.
- Publicado em produção nos 10 sistemas (Hub, Orçamentos, Admin Bancária, CRM, Necessidade de Compra, Logística, Cadastro, RH, Dashboard Financeiro satélite, Separação Parcial) com QA do Skip limpo em todos e autorização explícita do usuário.
- **Pendente**: teste manual ao vivo do golden path (trocar de sistema pelo menu, chegar autenticado sem login) ainda não foi feito; `AI_DB_CONTEXT.md` de RH e `supabase/db/domains/hub_ti.md` não atualizados nesta rodada.

## 2026-08-24 (4)

### Corrigido — devolução não aparecia como negativo (sistema + PDF) e "Enviar para o Cliente" nunca abria o e-mail com PDF em produção

- **Sinal negativo em devolução**: `orcamentos.valor_total` é sempre salvo positivo no banco (a RPC de aprovação exige `> 0` mesmo para devolução — só ela aplica o sinal negativo ao criar a parcela de crédito). O sistema Orçamentos mostrava esse valor cru (positivo) em todas as telas, mesmo pra devolução, o que confundia — parecia cobrança, não crédito. Criado `getDisplayValorTotal()` em `src/lib/budget-status.ts` (nova, aplica `-Math.abs()` quando `natureza_operacao === 'devolucao'`, exibição apenas, sem alterar o dado salvo) e aplicado em: lista principal, rascunhos, abas de aprovação (cliente/equipe/financeiro), detalhe de orçamentos do projeto, formulário de criação/edição (subtotal, total, subtotal por item) e no PDF gerado (`generate-report`, subtotal por item, subtotal geral, valor total — preço unitário continua positivo, é o preço de referência do produto).
- **Achado real durante a investigação**: o botão "Enviar para o Cliente" mostrava "orçamento enviado" mas nunca abria o `mailto:` nem baixava o PDF automaticamente. Causa raiz — a feature (SPEC-067, implementada e commitada no git local desde 06/08) **nunca tinha sido publicada no Skip**: a produção rodava uma versão de `BudgetTableRow.tsx` anterior à SPEC-067, sem o import nem a chamada de `sendInitialBudgetPdfAndEmail`; o próprio arquivo `src/lib/envio-inicial-cliente.ts` nem existia no working tree do Skip (confirmado pelo erro de build `Could not load src/lib/envio-inicial-cliente` na primeira tentativa de publicar). Não foi preciso corrigir nenhum código — só sincronizar Skip com o que já estava certo no git local (mesma classe de gap já documentada antes: "SPEC 'Realizado' não prova que está no ar").
- Publicado em produção: Orçamentos (Skip 32554, v0.0.355) — `gestao-financeira-clone-544cb.goskip.app`.
- PDF (`generate-report`, mesma correção de sinal + o bloco de observações da SPEC-118, já implementado antes) segue **pendente de deploy** — a Supabase CLI não tem sessão de login válida neste ambiente (401 Unauthorized), precisa de `supabase login` interativo do usuário.

### Adicionado — cadastro de usuário em lote na Central Lucenera (Hub)

- Pedido do usuário: criar várias contas de login de uma vez (ex.: onboarding de vários funcionários), em vez de repetir o dialog "Novo Usuário" um por um.
- `UsersTab.tsx`: novo botão "Novo Usuário em Lote" ao lado do já existente — textarea com uma linha por pessoa (`Nome, email@dominio.com`), senha e papel de acesso compartilhados por todo o lote, chama a RPC `criar_usuario` (já existente, sem migration) sequencialmente por linha. Falhas parciais (ex.: email já cadastrado) não travam o lote inteiro — toast lista os primeiros 5 erros e a lista é substituída só pelas linhas que falharam, pra corrigir e reenviar.
- Decisão do usuário: acesso por sistema (`user_system_access`) continua sendo concedido manualmente, um usuário/sistema por vez, na aba "Acesso a Sistemas" já existente — este formulário só cria a conta de login.
- Publicado em produção: Central Lucenera (Skip 37750, v0.0.40) — `central-lucenera-dashboard-1c9ba.goskip.app`. Testado pelo usuário no preview antes de publicar.

## 2026-08-24 (3)

### Corrigido — snapshot local de `aprovar_orcamento_financeiro` estava desatualizado

- Ao verificar se a devolução do ORC-0028 realmente mexeu no estoque (pedido do usuário), a RPC ao vivo em produção (lida via `pg_get_functiondef` no SQL Editor) confirmou o branch de devolução do SPEC-071 — mas o snapshot local `supabase/db/current/03_functions.sql` mostrava uma versão bem mais antiga da função, **sem nenhum branch de devolução**, tratando todo orçamento como venda (criaria `projeto_itens` positivos e reservaria estoque, nunca chamaria `registrar_devolucao_projeto_item`). Se alguém confiasse nesse snapshot pra entender o comportamento do sistema, chegaria a uma conclusão errada.
- Snapshot sincronizado com a versão real de produção: inclui o branch `natureza_operacao = 'devolucao'` (SPEC-071), a checagem de permissão via `hub_pode_executar` (SPEC-069, substituiu o check antigo por `usuarios.role`), e o ramo de venda com o modelo de reserva por `estoque_saldos_projeto_item`/`estoque_movimentos_projeto_item` (mais recente que o antigo `estoque_itens.quantidade_reservada` direto).
- Nenhuma mudança de comportamento em produção — só o arquivo de referência local foi corrigido pra não descrever um comportamento que o banco real não tem mais.

## 2026-08-24 (2)

### Corrigido — regressão SPEC-108 quebrava aprovação de todo orçamento de devolução desde 15/08

- Teste ao vivo do fluxo de devolução (ORC-0028) travou na aprovação financeira: `Orçamento de devolução possui item sem venda de origem vinculada`, mesmo depois de vincular os itens via "Buscar Venda de Origem" e salvar — o vínculo continuava `NULL` no banco.
- Causa raiz: a migration `20260815_116` (SPEC-108, trava de valor/produto pra admin) reescreveu `replace_orcamento_itens` via `CREATE OR REPLACE FUNCTION` e esqueceu a coluna `projeto_item_origem_id` (SPEC-071, `20260807_089`) — tanto no `INSERT` quanto no `SELECT` que lê o jsonb de entrada. Essa RPC faz DELETE+INSERT de *todos* os itens a cada save, então qualquer orçamento de devolução editado desde 15/08 perdia o vínculo com a venda de origem silenciosamente, sem erro nenhum ao salvar — só na hora de aprovar (ou nunca, se ninguém reparasse).
- Fix (`supabase/db/migrations/20260824_123_fix_replace_orcamento_itens_origem_id/001_fix_replace_orcamento_itens_origem_id.sql`): mesma função, mesma trava de admin da SPEC-108 preservada, só devolvendo `projeto_item_origem_id` à lista de colunas.
- **Aplicado direto em produção via SQL Editor do Supabase Dashboard** (não pelo `psql`/CLI de costume) — o host direto do Postgres (`db.<ref>.supabase.co`) só tem registro DNS IPv6 e o ambiente de execução não tem rota IPv6, então a conexão direta falha com "Network is unreachable"/"could not translate host name". A API REST (host sem `db.`) funciona normal via IPv4, mas a SQL Editor via navegador (sessão já autenticada do usuário) foi o caminho viável pra rodar DDL/`CREATE OR REPLACE FUNCTION` desta vez.
- Verificado ao vivo de ponta a ponta: refeito o vínculo dos 3 itens de ORC-0028 (deletados os 3 itens órfãos, re-adicionados via "Buscar Venda de Origem"), salvo, e reenviado pelo fluxo completo (Aprovar Manualmente → Aprovação da Equipe → Aprovar e Enviar ao Financeiro → Aprovar financeiramente). Aprovação financeira concluída sem erro: 1 parcela + 1 boleto gerados.
- **Achado colateral confirmado, não é bug**: editar itens de um orçamento em revisão financeira reseta o status pra "Enviado para o Cliente" (trigger existente que reinicia o ciclo de aprovação quando os itens mudam) — exige reaprovação completa do zero, como aconteceu aqui.

## 2026-08-24

### Importado — ciclo de sincronização Connect (ContaPagar/ContaReceber, PedidoCompra, Produtos/Estoque)

- Usuário disponibilizou 4 planilhas novas (`ContaPagar_2026-08-24.xlsx`, `ContaReceber_2026-08-24.xlsx`, `PedidoCompra_2026-08-24.xlsx`, `Produtos__2026-08-24.xlsx`) e pediu pra atualizar o banco, lembrando explicitamente do mapeamento permanente LUCE NERA = MANOELLA e para não duplicar dado (só atualizar o que já existe). Mesmo ciclo já rodado antes (07/08, 17/08 etc.) — constantes de caminho atualizadas nos 3 scripts (`importar_contas_pagar_receber.py`, `importar_pedido_compra.py`, `importar_produtos_estoque.py`), `--dry-run` conferido em cada um (números batendo com a execução real) antes da gravação.
- **ContaPagar/ContaReceber**: 74 negociações novas (empresa MANOELLA, mapeamento LUCE NERA confirmado inalterado), 146 transações novas, 2.947 atualizadas (status/pagamento), 14.040 já sincronizadas, 0 erros. 488 linhas com `(cod_duplicata, tipo)` ambíguo entre empresas puladas por desenho (mesmo padrão de todos os ciclos anteriores).
- **PedidoCompra**: 9 pedidos novos, 8 atualizados, 41 inalterados, 0 erros. `staging_pedido_compra` recarregada (75 linhas).
- **Produtos/Estoque**: 750 produtos atualizados (estoque/custo/valor de venda/lucro), 3.602 já sincronizados, 0 erros. 124 `CodProduto` da planilha sem match no banco (produtos ainda não cadastrados, fora do escopo do script — só atualiza existentes).
- `estoque_itens` sincronizado automaticamente via trigger `fn_sync_estoque_itens_from_produtos`, sem ação manual.

## 2026-08-17 (5)

### Importado — ciclo de sincronização Connect (ContaPagar/ContaReceber, PedidoCompra, Produtos/Estoque)

- Usuário disponibilizou 4 planilhas novas (`ContaPagar_2026-08-17.xlsx`, `ContaReceber_2026-08-17.xlsx`, `PedidoCompra_2026-08-17.xlsx`, `Produtos__2026-08-17.xlsx`) e pediu pra atualizar o banco. Mesmo ciclo já rodado antes (22/07, 23/07, 08/07) — constantes de caminho hardcoded nos 3 scripts (`importar_contas_pagar_receber.py`, `importar_pedido_compra.py`, `importar_produtos_estoque.py`) atualizadas antes da execução, `--dry-run` conferido em cada um antes da gravação real.
- **Achado bloqueante — "LUCE NERA" é a MANOELLA, não uma 4ª empresa**: o script de ContaPagar/ContaReceber usava uma empresa separada em `empresas` chamada "LUCE NERA" como placeholder pra duplicatas genuinamente novas sem empresa clara (decisão de 2026-07-15, quando isso ainda não estava esclarecido). Essa linha foi removida/consolidada em algum momento sem passar por este changelog, e o `EMPRESA_LUCE_NERA_ID` hardcoded ficou órfão — rodagem real travou com `insert or update on table "negociacoes" violates foreign key constraint`. Usuário esclareceu em chat (2026-08-17): **"LUCE NERA" é só como a empresa MANOELLA está identificada no banco de dados do sistema legado Connect — não é uma 4ª empresa, é a MANOELLA mesmo, permanentemente.** `EMPRESA_LUCE_NERA_ID` do script corrigido pra apontar direto pra MANOELLA (`9c877812-20e9-452c-bc65-5a542f67ff94`) e documentado no código pra nenhum import futuro tropeçar nisso de novo. Verificado após rerun: as 106 negociações novas foram criadas sob MANOELLA corretamente.
- **ContaPagar/ContaReceber**: 106 negociações novas (empresa MANOELLA), 197 transações novas, 3.035 atualizadas (status/pagamento), 13.757 já sincronizadas, 0 erros. 488 linhas com `(cod_duplicata, tipo)` ambíguo entre empresas puladas por desenho (mesmo padrão de todos os ciclos anteriores).
- **PedidoCompra**: 18 pedidos novos, 6 atualizados, 45 inalterados, 0 erros. `staging_pedido_compra` recarregada (92 linhas).
- **Produtos/Estoque**: 559 produtos atualizados (estoque/custo/valor de venda/lucro), 3.793 já sincronizados, 0 erros. 86 `CodProduto` da planilha sem match no banco (produtos ainda não cadastrados, fora do escopo do script — só atualiza existentes).
- `estoque_itens` sincronizado automaticamente via trigger `fn_sync_estoque_itens_from_produtos`, sem ação manual.

## 2026-08-17 (4)

### Corrigido — RH: não era possível editar salário de nenhum funcionário

- Usuário reportou erro ao tentar alterar o salário do Pedro: `column "salario_liquido" can only be updated to DEFAULT`.
- Causa raiz: `funcionarios_financeiro.salario_liquido` é `GENERATED ALWAYS AS (salario_base + salario_por_fora) STORED` — Postgres calcula sozinho e rejeita qualquer valor explícito. Tanto `funcionarios.ts` (`createEmployee`/`updateEmployee`, usado no cadastro) quanto `EmployeeFinance.tsx` (aba "Financeiro/Folha", usado pra lançar a folha do mês) mandavam esse campo no payload de escrita — afetava 100% das tentativas de editar/criar dados financeiros de qualquer funcionário, não só o Pedro.
- Removido `salario_liquido` dos dois payloads de escrita. O input "Salário Líquido (R$)" em `EmployeeFinance.tsx` foi removido — nunca alimentava nada de fato (a folha usa seu próprio cálculo, `salario_base - descontos + adicionais + salario_por_fora`), só existia pra ser mandado pro payload quebrado; mantido só o "Salário Líquido Calculado" (somente leitura) no resumo.
- **Achado colateral**: submodule local (`dashboard-rh-lucenera-5fe9c`) já estava com `funcionarios.ts` desatualizado em relação ao Skip — faltava o campo `perfil` (SPEC-064). Sincronizado no mesmo commit.
- Publicado Skip 23919 v0.0.224. Testado ao vivo: erro de `salario_liquido` não ocorre mais; guard pré-existente de "Empresa não definida" (SPEC-065) segue funcionando normalmente pra funcionários sem empresa cadastrada — não é regressão, é validação intencional.

## 2026-08-17 (3)

### Corrigido — SPEC-116: teste ao vivo do rollout completo (8 sistemas) achou 5 bugs reais

- Depois do rollout dos 6 sistemas (entrada anterior), pedido do usuário ("teste todos!!") de validar cada um ao vivo no navegador, não só via QA automático do Skip.
- **Orçamentos**: aba "Todos" usa `useBudgetStore.ts`, implementação separada de `budget-search.ts` (já corrigida no rollout) — nunca checava `arquiteto`, era de 1 termo e sensível a acento. "ribeiro" (nome de arquiteto visível na tela) retornava 0 antes da correção. Corrigido; publicado Skip 32554 v0.0.349.
- **Logística**: `EntregasFinalizadasPage.tsx` buscava `recebido_por`, mas a coluna de pessoa realmente exibida na linha é `gestora_equipe` — "marina borgato" retornava 0 antes da correção. Achado colateral ao investigar: `SeparacaoPage.tsx` também não checava `endereco_entrega`/`gestora_equipe`, e `PendentesPage.tsx` não checava `resolved_by` na aba Resolvidas. Publicado Skip 24039 v0.0.92.
- **Estoque/Compras, Admin Bancária, Hub/TI, RH**: testados ao vivo sem bug novo — confirma que os padrões (client-side normalize+multi-termo / server-side `.or()` encadeado) aplicados no rollout já estavam corretos nesses sistemas.
- `Avaliacoes.tsx`/`Cargos.tsx` (RH) e `DevolucaoItemSearchModal.tsx` (Orçamentos) não têm dado suficiente em produção pra exercitar a busca ao vivo — mudanças de baixo risco, aceitas por revisão de código.
- **Pendente**: 2 commits locais (Logística `823d074`, Orçamentos `3a63a23`) ainda não empurrados pro GitHub — `git push` trava no prompt interativo do Git Credential Manager, precisa ser rodado manualmente pelo usuário. Produção (Skip) já está correta em ambos.

## 2026-08-17 (2)

### Adicionado — SPEC-116: rollout da busca universal nos 6 sistemas restantes

- Depois dos 2 pilotos (Cadastro/CRM, ver entrada anterior), rollout completo no mesmo dia: Orçamentos (Skip 32554), Estoque/Compras (Skip 40326), Logística (Skip 24039), Admin Bancária (Skip 36395), RH (Skip 23919), Hub/TI (Skip 37750) — todos publicados em produção.
- **Padrão usado**: telas client-side (array já carregado) ganharam `normalize()` (accent-strip) + multi-termo AND; telas server-side ganharam `.or()` encadeado por termo (PostgREST soma como AND entre grupos).
- **Achados no processo**: (1) `TransactionFilters.tsx`/`transactionService.ts` do checklist original estava em Orçamentos, não em Admin Bancária — corrigido no sistema certo; (2) PostgREST não aceita `.or()` combinando coluna própria com coluna de tabela relacionada (embedded resource) — confirmado direto contra a API real (erro PGRST100); solução é filtrar client-side quando isso for necessário (usado em `PedidosCompra.tsx`); (3) submodule local de Logística tinha uma feature (duplo-clique) commitada mas nunca publicada no Skip — mudança de busca aplicada sem misturar com essa feature pendente.
- Todos os sistemas passaram no QA automático do Skip antes de publicar. Ainda não testados ao vivo no navegador (só os 2 pilotos foram) — ver Pendências da SPEC-116.

## 2026-08-17

### Adicionado — SPEC-116 (pilotos 1 e 2): busca universal multi-coluna estilo Google

- Pedido do usuário: busca full-text multi-coluna, parcial, sem distinção de acento/maiúscula, com múltiplos termos em qualquer ordem, em todo campo de busca do ecossistema.
- SPEC-116 criada cobrindo os ~10 sistemas; usuário aprovou seguir a recomendação (rollout faseado, começando pelos 2 pilotos abaixo). Ubiqua e Dashboard Financeiro satélite ficaram fora desta rodada (baixa prioridade / dados desconectados).
- **Piloto 1 — Cadastro (server-side)**: RPC `buscar_produtos_fuzzy` (SPEC-100) estendida — migration `20260817_119_spec116_busca_universal_produtos_fuzzy` — para casar múltiplos termos em qualquer ordem (antes era a frase inteira) e incluir `descricao_tecnica` (antes só nome/sku/referencia/marca/categoria). `Pecas.tsx` (`getProdutosEstoqueFiltradoBatched`) trocou o fallback ilike exato/parcial por uma chamada a essa RPC. Migration aplicada no Supabase real; testado ao vivo via psql: "interlight" (marca) e "led plafon" (2 termos, ordens trocadas) retornam corretamente. Publicado Skip 36668.
- **Piloto 2 — CRM (client-side)**: `Clientes.tsx` e `Projetos.tsx` — busca por múltiplos termos normalizados (accent-strip) contra todos os campos relevantes da linha (Clientes: nome/empresa/razão social/CPF-CNPJ/e-mail/telefone/endereço/observações; Projetos: código/nome/status/cidade/UF/cliente/arquiteto/engenheiro/responsável), em vez de 1-2 campos fixos com frase inteira. Publicado Skip 24580.
- **Achado**: submodule local `lucenera-crm-3bd29 (1)/src/pages/Projetos.tsx` estava desatualizado (versão pré-SPEC-043/044, com Sheet lateral e `getProjetos()` em vez de `useProjectStore`) — a mudança foi escrita direto no Skip para não regredir esse refactor mais recente; o submodule local ficou sem essa mudança específica (só `Clientes.tsx` foi sincronizado localmente).
- **Teste ao vivo (mesmo dia) achou 2 bugs reais que QA automático + smoke-test via psql não pegaram**: (1) termo genérico ("spot"/"interlight") casava até 2000 produtos, e mandar todos os ids via `.in('id', ids)` gerava URL de ~40-70KB que estourava limite do servidor — corrigido buscando em lotes de 150 ids (Skip 36668 v0.0.70); (2) bug de lógica de 3 valores do SQL — `sku ilike '%termo%'` retorna NULL (não false) quando `sku` é NULL, quebrando o `NOT EXISTS` do multi-termo e deixando termos sem match passarem — "led plafon" trazia produtos sem "led". Corrigido com `coalesce(coluna,'')` antes de todo `ilike` (migration `002_fix_null_propagation_multitermo.sql`, aplicada no Supabase real). Ambos os pilotos revalidados ao vivo no navegador após as correções, sem erro.
- Próximos passos (rollout dos demais sistemas) documentados na própria SPEC-116.

## 2026-08-16 (5)

### Adicionado — SPEC-114: busca + parcela/cliente/vencimento na seleção de boleto (Admin Bancária)

- Reunião Vinícius 14/08/2026: ele confundiu qual parcela (P1/P2/P3) era qual ao vincular NF a boleto, quando os valores eram parecidos.
- Sem campo de "número de parcela" em `boletos` — derivado no frontend agrupando por `orcamento_id` e ordenando por `vencimento`. Adicionado busca livre (cliente/número) nos dois seletores (form + modal "Vincular a um Boleto"); cada opção agora mostra `P{n}` · cliente · vencimento · valor.
- **Achado ao testar ao vivo**: bug pré-existente deixava a tela toda em branco (crash) quando um orçamento tinha boleto mas nenhuma NF registrada — corrigido junto.
- Publicado Skip 36395 v0.0.64. Testado ao vivo com orçamento real de 13 parcelas, busca filtrando corretamente, sem erros.

## 2026-08-16 (4)

### Corrigido — Backfill produtos.referencia = produtos.sku

- Usuário pediu pra corrigir o campo `referencia` vazio usando a planilha `Produtos__2026-08-07.xlsx`.
- Achado: a coluna "Referencia" da planilha é uma cópia do `sku` (4313 de 4351 produtos batendo exatamente) — não é dado novo. Dos 35 casos onde `sku` estava vazio e a planilha tinha valor, 33 colidiam com SKU já usado por outra variante de cor/tamanho do mesmo produto (a planilha não distingue variante) — só 2 eram seguros de importar.
- Decisão do usuário: em vez de tentar reconciliar essas variantes, espelhar `sku` → `referencia` em todo o catálogo (`UPDATE produtos SET referencia = sku WHERE referencia vazio`), pra que sistemas que leiam a coluna `referencia` diretamente (fora do Cadastro Lucenera, que já usa `sku` via decisão de 11/08) também tenham o dado.
- Migration `20260816_118_backfill_referencia_a_partir_do_sku` aplicada no Supabase real: 4686 linhas atualizadas, 0 sobrescritas (referencia estava 100% vazia antes). Não muda nenhuma UI.

## 2026-08-16 (3)

### Corrigido — Cadastro Lucenera: bug antigo de PecaModal duplicado + card lateral maior

- Pedido do usuário: aumentar o card lateral de peças/produtos, adicionar coluna "Código" antes de "Referência" na lista, e reduzir o scroll do formulário Nova/Editar Peça.
- Painel lateral de detalhes: 320px → 440-520px, colunas internas das tabelas ajustadas.
- Nova coluna "Código" (codigo_produto) antes de "Referência" na lista.
- Formulário Nova/Editar Peça: campos de h-8→h-7, padding das seções reduzido, modal com menos padding externo — scroll bem menor.
- **Achado ao testar ao vivo**: campo "Referência" do formulário salvava vazio. Investigando o git log, descobri que eu mesmo tinha reintroduzido um bug já corrigido e revertido 2x antes (commits `34943b6` e `2955d42`, 2026-08-11) — o rótulo "Referência" na UI sempre leu/gravou a coluna `sku` (não `referencia`, que está vazia em 4725 de 4726 peças). Revertido de volta pra `sku`.
- **Achado maior, bug antigo desde o scaffolding original do projeto (commits `daff012`/`b97de8a`, nunca numerados por SPEC)**: `<PecaModal/>` era renderizado duas vezes (em `App.tsx` E em `Layout.tsx`), montando 2 instâncias do formulário toda vez que "Editar Peça"/"Nova Peça" abria. Isso quebrava a exibição dos campos `Select` (Marca/Categoria apareciam em branco mesmo com dado correto no banco). Removida a instância duplicada de `App.tsx`.
- Publicado Skip 36668 v0.0.63→v0.0.68. Testado ao vivo em cada etapa (screenshots + inspeção de DOM via JS), console sem erros.

## 2026-08-16 (2)

### Corrigido — SPEC-103: seleção de L volta pra dentro da linha "Ver projetos" (2º feedback)

- Usuário mandou um mockup específico: queria o checkbox de seleção direto na linha expandida "Ver projetos" da tabela principal, não num modal à parte (que eu tinha acabado de criar como resposta ao primeiro feedback).
- Modal separado apagado. Checkbox por L adicionado direto em `NecessidadeCompraDetalhe.tsx` (a linha expandida que já existia desde a SPEC-039), com badge do L junto ao projeto e barra "N selecionado(s) · Gerar Compra" aparecendo ali mesmo.
- Publicado Skip 40326 v0.0.68. Testado ao vivo ponta a ponta, console sem erros.

## 2026-08-16 (1)

### Corrigido — SPEC-103: card de seleção por L virou modal (feedback do usuário)

- Usuário testou ao vivo e reportou: o card lateral criado pra selecionar L's ficava apertado demais, confundia.
- Lista de seleção (Orçamento/L/Cliente/Fornecedor/Pendente) saiu do card lateral (~320px) e virou um modal de verdade, mesmo padrão do "Buscar Venda de Origem" da Devolução. Card lateral agora só tem o resumo do produto e um botão que abre o modal.
- Publicado Skip 40326 v0.0.67. Testado ao vivo: modal abre com as linhas certas, seleção e geração de pedido funcionando ponta a ponta.

## 2026-08-15 (16)

### Adicionado — SPEC-106 (parcial): margem padrão de 50% pra peça sem cadastro

- Reunião Vinícius 14/08/2026: item avulso sem custo digitado mostrava 100% de lucro no painel "Gerenciamento do Orçamento" (custo nascia em 0), mascarando a leitura real do orçamento.
- Custo default de item avulso passa a ser 50% da venda (editável) em vez de 0.
- Publicado Skip 32554 v0.0.346.
- **Não implementado nesta rodada**: os 3 campos novos (Imposto/RT/Comissão) pedidos na mesma SPEC — não existe fórmula definida em lugar nenhum do sistema, precisa de definição do usuário antes de implementar.

## 2026-08-15 (15)

### Adicionado — SPEC-109: PDF do orçamento — código real, L separado, ordenar por L, 2 modelos

- Reunião Vinícius 14/08/2026: 4 ajustes no PDF gerado pela Edge Function generate-report.
- Achado: a tabela `orcamento_arquitetos` (múltiplos arquitetos com % de comissão, SPEC-077) existe de verdade em produção — o dump local usado na investigação anterior estava desatualizado e não mostrava essa tabela.
- Coluna "Código" agora usa o código real do produto (nunca mais o L nem a referência); "L" virou coluna própria; itens ordenados por número do L; nova "Data de Emissão" ao lado da "Data Impressão"; botão "Baixar PDF" virou menu com 2 modelos (cliente / interno com referência); PDF mostra todos os arquitetos quando o orçamento tiver mais de um cadastrado.
- Publicado Skip 32554 v0.0.345. Testado via chamada direta à API (mesma sessão do navegador) com orçamento real de 4+ itens — os 2 modelos geraram PDF válido com tamanhos diferentes, como esperado.

## 2026-08-15 (14)

### Adicionado — SPEC-110: ordem Sinal/Desconto consistente + sinal pré-preenchido por cliente

- Reunião Vinícius 14/08/2026: campos Sinal/Desconto pareciam trocados na tela; sinal deveria vir pré-preenchido quando o cliente tiver um valor padrão.
- Achado: existem dois blocos Sinal/Desconto na tela (campos editáveis e resumo de totais) — só o resumo mostrava a ordem errada (Sinal antes de Desconto, por decisão antiga da SPEC-078 de seguir a ordem do cálculo). Corrigido pra mostrar Desconto antes de Sinal nos dois lugares, sem mudar o cálculo em si.
- Novo campo `contatos.valor_sinal_padrao` (migration aplicada) — ao criar orçamento novo, se o cliente tiver um valor cadastrado, o campo Sinal vem pré-preenchido (editável). Ainda não existe campo na UI do CRM pra cadastrar esse valor — por ora só via banco.
- Publicado Skip 32554 v0.0.344. Testado ao vivo com dado real temporário (revertido em seguida).

## 2026-08-15 (13)

### Corrigido — SPEC-105: busca de venda de origem na Devolução não achava nada

- Reunião Vinícius 14/08/2026: buscar a venda de origem pra devolução não retornou nada no teste ao vivo — investigação anterior não conseguiu confirmar se era bug ou falta de dado.
- Reproduzido e confirmado como bug real (sem precisar do usuário): `projetos.cliente_id` pode divergir do `cliente_id` gravado na venda original. Em produção, 2 de 7 projetos com saldo ativo tinham essa divergência, e mais 2 de 7 tinham `cliente_id` nulo — a busca funcionava certo em só 3 de 7 casos.
- Fix: a busca agora casa por cliente OU pelo projeto atual (antes só por cliente), cobrindo os dois padrões de falha.
- Publicado Skip 32554 v0.0.343. Testado ao vivo recriando o cenário exato do bug.

## 2026-08-15 (12)

### Adicionado — SPEC-108: travar valor/produto no orçamento — só admin (edição)

- Reunião Vinícius 14/08/2026: só administrador (Vinícius + Lana) deveria poder editar valor de peça ou adicionar produto num orçamento; vendedoras só mexem desconto.
- Achado antes de implementar: a mesma tela cria E edita orçamento — travar incondicionalmente quebraria a criação de orçamento novo. Escopo corrigido: trava vale só pra editar orçamento já existente.
- Frontend: campo de preço, troca de produto e botões de adicionar produto desabilitados pra quem não é admin, só quando `isEditing`. Backend: RPC `replace_orcamento_itens` reforçada — compara preço/produto antes/depois do save e bloqueia mudança pra não-admin, migration aplicada no Supabase real.
- Publicado Skip 32554 v0.0.342. Testado ao vivo como admin (único perfil disponível): tela sem restrição, save normal funcionando.

## 2026-08-15 (11)

### Adicionado — SPEC-103 (parte 1): comprar por L Fixo direto em "Por Produto"

- Fecha o pedido pendente da reunião de 14/08: poder comprar por item específico de orçamento (L) sem trocar de aba. Decisão do usuário: o "card de seleção por L" segue o mesmo padrão visual do Card Lateral de Peça (SPEC-049).
- A aba separada "Por Item de Orçamento" (SPEC-040) foi removida — a tela Necessidade de Compra virou visão única. O card lateral que já mostrava "Entrega Futura por Projeto" ao selecionar um produto passou a mostrar os L's daquele produto com checkbox, fornecedor e "Gerar Compra (N)", reaproveitando o mesmo modal de geração de pedido da aba antiga.
- Publicado Skip 40326 v0.0.66. Testado ao vivo: seleção de 2 L's do produto 10289 (Interlight) abriu o modal com as linhas e custo corretos.

## 2026-08-15 (10)

### Alterado — SPEC-115: "Excluir" peça sai do painel rápido, fica só dentro da edição completa

- Reunião Vinícius 14/08/2026: um clique acidental no painel de detalhes da listagem apagava o cadastro de peça direto, sem passar pela edição completa.
- `PecaDetailsPanel.tsx`: removido o botão "Excluir" (mantido só "Editar"). `Pecas.tsx`: removida toda a lógica de exclusão que vivia na listagem. `PecaForm.tsx` (modal de edição): novo botão "Excluir Peça" no rodapé, só na edição (não na criação), com confirmação própria.
- Decisão do usuário: só reposicionar por agora, sem restrição de role (admin/gerente) em cima do botão.
- Achado à parte: `Pecas.tsx` local tinha uma coluna "Código" nunca publicada no Skip — deixada de fora do push, local realinhado ao conteúdo real do Skip.
- Publicado Skip 36668 v0.0.62. Testado ao vivo via DOM: painel rápido sem "Excluir"; edição completa com "Excluir Peça" funcionando.

## 2026-08-15 (9)

### Adicionado — SPEC-113: setor de estoque na busca de produto do orçamento

- Pedido pendente de reunião anterior, retomado em 14/08/2026: mostrar onde a peça está fisicamente estocada (Estoque/Showroom) na hora de escolher o produto no orçamento.
- Nova coluna "Setor" em `ProductSearchModal.tsx`, buscada em lote de `estoque_itens` (mesma fonte do hover "Distribuição por Local" já existente).
- Publicado Skip 32554 v0.0.341. Testado ao vivo: produtos com saldo real mostram "Estoque" corretamente.

## 2026-08-15 (8)

### Adicionado — SPEC-112: destaque visual quando orçamento tem observação preenchida

- Reunião Vinícius 14/08/2026: campo "Observações" existia mas ficava escondido — pedido explícito de um "cardzinho laranja" que salta aos olhos quando preenchido, pra não perder informação importante (ex.: qual empresa faturar).
- Ampliado além do pedido original: além da listagem dentro do detalhe do projeto (`ProjectOrcamentoList.tsx`), a listagem principal de orçamentos (`BudgetTableRow.tsx`, tela que todo mundo usa no dia a dia) também recebeu o destaque — senão ficaria incompleto.
- Borda laranja + ícone com preview (tooltip nativo) da observação nos dois lugares. Publicado Skip 32554 v0.0.340. Testado ao vivo com dado real temporário (revertido em seguida).

## 2026-08-15 (7)

### Adicionado — SPEC-111: aviso antes de salvar item de orçamento em Aprovação Financeira

- Reunião Vinícius 14/08/2026: editar item de um orçamento em "Aprovação Financeira" reinicia o ciclo de aprovação do cliente silenciosamente (trigger `handle_orcamento_item_change_reset`) — comportamento correto (o próprio Vinícius validou ao vivo), mas sem nenhum aviso, foi confundido com bug.
- Achado: `BudgetFormPage.tsx` só dispara o trigger nesse status específico — `'Orçamento Aprovado'` já pula os itens inteiramente (achado anterior de 2026-08-14), então nunca chega a disparar reset por essa tela.
- Fix: confirmação bloqueante antes de salvar quando status = "Aprovação Financeira", + toast de sucesso menciona o reinício explicitamente.
- Publicado Skip 32554 v0.0.339. Não testado clicando de verdade (regra da sessão: nunca disparar `window.confirm`/`alert` nativo via automação de browser) — verificado via QA (typecheck+build) do Skip.

## 2026-08-15 (6)

### Adicionado — SPEC-107: Cheque, Transferência e Permuta como forma de pagamento do orçamento

- Reunião Vinícius 14/08/2026: pediu Permuta como forma de pagamento nova. Achado: Cheque e Transferência já existiam no ENUM `pagamento_forma` mas nunca tinham sido liberados na tela do orçamento.
- Migration `ALTER TYPE pagamento_forma ADD VALUE 'permuta'` aplicada no Supabase real. `BudgetFormPage.tsx` (Orçamentos) libera os 3 valores no `<Select>` e em `validFormas`.
- Achado extra corrigido junto: importação de XML (Connect) recodificava silenciosamente forma de pagamento "transferência" pra "pix" (fallback só existia porque transferência nunca era válida) — removido, já que agora é opção real.
- Publicado Skip 32554 v0.0.338. Testado ao vivo: as 7 opções aparecem corretamente no select.

## 2026-08-15 (5)

### Alterado — SPEC-104: renomeia "Coberto" para "Reservado" e remove aba Devolução da Necessidade de Compra

- Reunião Vinícius 14/08/2026: coluna "Coberto" no detalhe expandido por produto renomeada pra "Reservado" (mesmo termo do card de peça do Cadastro, SPEC-101). Aba "Devolução" tirada da rotina de Compras — "essa coisa nem deveria ter aqui nessa rotina de compra" — sem remover a funcionalidade do banco, só o atalho de acesso.
- Publicado Skip 40326 v0.0.64. Testado ao vivo: abas agora só "Por Produto"/"Por Item de Orçamento", coluna mostra "Reservado".

## 2026-08-15 (4)

### Adicionado — SPEC-103 (parte 2): empresa de origem na Necessidade de Compra

- Reunião Vinícius 14/08/2026: tela agregava necessidade só por produto, sem mostrar de qual empresa veio a venda que originou a necessidade — decisão foi dar visibilidade (não regra automática de "comprar pela empresa que vendeu mais").
- Migration adiciona `empresa_id`/`empresa_nome` à `vw_necessidade_compra_detalhe` (JOIN com `orcamentos`/`empresas`, já existentes na view). Coluna "Empresa" nova em `NecessidadeCompraDetalhe.tsx` (detalhe inline por produto) e no modal de registrar pedido.
- Publicado Skip 40326 v0.0.63. Testado ao vivo: produto 10289 mostra corretamente "FOCO ILUMINACAO" nas 4 linhas do orçamento de origem.
- Parte 1 da SPEC (fundir abas "Por Produto"/"Por Item de Orçamento") ficou pendente — layout de UX não definido, adiado a pedido do usuário.

## 2026-08-15 (3)

### Corrigido — SPEC-102: fornecedor e impostos não vinham pré-preenchidos ao registrar pedido de compra

- Reunião Vinícius 14/08/2026: ao abrir "Registrar Pedido de Compra" a partir da Necessidade de Compra, o fornecedor já resolvido no cadastro do produto/marca não vinha pré-selecionado, e por consequência os campos de imposto (ICMS/IPI/ST, mecanismo da SPEC-038) também não disparavam.
- Fix: `ModalRegistrarCompra.tsx` (Compras) passou a pré-selecionar o fornecedor no `useEffect` de abertura, reaproveitando a função que já existia e já disparava o pré-preenchimento de impostos.
- Achado que corrige a própria SPEC: o 3º ponto do pedido original (valor do pedido sem BDI/impostos no fluxo de caixa) já estava certo — os 3 modais que criam pedido já somam custo+impostos antes de mandar pro banco. Nenhuma mudança de RPC foi necessária.
- Publicado Skip 40326 v0.0.62. Testado ao vivo: produto 10289 (Interlight) já abre com fornecedor e custo pré-preenchidos.

## 2026-08-15 (2)

### Corrigido — SPEC-101: badge "Reservado" no card de peça misturava reserva com entrega futura

- Reunião Vinícius 14/08/2026: card "Estoque por Local" (Cadastro Lucenera) mostrava "Reservado" como o total comprometido (reserva + entrega futura), não só o que está de fato no setor Reserva — reproduzido ao vivo com números reais.
- Causa: `estoque_itens.quantidade_reservada` é, por desenho, o total comprometido (usado por outras RPCs com esse significado) — não deveria ter sido usado pra essa métrica de exibição.
- Fix: badges do cabeçalho passaram a somar `q_reserva` de `vw_cadastro_produto_reserva_detalhe` (mesma fonte já usada pela tabela "Reservado por Cliente/Projeto" da SPEC-049) — nenhuma migration nova precisou ser criada, a view certa já existia. Tabela "Estoque por Local" (distribuição física por depósito) mantida como estava.
- Publicado Skip 36668 v0.0.61. Testado ao vivo: produto 10289 (816 comprometido, 0 em reserva real) agora mostra "Reservado: 0" corretamente.

## 2026-08-15 (1)

### Adicionado — SPEC-100: busca de produtos estilo Google no orçamento (marca/categoria)

- Reunião Vinícius 14/08/2026 apontou como prioridade: buscar "interlight" (marca) na tela de Buscar Produtos do orçamento não retornava nada — marca/categoria eram filtros `<Select>` separados, nunca entravam no texto livre.
- Confirmado com usuário: opção "de verdade estilo Google" — RPC fuzzy nova (`buscar_produtos_fuzzy`, mesmo padrão de `buscar_fornecedores_fuzzy` da SPEC-030/034, `word_similarity`+`unaccent`, tolera erro de digitação) cobrindo nome/sku/referencia/codigo_produto/marca/categoria.
- Migration aplicada no Supabase real (`20260815_113_spec100_busca_produtos_fuzzy`). `ProductSearchModal.tsx` (Orçamentos, Skip 32554) trocado pra chamar a RPC, mantendo os filtros de marca/categoria/fornecedor já existentes. Publicado v0.0.337.
- Testado ao vivo: "interlight" agora retorna corretamente as peças da marca.

## 2026-08-14 (9)

### Corrigido — pedido em "Ag. Separar" ainda não aparecia no Logística + crash na página inteira

- Usuário confirmou que o fluxo continuava incompleto: os fixes anteriores só cobriam separações já `'Pronto'` (venda 100% completa); uma separação recém-criada (`'Pendente'`, item em Ag. Separar) continuava invisível.
- Fix: `'Pendente'` adicionado ao filtro do Logística.
- Isso expôs um crash mais sério: a página inteira de Separação (não só o card) agrupa tudo por `data_entrega` sem checar null — separações `'Pendente'` da Separação Parcial não têm data ainda, e a tela ficava em branco.
- Corrigido com uma seção nova, "Aguardando data de entrega", pra itens sem data — sem mexer no agrupamento por dia que outras partes do sistema (ex.: Criar Rota) já dependem.
- Publicado Skip 24039, v0.0.89→v0.0.90. Testado ao vivo: a venda real (ainda em Ag. Separar) apareceu na hora, sem crash.

## 2026-08-14 (8)

### Adicionado + Corrigido — peças visíveis no card de separação do Logística + crash em produção

- Usuário perguntou se as peças (não só o vínculo com o projeto) aparecem no Logística quando uma separação é criada — resposta era não: o card ativo nunca lia `separacao_itens` (só um hook morto numa pasta duplicada fazia isso).
- Adicionado painel "Peças desta separação" no Detalhes do card (`SeparacaoItensList.tsx`), listando código/descrição/quantidade.
- **Bug real achado ao testar ao vivo na venda real da Roberta**: expandir "Detalhes" quebrava a tela inteira (branco) — `numero_venda?.join(', ')` estourava porque o campo é texto no banco pra separações da Separação Parcial, não array. Bug pré-existente, nunca antes exercitado porque essas separações nunca tinham aparecido na tela. Corrigido.
- Publicado Skip 24039, v0.0.87/v0.0.88. Testado ao vivo: peças reais (10009×7, 11461×3, 12395×3) aparecendo certas, sem crash.

## 2026-08-14 (7)

### Corrigido — pedido separado não aparecia no Logística + estorno bloqueava admin

- Usuário testou o fluxo real (separar até completar uma venda) e reportou dois bugs pós-SPEC-099: o pedido não aparecia no sistema de Logística, e o estorno recusava mesmo sendo admin.
- **Causa real do 1º bug**: nenhuma tela do Logística lê a tabela `entregas`, e as listas (`SeparacaoPage`, `CalendarioPage`) só mostravam `status IN ('material_solicitado','Em separação','separado')` — o status `'Pronto'` (o que a Separação Parcial usa) nunca esteve nesse filtro. A entrega tinha sido criada certo no banco, só ficava invisível pro Matheus. Fix: `'Pronto'` adicionado aos filtros do Logística (Skip 24039, v0.0.86) — testado ao vivo, a venda que ficou presa (23.316 Roberta Demeterco) passou a aparecer.
- **Achado mais sério**: mesmo corrigido isso, o fluxo real do Matheus (`finalizarEntrega`) nunca toca a tabela `entregas` — finaliza direto em `separacoes.status='finalizado'`. O trigger da SPEC-099 que devia mover `q_separado→q_entregue` (baseado em `entregas.status`) nunca dispararia de verdade. Trigger novo adicionado em cima do ponto real (`separacoes.status='finalizado'`).
- **2º bug**: o guard "já separado" do estorno granular (SPEC-099) bloqueava todo mundo sem exceção. Usuário foi explícito que admin deveria poder. Fix: admin/gerente agora conseguem estornar mesmo já fisicamente separado (retira de `q_separado`); continua bloqueado se já `entregue`.
- Migration `20260814_112_fix_link_logistica_real_e_estorno_admin`. Testado transacionalmente (admin ok, usuário comum bloqueado, trigger de finalização ok) e ao vivo no Logística — sem alterar a venda real da Roberta, só corrigindo a visibilidade.

## 2026-08-14 (6)

### Adicionado — SPEC-099: estorno granular + link real Ag.Separar→Separado→Entregue

- Usuário testou reverter uma separação com 2 peças (produto 10009 e 11461) e descobriu que o estorno devolvia as duas juntas, mesmo querendo desfazer só uma (e só parte da quantidade de uma delas). Achado ao investigar: `estornar_separacao_parcial` sempre revertia a separação inteira, sem granularidade.
- **Estorno granular**: nova RPC `estornar_item_separacao` (peça + quantidade específica, coluna `quantidade_estornada` rastreando o acumulado) + `estornar_separacao_parcial` refatorada pra virar "reverter tudo" (orquestra a RPC granular por item). Frontend em Separação Parcial: modal com um input de quantidade por peça, mais o botão "Reverter tudo".
- **Link Ag.Separar→Separado→Entregue**: campos `q_separado`/`q_entregue` existiam desde a SPEC-010 mas nunca eram escritos. Investigação achou que ligar no fluxo antigo de Logística (415+ registros reais) não fazia sentido — esses registros nunca tiveram `separacao_itens` vinculado (só texto livre), então não há saldo pra sincronizar ali. Conectado no que a própria Separação Parcial/SPEC-089 já usa: trigger novo quando `separacoes.status` vira `'Pronto'` (move `q_ag_separar→q_separado`) e trigger novo quando `entregas.status` vira `'Entregue'` (move `q_separado→q_entregue`). Decisão do usuário: sem backfill dos 424 registros antigos, "o fluxo antigo não funcionava".
- Testado no banco (transacional) e ao vivo no navegador, na mesma venda ORC-0022 onde o bug foi reportado — sem resíduo de teste. Publicado Skip 48801, v0.0.25.
- Achado colateral, ainda pendente: decisão do Vinícius de remover `boletos.nosso_numero` (reunião 11/08) não tem substituto definido — é a chave que a conciliação bancária automática (SPEC-008) usa pra casar o retorno do banco com o boleto certo.

## 2026-08-14 (5)

### Adicionado — SPEC-098: troca de peça em Reserva entre projetos (Separação Parcial)

- Pedido do usuário: quando uma peça está reservada pro projeto A mas o projeto B precisa dela com mais urgência, precisa dar pra "trocar" — a peça sai da reserva de A e entra na reserva de B, continuando em Reserva (não é empréstimo com devolução esperada).
- **Achado principal**: o mecanismo já existia inteiro no banco desde a SPEC-011 (`transferencias_estoque`, `solicitar_transferencia_estoque`, `aprovar_transferencia_estoque`) e nunca teve frontend em nenhum sistema — só faltava expor.
- **Regra de acesso**: inicialmente desenhada por equipe (`funcionarios_financeiro.equipes_id`), abandonada depois de achar que só 2 de 9 funcionários com login tinham essa equipe preenchida. Substituída, a pedido do usuário, por acesso liberado a quem tem `cargo = 'Projetista'` (3 pessoas: Marina Pousa, Thairine, Thais) ou `role` gerente/admin — sem checagem de equipe entre os projetos.
- **Bug real corrigido antes de publicar**: `funcionarios.cargo` de Marina/Thairine está gravado como `"Projetista "` (espaço sobrando) — comparação exata nunca teria funcionado; trocado para `btrim(cargo) = 'Projetista'`.
- Migration `20260814_110_spec098_troca_reserva_projetista`: guard novo em `aprovar_transferencia_estoque` + RPC nova `trocar_reserva_projetista` (orquestra solicitar+aprovar numa chamada só, troca fica imediata) + RPC `pode_trocar_reserva()` (pro frontend decidir se mostra o botão).
- Frontend em `separacao-parcial`: ação "Trocar" por item reservado, modal com painel "Reservado por Cliente/Projeto" (mesma informação do card de peça do Cadastro Lucenera, SPEC-049, reaproveitando a view `vw_cadastro_produto_reserva_detalhe`) servindo de seletor de destino, e tela "Log de Trocas" no cabeçalho.
- Testado direto no banco (sucesso e rejeição) e ao vivo no navegador na venda **ORC-0022** pedida pelo usuário, com um segundo projeto de teste criado e depois revertido — sem resíduo em produção. Publicado Skip 48801, v0.0.24.
- Pendência conhecida: Thais Gomes Pegrucci Favaron (`cargo = 'Projetista'`) não tem login vinculado — não consegue usar a função até alguém criar o usuário dela.

## 2026-08-14 (4)

### Corrigido — "Salvar Alterações" falhava sempre em orçamento já aprovado

Usuário reportou "salvar uma edição em orçamento falhou também". Reproduzido ao vivo em `ORC-0005`: 3 bugs em cadeia, cada um escondendo o próximo, todos afetando especificamente orçamentos com status "Orçamento Aprovado" (90% dos ~30 orçamentos reais hoje):

1. **`subgrupo` vazio trava com "Selecione o Tipo"**: orçamentos criados antes da SPEC-074 (26 de 29) têm `subgrupo` nulo no banco. Em modo de edição, "Tipo de Operação" fica desabilitado ("Não pode ser alterado após a criação"), então o `useEffect` de auto-preenchimento (que só roda fora de edição) nunca dispara e não há como o usuário corrigir manualmente. Fix: `form.reset()` em modo edição aplica o mesmo fallback que `defaultValues` já usava na criação (SPEC-097).
2. **`data_inicio_pagamento` obrigatório + só hoje/futuro trava com "Invalid input"**: campo introduzido pela SPEC-082 (12/08) — 19 de 30 orçamentos não têm esse valor, e mesmo os que têm ficam com data no passado depois de aprovados há semanas. Exigir "hoje ou futuro" pra salvar uma edição não relacionada a pagamento (ex.: observações) travava qualquer orçamento aprovado antigo. Fix: validação de obrigatoriedade/futuro só roda quando **não** é edição de orçamento já aprovado; campos de prazo de pagamento deixam de ser recalculados/sobrescritos nesse caso (parcelas/boletos reais já existem em tabelas próprias, essas colunas em `orcamentos` só registram histórico).
3. **`replace_orcamento_itens` sempre faz DELETE + INSERT de todos os itens** — viola a FK `projeto_itens_orcamento_item_id_fkey`, já que `projeto_itens` fica vinculado aos itens originais desde a aprovação (`aprovar_orcamento_financeiro`). Isso quebrava **qualquer** save num orçamento aprovado, mesmo sem tocar nos itens — é o erro real que finalmente apareceu depois de corrigir os 2 bugs client-side acima. Fix: `updateBudget` ganha flag `skipItens`, usada quando o orçamento já está aprovado — não escreve nada em `orcamento_itens` nesse caso (edição de itens pós-aprovação nunca funcionou; agora falha de forma segura em vez de quebrar o save inteiro, já que os itens ficam travados no que foi aprovado).

Testado ao vivo: `ORC-0005` (aprovado, real) salva com sucesso, itens/parcelas/subgrupo preservados corretamente. `ORC-0018` (rascunho, com data no passado) continua corretamente bloqueado exigindo data válida — sem regressão no fluxo normal de criação/edição de rascunho. Publicado Skip 32554, v0.0.334 → v0.0.336.

## 2026-08-14 (3)

### Corrigido — "não consigo adicionar quantidade" e "não tem como reverter" em Separação Parcial

- Usuário reportou os dois problemas testando `ORC-0005` (venda real de cliente, não teste): não conseguia digitar quantidade em 2 dos 3 itens, e não achava como reverter.
- **Investigado, não era bug de digitação**: testei o campo do 3º item (que tinha reserva disponível) e aceitou digitação normalmente. Os outros 2 itens tinham Reserva = 0 (100% já em "Ag Separar" desde 11/08) — o campo fica corretamente desabilitado por design, só que sem nenhuma explicação visível.
- **O botão de reverter já existia** (SPEC-090, seção "Parciais desta venda"), só que fica separado da tabela de itens, fácil de não notar.
- **Fix**: quando um item está sem reserva mas com quantidade em "Ag Separar", o campo desabilitado agora vira um link explicando a situação ("Sem reserva — N já enviado(s), ver abaixo p/ estornar") que rola a tela até a seção de Estornar. Publicado Skip 48801, v0.0.23.

## 2026-08-14 (2)

### Adicionado — card de aviso pro Matheus quando separação já iniciada é estornada

- Pedido do usuário: item 4 da reunião com Vinícius de 11/08 ("Estornar ela inteira ou editar... se editar essa lista tem que ter um aviso pro Matheus... tem que estornar, tem que deixar. Enquanto estiver aqui, aguardando separar, tem que ter a notificação.") só tinha sido parcialmente implementado pela SPEC-090 (estorno com motivo obrigatório existia, mas o aviso ao logístico — escrito em `entregas.observacoes` — nunca era visto por ninguém, porque a tela real de Logística não lê essa tabela).
- **Achado ao investigar onde o aviso deveria aparecer**: a aba "Pendentes" do app de Logística (`lucenera-logistics-b7cd1`) já tinha o formato de card certo ("Motivo da Pendência" em destaque) mas estava **completamente não-funcional** — lê da tabela `entregas_pendentes`, que nunca existiu no banco real (nem local, nem produção); o modal de registrar problema também era um placeholder vazio. A tela sempre mostrava "Nenhuma pendência! Tudo em dia" — na verdade um erro de query silencioso.
- **Achado adicional**: nenhuma função no banco jamais move estoque de `q_ag_separar` pra `q_separado`/`q_entregue` no fluxo novo de Separação Parcial — o conceito de "Separado" (distinto de "Ag Separar") nunca foi implementado de fato. Registrado como pendência separada, fora do escopo desta entrega (decisão do usuário).
- **Implementado**: tabela `entregas_pendentes` criada de verdade (destrava a aba Pendentes do Logística pro uso normal dela também) + `estornar_separacao_parcial` (SPEC-090) atualizada pra criar uma pendência lá, com o motivo do estorno, sempre que uma separação já registrada é cancelada — independente do estágio (Ag Separar ou além). Migration `20260814_109_entregas_pendentes_e_estorno_notifica_matheus`. Testado ao vivo de ponta a ponta: estorno em Separação Parcial → card aparece em Logística/Pendentes com motivo → "Solucionar" marca como resolvido corretamente.
- Publicado: Logística (Skip 24039, v0.0.85).

## 2026-08-14 (1)

### Corrigido + achado crítico — fluxo de ponta a ponta até a entrega (ORC-0022, todos os sistemas)

- **CHECK constraint de data usa UTC, frontend usa fuso do Brasil**: `orcamentos_data_inicio_pagamento_check` comparava com `CURRENT_DATE` (UTC do Postgres). Entre ~21h e meia-noite (horário de Brasília), o banco já virou o dia seguinte enquanto o calendário do frontend ainda oferece "hoje" no fuso local — toda criação de orçamento nesse horário falhava com erro cru do Postgres, todo dia. Fix: constraint compara com `(now() AT TIME ZONE 'America/Sao_Paulo')::date`. Migration `20260814_108_fix_data_inicio_pagamento_check_fuso_brasil`.
- **Separação Parcial travava permanentemente em "Pendente" sem jeito de finalizar**: se a data de entrega não é preenchida na mesma ação que zera a reserva, a separação fica presa (não há mais reserva pra digitar quantidade, e a única ação restante é "Estornar", que desfaz tudo). Fix: nova seção "Finalizar Entrega" que aparece quando a venda está sem reserva mas ainda há parcial "Pendente" — resgate manual sem precisar estornar. Publicado Skip 48801 v0.0.22.
- **CRÍTICO, não corrigido — reportado ao usuário**: a integração automática Separação Parcial → Logística (SPEC-089) escreve em `separacoes.status = 'Pronto'` + tabela `entregas`, mas o app real de Logística (`lucenera-logistics-b7cd1`) nunca lê a tabela `entregas` e sua query principal só busca `status IN ('material_solicitado','Em separação','separado')` — não inclui `'Pronto'`. Toda entrega criada pelo fluxo novo desde a SPEC-089 fica invisível pra quem usa a tela de Logística no dia a dia. São 2 sistemas paralelos com vocabulários de status incompatíveis sobre a mesma tabela `separacoes`. Precisa de decisão de arquitetura antes de corrigir.
- Achado menor: em Admin Bancária, os filtros "Venda"/"Fatura"/"Boleto" de Consultar Duplicatas são decorativos (nunca aplicados) — só "Duplicata" e "Pessoa"/"Empresa" filtram de verdade.
- Confirmado funcionando: Orçamentos (criação→aprovação equipe→aprovação financeira) → boleto aparece corretamente em Admin Bancária → item com estoque físico reserva e separa corretamente → Necessidade de Compra roteia corretamente item sem estoque.

## 2026-08-13 (7)

### Corrigido — continuação do teste ao vivo: aprovação financeira de ponta a ponta (ORC-0021)

- **Título do "Resumo Fiscal" hardcoded (Orçamentos)**: `FiscalSummaryDialog.tsx` mostrava literalmente "Resumo Fiscal (NF 4740 - Roberta Lucchesi)" — texto fixo no JSX, o mesmo em qualquer orçamento aberto, sem nenhuma relação com o orçamento real sendo visualizado. Valores (total, itens, CFOP) estavam corretos; só o título estava errado. Fix: título passa a usar `budget.numero` e o nome real do cliente. Publicado Skip 32554, v0.0.333.
- **Descrição do item errada em `projeto_itens` (bug sistêmico, desde SPEC-040/23-07)**: `aprovar_orcamento_financeiro` gravava a descrição do item com `COALESCE(oi.descricao, oi.custom_id, p.nome, ...)` — como `oi.custom_id` é o código de circuito ("L01"), ele sempre ganhava do nome real do produto sempre que preenchido. Afetava qualquer item com produto vinculado + `custom_id` preenchido, consumido também por outras views (separação/logística). Achado ao aprovar financeiramente o orçamento de teste `ORC-0021` e ver "L01" no lugar do nome do produto no resumo fiscal. Consulta em produção achou **12 itens errados em 5 orçamentos de clientes reais** (ORC-0005, ORC-0006, ORC-0007, ORC-0009, ORC-0010), além do item de teste. Fix: `COALESCE(oi.descricao, p.nome, oi.custom_id, 'Item do Orçamento')` — nome do produto prioritário sobre o código de circuito. Migration `20260813_107_fix_descricao_projeto_itens_prioridade_custom_id` aplicada em produção com autorização explícita do usuário, incluindo backfill retroativo das 13 linhas já erradas (confirmado 0 restantes após o UPDATE).
- **Fluxo de ponta a ponta validado até aprovação financeira**: `ORC-0021` avançou de rascunho (deixado assim na sessão anterior) até `Orçamento Aprovado`, passando por todas as etapas esperadas sem pular nenhuma (`historico_status_orcamentos` confirma: enviado_cliente → Aprovação da Equipe → Aprovação Financeira → Orçamento Aprovado). RPC criou 1 `projeto_item`, 1 `projeto_parcela`, 1 `boleto` corretamente. Item sem estoque físico foi roteado corretamente para Necessidade de Compra (`vw_necessidade_compra` mostra o projeto/cliente certo na tela de Compras) em vez de Separação — comportamento esperado, não testado até o fim de Separação/Logística por falta de estoque físico no produto de teste escolhido.

## 2026-08-13 (6)

### Corrigido — 3 bugs achados testando um projeto fictício de ponta a ponta (Orçamentos)

- **L custom_id vazio (ProductSearchModal/LQuantityRepeater)**: ao adicionar um L novo numa peça, o campo mostrava "L01" como placeholder cinza — parecia preenchido, mas o valor real era string vazia. O botão "Confirmar Seleção" ficava desabilitado sem nenhum toast de erro (disabled bloqueia o onClick antes dele disparar o aviso), travando silenciosamente todo fluxo de adicionar item a um orçamento. Fix: `handleAdd` gera um código real (`L01`, `L02`...) igual ao que o placeholder já prometia visualmente.
- **subgrupo (Tipo) vazio ao criar orçamento novo**: quando `SUBGRUPOS_POR_TIPO` tem só 1 opção pro tipo (caso de "Venda" → "VENDAS"), o campo "Tipo" renderiza um `Input` desabilitado mostrando essa opção, mas nunca chama `field.onChange`. Como "Venda" já vem selecionado por padrão, o `onClick` que preenche `subgrupo` nunca dispara — criar um orçamento novo sem trocar o Tipo de Operação falhava a validação "Selecione o Tipo" sem nenhum aviso visível até rolar a tela pro topo. Fix: `useEffect` sincroniza `subgrupo` automaticamente quando há só 1 opção.
- **Painel "Responsável (Sistema)" sempre "Não encontrado"**: lia `projeto.responsavel_id` (FK legada pra `usuarios`, morta desde a SPEC-077), em vez de `responsavel_funcionario_id` (FK real pra `funcionarios`). Cosmético — o campo funcional "Vendedor" já usava a FK certa — mas indicava dado incorreto pro usuário.
- **Correção do fix do subgrupo**: a 1ª tentativa (useEffect) tinha race condition com o carregamento assíncrono do projeto e podia deixar o campo vazio de novo mesmo depois de já preenchido. Fix definitivo: `subgrupo: 'VENDAS'` direto no `defaultValues` (não depende de nenhum efeito rodar na ordem certa).
- Achados construindo um projeto de teste completo (CRM → Orçamentos) a pedido do usuário, especificamente pra achar bugs não cobertos pelos testes anteriores. Publicado Skip 32554, v0.0.329→v0.0.332. **Fluxo ponta a ponta confirmado funcionando**: orçamento `ORC-0021` criado de verdade em produção (rascunho, vinculado ao projeto de teste, nunca enviado/aprovado).

## 2026-08-13 (5)

### Corrigido — achados do teste ao vivo das SPECs 088-096

- **Regressão PostgREST (Separação Parcial)**: a migration da SPEC-090 adicionou `alterado_por` como 2ª FK de `separacoes` para `usuarios`, tornando ambíguo o embed implícito `usuarios(nome)` já usado em `listarParciaisPorVenda` — quebrava o carregamento do histórico de parciais em produção. Não foi pego pelo QA do Skip (build/lint não executam a query real contra o Supabase); só apareceu testando ao vivo no navegador. Corrigido apontando o embed para `usuarios!responsavel_id(nome)`. Publicado Skip 48801, v0.0.21.
- **SPEC-096 incompleta (CRM)**: a correção original só editou `ClientFormFields.tsx`, mas a tela real de editar um cliente já existente (`/contatos/clientes/:id`) usa um componente separado, `ContatoDetail.tsx`, com sua própria lista de campos hardcoded — nunca alcançada pela mudança de v0.0.302. Mesmo reordenamento (Tipo Cliente perto de CPF/CNPJ, RG+Inscrição Estadual adjacentes) aplicado também ali. Publicado Skip 24580, v0.0.303.
- **Gap real (Separação Parcial → Logística, SPEC-089)**: a entrega criada automaticamente nunca recebia endereço — `separacoes.endereco_entrega` não é preenchido em nenhum ponto do fluxo novo, e a tela de Logística (`SeparacaoCardDetails.tsx`) mostrava literalmente "N/A" pro entregador. A SPEC original tinha documentado isso como "comportamento esperado", mas a decisão do usuário só cobria `entregador_id`, nunca o endereço. Corrigido: `finalizar_separacao_parcial_pronta` agora preenche `endereco_entrega`/`telefone` a partir do cadastro do cliente (só quando vazios, nunca sobrescreve). Migration aplicada em produção com autorização explícita.
- Ambos os submodules locais (`separacao-parcial`, `lucenera-crm-3bd29`) sincronizados e commitados.

## 2026-08-13 (4)

### Adicionado — SPECs 090-096: fecha os 12 itens da reunião de 11/08 com Vinícius

- **SPEC-090** (Separação Parcial): botão "Estornar" por separação — devolve o saldo pra reserva, exige motivo, avisa a entrega vinculada (se existir) pelas observações dela. RPC `estornar_separacao_parcial`, colunas `alterado_apos_registro`/`alterado_em`/`alterado_por` em `separacoes`.
- **SPEC-091 + SPEC-093** (Separação Parcial, unificadas): ao confirmar uma separação, abre automaticamente a impressão da lista (cabeçalho venda/cliente/projeto + itens) via `window.print()` — sem lib de PDF nova, resolve as duas SPECs de uma vez.
- **SPEC-092** (Separação Parcial): código da parcial deixa de ser um fragmento de UUID e passa a ser `{numero_venda}-P{n}` — sem migration, só cálculo no frontend.
- **SPEC-094** (Orçamentos): filtro de fornecedor na busca de produto (`ProductSearchModal.tsx`) — marca, categoria e busca por nome/SKU já existiam, só faltava esse.
- **SPEC-095** (Orçamentos): validade do orçamento calculada automaticamente (emissão + 10 dias), recalculada a cada mudança de emissão, com botão pra resetar ao padrão.
- **SPEC-096** (CRM): reorganiza `ClientFormFields.tsx` — Tipo Cliente sobe pra perto de CPF/CNPJ, RG e Inscrição Estadual ficam lado a lado.
- **SPEC-087** (achado, sem código): a trava de "empresa obrigatória" reclamada na reunião já tinha sido resolvida pela SPEC-078, um dia depois da reunião — sem relação documentada até agora.
- Publicado em 4 sistemas: Separação Parcial (Skip 48801, v0.0.20), Orçamentos (Skip 32554, v0.0.328), CRM (Skip 24580, v0.0.302), Compras (SPEC-088, Skip 40326, v0.0.61 — ver entrada anterior).

## 2026-08-13 (3)

### Adicionado — SPEC-089: integração automática Separação Parcial → Logística

- O Matheus precisava reentrar manualmente no sistema de Logística toda vez que terminava uma separação — achado técnico: a automação já existia (trigger `trg_separacao_pronta`, cria `entregas` quando `separacoes.status` vira `'Pronto'`), só que o fluxo novo de Separação Parcial (SPEC-072) nunca mudava esse status, então os dois sistemas continuavam desconectados apesar de compartilharem a mesma tabela.
- Nova RPC `finalizar_separacao_parcial_pronta`: quando a última ação de "Separar" deixa a venda inteira sem saldo em reserva, e o usuário informa uma data de entrega, marca a separação como `Pronto` — reaproveita o trigger existente em vez de duplicar lógica.
- `SeparacaoParcialPage.tsx` ganha campo opcional "Data de entrega (se esta ação completar a venda)".
- Publicado Skip 48801, v0.0.18, QA limpo.

## 2026-08-13 (2)

### Adicionado — SPEC-088: entrada de nota fiscal de compra sem pedido vinculado

- `EntradaNotaFiscal.tsx` (Necessidade de Compra) só liberava o formulário de registro depois de localizar um pedido de compra existente — sem opção pra compras que chegaram fisicamente sem nunca ter passado por um pedido formal.
- Migration `notas_fiscais_compra`: `pedido_compra_id` vira `nullable`, adiciona `fornecedor_id`, `empresa_id`, `produto_id` (todos nullable) + CHECK exigindo `pedido_compra_id` OU `fornecedor_id`.
- Frontend ganha alternância "Tenho o número do pedido" / "Não tenho pedido (entrada avulsa)"; no modo avulso escolhe fornecedor (busca fuzzy já existente) e empresa direto, com produto opcional (pode ser linkado depois).
- Publicado Skip 40326, v0.0.61, QA limpo. Smoke-test da query de embed (2 FKs novas: `fornecedor_id`→`contatos`, `empresa_id`→`empresas`) direto via REST contra produção, sem erro de ambiguidade.

## 2026-08-13 (1)

### Investigação — SPEC-086: cruzamento da reunião com Vinícius (11/08) contra o código real

- Reunião de 11/08/2026 (3 gravações, CRM/Orçamentos + Compras/Separação Parcial/Logística) nunca tinha sido documentada formalmente — vários pontos já tinham virado SPEC nos dias seguintes sem o vínculo registrado.
- 7 itens confirmados já resolvidos (SPEC-064, 075, 077, 079, 080, 081, e uma trava de quantidade que já existia desde a SPEC-072).
- 12 itens confirmados em aberto, cada um documentado como SPEC própria (087 a 096) para implementação item a item.

## 2026-08-12 (9)

### Corrigido — SPEC-085: `hub_pode_executar` negava acesso geral (16 combinações de papel/sistema)

- Débora (papel `compras_e_entregas`) reportou "Acesso negado" ao abrir Necessidade de Compra, apesar de ter `criar/editar/visualizar` corretamente concedidos em `papel_permissoes`.
- Causa raiz real: bug de comparação com NULL em SQL na função `hub_pode_executar`. A checagem `pp.acao = p_acao` nunca é `TRUE` quando `p_acao` é `NULL` — e `p_acao = NULL` é exatamente o que os apps satélite passam ao perguntar "esse usuário tem QUALQUER acesso a este sistema" (gate de tela inteira em `ProtectedRoute`). Como nenhuma linha de `papel_permissoes` desses papéis tinha `acao IS NULL` (só ações específicas), a checagem de acesso geral sempre retornava `false`, silenciosamente.
- Escopo real (query rodada antes do fix): **16 combinações de papel/sistema** afetadas — `administracao_comercial`, `compras_e_entregas`, `equipe_entrega`, `equipe_projetos` em cadastro/necessidade-de-compra/orcamentos/separacao-parcial/logistica/crm. Não era exclusivo da Débora nem de Necessidade de Compra.
- Fix aditivo: `CREATE OR REPLACE FUNCTION hub_pode_executar` adiciona `p_acao IS NULL OR` nas duas checagens (exceção individual e permissão por papel) — amplia só o caso "acesso geral", não muda nenhuma checagem de ação específica já em uso.
- Verificado: acesso geral da Débora e de um segundo papel afetado (Mariane, `equipe_projetos`) confirmados `true` depois do fix; ação não concedida (`aprovar` pra Débora) continua `false`, confirmando que o fix não passou a conceder mais do que o cadastrado.
- Achado à parte: o submodule local `compras-lucenera-3o23t98ee` está desatualizado — não tem a checagem `hasAccess` que já existe no Skip publicado (mesmo padrão de checkout desatualizado já visto antes nesta sessão); não sincronizado, só registrado.
- Aplicado direto no banco de produção (migration `20260812_102_fix_hub_pode_executar_null_acao`) — sem publish no Skip, é uma função de banco, não código de app.

## 2026-08-12 (8)

### Corrigido — SPEC-084 (ajuste 2): logo sobrepondo o nome da empresa no PDF (ex.: ISLIGHT)

- Depois do ajuste do recorte (logo alinhado e maior), usuário reportou que o logo ficou "em cima" do nome da empresa num orçamento da ISLIGHT.
- Causa: `page.drawText` posiciona a BASE do texto em `y`, não o topo — a letra sobe a partir daí pelo ascent da fonte (~7-8pt numa bold de 10pt). Só 5pt de espaço entre a borda inferior do logo e essa base garantia sobreposição matemática; já era assim antes, só ficou visível agora que o logo está maior e mais perto do texto.
- Aumentado o espaço pra 14pt.
- Verificado ao vivo no cenário exato relatado (`ORC-0020`, empresa ISLIGHT): logo e nome da empresa agora com espaçamento limpo.
- Publicado: Orçamentos (Skip 32554, v0.0.326, hash `c4c57bf`), push pro GitHub.

## 2026-08-12 (7)

### Corrigido — SPEC-084 (ajuste): logo do PDF descentralizada e pequena

- Depois de conferir o publish anterior (que corrigiu a ausência do logo), usuário reportou que ele saiu descentralizado e pequeno.
- Causa: o PNG de origem tem ~17-22% de margem transparente simétrica ao redor do conteúdo visível (herdada do uso como ícone de app) — o cálculo de escala do PDF "gastava" parte do tamanho máximo nessa margem vazia, resultando num logo pequeno (~51x40pt) e deslocado do canto onde o texto da empresa começa.
- `pdf-logo.ts` agora recorta o logo via `<canvas>` (bounding box do conteúdo opaco, medido uma vez: região 1262x854 de uma imagem 1920x1512) antes de gerar o base64 — sem precisar subir um novo arquivo PNG pro Skip, o recorte acontece em tempo de execução no navegador. Tamanho máximo no PDF subiu de 140x40 pra 110x50.
- Verificado ao vivo: logo agora sai alinhado (flush) com o texto da empresa logo abaixo e visivelmente maior.
- Publicado: Orçamentos (Skip 32554, v0.0.325, hash `0efa623`), push pro GitHub.

## 2026-08-12 (6)

### Corrigido — SPEC-084: PDF do orçamento com logo, endereço do cliente e Arquiteto Externo

- Usuário reportou 3 faltas no PDF exportado do orçamento (vs. o padrão do fluxo antigo Connect): logo vertical da Lucenera ausente, bloco do cliente sem endereço/CEP/cidade (só mostrava CPF/CNPJ e telefone, ambos "-" pra esse cliente de teste) e "Arquiteto Externo" completamente ausente ao lado de "Vendedor". Anexou 2 PDFs de referência (atual vs. esperado).
- **Causas raiz, todas no gerador (`supabase/functions/generate-report/index.ts`)**: (1) a função já sabia desenhar um logo recebido em `logoBase64`, mas nenhum dos 2 pontos do frontend que a chamam enviava esse parâmetro; (2) a query nunca buscava `endereco/cep/cidade/estado` do cliente, só `telefone/cpf_cnpj`; (3) nem a query nem o desenho tinham qualquer referência a `arquiteto_id` do orçamento, apesar da FK já existir e ser usada em outros pontos do sistema.
- Novo `src/lib/pdf-logo.ts` converte o logo já usado no app pra base64 e é passado nas 2 chamadas existentes. Query da Edge Function ganhou os campos de endereço do cliente, `arquiteto:contatos!orcamentos_arquiteto_id_fkey(nome)` e `projeto:projetos!orcamentos_projeto_id_fkey(codigo)`. Cabeçalho "Orçamento para" passa a mostrar código do projeto + nome do cliente (com guarda contra duplicar quando o nome legado já embute o código — achado ao testar) e um bloco de endereço completo substitui a antiga linha isolada de CPF/CNPJ; nova coluna "Arquiteto Externo" ao lado de "Vendedor".
- Verificado ao vivo em produção via chamada direta à Edge Function (orçamento real `ORC-0018`): endereço/CEP/cidade/telefone e Arquiteto Externo confirmados corretos no PDF baixado e lido. Logo confirmado indiretamente (PDF cresceu de ~2,9KB pra ~44,5KB ao enviar o logo, consistente com a imagem embutida) — não confirmado visualmente por bloqueio de downloads repetidos na automação do navegador (limitação da sessão, não do código).
- **Achado à parte, não corrigido aqui**: `envio-inicial-cliente.ts`/SPEC-067 (download automático + `mailto:` no envio inicial ao cliente) existe no GitHub mas nunca foi publicado no Skip — o `DraftBudgetsTab.tsx` de produção ainda usa o fluxo antigo (só copia link). Ficou de fora do escopo desta SPEC.
- Publicado: Orçamentos (Skip 32554, v0.0.324, hash `536ef7b`), push pro GitHub.

## 2026-08-12 (5)

### Adicionado — SPEC-083: aba "Gerenciamento" (admin/gerente) — lucro por peça e desconto simulado

- Usuário pediu uma aba nova, só pra admin/gerente, acessível via menu "⋮" no cabeçalho do orçamento (criação e edição), mostrando todas as peças com valor de venda, valor de custo, lucro e lucro % — com um campo de desconto simulado que recalcula tudo em tempo real, pra decidir "posso dar 15% de desconto e ainda ter lucro?" antes de negociar com o cliente.
- Investigação prévia: já existia o padrão `role === 'admin' || role === 'gerente'` reaproveitado do botão "Aprovar Financeiro"; `produtos` já tinha `preco_custo` (não usado em nenhuma query do formulário até agora); peças avulsas ("Adicionar Item não Cadastrado") não têm custo cadastrado em lugar nenhum.
- 4 decisões confirmadas com o usuário antes de implementar: painel em Dialog (não sai do formulário); peças avulsas aceitam custo manual só pra simulação (nunca salvo); desconto simulado tem botão "Aplicar ao orçamento" que preenche o Desconto Global de verdade; acesso admin+gerente (não só admin).
- Novo componente `GerenciamentoDialog.tsx`: busca `preco_custo` só dos produtos presentes no orçamento, calcula lucro/lucro% por linha e total, sem persistir nada além do que já existia.
- Sem migration, sem mudança de RLS — controle de acesso 100% no frontend.
- **Não verificado ao vivo na UI**: a conta de teste da sessão tem role `viewer`, não vê o menu — validação ficou restrita a build/tsc/oxlint/QA do Skip; recomendado teste real por alguém com role admin/gerente.
- Publicado: Orçamentos (Skip 32554, v0.0.322, hash `32bbecb`), push pro GitHub.

## 2026-08-12 (4)

### Corrigido — SPEC-082: Vencimento de parcelas mensal por padrão, com edição individual

- Usuário reportou que, ao gerar um orçamento com Boleto/3 parcelas, os "vencimentos calculados" mostrados (14/08, 17/08, 20/08) ficaram espaçados em 3 dias em vez de 1 mês, sem nenhum campo pra editar — a data era só um texto informativo.
- **Causa raiz**: `prazo_pagamento_dias[i] = prazoDias * (i + 1)`, onde `prazoDias` = dias entre hoje e a "Data de Início do Pagamento" escolhida (SPEC-002, antiga) — reproduzia o padrão manual do Connect, mas gerava espaçamento arbitrário entre parcelas (coincidentemente igual ao prazo até a 1ª parcela) em vez de intervalos mensais.
- Corrigido pra: cada parcela a partir da 2ª vence, por padrão, 1 mês após a anterior (`addMonths`). Novo bloco "Vencimentos das demais parcelas" mostra um seletor de data individual por parcela, pré-preenchido com o padrão, editável — a pessoa que negocia com o cliente pode sobrescrever qualquer vencimento, com link "Usar padrão (1 mês)" pra reverter.
- Cada vencimento calendário (padrão ou manual) é convertido num offset em dias antes de submeter — preserva o contrato que o backend (`aprovar_orcamento_financeiro`) já espera (offsets em dias a partir da data de aprovação, não da criação — arquitetura pré-existente, não revista aqui). Ao editar um orçamento existente, os vencimentos calendário de cada parcela são reconstruídos a partir dos offsets salvos.
- Sem migration — só mudou a fórmula que gera os offsets no frontend.
- Verificado ao vivo em produção (Boleto, 3 parcelas, início 14/08 → parcela 2 = 14/09, parcela 3 = 14/10); a interação por clique/screenshot da automação de navegador ficou instável nesta sessão, contornada disparando eventos de ponteiro via JavaScript direto no DOM.
- Publicado: Orçamentos (Skip 32554, v0.0.321, hash `f30d991`), push pro GitHub.

## 2026-08-12 (3)

### Corrigido — SPEC-081: Cliente/Vendedor não autopreenchiam, cliente sumia da busca, Arquiteto virou obrigatório

- Usuário reportou 3 bugs no "Novo Orçamento" (Cliente e Vendedor não autopreenchiam ao selecionar projeto; cliente cadastrado — "Vinicius Bortolin" — não aparecia na busca) + 1 observação (Arquiteto(s) do formulário de projeto no CRM ficou obrigatório, deveria ser opcional).
- Análise estática (leitura de código, RLS como `authenticated`, contagem de linhas) não encontrava defeito nenhum — o código parecia correto e o dado no banco também. Causa só apareceu com reprodução ao vivo no navegador (login manual do usuário, já que a automação não pode digitar senha) e inspeção do estado React: o array `clientes` tinha exatamente 1000 linhas.
- **Causa raiz real (Bugs 1 e 3)**: o PostgREST do projeto trunca silenciosamente qualquer resposta em 1000 linhas (`db-max-rows`, padrão da plataforma), mesmo com `.limit(50000)` pedido no código. Como a query de clientes ordena por `codigo_legado DESC NULLS LAST`, qualquer cliente sem código legado (cadastrado direto no sistema novo) cai depois do corte e some do array inteiro — tanto do autopreenchimento quanto da busca. Mesmo problema afetava `projetos` (3703 linhas reais, 2703 invisíveis) e `produtos` (4726 reais, 3726 invisíveis, embora esse array só alimente matching de XML). `use-options.ts` (Orçamentos) ganhou paginação via `.range()` em loop pras 3 queries afetadas.
- **Causa raiz (Bug 2, Vendedor)**: `handleProjectSelect` ainda usava a lógica pré-SPEC-077 (`responsavel_obra_id`/`responsavel_id` — campos de Engenheiro/FK morta), nunca atualizada pra usar `responsavel_funcionario_id` (coluna nova da SPEC-077, horas antes). Reescrito pra resolver, em ordem: `responsavel_funcionario_id` → nome (`responsavel_nome` contra `funcionarios.nome`, match parcial já que o texto legado é só o primeiro nome) → usuário logado.
- **Observação (Arquiteto obrigatório)**: reverte uma exigência introduzida horas antes na SPEC-077 do mesmo dia (a pedido de uma tarefa anterior) — removido `.min(1)` do schema (`ProjectNew.tsx`) e o guard de toast equivalente (`ProjectDetail.tsx`), mantendo a validação de soma=100% só quando a lista não está vazia.
- Verificado ao vivo: projeto "26.250 - vinicius teste" → Cliente e Vendedor autopreenchem corretamente, "Vinicius Bortolin" aparece na busca.
- Publicado: Orçamentos (Skip 32554, v0.0.320, hash `9f1d7a6`) e CRM (Skip 24580, v0.0.301, hash `7edd387`), push pro GitHub nos dois submodules.
- Achado sistêmico não resolvido nesta SPEC: o teto de 1000 linhas do PostgREST é config de projeto Supabase, provavelmente afeta outros sistemas com `.limit()` acima de 1000 sem paginar — decisão de levantar o `db-max-rows` global ou auditar sistema por sistema fica pra depois.

## 2026-08-12 (2)

### Adicionado — SPEC-080: múltiplos L's dentro do modal "Buscar Produtos"

- Usuário pediu explicitamente uma peça com **array de L's** (`{codigo_l, quantidade}[]`), com migration convertendo o L antigo em "array com 1 item" — exatamente a arquitetura rejeitada horas antes na SPEC-079, quando o usuário confirmou "linhas separadas sem mudar o banco" depois do achado de que `projeto_itens.orcamento_item_id` + `l_fixo` já rastreiam cada L por linha em todo o pipeline de estoque/entrega futura/necessidade de compra.
- Apontado o conflito antes de implementar: todos os critérios de aceitação (painel expansível, múltiplos L's por peça, várias peças ao mesmo tempo, validações, soma em tempo real) davam pra entregar sem mudar o banco — só levando a experiência de múltiplos L's (que já existia desde a SPEC-079, num diálogo separado) pra **dentro do próprio modal "Buscar Produtos"**. Usuário confirmou manter linhas separadas.
- `ProductSearchModal.onConfirm` muda de assinatura: de uma lista achatada (`ProductSearchItem[]`, 1 entrada por linha) para `ProductSelectionEntry[]` (`{product, entries: LEntry[]}[]`) — cada peça marcada ganha um painel inline (reaproveita o `LQuantityRepeater` da SPEC-079) que expande logo abaixo da linha, suportando múltiplas peças com L's ao mesmo tempo na mesma busca.
- Validação por peça: L vazio, quantidade ≤ 0 ou código duplicado **na mesma peça** bloqueiam a confirmação (toast identificando a peça); o mesmo L em peças diferentes continua permitido (validação não é global).
- O diálogo separado `MultiLAddDialog` (SPEC-079) continua existindo, mas passa a ser usado só por "Adicionar Item não Cadastrado" (que não passa pelo modal de busca).
- Segundo consumidor do `ProductSearchModal` (`EditableBudgetItemsTable.tsx`, tela de edição de itens na Aprovação Financeira) só recebeu ajuste de tipo pra continuar compilando — mantém o comportamento pré-existente (usa só a primeira peça selecionada, ignora L's coletados); não fazia parte do pedido e tem um modelo de dados de itens diferente.
- Sem migration de banco, sem mudança de PDF (já imprime uma linha por L desde a SPEC-078/079).
- Publicado: Orçamentos (Skip 32554, v0.0.318, hash `51d7067`), push pro GitHub (`7e58f63..4c8af35`).

## 2026-08-12 (1)

### Corrigido — SPEC-078: 4 bugs no módulo de Novo Orçamento

- Usuário pediu correção de 4 bugs, cada um com investigação obrigatória antes de corrigir (MCP do Skip estava desconectado nesta rodada — implementação feita local, publicada depois que reconectou).
- **Bug 1 (typo "Residential")**: campo Tipo de Projeto tinha valor interno em inglês em 2 lugares (`ProjectCreateModal.tsx` no Orçamentos, `ProjetoFormDialog.tsx` no Cadastro). Achado durante a correção: existia uma CHECK constraint real no banco (`check_tipo_projeto_valido`) que só permitia `'Residential'` — não era só um valor de seed. Migration `20260812_101` recria a constraint com `'Residencial'` e corrige a única linha existente com o valor antigo.
- **Bug 2 (cliente inline não linkava/não aparecia na busca)**: não encontrada causa determinística via leitura estática (fluxo parecia correto) — aplicado fix defensivo: cliente novo agora é injetado direto no state local (`setClientes`) em vez de depender só do round-trip de `fetchClientes()`, eliminando qualquer corrida entre criação e refetch.
- **Bug 3 (perfil da empresa no topo)**: não existia esse componente no código (nem condicionado a itens, nem incondicional) — criado um bloco novo (nome/razão social/endereço/telefone + logo) sempre visível ao escolher a Empresa, na seção "Informações Gerais".
- **Bug 4 (ordem do cálculo)**: achado mais sério que uma simples troca de ordem — o backend (`aprovar_orcamento_financeiro`) nunca deduzia o sinal ao gerar parcelas (dividia o valor cheio), e o PDF nunca mostrava o sinal. Consulta ao banco: só 1 orçamento em produção tem sinal>0, e esse ainda não tinha sido processado — **zero necessidade de recálculo retroativo**. Corrigido calculando `subtotal -> sinal -> desconto (+frete)` uma única vez no frontend, salvo em `valor_total`; a RPC de aprovação não precisou de nenhuma mudança de código porque já lê esse campo. PDF ganhou a linha "Sinal" e passou a respeitar `desconto_tipo` (antes mostrava o número cru de um desconto percentual como se fosse R$).
- Publicado: Orçamentos (Skip 32554, v0.0.317, hash `0e3786a` — teve uma correção extra depois do publish inicial porque um bloco do Bug 2 ficou faltando no primeiro patch) e Cadastro (Skip 36668, v0.0.60, hash `d95b247`).

### Adicionado — SPEC-079: múltiplos L's por peça + remoção do botão "Adicionar Item"

- Usuário pediu suporte a vários códigos "L" (identificador de luminária/circuito) por peça, cada um com sua própria quantidade, e a remoção do botão redundante "Adicionar Item".
- Achado técnico decisivo (confirmado no schema real do banco): `projeto_itens.orcamento_item_id` + `l_fixo` provam que cada L já é rastreado por linha em todo o pipeline de estoque/entrega/necessidade de compra — não por peça agregada. Por isso a implementação **não mudou o banco**: "múltiplos L's por peça" virou "várias linhas independentes geradas de uma vez" via um diálogo guiado (`MultiLAddDialog` + `LQuantityRepeater`), sem tocar RPC de aprovação nem PDF (que já imprime uma linha por item).
- Confirmado por leitura de código (não só pela palavra do usuário): "Adicionar Item" e "Adicionar Item não Cadastrado" eram literalmente o mesmo `onClick`, 100% redundantes. Removido o primeiro; o segundo agora abre o mesmo diálogo de múltiplos L's usado por "Buscar Produtos" quando só 1 produto é selecionado.
- Publicado junto com a SPEC-078, mesma versão (Orçamentos v0.0.317, hash `0e3786a`).

## 2026-08-11 (11)

### Adicionado — SPEC-077: Arquitetos múltiplos com % + Responsável vinculado a Funcionários (CRM + Orçamentos)

- Usuário pediu (tarefa formal, com 7 perguntas obrigatórias antes de codar): campo "Responsável" do projeto vira FK real para `funcionarios` (com cadastro inline, sem sair da tela); campo "Arquiteto" (projeto e orçamento) vira seleção múltipla com percentual de divisão de lucro, soma validada em 100% antes de salvar.
- Respostas do usuário às perguntas de escopo: só Arquiteto ganha percentual/múltiplos (Engenheiro e Responsável continuam vínculo único); Responsável continua seleção única (só troca de texto livre pra FK).
- **Achado crítico que mudou o desenho**: o texto livre `responsavel_nome` não é só um label — alimenta o trigger `fn_sync_equipe_por_responsavel` (`BEFORE UPDATE OF responsavel_nome`), que resolve a equipe do projeto em `equipes_projetos` e alimenta `vw_comissao_mensal`. Um trigger encadeado que setasse `responsavel_nome` por trás do novo campo FK não dispararia essa cláusula `OF` — solução foi o frontend gravar os dois campos juntos, sempre, no mesmo INSERT/UPDATE (nome vem do funcionário selecionado no dropdown).
- Migrations `20260811_100` (5 arquivos, todas aditivas — 2 tabelas de junção `projeto_arquitetos`/`orcamento_arquitetos`, 1 coluna `projetos.responsavel_funcionario_id`, 2 RPCs `SECURITY DEFINER` `replace_projeto_arquitetos`/`replace_orcamento_arquitetos`, backfill) aplicadas no Supabase real com autorização explícita do usuário. Backfill: 2272 projetos e 20 orçamentos migrados de `arquiteto_id` singular para a tabela de junção (100% cada, sem ambiguidade).
- **Bug de segurança real encontrado e corrigido durante smoke-test**: `replace_projeto_arquitetos` tinha um guard de permissão `IF NOT (role IN (...) OR hub_pode_executar(...))` que, quando `v_user_role` era SQL `NULL` (sessão sem `auth.uid()` válido), avaliava `NULL OR false = NULL` → `NOT NULL = NULL` → `IF NULL` é tratado como falso pelo PL/pgSQL, pulando silenciosamente a exceção esperada. Descoberto testando a RPC com um UUID falso antes de confiar nela; corrigido envolvendo a expressão inteira em `COALESCE(..., false)`. A RPC irmã (`replace_orcamento_arquitetos`, guard de condição única) não tinha esse problema.
- Responsável e ao menos 1 arquiteto passam a ser obrigatórios ao criar projeto no CRM (`salvar-projeto` + `ProjectDetail.tsx`) — requisito explícito da tarefa, mudança de comportamento em relação ao anterior (ambos opcionais). Em Orçamentos, arquiteto continua opcional (só valida soma=100% quando preenchido) — não fazia parte do pedido tornar obrigatório ali.
- CRM (7 arquivos: `use-auth.tsx`, `ArchitectSplitPicker.tsx` novo, `NewEmployeeModal.tsx` novo, `projetos.ts`, `salvar-projeto/index.ts`, `ProjectNew.tsx`, `ProjectDetail.tsx`) — `ProjectDetail.tsx` precisou ser resincronizado do Skip antes de editar (checkout local desatualizado, mesmo padrão recorrente desta sessão). Publicado: CRM (Skip 24580, v0.0.299, hash `761f086`), push pro GitHub (`6617894..d4308cf`).
- Orçamentos (3 arquivos: `ArchitectSplitPicker.tsx` novo — construído sobre `SearchableSelect` já existente, diferente do Popover+Command do CRM —, `useBudgetStore.ts`, `BudgetFormPage.tsx`) — auto-vínculo legado por nome do arquiteto do projeto (SPEC-061) adaptado pra popular o split inteiro quando o projeto já tem `projeto_arquitetos`, ou 1 linha de 100% no fallback por nome ambíguo. Publicado: Orçamentos (Skip 32554, v0.0.313, hash `0f15c81`), push pro GitHub (`78b0d9b..7ceb779`).
- Pendência sinalizada, não implementada: backfill de `responsavel_funcionario_id` a partir de `responsavel_nome` (texto livre, ~15 nomes distintos) — ambíguo demais pra automatizar com segurança, fica como revisão manual futura.

## 2026-08-11 (10)

### Adicionado — SPEC-076: voltar em todos os status do funil de Orçamentos

- Usuário pediu: em qualquer status do orçamento, poder voltar para a instância anterior (mesma lógica de "aprovar ou não, podendo voltar para revisão").
- Funil mapeado: `rascunho -> enviado_cliente -> Aprovação da Equipe -> Aprovação Financeira -> Orçamento Aprovado`. Dois retornos já existiam (rascunho↔enviado_cliente, via `voltar_orcamento_rascunho`; Aprovação da Equipe→enviado_cliente, via `equipe_devolver_orcamento_cliente`, SPEC-031). Faltavam dois degraus.
- **Aprovação Financeira → Aprovação da Equipe**: RPC nova `financeiro_devolver_orcamento_equipe` — flip de status simples, nenhum side-effect existe ainda nesse ponto do funil. Botão "Devolver para Equipe" em `FinancialApprovalTab.tsx`.
- **Orçamento Aprovado → Aprovação Financeira**: o mais arriscado — `aprovar_orcamento_financeiro` já criou `projeto_itens`, `projeto_parcelas`, `boletos` e reservou estoque real (`estoque_itens.quantidade_reservada`). Decisão do usuário: RPC nova `desfazer_aprovacao_financeira` apaga tudo que foi criado por essa aprovação e estorna a reserva, mas **bloqueia** (não apaga nada, `RAISE EXCEPTION` explicando o motivo) se algo já foi consumido a jusante — boleto pago/remessado, nota fiscal emitida, retorno bancário registrado, transação lançada, devolução/separação/transferência de estoque, ou item usado como origem de pedido de compra ou de outro orçamento de devolução. Restrito a admin/gerente. Não suporta orçamentos de devolução (natureza_operacao='devolucao') — fora de escopo. Botão em `BudgetTableRow.tsx` (cobre a aba "Aprovados" e "Todos").
- Achado importante durante o levantamento: a migration da SPEC-031 (18/07) nunca atualizou o CHECK constraint `orcamentos_status_check` para permitir o valor `'Aprovação da Equipe'` que ela mesma introduziu — bug já corrigido nesta mesma sessão (ver entrada anterior do changelog, migration `20260811_098`), mas documentado aqui porque foi descoberto durante esta investigação.
- Migrations `20260811_099` (2 arquivos, aditivas — só criam função nova) aplicadas no Supabase real com autorização explícita do usuário.
- Publicado: Orçamentos (Skip 32554, v0.0.312, hash `3d9816f`), QA limpo, push pro GitHub (`365e827..78b0d9b`).
- Pendência sinalizada ao usuário, não implementada: reversão de aprovação financeira de orçamentos de **devolução** (ramo separado de `aprovar_orcamento_financeiro`, que chama `registrar_devolucao_projeto_item` sobre item de origem em vez de criar `projeto_itens` novo) — exigiria lógica própria.

## 2026-08-11 (9)

### Corrigido — Orçamentos: "Aprovar Manualmente" quebrado + "Voltar para Rascunho" ausente

- Usuário reportou erro ao aprovar manualmente: `new row for relation "orcamentos" violates check constraint "orcamentos_status_check"`.
- Causa raiz: a migration `20260718_050` (SPEC-031, "Aprovação da Equipe") criou as RPCs de aprovação do cliente (`aprovar_orcamento_cliente_manual`, `aprovar_orcamento_cliente_publico`, `aprovar_orcamento_cliente`, `adm_aprovar_pelo_cliente`, `cliente_aprovar_orcamento`) fazendo `status = 'Aprovação da Equipe'`, mas nunca atualizou o CHECK constraint `orcamentos_status_check` da tabela pra permitir esse valor. Toda aprovação de cliente (manual, por token público ou pelo admin) vinha quebrando desde 18/07 — achado grave que passou despercebido ~3 semanas.
- Corrigido via migration aditiva `20260811_098_fix_orcamentos_status_check_aprovacao_equipe` (autorizada explicitamente pelo usuário antes de aplicar em produção): amplia a lista de status permitidos, nenhum dado muda.
- Achado 2 (mesmo relato do usuário): o botão "Voltar para Rascunho" (SPEC-070, RPC `voltar_orcamento_rascunho` já existia e funcionava no banco) tinha sumido da tela — a UI (`ClientApprovalTab.tsx`, `BudgetTableRow.tsx`) já referenciava `voltarOrcamentoRascunho` da store, mas esse método nunca foi implementado em `useBudgetStore.ts` nem publicado no Skip; feature ficou pela metade num checkout local anterior. Implementado o método na store (chama a RPC existente) e publicado.
- Achado 3 (fora de escopo, sinalizado mas não publicado): o checkout local de `BudgetTableRow.tsx` também tinha uma automação de e-mail/PDF no envio inicial (SPEC-067, usa `src/lib/envio-inicial-cliente.ts`) nunca publicada — feature maior e com efeito colateral real (envio de e-mail), deixada de fora deste fix por não fazer parte do pedido do usuário.
- Publicado: Orçamentos (Skip 32554, v0.0.311, hash `2322fcd`), QA limpo, push pro GitHub (`76d3e54..365e827`).

## 2026-08-11 (8)

### Corrigido — CRM: erro ao salvar projeto sem mensagem real (edge function `salvar-projeto`)

- Usuário reportou: ao tentar salvar um projeto, aparecia o erro genérico "a função de borda retornava um código de status que não era 2xx".
- Causa raiz: `supabase-js` sempre expõe `error.message` como esse texto fixo em falhas de `functions.invoke()` — o corpo real da resposta HTTP (com a mensagem de validação/erro do Postgres) fica em `error.context` e nunca era lido em `ProjectNew.tsx`, escondendo o motivo real de qualquer usuário e de quem for depurar depois.
- Testado diretamente contra a edge function em produção: payload válido funciona (200); código de projeto já existente retorna 500 com `"duplicate key value violates unique constraint \"projetos_codigo_key\""` no corpo — esse é o cenário mais provável do erro relatado, já que o formulário sugere automaticamente o "próximo código" incrementando o último criado, o que pode colidir quando a sequência tem furos (códigos legados importados fora de ordem).
- Corrigido: `ProjectNew.tsx` agora lê `error.context.json()` e usa a mensagem real no toast; `salvar-projeto/index.ts` passou a detectar especificamente a violação da constraint de código único (Postgres `23505`) e devolver `"Este código de projeto já está em uso. Escolha outro código."` em vez do erro cru do banco.
- Achado lateral (mesmo padrão desta sessão): `ProjectNew.tsx` local estava desatualizado — faltava a validação real de `cliente_id` obrigatório (SPEC-061, usava `.refine()` em produção contra um `min(1)` bugado localmente) e o filtro `.is('empresa_id', null)` no fetch de arquitetos (SPEC-044). Resincronizado do Skip antes de aplicar o fix.
- Publicado: CRM (Skip 24580, v0.0.298, hash `e232a09`), verificado em produção via chamada direta à edge function (mensagem amigável confirmada), push pro GitHub (`ddc3dee..6617894`).

## 2026-08-11 (7)

### Adicionado — CRM: Engenheiro ganha "Pessoas da Empresa" (paridade com Arquiteto)

- Pedido: campo de Novo Engenheiro deveria funcionar igual Arquiteto, permitindo adicionar mais de uma pessoa (CPF/CNPJ) vinculada à empresa engenheira.
- Generalizado o padrão da SPEC-044 (antes exclusivo de Arquiteto): `Engenheiros.tsx` ganhou a mesma seção "Pessoas da Empresa (opcional)" na criação (array dinâmico nome/data_nascimento/email/cpf_cnpj/endereco, insert em lote com `empresa_id` após criar o registro principal, navegação pra página de detalhe).
- `ContatoDetail.tsx` generalizado: `TIPOS_COM_PESSOAS` (antes hardcoded só pra arquiteto) agora é `['arquiteto', 'engenheiro']`; `fetchPessoas`, o insert de nova pessoa e a navegação de cada linha passaram a usar o tipo dinamicamente em vez de `'arquiteto'` fixo.
- Achado (3ª vez na mesma sessão): checkout local do CRM estava incompleto — `ContatoDetail.tsx` e `Fornecedores.tsx` não existiam localmente, e `App.tsx` local não tinha o gate RBAC (`hasAccess`) nem as rotas desses 2 arquivos. Resincronizado do Skip antes de editar.
- Publicado: CRM (Skip 24580, v0.0.297, hash `182a18c`), QA limpo, push pro GitHub (`928aac6..ddc3dee`).

## 2026-08-11 (6)

### Adicionado — SPEC-075: preenchimento automático de CEP/CNPJ (Orçamentos, CRM, Compras)

- Pedido genérico de "adicionar ao projeto" preenchimento automático de endereço via CEP e dados de empresa via CNPJ — perguntado em quais dos 10 sistemas isso deveria entrar. Resposta: Compras (fornecedores), Orçamentos (modal de cliente), CRM (cadastro de clientes/contatos).
- Achado: Orçamentos e CRM já tinham essa busca implementada inline (SPEC-052/061), sem fallback/debounce/cache/loading — refatorado pra versão completa. Compras não tinha nenhum formulário de fornecedor — criado do zero (`FornecedorModal.tsx` + `services/fornecedores.ts`, gravando em `contatos` + `contato_tipos`).
- `cepService.ts` (ViaCEP + fallback BrasilAPI) e `cnpjService.ts` (BrasilAPI + fallback ReceitaWS), cada um com cache em memória, mais `hooks/use-document-lookup.ts` (debounce 300ms + loading) — replicados como cópia própria nos 3 sistemas.
- Achado crítico ao publicar (mesmo padrão da SPEC-073/074): `ClientCreateModal.tsx` real no Skip tinha features inteiras ausentes do checkout local (SPEC-052 `tipo_cliente`, SPEC-061 `complemento`, e-mail obrigatório, Vendedor via `funcionarios`). Refeito em cima do conteúdo real antes de publicar, verificado byte-a-byte.
- Publicado: Orçamentos (Skip 32554 v0.0.310), CRM (Skip 24580 v0.0.296), Compras (Skip 40326 v0.0.60), todos com QA limpo e push pro GitHub.
- Detalhes completos em SPEC-075.

## 2026-08-11 (5)

### Corrigido — SPEC-073 e SPEC-074 publicadas no Skip (achado grave evitado)

- MCP do Skip reconectou; ao publicar as mudanças pendentes (SPEC-073 Duplicatas e SPEC-074 Tipo de Operação), descoberto que os checkouts locais dos 2 submodules estavam desatualizados em relação ao que já estava em produção — não só faltando features minhas, mas **tendo menos** do que o Skip real (SPEC-069 RBAC gate ausente em Administração Bancária; SPEC-071 Venda/Devolução completa ausente em Orçamentos).
- Se tivesse publicado direto por cima, teria apagado o gate de acesso (`hasAccess`) de Administração Bancária e a funcionalidade inteira de Devolução (modal de busca de venda de origem, `DevolucaoItemSearchModal`, `devolucoesService.ts`) de Orçamentos.
- Corrigido: buscado o conteúdo real via `skip_file_read`, mesclada a extensão de cada SPEC em cima do código real (não do checkout local desatualizado), verificado por diff byte-a-byte antes de aplicar. `npm run build` limpo + QA do Skip limpo em ambos.
- Publicado: Administração Bancária (Skip `36395` v`0.0.62`) e Orçamentos (Skip `32554` v`0.0.309`), ambos com push pro GitHub.
- Detalhes completos em SPEC-073 e SPEC-074.

## 2026-08-11 (4)

### Adicionado — SPEC-074: Tipo de Operação (Outros/SAC) + campo Tipo com subgrupos (Orçamentos)

- Usuário pediu 2 tipos novos ("Outros" e "SAC") no toggle da tela de Orçamento, ao lado de "Venda"/"Devolução", e um campo "Tipo" (dropdown) com subgrupos fixos dependentes do tipo selecionado.
- Achado antes de codar: o toggle Venda/Devolução da SPEC-071 nunca chegou de fato ao checkout local do submodule `gestão-financeira-clone-544cb` — só existia a coluna `natureza_operacao` no banco, zero uso no frontend (`grep` não achou nada). Sinalizado ao usuário; optou por implementar do zero neste checkout, com os 4 tipos já incluídos.
- Achado 2: `natureza_operacao` tinha `CHECK` restrito a `'venda'`/`'devolucao'`, e não existia coluna nenhuma pra guardar o subgrupo. Sinalizado; usuário autorizou ampliar o `CHECK` pra 4 valores e criar a coluna `subgrupo text` (migration `20260811_097_orcamento_tipo_operacao_outros_sac`, aditiva).
- Implementado em `BudgetFormPage.tsx`: novo Card "Tipo de Operação" com toggle de 4 botões (ícone + label) e Select "Tipo" cujas opções mudam conforme o tipo — troca de tipo reseta o subgrupo. Bug cosmético do Radix Select (trigger ficava em branco pro tipo SAC, que só tem 1 opção, até o usuário abrir o dropdown uma vez) corrigido trocando por um campo fixo somente-leitura quando há só 1 opção.
- `aprovar_orcamento_financeiro()` só tem ramo pra `devolucao` — `outros`/`sac` caem no ramo "venda" por padrão na aprovação financeira; fora de escopo desta rodada (só interface), sinalizado na SPEC-074.
- Testado com usuário de teste descartável (criado e apagado na mesma sessão) nos 4 tipos. Build/typecheck limpos. Commitado localmente no submodule — Skip desconectado durante a sessão, publish/push pendente.

## 2026-08-11 (3)

### Corrigido/Adicionado — Reconciliação do Plano de Contas (Apropriação, nível 3)

- Usuário colou a lista oficial de ~116 categorias de "Apropriação" pra bater com o que existe no banco (103 registros em `plano_de_contas` nível 3). Comparação feita com normalização de acentos (Unicode NFKD) pra separar diferenças cosméticas de diferenças reais.
- Achado crítico: todas as 27 categorias que só existiam no banco (e não na lista do usuário) têm lançamentos reais vinculados via `negociacoes.plano_contas_id` (de 1 a 2261 registros cada) — nenhuma órfã. Nenhuma foi removida.
- Migration `20260811_096_reconciliacao_plano_contas_apropriacao`: 23 `UPDATE` (renomeia mantendo o `id`, zero impacto em lançamentos vinculados — 17 só acento, 6 grafia/pontuação com mesmo conceito confirmadas com o usuário) + 34 `INSERT` (categorias novas da lista do usuário, `parent_id`/Sub Grupo escolhido por semelhança com os itens irmãos já existentes, faixa `codigo_connect` 90000001+ reservada pra itens que não vêm do sistema legado Connect).
- Não criado "DÉCIMO TERCEIRO" como categoria nova — é sinônimo de "13º SALÁRIO" (só renomeado), evitando duplicar a mesma despesa em dois lugares.
- Usuário sinalizou querer, no futuro, uma forma dos próprios usuários cadastrarem Grupo/Sub Grupo/Apropriação pela interface — não implementado nesta rodada, fica como ideia para SPEC futura.

## 2026-08-11 (2)

### Adicionado — SPEC-073: telas Cadastrar Duplicatas e Baixar Duplicata (Administração Bancária)

- Usuário pediu ajustes de "interface" em 3 telas do módulo de Duplicatas com uma especificação bem detalhada. Investigação encontrou que a spec descrevia o sistema legado Connect (bate quase campo-a-campo com `staging_conta_pagar`/`staging_conta_receber`) — 2 das 3 telas (Baixar Duplicata, Cadastrar Duplicatas) não existiam, e vários campos não tinham coluna no banco. Reportado ao usuário antes de codar; usuário autorizou construir as telas e adicionar as colunas.
- Migration `20260811_095_spec073_duplicatas_cadastro_baixa`: 10 colunas novas em `boletos` (apropriacao_id, conta_bancaria_id, forma_pagamento, bandeira, linha_digitavel, juros_multa, desconto, responsavel_id, referencia, conta_grupo_id, observacao), todas aditivas. Aplicada no Supabase real.
- 2 telas novas + botões Editar/Exportar ligados em Consultar Duplicatas. 3 botões (Executar/Acordo/Info) sinalizados como pendentes — sem regra de negócio definida em lugar nenhum do sistema.
- Detalhes completos em SPEC-073.

## 2026-08-11 (1)

### Corrigido/Adicionado — Cadastro Lucenera: duplo-clique na peça + layout do formulário

- Duplo-clique numa linha da tabela de Peças agora abre a edição direto (antes só selecionava, precisava clicar em "Editar" no painel lateral). Usuário pediu para virar padrão nos outros sistemas também — aguardando lista de telas específicas.
- Formulário de peça: "Dados Básicos", "Engenharia de Custos" e "Dados Fiscais" agora ficam empilhados na vertical (mesmas cores de borda de cada seção); "Estoque Integrado" continua como card lateral.
- Usuário reportou que o empilhamento sozinho ainda deixava scroll no formulário — campos que ocupavam a linha inteira sozinhos (Marca, Categoria, Fornecedor, Unidade, % ICMS, Máscara/Família, Status Comercial, Ativo) foram reagrupados em pares lado a lado, reduzindo a altura total sem tirar nenhum campo.
- Publicado (Skip `36668` v`0.0.58`), sincronizado com o GitHub.

## 2026-08-10 (10)

### Corrigido — SPEC-069: SSO da Central bugava em todos os 8 sistemas satélite

- Usuário reportou que clicar em qualquer sistema a partir da Central "bugava" e voltava pra tela de login. Reproduzido ao vivo com usuário de teste descartável.
- Dois bugs pré-existentes com o mesmo sintoma: 5 sistemas (Dashboard Financeiro, Cadastro, Necessidade de Compra, Sistema de Entregas, Separação Parcial) nunca implementavam o consumo do código SSO; os outros 3 (Administração Bancária, CRM, Orçamentos) tinham uma race condition entre `onAuthStateChange` e a troca assíncrona do código, resolvendo "sem login" antes da troca terminar.
- Corrigido nos 8: criado `cross-system-auth.ts` onde faltava, resolução de sessão agora espera a troca do SSO terminar antes de decidir "logado ou não". QA limpo, publicado em produção, sincronizado com o GitHub de cada submodule.

## 2026-08-10 (9)

### Corrigido — SPEC-069: Dashboard Financeiro restrito a Filippo, Pedro e Vinícius

- Usuário reportou que ninguém conseguia acessar o Dashboard Financeiro e pediu acesso exclusivo pra essas 3 pessoas. Causa raiz: só o papel `admin_geral` (só o Vinícius) tinha permissão nesse sistema — Filippo e Pedro só tinham o campo legado `usuarios.role`, não usado pelo RBAC novo.
- Migration `20260810_094_dashboard_financeiro_acesso_restrito`: papel dedicado `dashboard_financeiro_acesso`, atribuído só aos 3. Verificado: exatamente 3 de 11 usuários com acesso.
- A aba "Matriz de Acesso" do Hub (`/admin`) já permite administrar isso (marcar/desmarcar papéis por usuário) — não precisou de UI nova.

## 2026-08-10 (8)

### Corrigido — posição do card Separação Parcial no Hub

- Usuário pediu que "Separação Parcial" apareça no Hub logo após "Administração Bancária" e antes de "Sistema de Entregas". Migration `20260810_093_spec072_hub_reorder_separacao_parcial` reordenou `public.systems.display_order` (Hub é 100% data-driven, sem deploy de código necessário).
- De quebra, corrigida a URL da própria linha `hub` em `public.systems`, que tinha o mesmo domínio quebrado (`central-lucenera.goskip.app`) corrigido no item anterior — não aparece como card mas ficou inconsistente.

## 2026-08-10 (7)

### Corrigido — CRM: "Fornecedores" sumiu do menu + URL errada do botão Central

- Usuário reportou que "Fornecedores" tinha sumido do CRM e que o botão "Central" (adicionado no item anterior) levava a uma URL não publicada.
- Causa raiz do primeiro: ao publicar o botão "Central" no CRM, o `Layout.tsx` local (submodule desatualizado) sobrescreveu a versão do Skip, que já tinha o item "Fornecedores" no menu lateral — a página/rota nunca deixaram de existir, só o link do menu. Restaurado.
- Causa raiz do segundo: a URL usada (`https://central-lucenera.goskip.app/`) nunca foi publicada nesse domínio. Corrigida em todos os 8 sistemas para `https://central-lucenera-dashboard-1c9ba.goskip.app/dashboard` (confirmada publicada, rota `/dashboard` existe no app).
- QA limpo, publicado em produção e enviado ao GitHub nos 8 sistemas.

## 2026-08-10 (6)

### Adicionado — botão "Voltar para a Central Lucenera" em 8 sistemas

- Usuário pediu um botão de retorno ao Hub (`https://central-lucenera.goskip.app/`) em todos os sistemas-satélite. Adicionado no header/nav principal de: Cadastro Lucenera (`36668`), Necessidade de Compra (`40326`), Dashboard Financeiro (`41135`), Orçamentos (`32554`), CRM (`24580`), Logística (`24039`), Administração Bancária (`36395`) e Separação Parcial (`48801`).
- QA completo (setup/staticAnalysis/build/integrations/test) limpo nos 8, publicado em produção e sincronizado com o GitHub de cada submodule.
- Achado à parte: o submodule local `lucenera-logistics-b7cd1` estava em detached HEAD, um commit atrás de `main`/`origin/main` (a remoção do campo "Separação Parcial" do formulário, já publicada no Skip anteriormente, nunca tinha sido levada à branch local) — corrigido com fast-forward, sem perda de commits.

## 2026-08-10 (5)

### Corrigido — SPEC-072: lista de vendas visível, botão voltar e logo na Separação Parcial

- Usuário reportou 3 problemas de uso real: lista de vendas escondida atrás de um clique no campo de busca, sem forma de voltar da tela de detalhe para a busca, e logo da Lucenera ausente.
- Seletor escondido (`SearchableSelect`) substituído por uma lista sempre visível de vendas (cards com número/cliente/projeto) com filtro por texto.
- Adicionado botão "Voltar à busca" na tela de detalhe.
- Logo da Lucenera adicionada no login e no cabeçalho principal.
- Publicado (Skip `48801` v`0.0.11`, GitHub `2b2f3f7`).

## 2026-08-10 (4)

### Corrigido — SPEC-072: remove valor de boletos na Separação Parcial

- Usuário foi explícito: Separação Parcial não deve mostrar nenhuma informação de valor. Painel "Boletos desta venda" perdeu Valor/Vencimento; ficou só um resumo de parcelas pendentes + o número de cada boleto. Publicado (Skip `48801` v`0.0.10`, GitHub `6a40712`).
- **Incidente à parte, não relacionado**: SQL de outro projeto ("Memória Perene") colado por engano diretamente no SQL Editor do Supabase da Lucenera — criou 6 tabelas/4 tipos/4 funções isoladas (`memory_organization_*`), sem tocar em nada existente. Investigado (nada da Lucenera foi afetado) e revertido por completo a pedido do usuário — banco confirmado limpo.

## 2026-08-10 (3)

### Corrigido — SPEC-072: Separação Parcial sem opções de venda + conexão com boletos

- Pedido do usuário: "na separação parcial não tem nenhuma opção de venda orçamento! precisamos conectar com os orçamentos aprovados e também com os boletos gerados!". Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-072_Novo_Sistema_Separacao_Parcial_por_Setor.md`.
- **Causa raiz**: o campo "Venda" era texto livre sem nenhuma forma de descobrir números válidos, e a maioria dos orçamentos aprovados na base (12) não tem `projeto_itens` de verdade — só 6 têm saldo operacional. Virou um seletor de busca (`SearchableSelect`) populado só com vendas que de fato têm o que separar.
- **Boletos conectados**: novo painel mostra os boletos gerados na aprovação do orçamento (parcela, vencimento, valor, status). Exigiu estender a RLS de `boletos` (migration `20260810_092`) — antes só quem tinha acesso a `financeiro` conseguia ler boletos, o que bloquearia o resto da equipe que usa Separação Parcial.
- Testado no navegador com usuário descartável, sem resíduo em produção. Commitado e publicado (Skip `48801` v`0.0.9`, GitHub `9c576a9`).

## 2026-08-10 (2)

### Concluído — SPEC-069: RBAC completo (RLS estendido, RolesTab.tsx, adoção em 7 sistemas)

- Pedido do usuário: terminar todas as pendências da SPEC-069 nesta mesma sessão, com tudo commitado e publicado no Skip. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-069_Matriz_Permissoes_Perfis_RBAC.md`.
- **RLS estendido e aplicado** (migration `20260810_091_spec069_rls_shared_tables`): `projetos`, `contatos` (split cliente/arquiteto vs fornecedor por `tipo`), `orcamentos`, `orcamento_itens`, `separacoes` (incluindo o sistema novo `separacao-parcial`), `solicitacoes_compra`, `pedido_compra_itens`, `cotacoes_compra` — todas trocaram policies `USING (true)` por checagem via `hub_pode_executar`. Guards de permissão adicionados em 4 RPCs de Compras (`criar_pedido_compra_lote`, `criar_pedido_compra_de_necessidade`, `cancelar_pedido_compra`, `atualizar_preco_custo_produto`). Leitura continua aberta em todas — só escrita foi restringida, conforme o próprio critério de aceite da SPEC.
- Verificado com RLS real via `SET ROLE authenticated` (não `SUPABASE_DB_URL`/service role): usuária sem acesso em Orçamentos bloqueada (0 linhas afetadas), admin passa (1 linha) — confirma que a policy está de fato sendo enforçada.
- **`RolesTab.tsx` do Hub** (Central Lucenera): checkbox binário "Acesso total" virou seletor de 5 níveis (Total/Editar/Editar sem cadastrar/Consultar/Sem acesso) por papel×sistema.
- **Adotado o guard `hasAccess` (via `hub_pode_executar`) nos 7 sistemas restantes**: RH, CRM, Cadastro, Orçamentos, Necessidade de Compra, Administração Bancária e Sistema de Entregas — cada um publicado no Skip com QA completo (setup/staticAnalysis/build/integrations/test).
- **Decisões do usuário nesta sessão**: Ficha Técnica (P6, app Flask fora do Skip) fica de fora deste lote; filtro por linha para Equipe de Entrega em Orçamentos (P3) adiado para SPEC futura; split de `contatos` por tipo (P4) aprovado e aplicado.
- **Pendente**: esconder botões "Novo Produto" (Cadastro) e "Novo Orçamento" (Orçamentos) por papel — o RLS já bloqueia a escrita de verdade, falta só a UX; reextração de `supabase/db/current/`.

## 2026-08-10

### Adicionado — SPEC-072: Sistema novo "Separação Parcial" por setor de estoque

- Pedido do usuário: retirar o campo "Separação Parcial" (texto livre) de Logística e criar um sistema dedicado que implementa de verdade a separação por setor (Reserva/Entrega Futura/Entregue), a partir das reuniões com o Vinicius. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-072_Novo_Sistema_Separacao_Parcial_por_Setor.md`.
- **Backend** (migration `20260810_090_spec072_separacao_parcial_setor`, aplicada): `separacao_itens.projeto_item_id` (FK nova) e RPC `registrar_separacao_setor` — decrementa `q_reserva`, incrementa `q_ag_separar`. Implementada só a partir da Reserva (não as 3 opções pedidas inicialmente), seguindo a regra explícita da gravação ("se não está em reserva, não pode ser separado") — decisão técnica que precisa confirmação do usuário.
- **Sistema novo**: submodule `04-Sistemas/separacao-parcial` (`github.com/pedrolalala/separacao-parcial`), publicado diretamente no GitHub (Skip MCP estava desconectado nesta sessão, sem acesso para publicar via Skip/registrar no Hub). Tela de busca por número de venda + tabela de saldo por setor (inspirada na tela antiga do Connect, imagem de referência do usuário) + ação de separar + histórico de parciais.
- Testado localmente (build/lint/typecheck limpos, fluxo completo no navegador com usuário de teste descartável) — 2 bugs reais corrigidos no processo (referência do produto vinha da tabela errada; falha parcial deixava registro órfão). Nenhum resíduo de teste ficou em produção.
- **Continuação (mesmo dia, Skip reconectado)**: corrigido bug em produção reportado pelo usuário (`supabaseUrl is required` — env vars nunca configuradas no Skip Cloud); sistema registrado no Hub (`public.systems` + 15 linhas de RBAC em `papel_permissoes`, replicando o padrão de Logística); campo removido de Logística com o QA pipeline completo do Skip. Só falta confirmar com o usuário se a decisão de "só Reserva" (P-4) está correta.

## 2026-08-07

### Adicionado — SPEC-071: Tipo de Operação Devolução no Fluxo de Orçamento

- Pedido do usuário: registrar devolução de cliente como parte do fluxo normal de orçamento (não uma tela separada), com o crédito virando parcela/boleto negativo. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-071_Tipo_Operacao_Devolucao_Fluxo_Orcamento.md`.
- **Backend** (migration `20260807_088_spec071_natureza_operacao_devolucao`, aplicada): `orcamentos.natureza_operacao` ('venda'|'devolucao', default 'venda'), `orcamento_itens.projeto_item_origem_id` (FK para `projeto_itens`), `aprovar_orcamento_financeiro` estendida com branch de devolução (chama `registrar_devolucao_projeto_item` por item, gera `projeto_parcelas`/`boletos` negativos em vez de cobrança), `projeto_parcelas_valor_check` trocado de `> 0` para `<> 0`. Ramo de venda existente preservado sem nenhuma mudança de lógica.
- **Segunda migration** (`20260807_089_spec071_replace_orcamento_itens_origem`, aplicada): `replace_orcamento_itens` (RPC usada ao salvar um orçamento já existente) passou a persistir `projeto_item_origem_id` — sem isso, editar uma devolução já criada perderia o vínculo com a venda de origem.
- **Frontend** (`gestao-financeira-clone-544cb (1)`, publicado no Skip, versão `0.0.304`/`1f10abf`, QA completo ok): toggle "Tipo de Operação" (Venda/Devolução) em `BudgetFormPage.tsx`, travado após a criação; novo `services/devolucoesService.ts` + `components/budgets/DevolucaoItemSearchModal.tsx` para buscar vendas de origem via `vw_estoque_saldos_projeto_item` (cruzando todos os projetos do cliente); `useBudgetStore.ts` estendido para propagar os dois campos novos; badge "Devolução" na listagem (`BudgetTableRow.tsx`).
- **Pendente**: homologação manual no navegador do golden path completo; definir quem pode registrar/aprovar uma devolução (papel/permissão, herdado de SPEC-015/054 sem resolver).

## 2026-08-06 (1)

### Adicionado — SPEC-067: Enviar para o Cliente — download automático de PDF + e-mail pré-preenchido (mailto)

- Pedido do usuário: ao clicar "Enviar para o Cliente" num orçamento em Rascunho, quer que o PDF baixe sozinho e um e-mail já venha pronto (destinatário, assunto, corpo com o link de aprovação) para enviar ao cliente. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-067_Enviar_Cliente_PDF_Automatico_Email_Mailto.md`.
- Escopo restrito ao **envio inicial** de um rascunho (`DraftBudgetsTab.tsx` e o botão equivalente na lista "Todos") — reenvio após recusa e o ícone de reenviar continuam sem essa automação, por decisão do usuário.
- Sem migration — 100% frontend, reaproveitando o e-mail do cliente (já vinha via join) e a Edge Function `generate-report` (PDF) já existentes.
- **Achado durante a homologação**: a ordem original (baixar PDF, depois abrir o `mailto:`) fazia o e-mail nunca abrir de fato — o navegador só honra a navegação para um esquema externo como `mailto:` enquanto há "ativação de usuário" válida a partir do clique, e essa ativação expirava durante a geração do PDF (chamada de rede via Edge Function). Corrigido invertendo a ordem: abre o `mailto:` primeiro (rápido, ainda dentro da janela do clique), baixa o PDF depois.
- `gestao-financeira-clone-544cb` — implementado e publicado localmente no submodule (commits `17ca76d`, `6da70dc`), **push feito para o GitHub**. Publicação no Skip Cloud ainda pendente (fora do alcance desta sessão, sem acesso ao MCP do Skip).

### Adicionado — SPEC-070: Voltar Orçamento para Rascunho (Enviado ao Cliente / Recusado)

- Pedido do usuário: depois de enviar um orçamento ao cliente não havia nenhum jeito de voltar para Rascunho caso o cliente pedisse alteração antes de aprovar. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-070_Voltar_Orcamento_Rascunho_Apos_Envio_Cliente.md`.
- **Achado**: não existia, em nenhum lugar do sistema, um caminho (manual ou automático) de `enviado_cliente`/`recusado_cliente` de volta para `rascunho` — a única "devolução" existente (`equipe_devolver_orcamento_cliente`, SPEC-031) opera um nível acima, entre "Aprovação da Equipe" e `enviado_cliente`.
- **Decisões**: ação restrita a `enviado_cliente`/`recusado_cliente` (não mexe em orçamentos já aprovados pela equipe/financeiro); só `admin`/`gerente` (sem atalho de permissão via Hub, diferente do modelo); invalida o `token_aprovacao_cliente` (link antigo do cliente para de funcionar); motivo obrigatório, registrado em `historico_status_orcamentos`.
- Migration `20260806_082_spec070_voltar_orcamento_rascunho` (RPC nova `voltar_orcamento_rascunho`, **aplicada no Supabase real**).
- `gestao-financeira-clone-544cb` — implementado e publicado localmente no submodule (commit `28f1a34`), **push feito para o GitHub**. Publicação no Skip Cloud ainda pendente (fora do alcance desta sessão, sem acesso ao MCP do Skip).
- Achado registrado (não corrigido nesta SPEC): `supabase/db/current/03_functions.sql` está desatualizado para todo o domínio Orçamentos desde a SPEC-031 (18/07/2026) — funções e o bloco de reset da SPEC-019 não aparecem no snapshot local, só nas migrations aplicadas. Reextração completa do domínio continua pendente.

### Corrigido — SPEC-068: Orçamento — nome do cliente, desconto %/R$ + Sinal, vendedor via responsável da obra, dado do projeto 24.200

- Pedido da equipe de Projetos (Mariane), 4 itens. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-068_Correcoes_Orcamento_Cliente_Desconto_Sinal_Vendedor_Busca_Projeto.md`.
- **2.1** — combinação Razão Social + Nome Fantasia no painel de detalhes do projeto e no combobox de cliente do formulário de orçamento (antes só mostrava `contatos.nome` isolado). Não foi possível reproduzir/confirmar no código publicado a causa exata relatada ("mostrando código do projeto") — investigação em `ClientCreateModal.tsx` e `ClientFormFields.tsx` (CRM) não encontrou nenhum binding com `projeto.codigo`; fica como achado não fechado.
- **2.2** — novo: seletor de tipo de desconto (percentual/valor fechado em R$) com cálculo automático nos dois sentidos, e campo Sinal (R$, fixo, informativo — não gera parcela financeira). Migration `20260806_083_spec068_desconto_tipo_sinal_orcamento` (colunas `orcamentos.desconto_tipo`/`valor_sinal`, **aplicada no Supabase real**), incluindo atualização da RPC `buscar_orcamento_para_aprovacao` para expor desconto/sinal/saldo restante ao documento do cliente.
- **2.3** — vendedor autopreenchido agora usa `projeto.responsavel_obra_id` (fallback `responsavel_id`) em vez de `projeto.vendedor_id`, coluna que **não existe** na tabela `projetos` (referência morta desde a SPEC-061). Autopreenchimento agora só roda na criação de orçamento novo, nunca sobrescreve edição.
- **2.4** — achado: projeto 24.200 estava com `arquivado = true` no banco (status "Obra Finalizada"), por isso ficava fora do filtro de busca do "Novo Orçamento" — dado corrigido (`arquivado = false`) por decisão do usuário, confirmando que era erro de dado, não de regra.
- `gestao-financeira-clone-544cb` (Skip `projectId 32554`, versão `0.0.303`/`f06803c`, **publicado em produção**) — `BudgetFormPage.tsx`, `ClientApproval.tsx`, `services/clientApprovalService.ts`.

### Adicionado (parcial) — SPEC-069: Matriz de Permissões por Perfil (RBAC)

- Pedido do usuário: 6 papéis reutilizáveis (Administrador Geral, Gestão de RH, Administração
  Comercial, Compras e Entregas, Equipe de Projetos, Equipe de Entrega) com níveis granulares
  (TOTAL/EDITAR/EDITAR SEM CADASTRAR/CONSULTAR/SEM ACESSO) por sistema. Detalhes em
  `03-Projeto/Planos de Ação/SPECs/SPEC-069_Matriz_Permissoes_Perfis_RBAC.md`.
- Configurado sobre a infraestrutura já existente da SPEC-006 (`papeis`, `papel_permissoes`,
  `usuario_papeis`, RPC `hub_pode_executar`) — não é um modelo novo.
- Migration `20260806_084_spec069_rbac_matriz_perfis` **aplicada no Supabase real**: 6 papéis, 44
  linhas de `papel_permissoes` para 9 sistemas, ação `aprovar` adicionada ao vocabulário do modelo
  (necessária para Carol aprovar orçamentos sem ter TOTAL), `usuario_papeis` atribuído a
  Vinícius/Lana/Débora/Mariane (Carol ainda sem login em `usuarios`, pendente).
- **Achado crítico que bloqueia a continuação com segurança**: Lana e Mariane ainda têm o papel
  legado `gerente` (seed de compatibilidade da SPEC-006) atribuído, que concede acesso TOTAL a
  sistemas que a matriz nova pede como SEM ACESSO para elas — enquanto não for resolvido, qualquer
  RLS/RPC guard baseado em `hub_pode_executar` seria ineficaz para essas duas. RLS de RH/Adm.
  Bancária, guards de `criar_produto_orcamento`/`aprovar_orcamento_financeiro`, extensão do
  `RolesTab.tsx` do Hub e adoção por sistema (frontend) ficaram como trabalho subsequente.
- "Ficha Técnica" confirmada como o repositório `Lucenera-Power-point` — clonado como submodule
  `04-Sistemas/lucenera-power-point` (não commitado). Achado: é um app Python/Flask com integração
  SharePoint, arquitetura completamente diferente dos outros 10 sistemas (sem Supabase/React) — sem
  URL de produção confirmada, sem nenhum código que valide permissão via `hub_pode_executar`.
  Integrá-lo à matriz de RBAC é trabalho de engenharia novo, fora do escopo desta SPEC.
- **Continuação na mesma sessão**: usuário confirmou que a aprovação de equipe da Mariane em
  Orçamentos depende de `usuarios.role` (não da tabela nova de papéis) — papel legado `gerente`
  removido de Lana e Mariane, sem efeito colateral. Conta da Carol criada (e-mail fornecido pelo
  usuário) via RPC `criar_usuario`, atribuída a `administracao_comercial`. Com o bloqueio resolvido:
  - Migration `20260806_085_spec069_rls_financeiro_rh` **aplicada**: RLS de `boletos`/
    `notas_fiscais`/`remessas`/`contas_bancarias` (Administração Bancária) e `funcionarios_novo`
    (RH) substituído de `USING (true)` para `hub_pode_executar` — testado ao vivo.
  - Migration `20260806_086_spec069_rpc_guards_orcamentos` **aplicada**: guard novo em
    `aprovar_orcamento_financeiro` (não tinha nenhuma checagem — agora só admin_geral/Carol
    aprovam) e reforço em `criar_produto_orcamento` (já tinha checagem de role legado, adicionada
    checagem granular da matriz nova).
  - RolesTab do Hub e adoção por sistema (10 telas) continuam pendentes, fora do escopo desta sessão.

### Corrigido — Cadastro: remove "Código Progressivo (SKU)" do form/listagem de Peças, usa Referência

- Pedido do usuário: para peças, o "código progressivo" (campo `sku`) é a mesma informação que a Referência — redundante mostrar/editar os dois.
- `PecaForm.tsx`: campo SKU removido do formulário, Referência ocupa o lugar ao lado do Código (auto-gerado, intocado).
- `Pecas.tsx` / `PecaDetailsPanel.tsx`: coluna/rótulo "SKU / Referência" vira só "Referência"; valor exibido prioriza `referencia`, cai para `sku` só em registros legados sem referência preenchida.
- Coluna `produtos.sku` **não foi removida do banco** — continua existindo e sendo usada como chave de match em outros fluxos (import XML de orçamento, `criar_produto_orcamento`), só parou de aparecer nesta tela.
- `cadastro-lucenera-b86fe` (Skip `projectId 36668`, versão `0.0.51`/`71e098d`, **publicado em produção**).

## 2026-08-05 (7)

### Corrigido — SPEC-065: RH — Férias não criava (coluna gerada) + Vale Transporte não salvava

- `ferias.dias` é `GENERATED ALWAYS AS (data_fim - data_inicio + 1) STORED` — `VacationForm.tsx` enviava valor explícito nesse campo, rejeitado pelo Postgres em 100% das tentativas (confirmado: os 12 registros existentes são todos de seed no mesmo segundo, nenhum criado pelo app). Corrigido removendo `dias` dos payloads de insert/update.
- `EmployeeFinance.tsx`: `funcionarios_beneficios_empresas.empresa` é `NOT NULL` mas não era enviada no insert, e o erro não era verificado — mostrava "sucesso" falso sem gravar o VT. Corrigido: envia `empresa` sempre e bloqueia com mensagem clara se o funcionário não tiver Empresa definida no cadastro.
- `dashboard-rh-lucenera-5fe9c` (Skip `projectId 23919`, versão `0.0.219`/`42e7121`, **publicada em produção**).

### Adicionado — SPEC-061: Novo Orçamento (autopreenchimento) + cadastro de cliente (e-mail obrigatório, complemento, vendedor)

- 5 pontos trazidos pela equipe de Projetos sobre "Novo Orçamento" e cadastro de cliente. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-061_Novo_Orcamento_Autopreenchimento_Projeto_e_Cadastro_Cliente.md`.
- Migration `20260805_078_spec061_complemento_e_vendedor_funcionarios` (**aplicada no Supabase real**): `contatos.complemento`/`complemento_entrega`/`complemento_cobranca`; FK de `vendedor_id`/`vendedor_padrao_id` trocada de `auth.users` para `funcionarios(id)` (0 linhas afetadas, sem backfill).
- `lucenera-crm-3bd29` (Skip `projectId 24580`, versão `0.0.291`/`df632c5`, **publicada**): e-mail obrigatório no cadastro de cliente, complemento nos 3 blocos de endereço, `cliente_id` de verdade obrigatório em Novo Projeto (achado: validação existente não bloqueava nada — sentinela `'null'` passava em `min(1)`).
- `gestao-financeira-clone-544cb` (Skip `projectId 32554`, versão `0.0.302`/`2262db0`, **publicada**): e-mail obrigatório, complemento, Vendedor/Vendedor Padrão via `funcionarios` (não mais `usuarios`), autopreenchimento de Arquiteto por nome quando só existe o texto legado, aviso claro (não mais "Não encontrado" genérico) quando projeto não tem cliente/empresa vinculado na origem.
- Bug relatado pela Mariane (cliente cadastrado não aparece para montar orçamento): confirmado no Skip que o código correto já estava publicado — não é dessincronia Skip/local. Não reaberto sem reprodução.

## 2026-08-05 (6)

### Adicionado — SPEC-064: campo "Perfil" (Ribeirão/São Paulo) em 6 sistemas + tela de classificação no Dashboard Financeiro

- Lucenera está abrindo uma filial em São Paulo — toda a operação financeira/de projetos continua em Ribeirão Preto, mas o usuário precisa conseguir visualizar separadamente o que é de São Paulo. Detalhes completos em `03-Projeto/Planos de Ação/SPECs/SPEC-064_Perfil_Ribeirao_Sao_Paulo.md`.
- **Decisões**: perfil é só rótulo/visualização, não influencia nenhuma lógica de negócio; sem herança automática entre cliente/projeto/orçamento/pedido/boleto/transação — cada um tem seu próprio campo, manual; campo fixo de 2 valores (`ribeirao`/`sao_paulo`), mesmo padrão de `tipo_cliente`; dashboard novo = filtro no Dashboard Financeiro existente, não um app duplicado.
- **Achado crítico**: o Dashboard Financeiro não lê `orcamentos`/`boletos`/`pedidos_compra` — lê `v_financeiro_realizado`, derivada de `transacoes` (livro-caixa importado do Connect, desconectado do fluxo atual). Sem isso, o filtro do dashboard nunca teria dado nenhum resultado.
- Migration `20260805_077_spec064_perfil_ribeirao_sao_paulo` (4 arquivos, **aplicada no Supabase real**): coluna `perfil` em `contatos`, `projetos`, `funcionarios`, `funcionarios_novo`, `orcamentos`, `pedidos_compra`, `boletos`, `transacoes`; RPCs `criar_pedido_compra_lote`/`criar_pedido_compra_de_necessidade` recriadas com `p_perfil`; views `vw_funcionarios_completo` e `v_financeiro_realizado` recriadas.
- **Achado ao implementar RH**: existem 2 tabelas de funcionário (`funcionarios`, legada, usada por Férias/Faltas; `funcionarios_novo`, real, usada pela tela de Cadastro) — a coluna precisou ir nas duas.
- Publicado em produção nos 6 sistemas: CRM (`lucenera-crm-3bd29`, `0.0.290`/`f1f98f0` — cliente e projeto, independentes), RH (`dashboard-rh-lucenera-5fe9c`, `0.0.218`/`c742130`), Orçamentos (`gestao-financeira-clone-544cb`, `0.0.301`/`d55c64a`), Necessidade de Compra (`compras-lucenera-3o23t98ee`, `0.0.52`/`e616728`), Administração Bancária (`retorno-bancario-bradesco-5392a`, `0.0.55`/`87e9a2c`), Dashboard Financeiro (`dashboard-lucenera-b02z85wa3`, `0.0.23`/`6cb8462` — nova tela `/transacoes` de classificação manual + filtro Ribeirão/São Paulo/Todos em Contas a Pagar/Receber).
- Fora de escopo por decisão do usuário: Consultar Produtos (estoque só em Ribeirão), Sistema de Entregas, Fichas Técnicas.
- **Pendência**: submodules locais de CRM/Orçamentos/Compras/Adm. Bancária/Dashboard Financeiro não foram sincronizados nesta SPEC (só o Skip, fonte real de produção); sincronizar quando for mexer de novo em algum desses sistemas.

## 2026-08-05 (5)

### Corrigido — SPEC-063: Dashboard Financeiro não checava permissão do Hub (vazamento de acesso)

- Usuário reportou que configurou pelo Hub o que a Lana (`financeiro@lucenera.com.br`, papel "gerente") pode ver, mas ela estava vendo o "Dashboard Financeiro" mesmo assim. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-063_Dashboard_Financeiro_Checagem_Permissao_Hub.md`.
- **Achado**: a permissão granular do Hub (SPEC-006) estava configurada corretamente no banco (`papel_permissoes` do papel "gerente" não inclui "Dashboard Financeiro") — o bug era que **nenhum sistema-satélite** consultava essa permissão. `Layout.tsx` do Dashboard Financeiro só checava se havia uma sessão Supabase válida; como todos os 8 sistemas compartilham o mesmo `auth.users`, qualquer login válido em qualquer sistema Lucenera bastava para abrir esse dashboard e ver Contas a Pagar/Receber, Estoque etc. Confirmado que os outros 7 sistemas têm a mesma lacuna (fora do escopo desta SPEC, registrada como pendência em `supabase/db/domains/hub_ti.md`).
- `dashboard-lucenera-b02z85wa3` (Skip `projectId 41135`, produção `dashboard-empresa-40d7d.goskip.app`, versão `0.0.22`/`7f37a25`, **publicada em produção**): `use-auth.tsx` ganhou `hasAccess` (chama `hub_pode_executar`, SPEC-006); `Layout.tsx` bloqueia com tela "Acesso negado" quem não tem o sistema liberado.
- Achado à parte, não corrigido nesta SPEC: `Login.tsx` desse mesmo sistema tem credenciais reais (`pedro@lucenera.com.br`/senha) pré-preenchidas no código-fonte, visíveis sem login.

## 2026-08-05 (4)

### Publicado — SPEC-058: RH sem bloqueio duro de férias + folga compensatória

- Usuário pediu para publicar também o trabalho da SPEC-058 (feito em 2026-08-04, só codificado localmente até então) junto com a correção da busca de colaborador (SPEC-062). Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-058_RH_Ferias_Sem_Bloqueio_e_Folga_Compensatoria.md`.
- Migrations **aplicadas no Supabase real**: `20260804_074_rh_ferias_periodo_opcional` (`ferias.periodo_aquisitivo_id` agora nullable) e `20260804_075_rh_controle_falta_folga` (novo status `'folga'` em `controle_falta`).
- `dashboard-rh-lucenera-5fe9c` (Skip `projectId 23919`, versão `0.0.217`/`9b88f1d`, **publicada em produção**): `VacationForm.tsx` — removido bloqueio duro do botão "Solicitar" por saldo excedido ou período aquisitivo ausente (alertas visuais continuam aparecendo, só pararam de travar o clique); `FaltasDialog.tsx`/`FaltasTabela.tsx`/`FaltasCalendario.tsx` — novo status "Folga Compensatória" (grupo próprio no select, badge teal, entrada no calendário).
- Submodule local sincronizado e enviado ao GitHub (`dashboard-rh-lucenera-6g2endmv7`, commit `989fd15`).
- **Pendências que continuam em aberto**: datas exatas da folga da funcionária Cris (SPEC-058, P-07) e o agente `revisor` não foi rodado antes desta publicação (fora do fluxo padrão, a pedido do usuário).

## 2026-08-05 (3)

### Corrigido — SPEC-062: campo "Colaborador" sem busca em Nova Solicitação de Férias

- Usuário reportou que o campo "Colaborador" no formulário de férias (RH) só permitia "buscar" (typeahead nativo do `<Select>` do Radix, sem caixa de busca visível — dropdown de 29 funcionários ativos, digitar só pulava/realçava um item), não selecionar de forma confiável. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-062_RH_Ferias_Combobox_Busca_Colaborador.md`.
- `dashboard-rh-lucenera-5fe9c` (Skip `projectId 23919`, versão `0.0.216`/`dbdf1a5`, **publicada em produção**): `VacationForm.tsx` — campo "Colaborador" trocado de `<Select>` simples para combobox (`Popover`+`Command`, caixa de busca real que filtra por nome, clique seleciona). Resto do formulário (período aquisitivo, datas, saldo) inalterado.
- **Nota**: o submodule local desse sistema tem WIP da SPEC-058 (remoção de bloqueio duro de férias, ainda não publicado nem com migrations aplicadas) no mesmo arquivo — não foi misturado nesta mudança, que foi feita 100% direto no Skip.

## 2026-08-05 (2)

### Adicionado — SPEC-060: cancelar pedido de compra + reversão do pedido 1768 (fictício)

- Usuário relatou que o pedido de compra nº 1768 (ACEND ILUMINACAO LTDA, R$9.935,45, criado em teste no dia anterior junto da SPEC-057) estava distorcendo a tela Necessidade de Compra — reduzindo artificialmente o "Pendente" dos 7 produtos daquele pedido. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-060_Cancelar_Pedido_Compra.md`.
- **Achado**: não existia nenhuma forma de cancelar um pedido de compra pela interface — `pedidos_compra` só tem policy de `SELECT`, toda escrita passa por RPC `SECURITY DEFINER`.
- Migration `20260805_076_spec060_cancelar_pedido_compra` (**aplicada no Supabase real**): `pedidos_compra` ganhou `cancelado_em`/`cancelado_por`/`motivo_cancelamento` + RPC `cancelar_pedido_compra(p_pedido_id, p_motivo)` (bloqueada para pedido já recebido/parcialmente recebido/cancelado; cancela junto parcelas não pagas). Nenhuma view precisou mudar — `vw_necessidade_compra_pedidos_abertos`/`pedido_detalhe` (SPEC-039) já filtravam por `status NOT IN ('recebido', 'cancelado')`.
- Pedido 1768 cancelado via SQL direto no mesmo dia (antes do frontend ir ao ar) — confirmado que ele parou de contar como "pedido em aberto".
- `compras-lucenera-3o23t98ee` (Skip `projectId 40326`, versão `0.0.51`/`fe7bc4e`, **publicada em produção**): botão "Cancelar Pedido" em `PedidosCompra.tsx`, com confirmação (`AlertDialog`) e motivo opcional.
- **Nota**: o submodule local `04-Sistemas/compras-lucenera-3o23t98ee` estava com dezenas de arquivos modificados sem commit no momento desta SPEC — implementação feita 100% via Skip, submodule local não tocado (ficou fora do escopo desta SPEC; precisa de higienização à parte).

## 2026-08-05

### Adicionado — SPEC-059: Central Lucenera ganha cadastro fácil de usuário (email + senha)

- A aba "Gestão de Usuários" da Central Lucenera (Hub) só listava/editava usuários existentes; criar um usuário novo só era possível chamando a RPC `criar_usuario` direto no banco. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-059_Central_Lucenera_Cadastro_Facil_Usuarios.md`.
- Nenhuma migration necessária — `public.criar_usuario(p_email, p_password, p_nome, p_role)` já existia publicada no Supabase real e já valida que só `admin` pode chamar.
- `central-lucenera-dashboard-1c9ba` (Skip `projectId 37750`, versão `0.0.37`/`737e6c0`, **publicada em produção**): `UsersTab.tsx` ganhou botão "Novo Usuário" com dialog (Nome/Email/Senha/Papel) que chama a RPC e atualiza a lista. Espelhado no submodule local e enviado ao GitHub (`central-lucenera`, commit `2f2c389`).

## 2026-08-04 (6)

### Corrigido — SPEC-057: Necessidade de Compra e Pedido em Lote (teste ao vivo com Débora)

- Reunião de teste ao vivo do sistema com a Débora (compradora real), conduzida pelo Filippo (`02-Reunioes/14. Lucenera (Filippo) - 04.08.2026 - necessidade de compra debora/`), cruzada com os PDFs de referência do sistema legado Connect (`01-Documento/02 - Descritivo Connect/PDF/`). Detalhes completos em `03-Projeto/Planos de Ação/SPECs/SPEC-057_Correcoes_Necessidade_Compra_Pedido_Lote.md`.
- **Achado central**: `pedidos_compra.empresa_id` já existia e as RPCs já tentavam preenchê-lo automaticamente a partir de `usuarios.empresa_id` — mas nenhum dos 9 usuários tem essa coluna definida, então todo pedido criado pelo app gravava `empresa_id = NULL` silenciosamente. Não era campo faltando no banco, era campo faltando na tela.
- Migration `20260804_071_numeracao_pedido_compra_legado`: numeração de `pedidos_compra.numero` trocada de `PC-<ano>-NNNN` (nunca usado em produção) para sequencial simples sem prefixo, igual ao legado Connect — sequence nova começando em 1768 (usuário confirmou 1767 como último número real do sistema legado). **Aplicada no Supabase real.**
- Migration `20260804_072_pedido_compra_empresa_explicita`: adiciona `p_empresa_id` explícito às RPCs `criar_pedido_compra_lote`/`criar_pedido_compra_de_necessidade`. Achado ao aplicar: `CREATE OR REPLACE FUNCTION` com parâmetro novo no final cria uma segunda sobrecarga ambígua em vez de substituir — corrigido com `DROP FUNCTION` explícito da assinatura antiga antes de recriar. **Aplicada no Supabase real.**
- `compras-lucenera-3o23t98ee` (Skip `projectId 40326`, versão `0.0.50`/`1b027fc`): `NecessidadeCompra.tsx` (aba "Por Produto") perdeu as colunas Fornecedor/Comprometida/Necessidade/Empresa que comprou/Status do pedido/Entrega prevista (redundantes ou sempre vazias nesse contexto, por pedido direto da Débora); "Física" virou "Estoque"; novo checkbox "selecionar todos" no cabeçalho (respeita o mesmo agrupamento por fornecedor do checkbox individual). `ModalPedidoLote.tsx` e `ModalRegistrarCompra.tsx` ganharam campo obrigatório "Empresa" (novo `getEmpresas()` em `services/pedido-compra.ts`). Quantidades exibidas passam por arredondamento defensivo de 3 casas decimais (bug "5906,9999" relatado pela Débora não foi reproduzível nos dados atuais — mitigação preventiva, causa raiz não confirmada).

## 2026-08-04 (5)

### Fechado — "Regime de Apuração" vira Select fixo (Simples Nacional / Regime Normal)

- Usuário confirmou por texto as duas únicas opções do campo (pendência aberta desde a implementação inicial da SPEC-052, quando o print de referência só mostrava o dropdown fechado).
- Migration `supabase/db/migrations/20260804_070_spec052_regime_apuracao_fixo/001_regime_apuracao_check.sql` — `CHECK` em `contatos.regime_apuracao` restringindo a `simples_nacional | regime_normal`. Confirmado antes de aplicar que nenhum dos 3.861 contatos tinha valor preenchido (sem risco de violar a constraint). **Aplicada no Supabase real em 2026-08-04.**
- `lucenera-crm-3bd29 (1)` (Skip `projectId 24580`, versão `0.0.289`/`e26e02d`): `ClientFormFields.tsx` e `ContatoDetail.tsx` (que ganhou reforço no suporte a `FieldType: 'select'` para reaproveitar o mesmo padrão do "Tipo Cliente") trocaram o `Input` livre por `Select`.
- `gestao-financeira-clone-544cb (1)` (Skip `projectId 32554`, versão `0.0.300`/`e64d787`): mesmo tratamento em `ClientCreateModal.tsx`.
- Com isso, a única pendência aberta da SPEC-052 original (opções do regime tributário) está resolvida.

## 2026-08-04 (4)

### Adicionado — campo "Tipo Cliente" (consumidor/não contribuinte/indústria/revendedor)

- Usuário anexou os prints do sistema de referência do Vinicius e confirmou que o campo deve ser criado como Select fixo.
- Migration `supabase/db/migrations/20260804_069_spec052_tipo_cliente/001_add_tipo_cliente.sql` — coluna `contatos.tipo_cliente varchar` (nullable, sem default) com `CHECK` restringindo a `consumidor | nao_contribuinte | industria | revendedor` (mesmo padrão de `tipo_pessoa`, sem criar ENUM novo). **Aplicada no Supabase real em 2026-08-04.**
- Escopo: campo específico de cliente (o print é da tela "Cadastro de Clientes"), não estendido a arquiteto/engenheiro/eletricista/fornecedor.
- `lucenera-crm-3bd29 (1)` (Skip `projectId 24580`, versão `0.0.288`/`57cae50`): `ClientFormFields.tsx` ganhou o Select; `ContatoDetail.tsx` ganhou suporte genérico a `FieldType: 'select'` (com `options`) e a entrada `tipo_cliente` no `FIELD_CONFIGS.cliente`.
- `gestao-financeira-clone-544cb (1)` (Skip `projectId 32554`, versão `0.0.299`/`11ece1b`): `ClientCreateModal.tsx` ganhou o mesmo Select.
- Nenhuma migration de dados retroativa — os ~360 clientes/contatos existentes ficam com `tipo_cliente = NULL` até serem editados manualmente.

## 2026-08-04 (3)

### Adicionado — CRM: aba de Fornecedores (achado da Reunião.01 com Vinicius)

- Revisando os prints que o usuário anexou da Reunião.01 (`02-Reunioes/12. lucenera (Vinicius) - 27.07.2026_ correcoes necessarias/`), Vinicius também pediu: "no sistema que envolver produtos, preciso que tenha o campo de cadastro de Fornecedores - não encontrei... basicamente no CRM precisa de uma nova aba para adicionar fornecedores". Esse pedido não tinha sido coberto pela SPEC-052 (focada em cadastro de cliente).
- Achado: `contatos.tipo = 'fornecedor'` já existe e já tem 357 registros reais no Supabase (da importação Connect, SPEC-050) e é usado pela criação rápida de fornecedor em `cadastro-lucenera` (SPEC-053) — mas **nenhum sistema tinha uma tela de listagem/edição para esse tipo**. Os registros existentes usam `cnpj`/`razao_social`, não `cpf_cnpj` (diferente dos outros tipos de contato do CRM).
- `lucenera-crm-3bd29 (1)` (publicado direto no Skip, `projectId 24580`, seguindo o mesmo padrão de `Arquitetos.tsx`): nova página `src/pages/contatos/Fornecedores.tsx` (listagem cards/planilha, filtros por nome/razão social/cidade/UF, criação rápida); `src/pages/contatos/ContatoDetail.tsx` ganhou o tipo `fornecedor` (rota `/contatos/fornecedores/:id`, campos nome/razão social/CNPJ/contato/endereço); rota `/contatos/fornecedores` adicionada em `src/App.tsx`; item "Fornecedores" adicionado ao menu lateral em `src/components/Layout.tsx`. Versão publicada `0.0.287` (`f75c848`).
- Pendência levantada mas **não implementada** (requer decisão do usuário antes de mexer no schema): os prints também mostram um campo "Tipo Cliente" no sistema de referência do Vinicius, com opções fixas `CONSUMIDOR / NÃO CONTRIBUINTE / INDÚSTRIA / REVENDEDOR` — não existe coluna equivalente em `contatos` hoje, e não é o mesmo campo que "Regime Apuração" (que no print aparece fechado, mostrando só "SIMPLES NACIONAL", sem revelar a lista completa de opções). Fica em aberto até confirmação com o usuário se esse campo deve ser adicionado e com qual semântica exata.

## 2026-08-04 (2)

### Corrigido — SPEC-052/053/054: código já escrito nunca tinha chegado à produção (Skip)

- Usuário pediu para conferir se as correções da reunião com Vinicius (27/07/2026, `02-Reunioes/12. lucenera (Vinicius) - 27.07.2026_ correcoes necessarias/`) tinham sido de fato aplicadas. Achado: as três SPECs (052 cadastro de cliente, 053 cadastro de produto, 054 devolução por setor) estavam com código completo e correto no submodule local, mas **nada disso estava rodando em produção** — os 4 sistemas envolvidos (`lucenera-crm`, `gestao-financeira-clone`, `cadastro-lucenera`, `compras-lucenera`/Necessidade de Compra) são todos projetos Skip Cloud, e a working tree do Skip nunca recebeu essas mudanças (mesma divergência já registrada para SPEC-042/043/044). Verificado por leitura direta do código publicado em cada projeto Skip via `skip_file_read`, não pelo submodule.
- **SPEC-054 (devolução por setor)**: RPC `registrar_devolucao_projeto_item_setor` já estava aplicada e funcionando no Supabase real (confirmado via SQL direto), mas nenhum frontend a consumia. Publicado no Skip do projeto "Necessidade de Compra" (`projectId 40326`): `src/services/devolucoes.ts`, `src/components/compra/DevolucaoEstoqueTab.tsx`, `src/components/compra/ModalDevolucaoItem.tsx` (novos) e nova aba "Devolução" em `src/pages/NecessidadeCompra.tsx`. Versão publicada `0.0.49` (`fab8e56`).
- **SPEC-053 (cadastro de produto)**: publicado no Skip do projeto "Cadastro Lucenera" (`projectId 36668`): `src/services/produtos.ts` ganhou `checkCodigoExists`/`createMarca`/`createFornecedor`; `src/components/forms/PecaForm.tsx` — botões "+" de criação rápida de marca/fornecedor, campo `Código` virou somente leitura (a sequence `produtos_codigo_produto_seq` já existia no banco real, mas o formulário publicado ainda pedia digitação manual, então nunca era usada), e bordas coloridas separando os 4 blocos do formulário. Versão publicada `0.0.50` (`f97bb9c`).
- **SPEC-052 (cadastro de cliente)**: publicado em 3 sistemas — `gestao-financeira-clone` (`projectId 32554`, `src/components/ClientCreateModal.tsx`, versão `0.0.298`/`615d29e`) e `lucenera-crm` (`projectId 24580`, versão `0.0.286`/`b4752f9`). No CRM a versão local do formulário (`Clientes.tsx`) já estava obsoleta em relação ao Skip (que evoluiu para um componente compartilhado `ClientFormFields.tsx` + página cheia `ContatoDetail.tsx`, ver SPEC-044) — em vez de sobrescrever, os campos do SPEC-052 (autofill de CEP via ViaCEP, autofill de CNPJ via BrasilAPI, "Nome e Razão Social"/"Nome Fantasia", Inscrição Estadual + Regime de Apuração separados do RG, blocos de Endereço de Entrega/Cobrança) foram portados para dentro dos dois componentes já em produção: `src/components/ClientFormFields.tsx` (usado no diálogo "Novo Cliente") e `src/pages/contatos/ContatoDetail.tsx` (usado na edição em página cheia, incluindo a mesma lógica de autofill de CEP/CNPJ). Em todos os casos as colunas usadas (`rg`, `inscricao_estadual`, `regime_apuracao`, `*_entrega`, `*_cobranca`) já existiam em `contatos` no Supabase real — nenhuma migration foi necessária.
- Todas as 4 publicações passaram pelo pipeline de QA do Skip (`skip_project_apply_changes` em modo `development`, depois `skip_project_publish`) antes de ir ao ar.
- **Não alterado nesta correção**: os submodules locais em `04-Sistemas/` permanecem como estavam (já tinham o código certo) — a divergência entre local e Skip continua existindo para os arquivos não tocados aqui e deve ser tratada como um problema estrutural à parte (mesmo já apontado nas notas de SPEC-042/043/044).
- Pendências herdadas, não resolvidas nesta correção: "diferença de cor" em produtos (SPEC-053, aguardando definição), papel/permissão de quem pode registrar devolução e efeito financeiro de `gera_credito_financeiro` (SPEC-054), opções fixas do regime tributário (SPEC-052, aguardando print do Vinicius), homologação manual no navegador em todos os 4 sistemas.

## 2026-08-04 (1)

### Ajustado — CRM: larguras de coluna da tabela de Projetos

- Usuário reportou que colunas da tabela de Projetos (view "Planilha") cortavam texto com reticências, dificultando leitura de nome de projeto, cidade e engenheiro/arquiteto.
- `lucenera-crm-3bd29 (1)/src/pages/Projetos.tsx`: tabela trocada de `table-fixed` para `table-auto`. Coluna "Projeto" teve a largura reduzida (`w-[160px]`) e passou a quebrar em múltiplas linhas (`whitespace-normal break-words`) em vez de truncar com `...`. Colunas "Cidade" e "Eng./Arquiteto" tiveram a largura-base aumentada (`w-[140px]`/`w-[160px]`). Todas as demais colunas (Responsável, Entrada, Status, Fechamento, Valor Total, Eng./Arquiteto, Cidade) tiveram a classe `truncate` removida e passaram a usar `whitespace-nowrap`, exibindo o texto sempre por completo (a coluna cresce e o container já tem `overflow-x-auto` para rolagem horizontal quando necessário).
- Importante: este sistema é servido via Skip Cloud (projeto "Lucenera CRM", id 24580) e a working tree do Skip já estava divergente do submodule local (`Projetos.tsx` local usa componentes shadcn diferentes e não reflete o que está em produção). A edição foi feita diretamente na working tree do Skip via `skip_file_write`, aplicada (`skip_project_apply_changes`, QA completo passou) e publicada em produção (`skip_project_publish`, versão `0.0.285`, ref `e0956bf`). O submodule local `04-Sistemas/lucenera-crm-3bd29 (1)` não foi tocado e permanece desatualizado em relação ao Skip — mesma divergência já registrada nas SPEC-042/043/044.
- Pendência: sincronizar o submodule local com a working tree do Skip para eliminar a divergência (fora do escopo desta mudança pontual).

## 2026-08-03 (1)

### Sincronizado — Produtos desatualizados no Supabase (planilha Connect 31/07)

- Usuário reportou que o valor dos produtos estava desatualizado. Causa: existia uma planilha `Produtos__2026-07-31.xlsx` (export "Estoque" do Connect) já disponível em `01-Documento/01 - Planilhas/`, mais recente que a última sincronizada (23/07, commit `1989773`), mas o script `scripts/importar_produtos_estoque.py` ainda apontava para o arquivo antigo.
- Atualizada a constante `PLANILHA_PADRAO` do script para `Produtos__2026-07-31.xlsx` e rodado o import contra o Supabase real: dry-run confirmou 685 produtos divergentes; gravação real aplicou os 685 updates (custo_total, valor_venda, percentual_lucro, estoque_total/showroom/disponivel) com 0 erros. 3.667 produtos já estavam sincronizados. `estoque_itens` foi atualizado automaticamente pelo trigger `fn_sync_estoque_itens_from_produtos`.
- Pendência: 61 `CodProduto` da planilha não têm match em `produtos` (prováveis produtos novos, ainda não cadastrados — fora do escopo deste script, que só atualiza existentes). Lista completa disponível rodando `python scripts/importar_produtos_estoque.py --dry-run`.

## 2026-07-27 (9)

### Implementado — SPEC-053: Correções do Cadastro de Produto (código automático, criação rápida de marca/fornecedor, referência livre)

- SPEC desmembrada de uma SPEC única (origem: reunião com Vinicius, 27/07/2026), com decisão do usuário já resolvida: `produtos.codigo_produto` passa a ser gerado por sequence do Postgres (buracos na numeração aceitáveis), não por RPC dedicada, porque há dois caminhos de INSERT independentes em `produtos` (Cadastro grava direto, Orçamentos via RPC).
- Migration redigida (não aplicada no Supabase real): `supabase/db/migrations/20260727_068_spec053_codigo_produto_sequence/` — `001_sequence_codigo_produto.sql` cria `public.produtos_codigo_produto_seq` e associa como `DEFAULT nextval(...)` de `produtos.codigo_produto`; `002_criar_produto_orcamento_sem_codigo.sql` reescreve `public.criar_produto_orcamento(p_payload jsonb)` removendo a exigência/uso de `codigo_produto` do payload (corpo extraído do `db/current/03_functions.sql` real, resto do comportamento preservado).
- Achado incidental: `supabase/db/current/01_schema_full.sql` está desatualizado para `public.marcas` — não lista `fornecedor_id` (SPEC-030) nem `prazo_entrega_dias` (migration `20260715_041`), embora ambas já estejam aplicadas no banco real segundo `CHANGELOG.md`/`estoque_compras.md`. Os nomes de coluna usados nesta SPEC foram confirmados lendo as migrations originais. Recomendado reextrair `db/current/` na próxima oportunidade.
- `cadastro-lucenera-b86fe`: `src/services/produtos.ts` ganhou `createMarca()`/`createFornecedor()`; `src/components/forms/PecaForm.tsx` — `codigo_produto` virou campo somente leitura (gerado ao salvar), botões "+" ao lado de Marca e Fornecedor abrindo modais de criação rápida com auto-seleção, e separação visual (borda colorida) entre os 4 blocos do formulário.
- `gestao-financeira-clone-544cb (1)`: `src/services/productCatalogService.ts` ganhou `createMarcaQuick()`/`createFornecedorQuick()` e removeu `codigo_produto` do payload da RPC; `src/components/budgets/ProductCreateModal.tsx` — mesmo tratamento de código automático e botões "+" replicados.
- Confirmado que `referencia` não tinha (e continua sem) nenhuma máscara/regex/CHECK restritiva em nenhum dos dois formulários nem no banco — nenhuma mudança de código foi necessária.
- Verificação de RLS pedida pela SPEC: `marcas_insert` e `contatos_insert` existem para `authenticated` (não é o cenário deny-all-silencioso da SPEC-049), mas há uma assimetria — `contatos_insert` libera `admin`/`gerente`/`operador`, `marcas_insert` só `admin`/`gerente`. Documentado como achado, não corrigido (decisão de acesso, não técnica).
- Fora do escopo, propositalmente não implementado: campo de "cor"/"diferença de cor" em `produtos` — bloqueado até Vinicius definir o formato.
- `npm run lint` (oxlint), `npm run build` (vite) e formatação (`oxfmt` no Cadastro, `prettier` em Orçamentos) rodados sem erros/warnings novos em ambos os sistemas.
- Pendências: aplicar a migration no Supabase real e reextrair `supabase/db/current/`; esclarecer "diferença de cor"; confirmar se a restrição de formato relatada por Vinicius existe de fato em produção; decidir se `marcas_insert` deve liberar `operador`; homologação manual no navegador em ambos os sistemas. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-053_Correcao_Cadastro_Produto.md`.

## 2026-07-27 (8)

### Implementado — SPEC-052: Correções do Cadastro de Cliente (rótulos, campos ausentes, autopreenchimento CEP/CNPJ)

- SPEC desmembrada de uma SPEC única (origem: reunião com Vinicius, 27/07/2026), com decisões já resolvidas pelo usuário: provedor de CNPJ gratuito (BrasilAPI), e `regime_apuracao` implementado como texto livre por enquanto (print de referência do regime tributário ainda não chegou).
- Nenhuma migration foi necessária — todas as colunas usadas (`inscricao_estadual`, `regime_apuracao`, `cep_entrega`/`endereco_entrega`/`numero_entrega`/`bairro_entrega`/`cidade_entrega`/`estado_entrega`, equivalentes `_cobranca`) já existiam em `contatos` (`supabase/db/current/01_schema_full.sql`).
- `lucenera-crm-3bd29 (1)/src/pages/contatos/Clientes.tsx` (alvo principal): relabel `nome` → "Nome e Razão Social" e `nome_empresa` → "Nome Fantasia"; adicionados campos `inscricao_estadual` e `regime_apuracao`; busca automática de CEP (ViaCEP) nos 3 blocos de endereço (principal/entrega/cobrança) sem cruzar dados entre blocos; busca automática de CNPJ (BrasilAPI) preenchendo razão social/nome fantasia só quando o campo está vazio; adicionados os blocos "Endereço de Entrega" e "Endereço de Cobrança".
- `gestao-financeira-clone-544cb (1)/src/components/ClientCreateModal.tsx` (alvo secundário): mesmo tratamento de relabel, autofill de CEP/CNPJ e blocos de entrega/cobrança; `inscricao_estadual`/`regime_apuracao` já existiam neste formulário.
- `cadastro-lucenera-b86fe/src/components/modals/ClienteModal.tsx` não foi alterado (rota `/clientes` redirecionada, código morto) — usado apenas como referência de padrão (ViaCEP + 3 blocos de endereço).
- `npm run build`, `npm run lint` (oxlint) e formatação (`oxfmt` no CRM, `prettier` em Orçamentos) rodados com sucesso em ambos os sistemas, sem warnings novos.
- Pendências: homologação manual no navegador em ambos os sistemas, confirmação com Vinicius de qual tela ele testou, e o print do regime tributário (para decidir se `regime_apuracao` vira Select fixo). Nenhum commit/push foi feito nos submodules por este agente. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-052_Correcao_Cadastro_Cliente.md`.

## 2026-07-27 (7)

### Implementado — SPEC-054: Interface de Devolução de Estoque (linhas manuais por setor de origem)

- SPEC desmembrada de uma SPEC única por decisão do usuário (origem: reunião com Vinicius, 27/07/2026), já com o texto completo da nova função SQL verificado contra o banco real (`pg_get_functiondef`) na própria SPEC — implementação copiou o SQL literalmente, sem reescrita.
- Migration redigida (não aplicada no Supabase real): `supabase/db/migrations/20260727_067_spec054_devolucao_por_setor/001_registrar_devolucao_projeto_item_setor.sql` — RPC nova `registrar_devolucao_projeto_item_setor(p_projeto_item_id, p_setor_origem, p_quantidade, p_motivo)`, que recebe o setor de origem explicitamente por chamada (`entrega_futura | reserva | entregue`), em vez do rateio automático em cascata que `registrar_devolucao_projeto_item` (SPEC-015, mantida intocada) já faz — decisão do usuário: a tela exige lançamento manual de uma linha por setor.
- Frontend (`compras-lucenera-3o23t98ee`): nova aba "Devolução" em `src/pages/NecessidadeCompra.tsx`, ao lado de "Por Produto" e "Por Item de Orçamento". Componentes novos `src/components/compra/DevolucaoEstoqueTab.tsx` (lista itens com saldo aberto via `vw_estoque_saldos_projeto_item`) e `src/components/compra/ModalDevolucaoItem.tsx` (lançamento em linhas múltiplas por item, uma chamada de RPC por linha, validação client-side de soma por setor, erro tratado individualmente por linha via toast). Serviço novo `src/services/devolucoes.ts`, seguindo o mesmo padrão de `services/necessidade-compra-item.ts`.
- `supabase/db/domains/estoque_compras.md` atualizado: removida a afirmação desatualizada de que `devolucoes_estoque`/`transferencias_estoque` "ainda não existem" (achado da SPEC-054, tabelas confirmadas em produção desde 07/07/2026); documentada a nova RPC.
- Fora do escopo (decisão explícita, ver Pendências da SPEC): tela/ação de "confirmar coleta" (`status: aguardando_coleta -> coletada`) e efeito de `devolucoes_estoque.gera_credito_financeiro`, ambos herdados sem resolução da SPEC-015.
- `oxlint`, `oxfmt`/`format:check` e `vite build` de `compras-lucenera-3o23t98ee` rodados sem erros/warnings novos.
- Pendências: aplicar a migration no Supabase real, definir papel/permissão para registrar devolução, definir efeito de `gera_credito_financeiro`, definir tela de "confirmar coleta", homologar manualmente no navegador (devolução em 1/2/3 setores simultâneos). Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-054_Interface_Devolucao_Estoque.md`.

## 2026-07-27 (6)

### Implementado — SPEC-051: Fase explícita de Rascunho antes do envio ao cliente em Orçamentos

- Usuário aprovou a SPEC-051 (decisões P-1 a P-4 já resolvidas, com o texto real das funções/triggers extraído do Supabase de produção) e pediu a implementação.
- Migration redigida (não aplicada no Supabase real): `supabase/db/migrations/20260727_066_spec051_fase_rascunho_orcamento/` — `001_...sql` remove o bloco final de `handle_orcamento_workflow()` que promovia automaticamente `rascunho`/`aguardando_cliente`/`aguardando_aprovacao` para `enviado_cliente`; `002_...sql` remove por completo o trigger `trg_orcamento_item_workflow` e a função `handle_orcamento_item_workflow()` (gatilho mais direto do problema, disparava no primeiro `INSERT` de item); `003_...sql` adiciona validação de completude (empresa, projeto, cliente, forma de pagamento, ao menos 1 item) em `enviar_orcamento_para_cliente`, que agora é o único ponto de entrada para `enviado_cliente`.
- Achado de bug pré-existente corrigido: `src/stores/useBudgetStore.ts` (`enviarOrcamentoCliente`) chamava a RPC inexistente `enviar_orcamento_cliente` (sem "para") — corrigido para `enviar_orcamento_para_cliente`, a função real confirmada no banco.
- Frontend (`gestao-financeira-clone-544cb (1)`): nova aba "Rascunho" em `Budgets.tsx` (`DraftBudgetsTab.tsx`, novo), novo branch de ação em `BudgetTableRow.tsx`, helper `isDraftStatus` em `budget-status.ts`, toast pós-criação em `BudgetFormPage.tsx` ajustado para orientar o uso da aba "Rascunho". Ação "Enviar para o Cliente" aberta a qualquer usuário autenticado (P-2), sem botão "Salvar e Enviar" no formulário (P-4).
- Pendências: aplicar a migration no Supabase real, homologar manualmente no navegador (criar rascunho, editar sem "escapar" sozinho, enviar ao cliente explicitamente), `pnpm run lint`/`build`, reextrair `supabase/db/current/` e publicar no Skip. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-051_Fase_Rascunho_Antes_Envio_Cliente.md`.

## 2026-07-27 (5)

### Corrigido — SPEC-050: revisor achou arredondamento indevido de quantidade/desconto no import/export de XML

- `revisor` encontrou achado crítico antes de qualquer commit/publicação: `xml-budget-import.ts` arredondava `quantidade` e `desconto` para número inteiro (`Math.round`), apesar de `orcamento_itens.quantidade`/`desconto` suportarem decimais (`numeric(10,3)`/`numeric(12,2)`). XMLs reais do Connect têm itens fracionários genuínos (ex. metro linear de perfil de alumínio, `qtd_produto` `4,5`/`2,5`) — importar um desses inflava/reduzia a quantidade em até 25%, e um item com `qtd_produto` `0,5` viraria `1` (100% de erro) por causa de um `Math.max(1, ...)` adicional.
- Corrigido em `xml-budget-import.ts` (3 casas decimais para quantidade, 2 para desconto, sem arredondar para inteiro) e espelhado em `xml-budget-export.ts` (`computeItemSubtotal`, `buildItemXml`), já que o export usava o mesmo padrão de arredondamento no roundtrip.
- Também corrigido `findOrcamentoJaImportado()` (checagem de idempotência): antes engolia erro de rede/permissão e retornava `null` (interpretado como "não importado ainda", liberando o botão de aplicar sem garantia real); agora propaga o erro para a UI mostrar mensagem clara.
- `vite build` reexecutado após a correção, sem erros. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-050_Import_Export_XML_Connect_Orcamento.md`.

## 2026-07-27 (4)

### Implementado — SPEC-050: Importação e Exportação de XML no padrão Connect no sistema de Orçamentos

- Usuário aprovou a SPEC-050 (incluindo as decisões P-1 item avulso sem match, P-2 abrir `ClientCreateModal` quando cliente não é encontrado, P-3 ignorar `dt_devolucao`, e P-6 usar `orcamentos.numero` como `<cod_orcamento>` exportado) e pediu a implementação.
- Migration redigida (não aplicada no Supabase real): `supabase/db/migrations/20260727_065_spec050_import_export_xml_connect/001_orcamentos_origem_connect.sql` — `orcamentos.origem_connect_cod_orcamento integer` + `orcamentos.origem_connect_importado_em timestamptz` + índice único parcial, para idempotência do import de um mesmo XML.
- Frontend (`gestao-financeira-clone-544cb (1)`): `src/lib/xml-budget-import.ts` (parser client-side via `DOMParser`, porta simplificada de `OrçamentoParser` em `04-Sistemas/script python power point/data_manager.py`, sem a lógica de agrupamento/PowerPoint), `src/lib/xml-budget-export.ts` (serializador com raiz `Laghi_systems`), `src/components/budgets/ImportConnectXmlModal.tsx` (novo), botões "Importar XML (Connect)" e "Exportar XML" em `BudgetFormPage.tsx`. `use-options.ts` passa a trazer `codigo`/`cnpj` de `empresas` para casar o XML.
- Resolução determinística por código (não fuzzy como no import de PDF): `empresa_id` por `cnpj`/`codigo`, `cliente_id` por `contatos.codigo_legado`, `produto_id` por item via `produtos.codigo_produto` (confirmado no banco real como equivalente a `codigo_legado`, com `referencia` de fallback). Diferente do PDF, o import de XML sempre preserva a `descricao` textual do XML mesmo quando o produto foi casado.
- Lint (`oxlint`), `prettier --check` e `vite build` do `gestao-financeira-clone-544cb (1)` passaram sem novos erros/avisos.
- Pendências: aplicar a migration no Supabase real, homologar manualmente (import de XML real, reimport bloqueado, export), publicar no Skip. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-050_Import_Export_XML_Connect_Orcamento.md`.

## 2026-07-27 (3)

### Corrigido — SPEC-049: código publicado no Skip (não só no submodule) + achado crítico de RLS em `equipes_projetos`

- Usuário testou o card publicado e reportou que nenhuma das 3 seções novas apareceu. Causa raiz real: o projeto no Skip (`Cadastro Lucenera`, id 36668) tem sua própria cópia de arquivos, separada do submodule local — os agentes anteriores só editaram o arquivo em disco, que nunca chegou ao Skip. Confirmado via `skip_project_status`/`skip_file_read`: a versão publicada (`4eed663`) não tinha nenhuma linha da SPEC-049.
- Corrigido escrevendo `src/services/produtos.ts` e `src/components/pecas/PecaDetailsPanel.tsx` direto no projeto Skip via MCP (`skip_file_write`), após confirmar que as duas versões eram idênticas fora das partes da SPEC-049 (sem risco de sobrescrever mudança divergente). QA completo (`skip_project_apply_changes`, modo produção) passou em setup/análise estática/build/testes — só "integrations" falhou por 3 Edge Functions ausentes do pod, pré-existente e sem relação com esta mudança. Publicado como versão `0.0.47` (hash `b81c1fd`) em `https://cadastro-lucenera-b86fe.goskip.app`. Confirmado por download direto do bundle JS de produção que as strings novas (`Reservado por Cliente`, `Fornecedor Sugerido`, `vw_cadastro_produto_reserva_detalhe`) estão presentes.
- Usuário reportou de novo "não foi" após a publicação. Investigação usando `SET ROLE authenticated` no Supabase real (em vez de só `SUPABASE_DB_URL`/service role, que ignora RLS) achou um bug pré-existente real: **`equipes_projetos` tem RLS habilitado desde a migration `20260630_012_equipe_projetos_comissao` sem nenhuma policy de leitura** — `pg_policies` vazio para essa tabela, e `SELECT * FROM equipes_projetos` como `authenticated` sempre retornava 0 linhas (sem erro). Como a SPEC-049 é o primeiro consumidor autenticado real dessa tabela (todo acesso anterior era via `service_role`), esse bug nunca tinha sido percebido. `equipe_nome` sempre voltava `NULL` no card, mesmo com cliente/projeto corretos.
- Corrigido com migration `supabase/db/migrations/20260727_064_spec049_rls_equipes_projetos/001_select_policy_equipes_projetos.sql` — `CREATE POLICY authenticated_select_equipes_projetos ... FOR SELECT TO authenticated USING (true)`, mesmo padrão já usado nas outras tabelas do domínio (tabela sem dado sensível). **Aplicada em produção** e validada com `SET ROLE authenticated`: `equipe_nome` agora retorna "Thairine" corretamente para o produto 11307 do exemplo do usuário.
- Todas as 3 views usadas pelo card (`vw_cadastro_produto_reserva_detalhe`, `vw_necessidade_compra_pedido_detalhe`, `vw_necessidade_compra`) testadas com sucesso como `authenticated` após o fix, sem erro e com dado correto — cliente, equipe e fornecedor sugerido todos retornando certo para o produto de teste.
- **Lição registrada** em `supabase/db/domains/estoque_compras.md`: verificação de view/schema feita só via `SUPABASE_DB_URL` (service role/postgres) não detecta bug de RLS, porque esse role ignora RLS — é preciso testar como `authenticated` (`SET ROLE authenticated`) antes de considerar uma feature de leitura "pronta".
- Recusado, por regra do projeto: usuário pediu para eu logar no sistema real com email/senha para testar visualmente — negado (entrar com senha é ação proibida mesmo com autorização explícita do usuário); pedido que o próprio usuário valide no navegador.

## 2026-07-27 (2)

### Aplicado + ampliado — SPEC-049: migration da view de reserva aplicada em produção, card ganha "Fornecedor Sugerido"

- Usuário testou o card no app publicado e reportou que as informações novas (cliente/equipe/pedido) não apareciam — causa raiz: os dois passos manuais da entrada anterior (aplicar migration, publicar no Skip) ainda não tinham sido feitos.
- Antes de aplicar, validado por consulta direta (somente leitura) ao Supabase real que a view nova retornaria dado correto para o exemplo do usuário (produto código 11307, projeto 26.105, ORC-0010): cliente "MARIANA FERNANDES DE JESUS", equipe "Thairine".
- Migration `supabase/db/migrations/20260727_063_spec049_cadastro_reserva_detalhe/001_view_reserva_detalhe.sql` **aplicada em produção** via `psycopg2` (usuário confirmou explicitamente antes da execução), validada novamente pós-aplicação com o mesmo produto.
- Usuário pediu um adicional: mostrar também o "Fornecedor Sugerido" e a quantidade pendente mesmo quando ainda não existe nenhum pedido de compra real feito (caso do produto 11307, que aparece na tela "Necessidade de Compra → Por Item de Orçamento" com fornecedor STELLA e Pendente 1, sem pedido em trânsito). Confirmado por leitura do banco que esse "Fornecedor" vem de `vw_necessidade_compra` (`COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)`), view já em produção, sem precisar de migration nova.
- Frontend (`cadastro-lucenera-b86fe`): `getFornecedorSugeridoProduto` nova em `src/services/produtos.ts` (mesmo padrão das demais funções); `PecaDetailsPanel.tsx` ganhou uma linha "Fornecedor Sugerido · Pendente", visível só quando `pendente > 0`, independente da seção "Pedido de Compra em Trânsito" (uma pode aparecer sem a outra).
- `vw_necessidade_compra` passa a ter um **terceiro consumidor** (`cadastro-lucenera-b86fe`, ao lado de `compras-lucenera-3o23t98ee` e `dashboard-lucenera-b02z85wa3`) — registrado em `supabase/db/domains/estoque_compras.md`.
- Lint (`oxlint`/`oxfmt`) e `vite build` do `cadastro-lucenera-b86fe` passaram sem novos avisos/erros, para as duas rodadas desta entrada.
- Pendências: validar visualmente no navegador, publicar no Skip, reextrair `supabase/db/current/` do domínio de Compras (pendência crônica pré-existente). Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-049_Card_Lateral_Peca_Reserva_Cliente_Equipe_Pedido.md`.

## 2026-07-27 (1)

### Executado — SPEC-049: card lateral de peça no Cadastro ganha reserva por cliente/equipe e pedido em trânsito

- Usuário aprovou a SPEC-049 (incluindo as decisões P-01 "equipe" = `projetos.equipe_id` e P-02 uma linha por projeto/cliente sem agregação) e pediu a implementação.
- Migration redigida (não aplicada no Supabase real): `supabase/db/migrations/20260727_063_spec049_cadastro_reserva_detalhe/001_view_reserva_detalhe.sql`, criando `vw_cadastro_produto_reserva_detalhe` (reaproveita `vw_estoque_por_produto_projeto` da SPEC-010, soma `cliente_nome`/`equipe_nome` por `JOIN`, sem duplicar saldo).
- Confirmado, conforme pedido pela SPEC (P-05), que as colunas de `vw_necessidade_compra_pedido_detalhe` (SPEC-039) usadas pela seção "Pedido de Compra em Trânsito" batem com o arquivo de migration real (`20260722_056_spec039_necessidade_compra_grid/003_vw_necessidade_compra_pedido_resumo.sql`), já que o snapshot `supabase/db/current/` continua desatualizado nesse domínio.
- Frontend (`cadastro-lucenera-b86fe`): `getReservasProduto`/`getPedidosCompraEmTransito` novas em `src/services/produtos.ts` (mesmo padrão `supabase.from(...).select('*')` do arquivo); `PecaDetailsPanel.tsx` ganhou duas seções somente leitura abaixo de "Estoque por Local" — "Reservado por Cliente/Projeto" e "Pedido de Compra em Trânsito" — reaproveitando os componentes visuais já usados (Table, Skeleton, empty state). Dicionário de rótulos de status de pedido duplicado do `compras-lucenera-3o23t98ee` (sem import cross-repo).
- Lint (`oxlint`/`oxfmt`) e `vite build` do `cadastro-lucenera-b86fe` passaram sem novos avisos/erros.
- Pendências: aplicar a migration no Supabase real (passo manual do usuário), reextrair `supabase/db/current/` do domínio de Compras, testar o golden path no navegador, publicar no Skip. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-049_Card_Lateral_Peca_Reserva_Cliente_Equipe_Pedido.md`.

## 2026-07-25 (2)

### Executado — SPEC-048: schema + seed de dados mockados aplicados no Supabase de demo

- Usuário pediu para aplicar de fato o schema e os dados mockados no Supabase de demo (projeto dedicado, ref `cojwpzfpeqgdelixudyj`), a partir do que a SPEC-048 tinha planejado.
- **Achado de segurança durante a cópia dos sistemas:** `robocopy` trouxe o `dashboard/.env` original (dotfile, não aparecia em `ls`), que continha a `service_role` **real de produção** (projeto `vcvcwzmbiftcawncibke`). Sobrescrito imediatamente com as credenciais do projeto de demo antes de qualquer uso — nenhuma chave de produção chegou a ficar exposta na pasta da réplica além desse momento.
- Conexão direta ao banco (`db.<ref>.supabase.co`) falhou por só ter endereço IPv6 sem rota nesta rede; resolvido usando o Session Pooler do Supabase (IPv4), localizado com ajuda de navegação assistida no painel (conta `erp.lucenera@gmail.com`, com autorização do usuário).
- **Correção de abordagem:** a SPEC-048 recomendava recriar o schema via replay de `supabase/db/migrations/*`, mas a primeira migration (`001_snapshot_db_atual`) é um placeholder vazio — as tabelas base nunca foram capturadas em nenhuma migration deste repositório. Schema montado em duas camadas: base = `supabase/db/current/*.sql` (dump real de 07/07/2026) + delta = migrations `031` a `061`. Aplicado com sucesso: 95 tabelas, 54 views, 101 funções, 53 triggers, 356 policies no projeto de demo.
- **Dois gaps de drift de produção encontrados** durante a aplicação (documentados em `supabase/schema/README.md` da réplica, pendente de registro formal no repo de produção): (1) `estoque_itens.quantidade_disponivel` é usada pela migration `20260716_048` mas nunca foi criada por nenhuma migration — foi adicionada direto em produção fora do controle de versão; (2) o backfill da migration `20260715_045_custo_fixo_variavel` depende de uma tabela de staging (`stg_duplicatas_vigentes`) que não existe em nenhuma migration, provavelmente criada manualmente em produção durante uma limpeza pontual.
- 4 buckets de Storage criados no projeto de demo (`orcamentos`, `revenda-ubiqua-images` públicos; `notas_fiscais`, `materiais-separacao` privados), localizados por grep em `.storage.from(...)` no código dos sistemas.
- Seed de dados mockados escrito e aplicado (`supabase/seed/seed_data.py` na pasta da réplica, idempotente): cadastros, CRM/projetos, orçamentos, financeiro e estoque, incluindo 5 usuários de **login real** criados via Supabase Auth Admin API (não só linhas decorativas no banco — login funcional pra demo).
- Build validado com sucesso em 1 dos 10 sistemas (`central-lucenera`), confirmando que os apps rodam fora do Skip Cloud como Vite/React padrão.
- Detalhes completos, decisões e pendências (Edge Functions ainda não republicadas, 9 sistemas sem build validado, roteiro de apresentação ainda não ensaiado) em `03-Projeto/Planos de Ação/SPECs/SPEC-048_Replica_Demo_Convencao_Dados_Mockados.md`.

## 2026-07-25 (1)

### Criado — SPEC-048: réplica de demonstração do ecossistema para convenção (dados mockados + Supabase dedicado)

- Usuário pediu uma SPEC para replicar integralmente o ecossistema Lucenera em `C:\script python\Replica SISTEMA LUCENERA`, com dados mockados e um Supabase próprio, para apresentar numa convenção.
- Verificação encontrou a pasta-alvo **vazia** (criada minutos antes da conversa); usuário confirmou que é o destino da réplica, não a origem — a origem é o próprio repositório atual (`04-Sistemas/*` + `dashboard/` + `supabase/`).
- Usuário colou credenciais reais de um projeto Supabase (`sb_publishable_...`, `sb_secret_...`, JWT `anon`/`service_role`) no chat; confirmado que é um **projeto novo dedicado à demo**, não produção. Nenhuma chave foi gravada na SPEC ou em qualquer arquivo commitável, por regra do `AGENTS.md` e por já existir um incidente anterior (03/07/2026) de credencial commitada em texto plano.
- Levantamento do estado atual corrigiu uma desatualização na memória: são **10 sistemas React** em `04-Sistemas/` (não 6), incluindo `compras-lucenera-3o23t98ee` (Compras, distinto de Gestão Financeira) e `dashboard-lucenera-b02z85wa3` (dashboard de métricas web, distinto do `dashboard/` Python). `cadastro-lucenera-b86fe` aparece como não-rastreada no `git status`; `lucenera-crm-3bd29 (1)` está desatualizada em relação à versão publicada no Skip.
- Achado importante: `supabase/db/current/` (snapshot do schema) está desatualizado desde 07/07/2026 — faltam ~31 migrations. SPEC recomenda recriar o schema do projeto de demo via replay de `supabase/db/migrations/*` (62 pastas), não via esse snapshot. `08_seed_minimo.sql` está vazio — não há seed reaproveitável, todo dado mockado é novo.
- Usuário sinalizou interesse numa opção multi-tenant para o Supabase de demo; SPEC registra isso como decisão em aberto (duas opções), não como algo já implementado.
- Nenhuma implementação feita ainda. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-048_Replica_Demo_Convencao_Dados_Mockados.md`.

## 2026-07-24 (5)

### Criado — SPEC-047: sincronização diária automática (SharePoint → CRM + link)

- Usuário pediu pra pensar em sincronizar a lista "Organização Projetos" do SharePoint (onde os projetos nascem de verdade) com o CRM, pra projeto novo lá já aparecer aqui — e já preferiu que rode como agendamento diário no próprio Supabase (Edge Function + Cron), em vez de depender de sessão do Claude Code.
- Investigação (só leitura, via Graph API) achou que a Edge Function `sync-sharepoint` já existente **nunca deve ter funcionado**: ela tenta gravar campos (`responsavel`, `arquiteto_responsavel`, `prazo`, `valor`...) que não existem na tabela `projetos` real, e casa por `nome` em vez de `codigo`.
- Mapeamento real dos campos da lista confirmado por leitura direta: código, nome, responsável, cidade, nível estratégico e arquivado batem limpo com colunas do CRM. Status (`field_10`, valores tipo "Contrato de Projeto") não bate com o enum controlado do CRM, e arquiteto/engenheiro na lista são texto livre enquanto no CRM são vínculo por ID — ambos ficaram de fora do escopo v1 por risco de gravar errado.
- SPEC-047 registra a decisão: escopo v1 só com campos seguros (status/arquiteto/engenheiro continuam manuais), reaproveitando a lógica de link do SharePoint já testada na SPEC-046. Nenhuma implementação feita ainda.
- Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-047_Sincronizacao_Diaria_SharePoint_Projetos.md`.

## 2026-07-24 (4)

### Executado — SPEC-046: sincronização de Links do SharePoint para o histórico completo (`11.xxx`–`25.439`)

- Usuário pediu para estender a sincronização pra todo o histórico abaixo de `26.000` — 3.431 projetos, até o código `11.002` (bem mais do que os 165 do lote `26.xxx`).
- `--dry-run` revelou 472 matches, 2.002 "pasta não encontrada" (esperado pra histórico antigo), 295 sem `responsavel_nome`, e 661 erros de site 404 — mas o erro é **sistemático por pessoa**, não aleatório: os sites "PROJETOS\<NOME\>" não existem pra 11 responsáveis (Bender, Angélica, Ligia, Rianne, Amanda, Filippo, Vilber, Mary, Eduardo, Lais, Maria, João), provavelmente sites antigos renomeados/arquivados ou fora do padrão de nome assumido.
- Rodado sem `--dry-run`: **472 projetos atualizados** com sucesso (resultado idêntico ao dry-run).
- Total do dia com as 3 rodadas desta SPEC: **620 projetos** com `link_sharepoint` preenchido automaticamente, de um universo de ~3.600 projetos com código `XX.XXX`.
- Pendência registrada: descobrir o nome real dos 11 sites que deram 404 pra poder reprocessar os 661 projetos afetados.
- Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-046_Sincronizacao_Links_SharePoint_Projetos.md`.

## 2026-07-24 (3)

### Executado — SPEC-046: sincronização de Links do SharePoint para todos os projetos `26.xxx`

- Após validar o teste inicial (26.170–26.180), usuário pediu para rodar `scripts/sincronizar_links_sharepoint.py` para todos os projetos com código `26.xxx` (`--min 26.000 --max 26.999`).
- Resultado: **140 projetos atualizados** com `link_sharepoint`, 0 erros de site. 10 já tinham link e não foram sobrescritos (regra de segurança do script). 15 ficaram sem preencher automaticamente: 10 por "pasta não encontrada no site" (pasta pode não existir, ter nome fora do padrão, ou estar em subpasta — o script só olha a raiz da biblioteca) e 5 por falta de `responsavel_nome` no projeto (script não sabe em qual site "PROJETOS X" procurar).
- Lista completa dos 15 pendentes registrada na SPEC-046 (seção Realizado/Pendências) para acompanhamento manual.
- Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-046_Sincronizacao_Links_SharePoint_Projetos.md`.

## 2026-07-24 (2)

### Adicionado — SPEC-046: script de sincronização de Links do SharePoint (teste inicial, 8 projetos)

- Complemento da SPEC-045 (campo `link_sharepoint` manual): criado `scripts/sincronizar_links_sharepoint.py`, que lê a estrutura real do SharePoint via Microsoft Graph API (app "Lucenera Conexão Sharepoint para Skip", permissão `Files.Read.All` já concedida) e preenche `projetos.link_sharepoint` automaticamente — resolve o site pelo `responsavel_nome` (`PROJETOS<NOME>`), lista as pastas do site e casa pelo código no início do nome da pasta.
- Regra de segurança: só preenche projetos com link vazio, nunca sobrescreve. Suporta `--dry-run`.
- Testado no intervalo `26.170`–`26.180` a pedido do usuário, pra conferência antes de rodar geral: 2 tentativas de autenticação falharam por confusão entre "ID secreto" e "Valor" do client secret no Azure (erro AADSTS7000215) — resolvido depois de gerar um novo segredo e copiar a coluna certa. Rodado com sucesso: 8 projetos atualizados, 2 ignorados (já tinham link — um deles, 26.173, com um link suspeito apontando pra Home do site em vez da pasta), 1 sem `responsavel_nome` (26.178, ficou de fora).
- Ainda não rodado para o restante dos projetos — aguardando o usuário conferir os 8 links no CRM.
- Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-046_Sincronizacao_Links_SharePoint_Projetos.md`.

## 2026-07-24 (1)

### Adicionado — SPEC-045: Link do SharePoint no card de Projeto (CRM)

- Chefe quer acompanhar projetos de perto; o CRM só tem os dados do Supabase, não o que está no SharePoint (pasta por projeto com subpastas WhatsApp, Projetos, Originais, Orçamentos, Fotos, Email, DocuSign). Pedido: um campo no projeto para guardar o link da pasta raiz do SharePoint, editável junto com o resto do projeto.
- Nova coluna `projetos.link_sharepoint` (text, nullable) — migration `20260724_061_link_sharepoint_projeto`, **aplicada no Supabase real** via script Python (`psycopg2`) usando `SUPABASE_DB_URL` do `.env`. Primeira tentativa bloqueada automaticamente pelo classificador de segurança (escrita direta em infraestrutura compartilhada); usuário confirmou explicitamente antes da segunda tentativa, que aplicou com sucesso.
- `src/pages/ProjectDetail.tsx` (CRM, Skip `projectId 24580`): novo card "Link do SharePoint" entre "Informações Gerais/Responsáveis" e "Itens Aprovados do Projeto" — mostra link clicável (abre em nova aba) em modo leitura, campo de URL no mesmo toggle Editar/Salvar/Cancelar já existente.
- Não usa nem altera a Edge Function `sync-sharepoint` já existente no projeto (sincroniza listas de um site SharePoint diferente para popular `projetos`/`tabela_precos` em massa) — são funcionalidades independentes.
- Limitação registrada: `src/lib/supabase/types.ts` (tipos gerados) não foi atualizado — arquivo grande demais para a ferramenta de patch desta sessão; contornado com `as any` nos pontos que leem/escrevem `link_sharepoint`, documentado como pendência para quando os tipos forem regerados.
- QA completo `ok`, publicado como versão `0.0.284` (hash `c590768`).
- Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-045_CRM_Link_SharePoint_no_Projeto.md`.

## 2026-07-23 (11)

### Corrigido — limite de largura de página (`max-w-[1400px]`) removido globalmente

- Usuário sugeriu, com print, que o certo era o container/Card se adaptar à largura real da tela em vez de ficar travado, e que isso deveria valer pra outras páginas do sistema também.
- Causa raiz: `src/components/Layout.tsx` tem `<main className="... max-w-[1400px]">`, compartilhado por todas as páginas via `<Outlet />` — travava o conteúdo em 1400px mesmo em monitores maiores, sobrando espaço vazio. Removido o `max-w-[1400px]` do `<main>`.
- Além disso, `src/pages/Index.tsx` (Dashboard), `src/pages/contatos/Clientes.tsx`, `Arquitetos.tsx` e `Engenheiros.tsx` tinham cada uma o mesmo `max-w-[1400px] mx-auto` duplicado no próprio container raiz da página — removido nas 4, senão continuariam travadas mesmo com o Layout corrigido.
- Efeito: a Planilha de Projetos (e as demais páginas) agora usam a largura real disponível da tela, dando mais espaço pras colunas sem precisar cortar tanto texto.
- QA completo `ok`, publicado como versão `0.0.282` (hash `f211e67`).

## 2026-07-23 (10)

### Corrigido — texto cortado nas colunas da Planilha de Projetos após o fix anterior

- Usuário mandou print mostrando que, embora a tabela agora coubesse na tela sem scroll, o conteúdo estava sendo cortado mesmo em colunas "largas o bastante" (`26...` em vez de `26.180`, `24/06/...` em vez da data completa).
- Causa: o componente `TableHead`/`TableCell` (shadcn) já vem com `px-4` (16px de cada lado) embutido por padrão; como as larguras de coluna do ajuste anterior não levaram esse padding em conta, sobrava pouco espaço real pro texto. Corrigido adicionando `px-2` (8px) em todas as células dessa tabela, reduzindo o padding herdado, e reajustando as larguras (`Código` 70px, `Nível` 56px, `Entrada`/`Fechamento` 92px, `Valor Total` 105px, `Cidade` 100px, `UF` 40px, `Ações` 88px) para acomodar o conteúdo real (código completo, data completa dd/mm/aaaa) sem cortar.
- QA completo `ok`, publicado como versão `0.0.281` (hash `807d3c2`).

## 2026-07-23 (9)

### Corrigido — Planilha de Projetos (modo Completa) exigia scroll horizontal

- Usuário reportou, com prints, que a visão "Planilha" de Projetos no modo "Completa" (12 colunas) exigia arrastar a tabela para os lados para ver todas as informações — no modo "Operacional" (menos colunas) cabia sem problema.
- `src/pages/Projetos.tsx`: tabela passou a usar `table-fixed` com largura fixa reduzida por coluna (a coluna "Projeto" é a única flexível, absorve o espaço restante). Removido o `min-w-[700px]` que forçava a tabela a ser mais larga que o necessário. Rótulos de cabeçalho encurtados onde fazia sentido (ex.: "Nível Estratégico" → "Nível", "Data Entrada" → "Entrada"), texto menor (`text-xs`/`text-[10px]`) e `truncate` com tooltip (`title`) nas células que podem ter texto longo (nome do projeto, responsável, engenheiro/arquiteto, cidade).
- QA completo `ok`, publicado como versão `0.0.280` (hash `01f83aa`).
- Não é uma mudança de dado/banco, só de layout — não gerou entrada de SPEC nova (ajuste vinculado ao trabalho de padronização de visualização já registrado na SPEC-044).

## 2026-07-23 (8)

### Ajustado — SPEC-044: CPF e Endereço no cadastro de pessoas de Arquiteto

- Usuário pediu que cada pessoa adicionada em "Pessoas da Empresa" também tenha CPF e Endereço, não só nome/data de nascimento/e-mail.
- Adicionados os campos `cpf_cnpj` e `endereco` nos dois lugares onde uma pessoa é criada: no diálogo "Novo Arquiteto" (`Arquitetos.tsx`) e no "+ Adicionar Pessoa" da página cheia (`ContatoDetail.tsx`).
- QA completo `ok`, publicado como versão `0.0.279` (hash `a66db01`).
- Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-044_CRM_Visualizacao_Tela_Cheia_e_Pessoas_por_Empresa_Arquitetos.md`.

## 2026-07-23 (7)

### Ajustado — SPEC-044: adicionar pessoas já dentro do diálogo "Novo Arquiteto"

- Usuário pediu explicitamente a segunda abordagem (não escolhida na rodada anterior): poder adicionar mais de uma pessoa da empresa **direto no diálogo de criação**, sem precisar salvar e ser redirecionado para a página cheia primeiro.
- `Arquitetos.tsx`: diálogo "Novo Arquiteto" ganhou seção "Pessoas da Empresa (opcional)" com "+ Adicionar Pessoa" — linhas locais (nome/data nascimento/e-mail) editáveis e removíveis, mantidas em estado até o submit. Ao salvar: valida nome obrigatório em cada linha adicionada, cria o registro da empresa, insere todas as pessoas em lote com `empresa_id` apontando para a empresa recém-criada, e navega para a página cheia dela (onde as pessoas já aparecem).
- QA completo `ok`, publicado como versão `0.0.278` (hash `bebf76a`).
- Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-044_CRM_Visualizacao_Tela_Cheia_e_Pessoas_por_Empresa_Arquitetos.md`.

## 2026-07-23 (6)

### Ajustado — SPEC-044: Data de Nascimento/RG no cadastro rápido de Arquiteto + redirect pós-criação

- Usuário testou a SPEC-044 e reportou não encontrar Data de Nascimento, e-mail nem opção de mais de uma pessoa — estava no diálogo "Novo Arquiteto" (cadastro rápido), que tinha ficado fora do escopo original de propósito (só a página cheia pós-criação ganhou esses campos). Usuário confirmou que em alguns casos precisa disso já na criação.
- `Arquitetos.tsx`: diálogo "Novo Arquiteto" ganhou os campos Data de Nascimento (novo) e RG (já existia no schema, faltava o campo de formulário). Ao salvar, o insert usa `.select().single()` e navega direto para a página cheia do registro recém-criado (`/contatos/arquitetos/:id`), onde o usuário já pode clicar em "+ Adicionar Pessoa" na hora — evita a abordagem mais complexa de duplicar a lógica de "adicionar pessoa" dentro do próprio diálogo de criação.
- QA completo `ok`, publicado como versão `0.0.277` (hash `abb984d`).
- Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-044_CRM_Visualizacao_Tela_Cheia_e_Pessoas_por_Empresa_Arquitetos.md`.

## 2026-07-23 (5)

### Implementado — SPEC-044: tela cheia no CRM + Pessoas por Empresa em Arquitetos

- Usuário confirmou a SPEC-044 e pediu para executar. Implementado direto no projeto Skip "Lucenera CRM" (`projectId 24580`, mesmo caminho das SPEC-042/043, já que o submodule local está desatualizado).
- Criada página cheia genérica `src/pages/contatos/ContatoDetail.tsx` (rota `/contatos/:tipoPlural/:id`), com campos configurados por tipo e alternância Editar/Salvar/Cancelar, no padrão de `ProjectDetail.tsx`. `Clientes.tsx`, `Arquitetos.tsx`, `Engenheiros.tsx`, `Eletricistas.tsx` e `Projetos.tsx` foram reescritos para navegar até essa página (ou até `/projeto/:id`, já existente) em vez de abrir Sheet/Dialog — Sheet lateral de Projetos e Clientes removido, Dialogs de visualização/edição de Arquitetos/Engenheiros/Eletricistas removidos (criação continua igual).
- Campo `data_nascimento` (já existia no banco, nunca exposto) passou a ser editável nos 4 tipos de contato. Eletricista ganhou edição completa (antes só tinha cadastro + visualização) e exclusão.
- "Pessoas da Empresa" implementado em Arquitetos usando o relacionamento já existente `contatos.empresa_id -> contatos.id` (documentado em `supabase/db/domains/cadastros.md`) — nenhuma migration necessária. Pessoas vinculadas a uma empresa não aparecem na listagem principal de Arquitetos nem nos combos de seleção de arquiteto (`ProjectNew.tsx`, `ProjectDetail.tsx`) — filtro `empresa_id IS NULL` aplicado nesses três lugares.
- `supabase/AI_DB_CONTEXT.md` do CRM atualizado com uma seção "SPEC-044" documentando essa regra para qualquer código futuro que liste/selecione arquitetos.
- QA completo no Skip passou em todas as etapas (setup, análise estática, build, integrações, testes). Publicado em produção, versão final `0.0.276` (hash `2e63bae`), `https://lucenera-crm-3bd29.goskip.app`.
- Nenhuma mudança de schema ou dado no Supabase.
- Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-044_CRM_Visualizacao_Tela_Cheia_e_Pessoas_por_Empresa_Arquitetos.md`.

## 2026-07-23 (4)

### Criado — SPEC-044: tela cheia no CRM (Projetos/Clientes/Arquitetos/Engenheiros/Eletricistas) + pessoas por empresa em Arquitetos

- Usuário reportou que a visualização/edição de Projetos, Clientes, Arquitetos, Engenheiros e Eletricistas hoje abre um card lateral (Sheet) ou modal central (Dialog), e pediu que virasse uma aba/página cheia, igual ao padrão já usado em "Novo Projeto" e em `ProjectDetail.tsx`.
- Levantamento confirmou 3 padrões diferentes hoje: Projetos e Clientes usam `<Sheet>` lateral; Arquitetos/Engenheiros/Eletricistas usam `<Dialog>` central; Eletricistas nem tem formulário de edição (só cadastro + visualização somente-leitura). Nenhuma das 5 telas usa página cheia por padrão, embora `ProjectDetail.tsx` (`/projeto/:id`) já exista e funcione.
- Durante o desenho, usuário pediu também que Arquitetos ganhe suporte a "várias pessoas no mesmo cadastro" (para escritórios com múltiplos arquitetos) — precisa ficar no mesmo cadastro para não fragmentar comissão por projeto, mas precisa registrar nome/aniversário/e-mail de cada pessoa para contato individual. Achado: o banco já modela exatamente essa relação via `contatos.empresa_id -> contatos.id` (documentado em `supabase/db/domains/cadastros.md`), então a SPEC não precisa de nenhuma migration — só passa a usar essa coluna que já existe.
- Decisões fechadas com o usuário: (1) um único componente de página cheia genérico por tipo de contato, não 4 páginas separadas; (2) Sheet de Projetos é removido, vai direto para `/projeto/:id`; (3) Eletricistas ganha edição nesta SPEC; (4) pessoas vinculadas a uma empresa de Arquitetos não aparecem na listagem principal nem em combos de seleção — só dentro da página cheia da empresa.
- Nenhuma implementação feita ainda. Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-044_CRM_Visualizacao_Tela_Cheia_e_Pessoas_por_Empresa_Arquitetos.md`.

## 2026-07-23 (3)

### Otimizado — CRM: elimina fetch triplicado e storm de realtime (SPEC-043)

- Usuário aprovou implementar a SPEC-043 com uma restrição: sem mudanças estruturais no sistema nem no schema/dados do Supabase nesta rodada — só otimização de aplicação.
- Implementado direto no projeto Skip "Lucenera CRM" (`projectId 24580`), já que o submodule local está desatualizado (ver entrada anterior). `src/stores/useProjectStore.tsx` reescrito com `loading` no contexto e debounce de 1,5s nos dois canais de realtime (`proj_changes`/`cont_changes`), que antes disparavam refetch completo a cada evento individual, para todos os usuários conectados. `src/pages/Index.tsx` e `src/pages/Projetos.tsx` pararam de chamar `getProjetos()` por conta própria e passaram a consumir a store compartilhada — antes, navegar entre `/` e `/projetos` disparava até 3 buscas independentes da tabela `projetos` inteira (4 joins + parcelas cada). `Index.tsx` também parou de rebuscar a lista completa a cada evento realtime; seu canal ficou só para a RPC `get_dashboard_stats` + 5 projetos recentes, também debounced.
- Deliberadamente fora do escopo desta rodada: paginação real de servidor em `getProjetos()`, troca do dashboard para usar RPC de agregação, code splitting por rota, e qualquer índice/RLS no banco — todos ficam registrados como pendência na SPEC-043 para uma rodada futura, se necessário.
- QA completo no Skip (`skip_project_apply_changes`): setup, análise estática, build, integrações e testes, todos `ok`. Publicado como versão `0.0.274` (hash `4e1d103`) em produção (`https://lucenera-crm-3bd29.goskip.app`).
- Nenhuma medição objetiva de tempo de carregamento disponível (Skip Cloud não integrado ao projeto, sem logs de request) — validação de que a lentidão melhorou fica pendente de uso real pelo usuário.
- Detalhes em `03-Projeto/Planos de Ação/SPECs/SPEC-043_Otimizacao_Performance_CRM.md`.

## 2026-07-23 (2)

### Adicionado — `lucenera-crm` registrado como submodule em `04-Sistemas/`

- Pendência aberta desde a SPEC-042 (e reforçada na SPEC-043): usuário aprovou trazer o CRM para dentro do repositório central.
- `git submodule add -f https://github.com/pedrolalala/lucenera-crm.git "04-Sistemas/lucenera-crm-3bd29 (1)"` — `.gitmodules` já tinha a entrada declarada (nunca havia sido efetivamente inicializada); `04-Sistemas/` é ignorado no `.gitignore` geral, por isso precisou de `-f`, mesmo padrão usado pelo `scripts/submodules-register.sh` para os demais sistemas.
- Ponteiro aponta para `heads/main` do GitHub, commit `9078947` — **defasado** em relação ao publicado em produção no Skip (projeto `24580`, versão `0.0.273`, hash `16f6c06`): as mudanças da SPEC-042 (formulário completo de cliente, edição de vínculos no Sheet de Projeto) foram commitadas no Skip mas o push para o GitHub `main` nunca foi confirmado. Ou seja, o conteúdo local do submodule ainda não reflete o que está em produção — ver pendência registrada na SPEC-043.
- Nenhum commit feito ainda no repositório central (apenas `git submodule add`, staged); commit fica pendente de confirmação do usuário.

## 2026-07-23 (1)

### Criado — SPEC-043: diagnóstico de performance do CRM

- Usuário relatou CRM muito lento/travando, "às vezes parece que não está funcionando" por horas. Sistema não está carregado como submodule em `04-Sistemas/` (mesma situação da SPEC-042); diagnóstico feito lendo o código-fonte real via MCP Skip (projeto "Lucenera CRM", `projectId 24580`) e o schema no snapshot central `supabase/db/current/`.
- Achados principais (severidade alta): `getProjetos()` (`src/services/projetos.ts`) faz full-fetch paginado da tabela `projetos` inteira com 4 joins de FK + parcelas, chamado de forma independente 3x (`useProjectStore.tsx`, `Index.tsx`, `Projetos.tsx`); realtime (`postgres_changes` em `projetos`/`contatos`) dispara esse full-fetch e um `select('*').limit(5000)` de contatos em todos os navegadores conectados a cada INSERT/UPDATE/DELETE, sem debounce; `Projetos.tsx` ignora a store global e refaz o fetch por conta própria.
- Achados secundários (média/a confirmar): dashboard recalcula agregações no cliente em vez de usar a RPC `get_dashboard_stats` já existente; ausência de `@tanstack/react-query`/cache no frontend; zero code splitting por rota em `App.tsx`; índice possivelmente ausente em `projetos.arquiteto_id`/`responsavel_id`/`projeto_itens.projeto_id` (não confirmado, migrations locais do CRM não são fonte confiável); volume alto de policies RLS por tabela (14–16), sem evidência de subquery complexa.
- Nenhuma implementação feita ainda — SPEC fica pendente de priorização do usuário entre os 9 itens do checklist antes de qualquer mudança de código ou migration.
- Detalhes completos em `03-Projeto/Planos de Ação/SPECs/SPEC-043_Otimizacao_Performance_CRM.md`.

## 2026-07-23 (18)

### Aplicado — cruzamento 7 (completar cadastro do cliente): 14 clientes

- Telefone/email/endereço completados via planilha `Cliente` (só onde estava `NULL`, nunca sobrescreve): 9 telefone, 9 email, 9 email_financeiro, 9 endereço, 11 bairro, 9 cidade, 9 estado — 14 clientes distintos afetados.
- Cobertura já estava alta (82-90%) antes — essa planilha aparenta ter sido a fonte original de importação de `contatos`, não uma planilha nova trazendo dado inédito.

## 2026-07-23 (17)

### Aplicado — cruzamento 6 (Projeto → Arquiteto): 1.610 projetos ligados ao arquiteto real

- `projetos.arquiteto_id` preenchido para 1.610 de 3.039 projetos sem arquiteto, via nome exato entre `projetos."Nome Arquiteto"` e `contatos` tipo=arquiteto. `arquiteto_id`: 662 → 2.272.
- `responsavel_obra_id` não aplicado — os valores da planilha ("Responsável da Obra") são nomes de arquitetos/escritórios terceiros, não batem com nenhum dos 9 usuários internos do sistema (0 de 814).

## 2026-07-23 (16)

### Aplicado — cruzamento 5 (Financeiro → Projeto): 2.132 negociações ligadas ao projeto real

- `negociacoes.projeto_id` preenchido para 2.132 de 12.750 negociações, via `cod_venda` → planilha `venda` → código do projeto embutido no nome do cliente → `projetos.codigo`.
- 309 negociações sem `cod_venda`; das 12.441 restantes, só 17% resolvem projeto — mesmo gargalo de dado ausente dos outros cruzamentos.

## 2026-07-23 (15)

### Aplicado — cruzamento 2 (Projeto → Responsável): 1.774 projetos ligados ao usuário real

- Segundo cruzamento do projeto "Cruzamento de Dados" (ver `01-Documento/01 - Planilhas/DECISOES.md`): `projetos.responsavel_id` preenchido para 1.774 dos 2.901 projetos com `responsavel_nome` mas sem `responsavel_id`, via match de nome (case-insensitive/trim) contra os 9 usuários reais do sistema.
- 1.127 projetos continuam sem `responsavel_id` — nome histórico não corresponde a nenhum usuário ativo (equipe antiga, sem login).
- `projetos.responsavel_id`: 394 → 2.168 preenchidos.

## 2026-07-23 (14)

### Aplicado — cruzamento 1 (Projeto → Cliente): 546 projetos ligados ao cliente real

- Primeiro cruzamento do projeto "Cruzamento de Dados" (ver `01-Documento/01 - Planilhas/DECISOES.md`) aplicado em produção: `projetos.cliente_id` preenchido para 546 dos 3.182 projetos que estavam sem cliente vinculado, via match seguro (código do projeto embutido no cadastro do cliente, ou nome do projeto = nome do cliente, ambos únicos).
- 7 casos com pistas conflitantes ficaram de fora (não aplicados) — pelo menos um investigado é cadastro de cliente duplicado, não erro de cruzamento.
- 2.629 projetos continuam sem `cliente_id` por falta de qualquer pista rastreável nas fontes disponíveis hoje.
- `projetos.cliente_id`: 519 → 1.065 preenchidos (de 3.701 projetos).

## 2026-07-23 (13)

### Corrigido — `projetos.client_id` removido; 4 dashboards que estavam "cegos" para cliente voltaram a funcionar

- Início do projeto "Cruzamento de Dados" (ver `01-Documento/01 - Planilhas/AGENTS.md` e `DECISOES.md`, novos): plano de 9 cruzamentos para preencher `cliente_id`/`responsavel_id` de projetos e ligar o histórico de vendas (planilha `Cruzamento de dados.xlsx`, cruzada contra o Supabase real).
- Antes do cruzamento 1 (Projeto → Cliente), validado se `projetos.client_id` (coluna duplicada de `projetos.cliente_id`, nunca preenchida) era código morto. Não era: usada em 10 views do banco, sendo 4 delas (`vw_projetos_pipeline`, `vw_projetos_por_status`, `vw_financeiro_projetos`, `vw_dashboard_crm_fechamento` — Pipeline, Status, Financeiro por Projeto e Fechamento do CRM) sem nenhum fallback, retornando cliente/contagem vazios para 100% dos projetos desde sempre.
- Corrigido via `supabase/db/migrations/20260723_061_remove_projetos_client_id/`: as 10 views passaram a usar `cliente_id`; índice e FK de `client_id` removidos; coluna `client_id` removida de `projetos`. Aplicada em produção via `psycopg2`, com verificação antes do commit (ex: `vw_projetos_por_status` passou de `total_clientes = 0` em todas as linhas para contagens reais).
- `supabase/db/current/01_schema_full.sql` atualizado para refletir a remoção (coluna, comentário, índice, FK e as 10 views).

## 2026-07-23 (12)

### Importado — planilhas Connect (ContaPagar/ContaReceber/Produtos) de 23/07/2026

- Preparação de dados antes do cruzamento 1 (ver `01-Documento/01 - Planilhas/DECISOES.md`): rodados `scripts/importar_contas_pagar_receber.py` e `scripts/importar_produtos_estoque.py` sobre as planilhas mais recentes, agora localizadas em `01-Documento/01 - Planilhas/Atualização 23.07.2026/` (`ContaPagar_2026-07-23.xlsx`, `ContaReceber_2026-07-23.xlsx`, `Produtos__2026-07-23.xlsx`) — constantes de caminho hardcoded nos dois scripts atualizadas antes da execução (apontavam para a pasta/arquivos de 22/07).
- Contas a Pagar/Receber: 21 negociações novas (empresa LUCE NERA), 68 transações novas, 2.904 atualizadas, 0 erros. 488 linhas com `(cod_duplicata, tipo)` ambíguo entre empresas puladas por desenho (mesmo comportamento documentado no ciclo de 22/07).
- Produtos: 291 de 4.409 atualizados (4.061 já sincronizados, 57 sem match no banco — códigos ainda não cadastrados), 0 erros.
- Ambiente Python do repositório central não tinha `pandas` instalado (só `psycopg2`/`supabase`/`dotenv`) — instalado via `pip install pandas` antes de rodar os scripts.

## 2026-07-22 (8)

### Adicionado — 51 pedidos históricos em `pedidos_compra` (tela real), sem item de produto (decisão do usuário)

- Após o import (7) para as tabelas órfãs `pedido_compra`/`staging_pedido_compra`, o usuário pediu que esses pedidos aparecessem na tela real "Pedidos de Compra" (`/pedidos`, `compras-lucenera-3o23t98ee`) — mas **sem** vincular a item de produto, porque um pedido linkado a produto reduziria "Pendente" na Necessidade de Compra para um déficit que pode não existir mais hoje (pedido de abril/2025 não deve mexer em necessidade de julho/2026).
- Confirmado tecnicamente antes de implementar: `PedidosCompra.tsx`/`getPedidosCompra()` lê `pedidos_compra` direto (`select('*, contatos!fornecedor_id(nome)')`), sem exigir item — um pedido sem `pedido_compra_itens` aparece na lista e **não** entra em `vw_necessidade_compra`/`vw_necessidade_compra_pedidos_abertos` (que só agregam via item→produto).
- Script novo `scripts/criar_pedidos_compra_legado.py`: cria 1 pedido em `pedidos_compra` por `codigo_pedido` (numero `PC-LEGADO-<codigo_pedido>`, status `enviado`, `empresa_id` = LUCE NERA grupo — mesmo padrão do import ContaPagar/ContaReceber), fornecedor resolvido por match exato de nome contra `contatos` (tipo=fornecedor; não existe `codigo_fornecedor` em `contatos`, só `codigo_legado` para clientes). Grava também as parcelas **reais** da planilha (`vl_duplicata`/`dt_vencimento`/`num_parc`) em `pedido_compra_parcelas`, em vez de gerar por divisão automática — mais preciso.
- **9 dos 60 pedidos ficaram de fora, propositalmente, por fornecedor ambíguo/sem cadastro** (não adivinhado, mesmo princípio já usado no import ContaPagar/ContaReceber para `(cod_duplicata,tipo)` ambíguo):
  - STELLA (pedidos 646, 1699, 1700, 1713, 1714): 2 contatos com o mesmo nome em `contatos`, CNPJs de filiais diferentes (SC `10.691.158/0003-70` vs RS `10.691.158/0001-09`) — planilha não traz CNPJ para desambiguar.
  - TENSOFLEX (pedidos 1702, 1709, 1723): mesma situação, 2 contatos com CNPJs diferentes, ambos Rio de Janeiro.
  - METALURGICA IL INDUSTRIA DE ILUMINAÇÃO LTDA (pedido 1659): não existe em `contatos` (é diferente de "METALURGICA AVER METAIS LTDA", que já existe).
  - **Pendência do usuário**: decidir qual CNPJ é o correto para STELLA/TENSOFLEX (ou consolidar os contatos duplicados) e cadastrar o fornecedor faltante, depois rodar o script de novo (idempotente — pula `codigo_pedido` já convertido em `PC-LEGADO-*`, e teria que remover esses 3 nomes de `CODIGOS_PEDIDO_PULADOS` no script).
- Executado com sucesso: 51 pedidos novos em `pedidos_compra`, 45 parcelas reais em `pedido_compra_parcelas`, 0 erros. Confirmado pós-import: `pedido_compra_itens` continua em 0 registros (Necessidade de Compra intocada, como pretendido).
- Detalhes em `supabase/db/domains/estoque_compras.md`.

## 2026-07-22 (7)

### Importado — planilha PedidoCompra (financeiro) de 22/07/2026, novo script `importar_pedido_compra.py`

- Pedido do usuário: migrar `PedidoCompra_2026-07-22.xlsx` para popular "o campo do sistema de necessidade de compra" com dados reais.
- Investigação prévia encontrou um descompasso: a planilha só tem dados financeiros por pedido (`codigo_pedido`, fornecedor, `vl_nota`, parcelas) — nenhuma linha de produto/quantidade. A tela "Necessidade de Compra" (`compras-lucenera-3o23t98ee`) usa uma arquitetura totalmente separada (`pedidos_compra` plural + `pedido_compra_itens`, granular por produto), que exige item de produto para um pedido aparecer nela — dado que essa planilha não tem.
- Achado adicional: já existiam no banco `pedido_compra` (singular) + `staging_pedido_compra`, com colunas desenhadas exatamente para essa planilha, mas **órfãs** — nenhum código do ecossistema as lê (confirmado por busca em `04-Sistemas/`, `dashboard/`, `scripts/`, `supabase/functions/`) e não existia script de import nem função de transformação `staging → final`.
- Apresentado o achado ao usuário, que optou por importar mesmo assim como dado financeiro puro (pedido → fornecedor → parcelas), ciente de que **não afeta** as colunas Pendente/Status do Pedido/Entrega Prevista da tela de Necessidade de Compra.
- Script novo `scripts/importar_pedido_compra.py`: carrega a aba "Financeiro", grava fidelidade total (91 linhas, 1 por linha de Excel/parcela) em `staging_pedido_compra` (delete+insert por `codigo_pedido`, rerun-safe) e um header deduplicado por `codigo_pedido` (UNIQUE no schema real) em `pedido_compra` — upsert por `codigo_pedido`. Pedidos com 2+ parcelas na planilha (14 de 60) ficam com `numero_parcela`/`data_vencimento`/`valor_duplicata` `NULL` no header (1 linha não comporta N parcelas), preservados por completo em `staging_pedido_compra`.
- Executado com sucesso: 60 pedidos novos em `pedido_compra`, 91 linhas em `staging_pedido_compra`, 0 erros. Tabela estava 100% vazia antes desta importação.
- Detalhes em `supabase/db/domains/estoque_compras.md`.

## 2026-07-22 (6)

### Importado — planilhas Connect (ContaPagar/ContaReceber/Produtos) de 22/07/2026

- Rodados `scripts/importar_contas_pagar_receber.py` e `scripts/importar_produtos_estoque.py` sobre as novas planilhas exportadas do Connect (`ContaPagar_2026-07-22.xlsx`, `ContaReceber_2026-07-22.xlsx`, `Produtos__2026-07-22.xlsx`) — constantes de nome de arquivo hardcoded nos dois scripts atualizadas antes da execução.
- Contas a Pagar/Receber: 64 negociações novas (empresa LUCE NERA), 127 transações novas, 2.953 atualizadas, 0 erros. 488 linhas com `(cod_duplicata, tipo)` ambíguo entre empresas puladas por desenho.
- Produtos: inicialmente 250/252 produtos atualizados — 2 falharam com `numeric field overflow` em `percentual_lucro` (`numeric(5,2)`, máx 999,99), pois 2 produtos de custo residual (R$0,10) têm margem de 1150% na planilha (dado legítimo). Corrigido via migration `20260722_060_ampliar_precisao_percentual_lucro` (`percentual_lucro` → `numeric(9,2)`), aplicada em produção; reimport confirmou os 252/252 sincronizados sem erros.
- Detalhes em `supabase/db/domains/cadastros.md`.

## 2026-07-22 (5)

### Adicionado — SPEC-041: nomenclatura Realizado × Previsto + card Necessidade de Compra no Dashboard

- Reunião 21/07/2026 (Filippo) pediu 4 ajustes de nomenclatura/visualização no `dashboard-lucenera-b02z85wa3`: distinguir "Realizado" de valores "em aberto"/futuros, sem misturar necessidade de compra no fluxo de caixa realizado.
- Antes de implementar, descoberto que o espelho local do submodule estava desatualizado em relação ao Skip Cloud publicado (projeto 41135): `Index.tsx` e `cash-flow.ts` locais refletiam um protótipo antigo (KPIs de sincronização), enquanto a versão real em produção já tinha a implementação financeira completa (SPEC-025). Corrigido puxando o conteúdo real do Skip para o git local antes de qualquer edição.
- Implementado: item de menu/`<h1>` "Visão Geral" → "Fluxo de Caixa Realizado (Mês Atual)" (com filtro de mês/ano defaultando ao mês atual, editável); "Contas a Receber/Pagar Foco" → "Agenda de Recebimentos"/"Agenda de Pagamentos"; tooltip (`Info` + `Tooltip`) nos KPIs "Em Aberto (Receber/Pagar)" esclarecendo que são valores acumulados totais, não filtrados pelo período; novo card "Necessidade de Compra (Gasto Futuro Inevitável)" na página principal (`SUM(pendente × preco_custo)` de `vw_necessidade_compra`, via novo `src/services/necessidade-compra.ts`), com tom visual distinto (violeta) para reforçar que não é dado realizado.
- QA (setup/lint/build/testes) passou limpo no Skip; publicado em produção (`dashboard-empresa-40d7d.goskip.app`, versão `a47805c`) com autorização do usuário.
- `vw_necessidade_compra` passa a ter um segundo consumidor (o dashboard, além de `compras-lucenera-3o23t98ee`) — registrado em `supabase/db/domains/estoque_compras.md`.

## 2026-07-22 (4)

### Corrigido — achado adicional: reserva de estoque por item nunca acontecia na aprovação

- Ao confirmar visualmente se os itens do ORC-0010 apareciam na Necessidade de Compra "Por Item de Orçamento", descoberto que `aprovar_orcamento_financeiro` nunca criava `estoque_saldos_projeto_item` (SPEC-010) nem reservava `estoque_itens.quantidade_reservada` — só criava `projeto_itens`/`projeto_parcelas`/`boletos`. Sem o saldo por item, nenhuma peça consegue aparecer numa tela de déficit de estoque, mesmo com L Fixo vinculado corretamente.
- Existia uma segunda função no banco (`aprovar_orcamento_financeiro_base_spec001`) que já fazia essa reserva corretamente, mas não era a chamada pelo sistema e usava nomenclatura de status desatualizada.
- Corrigido via `supabase/db/migrations/20260722_059_unificar_reserva_estoque_aprovacao/` — incorpora a lógica de reserva na função oficial, preservando o contrato de status da SPEC-016 e o vínculo de L Fixo da SPEC-040. Testado com orçamento sintético (déficit forçado): reserva criada corretamente, item apareceu na view real.
- Backfill retroativo aplicado ao ORC-0010 (autorizado pelo usuário): confirmado visualmente na tela publicada — `ORC-0010 / L03 / PLAFON DE EMB ECO / Pendente 1`.

## 2026-07-22 (3)

### Corrigido — backfill pontual de ORC-0010

- Após o hotfix de `aprovar_orcamento_financeiro`, auditados todos os 12 orçamentos com status `Orçamento Aprovado` para ver quais tinham `projeto_itens`/`projeto_parcelas`/`boletos` faltando. Achado: 4 já estavam corretos, 1 (ORC-0010) tinha dados válidos mas nunca foi processado (0 itens/parcelas/boletos), 1 (ORC-0013) tem 2 itens avulsos textualmente idênticos — impossível vincular ao L Fixo correto sem adivinhar, deixado como está por desenho (decisão P-05 da SPEC-040); 6 (ORC-0004, LEG-1092/1100/1108/1115/1169) ficam pendentes por motivos próprios (dado incompleto no orçamento ou parcela órfã pré-existente da importação legada).
- Corrigido apenas o ORC-0010: status voltado temporariamente para `Aprovação Financeira` (sem alterar itens, não reinicia o ciclo), `aprovar_orcamento_financeiro` chamada de verdade, gerou os 3 `projeto_itens` (vinculados a L01/L02/L03 corretamente), 1 parcela e 1 boleto, status retornado a `Orçamento Aprovado`.
- Os outros 6 orçamentos com pendência continuam documentados em `supabase/db/domains/orcamentos.md`, cada um com o motivo específico — não corrigidos nesta rodada, por decisão explícita do usuário.

## 2026-07-22 (2)

### Corrigido — achado crítico: aprovação de orçamento quebrada em produção há ~2 semanas

- Durante investigação de por que itens de orçamentos já aprovados não apareciam vinculados ao L Fixo na Necessidade de Compra (SPEC-040), descoberto que `aprovar_orcamento_financeiro` — a RPC oficial de aprovação financeira, domínio Orçamentos/Financeiro (SPEC-016) — estava falhando em **toda chamada real** desde algum momento após 06/07/2026 (nenhum `projeto_itens` no banco tem data de criação posterior a essa data).
- Causa: `projeto_itens.subtotal` virou coluna `GENERATED ALWAYS` em 26/06/2026, e a correção necessária (remover o `INSERT` explícito nessa coluna) foi aplicada só numa função legada (`aprovar_orcamento_financeiro_base_spec001`), não na função oficial. Um hotfix não documentado (nenhuma migration deste repositório o captura) reintroduziu o `INSERT` explícito na função oficial depois de 06/07, quebrando a aprovação.
- Corrigido via `supabase/db/migrations/20260722_058_hotfix_aprovar_orcamento_subtotal_gerado/`, testado com um orçamento sintético real (2 itens do mesmo produto em L Fixos diferentes, L01/L35) — aprovação funcionou, `projeto_itens` corretamente vinculados por item, parcela e boleto gerados. Dados de teste removidos.
- Detalhes completos em `supabase/db/domains/orcamentos.md`.

### Pendente

- Decisão de produto separada: aplicar ou não a migration `20260706_020` (checagem de permissão, validação de frete, reserva automática de estoque na aprovação) — nunca foi aplicada de fato, fora do escopo deste hotfix.
- Reextrair `supabase/db/current/` para o domínio de Orçamentos também (mesma pendência crônica já registrada para Compras).

## 2026-07-22 (1)

### Corrigido

- Layout da tela Necessidade de Compra (`compras-lucenera-3o23t98ee`) — correção pós-publicação da SPEC-040 feita pelo usuário: shell da aplicação (`App.tsx`) passa a `h-screen flex flex-col overflow-hidden`, com `<main>` distribuindo altura via `flex-1 min-h-0`; `AppNav.tsx` ganhou `shrink-0` para não ser comprimido pelo flex do shell; `NecessidadeCompra.tsx` trocou o cálculo fixo de altura (`h-[calc(100vh-4rem)]`) por `flex-1 min-h-0`, seguindo o padrão flex do shell em vez de um valor calculado manualmente. Publicado em produção — Skip v0.0.47.

## 2026-07-21 (3)

### Adicionado

- Criada e implementada `SPEC-040_Necessidade_Compra_Granularidade_L_Fixo.md` no sistema `compras-lucenera-3o23t98ee`: nova aba "Por Item de Orçamento" na tela Necessidade de Compra, permitindo comprar uma peça específica de uma posição específica ("L Fixo") de um orçamento específico, sem misturar com outras posições do mesmo produto — coexistindo com a aba "Por Produto" (agregada, SPEC-039), que permanece 100% inalterada.
- Isso reverteu, só para esta aba nova, a decisão de "necessidade de compra agregada por produto" (reunião 08/06/2026) — decisão explícita do usuário nesta sessão, confirmada depois de eu alertar sobre o conflito com a decisão documentada.
- Backend: `projeto_itens.orcamento_item_id`/`l_fixo` (FK real para `orcamento_itens`, gravada automaticamente na aprovação financeira do orçamento); backfill best-effort para itens já existentes (9 de 11 preenchidos; casos ambíguos — mesmo produto em 2+ posições do mesmo orçamento — ficam sem vínculo, sem adivinhação); view nova `vw_necessidade_compra_item_orcamento`; vínculo de origem (`pedido_compra_item_origem`) passa a ser obrigatório (não mais melhor-esforço) nas compras feitas por este fluxo novo.

### Corrigido — achado crítico #2: migration de outro domínio nunca aplicada + hotfix não documentado

- Ao preparar a migration que recria `aprovar_orcamento_financeiro` (função central de Orçamentos/Financeiro, SPEC-016 — precisava ganhar 2 colunas novas para viabilizar a SPEC-040), confirmei via consulta direta ao Supabase real que a função ao vivo diverge significativamente tanto da migration `20260706_020` quanto de `supabase/db/current/03_functions.sql`: falta checagem de permissão (admin/gerente), falta validação de frete obrigatório, falta reserva automática de estoque na aprovação — ou seja, essa migration nunca foi de fato aplicada neste banco (mesmo padrão do achado crítico da SPEC-038 com `pedidos_compra`, agora num domínio diferente). Em contrapartida, a função ao vivo tem lógica (cálculo de subtotal, fallback de descrição) que não existe em nenhuma migration do repositório — um hotfix aplicado direto em produção, nunca capturado em arquivo.
- A migration da SPEC-040 foi reescrita para copiar o corpo real da função (confirmado byte a byte via `pg_get_functiondef`), preservando exatamente o comportamento ao vivo — sem adicionar nem remover a checagem de permissão, validação de frete ou reserva de estoque, que ficam como decisão de produto em aberto, separada, do domínio de Orçamentos/Financeiro.
- Todas as 4 migrations da SPEC-040 aplicadas e testadas via chamadas reais (RPC + REST): backfill confirmado, view nova validada, vínculo de origem obrigatório testado com sucesso.
- Frontend sincronizado com o Skip (projeto 40326), QA completo e publicado em produção — versão `0.0.46`.

### Pendente

- Decidir separadamente (fora do escopo de Compras) se a migration `20260706_020` (checagem de permissão, validação de frete, reserva automática de estoque na aprovação de orçamento) deve ser aplicada intencionalmente, ou se foi abandonada por algum motivo que precisa ser investigado primeiro.
- Reextrair `supabase/db/current/` — pendência crônica, agora reforçada por dois achados críticos do mesmo tipo em dois domínios diferentes.
- Testar o golden path pela UI (validação desta sessão foi via API/RPC direta).

## 2026-07-21 (2)

### Adicionado

- Criada e implementada `SPEC-039_Necessidade_Compra_Grid_Fullscreen_Fix_Busca.md` (fluxo planner → implementador → revisor → orquestrador) no sistema `compras-lucenera-3o23t98ee`: layout full-screen da tela Necessidade de Compra (container e grid ocupam 100% da viewport, todas as colunas sempre visíveis com scroll horizontal em vez de esconder colunas em telas menores); colunas novas Fornecedor, Empresa que comprou, Status do pedido e Data prevista de entrega; correção de um bug real de busca; recálculo de "Pendente" descontando pedidos de compra já em aberto.
- Causa raiz do bug de busca confirmada via chamada HTTP direta ao PostgREST: `produtos.codigo_produto` é `integer`, e o filtro antigo usava `ilike` sobre essa coluna (`operator does not exist: integer ~~* unknown`, erro `42883`) — isso derrubava a query inteira, ou seja, **toda busca não vazia falhava**, não só a busca por código. Corrigido tratando termos só-numéricos como busca exata por código (`.eq`) e o restante como busca por nome (`.ilike`), sem cast em runtime.
- 4 migrations aplicadas e testadas no Supabase real (`20260722_056_spec039_necessidade_compra_grid`): `pedidos_compra.empresa_id` (preenchida automaticamente pela RPC a partir da empresa do usuário autenticado, sem input manual no frontend); views `vw_necessidade_compra_pedidos_abertos`/`vw_necessidade_compra_pedido_detalhe` (resumo agregado por produto + detalhe pedido a pedido no painel expansível, resolvendo o conflito de granularidade produto-vs-pedido); `vw_necessidade_compra` recriada com as colunas `pendente`/`qtd_pedidos_abertos`/`proxima_data_prevista_entrega`, e o filtro de visibilidade da lista mudou de "só estoque físico" para "descontando também pedidos de compra já em aberto" (decisão do usuário: produto sai da lista quando o déficit já está 100% coberto por pedido em andamento).
- Teste end-to-end encontrou e corrigiu um resíduo de dados de teste da sessão da SPEC-038 (um pedido de teste `PC-2026-0001` que não foi limpo corretamente por um bug de ordem no script de cleanup daquela sessão) — removido da base real, sem relação com o código desta SPEC.
- Frontend sincronizado com o Skip (projeto 40326), QA completo e publicado em produção — versão `0.0.45`.

### Pendente

- Reextrair `supabase/db/current/` — pendência crônica reafirmada mais uma vez.
- Testar o golden path pela UI (a validação desta sessão foi via chamadas diretas à API/RPC, não clicando na tela).

## 2026-07-21 (1)

### Adicionado

- Criada e implementada `SPEC-038_Impostos_Numeracao_Vinculo_Parcelas_Desconto_Compras.md` (fluxo planner → implementador → revisor → orquestrador) no sistema `compras-lucenera-3o23t98ee` (Necessidade de Compra / Cotações): custo separado em líquido+ICMS+IPI+ST (editável, pré-preenchido do cadastro do produto); numeração automática de pedido (`PC-<ano>-NNNN`); vínculo informativo (opcional, nunca bloqueante) entre item de pedido e item de projeto de origem; parcelas reais do pedido de compra ao fornecedor, geradas automaticamente e com valor/vencimento editáveis manualmente por parcela (decisão explícita do usuário); campo "% desconto" em Cotações isolado do desconto que já afeta o preço de venda ao cliente.
- Revisão (`revisor`) encontrou 2 avisos técnicos antes do commit — ambos corrigidos: `criar_pedido_compra_de_necessidade` teria virado uma sobrecarga órfã no Postgres (assinatura mudou de 8 para 12 parâmetros, `CREATE OR REPLACE` não substitui function com número de parâmetros diferente — corrigido com `DROP FUNCTION` explícito da assinatura antiga); tabela nova `pedido_compra_item_origem` tinha policy de INSERT aberta em vez de escrita só via RPC (padrão do resto do domínio) — corrigido com nova RPC `vincular_origem_pedido_compra_item`.

### Corrigido — achado crítico: "Registrar Compra" estava quebrado em produção desde 10/07

- Antes de aplicar as migrations da SPEC-038, uma checagem direta no Supabase real (não em `supabase/db/current/`, que documentava errado) revelou que a tabela `pedidos_compra` — usada pelas RPCs `criar_pedido_compra_de_necessidade`/`criar_pedido_compra_lote` desde a SPEC-021 (10/07) — **nunca existiu de verdade**. A migration que deveria criá-la (`20260710_031_spec020_operacionalizacao_compras/004_pedidos_compra.sql`) nunca tinha sido aplicada, só as vizinhas do mesmo lote. Como PL/pgSQL não valida tabelas referenciadas na criação da function, só na execução, as RPCs existiam e pareciam normais, mas todo INSERT real falhava. A funcionalidade de "Registrar Compra" (individual e em lote) esteve quebrada em produção por ~11 dias sem detecção — inclusive a SPEC-035 (análise de lacunas, 18/07) repetiu o engano de assumir "backend pronto" sem checar o banco real.
- Aplicada a migration retroativa `004_pedidos_compra.sql` (cria a tabela + FK que faltava em `pedido_compra_itens.pedido_id`), e corrigidas 2 colunas legadas com `NOT NULL` indevido em `solicitacoes_compra` (`projeto_id`, `quantidade_pedida`) que também bloqueavam as RPCs. As 2 RPCs de registrar pedido de compra foram testadas de ponta a ponta via chamada HTTP real (não simulação) e funcionaram — provavelmente a primeira vez desde que foram criadas.
- As 5 migrations da SPEC-038 aplicadas e testadas em seguida (numeração automática, geração/edição de parcelas, vínculo de origem, desconto de compra, view estendida) — tudo confirmado funcionando via teste real, dados de teste removidos depois.
- A correção retroativa (aplicação de `004_pedidos_compra.sql` + FK `pedido_compra_itens.pedido_id` + as 2 colunas `NOT NULL` removidas) foi capturada em arquivo de migration próprio, `20260721_055_fix_pedidos_compra_base`, para reprodutibilidade em outros ambientes (as 3 correções já haviam sido aplicadas diretamente no banco antes de existir o arquivo).

### Publicado

- Frontend de `compras-lucenera-3o23t98ee` sincronizado com o Skip (projeto 40326), QA completo (setup/análise estática/build/integrações/testes) e publicado em produção — versão `0.0.44`, `https://pagina-em-branco-cdd79.goskip.app`.
- Commit no submodule `compras-lucenera-3o23t98ee` (`977e36e`) com os 11 arquivos de frontend da SPEC-038 (9 modificados + 2 novos: `PedidosCompra.tsx`, `PedidoParcelasPanel.tsx`).

### Pendente

- Testar o golden path pela UI (não só via RPC direta) dos 5 itens da SPEC-038 — backend e frontend já publicados, falta o usuário clicar no fluxo completo.
- Reextrair `supabase/db/current/` — pendência crônica (SPEC-030/033/034/038), agora ainda mais urgente: a documentação estava desatualizada a ponto de esconder que uma tabela inteira não existia.

## 2026-07-20 (2)

### Corrigido (5)

- **E-mail de notificação confirmado funcionando** (SPEC-037): usuário confirmou que o e-mail do teste caiu na pasta de spam de `vinicius@lucenera.com.br`/`pedro@lucenera.com.br` — ou seja, o envio via Gmail SMTP está funcionando; falta só os destinatários marcarem "Não é spam" para melhorar a reputação do remetente.
- Bug achado pelo usuário: botão "Baixar PDF" (na tela de orçamento salvo) sempre falhava com "Erro ao gerar o documento" — `savedQuote` nunca incluía a lista de itens (`QuoteData.items` ficava `undefined`), e `generateQuoteHTML` precisa desse array. Corrigido anexando o `items` do carrinho (capturado antes do `clearCart()`) ao `savedQuote`. Mesma causa também afetava "Enviar por E-mail".

### Adicionado (2)

- Cadastro de cliente (`CustomersPage.tsx`) passou a aceitar **CPF ou CNPJ**, não só CNPJ — pedido do usuário, revisando a decisão da SPEC-036 ("sempre CNPJ, nunca CPF"). Novo helper `formatCPFOuCNPJ`/`isValidCPFOuCNPJ` em `src/lib/utils.ts` detecta automaticamente qual dos dois pelo número de dígitos digitados. `AI_DB_CONTEXT.md` atualizado.

## 2026-07-20 (1)

### Adicionado

- Criada `SPEC-037_Ubiqua_Backorder_Sem_Estoque_e_Necessidade_Importacao.md`: toda a marca Ubiqua é importada pela empresa do usuário, então "sem estoque" e "aguardando importação" são o mesmo conceito. Implementado: texto "Não tem aquela peça em estoque" trocado por "Sem estoque" em `PartCard.tsx`/`QuantityModal.tsx`/`NewQuote.tsx`; botão "Adicionar ao Orçamento" deixou de ser bloqueado por falta de estoque (`PartCard.tsx`, combobox de busca e controles de quantidade em `NewQuote.tsx`, guard silencioso removido de `use-cart.tsx`); `QuantityModal.tsx` ganhou aviso de backorder com card visual (logo `og-image.png`) e checkbox de ciência do prazo de até 3 meses, com teto técnico de quantidade de 999 quando sem estoque.
- Migration `supabase/db/migrations/20260719_053_ubiqua_necessidade_importacao/` (rascunhada, **não aplicada** no Supabase real): coluna `itens_orcamento_ubiqua.sem_estoque_no_pedido` (snapshot no momento do pedido) + view `vw_necessidade_importacao_ubiqua` (demanda agregada por produto, decisão tomada após comparar 3 alternativas de modelagem — ver SPEC-037). `NewQuote.tsx` já grava a coluna e preenche `orcamentos_revenda_ubiqua.prazo_entrega` com aviso de importação quando o orçamento tem item de backorder.
- `AI_DB_CONTEXT.md` do sistema Ubiqua atualizado com a nova coluna, view e a seção "Necessidade de importação".

### Corrigido

- Bug crítico bloqueando testes: `CustomersPage.tsx` usava `formatCNPJ`/`isValidCNPJ` sem importar de `@/lib/utils` (diferente de `ProfilePage.tsx`/`Onboarding.tsx`, que importam certo) — o campo de CNPJ do cadastro de cliente não aceitava digitação (o `onChange` lançava `ReferenceError` antes de atualizar o estado).
- Sincronização com Skip: corrigido bug de imagem sumindo na página de detalhe do produto — a causa real não era o `onLoad`/cache de imagem (hipótese original), e sim o plugin legado `@tailwindcss/aspect-ratio` em `tailwind.config.ts` desabilitando a utility nativa `aspect-square` do Tailwind v3, colapsando o container da imagem para ~2px de altura. Removido o plugin (não usado por nenhum componente).

### Corrigido (2)

- Bug crítico bloqueando qualquer salvamento de orçamento novo, achado no primeiro teste real do usuário: `itens_orcamento_ubiqua.valor_total` é coluna `GENERATED ALWAYS` (calculada como `quantidade * valor_unitario - desconto_item`) no schema real, mas `NewQuote.tsx` tentava inserir um valor nela explicitamente — Postgres rejeitava com `cannot insert a non-DEFAULT value into column "valor_total"`. Bug pré-existente, não introduzido pela SPEC-037. Corrigido removendo o campo do insert.
- Migration `20260719_053_ubiqua_necessidade_importacao` **aplicada no Supabase real** (coluna `sem_estoque_no_pedido` e view `vw_necessidade_importacao_ubiqua`, verificadas via `information_schema`), com confirmação explícita do usuário, pelo orquestrador.
- Teste ponta a ponta em produção após os dois fixes: orçamento **ORC-2026-000012** salvo com sucesso, usando cliente real já cadastrado. Esse salvamento também dispara `process-budget-pdf` — pendente o usuário confirmar se o e-mail chegou em `vinicius@lucenera.com.br`/`pedro@lucenera.com.br`.

### Corrigido (3)

- **Causa raiz de "e-mail não chega" identificada**: usuário confirmou que nenhum e-mail chegou no teste do ORC-2026-000012. Verificado via `supabase secrets list --project-ref vcvcwzmbiftcawncibke`: a secret `RESEND_API_KEY` **não existe** no projeto Supabase real — nem para `process-budget-pdf`, `welcome-email` ou `enviar-confirmacao-email`. Não é bug de código, é configuração ausente; usuário precisa cadastrar a chave da própria conta Resend (o assistente não manuseia essa credencial).
- Corrigido bug adjacente: `process-budget-pdf` escondia falha de envio (`console.error`/`console.warn` sem `throw`, sempre retornava `success:true`). Agora propaga erro real. Deployado no Supabase real (`supabase functions deploy`, confirmado pelo usuário) — corrigido nas duas cópias (submodule e repo central).
- **Achado**: `supabase functions deploy` rodado da raiz do repo central publicou a partir de `supabase/functions/` do repo central — resolve a dúvida em aberto da SPEC-037 sobre qual cópia (submodule vs. central) é a fonte real de deploy das Edge Functions.

### Corrigido (4)

- Trocado o provedor de e-mail de `process-budget-pdf` de Resend para Gmail SMTP: usuário não tem acesso ao DNS de `lucenera.com.br`, então não dá pra verificar domínio customizado no Resend (obrigatório para entregar fora da própria conta). Agora usa `nodemailer` autenticado via senha de app do Google, remetente `erp.lucenera@gmail.com`. Secrets: `GMAIL_USER` (configurado) e `GMAIL_APP_PASSWORD` (pendente do usuário).
- **Incidente de segurança**: durante a sessão, o usuário colou em texto puro uma API key do Resend e a senha da conta Gmail `erp.lucenera@gmail.com`. O assistente recusou usar as duas (regra fixa: nunca inserir senha/API key/token em nenhum sistema, mesmo com autorização explícita do usuário) e orientou a revogar/trocar ambas.

### Pendente

- Usuário gerar senha de app do Google (myaccount.google.com/apppasswords) e configurar `GMAIL_APP_PASSWORD` nas secrets do Supabase (`supabase secrets set GMAIL_APP_PASSWORD=... --project-ref vcvcwzmbiftcawncibke`) — depois disso, o disparo de e-mail em todo pedido deve funcionar sem nenhum código novo.
- Confirmar que o usuário revogou a API key do Resend exposta e trocou a senha da conta Gmail.
- Reextrair `supabase/db/current/` para refletir a migration `20260719_053` já aplicada.
- Decidir endereços do fluxo `approvePurchase` (admin) — manter `vinicius@ubiqua.com`/`josi@ubiqua.com` ou trocar para os novos `@lucenera.com.br`.
- Teto de negócio real de quantidade em pedido sob encomenda — decisão do usuário com o gerente, teto técnico provisório de 999 em uso.
- Commit e push do submodule + ponteiro no repo central.

## 2026-07-18 (6)

### Adicionado

- Registrado o sistema "Catálogo de Peças Ubiqua" (`04-Sistemas/catalogo-pecas-ubiqua-e6fa0`, `pedrolalala/cat-logo-pe-as-ubiqua-`) como submodule central. Achado arquitetural: usa o mesmo projeto Supabase central (`vcvcwzmbiftcawncibke`), não um projeto separado.
- Criada e implementada `SPEC-036_Catalogo_Ubiqua_Marca_Isolamento_Clientes_e_Cores.md` (planner → implementador → revisor), a partir da análise da reunião com o Vinicius (representante/sócio Ubiqua). Entregue: subtítulo de marca "Ubiqua Representações" no header/footer; menus renomeados para deixar explícito "Cadastro de Cliente"/"Cadastro de Representante"; isolamento de clientes por representante individual — nova coluna `informacoes_cliente_ubiqua.cadastrado_por_usuario_id` + RLS restrita ao dono ou a `nivel_acesso IN ('admin','interno')`, substituindo policies antigas totalmente abertas (`USING (true)` para anon/authenticated); `AI_DB_CONTEXT.md` novo documentando o domínio Ubiqua.
- **Efeito colateral corrigido de brinde**: não existia nenhuma policy de DELETE em `informacoes_cliente_ubiqua` — exclusão de cliente nunca funcionava. Corrigido pela mesma migration.
- Migration `supabase/db/migrations/20260718_052_spec036_ubiqua_isolamento_clientes/` aplicada no Supabase real e verificada (coluna, 5 policies, índice, os 4 clientes pré-existentes ficaram com `cadastrado_por_usuario_id = NULL`, sem atribuição automática).

### Corrigido

- Achado crítico separado durante o teste do fluxo: o app Ubiqua não tinha **nenhuma forma de um representante novo criar conta** — `AuthWrapper.tsx` só implementava login; a função `signUp()` já existia no hook `use-auth.tsx` mas nunca era chamada por nenhum componente. Corrigido: alternador Entrar/Criar Conta no mesmo formulário, com validação de confirmação de senha. Ajuste adicional: `signUp()` passou a retornar `hasSession`, para mostrar a mensagem certa ao usuário conforme o projeto Supabase exigir ou não confirmação de e-mail.

### Investigado, não corrigido (decisão consciente)

- Hipótese original da SPEC de que o agrupamento de variantes de cor (`groupCatalogItems()` em `use-parts.ts`) tinha um bug de chave de agrupamento não se confirmou por auditoria direta dos dados reais: só 1 produto ("CRYSTAL") tem cores com preços diferentes, e mesmo esse caso vem de descrições/preços conflitantes entre 3 planilhas de origem diferentes (`fonte_planilha1/2/3`) — não é um bug de código, é dado duplicado/conflitante entre fontes. `use-parts.ts` não foi alterado; fica pendente decisão de qual planilha é autoritativa.
- Cadastro de cliente PJ completo (campos além de nome/email/telefone/CNPJ) segue bloqueado até o Vinicius enviar a lista/print combinada na reunião.

### Pendente

- Vinicius enviar campos completos do cadastro de cliente PJ.
- Decidir fonte de planilha autoritativa em `revenda_ubiqua` antes de revisitar o agrupamento por cor.
- Homologação manual do golden path completo (criar conta → onboarding → catálogo → cadastro de cliente → orçamento) em dispositivo real — não testável por leitura de código.
- Commit e push do submodule + ponteiro no repo central.

## 2026-07-18 (5)

### Adicionado

- Criada e implementada `SPEC-034_Sugestao_Automatica_Fornecedor_por_Marca.md` (fluxo planner → implementador → revisor). Análise real no Supabase mostrou que 63 das 109 marcas sem fornecedor tinham candidato de nome quase idêntico via `word_similarity()`. Entregue: correção da RPC `buscar_fornecedores_fuzzy` (usava `similarity()`, que não achava termo curto em nome de fornecedor longo — pendência aberta desde a SPEC-030), nova RPC `sugerir_fornecedores_marcas()`, e tela "Marcas" ganhou badge de sugestão + confirmação individual ou em lote (sempre com revisão explícita, nunca aplicação automática). Migrations aplicadas no Supabase real, revisado sem achado crítico, commitado (`51123f8`) e publicado em produção via Skip (`0.0.43`).
- **61 das 63 marcas de alta confiança foram vinculadas ao fornecedor** nesta sessão, a pedido do usuário. 2 casos foram sinalizados como possível falso positivo (encontrados só ao revisar a lista completa, fora da amostra que embasou a SPEC) e excluídos após confirmação do usuário: "LIGHT LIGHT"→"OMEGA LIGHT" (match por palavra genérica "LIGHT") e "OUTROS"→"OUTROS" (parecem registros placeholder dos dois lados). Total de marcas com fornecedor vinculado: 62 de 109.

## 2026-07-18 (4)

### Corrigido

- SPEC-033 (`compras-lucenera-3o23t98ee`): Pedro reportou que, mesmo após usar a tela nova "Marcas" para vincular fornecedor, os checkboxes de "Necessidade de Compra" continuavam desabilitados. Diagnóstico confirmado por teste direto no Supabase real: `UPDATE marcas SET fornecedor_id = ...` via SQL puro funciona e a view reflete corretamente — o bug estava só no frontend. Causa raiz: `atualizarFornecedorMarca()` chamava `.update().eq('id', ...)` **sem `.select()`**; quando a policy RLS bloqueia a escrita (0 linhas afetadas), o Postgrest não gera erro nenhum (`Prefer: return=minimal`), então a função assumia sucesso e mostrava toast de confirmação mesmo sem nada persistir. Corrigido encadeando `.select('id').single()` e tratando ausência de dado retornado como falha explícita. Revisado sem achado crítico, commitado (`255d30b`), pushado e republicado em produção via Skip (`0.0.42`).
- Registrada suspeita não confirmada para acompanhamento caso o erro persista após a correção: sessão JWT expirada/anônima no frontend, ou mismatch entre `auth.uid()` e `usuarios.id` para o usuário real logado — ambas as causas ficariam agora visíveis via toast de erro explícito, em vez de falso sucesso.

## 2026-07-18 (3)

### Adicionado

- Criada e implementada `SPEC-033_Fornecedor_por_Marca_e_Melhorias_Necessidade_Compra.md` (fluxo completo planner → implementador → revisor). Diagnóstico: o Pedido em Lote (SPEC-030 Parte 2) estava 100% travado — 0 de 233 produtos com necessidade de compra tinham `fornecedor_id` resolvido, porque `marcas.fornecedor_id` nunca foi preenchido para nenhuma das 110 marcas (não existia tela para isso). Entregue nesta sessão: tela nova "Marcas" (`/marcas`) em `compras-lucenera-3o23t98ee` para mapear marca → fornecedor pela UI (sem SQL manual); coluna "Disponível" em "Necessidade de Compra" (saldo real, pode ser negativo — campo já existia na view, só não era exibido); contexto de estoque (física/comprometida/disponível) dentro do modal "Pedido em Lote". Nenhuma migration nova. Revisado sem achado crítico, commitado (`1ebbace`), pushado e publicado em produção via Skip MCP (`pagina-em-branco-cdd79.goskip.app`, versão `0.0.41`).
- **Pendente**: o backfill em si (mapear cada uma das ~110 marcas ao fornecedor correspondente) continua sendo trabalho manual de Pedro/Filippo pela nova tela — sem isso, o Pedido em Lote continua sem itens selecionáveis.

## 2026-07-18 (2)

### Adicionado

- Criada e implementada `SPEC-032_Header_Unico_Itens_Orcamento.md`: na tela de edição de orçamento, o cabeçalho de colunas dos itens (`Luminária, Código Produto, Código de Referência, Produto, Qtd, Preço Unit., Desc %, Subtotal`) deixa de se repetir a cada item — passa a aparecer uma única vez, no topo da lista, em telas largas (mobile inalterado, a pedido do usuário). Componente novo `BudgetItemsHeader.tsx`; `BudgetItemCard.tsx` esconde os rótulos por campo via `lg:hidden`. Commitado/pushado (`2e139e8`) e publicado em produção via Skip MCP (versão `0.0.295`).
- Achado durante a publicação: `BudgetFormPage.tsx` no Skip tem um campo (`prazo_entrega_dias`, schema + UI completos) que não existe em nenhum commit do GitHub — usado `skip_file_patch` (busca/substituição cirúrgica) em vez de sobrescrever o arquivo inteiro, para não perder essa funcionalidade só-Skip. Registrado como pendência de investigação na SPEC-032.

## 2026-07-18

### Adicionado

- Criada e implementada `SPEC-031_Etapa_Aprovacao_Equipe_Orcamentos.md`: novo status `Aprovação da Equipe` no fluxo de orçamentos (`enviado_cliente -> Aprovação da Equipe -> Aprovação Financeira -> Orçamento Aprovado`), permitindo que a equipe confirme ou devolva ao cliente (com motivo obrigatório, trocando peça/cor) depois da visita à obra. Migration aplicada no Supabase real (`supabase/db/migrations/20260718_050_spec031_aprovacao_equipe_orcamentos/`): altera as 5 funções de aprovação do cliente para parar em `Aprovação da Equipe`, cria as RPCs `equipe_aprovar_orcamento`/`equipe_devolver_orcamento_cliente`, e cadastra o módulo `aprovacao_equipe` no Hub (SPEC-006, reaproveitando a ação `editar` já existente). Frontend implementado em `gestao-financeira-clone-544cb (1)` (`TeamApprovalTab.tsx` novo, `budget-status.ts`, `Budgets.tsx`, `BudgetFormPage.tsx`, `useBudgetStore.ts`), commitado/pushado (`066f2f3`, após reconciliar com 2 commits que já estavam em `origin/main`) e **publicado em produção via Skip MCP** (`https://gestao-financeira-clone-544cb.goskip.app`, versão `0.0.294`). Lint/build limpos, QA do Skip limpo. **Pendente**: conceder a permissão do módulo a algum papel no Hub (só admin/gerente conseguem agir por enquanto), homologar no app publicado.
- Achado durante a publicação: o projeto Skip tinha uma versão (`5492ca4`) sem correspondência em nenhum commit do GitHub, e o arquivo `useBudgetStore.ts` no Skip tinha um campo (`prazo_entrega_dias`) ausente do GitHub — preservado ao escrever a atualização (não sobrescrito às cegas). Risco de divergência Skip x GitHub documentado como pendência aberta na SPEC-031.
- Durante a implementação, confirmado por query direta no Supabase real que os objetos da SPEC-019 (`aprovado_cliente_origem`, `financeiro_editar_orcamento`, `buscar_orcamento_para_aprovacao`, `recusar_orcamento_cliente_publico`, trigger de reset) existem em produção — o snapshot local (`supabase/db/current/`) é que está desatualizado desde 2026-07-07, não a SPEC-019.

## 2026-07-17

### Corrigido

- Aplicadas no Supabase real as 5 migrations de `supabase/db/migrations/20260716_049_spec030_pedido_lote_marca_fornecedor/` (SPEC-030 Parte 2), que estavam apenas em rascunho desde 2026-07-16: coluna `marcas.fornecedor_id`, `vw_necessidade_compra` estendida com `marca_id`/`marca_nome`/`fornecedor_id`/`fornecedor_nome`, RPC `criar_pedido_compra_lote`, índice fuzzy `idx_contatos_nome_unaccent_trgm` e RPC `buscar_fornecedores_fuzzy`. Motivo: Pedro reportou que a marca não aparecia vinculada em Necessidade de Compra (sistema `compras-lucenera-3o23t98ee`), apesar de já aparecer em Estoque de Produtos — o frontend já estava pronto (commit `eb5cc7e`), só faltava a migration no banco.
- Corrigidos 2 bugs no rascunho da migration, encontrados só ao aplicar contra o Postgres real: (1) `004_idx_contatos_nome_unaccent_trgm.sql` usava `unaccent()` direto em expressão de índice, que exige função `IMMUTABLE` (`unaccent()` é `STABLE`) — corrigido com wrapper `public.immutable_unaccent()`; (2) `005_rpc_buscar_fornecedores_fuzzy.sql` tinha `SELECT DISTINCT ... ORDER BY` por expressão fora da lista de SELECT, rejeitado pelo Postgres — corrigido com subquery.
- Confirmado por query direta: `vw_necessidade_compra` agora retorna `marca_nome` preenchido em 230 de 233 linhas (as 3 restantes são produtos sem `marca_id` cadastrado, não um bug).

### Pendente

- Backfill de `marcas.fornecedor_id` (mapeamento marca → fornecedor, decisão de dado de Pedro/Filippo) — sem ele, `fornecedor_id`/`fornecedor_nome` continuam nulos e o Pedido em Lote não tem itens selecionáveis, embora a marca já apareça.
- Busca fuzzy de fornecedor (`buscar_fornecedores_fuzzy`) roda sem erro mas retorna 0 resultados em buscas curtas contra nomes de fornecedor longos (ex.: "Stella" vs. "STELLA IMPORTACAO E EXPORTACAO DE LUMINARIAS LTDA" tem `similarity() = 0.119`, abaixo do threshold `0.3`) — precisa de ajuste de algoritmo (`word_similarity()` em vez de `similarity()`), não só de threshold. Ver Pendências da SPEC-030 Parte 2.
- Teste manual no navegador e publicação via Skip continuam pendentes do usuário.
- Reextração do snapshot `supabase/db/current/` (desatualizado desde 2026-07-07) continua pendente.

## 2026-07-16

### Corrigido

- `compras-lucenera-3o23t98ee`: commit `55fd80e` (pushado) corrige `getFornecedores()` em `src/services/pedido-compra.ts` para filtrar por `contato_tipos.tipo = 'fornecedor'` (antes retornava contatos de qualquer tipo — arquiteto, cliente — na busca de "Marca/Fornecedor" do Registrar Pedido de Compra). Removida duplicata morta `getFornecedores()`/`FornecedorOption` em `services/compras.ts` e o mock associado. Ponteiro do submodule atualizado no repo central (`6ca80f2`). SPEC-030, Parte 1. Revisado pelo agente `revisor` sem achado crítico/aviso, lint/build limpos. **Publicação via Skip ainda pendente**: o servidor MCP `skip` está registrado mas com status "Needs authentication" — falta concluir OAuth para liberar as ferramentas `mcp__skip__*` de publish.

### Atualizado

- `03-Projeto/Planos de Ação/SPECs/SPEC-030_Fix_Filtro_Tipo_Fornecedor_Compras.md` expandida com uma Parte 2 (planejamento, não implementado): consolidar a Necessidade de Compra por fornecedor, fluxo de "Pedido em Lote" (1 pedido = 1 fornecedor, gerado a partir de `produtos.fornecedor_principal_id`) e busca de fornecedor tolerante a erro de digitação/variação de nome via `pg_trgm` + `unaccent` (extensões já habilitadas no banco). Decisões de escopo confirmadas por Pedro; implementação ainda não iniciada.

### Adicionado

- SPEC-030 Parte 2 implementada em código (commit `d1a2a7e`, pushado): filtro por **marca** (não fornecedor direto — marca/fornecedor tratados como equivalentes a pedido de Pedro) na Necessidade de Compra, fluxo de "Pedido em Lote" (`ModalPedidoLote.tsx` + RPC `criar_pedido_compra_lote`, generalização transacional de `criar_pedido_compra_de_necessidade`) e busca de fornecedor tolerante a erro de digitação via nova RPC `buscar_fornecedores_fuzzy` (`pg_trgm` + `unaccent`, threshold `similarity() > 0.3`). Migrations em rascunho (`supabase/db/migrations/20260716_049_spec030_pedido_lote_marca_fornecedor/`), **ainda não aplicadas no Supabase real** — inclui a coluna nova `marcas.fornecedor_id` (nullable, depende de backfill manual de Pedro/Filippo: mapear cada marca ao fornecedor correspondente). Revisado pelo agente `revisor` sem achado crítico/aviso; lint/build limpos. Publicação via Skip segue pendente (mesmo bloqueio de OAuth do MCP `skip` da Parte 1).
- Durante o push do commit `d1a2a7e`, reconciliados via merge vários commits automáticos do bot `Skip <skip@usecurling.com>` já presentes em `origin/main` (bumps de versão `v0.0.30`–`v0.0.32` e sincronizações de build) — evidência de que a plataforma Skip publica direto no GitHub por conta própria, independente da autenticação do MCP usada por agentes desta sessão.

## 2026-07-07

### Adicionado

- Criada `SPEC-019_Origem_Aprovacao_Cliente_e_Reset_Pos_Aprovacao.md`: coluna `orcamentos.aprovado_cliente_origem` (manual/token), reset automático da aprovação ao editar valor/frete/forma de pagamento/prazo/itens de um orçamento já em `Aprovação Financeira`/`Orçamento Aprovado`, RPC `financeiro_editar_orcamento` com opção explícita de não reiniciar (modal na tela de Aprovação Financeira), e criação de `buscar_orcamento_para_aprovacao`/`recusar_orcamento_cliente_publico` — RPCs que o frontend do sistema de Orçamentos (`ClientApproval.tsx`) já chamava mas nunca existiram no banco, causando "Link Inválido" em qualquer link público de aprovação.
- Corrigido no sistema de Orçamentos: modal de criar cliente/projeto direto do formulário de orçamento mostrava sucesso sem persistir nada — o evento de submit borbulhava por portal React até o form pai; adicionado `stopPropagation` em `ClientCreateModal.tsx`/`ProjectCreateModal.tsx`.
- Criado `03-Projeto/07_ANALISE_LACUNAS_IMPLEMENTACAO_2026_07_07.md`, comparando reuniões, mapeamentos, SPECs, snapshot Supabase e código dos sistemas para listar lacunas implementáveis, bloqueios, riscos de segurança, status de build/lint e ordem recomendada de execução.
- Implementadas localmente as migrations centrais `20260708_029_spec006_permissoes_granulares_hub` e `20260708_030_spec007_sso_cross_system`, com permissões granulares no Hub, SSO por `sso_code`, Edge Functions `generate-cross-system-code`/`exchange-cross-system-code` e checagem TDD em `scripts/verify-spec006-007.mjs`.
- Criada a evidência TDD `03-Projeto/Evidencias TDD/SPEC-006-007_TDD_2026_07_07.md` com RED/GREEN e comandos de build/lint executados.
- Adicionado `src/lib/cross-system-auth.ts` nos apps Hub, Orçamentos, Financeiro/Retorno e CRM para `redirectWithCode`/`consumeCodeFromUrl`.
- Aplicada/verificada a SPEC-006 no Supabase remoto e aplicada a SPEC-007 via `SUPABASE_DB_URL` do `.env`; Edge Functions `generate-cross-system-code` e `exchange-cross-system-code` publicadas como `ACTIVE`.

### Atualizado

- Atualizado `03-Projeto/00_INDICE.md` para incluir a análise de lacunas e corrigir status obsoletos das SPECs 008 a 018.
- Atualizadas `SPEC-006`, `SPEC-007`, `00_TASKS_GERAIS_ECOSSISTEMA.md`, `supabase/db/domains/hub_ti.md` e contextos locais dos sistemas afetados para refletir aplicação/publicação remota e pendência real de homologação/adopção.
- Reextraído `supabase/db/current/` após SPEC-006/007, atualizando schema, funções, triggers, views, policies, inventário e manifesto.
- Hub/Central: dashboard agora prefere `hub_sistemas_permitidos` para cards por permissão e abre sistemas com `redirectWithCode`; administração recebeu telas de papéis, exceções e auditoria de permissões.
- Orçamentos, Financeiro/Retorno e CRM: fluxos cross-system passaram a consumir/gerar `sso_code` para evitar login duplicado entre apps, mantendo fallback para link direto.
- Implementada a SPEC-014 no CRM: `getProjeto()` passa a carregar `projeto_itens(*)` e `ProjectDetail.tsx` ganhou o Card "Itens Aprovados do Projeto", somente leitura, com quantidade, preço, desconto, subtotal, origem por orçamento e situação `Cancelado`/`Ativo`. `getProjetos()` permaneceu sem `projeto_itens(*)` para não pesar a listagem. Badges ricos de estoque seguem pendentes da leitura da SPEC-010 com RLS/policy definida.
- Confirmada a SPEC-010 no Supabase real e escrita a migration corretiva `20260707_023_spec010_hardening`: recria views com `security_invoker`, revoga grants de `anon`/`authenticated`, reconcilia `estoque_itens.quantidade_reservada` para os quatro produtos divergentes encontrados e endurece `trigger_fechar_projeto` para não transformar `q_entrega_futura` diretamente em entregue.

## 2026-07-06

### Atualizado

- Escrita a migration central `20260706_022_saldos_estoque_projeto_item` implementando a SPEC-010 (saldos operacionais de estoque por item de projeto): cria `estoque_saldos_projeto_item`/`estoque_movimentos_projeto_item`, atualiza `aprovar_orcamento_financeiro_base_spec001` (alocação `q_reserva`/`q_entrega_futura` item por item, com lock por produto/local), `cancelar_orcamento` (reversão pelo saldo aberto real, não pela quantidade original) e `trigger_fechar_projeto` (move saldo para `q_entregue`), cria as views `vw_estoque_saldos_projeto_item`/`vw_estoque_por_produto_projeto`/`vw_estoque_resumo`, e um backfill conservador para itens aprovados antes da migration. RLS habilitada sem policy nas duas tabelas novas, por decisão de segurança pendente (ver README da migration e pendência crítica 7 do checklist geral). Aplicação no Supabase real confirmada em 07/07/2026; hardening complementar ficou em `20260707_023_spec010_hardening`.
- Aplicadas no Supabase real as migrations centrais `20260706_020_normalizacao_aprovacao_financeira_orcamento` e `20260706_021_criar_produto_orcamento`.
- Normalizada a aprovação financeira de orçamento no banco conforme SPEC-016: contrato oficial `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado`, RPC transacional por `orcamento_id`, wrappers legados protegidos e auditoria por orçamento.
- Criada a RPC `public.criar_produto_orcamento(p_payload jsonb)` para a SPEC-018, gravando diretamente em `public.produtos` com validações cadastrais canônicas, sem catálogo paralelo.
- Atualizadas `SPEC-016`, `SPEC-017` e `SPEC-018` com o estado aplicado no banco.
- Implementadas na UI de Orçamentos, via projeto Skip da org Lucenera, as SPECs `SPEC-017` e `SPEC-018`: aba financeira agora trabalha por orçamento em `Aprovação Financeira`, aprovação final usa `orcamento_id`, e o cadastro de produto pode ser feito direto no fluxo de orçamento.
- Aplicado `skip_project_apply_changes` no projeto Skip `32554` (`Orçamentos Aprovação`) em modo development, gerando a versão `0.0.273` / `dcd3442` com QA verde.
- Refatoradas as SPECs pendentes de Estoque para consolidar o contrato técnico por `projeto_item_id`: `SPEC-010` agora define `estoque_saldos_projeto_item` e `estoque_movimentos_projeto_item`; `SPEC-011` transfere entre itens de projeto; `SPEC-013` foi absorvida; `SPEC-015` passou a usar a regra de devolução dos vídeos Connect.
- Reextraído `supabase/db/current/` a partir do Supabase real, refletindo `razao_social` em contatos e o fluxo parcial de aprovação do cliente em orçamentos.
- Regenerado `supabase/db/current/09_schema_inventory.md`.
- Incorporada a reunião 08 em `02-Reunioes/`, com transcrição, ata, fluxos, decisões/pendências e insights.
- Consolidadas SPECs 010/011/012/013/014 para saldos por item de projeto, entrega futura, transferência de reservas e badges no CRM.
- Criada e depois consolidada `SPEC-015_Devolucao_Estoque_por_Item_de_Projeto.md` para a regra de devolução.
- Criadas `SPEC-016`, `SPEC-017` e `SPEC-018` para normalizar aprovação financeira de orçamentos, unificar o modal/fluxo de edição financeira e permitir criação de produto dentro do modal de orçamento.
- Atualizados `00_TASKS_GERAIS_ECOSSISTEMA.md`, escopos afetados e docs/domínios Supabase.

### Inconsistências registradas

- Aprovação do cliente possuía contratos concorrentes no banco real; a SPEC-016 decidiu e aplicou o contrato oficial `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado` na camada Supabase. A UI de Orçamentos foi atualizada pela SPEC-017 e segue para homologação visual.
- `estoque_saldos_projeto_item` e `estoque_movimentos_projeto_item` já existem no banco real, mas a revisão encontrou exposição das views para `anon`/`authenticated`, divergência de `quantidade_reservada` em quatro produtos e entrega direta de `q_entrega_futura`; aplicar `20260707_023_spec010_hardening` antes de destravar transferência, entrega futura detalhada, devolução automatizada e badges ricos no CRM.
- `supabase/db/current/` ainda precisa ser reextraído depois das migrations 020 e 021; esta etapa ficou pendente para não sobrescrever alterações locais já existentes no snapshot.

## 2026-06-26

### Atualizado

- Baixadas as Edge Functions remotas atuais do projeto Supabase `vcvcwzmbiftcawncibke`.
- Removida a cópia central de `sync-fechamentos-automatica`, ausente no remoto.
- Documentado `process-billing-automation` como legado ainda ativo no remoto e fora do fluxo novo.
- Espelhadas as migrations da SPEC-005 em `supabase/db/migrations/20260626_009_spec005_remocao_triggers_legados_aprovacao/`.
- Atualizados domínios, inventário de automações, mapa de relacionamentos, status/enums e contexto global do Supabase.
- Atualizadas SPECs 001-005 e `00_TASKS_GERAIS_ECOSSISTEMA.md` com o que foi confirmado nos repos e no remoto.
- Puxadas atualizações dos repositórios de sistemas; alterações locais existentes foram preservadas em stash antes do pull.

### Pendente

- Reextrair `supabase/db/current/` após a SPEC-005. A tentativa local falhou sem Docker/`pg_dump`.
- Confirmar remoção definitiva de `process-billing-automation` após checar scheduler/webhook externo.
- Homologar o fluxo de aprovação real com orçamento completo, frete, prazo, histórico, parcelas e boletos.

### Adicionado

- Criada governanca inicial do repositorio central.
- Criado `README.md` com fontes de verdade, estrutura alvo e regras de leitura.
- Criado `AGENTS.md` geral com fluxo obrigatorio para IA/desenvolvedor.
- Criada regra de `.gitignore` para evitar commit de `.env`, `node_modules`, `dist` e temporarios.
- Criados documentos operacionais em `00-Contexto/`.
- Criados `AGENTS.md` por area principal do repositorio central.
- Adicionada instrucao de submodules em `00-Contexto/SUBMODULES.md`.
- Adicionados scripts `scripts/submodules-clone-all.sh` e `scripts/submodules-register.sh`.
- Adicionado `.env.example` e instrucao para criar `.env` local geral para acesso ao Supabase.

### Decisao

- O repositorio central guarda memoria, contexto, banco consolidado, relatorios, specs e inventario.
- Cada sistema continua sendo atualizado tambem em seu repositorio proprio.
- Sistemas com repositorio proprio devem ser registrados como submodules dentro de `04-Sistemas/`.
- O `.env` geral deve existir apenas localmente e nao deve ser commitado.
- O banco consolidado em `supabase/` e a fonte de verdade tecnica; migrations antigas dentro de sistemas sao historico, nao definicao final.
