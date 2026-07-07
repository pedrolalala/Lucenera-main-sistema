# Domínio: Estoque e Compras

## Papel no ecossistema

Estoque/Compras deve ser um sistema próprio.

Ele trata movimentações operacionais de produtos, compras, estoque e relação com clientes/projetos.

## Decisão atual

Vendas aprovadas pertencem ao domínio de Orçamentos/Projetos.

O restante das entradas da Connect ligadas a clientes deve ser tratado como movimentação de estoque/operação, não como orçamento aprovado.

A reunião 08 de 06/07/2026 consolidou:

- "estoque de cliente" e "itens reservados" são o mesmo conceito de tela/operação;
- estoque disponível = estoque físico total - estoque reservado;
- entrega futura é compromisso ativo sem cobertura física;
- necessidade de compra é agregada por produto e não deve ficar amarrada a cliente;
- transferência entre clientes deve registrar operação, origem, destino, solicitante e aprovador.

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

Objetos aplicados / pendentes:

- `estoque_saldos_projeto_item` e `estoque_movimentos_projeto_item`: SPEC-010 aplicada no Supabase real em 07/07/2026. A migration corretiva `20260707_023_spec010_hardening` ficou escrita para fechar a exposição das views, reconciliar o agregado `estoque_itens.quantidade_reservada` e endurecer a entrega de itens com `q_entrega_futura`.
- `transferencias_estoque`, `devolucoes_estoque`, `vw_entrega_futura_projeto_item` e `vw_necessidade_compra` ainda não existem; estão desenhados nas SPECs 011/012/015 e dependem do hardening/RLS da SPEC-010 antes de expor a operação.

## Ação a ser realizada

Aplicar a migration `20260707_023_spec010_hardening` no Supabase real, depois reextrair `supabase/db/current/` e definir a policy de RLS antes de avançar transferência, entrega futura detalhada, devolução automatizada e badges ricos no CRM. No banco, separar claramente tabelas cadastrais de tabelas operacionais de movimentação. O saldo vivo usa `projeto_item_id`; cliente/projeto/orçamento/produto vêm por relacionamento (ver `vw_estoque_saldos_projeto_item`). `estoque_itens.quantidade_reservada` deve permanecer como agregado de compatibilidade dos saldos abertos por produto.
