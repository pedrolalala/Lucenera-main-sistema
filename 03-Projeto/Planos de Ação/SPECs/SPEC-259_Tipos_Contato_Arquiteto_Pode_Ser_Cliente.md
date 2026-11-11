---
titulo: "SPEC-259 — Tipos de contato: arquiteto pode ser cliente sem perder a identidade"
status: pendente
data_ultima_modificacao: 2026-11-07
sistemas_envolvidos:
  - Banco (Supabase)
  - CRM
  - Orçamentos
  - Showroom
  - Sincronização SharePoint (sharepoint-projetos-pull)
---

# SPEC-259 — Tipos de contato: arquiteto pode ser cliente sem perder a identidade

> **Renumerada em 07/11/2026:** esta SPEC nasceu como SPEC-258, número que o Pedro também usou para o trabalho do Financeiro (pop-up "as parcelas deste pedido já foram pagas?" no Compras). Os nomes já aplicados no banco continuam com `spec258`: pastas das migrations 302/303, histórico do Supabase (`schema_migrations`), tabelas `backup._bkp_spec258_*` e os comentários dos arquivos .sql e da Edge Function `sharepoint-projetos-pull` (v5). Não foram renomeados para não divergir do que está aplicado.

## Checklist de Ação

- [x] Fases 0–1 dos tipos de contato (catálogo `tipos_contato`, `contato_tipos.tipo_id`, `contatos.tipo_principal_id`, `vw_contatos_tipos`) — já estavam aplicadas no banco em 06/11 (backup `backup._bkp_contatos_tipo_20261106` / `_bkp_contato_tipos_20261106`), conferidas nesta SPEC.
- [x] Migration 302: gatilho `sync_contact_type_on_budget` não troca mais o tipo principal; views e funções aceitam "tem o tipo cliente".
- [x] Edge Function `sharepoint-projetos-pull` (versão 5): coluna "Arquiteto" só casa com contato que tem o tipo arquiteto, ativo, não duplicado; lê todos os contatos (não só 1.000); nome ambíguo não casa.
- [x] Migration 303: 23 cadastros duplicados "cliente usado como arquiteto" corrigidos (120 projetos).
- [ ] Grupos B e C (15 cadastros, 161 projetos) — dependem de decisão do usuário (ver Pendências).
- [ ] Fase 4: telas do CRM/Orçamentos lerem `contato_tipos` (arquiteto-cliente aparecer nas duas listas; cadastro com vários tipos).
- [ ] Fase 5: limpeza (gatilhos de sincronização temporários, `contatos.tipo`).

### Passos manuais do usuário

- [ ] Decidir os casos dos grupos B e C (lista em Pendências).

## Objetivo

Um contato tem UM tipo principal (quem ele é: arquiteto, cliente, fornecedor…) e pode ter tipos extras em `contato_tipos`. O papel num negócio vem de onde ele está ligado: quem está em `projetos.cliente_id` / `orcamentos.cliente_id` / nota fiscal é o cliente daquele negócio, mesmo que o cadastro seja de arquiteto.

## Decisões aprovadas (usuário, 06–07/11/2026)

- Se é arquiteto, o tipo principal é arquiteto; comprar não muda isso (ganha "cliente" como tipo extra).
- Ordem: primeiro corrigir as regras (gatilho, sincronização), depois os dados.
- Nenhuma mudança pode parar o que os apps fazem hoje; só acrescentar, com backup e rollback.

## Definição

### Causa 1 — gatilho do orçamento
`sync_contact_type_on_budget` (AFTER INSERT/UPDATE OF cliente_id em `orcamentos`) fazia `UPDATE contatos SET tipo = 'cliente'`: o arquiteto escolhido como cliente deixava de ser arquiteto. Agora só insere 'cliente' em `contato_tipos`.

Para nada deixar de funcionar, o que exigia "tipo principal = cliente" passou a aceitar também "tem o tipo cliente (tipo_id 1)":
`vw_financeiro_projetos`, `vw_projetos_pipeline`, `showroom_emp_buscar_cliente`, `showroom_emp_criar`, permuta em `aprovar_orcamento_financeiro` (fornecedor/cliente = tipo_id 1 ou 5). Só amplia: no dry-run as duas views deram resultado idêntico.

Não muda: RLS `spec069_*` (continua pelo tipo principal); seletores de cliente dos apps (CRM `ProjectNew`, `Clientes`; Orçamentos `BuscaPessoaDialog`, `use-options`) continuam filtrando `contatos.tipo = 'cliente'` até a Fase 4 — um arquiteto-cliente aparece só na lista de Arquitetos.

### Causa 2 — sincronização SharePoint → sistema
`sharepoint-projetos-pull` montava `nome → id` com `select('id, nome')` em TODOS os contatos (sem filtro de tipo; o PostgREST devolve só 1.000 de 4.266) e, com nomes repetidos, ficava com o último lido. Resultado: 281 projetos com `projetos.arquiteto_id` (campo antigo, mantido por compatibilidade) apontando para um cadastro DE CLIENTE com o mesmo nome do arquiteto. A lista oficial (`projeto_arquitetos`) estava certa nos projetos antigos e vazia nos que vieram só do SharePoint.

Correção: só contatos com tipo arquiteto (`contato_tipos.tipo_id = 2`), ativos e `canonical_id` nulo; leitura paginada; nome que bate com mais de um arquiteto não casa (como `aplicar_pull_sharepoint` usa `coalesce`, o projeto mantém o arquiteto atual — nunca apaga).

### Dados (migration 303)
23 pares "cadastro de cliente usado como arquiteto" + "cadastro de arquiteto ativo com o mesmo nome" (grupo A). Em 13 deles uma junção anterior de duplicados tinha escolhido o cadastro de cliente como principal — foi invertida.
- Cadastro de arquiteto = principal; o de cliente vira duplicata (`canonical_id` → arquiteto); 2 cadastros que apontavam para o de cliente passaram a apontar para o de arquiteto.
- 120 projetos: `arquiteto_id` → cadastro de arquiteto; 27 sem lista oficial receberam o arquiteto a 100% (critério da SPEC-077).
- 19 contatos ganharam o tipo extra "cliente" (11 arquitetos cujo duplicado era cliente de projeto/orçamento/negociação/título + 8 arquitetos clientes de orçamento).
- Não move `cliente_id` de projetos/orçamentos, negociações, títulos ou notas (o duplicado continua como "foto").
- Push para o SharePoint desligado só durante a transação (o nome do arquiteto não muda).
- Backup: `backup._bkp_spec258_contatos`, `_projetos`, `_projeto_arquitetos_inseridos`, `_contato_tipos_inseridos`; `rollback.sql` desfaz.

## Realizado

### 2026-11-07

- Migration 302 aplicada após dry-run em ROLLBACK (views idênticas; 867 arquitetos antes e depois; 3 funções ajustadas).
- `sharepoint-projetos-pull` publicada (versão 5; antes era idêntica ao repositório). Simulação: 776 arquitetos no mapa, 0 nomes ambíguos.
- Migration 303 aplicada após dry-run em ROLLBACK: 120 projetos, 27 listas preenchidas, 19 tipos extras, canonical 105 → 115, gatilho de push religado, 0 pushes disparados.

## Pendências

- [ ] Grupo B (SPEC-259) — cadastro "cliente" usado como arquiteto cujo arquiteto com o mesmo código Connect tem outro nome; o usuário precisa dizer se é a mesma pessoa: ANDRE CALIL (~ANDRÉ CALIL DE SALLES), ISABELLA CURY (~ISABELLA COSTA PICCIRILO CURY), CRISTINA SALOMAO (~MARIA CRISTINA SALOMAO), ELOISA BONINI (~ELOISA W REBEY, 105 projetos), ANDREA ESTEVES (~ANDREA ESTEVES PROJETOS LTDA), MG ARQUITETURA (~NA MATA PROJETOS PAISAGÍSTICOS LTDA, 22 projetos), RENATA DEL BIANCO (~CRIS BERMUDEZ PAISAGISMO LTDA).
- [ ] Grupo C (SPEC-259) — cadastro "cliente" único usado como arquiteto, sem cadastro de arquiteto: LUCIANA BERNASCONI, MAURICIO SIQUEIRA, RUBEN RIVITI, VANESSA CHIEREGATO, PAOLA CIMARELLI e PAOLA CIMARELLI LANDGRAF (provável mesma pessoa), JULIA (cliente em 4 projetos, arquiteta em 1 — provável vínculo errado), FILIPPO GIORGI (teste?). Decidir se o tipo principal vira arquiteto.
- [ ] Inconsistência geral (SPEC-259) — além destes, há projetos em que `projetos.arquiteto_id` (campo antigo) é diferente da lista oficial `projeto_arquitetos` (556 antes da correção) e projetos vindos do SharePoint com a lista oficial vazia; o pull só grava o campo antigo. Definir se o pull deve preencher a lista oficial.
- [ ] Fase 4 (SPEC-259) — CRM e Orçamentos: listas e seletores lerem `contato_tipos` (arquiteto-cliente nas duas listas), cadastro com vários tipos, CNPJ obrigatório para escritório de engenharia.
- [ ] Snapshot (SPEC-259) — reextrair `supabase/db/current/` (migrations 302 e 303 e Fases 0–1 ainda não refletidas).
