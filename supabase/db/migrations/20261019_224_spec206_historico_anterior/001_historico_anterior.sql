-- SPEC-206: traz para auditoria.eventos o histórico que já existia antes da Movimentação (migration 221).
-- Só entra ação de pessoa identificada (com usuário). O que veio de script/migração, sem autor, fica de fora.
-- Cada evento importado leva navegador = 'Histórico importado — <origem>' para ficar claro na Central.
-- Idempotente: apaga os importados e importa de novo. Não toca nos eventos gravados pelos gatilhos.
BEGIN;

DELETE FROM auditoria.eventos WHERE navegador LIKE 'Histórico importado%';

-- 1) Logins: sessões abertas no banco de SP (desde 14/10) ...
INSERT INTO auditoria.eventos (criado_em, usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, ip, navegador)
SELECT s.created_at, s.user_id, auditoria.nome_usuario(s.user_id), NULL, 'login', 'sessions', s.id::text, 'Entrou',
       host(s.ip), 'Histórico importado — sessão'
FROM auth.sessions s
WHERE NOT EXISTS (SELECT 1 FROM auditoria.eventos e
                  WHERE e.tipo = 'login' AND e.registro_id = s.id::text);

-- ... e o último acesso de quem não tem sessão aberta perto dessa hora (vem do cadastro da conta).
INSERT INTO auditoria.eventos (criado_em, usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, navegador)
SELECT u.last_sign_in_at, u.id, auditoria.nome_usuario(u.id), NULL, 'login', 'sessions', NULL, 'Entrou (último acesso registrado)',
       'Histórico importado — último acesso da conta'
FROM auth.users u
WHERE u.last_sign_in_at IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM auditoria.eventos e
                  WHERE e.tipo = 'login' AND e.usuario_id = u.id
                    AND e.criado_em BETWEEN u.last_sign_in_at - interval '2 minutes' AND u.last_sign_in_at + interval '2 minutes');

-- 2) logs_auditoria: aprovação financeira de orçamento, contato criado, permissão de aprovar concedida.
INSERT INTO auditoria.eventos (criado_em, usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, mudancas, navegador)
SELECT l.created_at, l.usuario_id, auditoria.nome_usuario(l.usuario_id),
       CASE l.tabela WHEN 'orcamentos' THEN 'orcamentos' WHEN 'usuarios' THEN 'hub' END,
       CASE WHEN l.tabela = 'orcamentos' THEN 'aprovou'
            WHEN l.operacao = 'INSERT' THEN 'criou'
            ELSE 'alterou' END,
       l.tabela,
       coalesce(l.dados_novos->>'orcamento_id', l.registro_id::text),
       CASE
         WHEN l.tabela = 'orcamentos' THEN
           coalesce((SELECT auditoria.referencia('orcamentos', to_jsonb(o)) FROM public.orcamentos o
                     WHERE o.id = coalesce((l.dados_novos->>'orcamento_id')::uuid, l.registro_id)),
                    concat_ws(' ', 'Orçamento já apagado', l.dados_novos->>'numero_venda'))
           || ' — aprovação financeira'
         WHEN l.tabela = 'contatos' THEN
           coalesce((SELECT auditoria.referencia('contatos', to_jsonb(c)) FROM public.contatos c WHERE c.id = l.registro_id),
                    auditoria.referencia('contatos', l.dados_novos))
         ELSE coalesce(l.observacao, '') || ' — ' || auditoria.referencia(l.tabela, l.dados_novos)
       END,
       CASE
         WHEN l.operacao = 'INSERT' THEN auditoria.limpar(l.dados_novos)
         WHEN l.dados_anteriores IS NOT NULL THEN
           (SELECT jsonb_object_agg(k, jsonb_build_array(l.dados_anteriores->k, l.dados_novos->k))
            FROM jsonb_object_keys(l.dados_novos) k
            WHERE l.dados_anteriores->k IS DISTINCT FROM l.dados_novos->k)
         ELSE jsonb_build_object('observacao', l.observacao)
       END,
       'Histórico importado — logs_auditoria'
FROM public.logs_auditoria l
WHERE l.usuario_id IS NOT NULL;

-- 3) Contatos com autor que não estão no logs_auditoria.
INSERT INTO auditoria.eventos (criado_em, usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, navegador)
SELECT c.created_at, c.created_by, auditoria.nome_usuario(c.created_by), NULL, 'criou', 'contatos', c.id::text,
       auditoria.referencia('contatos', to_jsonb(c)), 'Histórico importado — contatos.created_by'
FROM public.contatos c
WHERE c.created_by IS NOT NULL AND c.created_at IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.logs_auditoria l WHERE l.registro_id = c.id);

-- 4) Permissões e papéis mudados na Central (só os que têm autor).
INSERT INTO auditoria.eventos (criado_em, usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, mudancas, navegador)
SELECT a.criado_em, a.autor_id, auditoria.nome_usuario(a.autor_id), 'hub',
       CASE WHEN a.antes IS NULL THEN 'criou' WHEN a.depois IS NULL THEN 'apagou' ELSE 'alterou' END,
       a.entidade, a.entidade_id::text,
       CASE a.entidade
         WHEN 'usuario_papeis' THEN auditoria.referencia('usuario_papeis', coalesce(a.depois, a.antes))
         WHEN 'papel_permissoes' THEN concat_ws(' ', 'Permissão',
              (SELECT pa.nome FROM public.papeis pa WHERE pa.id = (coalesce(a.depois, a.antes)->>'papel_id')::uuid),
              '· ' || (coalesce(a.depois, a.antes)->>'acao'))
         WHEN 'papeis' THEN concat_ws(' ', 'Papel', coalesce(a.depois, a.antes)->>'nome')
         ELSE 'Exceção de permissão de ' || coalesce(auditoria.nome_usuario((coalesce(a.depois, a.antes)->>'usuario_id')::uuid), '')
       END,
       CASE WHEN a.antes IS NOT NULL AND a.depois IS NOT NULL THEN
              (SELECT jsonb_object_agg(k, jsonb_build_array(a.antes->k, a.depois->k))
               FROM jsonb_object_keys(a.depois) k WHERE a.antes->k IS DISTINCT FROM a.depois->k)
            ELSE coalesce(a.depois, a.antes) END,
       'Histórico importado — auditoria_permissoes'
FROM public.auditoria_permissoes a
WHERE a.autor_id IS NOT NULL;

-- 5) Mudanças de status de orçamento (historico_status_orcamentos.usuario guarda o id como texto).
INSERT INTO auditoria.eventos (criado_em, usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, mudancas, navegador)
SELECT h.created_at, u.uid, coalesce(auditoria.nome_usuario(u.uid), h.usuario), 'orcamentos',
       CASE WHEN h.status_novo ILIKE 'aprovad%' OR h.status_anterior = 'enviado_cliente' AND h.observacao ILIKE '%aprovação%cliente%'
            THEN 'aprovou' ELSE 'mudou_status' END,
       'orcamentos', h.orcamento_id::text,
       coalesce((SELECT auditoria.referencia('orcamentos', to_jsonb(o)) FROM public.orcamentos o WHERE o.id = h.orcamento_id),
                'Orçamento já apagado'),
       jsonb_build_object('status', jsonb_build_array(h.status_anterior, h.status_novo), 'observacao', jsonb_build_array(NULL, h.observacao)),
       'Histórico importado — historico_status_orcamentos'
FROM public.historico_status_orcamentos h
CROSS JOIN LATERAL (SELECT CASE WHEN h.usuario ~* '^[0-9a-f-]{36}$' THEN h.usuario::uuid END AS uid) u;

-- 6) Mudanças de status de pedido de produção.
INSERT INTO auditoria.eventos (criado_em, usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, mudancas, navegador)
SELECT p.criado_em, p.usuario_id, auditoria.nome_usuario(p.usuario_id), 'controle-producao',
       CASE WHEN p.acao = 'status_alterado' THEN 'mudou_status' WHEN p.dados_antigos IS NULL THEN 'criou' ELSE 'alterou' END,
       'producao_pedidos', p.producao_pedido_id::text,
       auditoria.referencia('producao_pedidos', coalesce(p.dados_novos, p.dados_antigos)),
       (SELECT jsonb_object_agg(k, jsonb_build_array(p.dados_antigos->k, p.dados_novos->k))
        FROM jsonb_object_keys(coalesce(p.dados_novos, '{}'::jsonb)) k
        WHERE k NOT IN ('updated_at') AND p.dados_antigos->k IS DISTINCT FROM p.dados_novos->k),
       'Histórico importado — producao_pedidos_log'
FROM public.producao_pedidos_log p
WHERE p.usuario_id IS NOT NULL;

-- 7) Quem criou/enviou/aprovou/cancelou, a partir das colunas de autor das próprias tabelas.
INSERT INTO auditoria.eventos (criado_em, usuario_id, usuario_nome, sistema, tipo, entidade, registro_id, referencia, navegador)
SELECT x.quando, x.quem, auditoria.nome_usuario(x.quem), x.sistema, x.tipo, x.tabela, x.id::text,
       auditoria.referencia(x.tabela, x.linha) || coalesce(' — ' || x.obs, ''),
       'Histórico importado — ' || x.tabela || '.' || x.coluna
FROM (
  SELECT o.created_at quando, o.digitado_por quem, 'orcamentos' sistema, 'criou' tipo, 'orcamentos' tabela, o.id, to_jsonb(o) linha, NULL obs, 'digitado_por' coluna
    FROM public.orcamentos o WHERE o.digitado_por IS NOT NULL
  UNION ALL
  SELECT o.enviado_cliente_em, o.enviado_cliente_por, 'orcamentos', 'mudou_status', 'orcamentos', o.id, to_jsonb(o), 'enviado ao cliente', 'enviado_cliente_por'
    FROM public.orcamentos o WHERE o.enviado_cliente_por IS NOT NULL AND o.enviado_cliente_em IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM public.historico_status_orcamentos h WHERE h.orcamento_id = o.id AND h.status_novo = 'enviado_cliente')
  UNION ALL
  SELECT p.criado_em, p.criado_por, 'necessidade-de-compra', 'criou', 'pedidos_compra', p.id, to_jsonb(p), NULL, 'criado_por'
    FROM public.pedidos_compra p WHERE p.criado_por IS NOT NULL
  UNION ALL
  SELECT p.aprovado_em, p.aprovado_por, 'necessidade-de-compra', 'aprovou', 'pedidos_compra', p.id, to_jsonb(p), NULL, 'aprovado_por'
    FROM public.pedidos_compra p WHERE p.aprovado_por IS NOT NULL AND p.aprovado_em IS NOT NULL
  UNION ALL
  SELECT p.cancelado_em, p.cancelado_por, 'necessidade-de-compra', 'mudou_status', 'pedidos_compra', p.id, to_jsonb(p), 'cancelado', 'cancelado_por'
    FROM public.pedidos_compra p WHERE p.cancelado_por IS NOT NULL AND p.cancelado_em IS NOT NULL
  UNION ALL
  SELECT p.created_at, p.created_by, 'controle-producao', 'criou', 'producao_pedidos', p.id, to_jsonb(p), NULL, 'created_by'
    FROM public.producao_pedidos p WHERE p.created_by IS NOT NULL
  UNION ALL
  SELECT p.inativado_em, p.inativado_por, 'controle-producao', 'mudou_status', 'producao_pedidos', p.id, to_jsonb(p), 'inativado', 'inativado_por'
    FROM public.producao_pedidos p WHERE p.inativado_por IS NOT NULL AND p.inativado_em IS NOT NULL
  UNION ALL
  SELECT g.created_at, g.created_by, 'controle-garantia', 'criou', 'garantia_itens', g.id, to_jsonb(g), NULL, 'created_by'
    FROM public.garantia_itens g WHERE g.created_by IS NOT NULL
  UNION ALL
  SELECT g.created_at, g.created_by, 'controle-garantia', 'criou', 'garantia_protocolos', g.id, to_jsonb(g), NULL, 'created_by'
    FROM public.garantia_protocolos g WHERE g.created_by IS NOT NULL
  UNION ALL
  SELECT p.created_at, p.created_by, 'crm', 'criou', 'projetos', p.id, to_jsonb(p), NULL, 'created_by'
    FROM public.projetos p WHERE p.created_by IS NOT NULL
) x
WHERE x.quando IS NOT NULL
  -- não repete o que os gatilhos já gravaram desde a migration 221
  AND NOT EXISTS (SELECT 1 FROM auditoria.eventos e
                  WHERE e.entidade = x.tabela AND e.registro_id = x.id::text AND e.tipo = x.tipo
                    AND e.navegador IS DISTINCT FROM 'Histórico importado — ' || x.tabela || '.' || x.coluna
                    AND e.criado_em BETWEEN x.quando - interval '1 minute' AND x.quando + interval '1 minute');

COMMIT;
