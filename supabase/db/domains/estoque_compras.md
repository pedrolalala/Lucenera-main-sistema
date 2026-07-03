# Domínio: Estoque e Compras

## Papel no ecossistema

Estoque/Compras deve ser um sistema próprio.

Ele trata movimentações operacionais de produtos, compras, estoque e relação com clientes/projetos.

## Decisão atual

Vendas aprovadas pertencem ao domínio de Orçamentos/Projetos.

O restante das entradas da Connect ligadas a clientes deve ser tratado como movimentação de estoque/operação, não como orçamento aprovado.

## Relação com Cadastros

O sistema pode mostrar dados cadastrais, mas seu foco é operacional:

- produto em estoque;
- produto comprado;
- produto reservado;
- produto entregue;
- movimentação por cliente/projeto;
- necessidade de compra/reposição;
- disparos futuros para financeiro quando houver fluxo de compra.

## Automações atuais

Automatizações identificadas no Supabase real relacionadas a Produtos/Estoque/Compras:

- `public.fn_atualizar_preco_venda()`: atualiza preço de venda de produto.
- `public.generate_product_slug(nome text, preco numeric)`: gera slug de produto.
- `public.get_next_sku(prefix text)`: gera próximo SKU por prefixo.
- `public.trigger_reserva_estoque()`: automação atual de reserva de estoque ligada ao projeto.
- `public.trigger_update_revenda_ubiqua_slug()`: atualiza slug de revenda Ubiqua.
- `public.update_revenda_ubiqua_ordem(payload jsonb)`: atualiza ordem da revenda Ubiqua.
- `public.update_revenda_ubiqua_updated_at()`: atualiza timestamp da revenda Ubiqua.

Triggers relacionadas:

- `public.produtos.produtos_updated_at`
- `public.produtos.trg_atualizar_preco_venda`
- `public.produtos.trg_calculo_preco_venda`
- `public.produtos.update_produtos_updated_at`
- `public.projetos.trg_reserva_estoque`
- `public.revenda_ubiqua.trg_revenda_ubiqua_slug`
- `public.revenda_ubiqua.trigger_revenda_ubiqua_updated_at`

Edge Functions relacionadas:

- Não há Edge Function central ativa específica de Estoque/Compras no inventário atual.
- Funções da Logística backup que lidam com materiais devem ser analisadas quando o novo sistema de Estoque/Compras/Logística for especificado.

## Ação a ser realizada

Criar SPEC própria para o novo sistema de Estoque/Compras. No banco, separar claramente tabelas cadastrais de tabelas operacionais de movimentação. Evitar misturar item vendido aprovado com simples movimentação de estoque.
