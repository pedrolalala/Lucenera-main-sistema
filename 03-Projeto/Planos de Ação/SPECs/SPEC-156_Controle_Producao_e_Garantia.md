---
titulo: "SPEC-156 — Controle de Produção e Controle de Garantia (2 sistemas novos, separados do Compras)"
status: "Módulo 1 (Produção) implementado, aplicado no Supabase real e publicado como sistema próprio. Módulo 2 (Garantia) só com repositório/projeto Skip criados, sem código ainda — pendências de negócio em aberto."
data_ultima_modificacao: 2026-09-22
sistemas_envolvidos:
  - Controle de Produção (04-Sistemas/controle-de-producao, github.com/pedrolalala/Controle-de-producao, Skip projectId 60535)
  - Controle de Garantia (04-Sistemas/controle-de-garantia, github.com/pedrolalala/controle-de-garantia, Skip projectId 60545) — repositório e projeto Skip criados, sem implementação ainda
  - Supabase (banco central)
---

# SPEC-156 — Controle de Produção e Controle de Garantia (módulos novos em Estoque/Compras)

> Fonte primária: reunião Vinícius, 16/09/2026, arquivos `02-Reunioes/24. Lucenera (Vinicius) - 16.09.2026_novo sistema de vendas/Reunião.02.txt` (Controle de Produção) e `Reunião.03.txt` (Controle de Garantia).

## Checklist de Ação

### Banco (Supabase, repo central)

- [x] Migration `producao_pedidos` + `producao_pedido_handoffs` (ver seção Módulo 1) — redigida em `supabase/db/migrations/20260922_157_producao_pedidos/001_producao_pedidos.sql` e **aplicada no Supabase real em 22/09/2026** (dry-run com ROLLBACK antes do COMMIT real)
- [x] Bucket de Storage `producao_pedidos` (PDF do pedido + PDF do desenho, leitura pública / escrita `authenticated` — confirmado com o usuário, mesmo padrão do bucket `notas_fiscais_compra`) — aplicado
- [x] RLS de `producao_pedidos` / `producao_pedido_handoffs` — aplicada (leitura ampla + escrita ampla para `authenticated`, sem regra de dono, conforme decidido na SPEC)
- [ ] Migration `garantia_protocolos` (+ enum `garantia_protocolo_status`) + `garantia_itens` (ver seção Módulo 2) — **fora do escopo desta execução** (Módulo 2 não implementado: pendências de regra de negócio em aberto)
- [ ] RLS de `garantia_protocolos` / `garantia_itens` — fora do escopo desta execução (Módulo 2)
- [ ] (Opcional, decisão pendente) tabela `garantia_fornecedor_responsavel` (mapeamento fornecedor → usuário padrão) — fora do escopo desta execução (Módulo 2)
- [ ] Atualizar `supabase/db/domains/estoque_compras.md` com os dois módulos novos — não feito nesta execução (o item cobre os dois módulos juntos; melhor fazer numa mão só quando o Módulo 2 também estiver implementado, para não documentar pela metade)
- [ ] Atualizar `supabase/docs/relationships.md` se novas FKs relevantes forem criadas (`producao_pedidos.empresa_id -> empresas.id`, `garantia_itens.fornecedor_id/cliente_id/produto_id/orcamento_id -> contatos/produtos/orcamentos`) — não feito nesta execução, mesmo motivo acima
- [ ] Reextrair `supabase/db/current/` após aplicar as migrations — depende da aplicação real da migration (passo manual do usuário)

### Frontend

- [x] Sistema `04-Sistemas/controle-de-producao` (Skip projectId 60535) bootstrapado do zero: login simples via Supabase Auth (`hooks/use-auth.tsx`, sem `hub_pode_executar` — sistema ainda não registrado no Hub), `ProtectedRoute`, `AppHeader` com link de volta pra Central — implementado em 22/09/2026
- [x] `services/producao.ts` + `pages/Producao.tsx` + `components/producao/` (modal novo pedido, upload de PDF, board/lista por status, tela de handoff) migrados sem alteração de lógica — implementado em 22/09/2026
- [x] Removido de dentro de `04-Sistemas/compras-lucenera-3o23t98ee` (rota `/producao`, item de nav, `services/producao.ts`, `pages/Producao.tsx`, `components/producao/`) depois de confirmado funcionando no sistema novo — 22/09/2026
- [x] `04-Sistemas/controle-de-garantia` (Skip projectId 60545) criado como submodule + repositório, conectado ao Supabase central pelo usuário — **sem código ainda**, aguardando pendências de negócio do Módulo 2 serem resolvidas
- [ ] `services/garantia.ts` + `pages/Garantia.tsx` + `components/garantia/` dentro de `controle-de-garantia` (formulário de item de garantia, agrupamento em protocolo, painel de status do protocolo, painel de adiantamentos pendentes de devolução) — fora do escopo desta execução (Módulo 2)
- [ ] Login/`ProtectedRoute`/`AppHeader` do `controle-de-garantia` (mesmo padrão simples do `controle-de-producao`) — fora do escopo desta execução (Módulo 2)
- [ ] Avaliar se `04-Sistemas/controle-de-producao/supabase/AI_DB_CONTEXT.md` e `04-Sistemas/controle-de-garantia/supabase/AI_DB_CONTEXT.md` devem ser criados — não feito nesta execução

### Passos manuais do usuário

- [x] ~~Confirmar a nomenclatura exata da "terceira aba"~~ — resolvido em 22/09/2026 lendo a planilha real `01-Documento/01 - Planilhas/CONTROLE DE PRODUÇÃO (1).xlsx`: é `CORTES (GAP - SLOT - VISTA)`.
- [ ] Confirmar se Cláudio, João, Manoel, Antônio, Leandro, Alexandre e Matheus têm (ou vão ganhar) login em `usuarios`/Supabase Auth — define se os campos de responsável/handoff são FK (`usuarios.id`, dropdown) ou texto livre
- [ ] Definir quem pode escrever em qual protocolo de garantia (todo mundo, ou só quem "responde" pelo fornecedor daquele protocolo) — regra de permissão, não decidida nesta SPEC
- [ ] Definir a fonte de verdade da "data de venda" por peça na Garantia quando não houver `notas_fiscais` (pré-Focus NFe) — usar `orcamentos`/`projeto_itens`, `vendas` (legado Connect) ou preenchimento manual
- [x] ~~Aplicar a migration `20260922_157_producao_pedidos` no Supabase real~~ — aplicada em 22/09/2026 (dry-run + COMMIT real via psql), confirmada com `\d` nas duas tabelas e no bucket.
- [ ] Reextrair `supabase/db/current/` (snapshot completo do schema) — não feito nesta rodada; o projeto não reextrai a cada migration (ver `00_manifest.md`, última reextração completa é de 07/07/2026), fica pendente igual outras SPECs recentes. Fazer junto do Módulo 2 ou numa rodada de manutenção própria.
- [ ] Atualizar `supabase/db/domains/estoque_compras.md` e `supabase/docs/relationships.md` — mesmo motivo acima, pendente
- [ ] Homologar com Vitória/Débora/João o fluxo real de um pedido de produção ponta a ponta (upload dos 2 PDFs, atualização de status, marcar pronto, handoff com dupla assinatura) antes de descontinuar a planilha Excel — código está no ar em produção, mas ninguém testou ao vivo com dado real ainda
- [ ] Homologar com Vitória/Débora um protocolo de garantia real (ex.: Interlight) antes de descontinuar a planilha/processo manual de garantia — só relevante quando o Módulo 2 for implementado
- [x] ~~Rodar o agente `revisor` antes de qualquer commit~~ — feito em 22/09/2026, sem achados críticos (1 aviso sobre o bucket público, confirmado com o usuário como aceitável)
- [x] ~~Correção de arquitetura: mover Produção pra sistema próprio~~ — usuário corrigiu em 22/09/2026, depois do Módulo 1 já publicado dentro do Compras: os dois sistemas deveriam ser separados. Usuário criou os repositórios GitHub (`Controle-de-producao`, `controle-de-garantia`) e os projetos Skip, e conectou ambos ao Supabase central. Registrados como submodules novos em `04-Sistemas/`.
- [x] ~~Publicar `controle-de-producao` como sistema próprio~~ — bootstrap completo (login simples, service/página/componentes migrados) commitado+pushado no submodule (`7be80f6`) e publicado no Skip em 22/09/2026 (v0.0.5, `https://pagina-em-branco-e9c45.goskip.app`). QA pipeline do Skip (setup/lint/build/integrations/test) `ok` em todos os estágios; build e lint locais confirmados também (`npm run build`/`npm run lint` sem erros).
- [x] ~~Remover Produção de dentro do `compras-lucenera-3o23t98ee`~~ — rota, nav e os 6 arquivos (`services/producao.ts`, `pages/Producao.tsx`, `components/producao/*`) removidos da working tree do Skip (v0.0.77) e do submodule local (`363bab7`), ambos publicados/pushados em 22/09/2026. Lint/build locais confirmados sem erros novos (só os 4 warnings pré-existentes, incluindo o `SystemSwitcher` não usado já documentado como pendência separada do rollout SPEC-120).

## Objetivo

Hoje dois processos operacionais da Lucenera rodam em planilha Excel manual (Controle de Produção) ou não têm mais nem planilha confiável (Controle de Garantia — "nem tem planilha mais"), gerando fricção de comunicação (ligações para saber status), risco de "bucha" de responsabilidade (quem entregou/recebeu uma peça) e falta de rastreabilidade (peças acumuladas esperando abertura de garantia com fornecedor).

Esta SPEC cria dois sistemas novos, **funcionalmente independentes entre si, do Estoque/Compras, e sem vínculo com orçamento/venda/projeto nesta fase** (decisão explícita do Vinícius: "não vai ter vínculo nenhum com a venda... não vai ter vínculo com nada"):

1. **Controle de Produção** — réplica digital da planilha de pedidos de produção interna (peças "linha e esteca" cortadas sob demanda + "peças avulsas"), com gestão de status em tempo real visível por todos, e registro de handoff com dupla assinatura (quem entrega / quem recebe).
2. **Controle de Garantia** — substitui a planilha manual do Matheus por um controle de protocolos de garantia por fornecedor, com status de acompanhamento, tratamento de "adiantamento de garantia" (peça nova entregue antes da devolução da defeituosa) e desfecho (peça nova / conserto / não acatado).

## Decisões aprovadas

- **Correção de 22/09/2026 (usuário, depois de já publicado o Módulo 1 como módulo do Compras): os dois sistemas são separados do Compras, cada um com seu próprio sistema em `04-Sistemas/`/projeto Skip** — Controle de Produção e Controle de Garantia NÃO ficam dentro de `compras-lucenera-3o23t98ee`. A seção "Por que módulo, não sistema novo" abaixo é a justificativa antiga (equivocada) que motivou a primeira implementação; mantida só como histórico, não como decisão vigente. Plano de correção: criar os dois sistemas novos, migrar o código de Produção (já funcionando) para o sistema novo dele, depois remover a página/rota/nav de dentro do `compras-lucenera-3o23t98ee` (as tabelas no Supabase central não mudam de lugar, só o frontend).
- Controle de Produção nesta fase é **só** réplica da planilha + gestão de status + handoff com dupla assinatura. **Fora de escopo explicitamente adiado por Vinícius**: ficha técnica de matéria-prima (BOM) por peça, baixa automática de insumos ao gerar pedido de produção, cálculo de custo agregado por matéria-prima, "estoque em produção" separado do estoque pronto, vínculo do pedido de produção com orçamento/necessidade de compra/separação.
- Controle de Garantia nesta fase não tem vínculo obrigatório com `projeto_itens`/reserva de estoque/separação — é um controle de protocolo e status, standalone, podendo referenciar orçamento/cliente/produto apenas de forma informativa/opcional.
- O prazo de garantia é contado a partir da **data de venda ao cliente**, não da data de compra do fornecedor (usar a nota fiscal de venda mais recente quando houver mais de uma).
- Vínculo com "Hélio" (sistema/processo legado citado na reunião) foi explicitamente descartado pelo Vinícius ("nem precisa mais, é uma coisa que a gente pode eliminar") — não incluir esse campo.
- Nenhuma alteração em tabelas do fluxo financeiro/orçamento (`boletos`, `projeto_parcelas`, `aprovar_orcamento_financeiro`) é necessária para esta SPEC.

## Por que módulo, não sistema novo (SUPERADA — ver "Decisões aprovadas" acima, correção de 22/09/2026)

- `03-Projeto/Escopos/05_ESCOPO_ESTOQUE_COMPRAS.md`, SPEC-EST-15, já define Garantia/troca/devolução como parte do domínio de Estoque/Compras — criar um sistema separado contradiria essa decisão já registrada.
- `04-Sistemas/compras-lucenera-3o23t98ee` já tem página dedicada para a Débora (`pages/PainelDebora.tsx`, em produção) — Débora e Vitória (as duas pessoas mais citadas nos dois novos processos) já são usuárias reais desse sistema, com login e acesso via `hub_pode_executar(p_system_slug: 'necessidade-de-compra', ...)`.
- Criar sistema novo implicaria registro em `systems`/`papel_permissoes` (Hub/TI), novo projeto Skip, nova sessão SSO — overhead desproporcional para dois MVPs que o próprio Vinícius descreveu como "banal"/"simples" e que ele mesmo pausou na parte mais complexa (ficha técnica).
- Padrão de acesso a dados já estabelecido no sistema (mantido, não substituído): uma página em `src/pages/`, um arquivo de serviço em `src/services/<dominio>.ts` chamando o cliente Supabase diretamente (sem Redux/Zustand), componentes de modal/tabela em `src/components/<dominio>/`, item de rota em `src/components/AppNav.tsx`. Ver `src/services/devolucoes.ts` + `src/components/compra/DevolucaoEstoqueTab.tsx` como precedente de módulo adicionado incrementalmente sem alterar arquitetura.

## Definição da SPEC

### Análise obrigatória de ecossistema

- **Depende de `projetos`/`orcamentos`/`contatos`/`produtos`/`boletos`/`projeto_itens`/`projeto_parcelas`/`usuarios`/`systems`/`user_system_access`?** Sim, parcialmente: `contatos` (fornecedor/cliente), `produtos` (peça), `usuarios` (responsável/handoff/created_by), `empresas` (campo "empresa" do pedido de produção) e, de forma **opcional/informativa**, `orcamentos`/`notas_fiscais` (Garantia, só para calcular a data de venda). Não toca `boletos`, `projeto_itens`, `projeto_parcelas`, `systems`/`user_system_access` diretamente (usa o `hub_pode_executar` já existente do sistema hospedeiro, sem criar `system_slug` novo).
- **Afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística, RH ou Hub/TI?** Afeta **Estoque/Compras** (dois módulos novos). Não afeta os demais nesta fase — é a decisão explícita do Vinícius de manter os dois processos desacoplados por enquanto.
- **Existe dado duplicado que deveria ser derivado por relacionamento em vez de duplicado?** Em parte, e isso é intencional nesta fase: `producao_pedidos.cliente_nome` e `garantia_itens` guardam nomes/textos livres em vez de FK obrigatória para `contatos`, porque Vinícius pediu explicitamente que não haja vínculo com a venda. Onde uma referência opcional existe (fornecedor/produto/cliente/orçamento), ela é FK real para o cadastro canônico, não texto duplicado.
- **Existe migration antiga em algum sistema que contradiz o snapshot central?** Não identificada para estes dois domínios — são tabelas novas, sem equivalente anterior (as ocorrências de `garantia_*` já existentes em `separacoes`/`separacoes_arquivos`, colunas `garantia_detalhes`/`inclui_garantia`/`garantia_peca`/`garantia_motivo`, e o valor `'Estoque Garantia'` do enum `estoque_local`, são de outro domínio — Logística/estoque físico — e não são reaproveitadas aqui; não colidem em nome de tabela).
- **A mudança exige atualizar `AI_DB_CONTEXT.md` de algum sistema?** `04-Sistemas/compras-lucenera-3o23t98ee` não tem esse arquivo hoje — avaliar se deve ser criado (ver checklist).
- **Sistema(s) afetado(s) e padrão de acesso a dados já usado:** `compras-lucenera-3o23t98ee`, padrão `services/*.ts` (chamada direta ao `supabase-js`) + `pages/*.tsx` + `components/<dominio>/*.tsx` + `hooks/use-auth.tsx` (checagem via `hub_pode_executar`). Mantido sem alteração de arquitetura.

---

### Módulo 1 — Controle de Produção

#### Estado atual

Planilha real confirmada: `01-Documento/01 - Planilhas/CONTROLE DE PRODUÇÃO (1).xlsx`, com **3 abas** (resolve a pendência da "terceira aba"):

| Aba | Linhas com dado | Colunas (header real) |
|---|---|---|
| `LINEAS E STECCAS` | 748 | DATA, PEDIDO, EMPRESA, SISTEMA, ARQUITETA (O), CLIENTE, PRAZO, NORMAL (prioridade), STATUS, ENTREGA (data que ficou pronto), OBSERVAÇÕES |
| `PEÇAS AVULSAS` | 948 | DATA, PEDIDO, EMPRESA, ARQUITETA (O), CLIENTE, PRAZO, NORMAL (prioridade), STATUS, DATA (2ª — data que ficou pronto), OBSERVAÇÕES |
| `CORTES (GAP - SLOT - VISTA)` | 26 | DATA, EMPRESA, ARQUITETA (O), CLIENTE, PRAZO, NORMAL (prioridade), STATUS, DATA (2ª — data que ficou pronto), OBSERVAÇÕES — **sem coluna PEDIDO**, o corte não tem número de pedido próprio, só observação (ex.: "GAP - L05, L07, L14") |

Achados que mudam o desenho original desta SPEC:
- **ARQUITETA (O)** não é um funcionário interno (Cláudio/João/Vitória) — é o(a) arquiteto(a)/decorador(a) responsável pelo projeto do cliente (valores reais: MARIANE, MARINA, THAIRINE, RICARDO, THAIS...). Não tem cadastro formal no banco hoje → fica como texto livre, não FK.
- **EMPRESA** tem valores fechados e batem com `empresas.nome` real do grupo: `LUCENERA`, `ISLIGHT`, `FOCO`, `CONNECT`, `CITEL` → vira FK real (`empresas.id`), não texto livre.
- **SISTEMA** só existe na aba `LINEAS E STECCAS` (mesmos 5 valores de EMPRESA + "CONNECT" com maior peso) — parece indicar o sistema/canal de origem do pedido, não o pedido em si. Campo opcional, exclusivo desse tipo de peça.
- **NORMAL** é o nome da coluna de prioridade na planilha (valores reais: `NORMAL`, `ALTA`, `URGENTE`) — nome ruim, no sistema novo vira `prioridade`.
- **STATUS** na planilha é quase sempre `PRONTO` (é um arquivo de pedidos já finalizados), mas aparecem também `CANCELADO`, `EXCLUÍDO`, `ENTRADA PARCIAL` — usados como seed da lista de sugestões (ver "Pendência de status" abaixo, resolvida a favor da opção 1 do texto livre + sugestões).
- **CLIENTE** e **PEDIDO** (nº) batem com o que Vinícius descreveu na reunião (ex.: pedido 1868) — mantidos como planejado.
- Não existe, na planilha, nenhuma coluna de handoff/dupla assinatura — é um processo em papel implantado à parte, fora da planilha. `producao_pedido_handoffs` continua sendo criada do zero, como já estava nesta SPEC, só que agora sabidamente **não substitui** dado nenhum da planilha, é aditiva.

Fluxo operacional (sem mudança): Débora monta o pedido de produção (hoje também na Connect) → manda desenho/pedido no grupo do WhatsApp → João imprime e entra na fila → Cláudio/Antônio/Manoel produzem → Vitória alimenta a planilha na entrada (data do pedido, empresa, sistema, arquiteto(a), cliente, prazo) e na saída (status, data que ficou pronto). Handoff com dupla assinatura (quem entrega / quem recebe) foi implantado na semana anterior à reunião, em papel, para resolver "bucha" de responsabilidade quando some peça.

#### Tabelas novas (`public`, banco central)

```sql
producao_pedidos
  id                     uuid PK default gen_random_uuid()
  tipo_peca              text NOT NULL CHECK (tipo_peca IN ('lineas_steccas','peca_avulsa','corte'))  -- 1 por aba real da planilha
  numero_pedido          text            -- nullable: aba CORTES não tem número de pedido
  data_pedido            date NOT NULL   -- "DATA" (1ª coluna)
  empresa_id             uuid NOT NULL REFERENCES empresas(id)   -- FK real: LUCENERA/ISLIGHT/FOCO/CONNECT/CITEL já existem em empresas
  sistema_origem         text            -- só usado quando tipo_peca = 'lineas_steccas'; texto livre (LUCENERA/CONNECT/FOCO/ISLIGHT/CITEL)
  arquiteto_nome         text            -- "ARQUITETA (O)", texto livre (sem cadastro formal hoje)
  cliente_nome           text            -- texto livre, SEM FK (decisão: sem vínculo com venda)
  data_prazo             date            -- "PRAZO" = data prevista de entrega
  prioridade             text NOT NULL DEFAULT 'normal' CHECK (prioridade IN ('normal','alta','urgente'))  -- coluna "NORMAL" na planilha
  status                 text NOT NULL DEFAULT 'em_andamento'  -- ver "Pendência de status" abaixo
  data_ficou_pronto      date            -- 2ª coluna "DATA"/"ENTREGA" na planilha
  observacao             text            -- ex.: "GAP - L05, L07, L14" / "precisa que o Felipe faça o cone antes"
  pdf_pedido_url         text                     -- Storage bucket producao_pedidos
  pdf_desenho_url        text                     -- Storage bucket producao_pedidos
  created_by             uuid REFERENCES usuarios(id)
  created_at             timestamptz NOT NULL DEFAULT now()
  updated_at             timestamptz NOT NULL DEFAULT now()

producao_pedido_handoffs
  id                        uuid PK default gen_random_uuid()
  producao_pedido_id        uuid NOT NULL REFERENCES producao_pedidos(id) ON DELETE CASCADE
  entregue_por_usuario_id   uuid REFERENCES usuarios(id)  -- nullable
  entregue_por_nome         text NOT NULL
  recebido_por_usuario_id   uuid REFERENCES usuarios(id)  -- nullable
  recebido_por_nome         text NOT NULL
  data_hora                 timestamptz NOT NULL DEFAULT now()
  observacao                text
  created_at                timestamptz NOT NULL DEFAULT now()
```

Storage: bucket `producao_pedidos`, 1 objeto para o PDF do pedido e 1 para o PDF do desenho por `producao_pedidos.id`, policy `authenticated` leitura/escrita (mesmo padrão do bucket `notas_fiscais_compra` já em uso no mesmo sistema).

RLS: leitura ampla para qualquer usuário `authenticated` com acesso ao sistema (requisito central do Vinícius — "para que todos consigam consultar", elimina a ligação Débora→Cláudio); escrita para `authenticated` (sem regra de dono/criador nesta fase, já que times de estoque/produção compartilham o mesmo fluxo).

#### Status — resolvido a favor da opção 1 (texto livre + sugestões)

Vinícius descreveu os status como algo vivo, alimentado pelo João em tempo real ("em andamento", "aguardando pintura", "com o Cunha", etc.). A planilha real confirma que não é uma lista fechada: 748+948+26 linhas têm quase só `PRONTO` (às vezes `Pronto`/`PRONTA`, inconsistente), mas também aparecem `CANCELADO`, `EXCLUÍDO` e `ENTRADA PARCIAL` soltos. Decisão: `status text` livre (sem enum no banco) + dropdown de sugestões na UI, semeado com: `em_andamento`, `aguardando_pintura`, `com_terceiro` (ex.: "com o Felipe"/"com o Cunha"), `pronto`, `entrada_parcial`, `cancelado`, `excluido`. Novo valor digitado pelo usuário é aceito (não é CHECK constraint) — mantém a flexibilidade que a planilha sempre teve, mas com sugestões pra evitar a inconsistência de maiúsculas/minúsculas observada nos dados reais.

#### Fluxo de tela (alto nível)

1. Débora (ou quem monta o pedido) cria um `producao_pedidos` com PDF do pedido + PDF do desenho.
2. João visualiza a fila (lista/board por status) e atualiza `status` em tempo real.
3. Quando a peça fica pronta, quem finaliza registra `data_ficou_pronto` e um `producao_pedido_handoffs` (quem entrega / quem recebe) — os dois campos são obrigatórios juntos (não permitir salvar handoff com só um lado preenchido).
4. Qualquer pessoa com acesso ao sistema consulta o status sem precisar ligar para ninguém.

#### Critérios de aceite

- Um pedido de produção pode ser criado com todos os campos da planilha real (tipo de peça/aba, nº pedido quando existir, empresa, sistema de origem quando aplicável, arquiteto(a), cliente, data do pedido, prazo, prioridade) e os dois PDFs anexados.
- Um pedido do tipo `corte` pode ser salvo sem número de pedido (reflete a aba `CORTES`, que nunca teve essa coluna).
- O status do pedido é visível e atualizável por qualquer usuário com acesso, sem exigir contato direto com quem está produzindo.
- Um handoff só é salvo com "entregue por" e "recebido por" preenchidos (nunca um lado sozinho) — reproduz a regra que resolveu a bucha de responsabilidade.
- Nenhum campo de `producao_pedidos`/`producao_pedido_handoffs` referencia `orcamentos`, `projeto_itens` ou `estoque_itens` — confirma o desacoplamento pedido pelo Vinícius.

---

### Módulo 2 — Controle de Garantia

#### Estado atual

Não existe mais planilha confiável ("nem tem planilha mais" — Vinícius, 16/09). O Matheus dá saída do produto em garantia e tentava alimentar uma planilha manual que ficou desatualizada. Prazo de garantia varia por fornecedor (Interlight = 5 anos; outros = 1 ou 2 anos) e conta a partir da data de venda ao cliente (nota fiscal de venda mais recente, quando houver mais de uma). Atendimento imediato quando o caso é simples/óbvio (troca do próprio estoque); vai para análise do fornecedor quando há suspeita de mau uso, recorrência ou sinistro (ex.: surto elétrico com muitas peças queimadas). Peças defeituosas atendidas se acumulam até juntar volume suficiente por fornecedor para abrir um "bloco"/protocolo formal. Existe o caso de "adiantamento de garantia" (cliente recebe peça nova antes de devolver a defeituosa, para não pagar eletricista duas vezes), que fica pendente até a peça velha ser recolhida — cobrança periódica (ex.: semanal).

Responsáveis por fornecedor citados: Vitória cuida da maioria; Débora cuida de Interlight e Iluminar.

#### Tabelas novas (`public`, banco central)

```sql
CREATE TYPE public.garantia_protocolo_status AS ENUM (
  'em_contato_fornecedor',
  'nota_fiscal_emitida',
  'material_enviado',
  'aguardando_analise',
  'material_recebido',
  'finalizado'
);

garantia_protocolos
  id             uuid PK default gen_random_uuid()
  fornecedor_id  uuid NOT NULL REFERENCES contatos(id)   -- contatos.tipo = 'fornecedor'
  responsavel_id uuid REFERENCES usuarios(id)             -- Vitória ou Débora, conforme fornecedor
  status         public.garantia_protocolo_status NOT NULL DEFAULT 'em_contato_fornecedor'
  desfecho       text CHECK (desfecho IN ('peca_nova','conserto','nao_acatado'))  -- só quando finalizado
  observacao     text
  created_at     timestamptz NOT NULL DEFAULT now()
  updated_at     timestamptz NOT NULL DEFAULT now()

garantia_itens
  id                        uuid PK default gen_random_uuid()
  fornecedor_id             uuid NOT NULL REFERENCES contatos(id)
  produto_id                uuid REFERENCES produtos(id)          -- nullable, peça sem cadastro
  produto_descricao_livre   text                                   -- fallback quando produto_id é NULL
  cliente_id                uuid REFERENCES contatos(id)          -- nullable
  orcamento_id              uuid REFERENCES orcamentos(id)        -- nullable, opcional/informativo
  data_venda_referencia     date                                   -- snapshot usado no cálculo do prazo
  prazo_garantia_anos       numeric                                -- snapshot do prazo aplicável (pendência: origem)
  motivo                    text NOT NULL                          -- 'queimou' | 'sobrecarga_mau_uso' | 'envio_errado' | 'producao_errada' | 'outro'
  atendimento               text NOT NULL CHECK (atendimento IN ('imediato','analise_fornecedor'))
  adiantamento              boolean NOT NULL DEFAULT false
  peca_antiga_devolvida_em  date                                   -- fecha a pendência do adiantamento
  garantia_protocolo_id     uuid REFERENCES garantia_protocolos(id) -- nullable até ser agrupado no "bloco"
  quantidade                numeric NOT NULL DEFAULT 1
  observacao                text
  created_by                uuid REFERENCES usuarios(id)
  created_at                timestamptz NOT NULL DEFAULT now()
  updated_at                timestamptz NOT NULL DEFAULT now()
```

Opcional (pendência, ver abaixo): `garantia_fornecedor_responsavel(fornecedor_id uuid REFERENCES contatos(id), usuario_id uuid REFERENCES usuarios(id))` como sugestão de responsável padrão por fornecedor (Vitória/Débora), sem forçar regra de permissão de escrita.

RLS: leitura ampla para `authenticated` (o objetivo declarado é "todo mundo pode ver como tá os processos de garantia"). Escrita: pendência — Vinícius não definiu se é restrita a quem "responde" pelo fornecedor.

#### Fluxo de tela (alto nível)

1. Peça com defeito chega → cria-se um `garantia_itens` com fornecedor, produto (ou descrição livre), cliente, motivo, se foi atendimento imediato ou foi para análise, se é adiantamento.
2. Itens sem `garantia_protocolo_id` ficam numa lista "aguardando abrir protocolo" (o "canto cheio de coisas pra pedir garantia").
3. Quando há volume suficiente por fornecedor, Vitória/Débora agrupam os itens em um `garantia_protocolos` novo (preenchendo `garantia_protocolo_id` nos itens) e avançam o `status` do protocolo pelos 6 estados fixos.
4. Ao finalizar, registra-se `desfecho` (peça nova / conserto / não acatado).
5. Itens com `adiantamento = true` e `peca_antiga_devolvida_em IS NULL` aparecem num painel de pendências para cobrança periódica.

#### Critérios de aceite

- Todo item de garantia registra fornecedor, peça (ou descrição livre), motivo, se foi atendimento imediato ou foi para análise, e se é adiantamento.
- Um protocolo de garantia agrega N itens de um mesmo fornecedor e percorre os 6 status fixos definidos por Vinícius, sem estado livre/hardcode divergente.
- O desfecho (peça nova / conserto / não acatado) só é exigido quando o protocolo está `finalizado`.
- Itens de adiantamento sem devolução aparecem numa lista de pendência, sem exigir automação de notificação nesta fase (decisão pendente se será automática).
- Nenhum campo é obrigatoriamente vinculado a `projeto_itens`/`estoque_itens`/`separacoes` — confirma o desacoplamento pedido pelo Vinícius; `orcamento_id` é sempre opcional/informativo.
- Não existe nenhum campo remanescente de vínculo com "Hélio".

## Realizado

**22/09/2026 — Módulo 1 (Controle de Produção) implementado.** Módulo 2 (Controle de Garantia) **não** foi implementado nesta execução — continua com pendências de regra de negócio em aberto (permissão de escrita por fornecedor, origem da data de venda pré-Focus-NFe), listadas na seção "Pendências".

Banco (repo central, `supabase/db/migrations/20260922_157_producao_pedidos/001_producao_pedidos.sql`) — **redigida e aplicada no Supabase real em 22/09/2026** (dry-run com ROLLBACK antes do COMMIT real, confirmada com `\d` nas duas tabelas e no bucket):
- Tabela `producao_pedidos` (campos exatamente como especificados na seção Módulo 1, `tipo_peca` CHECK `lineas_steccas|peca_avulsa|corte`, `empresa_id` FK real para `empresas`, `status` texto livre sem CHECK).
- Tabela `producao_pedido_handoffs` (dupla assinatura, `entregue_por_nome`/`recebido_por_nome` NOT NULL, `*_usuario_id` nullable).
- Índices em `tipo_peca`, `status`, `empresa_id`, `data_pedido`.
- Trigger `producao_pedidos_updated_at` usando `public.set_updated_at()` (função já existente no banco, reaproveitada — mesmo padrão de `contatos`/`produtos`/`projetos`/`usuarios`).
- RLS: leitura e escrita amplas para `authenticated` em ambas as tabelas (sem regra de dono, conforme decisão já registrada na SPEC).
- Bucket de Storage `producao_pedidos` (público para leitura, `authenticated` para upload — mesmo padrão do bucket `notas_fiscais_compra`, usado como referência de sintaxe).

Frontend (`04-Sistemas/compras-lucenera-3o23t98ee`, Skip projectId 40326 — **implementado, commitado+pushado no submodule (`cae8341`) e publicado no Skip em produção (v0.0.76, 22/09/2026)**):
- `src/services/producao.ts`: CRUD de `producao_pedidos` (criar com upload dos 2 PDFs, listar com filtro por `tipo_peca`/`empresa_id`/`prioridade`/busca textual, atualizar status, marcar pronto, registrar handoff, listar handoffs, listar usuários ativos para sugestão de nome no handoff, listar empresas). Segue o padrão já usado em `notas-fiscais-compra.ts`/`devolucoes.ts` (chamada direta ao `supabase-js`, `(supabase as any)` porque as tabelas novas ainda não estão no `types.ts` gerado).
- `src/pages/Producao.tsx`: lista única com filtro por tipo de peça (as 3 abas da planilha viram um filtro, não 3 telas), filtro por empresa/prioridade, busca textual, badges de prioridade/status, ação "Status" (abre modal de atualização, aceita texto livre com sugestões via `<datalist>`, e quando o valor é "pronto" exige data), ação "Handoff" (abre modal de dupla assinatura), linha expansível com histórico de handoffs.
- `src/components/producao/ModalNovoPedidoProducao.tsx`: formulário com todos os campos da planilha real + upload dos 2 PDFs (campo "Sistema de origem" só aparece quando `tipo_peca = lineas_steccas`; "Nº do pedido" fica desabilitado/opcional quando `tipo_peca = corte`, reproduzindo a ausência real dessa coluna na aba Cortes).
- `src/components/producao/ModalAtualizarStatusProducao.tsx`: campo de texto com `<datalist>` de sugestões (`em_andamento`, `aguardando_pintura`, `com_terceiro`, `pronto`, `entrada_parcial`, `cancelado`, `excluido`), aceita qualquer valor digitado (sem CHECK no banco); quando o status normalizado é "pronto", exige e grava `data_ficou_pronto`.
- `src/components/producao/ModalHandoffProducao.tsx`: campos "Entregue por"/"Recebido por" com `<datalist>` de usuários ativos (resolução "melhor esforço" do `usuario_id` por nome exato) — submissão bloqueada (`podeSalvar`) a menos que os dois campos estejam preenchidos, reproduzindo a regra central da SPEC que resolveu a "bucha" de responsabilidade.
- `src/components/producao/HistoricoHandoffsPanel.tsx`: painel expansível inline (mesmo padrão de `FornecedoresDaMarcaPanel.tsx` em `Marcas.tsx`) com a lista de handoffs de um pedido.
- `src/components/AppNav.tsx`: item de navegação "Produção" (`/producao`, ícone `Factory`) adicionado à lista existente — sem checagem de permissão por item (o sistema já checa acesso a nível de app inteiro via `hub_pode_executar('necessidade-de-compra', ...)` em `use-auth.tsx`, confirmado lendo o hook antes de implementar).
- `src/App.tsx`: rota `/producao` registrada dentro do `<ProtectedRoute>` existente.

Verificação feita: `npm run lint` (oxlint) e `npm run build` (vite build) rodados no submodule `compras-lucenera-3o23t98ee` sem erros novos (só warnings pré-existentes, não relacionados a estes arquivos); `npx oxfmt --check` confirmado limpo nos arquivos tocados. Revisão do agente `revisor` sem achados críticos (1 aviso sobre bucket público, confirmado aceitável com o usuário — mesmo padrão de `notas_fiscais_compra`). Migration aplicada no Supabase real (dry-run + COMMIT via psql, confirmada com `\d`). Publicação: `App.tsx`/`AppNav.tsx` locais estavam desatualizados frente à working tree real do Skip (que já tinha lazy-loading por rota, `ProtectedRoute` e `SystemSwitcher` do rollout SPEC-120 aplicados direto no Skip, não refletidos no submodule) — a rota/nav nova foi lida via `skip_file_read` e enxertada no padrão real do Skip via `skip_file_write`, não sobrescrita pela versão local mais simples; `skip_project_apply_changes` (QA completo: setup/lint/build/integrations/test, todos `ok`) + `skip_project_publish` confirmaram a publicação em `https://pagina-em-branco-cdd79.goskip.app`. **Não testado manualmente no navegador com dado real** (golden path com Vitória/Débora/João) — fica como passo manual do usuário (ver seção "Passos manuais do usuário").

Nenhum campo de `producao_pedidos`/`producao_pedido_handoffs` referencia `orcamentos`, `projeto_itens` ou `estoque_itens` — confirma o desacoplamento pedido pelo Vinícius (critério de aceite da SPEC).

**22/09/2026 (mesmo dia) — correção de arquitetura: migração para sistema próprio.** Depois do Módulo 1 já publicado dentro do `compras-lucenera-3o23t98ee`, o usuário corrigiu: os dois sistemas deveriam ser separados do Compras, não módulos dele (ver "Decisões aprovadas"). O usuário criou os repositórios GitHub `pedrolalala/Controle-de-producao` e `pedrolalala/controle-de-garantia`, os projetos Skip correspondentes (60535 e 60545) e conectou ambos ao mesmo Supabase central (`vcvcwzmbiftcawncibke`, confirmado batendo com o projeto real). Registrados como submodules novos em `04-Sistemas/controle-de-producao` e `04-Sistemas/controle-de-garantia`.

Migração do Módulo 1 executada na sequência:
- `controle-de-producao` (Skip 60535) bootstrapado do zero a partir do template em branco: `hooks/use-auth.tsx` (login simples por e-mail/senha no mesmo Supabase Auth central, **sem** `hub_pode_executar` — o sistema ainda não está registrado na tabela `systems` do Hub, então checagem de permissão granular não é possível hoje), `components/ProtectedRoute.tsx`, `components/AppHeader.tsx` (link de volta pra Central), `App.tsx`/`pages/Login.tsx` novos. `services/producao.ts`, `pages/Producao.tsx` e os 4 componentes de `components/producao/` foram migrados **sem alteração de lógica** (só o container da página perdeu o offset de altura fixo que existia por causa do tab-nav do Compras). `package.json` ganhou `@supabase/supabase-js` (Skip já tinha adicionado na working tree ao conectar o Supabase; local precisou do mesmo `npm install` pra buildar). `src/lib/supabase/types.ts` local é um stub minimalista (não o `Database` completo gerado pelo Skip, que passa de 256KB) — sem efeito em runtime porque todo acesso às tabelas novas já usa `(supabase as any)`.
- Verificação: `skip_project_apply_changes` (QA completo: setup/staticAnalysis/build/integrations/test, todos `ok`) + `skip_project_publish` publicaram em `https://pagina-em-branco-e9c45.goskip.app`. Localmente, `npm run lint` e `npm run build` também passaram sem erros no submodule. Commitado e pushado (`7be80f6`).
- Depois de confirmado que o sistema novo builda e publica limpo, o Módulo 1 foi **removido** de dentro do `compras-lucenera-3o23t98ee`: rota `/producao`, item de nav "Produção" e os 6 arquivos (`services/producao.ts`, `pages/Producao.tsx`, `components/producao/*`) apagados tanto da working tree do Skip (`skip_file_delete` + `skip_project_apply_changes` + `skip_project_publish`, v0.0.77, mesma URL `https://pagina-em-branco-cdd79.goskip.app`) quanto do submodule local (commitado e pushado, `363bab7`). `App.tsx`/`AppNav.tsx` do Compras voltaram ao estado anterior à SPEC-156 nos dois lugares. Lint/build locais confirmados sem erros novos.
- **As tabelas `producao_pedidos`/`producao_pedido_handoffs` no Supabase central não mudaram de lugar** — só o frontend migrou de projeto. Nenhuma nova migration foi necessária para a correção.
- `controle-de-garantia` (Skip 60545) só teve o submodule/repositório registrados e a conexão ao Supabase feita pelo usuário — **nenhum código escrito**, aguardando as pendências de negócio do Módulo 2 (permissão de escrita por fornecedor, origem da data de venda pré-Focus-NFe, listadas abaixo) serem resolvidas antes de implementar.

**Lição registrada em memória** ([[feedback_confirmar_sistema_novo_vs_modulo_com_usuario]]): decisão de "vira módulo de sistema existente" vs "vira sistema novo separado" é do usuário, não deveria ter sido decidida e implementada sem confirmação explícita — mesmo com justificativa técnica sólida (ver seção superada acima).

## Pendências

- [x] ~~Confirmar a nomenclatura exata da terceira aba~~ — **Resolvido em 22/09/2026** lendo a planilha real (`01-Documento/01 - Planilhas/CONTROLE DE PRODUÇÃO (1).xlsx`): a 3ª aba é `CORTES (GAP - SLOT - VISTA)`. `producao_pedidos.tipo_peca` vira `'lineas_steccas' | 'peca_avulsa' | 'corte'`.
- [x] ~~Definir se a lista de status é enum fixo ou configurável~~ — **Resolvido em 22/09/2026**: planilha real mostra dado sujo (`PRONTO`/`Pronto`/`PRONTA`, mais `CANCELADO`/`EXCLUÍDO`/`ENTRADA PARCIAL` soltos) → `status text` livre sem CHECK, com dropdown de sugestões na UI (ver Módulo 1).
- [ ] Confirmar se Cláudio, João, Manoel, Antônio, Leandro, Alexandre e Matheus têm ou vão ganhar login em `usuarios`/Supabase Auth — define se `entregue_por_usuario_id`/`recebido_por_usuario_id` (Produção, handoff) e `created_by`/`responsavel_id` (Garantia) podem ser FK obrigatória com dropdown, ou precisam continuar aceitando texto livre.
- [ ] Definir regra de permissão de escrita em `garantia_itens`/`garantia_protocolos`: qualquer usuário do sistema pode criar/editar qualquer item, ou só quem "responde" pelo fornecedor daquele protocolo (Vitória/Débora)? Não decidido nesta SPEC por ser regra de controle de acesso.
- [ ] Definir a origem confiável de `data_venda_referencia`/`prazo_garantia_anos` em `garantia_itens` quando a venda for anterior à integração Focus NFe (21/09/2026) e não houver `notas_fiscais` correspondente — usar `orcamentos`/`projeto_itens`, a tabela legada `vendas` (import Connect) ou preenchimento manual pela pessoa que abre o item.
- [ ] Definir se `prazo_garantia_anos` por fornecedor deve virar uma tabela de configuração (ex.: `garantia_fornecedor_prazo(fornecedor_id, anos)`) ou continuar como campo manual preenchido item a item — Vinícius deu exemplos (Interlight=5, outros=1 ou 2) mas não definiu uma tabela de prazos por fornecedor.
- [ ] Decidir se cobrança de "adiantamento pendente de devolução" (hoje feita "semanalmente" de forma manual pelo Vinícius) deve virar notificação automática (e-mail/WhatsApp) nesta fase ou permanecer como painel/lista de conferência manual.
- [ ] Decidir se anexos (nota fiscal do fornecedor, fotos da peça com defeito) entram nesta fase do Controle de Garantia — não foram pedidos explicitamente por Vinícius, mas a existência do status "nota fiscal emitida" sugere que pode haver documento a anexar.
- [ ] Confirmar se `garantia_fornecedor_responsavel` (mapeamento fornecedor → Vitória/Débora) deve existir como tabela, ou se é suficiente atribuir `responsavel_id` manualmente a cada protocolo sem um "padrão" pré-configurado.
- [ ] Avaliar, junto do usuário, se `04-Sistemas/controle-de-producao/supabase/AI_DB_CONTEXT.md` e `04-Sistemas/controle-de-garantia/supabase/AI_DB_CONTEXT.md` devem ser criados agora, ou se isso fica para uma SPEC de higienização futura dos dois submodules novos.
- [ ] Decidir se/quando registrar `controle-de-producao` e `controle-de-garantia` na tabela `systems` do Hub (com `papel_permissoes` explícita) para entrarem no SSO/SystemSwitcher como os outros 10 sistemas, ou se ficam com login próprio simples indefinidamente — hoje nenhum dos dois tem checagem de permissão granular, só "está logado ou não".
