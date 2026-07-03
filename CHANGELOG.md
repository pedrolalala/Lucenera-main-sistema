# Changelog

Registro cronologico das mudancas no repositorio central `Lucenera - ADAPTA PASS`.

## 2026-06-26

### Atualizado

- Baixadas as Edge Functions remotas atuais do projeto Supabase `vcvcwzmbiftcawncibke`.
- Removida a cópia central de `sync-fechamentos-automatica`, ausente no remoto.
- Documentado `process-billing-automation` como legado ainda ativo no remoto e fora do fluxo novo.
- Espelhadas as migrations da SPEC-005 em `supabase/db/migrations/20260626_009_spec005_remocao_triggers_legados_aprovacao/`.
- Atualizados domínios, inventário de automações, mapa de relacionamentos, status/enums e contexto global do Supabase.
- Atualizadas SPECs 001-005 e `00_TASKS_GERAIS_ECOSSISTEMA.md` com o que foi confirmado nos repos e no remoto.
- Puxadas atualizações dos repositórios de sistemas; alterações locais existentes foram preservadas em stash antes do pull.

### Pendente

- Reextrair `supabase/db/current/` após a SPEC-005. A tentativa local falhou sem Docker/`pg_dump`.
- Confirmar remoção definitiva de `process-billing-automation` após checar scheduler/webhook externo.
- Homologar o fluxo de aprovação real com orçamento completo, frete, prazo, histórico, parcelas e boletos.

### Adicionado

- Criada governanca inicial do repositorio central.
- Criado `README.md` com fontes de verdade, estrutura alvo e regras de leitura.
- Criado `AGENTS.md` geral com fluxo obrigatorio para IA/desenvolvedor.
- Criada regra de `.gitignore` para evitar commit de `.env`, `node_modules`, `dist` e temporarios.
- Criados documentos operacionais em `00-Contexto/`.
- Criados `AGENTS.md` por area principal do repositorio central.
- Adicionada instrucao de submodules em `00-Contexto/SUBMODULES.md`.
- Adicionados scripts `scripts/submodules-clone-all.sh` e `scripts/submodules-register.sh`.
- Adicionado `.env.example` e instrucao para criar `.env` local geral para acesso ao Supabase.

### Decisao

- O repositorio central guarda memoria, contexto, banco consolidado, relatorios, specs e inventario.
- Cada sistema continua sendo atualizado tambem em seu repositorio proprio.
- Sistemas com repositorio proprio devem ser registrados como submodules dentro de `04-Sistemas/`.
- O `.env` geral deve existir apenas localmente e nao deve ser commitado.
- O banco consolidado em `supabase/` e a fonte de verdade tecnica; migrations antigas dentro de sistemas sao historico, nao definicao final.
