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

## Ação a ser realizada

Quando consolidar o schema, preservar a distinção entre `empresas` como empresas do grupo Lucenera e `contatos.empresa_id` como empresa/PJ vinculada a um contato. Depois, registrar nas telas e integrações esse significado para evitar conciliação incorreta. No frontend da SPEC-018, reaproveitar `public.criar_produto_orcamento(p_payload jsonb)`, manter validações cadastrais de produto (`codigo_produto`, `sku`, marca, categoria e fornecedor) e impedir que a criação pelo Orçamentos escreva dados operacionais de estoque/compras.
