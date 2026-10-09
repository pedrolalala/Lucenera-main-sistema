# Passo a passo — Migração do Supabase de Ohio para São Paulo

> Plano técnico completo: `03-Projeto/Planos de Ação/SPECs/SPEC-192_Migracao_Supabase_Sao_Paulo.md`.
> Aqui está **quem faz o quê, em que ordem e como conferir**.
>
> - **Ohio (atual):** projeto `LUCENERA DATACENTER`, ref `vcvcwzmbiftcawncibke`, região us-east-2.
> - **São Paulo (novo):** ref `bgtfrcbipuxnsexbppsh`, região sa-east-1. Endereço: `https://bgtfrcbipuxnsexbppsh.supabase.co`.
>
> Legenda: **[VOCÊ]** = feito por você no painel ou em outro sistema · **[CLAUDE]** = eu faço pelo terminal ·
> ✅ = como conferir que deu certo.

---

## Visão geral

| Etapa | O que é | Afeta quem usa o sistema? | Duração |
|---|---|---|---|
| 1 | Contratar o plano e o servidor em São Paulo | Não | 10 min |
| 2 | Preparar São Paulo (arquivos, functions, login, tarefas) | Não | 1 dia |
| 3 | Ensaio geral com um sistema de teste | Não | 2–3 h |
| 4 | **Virada** (janela com sistemas parados) | **Sim — sistemas fora do ar** | 3–4 h |
| 5 | Testes com a equipe e liberação | Sim | 1–2 h |
| 6 | Acompanhamento e desligar Ohio | Não | 2 semanas |

Até a etapa 4, **todo mundo continua usando Ohio normalmente**. São Paulo só passa a valer na virada.

---

## Etapa 1 — Contratar plano e servidor [VOCÊ]

O projeto de São Paulo está em outra organização do Supabase (a da conta `pedro@lucenera.com.br`). O plano pago é
por **organização**.

1. Entre em **supabase.com/dashboard** com a conta dona do projeto de São Paulo.
2. Menu da esquerda, no topo → selecione a **organização do projeto de São Paulo** → **Billing**.
3. Clique em **Change subscription plan** → escolha **Pro** (US$ 25/mês) → confirme o cartão.
4. Abra o projeto de São Paulo → **Project Settings** (engrenagem) → **Compute and Disk**.
5. Em **Compute size**, escolha **Micro** (já incluso no crédito do Pro) → **Save**.
   O projeto reinicia sozinho em 1–2 minutos. Como está vazio de uso, não atrapalha ninguém.
6. Ainda em Project Settings → **General**: confira que a região é **South America (São Paulo)**.

✅ Me avise "plano feito". Eu confiro pela API: o compute tem que aparecer como `ci_micro` (hoje aparece vazio = Nano).

> **Ohio:** não precisa pagar nada. Mas Ohio pode cair de novo por falta de disco antes da virada. Se cair, ou
> fazemos a virada logo, ou você sobe Ohio para Micro temporariamente (exige Pro também na organização de Ohio).
> Por isso, quanto antes for a virada, melhor.

---

## Etapa 2 — Preparar São Paulo (sem afetar ninguém)

### 2.1 Banco de dados [CLAUDE] — ✅ já feito no ensaio de 08/10

Estrutura e dados copiados e conferidos: 156 tabelas, 128.623 linhas, funções, regras de acesso, triggers e views
idênticos, acentos corretos. Na virada, eu recarrego só os dados (Ohio continua mudando até lá).

### 2.2 Arquivos (Storage) [CLAUDE]

Copiar os ~140 MB dos 9 buckets (`showroom-lucenera`, `revenda-ubiqua-images`, `orcamentos`, `notas_fiscais`,
`notas_fiscais_compra`, `garantia_anexos`, `producao_pedidos`, `lucenera-memory-files`, `Logo`), com os mesmos
nomes e caminhos.

✅ Quantidade e tamanho de arquivos por bucket iguais nos dois projetos (eu mostro a tabela). Abrir 2 fotos do
Showroom pelo endereço novo.

### 2.3 Segredos das Edge Functions [VOCÊ + CLAUDE]

A API do Supabase só mostra o **nome** dos segredos, nunca o valor. Situação de cada um:

| Segredo | De onde vem o valor |
|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_URL` | O Supabase cria sozinho no projeto novo |
| `GEMINI_API_KEY` | `.env` (já tenho) |
| `SHAREPOINT_CLIENT_ID`, `SHAREPOINT_TENANT_ID`, `SHAREPOINT_CLIENT_SECRET` | `.env` (já tenho) |
| `SHAREPOINT_SYNC_SECRET` | Eu leio do cofre (vault) de Ohio |
| `GMAIL_USER`, `GMAIL_APP_PASSWORD` | **[VOCÊ]** — o e-mail e a "senha de app" do Gmail usados para enviar e-mails |
| `RESEND_API_KEY` | **[VOCÊ]** — painel do Resend (resend.com → API Keys); pode gerar uma nova |
| `lucenera Gestão Financeira` | **[VOCÊ]** — nome estranho, provavelmente sobra de teste. Se não souber o que é, deixamos de fora |

Como me passar os valores: **coloque no `.env`** (no bloco de São Paulo), por exemplo `GMAIL_USER=...`,
`GMAIL_APP_PASSWORD=...`, `RESEND_API_KEY=...`, e me avise. **Não cole senhas no chat.**

✅ Eu cadastro e mostro a lista de nomes no projeto novo (16 nomes, iguais aos de Ohio).

### 2.4 Edge Functions (27) [CLAUDE]

Publico as 27 funções no projeto novo, com a mesma configuração de "exige login ou não" (verify_jwt) de Ohio.
O código vem do repositório (`supabase/functions/`) e, para as que só existem nos projetos do Skip
(nota fiscal, Focus NFe, Ubiqua, cross-system-code, interpretar-reuniao etc.), do próprio Skip.

✅ Lista das 27 funções ativas no projeto novo, e uma chamada de teste em cada uma (tem que responder, não dar 404).

### 2.5 Tarefas agendadas e cofre (vault) [CLAUDE]

- Cofre: recriar `sharepoint_pull_url`, `sharepoint_push_url`, `sharepoint_sync_secret`, `supabase_anon_key`,
  **já com os endereços de São Paulo**.
- Tarefas: `ferias-gerar-periodos` (todo dia 06:00 UTC) e `sharepoint-projetos-pull` (a cada 5 min).
  **Ficam criadas, mas desligadas até a virada** (senão São Paulo puxaria o SharePoint em paralelo com Ohio).

✅ `cron.job` com as 2 tarefas (desligadas) e o cofre com os 4 nomes.

### 2.6 Configuração do login (Auth) [CLAUDE, ou VOCÊ se preferir pelo painel]

- **URL Configuration:** Site URL e os 38 endereços de retorno dos sistemas (`https://*.goskip.app/**`), iguais a Ohio.
- Expiração da sessão: 3600 s (igual).
- Modelos de e-mail (confirmação/recuperação de senha): copiar de Ohio, se tiverem sido personalizados.

Pelo painel, se quiser conferir: projeto São Paulo → **Authentication** → **URL Configuration**.

✅ Lista de endereços igual à de Ohio.

### 2.7 Levantamento nos sistemas do Skip [CLAUDE]

Para cada um dos 16 sistemas, anotar **onde** está o endereço do Supabase (variável de ambiente do Skip e/ou
ligação Supabase do projeto) e corrigir os **5 arquivos com o endereço fixo no código**:
- Catálogo Ubiqua: `PartDetailSheet.tsx`, `use-parts.ts`
- CRM: `Layout.tsx`
- Separação Parcial: `LoginPage.tsx`, `SeparacaoParcialPage.tsx`

Nesses 5, troco o endereço fixo por variável de ambiente **antes da virada**: continua apontando para Ohio,
então não muda nada para quem usa. Na virada, basta trocar a variável.

✅ Planilha com os 16 sistemas, onde fica a configuração de cada um, e os 5 arquivos corrigidos e publicados.

---

## Etapa 3 — Ensaio geral [CLAUDE + VOCÊ]

1. [CLAUDE] Escolho um sistema simples (ex.: Controle de Garantia) e publico uma **cópia de teste** apontando
   para São Paulo (versão de pré-visualização do Skip, não a oficial).
2. [VOCÊ] Entra nessa versão de teste com seu login e senha de sempre → abre telas, cadastra algo de teste, anexa
   uma foto.
3. [CLAUDE] Confiro no banco de São Paulo que gravou, e apago o teste.

✅ Login funcionou com a senha antiga; tela carregou dados; gravação e foto funcionaram.

Se algo falhar aqui, corrigimos **antes** de marcar a janela.

---

## Etapa 4 — Virada (dia D)

### 4.0 Antes do dia [VOCÊ]

- [ ] Marcar a data e a hora (sugestão: **sábado, 19h**, previsão até 23h).
- [ ] Avisar a equipe com 2 dias de antecedência. Mensagem sugerida:
  > "Sábado, das 19h às 23h, os sistemas da Lucenera (Central, Orçamentos, Cadastro, RH, Compras, Vendas, etc.)
  > ficarão fora do ar para mudança de servidor. Salve o que estiver fazendo antes das 19h. No domingo, ao entrar,
  > será preciso fazer login de novo (a senha continua a mesma)."
- [ ] Combinar quem testa o quê no fim da virada (ver 5.1).
- [ ] Não rodar a importação da Connect no sábado à tarde.

### 4.1 Congelar (19:00) [CLAUDE]

1. Desligo as tarefas agendadas de Ohio (SharePoint e férias).
2. Coloco os sistemas em manutenção, ou simplesmente ninguém usa no horário combinado.

✅ Nenhuma gravação nova em Ohio nos últimos 5 minutos (eu confiro pela data de alteração das tabelas).

### 4.2 Copiar os dados finais (19:15) [CLAUDE]

1. Cópia final dos dados de Ohio (5–10 min, o banco é pequeno).
2. Em São Paulo: esvazio os dados do ensaio e carrego os novos, com os mesmos cuidados do ensaio.
3. Copio os arquivos novos do Storage (os que entraram depois da etapa 2.2).

✅ Contagem de linhas **tabela a tabela igual** nos dois projetos (156 tabelas) e arquivos iguais por bucket.
Se não bater, não sigo: paro e investigo.

### 4.3 Ligar São Paulo (20:00) [CLAUDE]

1. Ligo as 2 tarefas agendadas em São Paulo.
2. Troco o endereço e a chave do Supabase nos **16 sistemas do Skip** e republico cada um.
3. Atualizo o `.env` central (o bloco de São Paulo vira o principal; Ohio fica comentado como "antigo").
4. Memória Lucenera: endereço no `supabase-adapter.js`.

✅ Cada sistema publicado e, no código no ar, aparece o endereço novo (`bgtfrcbipuxnsexbppsh`) e **nenhum** com o
antigo.

### 4.4 Integrações externas (20:30) [VOCÊ + CLAUDE]

- [ ] **[VOCÊ] Focus NFe:** painel da Focus → configurações de webhook/gatilho → trocar o endereço para
  `https://bgtfrcbipuxnsexbppsh.supabase.co/functions/v1/focus-nfe-webhook`.
- [ ] **[CLAUDE] SharePoint:** já fica certo pelo cofre (2.5). Faço um teste de envio e de leitura de projeto.
- [ ] **[CLAUDE]** Script de importação da Connect: rodo em modo de teste (sem gravar) contra São Paulo. Tem que dar
  "nada a alterar" em relação à planilha já importada.

### 4.5 Bloquear Ohio (21:00) [CLAUDE, com seu OK]

Coloco Ohio **somente leitura**. Assim, se algum lugar esquecido ainda apontar para Ohio, ele dá erro na hora e
aparece no teste, em vez de gravar no banco antigo sem ninguém perceber.

---

## Etapa 5 — Testes e liberação

### 5.1 Roteiro de testes (21:00–22:30) [VOCÊ + equipe]

Cada pessoa entra com **o próprio login** (vai pedir login de novo; a senha é a mesma):

| Sistema | O que testar | Quem |
|---|---|---|
| Central | Login, lista de sistemas, entrar em outro sistema pelo menu (sem pedir senha de novo), "Minha senha" | Pedro |
| Orçamentos | Abrir um orçamento, criar um de teste, mandar para aprovação, aprovar, ver PDF | Pedro / Vinícius |
| Vendas | Abrir uma venda, ver itens; NF-e em **homologação** (não emitir nota real) | Pedro |
| Cadastro | Consulta de Produtos: 12895 tem que mostrar R$ 142,29; editar sem salvar | Pedro |
| Compras | Necessidade de compra abre com números | Débora |
| Separação / Logística | Abrir pedido em separação; imprimir | Mateus |
| Showroom | Vitrine abre com fotos | Pedro |
| RH | Férias da Vitória (saldo −2) e Lana (9) | Lana |
| Adm. Bancária / Dashboard | Contas a pagar/receber abrem; total confere com sexta | Pedro |
| CRM, Garantia, Produção, Memória, Catálogo Ubiqua | Abrir, listar, abrir um registro | Pedro |

[CLAUDE] Durante os testes, acompanho os erros no banco (`erros_tela`) e nos logs das functions.

### 5.2 Decisão (22:30) [VOCÊ]

- **Tudo ok:** libera para a equipe. Ohio continua somente leitura.
- **Problema grave sem solução rápida → voltar para Ohio:**
  1. [CLAUDE] Volto o endereço antigo nos sistemas e republico (≈ 30 min).
  2. [CLAUDE] Tiro Ohio do somente leitura e religo as tarefas de lá.
  3. Como os testes foram só de leitura e cadastros de teste, nada real se perde.
  4. Corrigimos o problema e marcamos nova janela.

---

## Etapa 6 — Depois da virada

- [ ] **Segunda-feira:** acompanhar o primeiro dia de uso real (lentidão, erros, e-mails, NF-e de verdade).
- [ ] **Primeira importação da Connect** no projeto novo (dry-run antes).
- [ ] **Semana 1:** conferir o consumo de disco e CPU em São Paulo (Reports). Se ficar perto do limite, subir para Small.
- [ ] **Semana 2:** se tudo estiver normal, [CLAUDE] faço um backup final de Ohio (arquivo guardado no
  computador/OneDrive) e **[VOCÊ] apaga o projeto de Ohio** (Project Settings → General → Delete project).
- [ ] [CLAUDE] Atualizar documentação e memórias com o endereço novo.

---

## Resumo do que preciso de você (em ordem)

1. **Agora:** assinar o Pro e colocar São Paulo em Micro (etapa 1).
2. **Agora:** colocar no `.env` os valores de `GMAIL_USER`, `GMAIL_APP_PASSWORD`, `RESEND_API_KEY` e dizer o que é
   o segredo "lucenera Gestão Financeira" (etapa 2.3).
3. **Autorizar** eu seguir com a etapa 2 (só grava em São Paulo).
4. **Testar** a versão de ensaio (etapa 3).
5. **Marcar a janela** e avisar a equipe (etapa 4.0).
6. **No dia:** trocar o webhook na Focus NFe (4.4), liberar ou mandar voltar (5.2).
7. **Duas semanas depois:** apagar Ohio (etapa 6).
