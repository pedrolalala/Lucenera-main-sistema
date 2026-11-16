import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

// SPEC-287 (2026-11-14) — conferência diária, SÓ LEITURA, lista "Organização Projetos" × sistema.
// Chamada pelo pg_cron (disparar_conferencia_sharepoint, dias úteis 8h de São Paulo). Substitui o
// pull de 5 em 5 min: a lista não alimenta mais o sistema. NUNCA grava em `projetos`; grava uma
// linha de resumo em `sharepoint_sync_log` (direction 'conferencia', action 'ok' | 'divergencia').
//
// Divergências:
//   1. item da lista com código diferente do projeto ligado a ele (fluxo numerou diferente)
//   2. item da lista sem projeto no sistema (criado direto na lista)
//   3. projeto com sharepoint_item_id que não existe mais na lista
//   4. projeto criado há mais de 1 h sem item na lista (push falhou)

const SITE_PATH = 'lucenera.sharepoint.com:/sites/LUCENERAPROJETOS345'
const LIST_DISPLAY_NAME = 'Organização Projetos'
// itens só da lista anteriores à SPEC-287 já são conhecidos (vieram pelo pull); não repetir alarme
const INICIO_CONFERENCIA = '2026-11-14T00:00:00Z'
// itens vazios do teste da SPEC-228 (26/10/2026), pendência registrada na SPEC-287
const IGNORAR_CODIGOS = new Set(['PROV-0002', 'PROV-0003'])

function codigoOuNulo(v: unknown): string | null {
  if (v === null || v === undefined) return null
  const s = String(v).trim()
  return s === '' || s === '.' ? null : s
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '')

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

    const tokenResponse = await fetch(`https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        scope: 'https://graph.microsoft.com/.default',
        grant_type: 'client_credentials',
      }).toString(),
    })
    if (!tokenResponse.ok) throw new Error(`Falha ao obter token do Graph: ${await tokenResponse.text()}`)
    const { access_token: accessToken } = await tokenResponse.json()

    const { siteId, listId } = await resolveSiteAndList(supabase, accessToken)

    // --- todos os itens da lista (só id, título, código, criação) ---
    const itens: { id: string; titulo: string; codigo: string | null; criado: string }[] = []
    let url: string | null =
      `https://graph.microsoft.com/v1.0/sites/${siteId}/lists/${listId}/items` +
      `?$expand=fields($select=Title,field_0)&$select=id,createdDateTime&$top=999`
    while (url) {
      const resp = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } })
      if (!resp.ok) throw new Error(`Falha ao ler a lista: ${await resp.text()}`)
      const pagina = await resp.json()
      for (const it of pagina.value ?? []) {
        itens.push({
          id: String(it.id),
          titulo: String(it.fields?.Title ?? ''),
          codigo: codigoOuNulo(it.fields?.field_0),
          criado: String(it.createdDateTime ?? ''),
        })
      }
      url = pagina['@odata.nextLink'] ?? null
    }

    // --- projetos do sistema (paginado: PostgREST devolve no máximo 1.000 por vez) ---
    const projetos: any[] = []
    for (let de = 0; ; de += 1000) {
      const { data, error } = await supabase
        .from('projetos')
        .select('id, codigo, nome, sharepoint_item_id, created_at')
        .order('id')
        .range(de, de + 999)
      if (error) throw new Error(`Falha ao ler projetos: ${error.message}`)
      projetos.push(...(data ?? []))
      if (!data || data.length < 1000) break
    }

    const projetoPorItem = new Map<string, any>()
    for (const p of projetos) if (p.sharepoint_item_id) projetoPorItem.set(String(p.sharepoint_item_id), p)
    const itensPorId = new Map(itens.map((i) => [i.id, i]))

    const codigoDiferente: any[] = []
    const soNaLista: any[] = []
    for (const it of itens) {
      const p = projetoPorItem.get(it.id)
      if (!p) {
        if (it.criado >= INICIO_CONFERENCIA) soNaLista.push({ item: it.id, codigo: it.codigo, nome: it.titulo })
        continue
      }
      if (IGNORAR_CODIGOS.has(p.codigo)) continue
      // item ainda sem código (fluxo não numerou) não é divergência de código
      if (it.codigo && it.codigo !== p.codigo) {
        codigoDiferente.push({ item: it.id, codigo_lista: it.codigo, codigo_sistema: p.codigo, nome: p.nome })
      }
    }

    const sumiuDaLista: any[] = []
    const semItem: any[] = []
    const umaHoraAtras = new Date(Date.now() - 60 * 60 * 1000).toISOString()
    for (const p of projetos) {
      if (IGNORAR_CODIGOS.has(p.codigo)) continue
      if (p.sharepoint_item_id) {
        if (!itensPorId.has(String(p.sharepoint_item_id))) {
          sumiuDaLista.push({ codigo: p.codigo, nome: p.nome, item: p.sharepoint_item_id })
        }
      } else if (/^\d{2}\.\d+$/.test(p.codigo ?? '') && p.created_at >= INICIO_CONFERENCIA && p.created_at < umaHoraAtras) {
        semItem.push({ codigo: p.codigo, nome: p.nome })
      }
    }

    const total = codigoDiferente.length + soNaLista.length + sumiuDaLista.length + semItem.length
    const detalhes = {
      itens_lista: itens.length,
      projetos_sistema: projetos.length,
      codigo_diferente: codigoDiferente,
      so_na_lista: soNaLista,
      sumiu_da_lista: sumiuDaLista,
      sem_item_na_lista: semItem,
    }

    await supabase.from('sharepoint_sync_log').insert({
      direction: 'conferencia',
      action: total === 0 ? 'ok' : 'divergencia',
      source: 'sistema',
      campos_alterados: detalhes,
      resultado: total === 0 ? 'ok' : `${total} divergência(s)`,
    })

    return new Response(JSON.stringify({ success: true, divergencias: total, ...detalhes }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error: any) {
    console.error('Erro na conferência SharePoint:', error)
    await supabase.from('sharepoint_sync_log').insert({
      direction: 'conferencia',
      action: 'error',
      source: 'sistema',
      erro: error.message,
    })
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

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
  if (cachedSiteId && cachedListId) return { siteId: cachedSiteId, listId: cachedListId }

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
  const list = (await listsResponse.json()).value?.[0]
  if (!list) throw new Error(`Lista "${LIST_DISPLAY_NAME}" não encontrada no site.`)

  return { siteId, listId: list.id }
}
