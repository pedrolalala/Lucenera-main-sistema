# Domínio: Cadastros

## Papel no ecossistema

O domínio de Cadastros guarda dados cadastrais, não operacionais.

Ele deve responder perguntas como:

- Quem é o cliente?
- Quem é o fornecedor?
- Quais são os dados fiscais/comerciais?
- Quais produtos existem no catálogo?
- Quais funcionários e responsáveis existem?

## Decisão importante

O mesmo dado cadastral pode aparecer no sistema de Cadastros e também no sistema de Estoque/Compras, mas com responsabilidades diferentes:

- Cadastros: dados cadastrais limpos e reutilizáveis.
- Estoque/Compras: dados cadastrais necessários para operação, junto com informações de compra, estoque, movimentação e atendimento.

## Modelagem importante: dois sentidos para "empresa"

No ecossistema Lucenera, "empresa" pode significar duas coisas diferentes:

1. Empresa do grupo econômico Lucenera
   - fica na tabela `empresas`;
   - é usada para separar operação interna, faturamento, contas, remessas, transações, usuários e documentos por empresa do grupo;
   - responde à pergunta: "qual empresa da Lucenera está responsável por esta operação?".

2. Empresa/PJ de um cliente, fornecedor, arquiteto ou outro contato
   - fica na própria tabela `contatos`;
   - o vínculo é `contatos.empresa_id -> contatos.id`;
   - permite representar uma pessoa física ligada a uma pessoa jurídica;
   - permite que um mesmo cliente/contato tenha mais de uma empresa/PJ quando necessário para nota fiscal, cobrança ou relacionamento comercial.

Esse relacionamento não deve ser tratado automaticamente como erro. `contatos.empresa_id` não aponta para `empresas.id` porque a empresa de um contato também é um contato cadastral.

## Relação com outros domínios

- Orçamentos usam cliente, projeto e produtos.
- Financeiro deriva cliente/projeto a partir do orçamento aprovado.
- Estoque/Compras usa clientes/projetos para registrar movimentações.
- Hub/TI usa usuários e permissões para controlar acesso.
- Pela SPEC-018, Orçamentos pode abrir um modal de criação de produto usando `public.criar_produto_orcamento(p_payload jsonb)`, mas a gravação continua no cadastro canônico `produtos` e tabelas auxiliares, sem criar catálogo paralelo.
- Após a SPEC-010, Cadastro pode ler views derivadas de `estoque_saldos_projeto_item` para detalhar "Reservado por projeto/cliente" em produtos, mas não deve escrever reserva, transferência ou compra.

## Automações atuais

Automatizações identificadas no Supabase real relacionadas a Cadastros:

- `public.handle_contato_tipo()`: trata classificação/tipo de contato.
- `public.propagate_contato_nome()`: propaga nome de contato para registros relacionados.
- `public.propagate_usuario_nome()`: propaga nome de usuário para registros relacionados.
- `public.fn_log_auditoria()`: apoia auditoria em cadastros como fornecedores.
- `public.handle_updated_at()`, `public.set_updated_at()` e `public.update_updated_at_column()`: atualizam campos de modificação.

Triggers relacionadas:

- `public.contatos.contatos_updated_at`
- `public.contatos.on_contato_created`
- `public.contatos.trg_propagate_contato_nome`
- `public.fornecedores.trg_fornecedores_auditoria`
- `public.fornecedores.trg_fornecedores_updated_at`
- `public.funcionarios.funcionarios_updated_at`
- `public.usuarios.trg_propagate_usuario_nome`
- `public.usuarios.usuarios_updated_at`

## Import periódico de planilhas (Connect legado)

- `scripts/importar_produtos_estoque.py` sincroniza `produtos.estoque_total/estoque_showroom/estoque_disponivel/custo_total/valor_venda/percentual_lucro` a partir da planilha `Produtos__AAAA-MM-DD.xlsx` (export "Estoque" do sistema legado Connect). Só atualiza produtos existentes (match por `codigo_produto`); nunca cria produto novo. `estoque_itens` é sincronizado automaticamente por trigger (`fn_sync_estoque_itens_from_produtos`), não pelo script.
- O nome do arquivo padrão está hardcoded no script (`PLANILHA_PADRAO`) — precisa ser atualizado manualmente a cada nova planilha antes de rodar. Mesmo padrão em `scripts/importar_contas_pagar_receber.py` (`CP_PADRAO`/`CR_PADRAO`).
- **Achado (22/07/2026)**: `produtos.percentual_lucro` era `numeric(5,2)` (máx 999,99) e o import falhou (`numeric field overflow`) em 2 produtos de custo residual (R$0,10) com margem de 1150% — valor legítimo da planilha, não erro de cadastro. Corrigido via migration `20260722_060_ampliar_precisao_percentual_lucro` (`numeric(9,2)`). Como o `UPDATE` é atômico por linha, os 2 produtos ficaram sem NENHUM campo atualizado (nem estoque/custo/venda) até a correção — reforça rodar `--dry-run` e conferir a contagem de erros antes de considerar um import concluído.

## Geração de `codigo_produto` (SPEC-053 — aplicada)

- Decisão do usuário (2026-07-27): `produtos.codigo_produto` (integer, único via `produtos_codigo_produto_key`) passa a ser gerado por uma sequence Postgres (`public.produtos_codigo_produto_seq`) associada como `DEFAULT nextval(...)` da coluna, em vez de digitado manualmente nos dois formulários que gravam em `produtos` (Cadastro via `createProduto()`, Orçamentos via RPC `criar_produto_orcamento`). Buracos na numeração são aceitáveis para o negócio.
- Migration `supabase/db/migrations/20260727_068_spec053_codigo_produto_sequence/` **aplicada no Supabase real** (confirmado 2026-08-04: `DEFAULT nextval('produtos_codigo_produto_seq')` presente na coluna). `criar_produto_orcamento` foi reescrita na mesma migration para não exigir/usar `codigo_produto` do payload. O frontend de `cadastro-lucenera` (Skip) só passou a de fato omitir o campo do payload em 2026-08-04, junto com a sincronização do SPEC-053 (ver `CHANGELOG.md`).
- `supabase/db/current/` ainda não foi reextraído para refletir o `DEFAULT` novo e o corpo atualizado da função — pendente.

## `contatos.tipo_cliente` (SPEC-052, achado 2026-08-04)

- Coluna nova `contatos.tipo_cliente varchar` (nullable, `CHECK` com 4 valores: `consumidor | nao_contribuinte | industria | revendedor`), migration `20260804_069_spec052_tipo_cliente`, aplicada no Supabase real. Mesmo padrão de `tipo_pessoa` (varchar + CHECK, sem ENUM). Distinto de `regime_apuracao` (regime tributário). Escopo: só cliente, sem backfill dos contatos existentes.

## `contatos.regime_apuracao` (SPEC-052, fechado 2026-08-04)

- Coluna já existia como `text` livre; ganhou `CHECK` restringindo a `simples_nacional | regime_normal` (migration `20260804_070_spec052_regime_apuracao_fixo`), aplicada no Supabase real depois de confirmar que nenhum dos 3.861 contatos tinha valor preenchido. Opções confirmadas pelo usuário — **não** são as 3 opções (Simples Nacional/Lucro Presumido/Lucro Real) do código morto em `cadastro-lucenera-b86fe/src/components/modals/ClienteModal.tsx`; esse componente ficou desatualizado, não usar como referência.

## Ação a ser realizada

Quando consolidar o schema, preservar a distinção entre `empresas` como empresas do grupo Lucenera e `contatos.empresa_id` como empresa/PJ vinculada a um contato. Depois, registrar nas telas e integrações esse significado para evitar conciliação incorreta. No frontend da SPEC-018/SPEC-053, reaproveitar `public.criar_produto_orcamento(p_payload jsonb)`, manter validações cadastrais de produto (`sku`, marca, categoria e fornecedor — `codigo_produto` agora é gerado por sequence, não mais validado a partir do payload) e impedir que a criação pelo Orçamentos escreva dados operacionais de estoque/compras.
