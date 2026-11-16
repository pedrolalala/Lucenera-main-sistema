---
titulo: "SPEC-308 — Peça única (Ubiqua): estoque unificado, Tabela 2 (preço de revenda) por id da peça e baixa por venda ou por revenda"
status: não iniciado
data_ultima_modificacao: 2026-11-14
sistemas_envolvidos:
  - Banco (produtos, estoque_itens, revenda_ubiqua, orcamento_itens, itens_orcamento_ubiqua, orcamentos_revenda_ubiqua + tabelas novas)
  - Orçamentos (04-Sistemas/gestao-financeira-clone-544cb (1)) — busca de produtos e escolha da tabela de preço
  - Catálogo Ubiqua / site da revenda (04-Sistemas/catalogo-pecas-ubiqua-e6fa0)
  - Cadastro (04-Sistemas/cadastro-lucenera-b86fe) — peça, preço de revenda, vínculo de códigos
  - Peças / Estoque, Movimentação de Peças, Separação Parcial, Compras (Entrada de NF) — só conferência de impacto
  - Importadores da Connect (scripts/importar_nfe_connect.py, importar_reserva_entrega_futura_connect.py, importar_xml_orcamentos_connect.py)
---

# SPEC-308 — Peça única (Ubiqua): estoque unificado, Tabela 2 (preço de revenda) por id da peça e baixa por venda ou por revenda

> Documento de desenho. **Nada foi implementado nem aplicado.** Os números abaixo foram medidos no banco de São Paulo em 14/11/2026 (somente leitura).

## Checklist de Ação

### Fase 0 — Segurança dos dados (antes de qualquer mudança)
- [ ] Backup no schema `backup` (nunca no `public`): `_bkp_spec308_produtos`, `_bkp_spec308_estoque_itens`, `_bkp_spec308_revenda_ubiqua`, `_bkp_spec308_orcamento_itens`, `_bkp_spec308_projeto_itens`, `_bkp_spec308_connect_reserva_ambiente`.
- [ ] Relatório de conflitos (preço de venda e de revenda divergentes entre par MANOELLA × ISLIGHT) entregue ao usuário.

### Fase 1 — Estrutura nova, sem mudar comportamento (migration `…_364_spec308_tabelas_base`)
- [ ] Criar `produto_equivalente` (vínculo código ISLIGHT "-IS" → peça canônica).
- [ ] Criar `produto_preco_revenda` (Tabela 2) + `produto_preco_revenda_historico` + `preco_revenda_visualizadores`.
- [ ] Criar função `pode_ver_preco_revenda()` e `resolver_produto_canonico(uuid)`.
- [ ] Popular `produto_equivalente` (15 pares) e `produto_preco_revenda` (a partir de `revenda_ubiqua.valor_revenda`).

### Fase 2 — Site da Ubiqua passa a ler da fonte única (migration `…_365_spec308_site_ubiqua_fonte_unica`)
- [ ] `revenda_ubiqua.produto_id` (vitrine → peça canônica) e preenchimento.
- [ ] Trocar `ubiqua_estoque_atual()` para casar por `produto_id` (mesma assinatura; o site publicado continua funcionando).
- [ ] `revenda_ubiqua.valor_revenda` vira espelho (trigger a partir da Tabela 2); a Tabela 2 é a fonte.
- [ ] **Corrigir exposição de custo:** `vl_custo_produto`, `vl_custo_indireto`, `vl_custo_total_tabela` deixam de ser legíveis por `authenticated`.
- [ ] RPC `ubiqua_catalogo()` (opcional nesta fase; o site pode migrar depois).

### Fase 3 — Orçamentos (código + migration `…_366_spec308_orcamento_tabela_preco`)
- [ ] `orcamento_itens.tabela_preco` ('venda' | 'revenda').
- [ ] Busca de produtos mostra **uma linha por peça**, com o preço de venda; remover a segunda fonte `revenda_ubiqua` (ProductSearchModal, AsyncProductSelect, ProductSelectButton, use-options).
- [ ] Seletor "Tabela 2" só aparece para quem está em `preco_revenda_visualizadores`.

### Fase 3b — Estoque por empresa em toda peça (migration `…_366b_spec308_estoque_por_empresa`, decisão D2 de 14/11)
- [ ] `estoque_itens.empresa_id` (dono físico do saldo: MANOELLA, ISLIGHT, FOCO) em **todas** as peças, não só as da Ubiqua; chave única passa a `(produto_id, local, empresa_id)`.
- [ ] Preencher as linhas atuais: peça "-IS" → ISLIGHT; demais → empresa da peça (`produtos.empresa_id`).
- [ ] Kardex (`estoque_kardex`) e `movimentacoes_peca` gravam a empresa do saldo movimentado.
- [ ] Revisar as 17 funções de estoque (seção 8.2) para receber/derivar a empresa; `vw_consulta_estoque` mostra total e a divisão por empresa.
- [ ] Decidir D10 (de qual empresa sai a peça numa venda/revenda) antes de escrever esta fase.

### Fase 4 — Unificação da peça, com o estoque separado por empresa (migration de dados `…_367_spec308_unificar_estoque`, ensaio com ROLLBACK antes)
- [ ] Mover quantidade e reservada do código ISLIGHT para o canônico **na linha da empresa ISLIGHT** (kardex registra sozinho); a linha MANOELLA do canônico não é somada com a ISLIGHT.
- [ ] Reapontar `projeto_itens` (2), `orcamento_itens` (4) e `connect_reserva_ambiente` (2) para o canônico.
- [ ] Marcar os códigos "-IS" duplicados como `ativo = false` e `unificado_em`.
- [ ] Conferência antes × depois (somas por família).

### Fase 5 — Pedido de revenda do site mexe no estoque (migration `…_368_spec308_baixa_revenda`)
- [ ] `ubiqua_estoque_movimento` (livro de movimentos da revenda).
- [ ] RPCs `aprovar_orcamento_revenda_ubiqua`, `entregar_orcamento_revenda_ubiqua`, `cancelar_orcamento_revenda_ubiqua`.
- [ ] Ajustar `vw_cadastro_produto_setores` para a reserva de revenda não aparecer como "herança Connect".

### Fase 6 — Limpeza (SPEC futura, só depois de 30 dias estável)
- [ ] Remover do `revenda_ubiqua` as colunas de cópia (`estoque`, `disponivel`, `vl_venda_produto`, `vl_custo_*`).

### Passos manuais do usuário
- [ ] Decidir os pontos da seção "Pendências" (D1 a D9).
- [ ] Informar quem entra em `preco_revenda_visualizadores` (e-mails).
- [ ] Teste real (Carol / Débora / Vinicius) depois de cada fase.
- [ ] Aviso à equipe: na operação paralela com a Connect, a saída de peça "-IS" na Connect continua sendo lançada no código "-IS" lá, e aqui na peça única.

## Objetivo

Hoje a mesma peça Ubiqua existe duas vezes no sistema (código MANOELLA e código ISLIGHT "-IS"), o estoque está espalhado em vários lugares, o preço de revenda mora numa cópia de planilha (`revenda_ubiqua`) e a busca do Orçamento mostra a peça em duas linhas. O resultado é o que a Carol relatou: peça duplicada, estoque só numa das linhas e preços diferentes na tela.

Resultado esperado:

1. **Uma peça só** no nosso sistema, com o **valor de venda nosso** valendo para tudo, exceto para o site da Ubiqua revenda.
2. **Uma peça, estoque identificado por empresa**: cada peça tem um cadastro só e o saldo é separado por empresa dona (Manoella × Islight × Foco). Isso vale como **padrão para todas as peças**, e todos os sistemas (inclusive o site da Ubiqua) leem o mesmo dado.
3. **Tabela 2**: tabela nova, ligada ao id da peça, com o **preço de revenda**, no Supabase e ligada ao nosso sistema.
4. **Saída por venda ou por revenda**: o estoque muda e registra (kardex + auditoria), nos dois caminhos.

## Origem

- Central de Solicitações, Carol, 13/11/2026 19:30, "PRODUTOS DUPLICADOS - PREÇOS REVENDA" (id `2a6ac3af-d5bd-484f-b437-6b55b850e4f0`), com 2 prints da busca "Buscar Produtos" (refs 332131-IS e 189302).
- Orientação do usuário em 14/11/2026: o valor de revenda serve para o site da Ubiqua revenda; no nosso sistema o valor de venda vale para tudo, menos para o site; o estoque está em vários lugares e precisa ser unificado com o valor de venda nosso; criar tabela com o vínculo do id da peça para o preço de revenda; saindo peça por venda ou por revenda, o estoque muda e registra.

## Decisões aprovadas

- Valor de venda nosso (`produtos.preco_venda`) vale para todo o sistema; o preço de revenda só vale no site da Ubiqua revenda e na Tabela 2.
- Peça unificada em um cadastro; **o estoque continua dividido por empresa (Manoella × Islight) e isso se torna padrão de todas as peças** (decisão do usuário, 14/11/2026, D2). Preço de revenda em tabela nova ligada pelo id da peça.
- Toda saída (venda ou revenda) muda o estoque e registra.

## 1. Estado atual (medido em 14/11/2026)

### 1.1 Onde cada dado vive hoje

| Dado | Onde está | Observação |
|---|---|---|
| Código e preço de venda | `produtos` | Cada peça Ubiqua tem até 2 códigos: base (empresa MANOELLA, ref. `189302`) e ISLIGHT (ref. `189302-IS`). 99 produtos da marca UBIQUA, 40 deles "-IS". |
| Estoque físico | `estoque_itens` | Todo o saldo do sistema está no local `Estoque` (1.674 linhas). UBIQUA: 152 un. nos códigos base (28 linhas) e **418 un. nos códigos "-IS"** (31 linhas). |
| Preço de revenda | `revenda_ubiqua.valor_revenda` | Cópia de planilha com 87 linhas (50 MANOELLA + 37 ISLIGHT). |
| Cópia do preço de venda | `revenda_ubiqua.vl_venda_produto` | 63 linhas preenchidas. |
| Cópia do estoque | `revenda_ubiqua.estoque` / `disponivel` | Parada em junho. A busca do Orçamento ainda lê essa cópia. |
| Estoque que o site mostra | RPC `ubiqua_estoque_atual()` | Casa `revenda_ubiqua` com `produtos` pela **referência** (upper/trim) e devolve `estoque_disponivel`. O site (SPEC-171) soma Manoella + "-IS" e divide a quantidade entre as duas (`origem-peca.ts`). |
| Pedido do site | `orcamentos_revenda_ubiqua` + `itens_orcamento_ubiqua` | `itens_orcamento_ubiqua.produto_id` aponta para `revenda_ubiqua.id` (não para `produtos`). 1 pedido, em rascunho. **Nenhum status mexe em estoque.** O admin aprova direto pelo front (`status='aprovado'`). |

### 1.2 Causa da tela da Carol

O modal "Buscar Produtos" do Orçamento junta duas fontes: `produtos` (RPC `buscar_produtos_fuzzy`) **e** `revenda_ubiqua` (consulta direta). A linha "REVENDA" do print é a segunda fonte: marca vazia, `preco_venda = valor_revenda`, estoque `estoque/disponivel` da cópia antiga. Ao escolher essa linha, `vincularUbiquaAoCadastro` (BudgetFormPage) liga ao produto pelo `codigo_produto` e mantém o preço de revenda na linha. Ou seja, "vender pela revenda" já existe no Orçamento, mas por um atalho: o preço de revenda entra como preço de venda e a linha escolhida aponta para o código "-IS".

### 1.3 Pares MANOELLA × ISLIGHT

- 40 códigos "-IS": **15 têm par** base; **25 não têm** (acessórios como `T.CB.CR-IS`, `…-V2-IS`).
- Estoque só no "-IS": 28 casos (inclui os que não têm par). Só na base: 1. Nos dois: 2.
- Preço de venda diferente entre os dois do par: **1** (332109: R$ 1.504,50 × R$ 1.282,31).
- Preço de revenda diferente: 332109 (R$ 734,27 × R$ 624,91) e 321403/321404 (R$ 434,36 × R$ 434,35, 1 centavo).
- Pares em que só o "-IS" aparece na planilha de revenda: 189204 (R$ 517,09).

### 1.4 Quem aponta para os códigos "-IS" hoje

| Tabela | Linhas |
|---|---|
| `estoque_itens` | 61 |
| `estoque_kardex` | 72 (histórico, não muda) |
| `notas_fiscais_connect_itens` | 46 (histórico, não muda) |
| `produto_fornecedores` | 40 |
| `orcamento_itens` | 4 |
| `projeto_itens` | 2 |
| `connect_reserva_ambiente` | 2 |
| `movimentacoes_peca` | 1 (histórico) |

### 1.5 Achados colaterais

- **Custo exposto:** `revenda_ubiqua` tem política `SELECT … USING (true)` para `authenticated` e traz `vl_custo_produto`, `vl_custo_indireto`, `vl_custo_total_tabela` em 59 linhas. Qualquer conta logada (inclusive os 5 revendedores e contas públicas do Catálogo Ubiqua) lê o custo. Isso contraria a SPEC-193 (custo só para a lista de Administração) e a regra 11 do AGENTS.md.
- A política `revenda_ubiqua_select_anon` existe, mas `anon` não tem GRANT de SELECT na tabela hoje (inofensiva, mas deve ser removida para não virar risco).
- 17 funções mexem em `estoque_itens` (ver 8.2). Todas usam o local `Estoque`; por isso a unificação no mesmo local não exige mudar nenhuma delas.

### 1.6 Regras vigentes que esta SPEC respeita

- SPEC-232: toda função que mexe em `quantidade_reservada` mexe também nos saldos dos L; herança = reservado − (Reserva + Entrega Futura + Separação dos L).
- SPEC-244: operação paralela com a Connect; a equipe lança nos dois sistemas; não rodar importador de estoque.
- SPEC-193: custo só pela lista de Administração; coluna nova em `produtos` exige `GRANT SELECT (coluna)`.
- Segurança (AGENTS.md): RLS em toda tabela nova, `REVOKE ALL … FROM anon`, nunca `USING (true)` em dado sensível, função nova `REVOKE ALL … FROM PUBLIC, anon`, trava de papel com `IS DISTINCT FROM`.
- Feedback "Connect é herança": nenhuma importação da Connect muda quantidade; a unificação aqui é uma operação **nossa**, com conferência antes × depois.

## 2. Modelo novo (visão geral)

```
                          produtos  (peça CANÔNICA = código com o valor de venda nosso)
                          ├─ preco_venda ............ vale para TODO o sistema
                          └─ estoque_itens (local 'Estoque', empresa_id) ... UMA linha por peça × empresa
                             (Manoella | Islight | Foco): quantidade / reservada
                                  │ kardex_estoque_itens + auditoria_registrar (já existem)
        ┌─────────────────────────┼───────────────────────────────┐
        │                         │                               │
produto_equivalente      produto_preco_revenda  (TABELA 2)   ubiqua_estoque_movimento
(código ISLIGHT "-IS"    produto_id  PK/FK → produtos        (reserva / baixa / liberação
 → canônico)             valor_revenda                        do pedido de revenda)
 equivalente_id UNIQUE   + histórico + quem vê                       ▲
        │                         │                                   │
        ▼                         ▼                                   │
 importadores Connect     revenda_ubiqua  (vitrine do site: foto, cor, ordem)
 resolvem "-IS" → canônico   + produto_id FK → produtos        itens_orcamento_ubiqua
                             valor_revenda = ESPELHO da Tabela 2   + produto_sistema_id
                                                                  
orcamento_itens.tabela_preco = 'venda' | 'revenda'   (Orçamento Lucenera; Tabela 2 só para a lista autorizada)
```

Princípios:

1. **Canônica = código MANOELLA (sem "-IS")** quando existir. Os 25 "-IS" sem par ficam como são (não há duplicata para esconder).
2. **Estoque no canônico, separado por empresa.** O saldo que hoje está no "-IS" passa para o canônico **na linha da empresa ISLIGHT**; o saldo MANOELLA fica na linha MANOELLA. O código "-IS" fica inativo, mas **continua cadastrado e vinculado** (a Connect ainda usa esse código). A divisão por empresa é regra de **todas** as peças (não só Ubiqua).
3. **Preço de revenda nunca fica em `produtos`.** Vive em tabela própria, com histórico e acesso restrito.
4. **Todo movimento passa por `estoque_itens`**, que já dispara o kardex e a auditoria. Nada de saldo paralelo.

## 3. Tabelas (estrutura detalhada)

### 3.1 `produto_equivalente` (novo)

Liga o código ISLIGHT ao código canônico.

| Coluna | Tipo | Regra |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `produto_id` | uuid NOT NULL | FK `produtos(id)` ON DELETE RESTRICT — a peça **canônica** |
| `equivalente_produto_id` | uuid NOT NULL **UNIQUE** | FK `produtos(id)` ON DELETE RESTRICT — o código "-IS" |
| `empresa_origem_id` | uuid | FK `empresas(id)` — ISLIGHT |
| `motivo` | text | "Código ISLIGHT da Connect (SPEC-308)" |
| `unificado_em` | timestamptz | preenchido na Fase 4 quando o saldo foi movido |
| `criado_em` / `criado_por` | timestamptz / uuid | |

Regras: `CHECK (produto_id <> equivalente_produto_id)`; trigger impede cadeia (um equivalente não pode ser canônico de outro, nem o canônico ser equivalente). RLS: leitura para quem tem `pode_acessar_sistema('cadastro')`, `'orcamentos'`, `'necessidade-de-compra'` ou `'movimentacao-pecas'` (dentro de `(SELECT …)`); escrita só `service_role`/admin. `REVOKE ALL … FROM anon`.

### 3.2 `produto_preco_revenda` — a "Tabela 2" (novo)

| Coluna | Tipo | Regra |
|---|---|---|
| `produto_id` | uuid **PK** | FK `produtos(id)` ON DELETE RESTRICT — sempre a peça **canônica** (uma linha por peça) |
| `valor_revenda` | numeric(12,2) NOT NULL | `CHECK (valor_revenda >= 0)` |
| `vigente_desde` | date NOT NULL | padrão `current_date` |
| `observacao` | text | |
| `criado_em` / `criado_por` | timestamptz / uuid | |
| `atualizado_em` / `atualizado_por` | timestamptz / uuid | trigger |

`produto_preco_revenda_historico`: `id bigserial`, `produto_id`, `valor_anterior`, `valor_novo`, `alterado_em`, `alterado_por`, `origem` ('planilha', 'tela', 'carga SPEC-308'), gravado por trigger em INSERT/UPDATE/DELETE.

`preco_revenda_visualizadores`: `email text PK`, `nome`, `observacao`, `created_at` — mesmo desenho de `produto_custo_visualizadores` (SPEC-193).

Função `pode_ver_preco_revenda()` (`STABLE SECURITY DEFINER`, `search_path public`): mesma lógica de `pode_ver_custo_produto()` (service_role e contexto interno liberados; usuário só se o e-mail estiver na lista e `usuarios.ativo`). `REVOKE ALL … FROM PUBLIC, anon`.

RLS de `produto_preco_revenda`: `SELECT` e `UPDATE/INSERT` somente `USING ((SELECT public.pode_ver_preco_revenda()))`. Nenhum acesso `anon`. O site da Ubiqua **não lê esta tabela direto**: recebe o preço pela RPC/espelho (3.3).

Carga inicial: uma linha por peça canônica a partir de `revenda_ubiqua.valor_revenda`, resolvendo cada linha da vitrine para o canônico por `cod_produto`, depois referência, depois vínculo. Conflito entre MANOELLA × ISLIGHT: vale o valor da linha **canônica** (MANOELLA); a lista de conflitos vai no relatório da Fase 0.

### 3.3 `revenda_ubiqua` — passa a ser só a vitrine do site (alterada)

- **Nova coluna** `produto_id uuid NULL` → `produtos(id)` ON DELETE RESTRICT, preenchida por `cod_produto`, depois referência, depois `produto_equivalente`. Das 87 linhas, 10 não casam com nenhum produto (continuam como "peça sob encomenda", sem estoque, e entram na lista de pendências).
- **Continua guardando** só apresentação: `descricao`, `cor`, `imagem_catalogo_url`, `ordem`, `slug`, `empresa_id`.
- **Deixam de ser fonte** (viram cópia/espelho, depois removidas na Fase 6): `estoque`, `disponivel` (substituídos pelo estoque do canônico), `valor_revenda` (espelho da Tabela 2 por trigger, para o site publicado continuar funcionando sem deploy), `vl_venda_produto` (preço de venda sugerido, passa a vir de `produtos.preco_venda`), `vl_custo_produto`, `vl_custo_indireto`, `vl_custo_total_tabela`.
- **Segurança:** `REVOKE SELECT (vl_custo_produto, vl_custo_indireto, vl_custo_total_tabela) ON revenda_ubiqua FROM authenticated` (Fase 2); remover a política `revenda_ubiqua_select_anon`; revisar a política `revenda_ubiqua_insert` (sem `WITH CHECK` visível na listagem).

### 3.4 `orcamento_itens` (alterada)

`tabela_preco text NOT NULL DEFAULT 'venda' CHECK (tabela_preco IN ('venda','revenda'))`.

- A linha **sempre** aponta para a peça canônica (`produto_id`), então reserva, separação, entrega e devolução continuam funcionando sem mudar nenhuma função.
- `preco_unitario` continua sendo o valor da linha; `tabela_preco` registra de onde ele veio (para relatórios de margem e para a Carol ver "Tabela 2" no PDF interno, se quiserem).
- A trava de edição de valor só para Administração (SPEC-108) continua valendo.
- Grant de coluna: conferir `GRANT SELECT/INSERT/UPDATE (tabela_preco)` para os papéis que já gravam `preco_unitario`.

### 3.5 Pedido de revenda do site (alteradas)

`itens_orcamento_ubiqua`:
- `produto_sistema_id uuid NULL` → `produtos(id)`: peça canônica da linha, preenchida por trigger a partir de `revenda_ubiqua.produto_id`. O FK atual `produto_id → revenda_ubiqua(id)` não muda (o site continua usando).

`orcamentos_revenda_ubiqua`:
- `entregue_em timestamptz`, `entregue_por uuid` (novo estado "entregue"); `status` ganha o valor `entregue`.

### 3.6 `ubiqua_estoque_movimento` (novo)

Livro de movimentos do pedido de revenda (faz o papel que o "L" faz na venda; ver SPEC-232).

| Coluna | Tipo |
|---|---|
| `id` | bigserial PK |
| `item_orcamento_ubiqua_id` | uuid NOT NULL FK `itens_orcamento_ubiqua(id)` |
| `produto_id` | uuid NOT NULL FK `produtos(id)` (canônico) |
| `empresa_id` | uuid NOT NULL FK `empresas(id)` (empresa de onde o saldo foi reservado/baixado, D10) |
| `tipo` | text CHECK (`reserva`, `baixa`, `liberacao`) |
| `quantidade` | numeric(12,3) CHECK > 0 |
| `criado_em` / `criado_por` | timestamptz / uuid |

Saldo ativo da reserva de revenda por peça = Σ(`reserva`) − Σ(`baixa`) − Σ(`liberacao`). RLS: leitura por `pode_acessar_sistema('ubiqua')` ou `'movimentacao-pecas'`; escrita só pelas RPCs.

### 3.7 `estoque_itens.empresa_id` — estoque por empresa em toda peça (alterada, decisão D2)

| Item | Regra |
|---|---|
| Coluna | `empresa_id uuid NOT NULL` → `empresas(id)` ON DELETE RESTRICT. Padrão provisório = `produtos.empresa_id` durante a migração; depois sem DEFAULT (toda função informa a empresa). |
| Chave | `UNIQUE (produto_id, local, empresa_id)` no lugar de `(produto_id, local)`. Conferir antes qual constraint/índice existe hoje. |
| Carga | Linhas de peça "-IS" → empresa ISLIGHT; demais → empresa do cadastro da peça. Conferência: Σ `quantidade` e Σ `quantidade_reservada` iguais antes e depois. |
| Kardex | `estoque_kardex` e `movimentacoes_peca` ganham `empresa_id` (o trigger `trg_kardex_estoque_itens` copia da linha). Histórico antigo recebe a empresa pelo código da peça. |
| Consulta | `vw_consulta_estoque` mantém as colunas de hoje (total) e ganha `estoque_manoella`, `estoque_islight`, `estoque_foco`; o disponível da peça = soma das empresas − max(reservas, herança), como hoje. Disponível **por empresa** só para quem precisa escolher de onde sai. |
| Reservas / L | Reserva e saldos dos L (`estoque_saldos_projeto_item`) passam a registrar a empresa de onde a peça foi reservada. A regra da SPEC-232 (herança = reservado − Reserva − EF − Separação) vale por empresa. |
| Permissão | Mesmas políticas de `estoque_itens`; coluna nova com `GRANT SELECT/INSERT/UPDATE (empresa_id)` aos mesmos papéis. RLS e `REVOKE … anon` mantidos. |

Regra de negócio a decidir (D10): **de qual empresa sai a peça** numa venda, entrega ou pedido de revenda. Proposta: a empresa do orçamento/pedido; se faltar saldo nela, a tela mostra o saldo da outra empresa e pede escolha explícita (sem baixa automática entre empresas). Entrada de NF entra na empresa do pedido de compra.

## 4. Views e funções

| Objeto | Mudança |
|---|---|
| `ubiqua_estoque_atual()` | Mantém a assinatura `(referencia text, disponivel integer)`; passa a juntar por `revenda_ubiqua.produto_id` e devolve o disponível do **canônico** (soma das empresas), descontando a reserva de revenda. Como o estoque agora é identificado por empresa, `ubiqua_catalogo()` devolve também o disponível por empresa e o site deixa de "dividir" quantidade por regra de sufixo (`origem-peca.ts`). |
| `vw_consulta_estoque` | Sem mudança de fórmula. Os códigos "-IS" duplicados saem das listas por `ativo = false`. |
| `vw_cadastro_produto_setores` | A "Reserva sem venda (herança Connect)" passa a descontar a reserva de revenda ativa: herança = `quantidade_reservada` − (Reserva + EF + Separação dos L) − reserva de revenda. |
| `buscar_produtos_fuzzy` | Sem mudança (já não devolve inativos); conferir. |
| `resolver_produto_canonico(uuid)` | Devolve o canônico de um id (ele mesmo, ou o `produto_id` do vínculo). Usada por importadores e RPCs. |
| `preco_revenda_produto(uuid)` | `SECURITY DEFINER`, exige `pode_ver_preco_revenda()`; devolve o valor da Tabela 2. Usada pelo Orçamento. |
| `ubiqua_catalogo()` (opcional) | `SECURITY DEFINER`, só para `usuarios_ubiqua`/admin: vitrine + disponível do canônico + valor de revenda + preço de venda sugerido. |
| `aprovar_orcamento_revenda_ubiqua(uuid)` | Ver 5.3. |
| `entregar_orcamento_revenda_ubiqua(uuid)` | Ver 5.3. |
| `cancelar_orcamento_revenda_ubiqua(uuid, text)` | Ver 5.3. |

Toda função nova: `SECURITY DEFINER`, `SET search_path TO 'public'`, `REVOKE ALL … FROM PUBLIC, anon`, `GRANT EXECUTE … TO authenticated`, trava de papel com `IS DISTINCT FROM`.

## 5. Fluxos

### 5.1 Venda Lucenera pela Tabela "Venda" (sem mudança)
Orçamento → aprovação financeira → reserva → separação → entrega. O que muda: a peça só aparece uma vez na busca e o estoque mostrado é o único.

### 5.2 Venda Lucenera pela Tabela 2 (revenda)
1. Quem está em `preco_revenda_visualizadores` vê, na linha do orçamento, o seletor de tabela (Venda | Tabela 2). Os demais **não veem** o seletor nem o valor.
2. Ao escolher Tabela 2, a tela chama `preco_revenda_produto(produto_id)` e grava `preco_unitario` com esse valor e `tabela_preco = 'revenda'`.
3. Daí em diante é a mesma venda: aprovação reserva, entrega baixa e registra, devolução volta. Nada muda em `aprovar_orcamento_financeiro`, separação ou devolução.

### 5.3 Pedido do site da Ubiqua (novo efeito em estoque)
1. Representante monta o pedido no site (preço = Tabela 2, via espelho/RPC) → `rascunho`/`enviado` **sem efeito em estoque**.
2. **Aprovação** (`aprovar_orcamento_revenda_ubiqua`): para cada item com `produto_sistema_id` — trava `estoque_itens(produto,'Estoque', empresa)` (empresa conforme D10), confere o disponível (itens com `sem_estoque_no_pedido = true` continuam indo para a necessidade de importação, sem reservar), soma `quantidade_reservada` e grava `ubiqua_estoque_movimento (reserva)`. O kardex e a auditoria registram sozinhos pelo trigger de `estoque_itens`.
3. **Entrega** (`entregar_orcamento_revenda_ubiqua`): `quantidade −= q` e `quantidade_reservada −= q`, movimento `baixa`, `status = 'entregue'`.
4. **Cancelamento/rejeição depois de aprovado**: `quantidade_reservada −= q` e movimento `liberacao`.
5. Quem pode: aprovar/cancelar = admin da Ubiqua; entregar = Logística/Movimentação de Peças. Papéis exatos na pendência D5.

### 5.4 Compra e entrada de NF
A Entrada de NF e o recebimento de compra já escrevem em `estoque_itens` da peça do pedido. Depois da unificação, pedidos novos usam sempre o canônico. Pedidos antigos do código "-IS" (nenhum aberto hoje: `pedido_compra_itens` não tem linha "-IS") seriam resolvidos por `resolver_produto_canonico`.

### 5.5 Devolução
Devolução de venda ou de revenda volta para o estoque do canônico (mesma regra de hoje, agora com um só saldo).

### 5.6 Conferência com a Connect (operação paralela)
A Connect continua com dois códigos. Para a conferência diária ficar possível, criar a view `vw_estoque_unificado_vs_connect`: soma, por família, o saldo da Connect (planilha) dos dois códigos e compara com o saldo do canônico. Importadores que recebem código "-IS" (NF, reserva/EF, XML) resolvem para o canônico antes de gravar (`resolver_produto_canonico`).

## 6. Permissões

| Objeto | Quem lê | Quem grava |
|---|---|---|
| `produto_preco_revenda` + histórico | lista `preco_revenda_visualizadores` (e `service_role`) | mesma lista (decisão D4) |
| `produto_equivalente` | quem acessa Cadastro, Orçamentos, Compras, Movimentação | `service_role`/admin |
| `ubiqua_estoque_movimento` | `ubiqua`, `movimentacao-pecas` | só as RPCs |
| `revenda_ubiqua` (vitrine) | `authenticated` (sem as colunas de custo) | admin da Ubiqua |
| Preço de revenda no site | o revendedor logado, **só** pela RPC/espelho (nunca pela tabela Tabela 2) | — |
| `anon` | nada | nada |

Teste obrigatório depois de mexer em permissão: como `anon`, como revendedor, como usuário sem o sistema (ex.: auxiliar de estoque) e como Vinicius, todos em ROLLBACK.

## 7. Migração de dados (ordem, conferência e rollback)

Regra de ouro: **cada fase com dry-run terminado em ROLLBACK**, aplicada só depois de conferida, e com `rollback.sql` próprio. Nada de `COMMIT` dentro do arquivo de dry-run.

**Fase 0 — backup e relatório.** `CREATE TABLE backup._bkp_spec308_* AS SELECT …` das 6 tabelas listadas. Relatório: (a) 15 pares e 25 sem par; (b) conflitos de preço; (c) 10 linhas da vitrine sem produto; (d) pares do tipo `339203-IS` × `339203-V2-IS`.

**Fase 1.** Cria as tabelas e funções; popula `produto_equivalente` (15 pares) e `produto_preco_revenda`. Sem mudança de comportamento. Rollback: `DROP` das tabelas novas.

**Fase 2.** Cria `revenda_ubiqua.produto_id` e preenche; troca `ubiqua_estoque_atual()`; cria o espelho do preço; fecha a exposição de custo. Conferência: o catálogo do site mostra os mesmos números que `vw_consulta_estoque` do canônico; o preço mostrado no site continua igual ao de hoje. Rollback: devolve a função e as colunas.

**Fase 3.** Código do Orçamento + `orcamento_itens.tabela_preco`. Conferência: a busca mostra uma linha por peça; escolher Tabela 2 grava `tabela_preco = 'revenda'`.

**Fase 3b — estoque por empresa (antes da Fase 4).** Adiciona `empresa_id`, troca a chave única, preenche, ajusta kardex, view e as 17 funções. Conferência: Σ por peça igual à de antes; cada função de estoque testada em ROLLBACK (aprovar, cancelar, devolver, entrada de NF, movimentação) mostrando a empresa no kardex. Rollback: remover a coluna e voltar a chave única (só seguro enquanto nenhuma peça tiver duas linhas por empresa; senão restaurar do backup).

**Fase 4 — unificação da peça, estoque separado por empresa (a mais delicada).**
- Fotografia antes: por família (canônico + equivalente): Σ `quantidade`, Σ `quantidade_reservada` **por empresa**, saldos por L (`estoque_saldos_projeto_item`), `disponível` de `vw_consulta_estoque`.
- Para cada par, numa transação por par: `UPDATE`/`INSERT` em `estoque_itens` do canônico **na empresa ISLIGHT** com `quantidade` e `quantidade_reservada` do equivalente (a linha MANOELLA não muda); zera o do equivalente; `INSERT movimentacoes_peca` (tipo de unificação, motivo "SPEC-308", origem = código "-IS", destino = canônico); reaponta `projeto_itens`, `orcamento_itens` e `connect_reserva_ambiente`; marca o equivalente `ativo = false` e `produto_equivalente.unificado_em = now()`.
- Depois: Σ quantidade e Σ reservada da família **iguais** às de antes; saldos por L **iguais**; se qualquer soma divergir, a transação do par desfaz.
- `produto_fornecedores` (40 linhas dos "-IS") e `notas_fiscais_connect_itens` (46) **não** são alterados; ficam como histórico.
- Exceção consciente à regra "Connect é herança": aqui a quantidade muda por consolidação interna (soma exata), não por importação.
- Rollback: restaurar de `backup._bkp_spec308_*` os saldos e vínculos das famílias unificadas, reativar os códigos "-IS" e limpar `unificado_em`.

**Fase 5.** Cria o livro de movimentos e as 3 RPCs; ajusta `vw_cadastro_produto_setores`. Conferência: aprovar/entregar/cancelar um pedido de teste em ROLLBACK mostra o kardex, o `ubiqua_estoque_movimento` e o disponível mudando exatamente a quantidade do pedido; a "herança" da peça **não** muda.

**Fase 6.** Em SPEC própria, só depois de 30 dias estável.

## 8. Impacto

### 8.1 Por sistema

| Sistema | Mudança |
|---|---|
| Orçamentos | Remove a fonte `revenda_ubiqua` da busca (4 arquivos: `ProductSearchModal`, `AsyncProductSelect`, `ProductSelectButton`, `use-options`); `vincularUbiquaAoCadastro` deixa de ser necessário; seletor de Tabela 2 por permissão; gravar `tabela_preco`. |
| Catálogo Ubiqua | Fase 2 não exige deploy (RPC e espelho mantêm o contrato). Depois: ler `ubiqua_catalogo()` e deixar de dividir quantidade entre "Manoella" e "Islight" (`origem-peca.ts`). |
| Cadastro | Tela de peça mostra o preço de revenda (só para a lista) e o vínculo de código; `AI_DB_CONTEXT.md` atualizado. |
| Peças / Estoque | Mostra a reserva de revenda numa linha própria; "herança" ajustada. |
| Movimentação de Peças | Sem mudança de função; o movimento de unificação aparece no histórico. |
| Compras | Sem mudança; pedidos novos usam o canônico. |
| Importadores Connect | `importar_nfe_connect`, `importar_reserva_entrega_futura_connect` e `importar_xml_orcamentos_connect` resolvem "-IS" → canônico. |

### 8.2 Funções que mexem em `estoque_itens` (17) — **todas precisam ser revisadas** (D2: estoque por empresa em toda peça)
Cada uma passa a receber/derivar a `empresa_id` do saldo (D10) em vez de assumir uma linha por peça+local. Fase própria (3b), com teste por função em ROLLBACK. Lista:
`_aprovar_operacao_sem_financeiro`, `aprovar_orcamento_financeiro`, `cancelar_entrada_nota_compra`, `cancelar_orcamento`, `confirmar_recebimento_devolucao`, `desfazer_aprovacao_financeira`, `fn_sync_estoque_itens_from_produtos`, `movimentar_peca_setor`, `movimentar_peca_venda`, `registrar_devolucao_projeto_item_setor`, `registrar_devolucao_projeto_item`, `registrar_entrada_nota_compra`, `registrar_recebimento_compra`, `sync_entregue_ao_finalizar_entrega`, `sync_entregue_ao_finalizar_separacao`, `tratar_heranca_connect`, `trigger_fechar_projeto`. Alternativa descartada: usar os locais `Estoque Islight` / `Estoque Luce Nera` (existem no enum e já entram no total de `vw_consulta_estoque`) em vez da coluna `empresa_id`; mistura "onde está" com "de quem é" e quebra os filtros que assumem local `Estoque`. A coluna `empresa_id` mantém o local como está.

### 8.3 Análise de ecossistema (obrigatória)
- Depende de `produtos`, `orcamentos`/`orcamento_itens`, `projeto_itens`, `usuarios`, `systems`/acesso a sistemas. Não toca em `boletos`, `projeto_parcelas` nem no Financeiro.
- Afeta Orçamentos, Estoque/Compras, Cadastro e Logística (entrega do pedido de revenda). Não afeta CRM, RH nem o Financeiro.
- Dado duplicado a derivar por relacionamento: o saldo "-IS" (passa a derivar do canônico) e a cópia `revenda_ubiqua.estoque/disponivel`.
- Migrations antigas em sistema que contradizem o snapshot: conferir `catalogo-pecas-ubiqua-e6fa0/supabase/migrations` (publicar no Skip re-executa migrations legadas; ver memória "Publicar no Skip EXECUTA migrations legadas").
- Atualizar `AI_DB_CONTEXT.md` do Cadastro, Orçamentos e Catálogo Ubiqua, `supabase/docs/relationships.md` e o domínio `estoque_compras.md`.

## 9. Critérios de aceite

1. A busca de produtos do Orçamento mostra **uma linha por peça Ubiqua**, com o preço de venda e o estoque único (caso da Carol: refs 332131 e 189302).
2. O estoque do canônico, **por empresa**, é igual ao que cada código tinha antes (saldo "-IS" na linha ISLIGHT; saldo base na linha MANOELLA; peças 12521+13014, 12522+13013, etc.), a soma da família não muda e o saldo por L não muda. Toda peça do sistema mostra o estoque identificado por empresa.
3. A Tabela 2 guarda um preço por peça canônica, com histórico; só quem está em `preco_revenda_visualizadores` lê e grava.
4. O site da Ubiqua mostra os mesmos preços de revenda de hoje e o estoque correto, sem republicar o site (Fase 2).
5. Revendedor logado **não** consegue ler custo em `revenda_ubiqua` (teste como revendedor e como conta pública).
6. Orçamento Lucenera na Tabela 2 grava `tabela_preco = 'revenda'` e baixa/reserva/devolve estoque como uma venda normal.
7. Pedido da Ubiqua: aprovar reserva, entregar baixa, cancelar libera; cada passo aparece no kardex, na auditoria e em `ubiqua_estoque_movimento`, com a quantidade exata.
8. A "Reserva sem venda (herança Connect)" das peças Ubiqua não muda quando um pedido de revenda é aprovado.
9. Dry-run de cada migration termina em ROLLBACK e o backup do schema `backup` existe antes da Fase 4.

## 10. Testes obrigatórios

- Antes × depois por família (somas e L) com a lista completa dos 15 pares.
- RLS: `anon`, revendedor, conta pública, usuário sem sistema, Vinicius (todos em ROLLBACK).
- Pedido de revenda de teste (aprovar → entregar → cancelar) em transação com ROLLBACK.
- Orçamento de teste com linha em cada tabela, aprovar e conferir kardex.
- Importador Connect com código "-IS" resolve para o canônico (dry-run).
- Catálogo do site (build + página em produção) antes e depois da Fase 2.

## 11. Riscos

- **Parcialmente irreversível na prática:** depois que a equipe lança movimentos no canônico, desfazer a Fase 4 exige restaurar o backup e reaplicar os movimentos feitos depois. Por isso a janela entre a Fase 4 e a estabilidade deve ser curta e combinada com a equipe.
- A Connect continua com dois códigos; sem a view de conferência e a regra de lançamento nos dois sistemas, as contagens vão divergir.
- Publicar o Catálogo Ubiqua no Skip pode redeployar Edge Functions e re-executar migrations legadas (já aconteceu); validar antes.
- `ubiqua_estoque_atual()` hoje devolve 0 para referência sem produto; manter esse comportamento para as 10 linhas sem produto.

## Realizado

Nada executado. SPEC escrita em 14/11/2026 a partir de leitura do banco e do código.

## Pendências

- [ ] **D1 — Peça canônica:** confirmar que o canônico é o código MANOELLA (sem "-IS") e que os 25 códigos "-IS" sem par continuam como estão. Recomendação: sim.
- [x] **D2 — Estoque por empresa: DECIDIDO (14/11, usuário):** o estoque **continua dividido** entre Manoella e Islight e a identificação da empresa será **padrão para todas as peças**. Implementação: coluna `estoque_itens.empresa_id` (seção 3.7), revisão das 17 funções (Fase 3b).
- [ ] **D10 — De qual empresa sai a peça:** na venda, entrega e pedido de revenda, baixa da empresa do orçamento/pedido? Se faltar saldo nela, pode usar a outra empresa (com escolha explícita) ou fica bloqueado? Entrada de NF entra na empresa do pedido de compra? Recomendação: empresa do documento, sem baixa automática entre empresas.
- [ ] **D11 — Peças que não são Ubiqua:** a divisão por empresa passa a valer para todas já nesta SPEC; a carga inicial usa `produtos.empresa_id` (peça sem empresa → Manoella?). Confirmar a empresa padrão. As empresas do estoque são **MANOELLA, ISLIGHT e FOCO**; "LUCE NERA" nas planilhas da Connect é o nome da MANOELLA, não uma quarta empresa.
- [ ] **D3 — Conflitos de preço:** definir o valor correto de 332109 (venda R$ 1.504,50 × R$ 1.282,31; revenda R$ 734,27 × R$ 624,91) e dos centavos de 321403/321404. Recomendação: valer o do código MANOELLA.
- [ ] **D4 — Quem vê e edita a Tabela 2:** só o Vinicius (usuário admin `Vinicius`) ou uma lista de e-mails? Quem pode escolher "Tabela 2" no Orçamento? Recomendação: a mesma lista, em `preco_revenda_visualizadores`.
- [ ] **D5 — Pedido do site:** reservar na aprovação e baixar na entrega, igual à venda? Quem marca "entregue" (Logística, Movimentação de Peças ou admin da Ubiqua)? Quem aprova hoje é o admin do site.
- [ ] **D6 — Travamento de valor:** a linha em Tabela 2 segue a trava de edição só para Administração (SPEC-108)? Recomendação: sim.
- [ ] **D7 — Custo exposto:** fechar já (Fase 2) a leitura das colunas de custo de `revenda_ubiqua` por qualquer logado. Recomendação: sim, é correção de segurança.
- [ ] **D8 — Pares "-IS" × "-V2-IS":** `339203-IS` (13018) × `339203-V2-IS` (13452) e `339204-IS` (13017) × `339204-V2-IS` (13453) são dois códigos "-IS" da mesma peça; definir qual é o oficial.
- [ ] **D9 — Texto da Carol × orientação do usuário:** o pedido original diz "manter para todos a visualização apenas do valor de revenda"; a orientação de 14/11 diz que o valor de venda nosso vale para tudo, exceto o site. Confirmar com a Carol que vale a orientação do usuário.
- [ ] Operação paralela: combinar com a equipe como lançar a saída de peça "-IS" na Connect e aqui (peça única).
- [ ] 10 linhas da vitrine sem produto no cadastro: decidir se viram produto novo ou ficam como "sob encomenda".
