---
titulo: "SPEC-027 — Decisões da reunião Filippo/Pedro 13-07-2026"
status: concluído
data_ultima_modificacao: 2026-07-15
sistemas_envolvidos:
  - Central Lucenera (hub de sistemas, Skip id 37750)
  - Dashboard Lucenera / Dashboard Financeiro (Skip id 41135)
dependencias:
  - SPEC-026 (Melhorias diversas — captura ampla de tudo que foi discutido na mesma reunião)
---

# SPEC-027 — Decisões da reunião Filippo/Pedro 13-07-2026

> Releitura da mesma transcrição da SPEC-026
> (`02-Reunioes/09. lucenera (Filippo) - 06.07.2026_.../00_original/Reniao com o Filippo e Pedro 13-07.txt`),
> desta vez separando especificamente o que foi **decidido** (ação combinada)
> do que foi só discutido/explorado. A releitura encontrou **um item decidido
> que a SPEC-026 não capturou**: restringir o acesso ao Dashboard Financeiro.
> Isso é urgente porque o card já foi publicado no hub **sem** essa restrição.

---

## Checklist de Ação

### Achado novo — acesso ao Dashboard Financeiro (não estava na SPEC-026)
- [x] Investigado e explicado ao usuário: o painel "Acesso a Sistemas" da Central (`user_system_access`) **não tem efeito** para os 4 usuários `admin` (Pedro, Vinicius, Filippo, Kimberly), porque `Dashboard.tsx` pula a checagem de permissão inteira para `role='admin'`. **Decisão do usuário (2026-07-15): manter como está** — não restringir, os 4 admins continuam vendo o card "Dashboard Financeiro". Nenhuma mudança de código feita.

### Itens já decididos e já cobertos pela SPEC-026 (sem trabalho novo aqui)

Tabela de conferência — nenhum destes precisa de ação nesta SPEC, só confirma que a releitura não achou nada além do que já está registrado:

| Decisão | Onde está |
|---|---|
| Criar um sistema próprio só para o dashboard (não dentro do CRM nem da Administração Bancária) | SPEC-026 item 4 — feito, é o "Dashboard Lucenera" (Skip id 41135) |
| Gráfico Custo Fixo × Variável | SPEC-026 item 2 — implementado |
| Tela/KPI de Markup (Ponto de Equilíbrio) | SPEC-026 item 3 — implementado |
| Sistemas internos abrem em nova aba | SPEC-026 item 4 — implementado (e corrigido 2x depois, bug de popup blocker) |
| Dias em aberto na Necessidade de Compra | SPEC-026 item 5 — implementado |
| Prazo de entrega automático no orçamento (dias úteis) | SPEC-026 item 6 — implementado |
| Prazo de entrega por produto/marca | SPEC-026 item 7 — coluna criada, valores reais pendentes |
| Múltiplo de compra (MOQ / caixa fechada) | SPEC-026 item 8 — coluna criada, valores reais pendentes |
| Estoque mínimo / ponto de reposição | SPEC-026 item 9 — coluna criada, alerta ainda não implementado |
| Reunião com Débora antes de mexer em Pedido de Compra | SPEC-026 item 10 — bloqueado, reunião ainda não agendada |
| Busca por cliente em "Pendentes" (Sistema de Entregas) | SPEC-026 item 11 — já existia, verificado |
| Orçamento aprovado gera PowerPoint automaticamente | SPEC-026 item 12 — não iniciado, depende de investigar ferramenta externa |

### Passos manuais do usuário

- [x] Decidido: manter acesso como está, sem restrição adicional (2026-07-15).

---

## Objetivo

Responder precisamente à pergunta "quais outros pontos foram falados nessa
reunião" separando decisões firmes (o que vira trabalho) de exploração/
contexto (o que não vira trabalho). A releitura confirma que a SPEC-026 já
cobre praticamente tudo — a exceção é a restrição de acesso ao dashboard,
que ficou registrada na transcrição mas não virou item de ação antes.

---

## Definição da SPEC

### O achado: restrição de acesso ao Dashboard Financeiro

Trecho da reunião (parte 1, ~11:32–13:06):

> "Eu deixaria o dashboard em um lugar só para você ou para você, para o
> Vinícius. [...] Talvez na parte da administração bancária, porque é uma
> coisa bem restrita. Ou criar um novo sistema só para o dashboard."

Duas decisões nesse trecho:
1. **Sistema próprio para o dashboard** — feito (SPEC-026/SPEC-025, "Dashboard Lucenera").
2. **Acesso restrito** — não feito. Ao contrário: o card "Dashboard Financeiro" foi adicionado à tabela `systems` com `visivel_no_hub = true` sem nenhuma restrição de papel/permissão.

### Como o controle de acesso realmente funciona (grounded)

`src/pages/Dashboard.tsx` (Central Lucenera, Skip id 37750):

```ts
if (profile?.role === 'admin') {
  // vê TODOS os sistemas com visivel_no_hub = true, sem checar permissão por papel
  const { data: allSystems } = await supabase.from('systems').select('*')
    .eq('visivel_no_hub', true).order('display_order', { ascending: true })
  ...
}
// só usuários não-admin passam pelo RPC hub_sistemas_permitidos (checa papel_permissoes)
```

```sql
CREATE OR REPLACE FUNCTION public.hub_sistemas_permitidos(p_usuario_id uuid)
RETURNS SETOF systems ... AS $$
  SELECT DISTINCT s.*
  FROM systems s
  JOIN papel_permissoes pp ON pp.system_id = s.id
  JOIN usuario_papeis up ON up.papel_id = pp.papel_id AND up.usuario_id = p_usuario_id
  WHERE (pp.acao = 'visualizar' OR pp.acao IS NULL) AND s.visivel_no_hub = true
$$;
```

Ou seja: **usuários `admin` pulam completamente o sistema de permissão por
papel** (`papel_permissoes`/`usuario_papeis`) e veem tudo que está visível no
hub. Hoje existem 4 usuários `admin` no banco:

| Nome | Email | Seria incluído na restrição da reunião? |
|---|---|---|
| Pedro | pedro@lucenera.com.br | Sim (citado explicitamente) |
| Vinicius | vinicius@lucenera.com.br | Sim (citado explicitamente) |
| Filippo | filippo@lucenera.com.br | **Não confirmado** — foi ele quem sugeriu a restrição, mas isso não deixa claro se ele mesmo ficaria de fora |
| Kimberly | kimberly@adapta.org | **Não confirmado** — é a consultora externa da Adapta (empresa de IA que está ajudando a migrar o Connect); provavelmente não deveria ter acesso a dado financeiro por padrão |

### Caminhos possíveis de implementação (não escolhidos ainda)

1. **Tirar `visivel_no_hub` do Dashboard Financeiro** e criar um `papel_permissoes` específico só para Pedro/Vinícius (exigiria que eles NÃO dependam do bypass de admin — ou seja, mudar a lógica do `Dashboard.tsx` para checar permissão por papel mesmo para admins nesse sistema específico).
2. **Criar uma flag nova** (ex.: `systems.restrito_admin_lista uuid[]`) com a lista de `usuario_id` liberados, checada independentemente do papel.
3. **Não usar `role='admin'` como bypass geral** — repensar o modelo (fora do escopo pontual desta SPEC, mudança estrutural maior).

Nenhuma das três foi escolhida — depende da decisão de quem exatamente deve
ter acesso (ver Pendências).

---

## Critérios de aceite

- [x] Pedro e Vinícius conseguem ver e abrir o card "Dashboard Financeiro" no hub (já viam, como todo admin).
- [x] Decisão de acesso registrada e fechada com o usuário — sem restrição adicional por ora.

---

## Realizado

### 2026-07-15

- Confirmado com o usuário que a SPEC-026 já cobre todos os pontos decididos na reunião de 13/07.
- Investigado o mecanismo de acesso (`Dashboard.tsx` + `hub_sistemas_permitidos` + `user_system_access`) e explicado que o bypass de admin torna o painel de acesso por usuário inefetivo para os 4 admins atuais.
- Usuário decidiu manter o acesso como está (sem restringir Filippo/Kimberly). Encerrado sem mudança de código.

## Pendências

Nenhuma — item resolvido por decisão explícita do usuário. Se a política de acesso mudar no futuro (ex.: Kimberly deixar de ser admin/consultora), os 3 caminhos de implementação na seção "Caminhos possíveis" acima continuam válidos como referência.
