-- SPEC-236: endereço de entrega do pedido de compra e WhatsApp do Compras em um lugar só.
--  1. empresas: razão social da FOCO passa a "FOCO ILUMINAÇÃO LTDA" (decisão do usuário 28/10; vale para o sistema todo).
--  2. compras_config (uma linha): empresa de entrega padrão (estoque = FOCO) + WhatsApp do Compras.
--     Leitura: quem tem o Compras (necessidade-de-compra) ou admin. Gravação: só admin. Sem anon.
--  3. Fornecedores Manoella e Islight entregam no showroom: preenche os campos *_entrega do contato (que o PDF usa antes
--     do padrão). Esses campos não eram usados em nenhum fornecedor.
BEGIN;

UPDATE public.empresas SET razao_social = 'FOCO ILUMINAÇÃO LTDA' WHERE nome = 'FOCO ILUMINACAO';

CREATE TABLE public.compras_config (
  id boolean PRIMARY KEY DEFAULT true CHECK (id),
  empresa_entrega_padrao_id uuid REFERENCES public.empresas(id),
  whatsapp_compras text,
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  atualizado_por uuid REFERENCES public.usuarios(id)
);
COMMENT ON TABLE public.compras_config IS
  'SPEC-236: configuração do Compras (uma linha). Endereço de entrega padrão do pedido = empresa_entrega_padrao_id; WhatsApp no e-mail ao fornecedor.';

INSERT INTO public.compras_config (empresa_entrega_padrao_id, whatsapp_compras)
SELECT id, '(16) 99711-2520' FROM public.empresas WHERE nome = 'FOCO ILUMINACAO';

ALTER TABLE public.compras_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.compras_config FROM anon, PUBLIC;
GRANT SELECT, UPDATE ON public.compras_config TO authenticated;

CREATE POLICY compras_config_select ON public.compras_config FOR SELECT TO authenticated
  USING ((SELECT public.is_admin()) OR (SELECT public.pode_acessar_sistema('necessidade-de-compra')));
CREATE POLICY compras_config_update ON public.compras_config FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()));

UPDATE public.contatos
   SET endereco_entrega = 'Rua Ayrton Roxo', numero_entrega = '867', complemento_entrega = NULL,
       bairro_entrega = 'Alto da Boa Vista', cidade_entrega = 'Ribeirão Preto', estado_entrega = 'SP',
       cep_entrega = '14025-270'
 WHERE tipo = 'fornecedor'
   AND nome IN ('MANOELLA ZAUITH LEITE LOPES', 'ISLIGHT COMERCIO E SERVICOS DE ILUMINACAO LTDA')
   AND coalesce(endereco_entrega, '') = '';

COMMIT;
