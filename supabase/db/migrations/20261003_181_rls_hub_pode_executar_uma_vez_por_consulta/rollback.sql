-- Rollback da migration 20261003_181: volta hub_pode_executar para VOLATILE e as 51
-- políticas para o texto original (capturado do banco em 03/10/2026 antes de aplicar).

ALTER FUNCTION public.hub_pode_executar(uuid, text, text, text) VOLATILE;

ALTER POLICY spec069_boletos_delete ON public.boletos USING (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'deletar'::text)) WITH CHECK ();
ALTER POLICY spec069_boletos_insert ON public.boletos USING () WITH CHECK (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'criar'::text));
ALTER POLICY spec069_boletos_select ON public.boletos USING ((hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'visualizar'::text) OR hub_pode_executar(auth.uid(), 'separacao-parcial'::text, NULL::text, 'visualizar'::text))) WITH CHECK ();
ALTER POLICY spec069_boletos_update ON public.boletos USING (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'editar'::text)) WITH CHECK (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'editar'::text));
ALTER POLICY spec069_contas_bancarias_delete ON public.contas_bancarias USING (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'deletar'::text)) WITH CHECK ();
ALTER POLICY spec069_contas_bancarias_insert ON public.contas_bancarias USING () WITH CHECK (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'criar'::text));
ALTER POLICY spec069_contas_bancarias_select ON public.contas_bancarias USING (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'visualizar'::text)) WITH CHECK ();
ALTER POLICY spec069_contas_bancarias_update ON public.contas_bancarias USING (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'editar'::text)) WITH CHECK (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'editar'::text));
ALTER POLICY spec069_contatos_delete ON public.contatos USING (
CASE
    WHEN (tipo = 'fornecedor'::contato_tipo) THEN (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'deletar'::text) OR hub_pode_executar(auth.uid(), 'cadastro'::text, NULL::text, 'deletar'::text))
    ELSE hub_pode_executar(auth.uid(), 'crm'::text, NULL::text, 'deletar'::text)
END) WITH CHECK ();
ALTER POLICY spec069_contatos_insert ON public.contatos USING () WITH CHECK (
CASE
    WHEN (tipo = 'fornecedor'::contato_tipo) THEN (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'criar'::text) OR hub_pode_executar(auth.uid(), 'cadastro'::text, NULL::text, 'criar'::text))
    ELSE hub_pode_executar(auth.uid(), 'crm'::text, NULL::text, 'criar'::text)
END);
ALTER POLICY spec069_contatos_update ON public.contatos USING (
CASE
    WHEN (tipo = 'fornecedor'::contato_tipo) THEN (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'editar'::text) OR hub_pode_executar(auth.uid(), 'cadastro'::text, NULL::text, 'editar'::text))
    ELSE hub_pode_executar(auth.uid(), 'crm'::text, NULL::text, 'editar'::text)
END) WITH CHECK (
CASE
    WHEN (tipo = 'fornecedor'::contato_tipo) THEN (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'editar'::text) OR hub_pode_executar(auth.uid(), 'cadastro'::text, NULL::text, 'editar'::text))
    ELSE hub_pode_executar(auth.uid(), 'crm'::text, NULL::text, 'editar'::text)
END);
ALTER POLICY spec069_cotacoes_compra_delete ON public.cotacoes_compra USING (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'deletar'::text)) WITH CHECK ();
ALTER POLICY spec069_cotacoes_compra_insert ON public.cotacoes_compra USING () WITH CHECK (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'criar'::text));
ALTER POLICY spec069_cotacoes_compra_update ON public.cotacoes_compra USING (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'editar'::text)) WITH CHECK (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'editar'::text));
ALTER POLICY spec069_funcionarios_novo_delete ON public.funcionarios_novo USING (hub_pode_executar(auth.uid(), 'rh'::text, NULL::text, 'deletar'::text)) WITH CHECK ();
ALTER POLICY spec069_funcionarios_novo_insert ON public.funcionarios_novo USING () WITH CHECK (hub_pode_executar(auth.uid(), 'rh'::text, NULL::text, 'criar'::text));
ALTER POLICY spec069_funcionarios_novo_select ON public.funcionarios_novo USING (hub_pode_executar(auth.uid(), 'rh'::text, NULL::text, 'visualizar'::text)) WITH CHECK ();
ALTER POLICY spec069_funcionarios_novo_update ON public.funcionarios_novo USING (hub_pode_executar(auth.uid(), 'rh'::text, NULL::text, 'editar'::text)) WITH CHECK (hub_pode_executar(auth.uid(), 'rh'::text, NULL::text, 'editar'::text));
ALTER POLICY spec069_notas_fiscais_delete ON public.notas_fiscais USING (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'deletar'::text)) WITH CHECK ();
ALTER POLICY spec069_notas_fiscais_insert ON public.notas_fiscais USING () WITH CHECK (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'criar'::text));
ALTER POLICY spec069_notas_fiscais_select ON public.notas_fiscais USING (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'visualizar'::text)) WITH CHECK ();
ALTER POLICY spec069_notas_fiscais_update ON public.notas_fiscais USING (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'editar'::text)) WITH CHECK (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'editar'::text));
ALTER POLICY spec069_orcamento_itens_delete ON public.orcamento_itens USING (hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'deletar'::text)) WITH CHECK ();
ALTER POLICY spec069_orcamento_itens_insert ON public.orcamento_itens USING () WITH CHECK (hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'criar'::text));
ALTER POLICY spec069_orcamento_itens_update ON public.orcamento_itens USING (hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'editar'::text)) WITH CHECK (hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'editar'::text));
ALTER POLICY spec069_orcamentos_delete ON public.orcamentos USING (hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'deletar'::text)) WITH CHECK ();
ALTER POLICY spec069_orcamentos_insert ON public.orcamentos USING () WITH CHECK (hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'criar'::text));
ALTER POLICY spec069_orcamentos_update ON public.orcamentos USING (hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'editar'::text)) WITH CHECK (hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'editar'::text));
ALTER POLICY spec069_pedido_compra_itens_delete ON public.pedido_compra_itens USING (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'deletar'::text)) WITH CHECK ();
ALTER POLICY spec069_pedido_compra_itens_insert ON public.pedido_compra_itens USING () WITH CHECK (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'criar'::text));
ALTER POLICY spec069_pedido_compra_itens_update ON public.pedido_compra_itens USING (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'editar'::text)) WITH CHECK (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'editar'::text));
ALTER POLICY spec069_produtos_delete ON public.produtos USING (hub_pode_executar(auth.uid(), 'cadastro'::text, NULL::text, 'deletar'::text)) WITH CHECK ();
ALTER POLICY spec069_produtos_insert ON public.produtos USING () WITH CHECK ((hub_pode_executar(auth.uid(), 'cadastro'::text, NULL::text, 'criar'::text) OR hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'criar'::text)));
ALTER POLICY spec069_produtos_select ON public.produtos USING ((hub_pode_executar(auth.uid(), 'cadastro'::text, NULL::text, 'visualizar'::text) OR hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'visualizar'::text) OR hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'visualizar'::text))) WITH CHECK ();
ALTER POLICY spec069_produtos_update ON public.produtos USING ((hub_pode_executar(auth.uid(), 'cadastro'::text, NULL::text, 'editar'::text) OR hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'editar'::text) OR hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'editar'::text))) WITH CHECK ((hub_pode_executar(auth.uid(), 'cadastro'::text, NULL::text, 'editar'::text) OR hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'editar'::text) OR hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'editar'::text)));
ALTER POLICY spec069_projetos_delete ON public.projetos USING ((hub_pode_executar(auth.uid(), 'crm'::text, NULL::text, 'deletar'::text) OR hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'deletar'::text))) WITH CHECK ();
ALTER POLICY spec069_projetos_insert ON public.projetos USING () WITH CHECK ((hub_pode_executar(auth.uid(), 'crm'::text, NULL::text, 'criar'::text) OR hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'criar'::text)));
ALTER POLICY spec069_projetos_update ON public.projetos USING ((hub_pode_executar(auth.uid(), 'crm'::text, NULL::text, 'editar'::text) OR hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'editar'::text))) WITH CHECK ((hub_pode_executar(auth.uid(), 'crm'::text, NULL::text, 'editar'::text) OR hub_pode_executar(auth.uid(), 'orcamentos'::text, NULL::text, 'editar'::text)));
ALTER POLICY spec069_remessas_delete ON public.remessas USING (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'deletar'::text)) WITH CHECK ();
ALTER POLICY spec069_remessas_insert ON public.remessas USING () WITH CHECK (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'criar'::text));
ALTER POLICY spec069_remessas_select ON public.remessas USING (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'visualizar'::text)) WITH CHECK ();
ALTER POLICY spec069_remessas_update ON public.remessas USING (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'editar'::text)) WITH CHECK (hub_pode_executar(auth.uid(), 'financeiro'::text, NULL::text, 'editar'::text));
ALTER POLICY separacao_baixas_delete ON public.separacao_baixas USING ((hub_pode_executar(auth.uid(), 'separacao-parcial'::text, NULL::text, 'deletar'::text) OR hub_pode_executar(auth.uid(), 'logistica'::text, NULL::text, 'deletar'::text))) WITH CHECK ();
ALTER POLICY separacao_baixas_insert ON public.separacao_baixas USING () WITH CHECK ((hub_pode_executar(auth.uid(), 'separacao-parcial'::text, NULL::text, 'criar'::text) OR hub_pode_executar(auth.uid(), 'logistica'::text, NULL::text, 'criar'::text)));
ALTER POLICY spec069_separacoes_delete ON public.separacoes USING ((hub_pode_executar(auth.uid(), 'logistica'::text, NULL::text, 'deletar'::text) OR hub_pode_executar(auth.uid(), 'separacao-parcial'::text, NULL::text, 'deletar'::text))) WITH CHECK ();
ALTER POLICY spec069_separacoes_insert ON public.separacoes USING () WITH CHECK ((hub_pode_executar(auth.uid(), 'logistica'::text, NULL::text, 'criar'::text) OR hub_pode_executar(auth.uid(), 'separacao-parcial'::text, NULL::text, 'criar'::text)));
ALTER POLICY spec069_separacoes_update ON public.separacoes USING ((hub_pode_executar(auth.uid(), 'logistica'::text, NULL::text, 'editar'::text) OR hub_pode_executar(auth.uid(), 'separacao-parcial'::text, NULL::text, 'editar'::text))) WITH CHECK ((hub_pode_executar(auth.uid(), 'logistica'::text, NULL::text, 'editar'::text) OR hub_pode_executar(auth.uid(), 'separacao-parcial'::text, NULL::text, 'editar'::text)));
ALTER POLICY solicitacoes_update_aprovador ON public.solicitacoes USING (hub_pode_executar(auth.uid(), 'solicitacoes'::text, NULL::text, 'aprovar'::text)) WITH CHECK (hub_pode_executar(auth.uid(), 'solicitacoes'::text, NULL::text, 'aprovar'::text));
ALTER POLICY spec069_solicitacoes_compra_delete ON public.solicitacoes_compra USING (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'deletar'::text)) WITH CHECK ();
ALTER POLICY spec069_solicitacoes_compra_insert ON public.solicitacoes_compra USING () WITH CHECK (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'criar'::text));
ALTER POLICY spec069_solicitacoes_compra_update ON public.solicitacoes_compra USING (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'editar'::text)) WITH CHECK (hub_pode_executar(auth.uid(), 'necessidade-de-compra'::text, NULL::text, 'editar'::text));

NOTIFY pgrst, 'reload schema';
