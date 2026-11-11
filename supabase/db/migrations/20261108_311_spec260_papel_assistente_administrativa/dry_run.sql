BEGIN;
\i up.sql
SELECT p.nome FROM public.usuario_papeis up JOIN public.papeis p ON p.id=up.papel_id JOIN public.usuarios u ON u.id=up.usuario_id WHERE lower(u.email)='caroline@lucenera.com.br' ORDER BY 1;
SELECT count(*) FROM public.papel_permissoes pp JOIN public.papeis p ON p.id=pp.papel_id WHERE p.nome='assistente_administrativa';
ROLLBACK;
