---
titulo: "SPEC-008 — Conciliação de Retorno Bancário e Baixa Automática de Parcelas"
status: não iniciado
data_ultima_modificacao: 2026-06-26
sistemas_envolvidos:
  - Financeiro / Administração Bancária
  - Orçamentos
---

# SPEC-008 — Conciliação de Retorno Bancário e Baixa Automática de Parcelas

## Checklist de Ação

- [ ] Criar tabela `retorno_bancario_arquivos` (um registro por arquivo `.RET` processado, com hash do conteúdo para detectar reprocessamento).
- [ ] Criar tabela `retorno_bancario_registros` (um registro por linha do CNAB, com resultado da aplicação: `aplicado`/`divergente`/`nao_encontrado`/`ja_processado`).
- [ ] Criar RPC transacional `public.processar_retorno_bancario(p_arquivo_nome text, p_hash text, p_conta text, p_registros jsonb)` que: valida hash (bloqueia reprocessamento), dá baixa em `boletos`/`projeto_parcelas` quando o valor confere, cria a linha correspondente em `transacoes`, marca divergência quando o valor não confere, e marca "não encontrado" quando o `nosso_numero` não existe — tudo em uma única transação, sem abortar o lote inteiro por um registro problemático.
- [ ] Remover os dados de exemplo (`initialRecords`) de `RetornoBoletos.tsx` — a tela deve iniciar vazia.
- [ ] Trocar a lógica atual de updates diretos linha a linha no frontend (`handleFileChange`) por uma única chamada à RPC `processar_retorno_bancario`.
- [ ] Exibir coluna de status de aplicação (aplicado/divergente/não encontrado) na tabela de resultado, com destaque visual para os casos que precisam de revisão manual.
- [ ] Implementar o botão "Log" (hoje sem função) para abrir o histórico de `retorno_bancario_arquivos` e seus registros.
- [ ] Adicionar fluxo de "forçar reprocessamento" (com confirmação explícita) para o caso legítimo de corrigir um arquivo já processado, sem reabrir a porta para duplicar baixas por acidente.

### Passos manuais do usuário

- [ ] Aplicar a migration no banco remoto compartilhado (`vcvcwzmbiftcawncibke`).
- [ ] Reextrair o snapshot de `supabase/db/current/` após aplicar.
- [ ] Validar com um arquivo de retorno real (ou um de teste no mesmo layout) que a baixa, a divergência e o "não encontrado" se comportam como esperado antes de usar em produção.
- [ ] Confirmar que `boletos.nosso_numero` é, de fato, único na prática (não há constraint `UNIQUE` hoje) — se não for, decidir a regra de precedência antes de depender dele como chave de match.

## Objetivo

As SPECs 001-005 fecharam a ida do fluxo financeiro: orçamento aprovado → `projeto_itens` → `projeto_parcelas` → `boletos`. Mas o caminho de volta — o banco confirmando que um boleto foi pago — está incompleto. Hoje (`retorno-bancario-bradesco-5392a/src/pages/RetornoBoletos.tsx`) já existe uma lógica real de leitura de retorno CNAB 400 (`parseCnab400`) que atualiza `boletos.status`/`projeto_parcelas.status` diretamente no upload do arquivo, mas com três lacunas que impedem usar isso com confiança em produção:

1. **Sem rastro de qual arquivo gerou qual baixa**: não há registro de que um arquivo já foi processado — reprocessar o mesmo `.RET` por engano reaplica os updates silenciosamente, sem aviso.
2. **Sem lançamento em `transacoes`**: a baixa muda `boletos`/`projeto_parcelas`, mas nunca cria a linha correspondente em `transacoes` — o dinheiro recebido não aparece no livro-caixa/ledger usado pelo resto do Financeiro (dashboards, contas a pagar/receber).
3. **Sem tratamento de divergência**: se o valor pago no retorno é diferente do valor esperado da parcela (juros, desconto, pagamento parcial), o código de hoje aceita e dá baixa do mesmo jeito, sem sinalizar nada para revisão humana.

Esta SPEC fecha esse ciclo: leitura do retorno → conferência → baixa (ou divergência sinalizada) → lançamento no ledger → rastro auditável de qual arquivo fez o quê.

## Decisões aprovadas

- A lógica de decisão (baixar, marcar divergente, marcar não encontrado) migra do frontend para uma RPC transacional no banco — mesmo padrão já usado em `aprovar_orcamento_financeiro` (SPEC-001) e evita lógica de negócio espalhada em `useEffect`/`handleFileChange`.
- Reprocessar um arquivo já processado (mesmo hash de conteúdo) é bloqueado por padrão; só é permitido com uma ação explícita de "forçar", para não duplicar baixas/lançamentos por acidente (ex.: usuário sobe o mesmo arquivo duas vezes).
- Divergência (valor pago ≠ valor esperado da parcela) **não** dá baixa automática — fica registrada para revisão manual, em vez de aceitar silenciosamente um valor errado.
- Um registro cujo `nosso_numero` não existe em `boletos` não aborta o processamento do restante do arquivo (mesmo princípio de "pular, não abortar o lote" já usado na SPEC-002 para sincronização de orçamentos sem prazo).
- Os dados de exemplo (`initialRecords`) hoje fixos em `RetornoBoletos.tsx` são removidos — são resíduo de prototipagem, não dado real.
- Esta SPEC não resolve `FIN-07` (rotina oficial de geração de `nosso_numero`, hoje provisória) nem `FIN-08` (homologação bancária do CNAB com o Bradesco) — assume que o arquivo de retorno chega no layout já suportado por `parseCnab400`.

## Definição da SPEC

### Estado atual (confirmado no código em 26/06/2026)

- `src/pages/RetornoBoletos.tsx` (394 linhas): tem `initialRecords` com 4 linhas de exemplo fixas, exibidas mesmo sem nenhum upload — resíduo de prototipagem em produção.
- `handleFileChange` já chama `parseCnab400(text)` (real, não simulado) e, para cada registro com `pago > 0`, faz `update` direto em `boletos` (status, data_pagamento, valor_pago) e, se achou `parcela_id`, em `projeto_parcelas` (status, valor_pago, data_pagamento). Para `pago === 0`, marca `boletos.status = 'Cancelado'`.
- **Nenhuma linha é criada em `transacoes`** — confirmado por leitura do código: não há nenhuma chamada `.from('transacoes')` em `RetornoBoletos.tsx`.
- `public.transacoes` já tem as colunas necessárias para representar o recebimento (`parcela_id`, `valor`, `data_transacao`, `tipo`, `descricao`, `vl_pago`, `dt_pagamento`) — não precisa de migration na tabela em si, só passar a popular.
- `public.boletos` não tem constraint `UNIQUE` em `nosso_numero` no schema atual — o match por `.eq('nosso_numero', ...)` funciona hoje, mas não há garantia de unicidade.

### Modelo de dados novo

```sql
CREATE TABLE public.retorno_bancario_arquivos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome_arquivo text NOT NULL,
  hash_conteudo text NOT NULL UNIQUE,   -- sha256 do conteúdo; bloqueia reprocessamento do mesmo arquivo
  conta text,
  processado_por uuid REFERENCES public.usuarios(id),
  processado_em timestamptz NOT NULL DEFAULT now(),
  total_registros integer NOT NULL DEFAULT 0,
  total_aplicados integer NOT NULL DEFAULT 0,
  total_divergentes integer NOT NULL DEFAULT 0,
  total_nao_encontrados integer NOT NULL DEFAULT 0,
  forcado boolean NOT NULL DEFAULT false  -- true quando reprocessado deliberadamente
);

CREATE TABLE public.retorno_bancario_registros (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  arquivo_id uuid NOT NULL REFERENCES public.retorno_bancario_arquivos(id) ON DELETE CASCADE,
  nosso_numero text NOT NULL,
  boleto_id uuid REFERENCES public.boletos(id),
  parcela_id uuid REFERENCES public.projeto_parcelas(id),
  transacao_id uuid REFERENCES public.transacoes(id),
  valor_esperado numeric(12,2),
  valor_recebido numeric(12,2),
  data_pagamento date,
  ocorrencia_codigo text,
  status_aplicacao text NOT NULL CHECK (status_aplicacao IN ('aplicado','divergente','nao_encontrado','ja_processado')),
  motivo_divergencia text
);
```

### RPC transacional

```sql
CREATE OR REPLACE FUNCTION public.processar_retorno_bancario(
  p_nome_arquivo text,
  p_hash text,
  p_conta text,
  p_registros jsonb,    -- array de {nosso_numero, valor_recebido, data_pagamento, ocorrencia_codigo}
  p_forcar boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_arquivo_id uuid;
  v_reg jsonb;
  v_boleto public.boletos%ROWTYPE;
  v_aplicados integer := 0;
  v_divergentes integer := 0;
  v_nao_encontrados integer := 0;
BEGIN
  IF NOT p_forcar AND EXISTS (SELECT 1 FROM retorno_bancario_arquivos WHERE hash_conteudo = p_hash) THEN
    RAISE EXCEPTION 'Arquivo % já foi processado anteriormente (hash %). Use a opção de forçar reprocessamento se isso for intencional.', p_nome_arquivo, p_hash
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO retorno_bancario_arquivos (nome_arquivo, hash_conteudo, conta, forcado, total_registros)
  VALUES (p_nome_arquivo, p_hash, p_conta, p_forcar, jsonb_array_length(p_registros))
  RETURNING id INTO v_arquivo_id;

  FOR v_reg IN SELECT * FROM jsonb_array_elements(p_registros)
  LOOP
    SELECT * INTO v_boleto FROM boletos WHERE nosso_numero = v_reg->>'nosso_numero' LIMIT 1;

    IF NOT FOUND THEN
      INSERT INTO retorno_bancario_registros (arquivo_id, nosso_numero, valor_recebido, data_pagamento, ocorrencia_codigo, status_aplicacao)
      VALUES (v_arquivo_id, v_reg->>'nosso_numero', (v_reg->>'valor_recebido')::numeric, (v_reg->>'data_pagamento')::date, v_reg->>'ocorrencia_codigo', 'nao_encontrado');
      v_nao_encontrados := v_nao_encontrados + 1;
      CONTINUE;
    END IF;

    IF coalesce((v_reg->>'valor_recebido')::numeric, 0) <> coalesce(v_boleto.valor, 0) THEN
      INSERT INTO retorno_bancario_registros (arquivo_id, nosso_numero, boleto_id, parcela_id, valor_esperado, valor_recebido, data_pagamento, ocorrencia_codigo, status_aplicacao, motivo_divergencia)
      VALUES (v_arquivo_id, v_reg->>'nosso_numero', v_boleto.id, v_boleto.parcela_id, v_boleto.valor, (v_reg->>'valor_recebido')::numeric, (v_reg->>'data_pagamento')::date, v_reg->>'ocorrencia_codigo', 'divergente', 'Valor recebido difere do valor esperado do boleto.');
      v_divergentes := v_divergentes + 1;
      CONTINUE;
    END IF;

    UPDATE boletos
    SET status = 'pago', valor_pago = (v_reg->>'valor_recebido')::numeric, data_pagamento = (v_reg->>'data_pagamento')::date
    WHERE id = v_boleto.id;

    IF v_boleto.parcela_id IS NOT NULL THEN
      UPDATE projeto_parcelas
      SET status = 'paga', valor_pago = (v_reg->>'valor_recebido')::numeric, data_pagamento = (v_reg->>'data_pagamento')::date
      WHERE id = v_boleto.parcela_id;
    END IF;

    INSERT INTO transacoes (parcela_id, tipo, descricao, valor, data_transacao, vl_pago, dt_pagamento, status_pago)
    VALUES (v_boleto.parcela_id, 'entrada', 'Recebimento boleto ' || v_boleto.nosso_numero, v_boleto.valor, (v_reg->>'data_pagamento')::date, (v_reg->>'valor_recebido')::numeric, (v_reg->>'data_pagamento')::date, 1)
    RETURNING id INTO v_boleto.id;  -- reaproveitando variável só para capturar o id gerado

    INSERT INTO retorno_bancario_registros (arquivo_id, nosso_numero, boleto_id, parcela_id, transacao_id, valor_esperado, valor_recebido, data_pagamento, ocorrencia_codigo, status_aplicacao)
    VALUES (v_arquivo_id, v_reg->>'nosso_numero', v_boleto.id, v_boleto.parcela_id, v_boleto.id, v_boleto.valor, (v_reg->>'valor_recebido')::numeric, (v_reg->>'data_pagamento')::date, v_reg->>'ocorrencia_codigo', 'aplicado');
    v_aplicados := v_aplicados + 1;
  END LOOP;

  UPDATE retorno_bancario_arquivos
  SET total_aplicados = v_aplicados, total_divergentes = v_divergentes, total_nao_encontrados = v_nao_encontrados
  WHERE id = v_arquivo_id;

  RETURN jsonb_build_object(
    'arquivo_id', v_arquivo_id,
    'aplicados', v_aplicados,
    'divergentes', v_divergentes,
    'nao_encontrados', v_nao_encontrados
  );
END;
$$;
```

> Nota: o tipo de `transacao_tipo` e o nome exato do valor (`'entrada'`) precisam ser confirmados contra o enum real de `public.transacao_tipo` antes de aplicar — o código acima é o desenho funcional, não a migration final.

### Frontend (`retorno-bancario-bradesco-5392a`)

| Arquivo | Mudança |
|---|---|
| `src/pages/RetornoBoletos.tsx` | Remover `initialRecords`; tela inicia vazia com mensagem de estado vazio. `handleFileChange` passa a calcular o hash do conteúdo (`crypto.subtle.digest`) e chamar `processar_retorno_bancario` em vez de fazer updates linha a linha. |
| `src/pages/RetornoBoletos.tsx` | Nova coluna "Status" na tabela (aplicado/divergente/não encontrado), com cor de destaque para os dois últimos. |
| `src/pages/RetornoBoletos.tsx` | Botão "Log" passa a abrir um painel/modal com o histórico de `retorno_bancario_arquivos` (nome, data, totais) e, ao expandir, os registros de `retorno_bancario_registros`. |
| `src/pages/RetornoBoletos.tsx` | Quando a RPC retornar erro de "já processado", oferecer o botão "Forçar reprocessamento" que rechama a RPC com `p_forcar = true`, com um modal de confirmação explícito. |

### Critérios de aceite

- Processar um arquivo de retorno com um registro "06-liquidação normal" e valor exato dá baixa no boleto e na parcela, e cria uma linha em `transacoes` — tudo em uma única chamada transacional.
- Reprocessar o mesmo arquivo (mesmo hash) é bloqueado com mensagem clara, sem duplicar baixa nem lançamento.
- Forçar o reprocessamento (ação explícita) é permitido e fica registrado (`forcado = true`).
- Um registro com valor pago diferente do valor esperado fica `divergente`, sem alterar `boletos`/`projeto_parcelas`/`transacoes`.
- Um `nosso_numero` que não existe em `boletos` fica `nao_encontrado`, e o restante do arquivo continua sendo processado normalmente.
- A tela não exibe mais nenhum dado de exemplo antes do primeiro upload.

## Realizado

(nada implementado ainda — esta SPEC define o desenho a ser aprovado e construído.)

## Pendências

- [ ] Confirmar o enum real de `public.transacao_tipo` e ajustar o valor usado no `INSERT INTO transacoes` (o desenho acima usa `'entrada'` como placeholder).
- [ ] Confirmar se `boletos.nosso_numero` deve ganhar constraint `UNIQUE` antes de depender dele como chave de match na RPC.
- [ ] Implementar as tabelas, a RPC e as mudanças de frontend descritas nesta SPEC.
- [ ] Decidir a regra de exibição/ação para registros `divergente` e `nao_encontrado` na UI (hoje só "aplicado" tem um caminho claro).
- [ ] Testar com um arquivo de retorno real (ou de teste no mesmo layout) antes de usar em produção — depende também da homologação do CNAB (`FIN-08`) para o ciclo completo (remessa → retorno) ser validado ponta a ponta.
