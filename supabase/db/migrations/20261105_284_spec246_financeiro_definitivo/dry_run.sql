-- Dry-run da 284: aplica a estrutura, prova as travas e DESFAZ. Termina em ROLLBACK.
-- SPEC-246 (05/11): financeiro definitivo — a carga de 05/11 é a ÚLTIMA; daqui em diante o financeiro é contabilizado pelo sistema novo.
--  * connect_financeiro_encerrado: marco único (como o da operação em paralelo). Com ele gravado, nenhuma parcela com código da Connect
--    (cod_itens_duplicata) pode ser CRIADA e o código de uma parcela existente não pode mudar. Parcelas nativas (sem código) seguem livres.
--  * uq_transacoes_tipo_cod_ativa: UNIQUE parcial (tipo, cod_itens_duplicata) onde não cancelada — acaba a contagem em dobro.
--    PRÉ-REQUISITO: zero duplicados ativos (corrigido por scripts/corrigir_receitas_copia_de_despesa.py, 1.572 parcelas, backup no schema backup).
--  * contato_legado_ids: mapa EXPLÍCITO (espaço, código da Connect) -> contato. O código da pessoa da Connect não é único entre cliente e fornecedor.
--  * vendas_connect: venda da Connect <-> orçamento/projeto/cliente do sistema (vazia; alimentada por Reserva/XML e pelo vínculo manual).
--  * vw_financeiro_integridade: uma linha por verificação (quantidade e valor), para a conferência passar a ser do sistema nativo, não da planilha.
-- Não altera valores, status, estoque, vendas nem contatos. Plano de contas x tipo NÃO é trava (a própria Connect mistura): só alerta na view.
BEGIN;

-- 1) marco do financeiro
CREATE TABLE IF NOT EXISTS public.connect_financeiro_encerrado (
  id           integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  encerrado_em timestamptz NOT NULL DEFAULT now(),
  observacao   text
);
ALTER TABLE public.connect_financeiro_encerrado ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.connect_financeiro_encerrado FROM anon, authenticated;
GRANT SELECT ON public.connect_financeiro_encerrado TO authenticated;
GRANT ALL ON public.connect_financeiro_encerrado TO service_role;
DROP POLICY IF EXISTS connect_financeiro_encerrado_select ON public.connect_financeiro_encerrado;
CREATE POLICY connect_financeiro_encerrado_select ON public.connect_financeiro_encerrado FOR SELECT TO authenticated USING (true);
INSERT INTO public.connect_financeiro_encerrado (id, observacao)
VALUES (1, 'Decisão de 05/11/2026: a planilha de Contas a Receber/Pagar de 05/11 foi a ÚLTIMA carga; a partir daqui o financeiro é do sistema novo (operação em paralelo com a Connect).')
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.trg_transacoes_legado_imutavel()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $f$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.cod_itens_duplicata IS NOT NULL AND EXISTS (SELECT 1 FROM public.connect_financeiro_encerrado) THEN
      RAISE EXCEPTION 'Financeiro encerrado para carga da Connect (05/11/2026): parcelas novas nascem no sistema, sem código legado.' USING ERRCODE = 'P0001';
    END IF;
  ELSIF OLD.cod_itens_duplicata IS NOT NULL AND NEW.cod_itens_duplicata IS DISTINCT FROM OLD.cod_itens_duplicata THEN
    RAISE EXCEPTION 'O código da parcela na Connect (cod_itens_duplicata) é histórico e não pode ser alterado.' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS trg_transacoes_legado_imutavel ON public.transacoes;
CREATE TRIGGER trg_transacoes_legado_imutavel BEFORE INSERT OR UPDATE OF cod_itens_duplicata ON public.transacoes
  FOR EACH ROW EXECUTE FUNCTION public.trg_transacoes_legado_imutavel();

-- 2) sem duplicidade de parcela ativa
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.transacoes WHERE cod_itens_duplicata IS NOT NULL AND status_pago <> 2
             GROUP BY tipo, cod_itens_duplicata HAVING count(*) > 1) THEN
    RAISE EXCEPTION 'Ainda há cod_itens_duplicata duplicado entre parcelas ativas: rode scripts/corrigir_receitas_copia_de_despesa.py antes.';
  END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS uq_transacoes_tipo_cod_ativa ON public.transacoes (tipo, cod_itens_duplicata)
  WHERE cod_itens_duplicata IS NOT NULL AND status_pago <> 2;

-- 3) mapa explícito de pessoas da Connect
CREATE TABLE IF NOT EXISTS public.contato_legado_ids (
  espaco      text    NOT NULL CHECK (espaco IN ('cliente', 'fornecedor', 'arquiteto')),
  cod_connect integer NOT NULL,
  contato_id  uuid    NOT NULL REFERENCES public.contatos (id) ON DELETE CASCADE,
  metodo      text    NOT NULL CHECK (metodo IN ('documento', 'codigo+nome', 'nome', 'pre_cadastro', 'manual')),
  criado_em   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (espaco, cod_connect)
);
CREATE INDEX IF NOT EXISTS ix_contato_legado_ids_contato ON public.contato_legado_ids (contato_id);
ALTER TABLE public.contato_legado_ids ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.contato_legado_ids FROM anon, authenticated;
GRANT SELECT ON public.contato_legado_ids TO authenticated;
GRANT ALL ON public.contato_legado_ids TO service_role;
DROP POLICY IF EXISTS contato_legado_ids_select ON public.contato_legado_ids;
CREATE POLICY contato_legado_ids_select ON public.contato_legado_ids FOR SELECT TO authenticated
  USING ((SELECT public.pode_acessar_sistema('financeiro')));

-- 4) venda da Connect <-> sistema
CREATE TABLE IF NOT EXISTS public.vendas_connect (
  cod_venda     integer PRIMARY KEY,
  cod_orcamento integer,
  cod_cliente   integer,
  orcamento_id  uuid REFERENCES public.orcamentos (id) ON DELETE SET NULL,
  projeto_id    uuid REFERENCES public.projetos (id) ON DELETE SET NULL,
  empresa_id    uuid REFERENCES public.empresas (id) ON DELETE SET NULL,
  fonte         text NOT NULL CHECK (fonte IN ('reserva_ef', 'xml', 'manual', 'financeiro')),
  criado_em     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_vendas_connect_orcamento ON public.vendas_connect (orcamento_id);
ALTER TABLE public.vendas_connect ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.vendas_connect FROM anon, authenticated;
GRANT SELECT ON public.vendas_connect TO authenticated;
GRANT ALL ON public.vendas_connect TO service_role;
DROP POLICY IF EXISTS vendas_connect_select ON public.vendas_connect;
CREATE POLICY vendas_connect_select ON public.vendas_connect FOR SELECT TO authenticated
  USING ((SELECT public.pode_acessar_sistema('financeiro')));

-- 5) integridade contínua (alertas; não bloqueiam o legado)
CREATE OR REPLACE VIEW public.vw_financeiro_integridade WITH (security_invoker = true) AS
SELECT 'negociacao_sem_pessoa'::text AS verificacao, 'A duplicata não tem contato nem nome de pessoa'::text AS descricao, count(*)::bigint AS qtd, 0::numeric AS valor
  FROM public.negociacoes WHERE contato_id IS NULL AND coalesce(nullif(btrim(nome_pessoa), ''), nullif(btrim(razao_pessoa), '')) IS NULL
UNION ALL
SELECT 'negociacao_sem_contato_cadastrado', 'Duplicata só com o nome da planilha (sem cadastro de contato ligado)', count(*), 0
  FROM public.negociacoes WHERE contato_id IS NULL AND coalesce(nullif(btrim(nome_pessoa), ''), nullif(btrim(razao_pessoa), '')) IS NOT NULL
UNION ALL
SELECT 'negociacao_sem_empresa', 'Duplicata sem empresa do grupo', count(*), 0 FROM public.negociacoes WHERE empresa_id IS NULL
UNION ALL
SELECT 'negociacao_sem_plano_de_contas', 'Duplicata sem conta do plano de contas', count(*), 0 FROM public.negociacoes WHERE plano_contas_id IS NULL
UNION ALL
SELECT 'parcela_sem_negociacao', 'Parcela ativa sem duplicata', count(*), coalesce(sum(vl_parcela), 0) FROM public.transacoes WHERE negociacao_id IS NULL AND status_pago <> 2
UNION ALL
SELECT 'parcela_paga_sem_conta_bancaria', 'Parcela paga sem conta bancária', count(*), coalesce(sum(vl_pago), 0) FROM public.transacoes WHERE status_pago = 1 AND conta_id IS NULL
UNION ALL
SELECT 'parcela_aberta_sem_conta_bancaria', 'Parcela em aberto sem conta bancária prevista', count(*), coalesce(sum(vl_parcela), 0) FROM public.transacoes WHERE status_pago = 0 AND conta_id IS NULL
UNION ALL
SELECT 'receita_igual_a_despesa', 'Receita ativa idêntica a uma despesa ativa (contagem em dobro)', count(*), coalesce(sum(t.vl_parcela), 0)
  FROM public.transacoes t WHERE t.tipo::text = 'receita' AND t.status_pago <> 2 AND EXISTS (
    SELECT 1 FROM public.transacoes d WHERE d.tipo::text = 'despesa' AND d.status_pago <> 2 AND d.cod_itens_duplicata = t.cod_itens_duplicata
      AND d.vl_parcela = t.vl_parcela AND d.dt_vencimento = t.dt_vencimento)
UNION ALL
SELECT 'plano_de_contas_de_outro_tipo', 'Duplicata cujo plano de contas é de tipo diferente (legado da Connect; alerta)', count(*), 0
  FROM public.negociacoes n JOIN public.plano_de_contas p ON p.id = n.plano_contas_id
  WHERE (n.tipo::text = 'receita' AND p.tipo::text <> 'receita') OR (n.tipo::text = 'despesa' AND p.tipo::text = 'receita')
UNION ALL
SELECT 'parcela_vencimento_antes_da_emissao', 'Vencimento anterior à emissão (dado da Connect)', count(*), 0
  FROM public.transacoes WHERE status_pago <> 2 AND dt_vencimento < dt_emissao
UNION ALL
SELECT 'receita_sem_projeto', 'Duplicata de receber sem projeto ligado', count(*), 0
  FROM public.negociacoes WHERE tipo::text = 'receita' AND projeto_id IS NULL;
GRANT SELECT ON public.vw_financeiro_integridade TO authenticated;


DO $$ BEGIN
  RAISE NOTICE 'integridade: %', (SELECT string_agg(verificacao || '=' || qtd, ', ' ORDER BY verificacao) FROM public.vw_financeiro_integridade);
  BEGIN
    INSERT INTO public.transacoes (tipo, cod_itens_duplicata, valor, status_pago) VALUES ('despesa', 999999, 1, 0);
    RAISE NOTICE 'FALHOU: aceitou parcela com codigo legado';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'OK: parcela com codigo legado recusada'; END;
  BEGIN
    UPDATE public.transacoes SET cod_itens_duplicata = cod_itens_duplicata + 1000000
      WHERE id = (SELECT id FROM public.transacoes WHERE cod_itens_duplicata IS NOT NULL LIMIT 1);
    RAISE NOTICE 'FALHOU: alterou codigo legado';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'OK: alteracao do codigo legado recusada'; END;
  RAISE NOTICE 'parcelas ativas: %', (SELECT count(*) FROM public.transacoes WHERE status_pago <> 2);
END $$;
ROLLBACK;
