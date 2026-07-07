# Migration 20260708_030 - SPEC-007 (SSO entre sistemas)

## Contexto

Ver `03-Projeto/Planos de Ação/SPECs/SPEC-007_Token_Acesso_Compartilhado_Entre_Sistemas.md`.

## Arquivos

| Arquivo | Função |
|---|---|
| `001_cross_system_session_codes.sql` | Cria a tabela central de códigos opacos de troca, com expiração de 60 segundos e uso único. |

## Segurança

- A tabela fica com RLS habilitado e sem grants diretos para `anon`/`authenticated`.
- Escrita/leitura/consumo acontecem somente pelas Edge Functions `generate-cross-system-code` e `exchange-cross-system-code`, usando `SUPABASE_SERVICE_ROLE_KEY` no runtime.
- O código vai na URL; tokens de sessão não vão.

## Verificação esperada

- Código expirado ou já usado retorna erro na troca.
- Código gerado por um usuário não aceita `usuario_id` no payload.
- O destino recebe uma sessão Supabase válida via `setSession` ou `verifyOtp`.
