-- SPEC-258 (correção dos dados): arquiteto volta a ser arquiteto nos projetos.
-- Causa: a sincronização SharePoint -> sistema (sharepoint-projetos-pull, corrigida na mesma SPEC) casava o nome da coluna
-- "Arquiteto" com QUALQUER contato e gravava em `projetos.arquiteto_id` o cadastro DE CLIENTE com o mesmo nome (duplicado
-- vindo da Connect). Em 13 desses pares uma junção anterior de duplicados ainda tinha escolhido o cadastro de cliente como o
-- principal (o de arquiteto ficou com canonical_id apontando para o de cliente).
-- Escopo: só os 23 pares "cadastro de cliente usado como arquiteto" + "cadastro de arquiteto ATIVO com o MESMO nome" (grupo A).
-- Os casos sem cadastro de arquiteto com o mesmo nome (grupos B e C, ex. ELOISA BONINI, MG ARQUITETURA) NÃO são tocados.
--   1. O cadastro de arquiteto passa a ser o principal (canonical_id nulo); o de cliente vira duplicata dele
--      (canonical_id = arquiteto). Outros cadastros que apontavam para o de cliente passam a apontar para o de arquiteto.
--   2. Se o cadastro de cliente foi usado como cliente (projeto, orçamento, negociação Connect, título), o arquiteto ganha
--      também o tipo 'cliente' em contato_tipos (tipo extra; o principal continua arquiteto).
--   3. `projetos.arquiteto_id` dos 120 projetos passa para o cadastro de arquiteto; nos 27 sem lista oficial, a lista
--      (`projeto_arquitetos`) recebe esse arquiteto com 100% (mesmo critério do backfill da SPEC-077).
--   4. Contatos de tipo principal não-cliente que são cliente de projeto/orçamento ganham o tipo extra 'cliente' (8 arquitetos).
-- Não move cliente_id de projeto/orçamento, negociações, títulos nem notas: o cadastro duplicado continua lá como "foto".
-- O push para o SharePoint fica desligado só nesta transação: o nome do arquiteto é o mesmo, não há o que enviar.
-- Backup em backup._bkp_spec258_* (rollback.sql desfaz tudo a partir dele).

CREATE TEMP TABLE _spec258_par ON COMMIT DROP AS
SELECT d.id AS dup_id, b.id AS arq_id, (b.canonical_id = d.id) AS invertido
  FROM contatos d
  JOIN contatos b ON b.id <> d.id
                 AND lower(trim(b.nome)) = lower(trim(d.nome))
                 AND b.tipo = 'arquiteto' AND b.ativo
                 AND EXISTS (SELECT 1 FROM contato_tipos ct WHERE ct.contato_id = b.id AND ct.tipo_id = 2)
                 AND (b.canonical_id IS NULL OR b.canonical_id = d.id)
 WHERE d.tipo = 'cliente' AND d.canonical_id IS NULL
   AND EXISTS (SELECT 1 FROM projetos p WHERE p.arquiteto_id = d.id);

DO $chk$
BEGIN
  IF (SELECT count(*) FROM _spec258_par) <> 23
     OR EXISTS (SELECT 1 FROM _spec258_par GROUP BY dup_id HAVING count(*) > 1)
     OR EXISTS (SELECT 1 FROM _spec258_par GROUP BY arq_id HAVING count(*) > 1) THEN
    RAISE EXCEPTION 'SPEC-258: esperava 23 pares 1-para-1, achou %. Nada foi alterado.', (SELECT count(*) FROM _spec258_par);
  END IF;
END $chk$;

-- backups
CREATE TABLE backup._bkp_spec258_contatos AS
SELECT c.id, c.canonical_id, c.updated_at, now() AS copiado_em
  FROM contatos c
 WHERE c.id IN (SELECT dup_id FROM _spec258_par UNION SELECT arq_id FROM _spec258_par)
    OR c.canonical_id IN (SELECT dup_id FROM _spec258_par);
CREATE TABLE backup._bkp_spec258_projetos AS
SELECT p.id, p.arquiteto_id, p.updated_at, now() AS copiado_em
  FROM projetos p WHERE p.arquiteto_id IN (SELECT dup_id FROM _spec258_par);
CREATE TABLE backup._bkp_spec258_projeto_arquitetos_inseridos (projeto_id uuid, arquiteto_id uuid);
CREATE TABLE backup._bkp_spec258_contato_tipos_inseridos (contato_id uuid, tipo text);
REVOKE ALL ON backup._bkp_spec258_contatos, backup._bkp_spec258_projetos,
  backup._bkp_spec258_projeto_arquitetos_inseridos, backup._bkp_spec258_contato_tipos_inseridos FROM anon, authenticated;

-- 1. arquiteto vira o principal; cliente vira duplicata dele
--    (nesta ordem: o índice único de CPF/CNPJ só vale entre cadastros principais — o de cliente sai antes do de arquiteto entrar)
UPDATE contatos c SET canonical_id = x.arq_id FROM _spec258_par x WHERE c.id = x.dup_id;
UPDATE contatos c SET canonical_id = x.arq_id FROM _spec258_par x WHERE c.canonical_id = x.dup_id AND c.id <> x.arq_id;
UPDATE contatos c SET canonical_id = NULL FROM _spec258_par x WHERE c.id = x.arq_id AND x.invertido;

-- 2 e 4. tipo extra 'cliente'
WITH novos AS (
  INSERT INTO contato_tipos (contato_id, tipo)
  SELECT DISTINCT alvo, 'cliente' FROM (
    SELECT x.arq_id AS alvo FROM _spec258_par x
     WHERE EXISTS (SELECT 1 FROM projetos p WHERE p.cliente_id = x.dup_id)
        OR EXISTS (SELECT 1 FROM orcamentos o WHERE o.cliente_id = x.dup_id)
        OR EXISTS (SELECT 1 FROM negociacoes n WHERE n.contato_id = x.dup_id)
        OR EXISTS (SELECT 1 FROM financeiro_titulos f WHERE f.contato_id = x.dup_id)
    UNION
    SELECT c.id FROM contatos c
     WHERE c.tipo <> 'cliente'
       AND (EXISTS (SELECT 1 FROM projetos p WHERE p.cliente_id = c.id)
            OR EXISTS (SELECT 1 FROM orcamentos o WHERE o.cliente_id = c.id))
  ) a
  ON CONFLICT (contato_id, tipo) DO NOTHING
  RETURNING contato_id, tipo
)
INSERT INTO backup._bkp_spec258_contato_tipos_inseridos SELECT contato_id, tipo FROM novos;

-- 3. projetos: lista oficial vazia recebe o arquiteto a 100%; campo antigo passa para o cadastro de arquiteto
ALTER TABLE projetos DISABLE TRIGGER trg_projetos_sharepoint_push;
SELECT set_config('app.sync_em_andamento', 'on', true);

WITH novos AS (
  INSERT INTO projeto_arquitetos (projeto_id, arquiteto_id, percentual)
  SELECT p.id, x.arq_id, 100
    FROM projetos p JOIN _spec258_par x ON x.dup_id = p.arquiteto_id
   WHERE NOT EXISTS (SELECT 1 FROM projeto_arquitetos pa WHERE pa.projeto_id = p.id)
  RETURNING projeto_id, arquiteto_id
)
INSERT INTO backup._bkp_spec258_projeto_arquitetos_inseridos SELECT projeto_id, arquiteto_id FROM novos;

UPDATE projetos p SET arquiteto_id = x.arq_id FROM _spec258_par x WHERE p.arquiteto_id = x.dup_id;

ALTER TABLE projetos ENABLE TRIGGER trg_projetos_sharepoint_push;

-- conferência final (aborta tudo se algo não bateu)
DO $fim$
BEGIN
  IF EXISTS (SELECT 1 FROM projetos p JOIN _spec258_par x ON x.dup_id = p.arquiteto_id) THEN
    RAISE EXCEPTION 'SPEC-258: ainda há projeto com o cadastro de cliente como arquiteto';
  END IF;
  IF EXISTS (SELECT 1 FROM projetos p JOIN _spec258_par x ON x.arq_id = p.arquiteto_id
              WHERE p.id IN (SELECT id FROM backup._bkp_spec258_projetos) AND NOT EXISTS (SELECT 1 FROM projeto_arquitetos pa WHERE pa.projeto_id = p.id AND pa.arquiteto_id = x.arq_id)) THEN
    RAISE EXCEPTION 'SPEC-258: projeto com campo antigo diferente da lista oficial';
  END IF;
  IF EXISTS (SELECT 1 FROM contatos c JOIN contatos k ON k.id = c.canonical_id
              WHERE k.canonical_id IS NOT NULL AND k.id IN (SELECT arq_id FROM _spec258_par)) THEN
    RAISE EXCEPTION 'SPEC-258: duplicata apontando para outra duplicata';
  END IF;
END $fim$;
