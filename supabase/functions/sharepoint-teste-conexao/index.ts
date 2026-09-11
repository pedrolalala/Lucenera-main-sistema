import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { corsHeaders } from '../_shared/cors.ts'

// Função TEMPORÁRIA de teste de conectividade com a lista "Organização Projetos" do SharePoint.
// Objetivo único: provar que a permissão Sites.Selected (write) da app "Lucenera CRM" (SPEC-131,
// Item 3, concluído em 2026-09-11) realmente grava na lista, antes de construir o pipeline
// definitivo (SPEC-130). NÃO faz parte da SPEC-130 — apagar esta function depois do teste.
//
// Cria 1 item de teste na lista, com Title marcado como TESTE e o campo de responsável/vendedor
// preenchido (por padrão "Mariane", a pedido do usuário). O nome interno do campo de responsável
// é um PALPITE (`field_9`, visto na leitura de colunas da SPEC-047 em 2026-07-24) — ainda não
// confirmado pelo Alan (SPEC-131, Item 2). Se a coluna certa for outra, o item ainda assim é
// criado (só esse campo específico fica vazio) — o teste de escrita continua válido.

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const tenantId = Deno.env.get('SHAREPOINT_TENANT_ID')
    const clientId = Deno.env.get('SHAREPOINT_CLIENT_ID')
    const clientSecret = Deno.env.get('SHAREPOINT_CLIENT_SECRET')

    if (!tenantId || !clientId || !clientSecret) {
      throw new Error(
        'Credenciais do SharePoint ausentes. Configure SHAREPOINT_TENANT_ID, SHAREPOINT_CLIENT_ID e ' +
          'SHAREPOINT_CLIENT_SECRET nos secrets da Edge Function com os valores da app "Lucenera CRM".',
      )
    }

    // 1. Token via client credentials
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
    if (!tokenResponse.ok) {
      const errTxt = await tokenResponse.text()
      throw new Error(`Falha ao obter token do Microsoft Graph. Detalhes: ${errTxt}`)
    }
    const { access_token: accessToken } = await tokenResponse.json()

    // 2. Resolver o site
    const siteResponse = await fetch(
      'https://graph.microsoft.com/v1.0/sites/lucenera.sharepoint.com:/sites/LUCENERAPROJETOS345',
      { headers: { Authorization: `Bearer ${accessToken}` } },
    )
    if (!siteResponse.ok) {
      const errTxt = await siteResponse.text()
      throw new Error(
        `Falha ao acessar o site do SharePoint (permissão pode não estar concedida ainda). Detalhes: ${errTxt}`,
      )
    }
    const { id: siteId } = await siteResponse.json()

    // 3. Resolver a lista "Organização Projetos"
    const listsResponse = await fetch(
      `https://graph.microsoft.com/v1.0/sites/${siteId}/lists?$filter=displayName eq 'Organização Projetos'`,
      { headers: { Authorization: `Bearer ${accessToken}` } },
    )
    if (!listsResponse.ok) {
      const errTxt = await listsResponse.text()
      throw new Error(`Falha ao buscar listas do site. Detalhes: ${errTxt}`)
    }
    const listsData = await listsResponse.json()
    const list = listsData.value?.[0]
    if (!list) {
      throw new Error(
        'Lista "Organização Projetos" não encontrada nesse site. Confirmar com o Alan o displayName exato ' +
          '(SPEC-131 cita divergência entre "Organização Projetos" e "Organização de Projetos").',
      )
    }

    // 4. Criar o item de teste
    const body = await req.json().catch(() => ({}))
    const nomeResponsavel: string = body.responsavel ?? 'Mariane'
    const titulo: string =
      body.titulo ?? `TESTE CONEXÃO SPEC-130/131 — NÃO CONSIDERAR (${new Date().toISOString()})`

    const createResponse = await fetch(
      `https://graph.microsoft.com/v1.0/sites/${siteId}/lists/${list.id}/items`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          fields: {
            Title: titulo,
            // Responsável/vendedor — nome interno a confirmar (palpite: field_9). Ver comentário no topo.
            field_9: nomeResponsavel,
          },
        }),
      },
    )

    const createData = await createResponse.json()

    return new Response(
      JSON.stringify({
        success: createResponse.ok,
        status: createResponse.status,
        siteId,
        listId: list.id,
        listDisplayName: list.displayName,
        itemCriado: createResponse.ok ? createData : null,
        erro: createResponse.ok ? null : createData,
        aviso: 'Item de TESTE criado na lista real — apagar manualmente depois de conferir.',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: createResponse.ok ? 201 : 500,
      },
    )
  } catch (error: any) {
    console.error('Erro no teste de conexão SharePoint:', error)
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
