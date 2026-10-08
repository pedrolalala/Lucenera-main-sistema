---
titulo: "SPEC-189 — RH: faltas de 2026 importadas da planilha + fim da tela branca"
status: concluído
data_ultima_modificacao: 2026-10-08
sistemas_envolvidos:
  - RH Lucenera (dashboard-rh-lucenera-5fe9c, Skip 23919)
  - Supabase (controle_falta)
---

# SPEC-189 — RH: faltas de 2026 importadas da planilha + fim da tela branca

## Checklist de Ação

- [x] Tela branca no computador da Lana: recarrega sozinho quando um pedaço de página da versão antiga não existe mais (`vite:preloadError`) e `ErrorBoundary` com botão "Recarregar" em qualquer erro de tela. RH v0.0.233.
- [x] Importar `01-Documento/01 - Planilhas/Controle de Faltas.xlsx`, só 2026 até 08/10 (decisão do usuário).
- [x] Acesso ao RH: confirmado que só Lana, Vinicius, Filippo e Pedro têm o RH (SPEC-183); a checagem do próprio RH (`hub_pode_executar('rh')`) nega os demais.

## Decisões (2026-10-08)

- Planilha: 1 aba por mês, categoria pela COR da célula conforme a legenda da própria aba. Mapeamento: FALTA → `ausente`; FOLGA → `folga`; LICENÇA/ATESTADO → `atestado`; FÉRIAS fica de fora (vem da SPEC-188); presença/home office/feriado não geram registro.
- Thairine (24/11/2025–24/03/2026) e Thais (28/08/2025–30/06/2026): licença-maternidade (confirmado pelo usuário).
- Não sobrescreve registro existente (o do sistema é mais detalhado). Backup `_bkp_controle_falta_20261008`.

## Realizado

### 2026-10-08

- 164 registros novos (85 licença-maternidade, 41 atestado, 25 folga, 13 falta); 135 já existiam e foram mantidos; todos os nomes casaram com o cadastro. 2026 no sistema: 301 registros. Conferido como Lana.
- RH Skip 23919 v0.0.233 (`945591c`) publicado com a correção da tela branca; textos conferidos no bundle.

### 2026-10-08 (erro ao criar férias na tela da Lana)

- Lana viu "Algo deu errado nesta tela" ao criar férias (registro foi gravado; tentou 4x para a Vitória, 14/10–26/10 e 3x 14/10–27/10).
- Não reproduzido: usuário de teste temporário (admin) fez o mesmo fluxo em produção com Playwright — criou sem erro e sem erro no console. Usuário, funcionário e férias de teste apagados.
- Para pegar a causa real: tabela `erros_tela` (migration `20261008_193_erros_tela`; logado grava, só admin lê) e a tela de erro do RH grava mensagem/pilha/URL/navegador e mostra o detalhe. RH v0.0.234.

## Pendências

- [x] ~~Consultar `erros_tela` na próxima ocorrência~~ — causa achada (15:00, Edge 154 da Lana, /ferias): `NotFoundError: Failed to execute 'removeChild' on 'Node'` = tradutor automático do navegador mexendo no DOM do React (a própria mensagem veio traduzida). Corrigido: `index.html` com `lang="pt-BR" translate="no"` + `<meta name="google" content="notranslate">` (RH v0.0.235).
- [x] Os outros sistemas com `lang="en"` corrigidos em 08/10 (Cadastro, Ubiqua, Central, Compras, Garantia, Dashboard, Orçamentos, CRM, Logística, Adm. Bancária, Separação, Vendas); Memória, Produção e Showroom já eram `pt-BR`. Conferido no ar; nenhuma Edge Function republicada; `schema_migrations` igual (Logística repetiu a falha sem efeito da seed legada).

- [ ] `kimberly@adapta.org` é admin geral e por isso entra em todos os sistemas, inclusive o RH (bypass de admin) — decidir se mantém.
- [ ] Os outros sistemas também carregam páginas em pedaços (SPEC-123) e podem ter a mesma tela branca depois de publicação — aplicar a mesma proteção se aparecer.
