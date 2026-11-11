// SPEC-242: a chave anon (que está em todo site) é um JWT válido, então `verify_jwt` sozinho deixa qualquer
// visitante chamar a função. Toda função que usa a service_role tem que conferir aqui quem está chamando.
import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2'

export type Chamador = { userId: string; email: string | null; cliente: SupabaseClient }

/**
 * Exige um usuário logado de verdade (a chave anon não tem usuário → 401).
 * Com `sistemas`, exige também acesso a pelo menos um deles (Acesso a Sistemas / pode_acessar_sistema) → 403.
 * Devolve o chamador com um cliente que respeita o RLS dele, ou a Response de erro pronta.
 */
export async function exigirUsuario(
  req: Request,
  corsHeaders: Record<string, string>,
  sistemas: string[] = [],
): Promise<Chamador | Response> {
  const erro = (status: number, mensagem: string) =>
    new Response(JSON.stringify({ error: mensagem }), {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  const authHeader = req.headers.get('Authorization') ?? ''
  if (!/^Bearer\s+\S+/i.test(authHeader)) return erro(401, 'Não autorizado.')

  const cliente = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data, error } = await cliente.auth.getUser()
  if (error || !data?.user) return erro(401, 'Não autorizado.')

  if (sistemas.length > 0) {
    let liberado = false
    for (const slug of sistemas) {
      const { data: pode } = await cliente.rpc('pode_acessar_sistema', { p_slug: slug })
      if (pode === true) {
        liberado = true
        break
      }
    }
    if (!liberado) return erro(403, 'Sem acesso a este sistema.')
  }

  return { userId: data.user.id, email: data.user.email ?? null, cliente }
}
