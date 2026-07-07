import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const root = decodeURIComponent(new URL('..', import.meta.url).pathname).replace(/\/$/, '')

const checks = []

function file(path) {
  return join(root, path)
}

function read(path) {
  return readFileSync(file(path), 'utf8')
}

function expectFile(path, label) {
  checks.push({
    label,
    pass: existsSync(file(path)),
  })
}

function expectContains(path, pattern, label) {
  const content = existsSync(file(path)) ? read(path) : ''
  checks.push({
    label,
    pass: pattern instanceof RegExp ? pattern.test(content) : content.includes(pattern),
  })
}

expectFile(
  'supabase/db/migrations/20260708_029_spec006_permissoes_granulares_hub/001_tabelas.sql',
  'SPEC-006 migration cria tabelas de permissao',
)
expectContains(
  'supabase/db/migrations/20260708_029_spec006_permissoes_granulares_hub/002_rpcs.sql',
  'hub_pode_executar',
  'SPEC-006 publica RPC hub_pode_executar',
)
expectContains(
  '04-Sistemas/central-lucenera-dashboard-1c9ba/src/pages/Dashboard.tsx',
  'hub_sistemas_permitidos',
  'Hub usa RPC hub_sistemas_permitidos nos cards',
)
expectFile(
  'supabase/db/migrations/20260708_030_spec007_sso_cross_system/001_cross_system_session_codes.sql',
  'SPEC-007 migration cria cross_system_session_codes',
)
expectFile(
  'supabase/functions/generate-cross-system-code/index.ts',
  'SPEC-007 Edge Function generate-cross-system-code existe',
)
expectFile(
  'supabase/functions/exchange-cross-system-code/index.ts',
  'SPEC-007 Edge Function exchange-cross-system-code existe',
)
expectContains(
  '04-Sistemas/central-lucenera-dashboard-1c9ba/src/lib/cross-system-auth.ts',
  'redirectWithCode',
  'Hub tem helper redirectWithCode',
)
expectContains(
  '04-Sistemas/retorno-bancario-bradesco-5392a/src/hooks/use-auth.tsx',
  'consumeCodeFromUrl',
  'Financeiro consome sso_code antes do login',
)
expectContains(
  '04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/budgets/FinanceResultModal.tsx',
  'redirectWithCode',
  'Orcamentos abre Financeiro via codigo SSO',
)
expectContains(
  '04-Sistemas/lucenera-crm-3bd29 (1)/src/pages/ProjectDetail.tsx',
  'redirectWithCode',
  'CRM abre Orcamentos via codigo SSO',
)

const failed = checks.filter((check) => !check.pass)

for (const check of checks) {
  console.log(`${check.pass ? 'PASS' : 'FAIL'} ${check.label}`)
}

if (failed.length > 0) {
  console.error(`\n${failed.length} contrato(s) SPEC-006/007 ainda pendente(s).`)
  process.exit(1)
}
