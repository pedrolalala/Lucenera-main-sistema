// SPEC-165 — Interpreta o texto de uma reunião de projeto (Memória Lucenera)
// e devolve uma PROPOSTA estruturada: resumo, andamento, decisões vinculadas
// ao projeto e sugestões de aproveitamento para os demais temas.
//
// Não grava nada. Quem salva é a pessoa, na tela; as sugestões vão para a
// fila de revisão e só viram item de tema depois de aprovação humana.
// Decisões marcadas como solução excepcional nunca geram sugestão (filtro
// aqui e trigger no banco).
import { createClient } from 'npm:@supabase/supabase-js@2'
import mammoth from 'npm:mammoth@1.9.0'
import { Buffer } from 'node:buffer'
import { corsHeaders } from '../_shared/cors.ts'

// Em ordem de preferência. Se um modelo responder sobrecarga (429/5xx) ou
// "não disponível" (404, modelos aposentados pelo Google), tenta o próximo;
// se todos falharem, uma segunda rodada após pausa curta. Observado em
// 29/09/2026: 503 "high demand" intermitente em quase todos os flash.
// Os "lite" são reserva: menos refinados, mas com mais capacidade livre.
const MODELOS = ['gemini-3.6-flash', 'gemini-3.8-flash', 'gemini-3.5-flash-lite', 'gemini-flash-lite-latest']
const RODADAS = 2
// Limite por tentativa, para a reserva entrar antes do teto (~150 s) da Edge Function.
const LIMITE_TENTATIVA_MS = 45_000
const LIMITE_TOTAL_MS = 135_000
const LIMITE_TEXTO = 120_000

// Chaves aceitas em `campos` por tema (espelho de src/lib/templates.ts do app).
const CAMPOS_POR_TIPO: Record<string, string[]> = {
  regra_material: ['material_aplicacao', 'combinacoes_permitidas', 'acessorios_disponiveis', 'acessorios_recomendados', 'restricoes', 'detalhamento'],
  padrao_projeto: ['materiais', 'posicionamentos', 'conceito', 'referencias'],
  teste_material: ['material', 'fabricante', 'aprovacao', 'condicoes', 'resultado', 'observacoes'],
  procedimento: ['passo_a_passo', 'responsavel', 'ferramentas', 'observacoes'],
  marca: ['segmento', 'tipo_parceria', 'contato', 'observacoes_tecnicas'],
  designer: ['especialidade', 'projetos', 'contato', 'observacoes'],
  visita_obra: ['local', 'objetivo', 'observacoes_tecnicas', 'problemas'],
  vivencia_evento: ['local', 'equipe', 'aprendizados', 'referencias'],
}

const INSTRUCAO = `Você organiza atas de reuniões de projeto de um escritório de light design (Lucenera).
Leia o texto (transcrição ou resumo de reunião) e responda SOMENTE com o JSON pedido, em português.

1. Registro da reunião (histórico): título curto do assunto, data (AAAA-MM-DD se houver), código do projeto
   (formato NN.NNN, ex.: 26.181; use a dica se o texto não trouxer), participantes, resumo em 2 a 3 frases,
   andamento do projeto (status e o que foi falado), pauta, pendências e próximos passos
   (uma linha por ação: ação — responsável — prazo, quando houver).
2. Decisões: liste cada decisão de projeto tomada na reunião, uma por item, com contexto curto.
   Marque "excepcional": true quando a decisão for uma solução pontual/excepcional para atender este
   projeto específico (exceção, improviso, adaptação de obra, pedido particular do cliente) e não algo que
   a Lucenera adotaria como regra geral.
3. Sugestões de aproveitamento: SOMENTE conhecimento reaproveitável em outros projetos que pertença a um
   destes temas: regra_material, padrao_projeto, teste_material, procedimento, marca, designer,
   visita_obra, vivencia_evento. Nunca sugira a partir de solução excepcional. Se não houver nada
   claramente reaproveitável, devolva lista vazia — é melhor não sugerir do que sugerir algo fraco.
   Cada sugestão: tema, título, campos (use apenas as chaves do tema), justificativa de por que é
   reaproveitável e o trecho da reunião de onde saiu.
Chaves por tema: ${Object.entries(CAMPOS_POR_TIPO).map(([t, c]) => `${t}: ${c.join(', ')}`).join(' | ')}.
Não invente informação que não esteja no texto.`

const S = (description?: string) => ({ type: 'STRING', ...(description ? { description } : {}) })
const SCHEMA = {
  type: 'OBJECT',
  properties: {
    titulo: S(),
    data_reuniao: S('AAAA-MM-DD ou vazio'),
    project_code: S('NN.NNN ou vazio'),
    participantes: S(),
    resumo: S(),
    andamento: S(),
    pauta: S(),
    pendencias: S(),
    proximos_passos: S(),
    decisoes: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: { decisao: S(), contexto: S(), excepcional: { type: 'BOOLEAN' }, motivo_excepcional: S() },
        required: ['decisao', 'excepcional'],
      },
    },
    sugestoes: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          tipo_destino: { type: 'STRING', enum: Object.keys(CAMPOS_POR_TIPO) },
          titulo: S(),
          campos: {
            type: 'ARRAY',
            items: { type: 'OBJECT', properties: { chave: S(), valor: S() }, required: ['chave', 'valor'] },
          },
          justificativa: S(),
          trecho_origem: S(),
          indice_decisao: { type: 'INTEGER', description: 'posição (0..n) da decisão em que se apoia, ou -1' },
          baseada_em_solucao_excepcional: { type: 'BOOLEAN' },
        },
        required: ['tipo_destino', 'titulo', 'campos', 'justificativa', 'baseada_em_solucao_excepcional'],
      },
    },
  },
  required: ['titulo', 'resumo', 'andamento', 'decisoes', 'sugestoes'],
}

function resposta(corpo: unknown, status = 200) {
  return new Response(JSON.stringify(corpo), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
}

async function extrairTexto(body: { texto?: string; arquivo_base64?: string; nome_arquivo?: string }) {
  if (body.texto?.trim()) return body.texto
  if (!body.arquivo_base64) return ''
  const bytes = Buffer.from(body.arquivo_base64, 'base64')
  const nome = (body.nome_arquivo ?? '').toLowerCase()
  if (nome.endsWith('.docx')) {
    const { value } = await mammoth.extractRawText({ buffer: bytes })
    return value
  }
  return new TextDecoder('utf-8').decode(bytes)
}

const vazio = (v: unknown) => (typeof v === 'string' ? v.trim() : '')

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return resposta({ error: 'Use POST' }, 405)

  // Só usuário interno ativo (mesma regra do RLS da base).
  const auth = req.headers.get('Authorization') ?? ''
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: auth } },
    db: { schema: 'memoria' },
  })
  const { data: interno, error: errInterno } = await sb.rpc('kb_eh_interno')
  if (errInterno || !interno) return resposta({ error: 'Acesso não autorizado' }, 401)

  const apiKey = Deno.env.get('GEMINI_API_KEY')
  if (!apiKey) return resposta({ error: 'Interpretação indisponível: GEMINI_API_KEY não configurada no servidor.' }, 500)

  let body: { texto?: string; arquivo_base64?: string; nome_arquivo?: string; project_code?: string }
  try {
    body = await req.json()
  } catch {
    return resposta({ error: 'Corpo inválido' }, 400)
  }

  let texto: string
  try {
    texto = (await extrairTexto(body)).trim()
  } catch (e) {
    return resposta({ error: `Não foi possível ler o arquivo: ${e instanceof Error ? e.message : e}` }, 400)
  }
  if (texto.length < 30) return resposta({ error: 'Texto da reunião vazio ou curto demais.' }, 400)
  const truncado = texto.length > LIMITE_TEXTO
  if (truncado) texto = texto.slice(0, LIMITE_TEXTO)

  const dica = [
    body.project_code ? `Código do projeto informado: ${body.project_code}` : '',
    body.nome_arquivo ? `Nome do arquivo: ${body.nome_arquivo}` : '',
  ].filter(Boolean).join('\n')

  const inicio = Date.now()
  let proposta: any
  let ultimoStatus: number | string = 0
  let fatal = false
  const tentativas = Array.from({ length: RODADAS }, (_, r) => MODELOS.map((m) => ({ m, r }))).flat()
  for (const { m: modelo, r: rodada } of tentativas) {
    if (proposta || fatal) break
    const restante = LIMITE_TOTAL_MS - (Date.now() - inicio)
    if (restante < 5_000) break
    if (rodada > 0 && modelo === MODELOS[0]) await new Promise((ok) => setTimeout(ok, 3000))
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), Math.min(LIMITE_TENTATIVA_MS, restante))
    try {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent?key=${apiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          signal: controller.signal,
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: INSTRUCAO }] },
            contents: [{ role: 'user', parts: [{ text: `${dica}\n\nTEXTO DA REUNIÃO:\n${texto}` }] }],
            generationConfig: { responseMimeType: 'application/json', responseSchema: SCHEMA, temperature: 0.2 },
          }),
        },
      )
      if (res.ok) {
        const data = await res.json()
        proposta = JSON.parse(data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '{}')
        console.log('Interpretado com', modelo, `${Date.now() - inicio}ms`)
        break
      }
      ultimoStatus = res.status
      console.error('Gemini erro', modelo, res.status, (await res.text()).slice(0, 300))
      // 400/401/403: problema da requisição ou da chave — não adianta insistir.
      if ([400, 401, 403].includes(res.status)) fatal = true
    } catch (e) {
      ultimoStatus = e instanceof Error && e.name === 'AbortError' ? 'tempo esgotado' : 'falha de rede'
      console.error('Gemini falhou', modelo, e)
    } finally {
      clearTimeout(timeout)
    }
  }
  if (!proposta) {
    return resposta(
      { error: `O serviço de interpretação está sobrecarregado no momento (${ultimoStatus}). Tente novamente em alguns minutos.` },
      503,
    )
  }

  const decisoes = (Array.isArray(proposta.decisoes) ? proposta.decisoes : [])
    .map((d: any) => ({
      decisao: vazio(d.decisao),
      contexto: vazio(d.contexto),
      excepcional: Boolean(d.excepcional),
      motivo_excepcional: vazio(d.motivo_excepcional),
    }))
    .filter((d: any) => d.decisao)

  // Solução excepcional nunca vira sugestão, mesmo que o modelo erre.
  const sugestoes = (Array.isArray(proposta.sugestoes) ? proposta.sugestoes : [])
    .filter((s: any) => CAMPOS_POR_TIPO[s.tipo_destino] && vazio(s.titulo) && !s.baseada_em_solucao_excepcional)
    .map((s: any) => {
      const idx = Number.isInteger(s.indice_decisao) && s.indice_decisao >= 0 && s.indice_decisao < decisoes.length ? s.indice_decisao : null
      const permitidos = CAMPOS_POR_TIPO[s.tipo_destino]
      const campos: Record<string, string> = {}
      for (const c of Array.isArray(s.campos) ? s.campos : []) {
        if (permitidos.includes(c?.chave) && vazio(c?.valor)) campos[c.chave] = vazio(c.valor)
      }
      return {
        tipo_destino: s.tipo_destino,
        titulo: vazio(s.titulo),
        campos,
        justificativa: vazio(s.justificativa),
        trecho_origem: vazio(s.trecho_origem),
        indice_decisao: idx,
      }
    })
    .filter((s: any) => s.indice_decisao === null || !decisoes[s.indice_decisao].excepcional)
    .slice(0, 8)

  const data = vazio(proposta.data_reuniao)
  return resposta({
    titulo: vazio(proposta.titulo),
    data_reuniao: /^\d{4}-\d{2}-\d{2}$/.test(data) ? data : null,
    project_code: vazio(proposta.project_code) || vazio(body.project_code) || null,
    participantes: vazio(proposta.participantes),
    resumo: vazio(proposta.resumo),
    andamento: vazio(proposta.andamento),
    pauta: vazio(proposta.pauta),
    pendencias: vazio(proposta.pendencias),
    proximos_passos: vazio(proposta.proximos_passos),
    decisoes,
    sugestoes,
    texto_truncado: truncado,
  })
})
