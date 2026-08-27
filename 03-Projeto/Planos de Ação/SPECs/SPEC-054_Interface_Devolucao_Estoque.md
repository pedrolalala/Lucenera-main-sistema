    ---
    titulo: "SPEC-054 — Interface de Devolução de Estoque (linhas manuais por setor de origem)"
    status: implementado, migration aplicada no Supabase real (2026-07-27) e frontend publicado em produção (Skip) em 2026-08-04 — pendências de governança herdadas da SPEC-015 seguem em aberto; falta homologação no navegador
    data_ultima_modificacao: 2026-07-27
    sistemas_envolvidos:
    - Compras (compras-lucenera-3o23t98ee)
    - Supabase (banco central)
    dependencias:
    - SPEC-010 (estoque_saldos_projeto_item)
    - SPEC-011 (transferência de reserva)
    - SPEC-012 (entrega futura / necessidade de compra)
    - SPEC-015 (devolução de estoque — backend já aplicado, sem frontend)
    - SPEC-040 (Necessidade de Compra por L Fixo / projeto_item_id)
    ---

    # SPEC-054 — Interface de Devolução de Estoque

    > Origem: reunião com Vinicius em 27/07/2026, `02-Reunioes/12. lucenera (Vinicius) - 27.07.2026_ correcoes necessarias/Reunião.04.txt`. Desmembrada de uma SPEC única por decisão do usuário em 2026-07-27.

    ## Checklist de Ação

    ### Banco

    - [x] Ler o texto real de `registrar_devolucao_projeto_item` e das colunas de `estoque_saldos_projeto_item`/`devolucoes_estoque` direto no Supabase real (`pg_get_functiondef`/`information_schema.columns`) — feito em 2026-07-27, texto exato registrado na seção "Desenho da nova RPC" abaixo.
    - [x] Criar a nova RPC `registrar_devolucao_projeto_item_setor` (SQL completo já redigido na seção "Desenho da nova RPC") para aceitar um **setor de origem explícito** por chamada (`p_setor_origem: 'entrega_futura' | 'reserva' | 'entregue'`), em vez de sempre fazer o rateio em cascata automático — decisão do usuário (2026-07-27): a tela exige lançamento manual de uma linha por setor, replicando o processo que Vinicius descreveu. Migration redigida em `supabase/db/migrations/20260727_067_spec054_devolucao_por_setor/001_registrar_devolucao_projeto_item_setor.sql` (com o `GRANT EXECUTE` da revisão), **aplicada no Supabase real em 2026-07-27** — confirmado que a função existe e `authenticated` tem `EXECUTE`.
    - [x] A nova versão da RPC deve: validar que o setor informado tem saldo suficiente (`RAISE EXCEPTION` claro se não tiver); subtrair só daquele setor; se o setor for `entregue`, **não** decrementar a coluna de entregue (é histórico, conforme regra já validada na SPEC-015) — só incrementar `q_devolvida`; se o setor for `reserva` ou `entregue`, incrementar estoque físico disponível; se o setor for `entrega_futura`, só reduzir a necessidade de compra (efeito "virtual", sem entrada física), conforme já implementado. Texto copiado literalmente da SPEC, sem alteração.
    - [x] Manter a função/RPC original (`registrar_devolucao_projeto_item` com rateio automático) intacta — confirmado sem consumidor em nenhum dos 8 sistemas; a migration não a toca.
    - [x] Atualizar `supabase/db/domains/estoque_compras.md`: removida a afirmação desatualizada de que `devolucoes_estoque`/`transferencias_estoque` "ainda não existem"; documentada a nova RPC/parâmetro.

    ### Frontend (`compras-lucenera-3o23t98ee`)

    - [x] Nova aba de Devolução, dentro da página que já contém `NecessidadeCompraPorItemTab.tsx` (`src/pages/NecessidadeCompra.tsx`, terceira `TabsTrigger`/`TabsContent` "Devolução", ao lado de "Por Produto" e "Por Item de Orçamento"), listando itens com saldo aberto (`q_entrega_futura + q_reserva + q_entregue > 0`, equivalente client-side a "pelo menos um dos 3 > 0" já que nenhuma das colunas é negativa) via `vw_estoque_saldos_projeto_item`. Componente novo: `src/components/compra/DevolucaoEstoqueTab.tsx`.
    - [x] Para cada item, exibidos os 3 saldos por setor (Entrega Futura / Reserva / Entregue) lado a lado — colunas na lista e cards no topo do modal de lançamento.
    - [x] Interface de lançamento em **linhas múltiplas por item**: modal `src/components/compra/ModalDevolucaoItem.tsx`, aberto a partir do botão "Devolver" de cada linha da lista — usuário adiciona 1+ linhas para o item, cada linha com `setor_origem` (select, com opções sem saldo desabilitadas) + `quantidade` + `motivo` (texto livre opcional); ao confirmar, dispara uma chamada de `registrarDevolucaoPorSetor` por linha (não atômico entre linhas, conforme decisão da SPEC). Linhas com falha permanecem no modal para nova tentativa; linhas com sucesso são removidas e a lista é recarregada.
    - [x] Validação client-side: soma das quantidades lançadas na mesma sessão, por setor, não pode exceder o saldo daquele setor — bloqueia o botão de confirmar e mostra aviso inline por linha quando estourado.
    - [x] Novo serviço `compras-lucenera-3o23t98ee/src/services/devolucoes.ts`, seguindo o mesmo padrão de `services/necessidade-compra-item.ts` (busca debounced no componente, paginação em lote de 500, `applySearchFilter` com o mesmo tratamento de `produto_codigo` `integer`).

    ### Passos manuais do usuário

    - [x] Aplicar a migration `supabase/db/migrations/20260727_067_spec054_devolucao_por_setor/001_registrar_devolucao_projeto_item_setor.sql` no Supabase real — aplicada em 2026-07-27.
    - [ ] Definir quem pode registrar uma devolução (papel/permissão) — hoje a RPC está aberta a qualquer `authenticated`, sem aprovação. Pendência herdada da SPEC-015, nunca resolvida.
    - [ ] Definir o efeito financeiro de `devolucoes_estoque.gera_credito_financeiro` — crédito, reembolso, abatimento de parcela futura, ou só registro operacional. Pendência herdada da SPEC-015.
    - [ ] Definir a tela/ação de Logística para marcar uma devolução `aguardando_coleta` como `coletada`, e o que isso deve fazer no estoque físico quando a devolução veio de `q_entregue` (hoje a RPC não incrementa `estoque_itens` para essa parte). Validar com Débora/Vitória (Compras) e Logística onde a tela deve morar.
    - [ ] Homologação manual no navegador: registrar devolução de um item com saldo em 1, 2 e 3 setores simultaneamente, conferindo o resultado em `estoque_saldos_projeto_item` e em `vw_necessidade_compra`.

    ## Objetivo

    Construir a interface de devolução de estoque que hoje **não existe em nenhum sistema**, seguindo a regra de negócio explicada por Vinicius: quando a quantidade a devolver está espalhada entre mais de um setor (Entrega Futura / Reserva / Entregue), o usuário lança uma linha manual por setor de origem, informando explicitamente de onde cada parte da devolução sai.

    ## Decisões aprovadas

    - **Fluxo de lançamento (decisão do usuário, 2026-07-27)**: linhas manuais por setor de origem, não rateio automático. O usuário decide explicitamente de qual setor cada parte da devolução sai, replicando o processo que Vinicius descreveu na reunião. Isso exige estender/criar uma RPC que aceite o setor de origem como parâmetro explícito, em vez de reaproveitar sem alteração a RPC `registrar_devolucao_projeto_item` já existente (que faz cascata automática Entrega Futura → Reserva → Entregue).
    - A regra de efeito por setor já está validada e não muda: subtrair de `entregue` não decrementa a quantidade entregue (é histórico); devolução de `reserva`/`entregue` entra fisicamente no estoque; devolução de `entrega_futura` só reduz a necessidade de compra virtualmente, sem entrada física.

    ## Definição da SPEC

    ### Estado atual (achado central)

    A regra de negócio inteira que Vinicius narrou já está implementada e testada no banco desde 07/07/2026 (SPEC-010/012/015):

    - Tabela `devolucoes_estoque` e RPC `registrar_devolucao_projeto_item(p_projeto_item_id, p_quantidade, p_motivo)` confirmadas presentes em `supabase/db/current/01_schema_full.sql`.
    - A RPC atual já faz o rateio `Entrega Futura → Reserva → Entregue` automaticamente numa única chamada — o exemplo testado e documentado no "Realizado" da SPEC-015 (`q_entrega_futura=10, q_reserva=10, q_entregue=20`, devolução de 40 → resultado `10/10/20`) é idêntico ao exemplo que Vinicius deu na reunião.
    - **Nenhum frontend em nenhum sistema consome essa RPC ou essa tabela hoje.**

    Por decisão do usuário, esta SPEC não reaproveita o rateio automático como está — precisa de uma nova via de entrada que aceite o setor de origem explicitamente por linha, mantendo as mesmas regras de efeito (histórico do `entregue`, entrada física vs. virtual) já validadas.

    ### Desenho da nova RPC (confirmado contra o texto real do banco em 2026-07-27, via `pg_get_functiondef`/`information_schema.columns`)

    Texto real de `registrar_devolucao_projeto_item(p_projeto_item_id, p_quantidade, p_motivo)` (a versão de rateio automático, que permanece intocada) e das colunas reais de `estoque_saldos_projeto_item` (`q_reserva`, `q_entrega_futura`, `q_ag_separar`, `q_separado`, `q_entregue`, `q_devolvida`, `q_transferida_saida`, `status_operacional`) e `devolucoes_estoque` (`quantidade`, `qtd_de_entrega_futura`, `qtd_de_reserva`, `qtd_de_entregue`, `status`, `motivo`, `gera_credito_financeiro`, `solicitado_por`, `aprovado_por`) já foram lidos — não é necessário reler antes de implementar.

    Nova função, mesmo padrão de segurança/estrutura da original, mas recebendo o setor de origem explicitamente em vez de fazer cascata:

    ```sql
    CREATE OR REPLACE FUNCTION public.registrar_devolucao_projeto_item_setor(
    p_projeto_item_id uuid,
    p_setor_origem text, -- 'entrega_futura' | 'reserva' | 'entregue'
    p_quantidade numeric,
    p_motivo text DEFAULT NULL
    )
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO 'public'
    AS $function$
    DECLARE
        v_saldo        public.estoque_saldos_projeto_item%ROWTYPE;
        v_produto_id   uuid;
        v_saldo_setor  numeric(10,3);
        v_status       text;
        v_devolucao_id uuid;
    BEGIN
        IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
            RAISE EXCEPTION 'Quantidade deve ser maior que zero.' USING ERRCODE = 'P0001';
        END IF;

        IF p_setor_origem NOT IN ('entrega_futura', 'reserva', 'entregue') THEN
            RAISE EXCEPTION 'Setor de origem inválido: %. Use entrega_futura, reserva ou entregue.', p_setor_origem
                USING ERRCODE = 'P0001';
        END IF;

        SELECT produto_id INTO v_produto_id FROM public.projeto_itens WHERE id = p_projeto_item_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Item de projeto % nao encontrado.', p_projeto_item_id USING ERRCODE = 'P0001';
        END IF;

        SELECT * INTO v_saldo
        FROM public.estoque_saldos_projeto_item
        WHERE projeto_item_id = p_projeto_item_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Item de projeto % nao possui saldo operacional (estoque_saldos_projeto_item).', p_projeto_item_id USING ERRCODE = 'P0001';
        END IF;

        v_saldo_setor := CASE p_setor_origem
            WHEN 'entrega_futura' THEN v_saldo.q_entrega_futura
            WHEN 'reserva' THEN v_saldo.q_reserva
            WHEN 'entregue' THEN v_saldo.q_entregue
        END;

        IF p_quantidade > v_saldo_setor THEN
            RAISE EXCEPTION 'Quantidade de devolucao (%) excede o saldo do setor % (%).',
                p_quantidade, p_setor_origem, v_saldo_setor USING ERRCODE = 'P0001';
        END IF;

        -- q_entregue nunca decrementa (histórico), mesmo quando o setor de origem é 'entregue'.
        UPDATE public.estoque_saldos_projeto_item
        SET q_entrega_futura = q_entrega_futura - CASE WHEN p_setor_origem = 'entrega_futura' THEN p_quantidade ELSE 0 END,
            q_reserva = q_reserva - CASE WHEN p_setor_origem = 'reserva' THEN p_quantidade ELSE 0 END,
            q_devolvida = q_devolvida + p_quantidade,
            atualizado_em = now()
        WHERE projeto_item_id = p_projeto_item_id;

        -- Mesma regra RN-08 da função original: quantidade_reservada só é liberada
        -- pela parte que veio de entrega_futura ou reserva.
        IF p_setor_origem IN ('entrega_futura', 'reserva') AND v_produto_id IS NOT NULL THEN
            UPDATE public.estoque_itens
            SET quantidade_reservada = GREATEST(quantidade_reservada - p_quantidade, 0)
            WHERE produto_id = v_produto_id
            AND local = 'Estoque'::public.estoque_local;
        END IF;

        v_status := CASE WHEN p_setor_origem = 'entregue' THEN 'aguardando_coleta' ELSE 'registrada' END;

        INSERT INTO public.devolucoes_estoque (
            projeto_item_id, quantidade, qtd_de_entrega_futura, qtd_de_reserva, qtd_de_entregue,
            status, motivo, solicitado_por
        ) VALUES (
            p_projeto_item_id, p_quantidade,
            CASE WHEN p_setor_origem = 'entrega_futura' THEN p_quantidade ELSE 0 END,
            CASE WHEN p_setor_origem = 'reserva' THEN p_quantidade ELSE 0 END,
            CASE WHEN p_setor_origem = 'entregue' THEN p_quantidade ELSE 0 END,
            v_status, p_motivo, auth.uid()
        )
        RETURNING id INTO v_devolucao_id;

        INSERT INTO public.estoque_movimentos_projeto_item
            (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
        VALUES
            (p_projeto_item_id, 'devolucao', p_quantidade, 'devolucao_estoque', v_devolucao_id, p_motivo, auth.uid());

        RETURN jsonb_build_object(
            'devolucao_id', v_devolucao_id,
            'status', v_status,
            'setor_origem', p_setor_origem,
            'quantidade', p_quantidade
        );
    END;
    $function$;
    ```

    Comportamento: valida saldo suficiente **no setor informado** (não no total, diferente da original); atualiza `estoque_saldos_projeto_item` subtraindo só daquele setor (`entregue` nunca decrementa, só soma em `q_devolvida`); libera `estoque_itens.quantidade_reservada` só para `entrega_futura`/`reserva`; registra uma linha em `devolucoes_estoque` por chamada (uma linha = uma linha lançada na UI = uma chamada da RPC). A função original `registrar_devolucao_projeto_item` (rateio automático) permanece intocada — não identificado nenhum outro consumidor dela nos 8 sistemas, mas mantida por segurança (sem custo em deixá-la).

    ### Análise de ecossistema

    - **Depende de**: `estoque_saldos_projeto_item`, `devolucoes_estoque`, `projeto_itens` (via `projeto_item_id`). Não depende de `orcamentos` diretamente (a granularidade é pós-aprovação, já em `projeto_itens`).
    - **Afeta**: Compras (`compras-lucenera-3o23t98ee`), onde a tela de Necessidade de Compra já opera na mesma granularidade. Afeta indiretamente Estoque (saldo físico) e, potencialmente, Financeiro (se o crédito financeiro for implementado — fora do escopo desta SPEC, ver Pendências).
    - **Migration antiga que contradiz o snapshot central**: `supabase/db/domains/estoque_compras.md` afirma que `devolucoes_estoque`/`transferencias_estoque` "ainda não existem" — desatualizado, achado desta SPEC.
    - **Exige atualizar `AI_DB_CONTEXT.md`**: sim, do sistema `compras-lucenera-3o23t98ee`, quando a tela for implementada.

    ## Critérios de aceite

    - Registrar devolução de um item com saldo 100% num único setor funciona igual ao comportamento já validado na SPEC-015.
    - Registrar devolução de um item com saldo em 2-3 setores exige e aceita lançamento de uma linha por setor, cada uma limitada ao saldo daquele setor.
    - `q_entregue` nunca diminui, mesmo quando uma linha de devolução tem origem `entregue`.
    - Uma linha com origem `entrega_futura` reduz `vw_necessidade_compra`/`vw_necessidade_compra_item_orcamento` imediatamente (view não materializada, sem necessidade de refresh).
    - Uma linha com origem `reserva` ou `entregue` incrementa o estoque físico disponível.

    ## Testes obrigatórios

    Verificação manual via SQL (sem suíte automatizada): recriar o exemplo exato de Vinicius (`10 entrega_futura / 10 reserva / 20 entregue`, devolução total de 20 em duas linhas de 10) e conferir o resultado final (`entrega_futura=0, reserva=0, q_devolvida=20, entregue=20`) bate com o que ele descreveu. Depois, testes manuais no navegador do fluxo completo.

    ## Realizado

    **2026-07-27 — implementação inicial (agente implementador):**

    - **Banco**: migration `supabase/db/migrations/20260727_067_spec054_devolucao_por_setor/001_registrar_devolucao_projeto_item_setor.sql` redigida com o texto exato da seção "Desenho da nova RPC" desta SPEC (copiado literalmente, sem reescrita), mais `COMMENT ON FUNCTION` citando a SPEC-054. **Aplicada no Supabase real em 2026-07-27** (após adicionar o `GRANT EXECUTE` que a revisão apontou faltando). `registrar_devolucao_projeto_item` (rateio automático, SPEC-015) permanece intocada.
    - **`supabase/db/domains/estoque_compras.md`**: removida a frase desatualizada "`transferencias_estoque`, `devolucoes_estoque` ... ainda não existem"; adicionado registro da SPEC-054 e da nova RPC.
    - **Frontend (`compras-lucenera-3o23t98ee`)**:
    - `src/services/devolucoes.ts` (novo) — `getItensComSaldoParaDevolucao()` (lê `vw_estoque_saldos_projeto_item`, filtro `status_operacional = 'ativo'` + `or(q_entrega_futura.gt.0,q_reserva.gt.0,q_entregue.gt.0)`, busca debounced/paginada igual ao Fluxo B) e `registrarDevolucaoPorSetor()` (chama a RPC nova via `supabase.rpc`).
    - `src/components/compra/DevolucaoEstoqueTab.tsx` (novo) — lista de itens com saldo aberto, mesmo padrão visual de `NecessidadeCompraPorItemTab.tsx` (busca, scroll infinito em lotes de 100, sem paginação de servidor).
    - `src/components/compra/ModalDevolucaoItem.tsx` (novo) — modal de lançamento em linhas múltiplas por item, com validação client-side de soma por setor, disparo de uma RPC por linha, e tratamento de erro individual por linha via toast (mensagem real do Postgres, ex. `Quantidade de devolucao (X) excede o saldo do setor Y (Z).`).
    - `src/pages/NecessidadeCompra.tsx` — nova aba "Devolução" (terceira `TabsTrigger`/`TabsContent`), ao lado de "Por Produto" e "Por Item de Orçamento". Escolha de local documentada: mesma página, por já operar na granularidade `projeto_item_id`, e por já ter o padrão de abas estabelecido pela SPEC-040.
    - Sem restrição de papel/permissão — mesmo padrão hoje aberto a qualquer `authenticated` (decisão já registrada nesta SPEC).
    - **Fora do escopo, não implementado** (conforme instrução explícita): nenhuma tela/ação de "confirmar coleta" (`status: aguardando_coleta -> coletada`), nenhum tratamento de `gera_credito_financeiro`.
    - **Verificações rodadas**: `npm run lint` (oxlint, sem warnings novos — só 2 pré-existentes em `Cotacoes.tsx`, não relacionados), `npm run format`/`format:check` (oxfmt, aplicado), `npm run build` (`vite build`, sucesso; warnings de bundle/CSS pré-existentes, não relacionados).
    - **Não testado**: golden path no navegador (login, abrir aba Devolução, lançar devolução em 1/2/3 setores, conferir saldo atualizado e `vw_necessidade_compra`) — depende da migration estar aplicada no Supabase real primeiro. Ver "Passos manuais do usuário" no Checklist.

    **2026-07-27 — revisão (agente revisor) e correção:**

    - Achado 🟡: a migration não tinha `GRANT EXECUTE ON FUNCTION ... TO authenticated` — sem isso, a chamada via `supabase.rpc(...)` falharia com "permission denied" assim que aplicada, quebrando a funcionalidade inteira. A omissão já vinha do texto original da seção "Desenho da nova RPC" desta SPEC (o implementador só copiou fielmente o que estava redigido). Corrigido: `GRANT EXECUTE ON FUNCTION public.registrar_devolucao_projeto_item_setor(uuid, text, numeric, text) TO authenticated;` adicionado ao final de `001_registrar_devolucao_projeto_item_setor.sql`.
    - Demais pontos revisados sem achado crítico: SQL da RPC idêntico caractere por caractere ao redigido na SPEC; `registrar_devolucao_projeto_item` (SPEC-015) intocada; `vw_estoque_saldos_projeto_item` confirmada real com as colunas usadas; validação client-side de soma por setor considera todas as linhas da sessão (não burlável); tratamento de erro por linha correto; nenhum escopo fora do combinado foi implementado. Achado 🔵 informativo (não corrigido, sem risco): os cards de saldo no modal não recarregam automaticamente após sucesso parcial de algumas linhas — só refletem o saldo real ao reabrir o modal; o backend revalida o saldo de qualquer forma, então não há risco de dado incorreto salvo.

    ## Pendências

    - [x] Ler o texto real de `registrar_devolucao_projeto_item` e das colunas de `estoque_saldos_projeto_item`/`devolucoes_estoque` — feito em 2026-07-27.
    - [ ] Definir quem pode registrar uma devolução (papel/permissão). Pendência herdada da SPEC-015, nunca resolvida — **implementação inicial segue sem restrição de papel** (mesmo padrão hoje aberto a qualquer `authenticated`, igual à RPC original), ajustável depois que a definição vier.
    - [ ] Definir o efeito financeiro de `gera_credito_financeiro` — **fora do escopo desta implementação**; a coluna já existe e continua sem nenhum fluxo associado, não é setada pela nova RPC (fica `NULL`/default).
    - [ ] Definir a tela/ação de Logística para marcar `status = 'coletada'` e o efeito físico no estoque quando a origem é `entregue` — **fora do escopo desta implementação**; a nova RPC marca `status = 'aguardando_coleta'` corretamente, mas a tela de "confirmar coleta" não faz parte desta SPEC.
    - [x] Confirmar se a RPC original (rateio automático) tem algum outro consumidor: nenhum frontend em nenhum dos 8 sistemas a consome hoje — mantida intocada por segurança, sem custo em deixá-la.
