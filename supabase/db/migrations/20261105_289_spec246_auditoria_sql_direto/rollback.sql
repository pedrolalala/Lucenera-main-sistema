-- Rollback da 289: volta a fn_registrar à versão anterior (alterações por SQL direto voltam a não ser registradas). Eventos já gravados são mantidos.
BEGIN;
CREATE OR REPLACE FUNCTION auditoria.fn_registrar()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_nome text;
  v_old jsonb;
  v_new jsonb;
  v_r jsonb;
  v_mud jsonb := '{}'::jsonb;
  v_tipo text;
  k text;
  v_ign text[] := ARRAY['updated_at','atualizado_em','created_at','criado_em','sync_hash','last_synced_at',
                        'last_sync_source','last_synced_by','alterado_em','ultima_consulta_em','tentativa_atual',
                        'payload_enviado','token_aprovacao_cliente','estoque_total','estoque_disponivel',
                        'estoque_showroom','quantidade_disponivel'];
  v_sens text[] := ARRAY['preco_custo','custo_total','margem_lucro','porc_frete','porc_despesas','porc_bdi','porc_st',
                         'porc_desconto','icms_entrada','ipi_entrada','vl_custo_indireto','percentual_desconto_compra',
                         'banco','agencia','conta','chave_pix'];
BEGIN
  IF v_uid IS NULL THEN
    -- Sem usuário só entra o cliente aprovando/recusando pelo link público (PostgREST como anon).
    -- Importações, scripts e Edge Functions com service role continuam fora.
    IF TG_TABLE_NAME = 'orcamentos'
       AND coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'role', '') = 'anon' THEN
      v_nome := 'Cliente (link de aprovação)';
    ELSE
      RETURN NULL;
    END IF;
  END IF;

  IF TG_OP <> 'INSERT' THEN v_old := to_jsonb(OLD); END IF;
  IF TG_OP <> 'DELETE' THEN v_new := to_jsonb(NEW); END IF;
  v_r := coalesce(v_new, v_old);

  IF TG_OP = 'UPDATE' THEN
    FOR k IN SELECT jsonb_object_keys(v_new) LOOP
      CONTINUE WHEN k = ANY (v_ign);
      IF (v_new->k) IS DISTINCT FROM (v_old->k) THEN
        v_mud := v_mud || jsonb_build_object(k,
          CASE WHEN k = ANY (v_sens) THEN '["***","***"]'::jsonb ELSE jsonb_build_array(v_old->k, v_new->k) END);
      END IF;
    END LOOP;
    IF v_mud = '{}'::jsonb THEN RETURN NULL; END IF;

    v_tipo := 'alterou';
    IF v_mud ? 'status' THEN
      v_tipo := CASE WHEN (v_new->>'status') ILIKE 'aprovad%' THEN 'aprovou' ELSE 'mudou_status' END;
    END IF;
    IF EXISTS (SELECT 1 FROM jsonb_each(v_mud) e
                WHERE e.key IN ('aprovado_em', 'aprovado_cliente_em') AND e.value->>0 IS NULL AND e.value->>1 IS NOT NULL) THEN
      v_tipo := 'aprovou';
    END IF;
  ELSIF TG_OP = 'INSERT' THEN
    v_tipo := 'criou';
    v_mud := auditoria.limpar(v_new);
  ELSE
    v_tipo := 'apagou';
    v_mud := auditoria.limpar(v_old);
  END IF;

  PERFORM auditoria.inserir(
    v_uid, auditoria.sistema_atual(), v_tipo, TG_TABLE_NAME,
    coalesce(v_r->>'id', v_r->>'usuario_id', v_r->>'user_id'),
    auditoria.referencia(TG_TABLE_NAME, v_r), v_mud, NULL, NULL, v_nome);
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'auditoria.fn_registrar (%): %', TG_TABLE_NAME, SQLERRM;
  RETURN NULL;
END $function$
;
COMMIT;
