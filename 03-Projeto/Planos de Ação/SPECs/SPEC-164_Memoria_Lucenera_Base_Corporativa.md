---
titulo: "SPEC-164 — Memória Lucenera: readaptação para base de conhecimento corporativa"
status: concluído
data_ultima_modificacao: 2026-09-28
sistemas_envolvidos:
  - Memória Lucenera (Skip 57204, 04-Sistemas/memoria-lucenera)
  - Supabase (schema memoria)
  - Hub/TI (papel_permissoes)
---

# SPEC-164 — Memória Lucenera: base de conhecimento corporativa

## Checklist de Ação

- [x] Diagnóstico do estado atual — `04-Sistemas/memoria-lucenera/DIAGNOSTICO.md` (stack, modelo, telas, problemas, classificação MANTER/ADAPTAR/REMOVER).
- [x] Migration `supabase/db/migrations/20260924_164_memoria_base_corporativa/` (001 modelo, 002 RLS/Hub, 003 busca, 004 sinônimos, 005 cópia do conteúdo existente, 099 verificação).
- [x] Dry-run da migration com ROLLBACK + testes de RLS como `authenticated` (usuário comum e curador).
- [x] Aplicar a migration no Supabase real.
- [x] Frontend React no Skip 57204: home com busca dominante, autocomplete, chips de categoria, atalhos por tema.
- [x] Inserção guiada por tipo (9 templates) com salvar imediato, rascunho e anexos de imagem.
- [x] Tela do item (leitura, edição, arquivar, anexos, histórico).
- [x] Pendentes antigos: listar os itens da caixa de entrada antiga do próprio usuário com atalho para registrar como Reunião de projeto.
- [x] App antigo movido para rota oculta (`/legado`), sem apagar código; signUp aberto e modo demonstração desligados.
- [x] Teste ponta a ponta pela API real (supabase-js como usuário autenticado: buscar, sugerir, inserir, anexar, editar, histórico, arquivar, permissões). 24/24 depois da 006.
- [x] Teste visual no navegador (Playwright + Chrome headless, na produção).
- [x] Identidade visual Lucenera padronizada com a Central (logo branca + azul-marinho `hsl(222 47% 11%)` + dourado `hsl(45 93% 47%)`).
- [x] Publicar no Skip.
- [x] Documentação: `supabase/db/domains/memoria.md`, `docs/status_enums.md`, `04-Sistemas/00 - Sumario Sistemas.md`, `CHANGELOG.md`, DIAGNOSTICO.md §7.

### Passos manuais do usuário

- [x] Aplicar a migration `20260924_164_memoria_base_corporativa` (arquivos 001 a 005, em ordem) no Supabase real — a aplicação automática foi bloqueada pelo controle de permissões da sessão. Depois rodar `099_verify.sql` (esperado: 54 itens, 0 órfãos).
- [x] Publicar o Skip 57204 (v0.0.12 já passou no QA). **Só depois da migration**: sem ela, a interface nova mostra "Base em atualização" após o login.

- [ ] Validar a home e o fluxo de inserção com 1 ou 2 pessoas da equipe (critério: achar uma regra em segundos, registrar uma reunião em menos de 1 minuto).
- [ ] Decidir se outros papéis do Hub (ex.: `gerente`) também serão curadores — basta conceder `aprovar` no sistema `memoria` pelo Hub, sem migration.

## Objetivo

O app foi construído como memória pessoal do fundador (RLS por dono, taxonomia pessoal, formulário genérico por tabela). Readaptar para uso corporativo com dois pilares de mesmo peso: consulta rápida (qualquer pessoa acha uma informação em segundos) e captura estruturada (registrar é rápido e guiado por tipo).

## Decisões aprovadas (2026-09-24, com o usuário)

- **Importação de planilhas Connect: fora do escopo.** A Memória Lucenera não recebe dados da Connect; a reconciliação dos imports Connect é a SPEC-157. O modelo guarda `origem`/`origem_fonte`/`origem_chave` (chave estável) para uma importação futura sem mudança de schema.
- **Permissões: todos leem, autor edita.** Usuário interno ativo (`public.usuarios.ativo`) lê tudo que está publicado e cria itens; rascunho só o autor vê; editar/arquivar = autor ou curador; apagar = só curador. Curador = `hub_pode_executar(uid, 'memoria', NULL, 'aprovar')`, concedido a `admin` e `admin_geral`.
- **Interface: React no próprio Skip 57204** (scaffold React/Vite/shadcn que já existe no projeto). O app estático antigo fica numa rota oculta durante a transição.
- **Conteúdo sem tipo equivalente** (regras comerciais, modelos de texto, cadastro institucional, links) **vira Procedimento interno**, com tags de subtema. Mantidos exatamente os 9 tipos.

## Definição

### Tipos e núcleos

| Núcleo (`kb_categoria`) | Natureza | Tipos (`kb_tipo`) |
|---|---|---|
| `tecnico` | referência estável | `regra_material`, `padrao_projeto`, `teste_material` |
| `comercial` | referência estável | `marca`, `designer` |
| `operacional` | referência estável | `procedimento` |
| `projeto` | registro contínuo | `reuniao_projeto`, `visita_obra` |
| `aprendizado` | registro contínuo | `vivencia_evento` |

A categoria é coluna gerada a partir do tipo (nunca diverge).

### Banco (`memoria`)

- `kb_itens`: tipo, categoria (gerada), titulo, resumo, `campos jsonb` (campos do template), `tags text[]`, `data_referencia`, `project_code`, status (`rascunho/publicado/arquivado`), origem (`manual/importada`) + `origem_fonte`/`origem_chave` (único), `legado_tabela`/`legado_id` (único), `autor_id` (**ON DELETE SET NULL**), `atualizado_por`, `revisado_em`, `proxima_revisao`, `metadata`, timestamps. Colunas `*_norm` mantidas por trigger para a busca.
- `kb_itens_versoes`: snapshot da versão anterior a cada alteração de conteúdo (trigger).
- `kb_anexos`: arquivos por item no bucket `lucenera-memory-files`, prefixo `kb/<item_id>/`. `metadata jsonb` reservado para busca por imagem futura (descrição visual, embedding) — pode ganhar coluna nova sem quebrar nada.
- `kb_sinonimos (grupo, termo)`: dicionário de jargão de light design, editável pelo curador. Semente com 21 grupos (downlight/luminária de embutir, temperatura de cor, CRI/IRC/fidelidade cromática, ângulo de abertura, facho, UGR/ofuscamento, preparação/infraestrutura, fotometria, acendimento, dimerização, fita LED, sanca, wall washer etc.).
- RPC `kb_buscar(q, categoria, tipo, limite, prefixo)`: acento/caixa ignorados, sinônimos (inclusive expressões de várias palavras), E entre conceitos, relevância título (10) > conteúdo (4) > tags (2), sinônimo vale 80%, correção de erro de digitação pelo dicionário, trecho em volta da ocorrência. SECURITY INVOKER (RLS decide o que aparece).
- RPC `kb_sugerir(q)`: autocomplete (títulos + tags + termos técnicos).
- Tabelas antigas intactas. Conteúdo existente **copiado** (54 itens: 31 conhecimentos, 17 marcas, 4 cadastros institucionais, 2 links), com o registro original completo em `metadata.legado`.

### Templates (campos em `campos jsonb`)

| Tipo | Título | Data | Campos |
|---|---|---|---|
| Reunião de projeto | Assunto | Data | participantes, pauta, decisoes, pendencias, acoes (ações e responsáveis) + código do projeto |
| Visita em obra | Obra | Data | local, objetivo, observacoes_tecnicas, problemas + fotos + código do projeto |
| Teste de material | Título do teste | Data do teste | material, fabricante, condicoes, resultado, aprovacao (aprovado/reprovado/condicional), observacoes + fotos |
| Regra de uso de material | Título da regra | — | material_aplicacao, combinacoes_permitidas, acessorios_disponiveis, acessorios_recomendados, restricoes, detalhamento + referência visual |
| Padrão de projeto | Padrão | — | materiais, posicionamentos, conceito, referencias + imagens |
| Procedimento interno | Nome do procedimento | — | passo_a_passo, responsavel, ferramentas, observacoes |
| Marca | Nome | — | segmento, tipo_parceria, contato, observacoes_tecnicas |
| Designer | Nome | — | especialidade, projetos, contato, observacoes |
| Vivência de evento | Evento | Data | local, equipe, aprendizados, referencias + fotos |

Campos obrigatórios: só tipo e título. O resto é opcional para manter a inserção abaixo de 1 minuto.

### Riscos de RLS e critério de teste

- Risco: base inteira invisível se `kb_eh_interno()` falhar → testado como `mariane@` (vê 54) e `pedro@` (vê 54, curador).
- Risco: usuário comum editar/apagar item alheio → testado: UPDATE em item importado de outro autor afeta 0 linhas; DELETE afeta 0; INSERT com `autor_id` de outra pessoa é bloqueado.
- Storage: leitura de `kb/%` para internos; exclusão pelo dono do objeto ou curador. A policy antiga (pasta `<uid>/`) não muda.

### Rollback

Aditivo. Para desfazer: `DROP` das 4 tabelas `kb_*`, das funções `kb_*`, dos 4 tipos `kb_*`, das 3 policies `memoria_kb_anexos_*` em `storage.objects` e `DELETE FROM public.papel_permissoes WHERE acao='aprovar' AND system_id=(SELECT id FROM systems WHERE slug='memoria')`. Nenhum dado antigo é afetado.

## Realizado

### 2026-09-24

- Diagnóstico escrito (`04-Sistemas/memoria-lucenera/DIAGNOSTICO.md`). Achados principais: RLS por dono torna a base invisível para a equipe; `ON DELETE CASCADE` em `owner_id` apagaria o conhecimento de quem for desligado; upload/voz nunca funcionaram (3 recapitulações de reunião de 23/09 paradas na caixa de entrada); busca por `JSON.stringify`; signUp aberto no Auth compartilhado; HTML sem escape.
- Migration escrita e testada em dry-run (ROLLBACK), inclusive RLS como `authenticated` e busca com sinônimos/erro de digitação ("downlight", "dowlight", "luminária de embutir" e "embutir" encontram "Spots Embutidos"; "CRI" encontra "Fidelidade Cromática"). Aplicação no banco real bloqueada pelo controle de permissões — ficou como passo manual.
- Interface React escrita no Skip 57204 (21 arquivos: `src/lib/kb.ts`, `src/lib/templates.ts`, `src/hooks/use-auth.tsx`, `src/components/{Layout,CaixaBusca,ChipsCategoria,Destaque,FormularioItem}.tsx`, `src/pages/{Index,Buscar,Novo,NovoItem,Item,EditarItem,Pendentes,Login,NovaSenha,Legado}.tsx`, `App.tsx`, `main.css`, `tailwind.config.ts`, `index.html`). Type-check, lint e build locais OK; QA do Skip verde (v0.0.12 `11d8d24`, preview). Não publicada. Mesmo código espelhado no submodule `04-Sistemas/memoria-lucenera` (não commitado).

### 2026-09-24 (tarde) — aplicação, publicação e teste

- Migration 001-005 aplicada no Supabase real com autorização do usuário (54 itens, 0 órfãos, tabelas antigas intactas, `aprovar` para admin/admin_geral).
- Skip 57204 publicado (`11d8d24`), produção servindo o bundle novo; `/`, `/buscar`, `/novo/*`, `/legado` respondem 200.
- Teste ponta a ponta pela API real, logado como `pedro@` (curador): 22/24 na primeira rodada. Falhas reais corrigidas pela `006_correcoes_pos_teste.sql` (aplicada): (1) `project_code` não era pesquisável, mas a tela do item linka o código para a busca; (2) `service_role` sem GRANT nas tabelas `kb_*`. Segunda rodada 24/24. Item de teste, anexo e arquivo no storage apagados no final.
- Permissões de usuário comum conferidas no banco real simulando `mariane@` (transação desfeita): vê 54, cria o próprio, edita alheio = 0, apaga = 0, vê seus 4 pendentes.

### 2026-09-24 (fim da tarde) — identidade visual + teste visual

- Pedido do usuário: padronizar com a marca. Cabeçalho e painel de login em azul-marinho da Central (`--marinho: 222 47% 11%`), logo Lucenera branca (horizontal no cabeçalho, vertical no login, recortadas das artes da Central e da Logística), dourado da Central (`45 93% 47%`) no botão Inserir e no realce da busca; área de leitura clara em tom frio. Logos embutidas como data URI em `src/lib/marca*.ts` (o MCP do Skip não grava binário; a vertical foi dividida em 2 arquivos por limite de escrita).
- Teste visual com Playwright + Chrome headless (sessão real via magic link do admin): login, home, autocomplete, busca, tema, item, editar, cancelar, inserir, celular.
- **Bug achado e corrigido (estava em produção desde `11d8d24`):** qualquer navegação por clique deixava a tela em branco. `useEffect(() => window.scrollTo(0, 0))` devolvia o retorno de `scrollTo`; o `skip.js` substitui `window.scrollTo` por uma versão que devolve Promise, e o React quebra ao chamar a "limpeza". Corrigido com corpo em bloco (Layout e CaixaBusca).
- Publicado `67f3ef1` (v0.0.13); roteiro por cliques repetido na produção sem erros.

### 2026-09-28 — formulário de item novo travado

- Relato do usuário: em Reunião de projeto não conseguia mexer em nada. Causa: `FormularioItem` recebia `anexosAtuais = []` como padrão (array novo a cada render); o efeito das prévias dependia dele e chamava `setPrevias({})` com objeto novo, gerando loop infinito de renderização que congelava a página. Afetava **os 9 formulários de item novo** (a edição não, porque lá os anexos vêm de estado estável). O teste visual de 24/09 não pegou porque só tirou captura da tela, sem digitar.
- Correção: constante estável `SEM_ANEXOS` + efeito só roda quando há imagem. Publicado `3371e9f` (v0.0.14). Verificado na produção: digitação nos 9 formulários e o caminho Pendentes → Reunião de projeto (título, código 23.249 e texto da recapitulação pré-preenchidos).

## Pendências

- [ ] SSO a partir da Central e upload de foto pelo formulário não foram exercitados no navegador (upload foi testado pela API).

- [ ] Fase de IA (transcrição de voz, interpretação de documentos) segue fora do escopo; as Edge Functions da SPEC-129 nunca foram implantadas.
- [ ] As tabelas antigas continuam com `owner_id ON DELETE CASCADE`; como o conteúdo foi copiado para `kb_itens` (SET NULL), o risco fica restrito ao app legado.
