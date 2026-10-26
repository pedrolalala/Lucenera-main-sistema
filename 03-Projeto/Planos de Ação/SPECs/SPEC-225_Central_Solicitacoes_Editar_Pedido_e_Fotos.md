---
titulo: "SPEC-225 — Central de Solicitações: autor edita o pedido enquanto está Aberto + fotos anexadas ao pedido"
status: implementada (no ar 26/10; falta o teste do usuário)
data_ultima_modificacao: 2026-10-26
sistemas_envolvidos:
  - Central de Solicitações (central-de-solicitacoes) — Novo Pedido e Detalhe do pedido
  - Banco (Supabase SP) — solicitacoes, tabela nova solicitacao_anexos, bucket privado solicitacoes-anexos
---

# SPEC-225 — Editar o próprio pedido e anexar fotos

> Pedido do usuário (26/10/2026): "permitir para quem efetuou o pedido de editar o pedido mesmo, pelo menos na
> primeira fase em aberto. Talvez depois que começa ser atendido não deve ser editável, e possibilitar de anexar uma
> foto para conseguir explicar com mais facilidade um pedido de alteração".

## Como está hoje (conferido em 26/10)
- Tabela `solicitacoes` (SPEC-121); status: aberto, em_analise, aprovado, rejeitado, em_desenvolvimento, concluido.
- A tela **não tem** edição. O banco tem a policy `solicitacoes_update_autor_aberto` (autor + status aberto) mas o
  `WITH CHECK` só exige `usuario_id = auth.uid()` — o autor poderia mudar **qualquer coluna**, inclusive o status e a
  classificação da IA.
- Não há anexo de arquivo/foto.

## Decisões
1. **Editar:** só o **autor**, só com status **Aberto** (depois que começa a ser atendido, não edita). Campos: título,
   descrição, tipo e sistema relacionado. Pela RPC `editar_minha_solicitacao`; a policy solta sai. Ao editar, a
   classificação da IA é refeita.
2. **Fotos:** imagens (JPG, PNG, WEBP, GIF) até 10 MB, várias por pedido. Anexa o **autor** (ao criar e enquanto o
   pedido estiver Aberto) e **quem atende** (permissão `aprovar` da Central, a qualquer momento). Remover: quem anexou
   enquanto o pedido estiver Aberto; o aprovador a qualquer momento. Todos que veem o pedido veem as fotos.
3. Bucket **privado** `solicitacoes-anexos` (link temporário para ver); tabela `solicitacao_anexos` com RLS.

## Checklist de Ação
- [x] A1. Migration: RPC `editar_minha_solicitacao` + troca da policy de update do autor; tabela `solicitacao_anexos`
      (RLS, sem anon); bucket privado + policies de storage; função `solicitacao_pode_anexar`; dry-run + rollback
- [x] B1. Novo Pedido: escolher fotos (prévia, remover antes de salvar); sobem depois de criar o pedido
- [x] B2. Detalhe: botão **Editar** (autor + Aberto) com o mesmo formulário; aviso "só dá para editar enquanto está Aberto"
- [x] B3. Detalhe: galeria de fotos (clique abre grande), "Adicionar fotos" e remover (quando pode)
- [x] C1. Docs: CHANGELOG, `supabase/docs/relationships.md`

## Rollback
- `rollback.sql`: volta a policy antiga, remove RPC/tabela/policies de storage (os arquivos do bucket ficam; apagar pelo
  painel se quiser). Telas: reverter o commit do sistema.

## Realizado

### 2026-10-26
- Migration `supabase/db/migrations/20261026_240_spec225_solicitacoes_editar_fotos/` (`001_solicitacoes_editar_fotos.sql`
  + `rollback.sql`) **APLICADA** no SP: RPC `editar_minha_solicitacao` (autor + Aberto; zera a classificação da IA);
  policy `solicitacoes_update_autor_aberto` removida; `solicitacao_pode_anexar(uuid)` e
  `solicitacao_pode_anexar_arquivo(text)`; tabela `solicitacao_anexos` (RLS: ver = logado; pôr/tirar = autor com pedido
  Aberto ou quem tem `aprovar`); bucket privado `solicitacoes-anexos` (10 MB, JPG/PNG/WEBP/GIF) com policies.
- Dry-run em ROLLBACK (pedido de teste criado e desfeito): autor edita (ok); autor muda status direto (0 linhas);
  outro usuário edita (erro); depois de "Em análise" autor não edita nem anexa nem remove; aprovador anexa; storage
  aceita a pasta do pedido e recusa outra; `anon` sem acesso; rollback devolve a policy antiga.
- Central de Solicitações `165238c` (no ar pelo GitHub): Novo Pedido com "Fotos (opcional)" (escolher, arrastar ou colar
  um print com Ctrl+V; prévia e tirar antes de salvar); Detalhe com botão **Editar** (autor + Aberto; aviso quando já
  está sendo atendido) e galeria de fotos (clicar abre grande; adicionar/remover quando pode).

