import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

// SPEC-130 — pull SharePoint -> sistema. Chamada pelo pg_cron (via disparar_pull_sharepoint(),
// migration 20260911_132, arquivo 010) a cada 5 min. Usa a query `delta` do Graph (só traz o
// que mudou desde a última execução, via deltaLink persistido em sharepoint_sync_state).
//
// NÃO TESTADA AO VIVO AINDA — a paginação/formato exato da resposta de delta numa lista do
// SharePoint deve ser confirmada na primeira homologação manual (SPEC-130, critério de
// aceite) antes de ligar o cron de produção.
//
// SharePoint tratado como fonte de verdade nesta fase (decisão do usuário, 2026-09-11, pra
// resolver o risco de duplicidade sem a complexidade de detecção de conflito ainda): o pull
// SEMPRE aplica o que vier de lá, sem comparar `updated_at`. Só pula quando o conteúdo já é
// idêntico (otimização). Detecção de conflito de verdade (comparando com a data de
// modificação real do item no SharePoint, não `updated_at` genérico) fica pra uma fase
// futura, quando push e pull rodarem como duas vias simultâneas de verdade.

const SITE_PATH = 'lucenera.sharepoint.com:/sites/LUCENERAPROJETOS345'
const LIST_DISPLAY_NAME = 'Organização Projetos'

function valorOuNulo(v: unknown): string | null {
  if (v === null || v === undefined) return null
  const s = String(v).trim()
  return s === '' || s === '.' ? null : s
}

function extrairNivel(v: unknown): string | null {
  const s = valorOuNulo(v)
  if (!s) return null
  const m = s.match(/\d+/)
  return m ? m[0] : null
}

function extrairData(v: unknown): string | null {
  const s = valorOuNulo(v)
  if (!s) return null
  const d = new Date(s)
  return isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10)
}

async function sha256(texto: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(texto))
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const supabase = createClient(supabaseUrl, serviceKey)

  // `conflitos` fica sempre 0 nesta fase — SharePoint é tratado como fonte de verdade (decisão
  // do usuário, 2026-09-11), sem detecção de conflito. Mantido no resumo pra quando a detecção
  // de conflito voltar, numa fase futura de duas vias simultâneas de verdade.
  const resumo = { processados: 0, criados: 0, atualizados: 0, ignorados: 0, conflitos: 0, erros: 0 }

  try {
    const syncSecret = Deno.env.get('SHAREPOINT_SYNC_SECRET')
    if (!syncSecret || req.headers.get('x-sync-secret') !== syncSecret) {
      return new Response(JSON.stringify({ error: 'Não autorizado.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const tenantId = Deno.env.get('SHAREPOINT_TENANT_ID')
    const clientId = Deno.env.get('SHAREPOINT_CLIENT_ID')
    const clientSecret = Deno.env.get('SHAREPOINT_CLIENT_SECRET')
    if (!tenantId || !clientId || !clientSecret) {
      throw new Error('Credenciais do SharePoint ausentes nos secrets da Edge Function.')
    }

    const tokenResponse = await fetch(
      `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          client_id: clientId,
          client_secret: clientSecret,
          scope: 'https://graph.microsoft.com/.default',
          grant_type: 'client_credentials',
        }).toString(),
      },
    )
    if (!tokenResponse.ok) throw new Error(`Falha ao obter token do Graph: ${await tokenResponse.text()}`)
    const { access_token: accessToken } = await tokenResponse.json()

    const { siteId, listId } = await resolveSiteAndList(supabase, accessToken)

    // --- mapas de nome -> id, carregados uma vez por execução ---
    const { data: contatos } = await supabase.from('contatos').select('id, nome')
    const { data: usuarios } = await supabase.from('usuarios').select('id, nome')
    const mapaContatos = new Map((contatos ?? []).map((c: any) => [c.nome.trim().toLowerCase(), c.id]))
    const mapaUsuarios = new Map((usuarios ?? []).map((u: any) => [u.nome.trim().toLowerCase(), u.id]))

    const { data: statusMapRows } = await supabase.from('sharepoint_status_map').select('*')
    const mapaStatusReverso = new Map(
      (statusMapRows ?? []).map((r: any) => [String(r.sharepoint_valor).trim(), r.projeto_status]),
    )

    const { data: estadoMapRows } = await supabase.from('sharepoint_estado_map').select('*')
    const mapaEstadoReverso = new Map(
      (estadoMapRows ?? []).map((r: any) => [String(r.sharepoint_item_id), r.estado]),
    )

    // --- delta: continua de onde parou, ou começa do zero ---
    const { data: estadoDelta } = await supabase
      .from('sharepoint_sync_state')
      .select('valor')
      .eq('chave', 'delta_link')
      .maybeSingle()

    let proximaUrl =
      estadoDelta?.valor ??
      `https://graph.microsoft.com/v1.0/sites/${siteId}/lists/${listId}/items/delta?$expand=fields`

    let novoDeltaLink: string | null = null

    while (proximaUrl) {
      const resp = await fetch(proximaUrl, { headers: { Authorization: `Bearer ${accessToken}` } })
      if (!resp.ok) throw new Error(`Falha na consulta delta: ${await resp.text()}`)
      const pagina = await resp.json()

      for (const item of pagina.value ?? []) {
        if (item['@removed']) continue // exclusão nunca propaga (decisão da SPEC-130)
        resumo.processados++
        try {
          await processarItem(supabase, item, mapaContatos, mapaUsuarios, mapaStatusReverso, mapaEstadoReverso, resumo)
        } catch (err: any) {
          resumo.erros++
          await supabase.from('sharepoint_sync_log').insert({
            sharepoint_item_id: String(item.id ?? ''),
            direction: 'pull',
            action: 'error',
            source: 'sharepoint',
            erro: err.message,
          })
        }
      }

      if (pagina['@odata.nextLink']) {
        proximaUrl = pagina['@odata.nextLink']
      } else {
        novoDeltaLink = pagina['@odata.deltaLink'] ?? null
        proximaUrl = ''
      }
    }

    if (novoDeltaLink) {
      await supabase.from('sharepoint_sync_state').upsert({
        chave: 'delta_link',
        valor: novoDeltaLink,
        updated_at: new Date().toISOString(),
      })
    }

    return new Response(JSON.stringify({ success: true, ...resumo }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error: any) {
    console.error('Erro no pull SharePoint:', error)
    return new Response(JSON.stringify({ success: false, error: error.message, ...resumo }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

async function processarItem(
  supabase: ReturnType<typeof createClient>,
  item: any,
  mapaContatos: Map<string, string>,
  mapaUsuarios: Map<string, string>,
  mapaStatusReverso: Map<string, string>,
  mapaEstadoReverso: Map<string, string>,
  resumo: Record<string, number>,
) {
  const fields = item.fields ?? {}
  const sharepointItemId = String(item.id)

  const nome = valorOuNulo(fields.Title)
  const codigo = valorOuNulo(fields.field_0)
  const responsavelNome = valorOuNulo(fields.field_9)
  const cidade = valorOuNulo(fields.field_4)
  const arquivado = typeof fields.Arquivado === 'boolean' ? fields.Arquivado : null
  const nivel = extrairNivel(fields.N_x00ed_velEstrat_x00e9_gico)
  const statusValorSharepoint = valorOuNulo(fields.field_10)
  const status = statusValorSharepoint ? mapaStatusReverso.get(statusValorSharepoint) ?? null : null
  const nomeArquiteto = valorOuNulo(fields.field_2)
  const nomeResponsavelObra = valorOuNulo(fields.Respons_x00e1_veldaObra)
  const arquitetoId = nomeArquiteto ? mapaContatos.get(nomeArquiteto.toLowerCase()) ?? null : null
  const responsavelObraId = nomeResponsavelObra
    ? mapaUsuarios.get(nomeResponsavelObra.toLowerCase()) ?? null
    : null
  // Data Entrada (field_6): fix 2026-09-11 — a SPEC-130 já tinha sido corrigida confirmando que
  // é a data de entrada de verdade (amostra real da lista), mas o código ficou desatualizado
  // mandando NULL sempre. Corrigido aqui.
  const dataEntrada = extrairData(fields.field_6)
  // Estado é lookup (EstadoLookupId = id numérico do item na lista "Estados", não texto).
  const estadoLookupId = fields.EstadoLookupId != null ? String(fields.EstadoLookupId) : null
  const estado = estadoLookupId ? mapaEstadoReverso.get(estadoLookupId) ?? null : null

  const syncHash = await sha256(
    JSON.stringify({ nome, codigo, responsavelNome, cidade, arquivado, dataEntrada, nivel, status, arquitetoId, responsavelObraId, estado }),
  )

  // Busca em duas consultas separadas (nunca concatenar `codigo` — vindo do SharePoint, texto
  // livre — direto numa string de filtro: achado 🔴 do revisor em 2026-09-11, risco de quebrar
  // ou casar o filtro errado com vírgula/parêntese no valor). Cada `.eq()` é parametrizado pelo
  // supabase-js, sem risco de injeção.
  let existente: any = null
  {
    const { data } = await supabase
      .from('projetos')
      .select('id, nome, codigo, responsavel_nome, cidade, arquivado, data_entrada, status, arquiteto_id, responsavel_obra_id, estado')
      .eq('sharepoint_item_id', sharepointItemId)
      .maybeSingle()
    existente = data
  }
  if (!existente && codigo) {
    const { data } = await supabase
      .from('projetos')
      .select('id, nome, codigo, responsavel_nome, cidade, arquivado, data_entrada, status, arquiteto_id, responsavel_obra_id, estado')
      .eq('codigo', codigo)
      .is('sharepoint_item_id', null)
      .maybeSingle()
    existente = data
  }

  const changedBySharepoint =
    item.lastModifiedBy?.user?.displayName ?? item.lastModifiedBy?.application?.displayName ?? null

  // SharePoint é tratado como fonte de verdade nesta fase (decisão do usuário, 2026-09-11):
  // o pull sempre aplica o que vier de lá, sem segurar por "o sistema editou depois" — a
  // lógica de conflito por `updated_at` (frágil: a coluna é tocada por Orçamentos/Financeiro/RH
  // também) foi removida daqui. Só pula quando o conteúdo já está idêntico (otimização, não
  // proteção).
  if (existente) {
    const igual =
      (existente.nome ?? null) === nome &&
      (existente.codigo ?? null) === (codigo ?? existente.codigo) &&
      (existente.responsavel_nome ?? null) === responsavelNome &&
      (existente.cidade ?? null) === cidade &&
      (existente.arquivado ?? null) === (arquivado ?? existente.arquivado) &&
      (existente.data_entrada ?? null) === (dataEntrada ?? existente.data_entrada) &&
      (existente.status ?? null) === (status ?? existente.status) &&
      (existente.arquiteto_id ?? null) === (arquitetoId ?? existente.arquiteto_id) &&
      (existente.responsavel_obra_id ?? null) === (responsavelObraId ?? existente.responsavel_obra_id) &&
      (existente.estado ?? null) === (estado ?? existente.estado)

    if (igual) {
      resumo.ignorados++
      return
    }
  }

  const { data: rpcResult, error: rpcError } = await supabase.rpc('aplicar_pull_sharepoint', {
    p_sharepoint_item_id: sharepointItemId,
    p_nome: nome,
    p_codigo: codigo,
    p_responsavel_nome: responsavelNome,
    p_cidade: cidade,
    p_arquivado: arquivado,
    p_data_entrada: dataEntrada,
    p_nivel_estrategico: nivel,
    p_status: status,
    p_arquiteto_id: arquitetoId,
    p_responsavel_obra_id: responsavelObraId,
    p_estado: estado,
    p_sync_hash: syncHash,
  })
  if (rpcError) throw new Error(`aplicar_pull_sharepoint falhou: ${rpcError.message}`)

  const linha = Array.isArray(rpcResult) ? rpcResult[0] : rpcResult
  if (linha?.acao === 'create') resumo.criados++
  else resumo.atualizados++

  await supabase.from('sharepoint_sync_log').insert({
    projeto_id: linha?.projeto_id ?? null,
    sharepoint_item_id: sharepointItemId,
    direction: 'pull',
    action: linha?.acao === 'create' ? 'create' : 'update',
    source: 'sharepoint',
    changed_by_sharepoint: changedBySharepoint,
    campos_alterados: fields,
    payload_hash: syncHash,
    resultado: 'ok',
  })
}

async function resolveSiteAndList(
  supabase: ReturnType<typeof createClient>,
  accessToken: string,
): Promise<{ siteId: string; listId: string }> {
  const { data: cached } = await supabase
    .from('sharepoint_sync_state')
    .select('chave, valor')
    .in('chave', ['site_id', 'list_id'])

  const cachedSiteId = cached?.find((c) => c.chave === 'site_id')?.valor
  const cachedListId = cached?.find((c) => c.chave === 'list_id')?.valor
  if (cachedSiteId && cachedListId) {
    return { siteId: cachedSiteId, listId: cachedListId }
  }

  const siteResponse = await fetch(`https://graph.microsoft.com/v1.0/sites/${SITE_PATH}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  })
  if (!siteResponse.ok) throw new Error(`Falha ao resolver o site: ${await siteResponse.text()}`)
  const { id: siteId } = await siteResponse.json()

  const listsResponse = await fetch(
    `https://graph.microsoft.com/v1.0/sites/${siteId}/lists?$filter=displayName eq '${LIST_DISPLAY_NAME}'`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  )
  if (!listsResponse.ok) throw new Error(`Falha ao resolver a lista: ${await listsResponse.text()}`)
  const listsData = await listsResponse.json()
  const list = listsData.value?.[0]
  if (!list) throw new Error(`Lista "${LIST_DISPLAY_NAME}" não encontrada no site.`)

  await supabase.from('sharepoint_sync_state').upsert([
    { chave: 'site_id', valor: siteId, updated_at: new Date().toISOString() },
    { chave: 'list_id', valor: list.id, updated_at: new Date().toISOString() },
  ])

  return { siteId, listId: list.id }
}
