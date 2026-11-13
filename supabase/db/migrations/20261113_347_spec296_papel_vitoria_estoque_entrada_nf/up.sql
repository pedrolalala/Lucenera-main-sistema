-- SPEC-296 (reuniao 54, 13/11/2026): permissoes da Vitoria. Papel novo 'estoque_entrada_nf' no lugar de 'estoque' SO para ela
-- (Matheus e Alexandre continuam no 'estoque'). Decisoes: Cadastro consultar+editar (sem criar); Orcamentos como o Matheus (criar/editar,
-- para liberar garantia); Venda Parcial ver+transicoes; Entregas; Producao e Garantia (ver, como o estoque); Compras SO 'editar' para dar entrada de NF
-- (registrar_entrada_nota_compra exige necessidade-de-compra editar); Movimentacao de Pecas NAO.
BEGIN;

INSERT INTO public.papeis (nome, descricao)
SELECT 'estoque_entrada_nf', 'SPEC-296: Estoque + entrada de NF — Cadastro (consulta/edita), Orcamentos (criar/editar), Venda Parcial, Entregas, Producao/Garantia (ver), Compras (editar, p/ entrada de NF), Solicitacoes. Sem Movimentacao de Pecas.'
WHERE NOT EXISTS (SELECT 1 FROM public.papeis WHERE nome = 'estoque_entrada_nf');

INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, s.id, NULL, v.acao
  FROM public.papeis p
  JOIN (VALUES
    ('cadastro','visualizar'),('cadastro','editar'),
    ('orcamentos','visualizar'),('orcamentos','criar'),('orcamentos','editar'),
    ('separacao-parcial','visualizar'),('separacao-parcial','criar'),('separacao-parcial','editar'),
    ('logistica','visualizar'),('logistica','criar'),('logistica','editar'),
    ('controle-producao','visualizar'),('controle-garantia','visualizar'),
    ('necessidade-de-compra','visualizar'),('necessidade-de-compra','editar'),
    ('solicitacoes','visualizar'),('solicitacoes','criar')
  ) AS v(slug, acao) ON true
  JOIN public.systems s ON s.slug = v.slug
 WHERE p.nome = 'estoque_entrada_nf'
   AND NOT EXISTS (SELECT 1 FROM public.papel_permissoes x
                    WHERE x.papel_id = p.id AND x.system_id = s.id AND x.modulo_id IS NULL AND x.acao = v.acao);

-- troca o papel so da Vitoria
DELETE FROM public.usuario_papeis up USING public.usuarios u, public.papeis p
 WHERE up.usuario_id = u.id AND up.papel_id = p.id AND lower(u.email) = 'vitoria@lucenera.com.br' AND p.nome = 'estoque';
INSERT INTO public.usuario_papeis (usuario_id, papel_id)
SELECT u.id, p.id FROM public.usuarios u JOIN public.papeis p ON p.nome = 'estoque_entrada_nf'
 WHERE lower(u.email) = 'vitoria@lucenera.com.br'
   AND NOT EXISTS (SELECT 1 FROM public.usuario_papeis x WHERE x.usuario_id = u.id AND x.papel_id = p.id);

-- Acesso a Sistemas (cards + portao do hub_pode_executar)
INSERT INTO public.user_system_access (user_id, system_id)
SELECT u.id, s.id FROM public.usuarios u
  JOIN public.systems s ON s.slug IN ('orcamentos','controle-producao','controle-garantia','necessidade-de-compra')
 WHERE lower(u.email) = 'vitoria@lucenera.com.br'
ON CONFLICT (user_id, system_id) DO NOTHING;

NOTIFY pgrst, 'reload schema';
COMMIT;
