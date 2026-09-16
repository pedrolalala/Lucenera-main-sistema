-- SPEC-134: campo "Código do Projeto" em todos os formulários de adicionar
-- informação da Memória Lucenera (schema memoria). Texto livre (sem FK para
-- public.projetos — o domínio memoria nunca referencia public), para marcar
-- qualquer registro com o código do projeto Lucenera (ex.: 26.181) e facilitar
-- a busca depois.
begin;

alter table memoria.entities add column if not exists project_code text;
alter table memoria.knowledge_items add column if not exists project_code text;
alter table memoria.experiences add column if not exists project_code text;
alter table memoria.decisions add column if not exists project_code text;
alter table memoria.projects add column if not exists project_code text;
alter table memoria.sources add column if not exists project_code text;
alter table memoria.inbox_items add column if not exists project_code text;

create index if not exists entities_project_code_idx on memoria.entities(project_code) where project_code is not null;
create index if not exists knowledge_items_project_code_idx on memoria.knowledge_items(project_code) where project_code is not null;
create index if not exists experiences_project_code_idx on memoria.experiences(project_code) where project_code is not null;
create index if not exists decisions_project_code_idx on memoria.decisions(project_code) where project_code is not null;
create index if not exists projects_project_code_idx on memoria.projects(project_code) where project_code is not null;
create index if not exists sources_project_code_idx on memoria.sources(project_code) where project_code is not null;
create index if not exists inbox_items_project_code_idx on memoria.inbox_items(project_code) where project_code is not null;

commit;
