# Instrucao da Pasta scripts

Esta pasta guarda scripts administrativos e de manutencao do repositorio central: clonar/registrar submodules e importar dados pontuais para o Supabase.

## Regras

- Scripts que acessam o Supabase real devem usar o `.env` geral da raiz do repositorio central (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_URL`). Nunca hardcodar credencial.
- Script de importacao pontual (ex.: `importar_razao_social_clientes.py`) deve ser idempotente ou documentar claramente que roda uma unica vez.
- `submodules-clone-all.sh` e `submodules-register.sh` sao os unicos scripts que devem alterar `.gitmodules`; qualquer novo sistema deve passar por eles em vez de `git submodule add` manual sem registro.
- Nunca commitar `.env`, dump de banco ou credencial dentro desta pasta.

## Antes de rodar ou criar um script aqui

1. Confirmar que o `.env` da raiz existe e esta correto.
2. Ler `../00-Contexto/` para entender se a acao ja e coberta por um fluxo existente.
3. Rodar em modo leitura/dry-run primeiro quando o script alterar dados de producao.
