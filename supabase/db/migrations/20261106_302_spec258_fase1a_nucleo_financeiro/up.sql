-- SPEC-258 FASE 1A: núcleo do financeiro novo (TABELAS VAZIAS). Nada existente é alterado, nenhum dado é copiado, nenhuma tela muda.
-- Princípios: tudo com id uuid; ligação = chave estrangeira real (uma coluna por origem, exatamente uma preenchida); o "liquidado" só nasce
-- das baixas (gatilho); GRAVAÇÃO DIRETA PROIBIDA (as tabelas só têm SELECT para authenticated; escrever só por funções SECURITY DEFINER da Fase 1B);
-- histórico financeiro PERMANENTE em tabela própria (a auditoria geral é apagada com 12 meses); ids da Connect só em colunas legado_* imutáveis.
-- Regra do usuário (06/11/2026): no legado, a Connect (planilha de 05/11) é a verdade; o que o banco tem a mais NÃO migra.

-- ===================================================================== enumerações
CREATE TYPE public.fin_natureza   AS ENUM ('receber', 'pagar');
CREATE TYPE public.fin_origem     AS ENUM ('orcamento', 'pedido_compra', 'nota_fiscal_compra', 'folha', 'custo_recorrente',
                                           'regra_repasse', 'permuta', 'devolucao', 'adiantamento', 'manual', 'legado_connect');
CREATE TYPE public.fin_especie    AS ENUM ('venda', 'credito_devolucao', 'compra', 'nota_compra', 'adiantamento', 'despesa', 'salario',
                                           'comissao', 'rt_arquiteto', 'permuta', 'outro');
CREATE TYPE public.fin_situacao   AS ENUM ('prevista', 'firme', 'cancelada', 'substituida', 'renegociada');
CREATE TYPE public.fin_baixa_tipo AS ENUM ('recebimento', 'pagamento', 'compensacao', 'renegociacao', 'abatimento', 'baixa_interna', 'estorno');
CREATE TYPE public.fin_cobranca_meio AS ENUM ('boleto', 'pix', 'cartao', 'deposito', 'carteira', 'cheque', 'outro');
CREATE TYPE public.fin_pendencia_status AS ENUM ('aberta', 'resolvida', 'aceita');

-- ===================================================================== regras de repasse (RT e comissão)
CREATE TABLE public.financeiro_regras_repasse (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo             text NOT NULL CHECK (tipo IN ('rt_arquiteto', 'comissao')),
    escopo           text NOT NULL CHECK (escopo IN ('padrao', 'beneficiario', 'projeto', 'venda')),
    beneficiario_contato_id     uuid REFERENCES public.contatos(id),
    beneficiario_funcionario_id uuid REFERENCES public.funcionarios(id),
    beneficiario_equipe_id      uuid REFERENCES public.equipes_projetos(id),
    projeto_id       uuid REFERENCES public.projetos(id),
    orcamento_id     uuid REFERENCES public.orcamentos(id),
    percentual       numeric(7,4) NOT NULL CHECK (percentual >= 0 AND percentual <= 100),
    base_calculo     text NOT NULL CHECK (base_calculo IN ('bruto', 'liquido', 'sem_frete_imposto', 'recebido')),
    gatilho          text NOT NULL CHECK (gatilho IN ('proporcional_recebido', 'venda_quitada', 'aprovacao', 'dia_fixo')),
    dia_fixo         smallint CHECK (dia_fixo BETWEEN 1 AND 31),
    exige_nota_fiscal boolean,                      -- NULL = a confirmar (SPEC-258, pergunta 5)
    vigencia_inicio  date NOT NULL DEFAULT current_date,
    vigencia_fim     date,
    ativo            boolean NOT NULL DEFAULT true,
    observacao       text,
    criado_em        timestamptz NOT NULL DEFAULT now(),
    criado_por       uuid,
    CHECK (vigencia_fim IS NULL OR vigencia_fim >= vigencia_inicio),
    CHECK (gatilho <> 'dia_fixo' OR dia_fixo IS NOT NULL),
    -- escopo x quem/qual venda: padrão sem ninguém; beneficiário com 1 pessoa; projeto/venda apontam para o projeto/orçamento
    CHECK (CASE escopo
             WHEN 'padrao' THEN num_nonnulls(beneficiario_contato_id, beneficiario_funcionario_id, beneficiario_equipe_id, projeto_id, orcamento_id) = 0
             WHEN 'beneficiario' THEN num_nonnulls(beneficiario_contato_id, beneficiario_funcionario_id, beneficiario_equipe_id) = 1
                                      AND num_nonnulls(projeto_id, orcamento_id) = 0
             WHEN 'projeto' THEN projeto_id IS NOT NULL AND orcamento_id IS NULL AND num_nonnulls(beneficiario_contato_id, beneficiario_funcionario_id, beneficiario_equipe_id) <= 1
             WHEN 'venda' THEN orcamento_id IS NOT NULL AND num_nonnulls(beneficiario_contato_id, beneficiario_funcionario_id, beneficiario_equipe_id) <= 1
           END),
    -- RT é de arquiteto (contato); comissão é de funcionário ou equipe
    CHECK ((tipo = 'rt_arquiteto' AND beneficiario_funcionario_id IS NULL AND beneficiario_equipe_id IS NULL)
        OR (tipo = 'comissao' AND beneficiario_contato_id IS NULL))
);

-- ===================================================================== títulos (a obrigação)
CREATE TABLE public.financeiro_titulos (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    natureza                 public.fin_natureza NOT NULL,
    origem_tipo              public.fin_origem   NOT NULL,
    origem_seq               smallint NOT NULL DEFAULT 1,
    -- UMA chave estrangeira real por origem (exatamente a que combina com origem_tipo)
    orcamento_id             uuid REFERENCES public.orcamentos(id),
    pedido_compra_id         uuid REFERENCES public.pedidos_compra(id),
    nota_fiscal_compra_id    uuid REFERENCES public.notas_fiscais_compra(id),
    folha_pagamento_id       uuid REFERENCES public.folha_pagamento(id),
    custo_recorrente_id      uuid REFERENCES public.custos_recorrentes(id),
    regra_repasse_id         uuid REFERENCES public.financeiro_regras_repasse(id),
    especie                  public.fin_especie NOT NULL,
    empresa_id               uuid NOT NULL REFERENCES public.empresas(id),
    perfil                   text CHECK (perfil IN ('ribeirao', 'sao_paulo')),
    contato_id               uuid REFERENCES public.contatos(id),
    funcionario_id           uuid REFERENCES public.funcionarios(id),
    plano_contas_id          uuid REFERENCES public.plano_de_contas(id),
    projeto_id               uuid REFERENCES public.projetos(id),
    documento                text,
    descricao                text,
    substitui_titulo_id      uuid REFERENCES public.financeiro_titulos(id),
    titulo_base_id           uuid REFERENCES public.financeiro_titulos(id),   -- a venda que gerou um RT/comissão
    titulo_compensado_id     uuid REFERENCES public.financeiro_titulos(id),   -- crédito de devolução -> venda de origem
    cancelado_em             timestamptz,
    cancelado_por            uuid,
    motivo_cancelamento      text,
    legado_cod_duplicata     integer,        -- número da Connect: SÓ rastreio, imutável
    criado_em                timestamptz NOT NULL DEFAULT now(),
    criado_por               uuid,
    CHECK (num_nonnulls(contato_id, funcionario_id) <= 1),
    CHECK (id <> substitui_titulo_id AND id <> titulo_base_id AND id <> titulo_compensado_id),
    CHECK ((cancelado_em IS NULL) = (motivo_cancelamento IS NULL)),
    -- origem: a coluna certa preenchida e só ela
    CHECK (num_nonnulls(orcamento_id, pedido_compra_id, nota_fiscal_compra_id, folha_pagamento_id, custo_recorrente_id, regra_repasse_id)
           = CASE WHEN origem_tipo IN ('manual', 'legado_connect', 'adiantamento') THEN 0 ELSE 1 END),
    CHECK (CASE origem_tipo
             WHEN 'orcamento'          THEN orcamento_id IS NOT NULL
             WHEN 'permuta'            THEN orcamento_id IS NOT NULL
             WHEN 'devolucao'          THEN orcamento_id IS NOT NULL
             WHEN 'pedido_compra'      THEN pedido_compra_id IS NOT NULL
             WHEN 'nota_fiscal_compra' THEN nota_fiscal_compra_id IS NOT NULL
             WHEN 'folha'              THEN folha_pagamento_id IS NOT NULL
             WHEN 'custo_recorrente'   THEN custo_recorrente_id IS NOT NULL
             WHEN 'regra_repasse'      THEN regra_repasse_id IS NOT NULL AND titulo_base_id IS NOT NULL
             ELSE true END),
    -- nativo exige plano de contas; só o legado da Connect pode ficar sem (vira pendência)
    CHECK (origem_tipo = 'legado_connect' OR plano_contas_id IS NOT NULL),
    CHECK (origem_tipo = 'legado_connect' OR legado_cod_duplicata IS NULL),
    CHECK (origem_tipo <> 'legado_connect' OR legado_cod_duplicata IS NOT NULL),
    -- natureza coerente com a origem
    CHECK (CASE origem_tipo
             WHEN 'orcamento'          THEN natureza = 'receber'
             WHEN 'devolucao'          THEN natureza = 'receber'
             WHEN 'permuta'            THEN natureza = 'pagar'
             WHEN 'pedido_compra'      THEN natureza = 'pagar'
             WHEN 'nota_fiscal_compra' THEN natureza = 'pagar'
             WHEN 'folha'              THEN natureza = 'pagar'
             WHEN 'custo_recorrente'   THEN natureza = 'pagar'
             WHEN 'regra_repasse'      THEN natureza = 'pagar'
             ELSE true END),
    -- salário e comissão são de funcionário; RT é de arquiteto (contato)
    CHECK (especie NOT IN ('salario', 'comissao') OR funcionario_id IS NOT NULL OR origem_tipo = 'legado_connect'),
    CHECK (especie <> 'rt_arquiteto' OR contato_id IS NOT NULL OR origem_tipo = 'legado_connect')
);
-- idempotência: a mesma origem não gera dois títulos
CREATE UNIQUE INDEX financeiro_titulos_uq_orcamento ON public.financeiro_titulos (origem_tipo, orcamento_id, origem_seq) WHERE orcamento_id IS NOT NULL;
CREATE UNIQUE INDEX financeiro_titulos_uq_pedido    ON public.financeiro_titulos (origem_seq, pedido_compra_id) WHERE pedido_compra_id IS NOT NULL;
CREATE UNIQUE INDEX financeiro_titulos_uq_nota      ON public.financeiro_titulos (origem_seq, nota_fiscal_compra_id) WHERE nota_fiscal_compra_id IS NOT NULL;
CREATE UNIQUE INDEX financeiro_titulos_uq_folha     ON public.financeiro_titulos (origem_seq, folha_pagamento_id) WHERE folha_pagamento_id IS NOT NULL;
CREATE UNIQUE INDEX financeiro_titulos_uq_recorrente ON public.financeiro_titulos (origem_seq, custo_recorrente_id) WHERE custo_recorrente_id IS NOT NULL;
CREATE UNIQUE INDEX financeiro_titulos_uq_repasse   ON public.financeiro_titulos (regra_repasse_id, titulo_base_id, origem_seq) WHERE regra_repasse_id IS NOT NULL;
-- a duplicata da Connect (mesma chave do legado: empresa + número + natureza) existe uma vez só
CREATE UNIQUE INDEX financeiro_titulos_uq_legado    ON public.financeiro_titulos (empresa_id, legado_cod_duplicata, natureza) WHERE legado_cod_duplicata IS NOT NULL;
CREATE INDEX financeiro_titulos_contato_idx  ON public.financeiro_titulos (contato_id) WHERE contato_id IS NOT NULL;
CREATE INDEX financeiro_titulos_projeto_idx  ON public.financeiro_titulos (projeto_id) WHERE projeto_id IS NOT NULL;
CREATE INDEX financeiro_titulos_base_idx     ON public.financeiro_titulos (titulo_base_id) WHERE titulo_base_id IS NOT NULL;

-- ===================================================================== parcelas (a agenda)
CREATE TABLE public.financeiro_parcelas (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo_id                   uuid NOT NULL REFERENCES public.financeiro_titulos(id),
    numero                      integer NOT NULL CHECK (numero >= 1),
    vencimento                  date NOT NULL,
    valor                       numeric(14,2) NOT NULL,
    situacao                    public.fin_situacao NOT NULL,
    confirmada_em               timestamptz,
    confirmada_por              uuid,
    forma_prevista              text,
    valor_liquidado             numeric(14,2) NOT NULL DEFAULT 0,   -- mantido pelo gatilho das baixas; ninguém digita
    legado_cod_itens_duplicata  integer,                            -- código da parcela na Connect: SÓ rastreio, imutável
    observacao                  text,
    criado_em                   timestamptz NOT NULL DEFAULT now(),
    criado_por                  uuid,
    UNIQUE (titulo_id, numero),
    CHECK (situacao <> 'firme' OR confirmada_em IS NOT NULL OR legado_cod_itens_duplicata IS NOT NULL)
);
CREATE INDEX financeiro_parcelas_venc_idx ON public.financeiro_parcelas (vencimento);
CREATE INDEX financeiro_parcelas_situacao_idx ON public.financeiro_parcelas (situacao);
CREATE UNIQUE INDEX financeiro_parcelas_uq_legado ON public.financeiro_parcelas (legado_cod_itens_duplicata, titulo_id) WHERE legado_cod_itens_duplicata IS NOT NULL;

-- ===================================================================== cobranças (boleto, Pix, cartão…)
CREATE TABLE public.financeiro_cobrancas (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    parcela_id        uuid NOT NULL REFERENCES public.financeiro_parcelas(id),
    sentido           public.fin_natureza NOT NULL,
    meio              public.fin_cobranca_meio NOT NULL,
    nosso_numero      text,
    linha_digitavel   text,
    remessa_sequencial integer,
    conta_bancaria_id uuid REFERENCES public.contas_bancarias(id),
    status_banco      text NOT NULL DEFAULT 'pendente_registro',
    valor             numeric(14,2) NOT NULL CHECK (valor >= 0),
    vencimento        date NOT NULL,
    criado_em         timestamptz NOT NULL DEFAULT now(),
    criado_por        uuid
);
CREATE UNIQUE INDEX financeiro_cobrancas_uq_nosso ON public.financeiro_cobrancas (conta_bancaria_id, nosso_numero) WHERE nosso_numero IS NOT NULL;
CREATE INDEX financeiro_cobrancas_parcela_idx ON public.financeiro_cobrancas (parcela_id);

-- ===================================================================== baixas (o fato real; histórico de contas pagas/recebidas)
CREATE TABLE public.financeiro_baixas (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    parcela_id        uuid NOT NULL REFERENCES public.financeiro_parcelas(id),
    tipo              public.fin_baixa_tipo NOT NULL,
    data              date NOT NULL,
    valor             numeric(14,2) NOT NULL CHECK (valor >= 0),    -- valor LIQUIDADO por esta baixa (na baixa interna: o valor que ela quita)
    juros             numeric(14,2) NOT NULL DEFAULT 0 CHECK (juros >= 0),
    multa             numeric(14,2) NOT NULL DEFAULT 0 CHECK (multa >= 0),
    desconto          numeric(14,2) NOT NULL DEFAULT 0 CHECK (desconto >= 0),
    forma             text,
    conta_bancaria_id uuid REFERENCES public.contas_bancarias(id),
    empresa_pagadora_id uuid REFERENCES public.empresas(id),        -- quando a conta é de outra empresa (pergunta 27)
    cobranca_id       uuid REFERENCES public.financeiro_cobrancas(id),
    comprovante_url   text,
    motivo            text,
    origem_baixa      text NOT NULL CHECK (origem_baixa IN ('manual', 'retorno_bancario', 'antecipacao', 'legado')),
    estorno_de        uuid REFERENCES public.financeiro_baixas(id),
    criado_em         timestamptz NOT NULL DEFAULT now(),
    criado_por        uuid,
    movimenta_caixa   boolean GENERATED ALWAYS AS (tipo IN ('recebimento', 'pagamento')) STORED,
    -- dinheiro de verdade exige conta bancária (só o legado pode estar sem, e então vira pendência)
    CHECK (NOT movimenta_caixa OR conta_bancaria_id IS NOT NULL OR origem_baixa = 'legado'),
    -- tipos sem dinheiro exigem motivo
    CHECK (tipo NOT IN ('baixa_interna', 'abatimento', 'renegociacao', 'compensacao', 'estorno') OR length(btrim(coalesce(motivo, ''))) > 0 OR origem_baixa = 'legado'),
    CHECK ((tipo = 'estorno') = (estorno_de IS NOT NULL)),
    -- só baixa interna e abatimento podem ter valor zero ("Acordo Valor Zerado")
    CHECK (valor > 0 OR tipo IN ('baixa_interna', 'abatimento'))
);
CREATE INDEX financeiro_baixas_parcela_idx ON public.financeiro_baixas (parcela_id);
CREATE INDEX financeiro_baixas_data_idx    ON public.financeiro_baixas (data);

-- ===================================================================== renegociações (acordo / "Duplicata Gerada")
CREATE TABLE public.financeiro_renegociacoes (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    parcela_origem_id  uuid NOT NULL REFERENCES public.financeiro_parcelas(id),
    parcela_nova_id    uuid NOT NULL REFERENCES public.financeiro_parcelas(id),
    grupo_acordo       integer,                         -- agrupamento "acordo" da Connect (legado)
    criado_em          timestamptz NOT NULL DEFAULT now(),
    criado_por         uuid,
    CHECK (parcela_origem_id <> parcela_nova_id),
    UNIQUE (parcela_origem_id, parcela_nova_id)
);

-- ===================================================================== fila de pendências ("nada fica aberto")
CREATE TABLE public.financeiro_pendencias (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo_id      uuid REFERENCES public.financeiro_titulos(id),
    parcela_id     uuid REFERENCES public.financeiro_parcelas(id),
    baixa_id       uuid REFERENCES public.financeiro_baixas(id),
    tipo           text NOT NULL,
    descricao      text,
    status         public.fin_pendencia_status NOT NULL DEFAULT 'aberta',
    motivo_aceite  text,
    aceita_por     uuid,
    aceita_em      timestamptz,
    responsavel    text,
    resolvida_por  uuid,
    resolvida_em   timestamptz,
    criada_em      timestamptz NOT NULL DEFAULT now(),
    CHECK (num_nonnulls(titulo_id, parcela_id, baixa_id) >= 1),
    CHECK (status <> 'aceita' OR (length(btrim(coalesce(motivo_aceite, ''))) > 0 AND aceita_por IS NOT NULL AND aceita_em IS NOT NULL)),
    CHECK (status <> 'resolvida' OR resolvida_em IS NOT NULL)
);
CREATE INDEX financeiro_pendencias_status_idx ON public.financeiro_pendencias (status, tipo);

-- ===================================================================== de-para de ids (antigo -> novo)
CREATE TABLE public.financeiro_legado_ids (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tabela_antiga  text NOT NULL,
    id_antigo      uuid NOT NULL,
    tabela_nova    text NOT NULL,
    id_novo        uuid NOT NULL,
    criado_em      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tabela_antiga, id_antigo)
);

-- ===================================================================== histórico financeiro PERMANENTE
CREATE TABLE public.financeiro_eventos (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tabela      text NOT NULL,
    registro_id uuid NOT NULL,
    operacao    text NOT NULL CHECK (operacao IN ('INSERT', 'UPDATE', 'DELETE')),
    usuario_id  uuid,
    antes       jsonb,
    depois      jsonb,
    criado_em   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX financeiro_eventos_registro_idx ON public.financeiro_eventos (tabela, registro_id);

CREATE OR REPLACE FUNCTION public.financeiro_registrar_evento() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
BEGIN
    INSERT INTO public.financeiro_eventos (tabela, registro_id, operacao, usuario_id, antes, depois)
    VALUES (TG_TABLE_NAME,
            coalesce((CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END), gen_random_uuid()),
            TG_OP, auth.uid(),
            CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) END,
            CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) END);
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $f$;

DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['financeiro_titulos', 'financeiro_parcelas', 'financeiro_baixas', 'financeiro_cobrancas',
                             'financeiro_renegociacoes', 'financeiro_pendencias', 'financeiro_regras_repasse'] LOOP
        EXECUTE format('CREATE TRIGGER trg_%s_evento AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.financeiro_registrar_evento()', t, t);
    END LOOP;
END $$;

-- ===================================================================== gatilhos de integridade
-- (a) ids da Connect são imutáveis (uma função por tabela: o campo só existe em uma delas)
CREATE OR REPLACE FUNCTION public.financeiro_titulo_legado_imutavel() RETURNS trigger
LANGUAGE plpgsql SET search_path TO 'public' AS $f$
BEGIN
    IF NEW.legado_cod_duplicata IS DISTINCT FROM OLD.legado_cod_duplicata THEN
        RAISE EXCEPTION 'legado_cod_duplicata é imutável.' USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END $f$;
CREATE OR REPLACE FUNCTION public.financeiro_parcela_legado_imutavel() RETURNS trigger
LANGUAGE plpgsql SET search_path TO 'public' AS $f$
BEGIN
    IF NEW.legado_cod_itens_duplicata IS DISTINCT FROM OLD.legado_cod_itens_duplicata THEN
        RAISE EXCEPTION 'legado_cod_itens_duplicata é imutável.' USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END $f$;
CREATE TRIGGER trg_titulos_legado_imutavel  BEFORE UPDATE ON public.financeiro_titulos  FOR EACH ROW EXECUTE FUNCTION public.financeiro_titulo_legado_imutavel();
CREATE TRIGGER trg_parcelas_legado_imutavel BEFORE UPDATE ON public.financeiro_parcelas FOR EACH ROW EXECUTE FUNCTION public.financeiro_parcela_legado_imutavel();

-- (b) baixa só entra em parcela firme (ou prevista que acabou de ser confirmada); nunca em cancelada/substituída/renegociada
CREATE OR REPLACE FUNCTION public.financeiro_baixa_valida() RETURNS trigger
LANGUAGE plpgsql SET search_path TO 'public' AS $f$
DECLARE v_sit public.fin_situacao;
BEGIN
    SELECT situacao INTO v_sit FROM public.financeiro_parcelas WHERE id = NEW.parcela_id;
    IF v_sit IS DISTINCT FROM 'firme' THEN
        RAISE EXCEPTION 'Baixa só em parcela firme (situação atual: %).', coalesce(v_sit::text, 'inexistente') USING ERRCODE = 'P0001';
    END IF;
    IF NEW.tipo = 'estorno' THEN
        IF NOT EXISTS (SELECT 1 FROM public.financeiro_baixas b WHERE b.id = NEW.estorno_de AND b.parcela_id = NEW.parcela_id AND b.tipo <> 'estorno') THEN
            RAISE EXCEPTION 'Estorno precisa apontar para uma baixa da mesma parcela.' USING ERRCODE = 'P0001';
        END IF;
    END IF;
    RETURN NEW;
END $f$;
CREATE TRIGGER trg_baixa_valida BEFORE INSERT ON public.financeiro_baixas FOR EACH ROW EXECUTE FUNCTION public.financeiro_baixa_valida();

-- (c) baixa nunca é editada nem apagada: errou, estorna
CREATE OR REPLACE FUNCTION public.financeiro_baixa_imutavel() RETURNS trigger
LANGUAGE plpgsql SET search_path TO 'public' AS $f$
BEGIN
    RAISE EXCEPTION 'Baixa não pode ser alterada nem apagada: registre um estorno.' USING ERRCODE = 'P0001';
END $f$;
CREATE TRIGGER trg_baixa_imutavel BEFORE UPDATE OR DELETE ON public.financeiro_baixas FOR EACH ROW EXECUTE FUNCTION public.financeiro_baixa_imutavel();

-- (d) valor liquidado da parcela = baixas (todas as que quitam) - estornos; ninguém digita
CREATE OR REPLACE FUNCTION public.financeiro_recalcula_liquidado() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
BEGIN
    UPDATE public.financeiro_parcelas p
       SET valor_liquidado = coalesce((SELECT sum(CASE WHEN b.tipo = 'estorno' THEN -b.valor ELSE b.valor END) FROM public.financeiro_baixas b WHERE b.parcela_id = NEW.parcela_id), 0)
     WHERE p.id = NEW.parcela_id;
    RETURN NULL;
END $f$;
CREATE TRIGGER trg_baixa_recalcula AFTER INSERT ON public.financeiro_baixas FOR EACH ROW EXECUTE FUNCTION public.financeiro_recalcula_liquidado();

-- (e) valor_liquidado só muda pelo gatilho acima
CREATE OR REPLACE FUNCTION public.financeiro_parcela_liquidado_travado() RETURNS trigger
LANGUAGE plpgsql SET search_path TO 'public' AS $f$
BEGIN
    IF NEW.valor_liquidado IS DISTINCT FROM OLD.valor_liquidado AND pg_trigger_depth() < 2 THEN
        RAISE EXCEPTION 'valor_liquidado é calculado pelas baixas e não pode ser alterado à mão.' USING ERRCODE = 'P0001';
    END IF;
    IF OLD.valor_liquidado <> 0 AND NEW.valor IS DISTINCT FROM OLD.valor THEN
        RAISE EXCEPTION 'Parcela com baixa não pode mudar de valor: estorne a baixa ou renegocie.' USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END $f$;
CREATE TRIGGER trg_parcela_liquidado_travado BEFORE UPDATE ON public.financeiro_parcelas FOR EACH ROW EXECUTE FUNCTION public.financeiro_parcela_liquidado_travado();

-- ===================================================================== segurança: RLS, sem gravação direta, folha só RH
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['financeiro_titulos', 'financeiro_parcelas', 'financeiro_baixas', 'financeiro_cobrancas', 'financeiro_renegociacoes',
                             'financeiro_pendencias', 'financeiro_regras_repasse', 'financeiro_legado_ids', 'financeiro_eventos'] LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon, authenticated', t);
        EXECUTE format('GRANT SELECT ON public.%I TO authenticated', t);
    END LOOP;
END $$;

-- títulos: financeiro vê tudo MENOS salário/comissão; esses só o RH
CREATE POLICY fin_titulos_select ON public.financeiro_titulos FOR SELECT TO authenticated USING (
    (especie NOT IN ('salario', 'comissao') AND (SELECT public.pode_acessar_sistema('financeiro')))
    OR (SELECT public.pode_acessar_sistema('rh')));
-- parcelas, baixas, cobranças, renegociações e pendências herdam a visibilidade do título (a subconsulta passa pelo RLS do título)
CREATE POLICY fin_parcelas_select ON public.financeiro_parcelas FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.financeiro_titulos t WHERE t.id = titulo_id));
CREATE POLICY fin_baixas_select ON public.financeiro_baixas FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.financeiro_parcelas p WHERE p.id = parcela_id));
CREATE POLICY fin_cobrancas_select ON public.financeiro_cobrancas FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.financeiro_parcelas p WHERE p.id = parcela_id));
CREATE POLICY fin_renegociacoes_select ON public.financeiro_renegociacoes FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.financeiro_parcelas p WHERE p.id = parcela_origem_id));
CREATE POLICY fin_pendencias_select ON public.financeiro_pendencias FOR SELECT TO authenticated
    USING ((SELECT public.pode_acessar_sistema('financeiro'))
           AND (titulo_id IS NULL OR EXISTS (SELECT 1 FROM public.financeiro_titulos t WHERE t.id = titulo_id)));
-- regras de repasse: financeiro e RH
CREATE POLICY fin_regras_select ON public.financeiro_regras_repasse FOR SELECT TO authenticated
    USING ((SELECT public.pode_acessar_sistema('financeiro')) OR (SELECT public.pode_acessar_sistema('rh')));
-- de-para e histórico: só financeiro
CREATE POLICY fin_legado_ids_select ON public.financeiro_legado_ids FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('financeiro')));
CREATE POLICY fin_eventos_select ON public.financeiro_eventos FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('financeiro')));

REVOKE ALL ON FUNCTION public.financeiro_registrar_evento(), public.financeiro_titulo_legado_imutavel(), public.financeiro_parcela_legado_imutavel(), public.financeiro_baixa_valida(),
                       public.financeiro_baixa_imutavel(), public.financeiro_recalcula_liquidado(), public.financeiro_parcela_liquidado_travado() FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.financeiro_titulos  IS 'SPEC-258: a obrigação (conta a receber/a pagar). Gravação só por funções (Fase 1B).';
COMMENT ON TABLE public.financeiro_parcelas IS 'SPEC-258: a agenda. valor_liquidado é calculado pelas baixas.';
COMMENT ON TABLE public.financeiro_baixas   IS 'SPEC-258: o fato real (pago/recebido) e o histórico de contas pagas; imutável (errou, estorna).';
COMMENT ON TABLE public.financeiro_eventos  IS 'SPEC-258: histórico financeiro PERMANENTE (não entra no expurgo de 12 meses da auditoria geral).';
