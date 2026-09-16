---
titulo: "SPEC-124 — Estrutura organizacional real (equipes de projeto + administração) e alinhamento do RBAC"
status: pendente
data_ultima_modificacao: 2026-08-30 (escopo de visibilidade por equipe confirmado; e-mails das contas novas recebidos, aguardando identificação de 6 deles)
sistemas_envolvidos:
  - Banco compartilhado (`equipes_projetos`, `funcionarios`, `usuarios`, `usuario_papeis`, `papeis`, `papel_permissoes`)
  - CRM (lucenera-crm-3bd29) — Projetos.tsx usa `projeto.equipe_id`
  - Todos os 10-11 sistemas — RBAC (SPEC-069) e SystemSwitcher (SPEC-120) leem `usuario_papeis`/`papeis`
dependencias:
  - SPEC-069 (RBAC — papéis/usuario_papeis/papel_permissoes/hub_pode_executar)
  - Auditoria de segurança 2026-08-30 (achado: papéis legados "admin"/"gerente" coexistindo com papéis novos dão acesso total por padrão, tornando o RBAC granular irrelevante pra quem os carrega)
---

# SPEC-124 — Estrutura organizacional real e alinhamento do RBAC

> `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Esta é uma SPEC de **estruturação/planejamento** — nada foi implementado. O objetivo é documentar o organograma real que o usuário passou, confrontar com o que já existe no banco, e levantar as decisões necessárias antes de qualquer mudança de RBAC ou de dado.

## Origem

Pedido direto do usuário, na sequência da auditoria de segurança e do levantamento de RBAC desta sessão: estruturar o organograma real da empresa (equipes de projeto + administração) como base para revisar o RBAC.

## Organograma conforme informado pelo usuário

```
Filippo (Dono)
│
├── Vinicius — Gerente da Administração
│     ├── Lana — Administração (cuida do RH)
│     ├── Caroline — Administração
│     ├── Debora — Administração, Compras
│     └── Estoque — Vitoria, Matheus (Líder de Logística), Alexandre (confirmado 2026-08-30, não fazia parte do organograma inicial)
│
└── Mariane — Gerente de Projetos
      ├── Equipe Thairine — Adriana Jabur, Giovana Gonella, Rafaela Netto
      ├── Equipe Marina — Giovanna Nori, Isabela Jacob, Ketlyn Verônica
      └── Equipe Thais Gomes — Helena Fogaça, Murillo Simpolo, Tricia Borges
```

## Confronto com o que já existe no banco (investigado nesta SPEC, não é suposição)

### O que já existe e bate com o organograma

- **`equipes_projetos`** já tem exatamente 3 linhas: `Thairine`, `Marina`, `Thais` — e já é usada de verdade: `projetos.equipe_id` aponta pra essas 3 equipes em **1.637 projetos** (Thairine: 749, Marina: 763, Thais: 125). O conceito de "3 equipes de projeto" já é a espinha dorsal de como o CRM organiza projeto hoje, mesmo sem o resto da estrutura (líder, membros) existir.
- **Caroline** tem o papel `administracao_comercial` — bate com "Administração".
- **Debora** tem o papel `compras_e_entregas` — bate com "Administração, Compras".
- **Lana** tem o papel `rh_administracao` — bate com "cuida do RH".
- **Mariane** tem o papel `equipe_projetos` — bate parcialmente (dá acesso de edição a CRM/Orçamentos/Separação/Entregas, mas não expressa "ela é a gerente que coordena as 3 equipes").
- **Vinicius** tem `admin_geral` — coerente com "Gerente da Administração" tendo visão ampla.
- **Filippo** tem `admin_geral` — coerente com "Dono".

### Gaps encontrados (fatos, confirmados no banco)

1. **`equipes_projetos` não tem conceito de líder nem de membro** — é só `id`/`equipes` (nome)/`created_at`. Não existe nenhuma coluna ou tabela ligando Thairine/Marina/Thais Gomes como "líder" da equipe que leva o próprio nome, nem ligando os 9 auxiliares a uma equipe. O vínculo hoje é só pelo primeiro nome da equipe coincidir com o nome da coordenadora — funciona por convenção, não por estrutura de dado.
2. **8 dos 9 auxiliares de projeto foram encontrados em `funcionarios`, todos como "Assistente Projetista", todos no mesmo `departamento_id`, e nenhum tem `usuario_id`** (login) — Giovana Bruna Gonella, Adriana Mendonça Jabur, Helena Nascimento Fogaça, Trícia Helena Borges da Silva, Isabella Miguel Jacob, Giovanna Nori, Ketlyn Verônica de Souza, Murillo Veloso Spimpolo. **Nenhum deles consegue logar em sistema nenhum hoje.**
3. **"Rafaela Netto" não foi encontrada** em `funcionarios` com esse sobrenome exato — pode ser grafia diferente do cadastro real (confirmar) ou ela ainda não estar cadastrada.
4. **Thairine e Marina — apesar de coordenarem juntas 1.512 dos 1.637 projetos — só têm o papel `viewer`** (`usuario_papeis` + legado `usuarios.role = 'viewer'`). Isso não bate com o organograma: uma coordenadora de equipe com só permissão de leitura não deveria conseguir editar os próprios projetos que coordena, o que é claramente necessário na prática (e provavelmente está acontecendo hoje só porque `viewer` legado também tem "acesso total por padrão" em Orçamentos/Consultar Produtos/Separação/Entregas — ver achado 6).
5. **Thais Gomes não tem `usuario_id`/login nenhum** — apesar de coordenar 125 projetos e aparecer no organograma como coordenadora igual a Thairine e Marina.
6. **Papel legado "acesso total por padrão" continua ativo em cima dos papéis novos** (achado já reportado na auditoria de segurança): Filippo, Vinicius, Lana e kimberly carregam `admin` legado; Marina e Thairine carregam `viewer` legado. Como o acesso final é a união de tudo, isso significa que hoje **o organograma real não determina o acesso real** — o papel legado por baixo já libera (ou já restringe, no caso de Marina/Thairine) mais do que o papel novo diria.
7. **Não existe, em lugar nenhum do RBAC, o conceito "Gerente de Projetos vê/edita as 3 equipes"** nem "Gerente da Administração vê/edita RH+Compras+Comercial". O RBAC atual (SPEC-069) é só por função (`equipe_projetos`, `compras_e_entregas`, `rh_administracao`...), não por hierarquia — não há um papel "gerente_projetos" distinto de "equipe_projetos", nem um "gerente_administracao" distinto de `admin_geral`.

## Decisões já confirmadas pelo usuário

- ✅ **Escopo de visibilidade por equipe = SÓ a própria equipe.** Cada coordenadora e seus auxiliares devem ver/editar só os projetos da equipe deles, não o CRM inteiro. **Isso não é uma mudança pequena de RBAC** — hoje nada em `projetos`/tabelas relacionadas restringe por `equipe_id`, e o RLS atual (`spec069_*`) é por sistema/módulo/ação, não por "linha pertence à minha equipe". Implementar isso exige uma **SPEC técnica própria** (RLS por `equipe_id`, e decidir o que acontece com projetos sem equipe atribuída, com múltiplas equipes envolvidas, etc.) — não sai como parte desta SPEC de estruturação. Fica registrado aqui como requisito confirmado para a próxima etapa.
- ✅ **Login para os auxiliares de equipe**: confirmado implicitamente — o usuário forneceu e-mail `@lucenera.com.br` para todos os 9 auxiliares (exceto Rafaela Netto, cujo e-mail não veio — ver pendência). Contas devem ser criadas para todos.

## Contas — o que já existe vs. o que falta criar (levantado em 2026-08-30)

Lista de e-mails recebida do usuário, cruzada com `usuarios` real:

| E-mail | Já tem conta? | Pessoa / função esperada |
|---|---|---|
| pedro@lucenera.com.br | ✅ Sim (`admin`) | Pedro |
| mariane@lucenera.com.br | ✅ Sim (`gerente` legado + `equipe_projetos`) | Mariane — Gerente de Projetos |
| vinicius@lucenera.com.br | ✅ Sim (`admin`) | Vinicius — Gerente da Administração |
| filippo@lucenera.com.br | ✅ Sim (`admin`) | Filippo — Dono |
| thairine@lucenera.com.br | ✅ Sim (só `viewer` — **papel errado hoje**) | Thairine — coordenadora de equipe |
| marina@lucenera.com.br | ✅ Sim (só `viewer` — **papel errado hoje**) | Marina — coordenadora de equipe |
| thais@lucenera.com.br | ❌ Não existe | Thais Gomes — coordenadora de equipe (hoje sem login nenhum) |
| adriana@lucenera.com.br | ❌ Não existe | Adriana Jabur — equipe Thairine |
| giovana@lucenera.com.br | ❌ Não existe | Giovana Gonella — equipe Thairine |
| giovanna.nori@lucenera.com.br | ❌ Não existe | Giovanna Nori — equipe Marina |
| isabella@lucenera.com.br | ❌ Não existe | Isabela Jacob — equipe Marina |
| ketlyn@lucenera.com.br | ❌ Não existe | Ketlyn Verônica — equipe Marina |
| helena@lucenera.com.br | ❌ Não existe | Helena Fogaça — equipe Thais Gomes |
| murillo@lucenera.com.br | ❌ Não existe | Murillo Simpolo — equipe Thais Gomes |
| tricia@lucenera.com.br | ❌ Não existe | Tricia Borges — equipe Thais Gomes |
| *(sem e-mail informado)* | ❌ Não existe | **Rafaela Netto** — equipe Thairine — pendência: confirmar e-mail e grafia do sobrenome (não achada em `funcionarios` com "Netto" exato) |
| vitoria@lucenera.com.br | ❌ Não existe | Vitoria Lidia da Silva — **Estoque** (confirmado pelo usuário; cargo cadastrado é "Assistente Administrativo", mas a função real informada é Estoque) |
| matheus@lucenera.com.br | ❌ Não existe | Matheus Fernando Luzente — **Estoque/Logística** ("Líder de Logística" no cadastro; mesmo departamento de Alexandre) |
| alexandrecosta490@gmail.com | ❌ Não existe | Alexandre Guilherme da Costa — **Estoque** ("Auxiliar de Estoque" no cadastro; confirma o e-mail pessoal — não é `@lucenera.com.br`, mas é a mesma pessoa) |
| teste@lucenera.com.br | — | **Excluído.** Confirmado pelo usuário: não deve ser criado. |
| moara@lucenera.com.br | — | **Excluído.** Confirmado pelo usuário: saiu da empresa. |
| Terezinha@lucenera.com.br | — | **Excluído.** Confirmado pelo usuário: saiu da empresa. |

**Quem cria as contas**: não é possível eu criar login novo (bloqueado nas regras de segurança desta sessão, e é literalmente a função `criar_usuario` que a auditoria de segurança encontrou como vulnerável). A criação das ~14-15 contas novas precisa ser feita pelo usuário/administrador via a tela de gestão de usuários do Hub (Central Lucenera → Administração). Depois de cada conta existir, atribuir o papel correto (`usuario_papeis`) pode ser feito nesta sessão.

## Realizado

### 2026-08-30

- **Papel `estoque` criado** (`papeis`, id `28128d1c-502f-4a1b-92df-ad9b7067f149`) — escopo confirmado pelo usuário: **Consultar Produtos** (visualizar) + **Sistema de Entregas** (criar/editar/visualizar), mais Central de Solicitações (criar/visualizar, regra aplicada a todo papel desde a SPEC-121). Destinado a Vitoria, Matheus e Alexandre — contas ainda não criadas (ver pendência de criação de conta abaixo), atribuição do papel a eles fica pra quando as contas existirem.
- **Marina e Thairine corrigidas**: ambas ganharam o papel `equipe_projetos` (o mesmo que a Mariane tem) via `usuario_papeis` — antes só tinham `viewer`, incompatível com coordenar 1.512 dos 1.637 projetos do CRM. **Não mexi no papel legado `viewer` de nenhuma das duas** — isso seguindo em aberto na decisão sobre papéis legados abaixo; por ora elas ficam com `viewer` (legado) + `equipe_projetos` (novo) ao mesmo tempo, união dos dois.
- **E-mail de Rafaela Netto confirmado**: `rafaela@lucenera.com.br` — conta ainda não existe, precisa ser criada pelo usuário como as demais.
- **`equipe_projetos` corrigido com 2 permissões que faltavam**, confirmadas pelo usuário como regra real da operação:
  - `criar` em Orçamentos — usuário confirmou "todos os projetistas podem criar orçamento" (o papel só tinha editar/visualizar antes).
  - `editar` no módulo `aprovacao_equipe` de Orçamentos — usuário confirmou "todos projetistas podem aprovar orçamentos até o ponto da aprovação da equipe". **Verificado no código da RPC antes de aplicar**: `equipe_aprovar_orcamento` checa especificamente `hub_pode_executar(uid, 'orcamentos', 'aprovacao_equipe', 'editar')` — módulo e ação diferentes da aprovação financeira (`aprovar_orcamento_financeiro` checa `hub_pode_executar(uid, 'orcamentos', NULL, 'aprovar')`, sistema inteiro). São checagens tecnicamente independentes — confirmado que essa mudança **não** destrava aprovação financeira pra equipe de projetos.
- **Papel de Mariane resolvido**: usuário confirmou que ela **não tem nenhuma ação a mais** que a equipe de projetos — "só gerenciar as 3 equipes". Ou seja: **não precisa de papel novo** (`gerente_projetos` descartado) — ela continua com `equipe_projetos`, igual a todo mundo, tecnicamente. A única diferença dela é de **escopo de dado** (ver quando "Papel de Mariane...") — quando a visibilidade por equipe for implementada (decisão já confirmada, mas ainda sem SPEC técnica própria), ela precisa enxergar as **3 equipes juntas**, não só uma. Isso fica registrado como requisito para aquela SPEC futura, não como uma diferença de RBAC hoje.
- **Escopo de `equipe_projetos` no CRM confirmado**: usuário confirmou que projetistas podem criar/editar projetos, clientes, arquitetos, engenheiros e fornecedores — **já coberto** pelo que o papel já tinha (`criar`+`editar`+`visualizar` no CRM inteiro, sem distinção de tela — confirmado que o CRM não tem nenhum `modulo` cadastrado hoje, é tudo "sistema inteiro"). Nenhuma mudança de banco necessária aqui.
- **Novo requisito confirmado, NÃO implementado**: a tela inicial/Dashboard **de dentro do próprio CRM** (`Index.tsx`, números agregados de todos os projetos/todas as equipes) não deve ser visível pra `equipe_projetos`. Isso é diferente do sistema separado "Dashboard Financeiro" (que eles já não acessam). Como o CRM não tem nenhum `modulo` cadastrado, hoje **não existe like nenhuma forma de restringir isso via RBAC** — precisa de: (1) criar um `modulo` novo (`dashboard`) no `system_id` do CRM, (2) uma permissão específica pra esse módulo, e (3) alterar o código do CRM (`Index.tsx`/rota `/` e `/dashboard`) pra checar essa permissão antes de renderizar, redirecionando quem não tem pra outra tela (ex.: `/projetos`). **Isso é implementação de código, não só ajuste de papel no banco — fica registrado aqui como requisito, não foi feito.**

- **Papel de Vinicius resolvido**: usuário confirmou que ele deve ver/fazer tudo igual a Pedro e Filippo. **Verificado no banco — já é exatamente assim hoje**: calculei a união de sistemas de cada um via `usuario_papeis`/`papel_permissoes` e os três batem 100% (12 sistemas idênticos: Administração Bancária, Central de Solicitações, Consultar Produtos, CRM, Dashboard Financeiro, Fichas Técnicas, Hub, Necessidade de Compra, Orçamentos, RH, Separação Parcial, Sistema de Entregas). Como os três dependem do mesmo papel `admin` (que já concede "qualquer ação" por sistema), as ações também são idênticas. **Nenhuma mudança de banco necessária.**
- **Papéis legados de Marina e Thairine removidos**: cada uma tinha o papel migrado `viewer` (em `usuario_papeis`) **junto** com o `equipe_projetos` novo — removido o `viewer` de ambas, ficando só com `equipe_projetos`. **Achado importante no processo**: `usuarios.role` (coluna antiga, separada da tabela `usuario_papeis`) valia `'viewer'` pras duas, e o front-end de Orçamentos **lê essa coluna direto e bloqueia na tela** quem tem `role IN ('viewer','visitante')` — independente do RBAC novo. Só apagar o papel não bastava: troquei também `usuarios.role` de `'viewer'` para `'funcionario'` nas duas (valor neutro, não aciona nenhum bypass tipo `role==='admin'` nem o bloqueio do Orçamentos). Confirmado no fim: as duas ficam só com `equipe_projetos` no RBAC novo, sem nenhum papel/coluna legado sobrando.
- **Filippo, Vinicius e Pedro — decisão explícita: MANTER como está.** Achei 2 riscos reais antes de propor remover o `admin` legado deles: (1) **Pedro não tem `admin_geral`** — só `admin` legado + `dashboard_financeiro_acesso`; remover o legado sem repor causaria perda de acesso a 11 sistemas. (2) **Vinicius e Filippo perderiam Fichas Técnicas** — nenhum papel novo que eles têm cobre esse sistema, só o `admin` legado. Apresentei os dois riscos ao usuário, que confirmou manter como está — não é problema de segurança pra eles (donos/gerentes devem mesmo ter acesso total), a limpeza só era necessária onde causava bug real (Marina/Thairine). **Nenhuma mudança feita para os 3.**
- **"Administração" e "Estoque" formalizadas como equipe**: usuário confirmou que sim, as duas devem virar equipe — adicionadas 2 linhas novas em `equipes_projetos` (mesma tabela que já tinha Thairine/Marina/Thais), agora com 5 equipes no total. Puramente aditivo, sem migration/mudança de schema.
- **Coluna `lider_funcionario_id` adicionada a `equipes_projetos`** (`ALTER TABLE ... ADD COLUMN ... REFERENCES funcionarios(id)`, nullable) e preenchida pras 5 equipes, confirmado pelo usuário:
  - Thairine → líder: Thairine Cristina da Silva (ela mesma)
  - Marina → líder: Marina Pousa Barbara Gregorio (ela mesma)
  - Thais → líder: Thais Gomes Pegrucci Favaron (ela mesma)
  - Administração → líder: Vinicius Bortolin Costa
  - Estoque → líder: Matheus Fernando Luzente ("Líder de Logística" no cadastro — bate)
  - **Mariane (Gerente de Projetos) não é líder de nenhuma equipe individual** — ela coordena as 3 de projeto (Thairine/Marina/Thais) de forma transversal, confirmado anteriormente. Fica documentada aqui, não em `lider_funcionario_id` de nenhuma linha.
- **Ainda sem membros vinculados** — a tabela agora tem nome + líder por equipe, mas o vínculo "quais funcionários pertencem a cada equipe" (os 9 auxiliares de projeto, e quem mais entrar em Administração/Estoque) continua sem estrutura de dado — precisa da tabela `equipe_membros` (ver Proposta de estrutura), ainda não criada.

- **Vínculo funcionário → equipe implementado**: coluna `equipe_id` adicionada em `funcionarios` (`ALTER TABLE ... ADD COLUMN ... REFERENCES equipes_projetos(id)`) — usuário achou que isso já existia numa planilha, mas **confirmado no banco que não existia nenhuma coluna assim** (só `departamento_id`, que é o mesmo pros 9 auxiliares de projeto, não distingue equipe). Preenchida pras 19 pessoas identificadas até agora:
  - Thairine (3): Thairine Cristina da Silva, Adriana Mendonça Jabur, Giovana Bruna Gonella
  - Marina (4): Marina Pousa Barbara Gregorio, Giovanna Nori, Isabella Miguel Jacob, Ketlyn Verônica de Souza
  - Thais (4): Thais Gomes Pegrucci Favaron, Helena Nascimento Fogaça, Murillo Veloso Spimpolo, Trícia Helena Borges da Silva
  - Administração (5): Vinicius Bortolin Costa, Lana Bispo, Caroline Scaramuza Foresto (+ o registro duplicado "caroline"), debora
  - Estoque (3): Matheus Fernando Luzente, Alexandre Guilherme da Costa, Vitoria Lidia da Silva
  - **Filippo e Mariane ficam sem `equipe_id`** (Dono e Gerente de Projetos são transversais, não membros de uma equipe específica) — proposital, não esquecimento.
  - **Rafaela Netto continua sem NENHUM registro em `funcionarios`** — confirmado de novo nesta rodada (busca por "netto"/"rafaela" não achou nada). Ela precisa ser **cadastrada como funcionária primeiro** (não é só criar login depois — o registro básico dela nem existe).
- **Registro duplicado de Caroline e Debora encontrado**: cada uma tem 2 linhas em `funcionarios` (uma completa com cargo, outra genérica só com o primeiro nome e o `usuario_id` de fato usado no login) — vinculei `equipe_id` nas duas cópias pra não deixar nenhuma órfã, mas a duplicata em si não foi limpa (fora do escopo desta SPEC).

## Decisões ainda pendentes (usuário precisa confirmar antes de qualquer implementação)
- [ ] **Lana e kimberly** ainda têm papel legado (`admin`) coexistindo com papéis novos, e não foram endereçadas nesta rodada (o usuário confirmou manter só Filippo/Vinicius/Pedro como estão — Lana/kimberly ficaram de fora dessa decisão específica). Lana em particular tem uma mistura de 5 papéis novos (`administracao_comercial`, `compras_e_entregas`, `equipe_projetos`, `gerente`, `rh_administracao`) que não bate claramente com "ela cuida do RH" do organograma — vale revisar à parte.
- [ ] **Cadastrar Rafaela Netto em `funcionarios`** (não existe registro nenhum, nem cargo/departamento) antes de conseguir vincular equipe ou criar login pra ela.
- [ ] Limpar os registros duplicados de Caroline e Debora em `funcionarios` (2 linhas cada) — não bloqueia nada agora, mas é dívida de dado.

### Resolvidas em 2026-08-30/31
- ~~Identidade de vitoria/teste/moara/Terezinha/matheus/alexandrecosta490~~ → Vitoria/Matheus/Alexandre = Estoque; teste/moara/Terezinha = excluídos (teste não entra, moara e Terezinha saíram da empresa).
- ~~Papel de Mariane como "Gerente de Projetos"~~ → sem ação extra, só `equipe_projetos`; diferença é de escopo de dado (3 equipes), não de RBAC — fica pra SPEC técnica de visibilidade por equipe.
- ~~Papel de Estoque~~ → papel `estoque` próprio criado (Consultar Produtos + Sistema de Entregas), não reaproveitou `compras_e_entregas` — escopo confirmado como mais estreito pelo usuário.
- ~~Líder formal de Administração e Estoque~~ → Vinicius e Matheus, respectivamente. Coluna `lider_funcionario_id` criada e preenchida pras 5 equipes.
- ~~Vínculo funcionário → equipe~~ → coluna `equipe_id` criada em `funcionarios` e preenchida pras 19 pessoas identificadas (falta só Rafaela Netto, que nem tem registro ainda).
- ~~Papel de Vinicius~~ → já idêntico a Pedro/Filippo, confirmado no banco, nenhuma mudança necessária.
- ~~Papéis legados de Filippo/Vinicius/Pedro~~ → mantidos como estão, por decisão explícita do usuário após avaliar os riscos.
- ~~Administração/Estoque como equipe formal~~ → sim, 2 linhas novas em `equipes_projetos`.
- ~~E-mail/grafia de Rafaela Netto~~ → `rafaela@lucenera.com.br`.

## Escopo técnico ainda não implementado (confirmado, mas exige código/migration própria)

Estes dois itens são maiores que "ajustar papel no banco" — cada um deve virar sua própria SPEC técnica antes de codar, não saem como parte desta SPEC de estruturação:

1. **Visibilidade por equipe** (RLS por `equipe_id` em `projetos` e tabelas relacionadas) — confirmado que cada equipe só deve ver seus próprios projetos, e que Mariane (Gerente de Projetos) precisa ver as 3 equipes juntas. Precisa decidir: o que acontece com projeto sem equipe atribuída, como a Mariane "vê as 3" tecnicamente (papel extra? condição especial na policy?), e se isso afeta só `projetos` ou também `orcamentos`/outras tabelas ligadas.
2. **Esconder o Dashboard interno do CRM** de `equipe_projetos` — precisa de um `modulo` novo no CRM (que hoje não tem nenhum) + mudança no código do `Index.tsx`/rotas `/` e `/dashboard`.

## Proposta de estrutura (para discussão — nada decidido/implementado)

1. **Formalizar liderança e membros de equipe**: adicionar `lider_funcionario_id` em `equipes_projetos`, e uma tabela `equipe_membros` (equipe_id, funcionario_id) ligando os 9 auxiliares às 3 equipes — hoje esse vínculo só existe na cabeça de quem opera o sistema, não no banco.
2. **Revisar caso a caso os papéis legados** dos 11 usuários (achado 6) — provavelmente removendo o legado de Marina/Thairine (travando elas em `viewer` sem necessidade) e decidindo, um a um, se Filippo/Vinicius/Lana/kimberly devem manter `admin` legado ou migrar 100% pra papéis novos equivalentes.
3. Existe uma equipe de administração formal em `equipes_projetos` (ou tabela equivalente) prevista pra Administração/Estoque, ou fica de fora desse conceito (hoje exclusivo dos times de projeto)?

## Critérios de aceite (quando as decisões acima forem tomadas)

- O organograma real (Dono → 2 gerências → equipes/pessoas) está refletido de forma explícita e consultável no banco (não só "por convenção de nome").
- Cada pessoa citada no organograma tem exatamente o nível de acesso condizente com sua função real — sem papel legado "restante" distorcendo pra mais ou pra menos.
- Fica documentado, para quem entrar depois, quem é responsável por qual equipe/área — hoje essa informação só existe verbalmente/nesta conversa.

## Pendências

- [ ] O que fazer com os papéis legados que ainda coexistem com os novos.
- [ ] Formalizar (ou não) "Administração"/"Estoque" como equipe.
- [ ] Criar as ~14-15 contas novas (usuário, via Hub) e então atribuir os papéis já definidos (`equipe_projetos` para as 9 de projeto, `estoque` para Vitoria/Matheus/Alexandre).
- [ ] Abrir SPEC técnica própria para visibilidade por equipe (RLS) e para o módulo de Dashboard do CRM — ambos confirmados, nenhum implementado ainda.
