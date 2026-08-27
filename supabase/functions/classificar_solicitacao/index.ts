// SPEC-121: classifica um pedido (solicitacoes) como "estrutural" ou
// "pontual" chamando a API do Gemini. Falha da IA (chave ausente, API fora
// do ar, resposta que não é JSON válido) NUNCA deve travar o pedido — só
// deixa `classificacao_ia` como null, pra ser reclassificado depois.
import { createClient } from 'npm:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const SYSTEM_INSTRUCTION = `Você classifica pedidos internos de bug ou alteração de sistema para a
empresa Lucenera. Sua única tarefa é decidir se o pedido é ESTRUTURAL ou
PONTUAL, e devolver SEMPRE um JSON válido, sem nenhum texto fora do JSON.

Definições:
- ESTRUTURAL: o sistema fica incorreto, trava, perde dado, bloqueia um
  fluxo de trabalho, ou produz um resultado errado sem essa mudança. Bugs
  que impedem alguém de concluir uma tarefa são sempre estruturais.
- PONTUAL: preferência visual, texto, cor, posição de um botão, atalho de
  conveniência, ou qualquer ajuste onde o sistema já funciona corretamente
  sem a mudança — só fica "melhor" ou "mais do jeito que a pessoa gosta".

Na dúvida entre as duas, classifique como ESTRUTURAL — o custo de revisar
uma coisa pontual à toa é menor que o de ignorar um bug real.

Responda SOMENTE com este JSON, nada antes nem depois:
{
  "classificacao": "estrutural" | "pontual",
  "justificativa": "1-2 frases em português explicando o motivo",
  "confianca": 0.0 a 1.0
}`

interface ClassificacaoResultado {
  classificacao: 'estrutural' | 'pontual'
  justificativa: string
  confianca: number
}

function parseClassificacao(texto: string): ClassificacaoResultado | null {
  try {
    const parsed = JSON.parse(texto)
    if (parsed.classificacao !== 'estrutural' && parsed.classificacao !== 'pontual') return null
    if (typeof parsed.justificativa !== 'string') return null
    return {
      classificacao: parsed.classificacao,
      justificativa: parsed.justificativa,
      confianca: typeof parsed.confianca === 'number' ? parsed.confianca : 0.5,
    }
  } catch {
    return null
  }
}

async function classificarComGemini(userMessage: string): Promise<ClassificacaoResultado | null> {
  const apiKey = Deno.env.get('GEMINI_API_KEY')
  if (!apiKey) {
    console.error('GEMINI_API_KEY não configurada — pulando classificação.')
    return null
  }

  const controller = new AbortController()
  // 28s, não 10s: o Gemini 3.6-flash (modelo "thinking") demora <1s em
  // pedidos curtos, mas observado levando >20s em pedidos mais longos/
  // complexos (achado ao testar com um bug real na SPEC-121) — 10s cortava
  // a classificação de exatamente os pedidos mais importantes de classificar.
  const timeout = setTimeout(() => controller.abort(), 28000)

  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: controller.signal,
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
          contents: [{ role: 'user', parts: [{ text: userMessage }] }],
          generationConfig: { responseMimeType: 'application/json' },
        }),
      },
    )

    if (!res.ok) {
      console.error('Gemini respondeu com erro:', res.status, await res.text())
      return null
    }

    const data = await res.json()
    const texto = data?.candidates?.[0]?.content?.parts?.[0]?.text
    if (!texto) return null

    return parseClassificacao(texto)
  } catch (err) {
    console.error('Falha ao chamar Gemini:', err)
    return null
  } finally {
    clearTimeout(timeout)
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { solicitacao_id } = await req.json()
    if (!solicitacao_id) {
      return new Response(JSON.stringify({ error: 'solicitacao_id é obrigatório' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const { data: solicitacao, error: fetchError } = await supabase
      .from('solicitacoes')
      .select('id, titulo, descricao, tipo, sistema_relacionado_id, systems(name)')
      .eq('id', solicitacao_id)
      .single()

    if (fetchError || !solicitacao) {
      return new Response(JSON.stringify({ error: 'Pedido não encontrado' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 404,
      })
    }

    const sistemaNome = (solicitacao as any).systems?.name || 'não informado'
    const userMessage = `Tipo do pedido: ${solicitacao.tipo}
Sistema relacionado: ${sistemaNome}
Título: ${solicitacao.titulo}
Descrição: ${solicitacao.descricao}`

    const resultado = await classificarComGemini(userMessage)

    if (resultado) {
      await supabase
        .from('solicitacoes')
        .update({
          classificacao_ia: resultado.classificacao,
          justificativa_ia: resultado.justificativa,
          confianca_ia: resultado.confianca,
        })
        .eq('id', solicitacao_id)
    }

    return new Response(JSON.stringify({ success: true, resultado }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error: any) {
    console.error('Erro em classificar_solicitacao:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
