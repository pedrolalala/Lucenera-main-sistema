-- SPEC-164 — Dicionário inicial de sinônimos e jargão de light design.
-- Editável depois pelo curador (tabela memoria.kb_sinonimos). Termos são
-- normalizados por kb_norm (sem acento, minúsculas), então "Luminária de
-- Embutir" e "luminaria de embutir" são o mesmo termo.

BEGIN;

INSERT INTO memoria.kb_sinonimos (grupo, termo)
SELECT g.grupo, memoria.kb_norm(t.termo)
FROM (VALUES
  ('downlight',            ARRAY['downlight', 'luminária de embutir', 'embutir', 'embutido de teto', 'spot de embutir', 'spot embutido']),
  ('temperatura de cor',   ARRAY['temperatura de cor', 'tonalidade', 'kelvin', 'cct', 'luz quente', 'luz fria', 'luz neutra']),
  ('cri',                  ARRAY['cri', 'irc', 'índice de reprodução de cor', 'reprodução de cor', 'fidelidade cromática']),
  ('ângulo de abertura',   ARRAY['ângulo de abertura', 'abertura de facho', 'ângulo do facho', 'abertura', 'ângulo']),
  ('facho',                ARRAY['facho', 'feixe', 'facho de luz', 'beam', 'abertura de facho']),
  ('ugr',                  ARRAY['ugr', 'ofuscamento', 'índice de ofuscamento', 'glare', 'antiofuscamento', 'controle de ofuscamento']),
  ('preparação',           ARRAY['preparação', 'infraestrutura', 'infra', 'pré-instalação', 'previsão de pontos', 'tubulação']),
  ('fotometria',           ARRAY['fotometria', 'curva fotométrica', 'ies', 'ldt', 'eulumdat', 'distribuição luminosa']),
  ('acendimento',          ARRAY['acendimento', 'circuito de acendimento', 'circuitos', 'comando', 'interruptor']),
  ('dimerização',          ARRAY['dimerização', 'dimerizável', 'dimerizar', 'dimmer', 'dimming', 'dali', '0-10v', 'triac']),
  ('fita led',             ARRAY['fita led', 'fita de led', 'strip led', 'led linear', 'perfil de led']),
  ('sanca',                ARRAY['sanca', 'sanca aberta', 'sanca fechada', 'luz indireta']),
  ('wall washer',          ARRAY['wallwasher', 'wall washer', 'wallwashing', 'lavagem de parede']),
  ('embutido de piso',     ARRAY['embutido de piso', 'embutido de solo', 'uplight', 'balizador de piso']),
  ('espeto',               ARRAY['espeto', 'finco', 'espeto de jardim']),
  ('grau de proteção',     ARRAY['ip', 'grau de proteção', 'ip65', 'ip66', 'ip67', 'ip68']),
  ('trilho',               ARRAY['trilho', 'trilho eletrificado', 'spot de trilho']),
  ('pendente',             ARRAY['pendente', 'luminária pendente', 'suspensa', 'luminária suspensa']),
  ('arandela',             ARRAY['arandela', 'luminária de parede', 'aplique']),
  ('lona tensionada',      ARRAY['lona tensionada', 'lona', 'forro tensionado', 'teto tensionado', 'barrisol']),
  ('automação',            ARRAY['automação', 'cenas', 'cena', 'relatório de cenas'])
) AS g(grupo, termos)
CROSS JOIN LATERAL unnest(g.termos) AS t(termo)
ON CONFLICT DO NOTHING;

COMMIT;
