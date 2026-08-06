-- SPEC-066 Frente E: "Entrada de Nota Fiscal" (substitui a aba
-- "Recebimento", hoje placeholder). Nota fiscal de COMPRA (recebida de
-- fornecedor), vinculada a um pedido_compra -- domínio diferente da
-- tabela public.notas_fiscais já existente (essa é de vendas: nota
-- emitida pro cliente, ligada a orcamento_id/boleto_id, usada pelo
-- sistema de Administração Bancária). Por isso o nome novo, para não
-- colidir.
--
-- v1 vincula só ao pedido_compra (fornecedor/itens/valor/empresa) -- não
-- replica o nível de detalhe orçamento/venda/cliente/L do sistema legado
-- que a própria Débora sugeriu simplificar (Reunião.05).
--
-- Tanto o Matheus (recebe fisicamente, anexa PDF/foto na hora) quanto a
-- Débora (pega o anexo por e-mail) usam a mesma tela/tabela -- por isso
-- arquivo_url é opcional, não obrigatório.

CREATE TABLE public.notas_fiscais_compra (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    pedido_compra_id uuid NOT NULL REFERENCES public.pedidos_compra(id),
    numero_nf text NOT NULL,
    data_emissao date,
    valor numeric(12,2),
    arquivo_url text,
    observacao text,
    criado_por uuid REFERENCES public.usuarios(id),
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE public.notas_fiscais_compra IS
  'SPEC-066: entrada de nota fiscal de compra (fornecedor), vinculada a pedidos_compra. Não confundir com public.notas_fiscais (domínio vendas).';

CREATE INDEX idx_notas_fiscais_compra_pedido ON public.notas_fiscais_compra USING btree (pedido_compra_id);

CREATE TRIGGER notas_fiscais_compra_updated_at
    BEFORE UPDATE ON public.notas_fiscais_compra
    FOR EACH ROW EXECUTE FUNCTION public.fn_atualiza_updated_at();

ALTER TABLE public.notas_fiscais_compra ENABLE ROW LEVEL SECURITY;

CREATE POLICY notas_fiscais_compra_select ON public.notas_fiscais_compra
  FOR SELECT TO authenticated USING (true);

CREATE POLICY notas_fiscais_compra_insert ON public.notas_fiscais_compra
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY notas_fiscais_compra_update ON public.notas_fiscais_compra
  FOR UPDATE TO authenticated USING (true);

-- Bucket de storage para o PDF/foto da nota fiscal de compra (mesmo
-- padrão do bucket "orcamentos": público para leitura, authenticated
-- para upload).
INSERT INTO storage.buckets (id, name, public)
VALUES ('notas_fiscais_compra', 'notas_fiscais_compra', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY notas_fiscais_compra_storage_read ON storage.objects
  FOR SELECT USING (bucket_id = 'notas_fiscais_compra');

CREATE POLICY notas_fiscais_compra_storage_insert ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'notas_fiscais_compra');
