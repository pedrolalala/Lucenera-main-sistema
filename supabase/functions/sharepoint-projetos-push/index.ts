import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

// SPEC-130 — push sistema -> SharePoint. Chamada pela trigger `trg_projetos_sharepoint_push`
// (migration 20260911_132, arquivo 006) via pg_net a cada criação/edição relevante de um
// projeto. Nunca chamada por usuário final — protegida por um segredo compartilhado
// (header x-sync-secret), gerado junto com o secret do Vault 'sharepoint_sync_secret'.
//
// Mapa de campos (confirmado por leitura real da lista + amostra de dados em 2026-09-11):
//   Title = nome | field_0 = codigo | field_9 = responsavel_nome | field_4 = cidade
//   Arquivado = arquivado | N_x00ed_velEstrat_x00e9_gico = "Nível N" | field_10 = status
//   (via sharepoint_status_map) | field_2 = nome do arquiteto | Respons_x00e1_veldaObra =
//   nome do responsável da obra. Campo vazio = caractere literal "." (convenção observada
//   na lista, não string vazia). NÃO envia field_6 (Data Entrada) — evidência de 2026-09-11
//   mostrou que é preenchido automaticamente pelo SharePoint na criação; escrever nele fica
//   pendente de confirmação com o Alan (SPEC-130/131).

// Anti-duplicação (fix pós-revisão, 2026-09-11): antes de criar item novo, busca por `codigo`
// na lista (ele não se repete) mesmo sem `sharepoint_item_id` salvo localmente — protege
// contra criar um segundo item quando uma tentativa anterior gravou no Graph mas falhou antes
// de confirmar no banco (achado 🔴 do revisor). Ver `03-Projeto/Auditoria/2026-09-11_auditoria_spec130_sharepoint_projetos_sync.md`.

const SITE_PATH = 'lucenera.sharepoint.com:/sites/LUCENERAPROJETOS345'
const LIST_DISPLAY_NAME = 'Organização Projetos'
const VAZIO_SHAREPOINT = '.'

function campoOuVazio(valor: string | null | undefined): string {
  const v = (valor ?? '').trim()
  return v === '' ? VAZIO_SHAREPOINT : v
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const supabase = createClient(supabaseUrl, serviceKey)

  let projetoId: string | null = null
  try {
    const syncSecret = Deno.env.get('SHAREPOINT_SYNC_SECRET')
    if (!syncSecret || req.headers.get('x-sync-secret') !== syncSecret) {
      return new Response(JSON.stringify({ error: 'Não autorizado.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const body = await req.json()
    projetoId = body.projeto_id
    const changedByUsuarioId: string | null = body.changed_by_usuario_id ?? null
    const syncHash: string | null = body.sync_hash ?? null

    if (!projetoId) throw new Error('projeto_id ausente no payload.')

    const { data: projeto, error: projetoError } = await supabase
      .from('projetos')
      .select(
        `id, nome, codigo, responsavel_nome, cidade, arquivado, nivel_estrategico, status, estado,
         sharepoint_item_id, last_sync_source,
         arquiteto:contatos!projetos_arquiteto_id_fkey(nome),
         responsavel_obra:usuarios!projetos_responsavel_obra_id_fkey(nome)`,
      )
      .eq('id', projetoId)
      .single()

    if (projetoError || !projeto) {
      throw new Error(`Projeto ${projetoId} não encontrado: ${projetoError?.message ?? 'sem dado'}`)
    }

    // defesa extra: se por algum motivo chegou aqui com origem SharePoint, não reenvia
    if (projeto.last_sync_source === 'sharepoint') {
      return new Response(JSON.stringify({ success: true, skipped: true, motivo: 'origem sharepoint' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // código é fonte única do sistema — se por acaso não tiver, gera agora
    let codigo = projeto.codigo
    if (!codigo) {
      const { data: novoCodigo, error: codigoError } = await supabase.rpc('gerar_codigo_projeto')
      if (codigoError) throw new Error(`Falha ao gerar código: ${codigoError.message}`)
      codigo = novoCodigo as string
      await supabase.from('projetos').update({ codigo }).eq('id', projetoId)
    }

    let statusSharepoint: string | null = null
    if (projeto.status) {
      const { data: statusMap } = await supabase
        .from('sharepoint_status_map')
        .select('sharepoint_valor')
        .eq('projeto_status', projeto.status)
        .maybeSingle()
      statusSharepoint = statusMap?.sharepoint_valor ?? null
    }

    // Estado é campo de lookup no SharePoint (EstadoLookupId) — precisa do ID do item na
    // lista "Estados", não da sigla (achado 2026-09-11: sem isso a automação de criação de
    // grupo/pasta não dispara). Ver sharepoint_estado_map.
    let estadoLookupId: string | null = null
    if (projeto.estado) {
      const { data: estadoMap } = await supabase
        .from('sharepoint_estado_map')
        .select('sharepoint_item_id')
        .eq('estado', String(projeto.estado).trim().toUpperCase())
        .maybeSingle()
      estadoLookupId = estadoMap?.sharepoint_item_id ?? null
    }

    const fields: Record<string, unknown> = {
      Title: projeto.nome,
      field_0: codigo,
      field_9: campoOuVazio(projeto.responsavel_nome),
      field_4: campoOuVazio(projeto.cidade),
      Arquivado: !!projeto.arquivado,
      field_2: campoOuVazio((projeto as any).arquiteto?.nome),
      Respons_x00e1_veldaObra: campoOuVazio((projeto as any).responsavel_obra?.nome),
    }
    if (projeto.nivel_estrategico) {
      fields.N_x00ed_velEstrat_x00e9_gico = `Nível ${projeto.nivel_estrategico}`
    }
    if (statusSharepoint) {
      fields.field_10 = statusSharepoint
    }
    if (estadoLookupId) {
      fields.EstadoLookupId = Number(estadoLookupId)
    }

    // --- Microsoft Graph ---
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

    let sharepointItemId = projeto.sharepoint_item_id as string | null

    // Anti-duplicação (achado 🔴 do revisor, 2026-09-11): mesmo sem sharepoint_item_id salvo
    // localmente (ex. falha entre o POST no Graph e a confirmação no banco numa tentativa
    // anterior), o código não se repete — busca por ele na lista antes de decidir criar.
    // Evita um segundo item (e disparar a automação de pasta/Teams de novo) pro mesmo projeto.
    if (!sharepointItemId && codigo) {
      const codigoEscapado = String(codigo).replace(/'/g, "''")
      const buscaResponse = await fetch(
        `https://graph.microsoft.com/v1.0/sites/${siteId}/lists/${listId}/items?$filter=fields/field_0 eq '${codigoEscapado}'&$expand=fields`,
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            Prefer: 'HonorNonIndexedQueriesWarningMayFailRandomly',
          },
        },
      )
      if (buscaResponse.ok) {
        const buscaData = await buscaResponse.json().catch(() => ({}))
        const achado = buscaData.value?.[0]
        if (achado) sharepointItemId = achado.id
      }
      // busca falhou (ex. coluna não indexada recusada mesmo com o header) — segue tentando
      // criar; não trava o push por causa disso, só reduz a proteção contra duplicata.
    }

    let graphResponse: Response
    const foiCriacao = !sharepointItemId
    if (!sharepointItemId) {
      graphResponse = await fetch(
        `https://graph.microsoft.com/v1.0/sites/${siteId}/lists/${listId}/items`,
        {
          method: 'POST',
          headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ fields }),
        },
      )
    } else {
      graphResponse = await fetch(
        `https://graph.microsoft.com/v1.0/sites/${siteId}/lists/${listId}/items/${sharepointItemId}/fields`,
        {
          method: 'PATCH',
          headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(fields),
        },
      )
    }

    const graphData = await graphResponse.json().catch(() => ({}))

    if (!graphResponse.ok) {
      await supabase.from('sharepoint_sync_log').insert({
        projeto_id: projetoId,
        sharepoint_item_id: sharepointItemId,
        direction: 'push',
        action: 'error',
        source: 'sistema',
        changed_by_usuario_id: changedByUsuarioId,
        campos_alterados: fields,
        payload_hash: syncHash,
        erro: JSON.stringify(graphData),
      })
      throw new Error(`Graph recusou a gravação: ${JSON.stringify(graphData)}`)
    }

    if (!sharepointItemId) {
      sharepointItemId = graphData.id
    }

    const { error: confirmError } = await supabase.rpc('confirmar_push_sharepoint', {
      p_projeto_id: projetoId,
      p_sharepoint_item_id: sharepointItemId,
      p_sync_hash: syncHash,
      p_changed_by_usuario_id: changedByUsuarioId,
    })
    if (confirmError) throw new Error(`Falha ao confirmar push no banco: ${confirmError.message}`)

    await supabase.from('sharepoint_sync_log').insert({
      projeto_id: projetoId,
      sharepoint_item_id: sharepointItemId,
      direction: 'push',
      action: foiCriacao ? 'create' : 'update',
      source: 'sistema',
      changed_by_usuario_id: changedByUsuarioId,
      campos_alterados: fields,
      payload_hash: syncHash,
      resultado: 'ok',
    })

    return new Response(
      JSON.stringify({ success: true, sharepoint_item_id: sharepointItemId }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error: any) {
    console.error('Erro no push SharePoint:', error)
    if (projetoId) {
      await supabase.from('sharepoint_sync_log').insert({
        projeto_id: projetoId,
        direction: 'push',
        action: 'error',
        source: 'sistema',
        erro: error.message,
      })
    }
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
