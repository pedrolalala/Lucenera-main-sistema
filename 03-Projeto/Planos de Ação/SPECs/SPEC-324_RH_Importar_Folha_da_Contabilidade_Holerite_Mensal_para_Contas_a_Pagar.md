---
titulo: "SPEC-324 — RH: importar a Folha de Pagamento mensal (planilha da contabilidade) e gerar a conta a pagar certa (salário por funcionário + guias da empresa)"
status: não iniciado
data_ultima_modificacao: 2026-11-18
sistemas_envolvidos:
  - RH (`dashboard-rh-lucenera-5fe9c`) — tela de importação e conferência da folha
  - Contas a Pagar (`retorno-bancario-bradesco-5392a`, modo Pagar) — recebe os títulos; folha/salário só para quem tem o RH
  - Banco (Supabase SP) — tabelas de folha importada + função de geração de títulos
  - Dashboard Financeiro (fluxo de caixa) — só leitura, folha agregada (SPEC-258)
---

# SPEC-324 — Importar a Folha da contabilidade e gerar o Contas a Pagar

Continua a **SPEC-258** (Fase 4, origem "folha": "folha = título por funcionário/mês, só RH"; a coluna `financeiro_titulos.folha_pagamento_id` e a espécie `salario` já existem e **nenhum título de folha foi criado até hoje**).

## Objetivo

Todo mês a contabilidade exporta a folha em planilha (Excel). O RH sobe esses arquivos no sistema e, depois de conferir, o sistema:

1. guarda o **holerite de cada funcionário** do mês (proventos, descontos, bases, líquido);
2. guarda os **totais da empresa** (INSS/GPS, FGTS, IRRF, contribuição assistencial, consignado);
3. **confere** que a soma dos holerites bate com os totais da contabilidade, centavo a centavo;
4. lança no **Contas a Pagar**: o **líquido de cada funcionário** (só o RH enxerga) e as **guias/repasses da empresa** (o financeiro enxerga), com empresa, vencimento e plano de contas certos.

## O que foi analisado (outubro/2026, arquivos enviados em 18/11)

Pasta: `01-Documento/01 - Planilhas/Holerite/`. São **5 arquivos `.xlsx`**, 1 aba cada, gerados pelo sistema da contabilidade em 17/11/2026, competência **10/2026**. O código da empresa vem no nome do arquivo (`2781` + código: `40043`, `40120`, `40200`).

| Empresa (código) | CNPJ | Holerites (por funcionário) | Totais |
|---|---|---|---|
| 0043 — MANOELLA ZAUITH LEITE LOPES (= **MANOELLA** no banco) | 11.258.465/0001-63 | **NÃO veio** | veio — 8 funcionários |
| 0120 — ISLIGHT | 21.585.885/0001-08 | veio — 1 funcionário | veio |
| 0200 — FOCO ILUMINACAO LTDA | 24.090.967/0001-70 | veio — 16 funcionários | veio |

**Dois tipos de planilha** (nomes "Folha de Pagto …" e "Totais da Folha de Pagto …"):

- **Folha de Pagto** (holerite): bloco por funcionário com matrícula, nome, cargo, CBO, admissão/demissão, **CPF**, salário; lado **PROVENTOS** (rubrica, referência, valor), lado **DESCONTOS**, lado **BASES** (INSS, FGTS, IRRF) e a linha de totais (vencimentos, descontos, **valor líquido**). Mesclagem de células e colunas que **mudam de posição** entre funcionários (valor de provento ora na coluna H, ora I). O holerite de 2 funcionários da FOCO **quebra de página** e aparece em dois blocos com a mesma matrícula (os valores se somam).
- **Totais**: a mesma estrutura somada por empresa + situação dos funcionários (ativos, demitidos, afastados) + **resumo da GPS** + bases.
- Os textos vêm com acentos corrompidos (`SALÁRIO` lido como `SAL?RIO`): o importador deve tratar a codificação e **usar o código da rubrica (5 dígitos)**, não o texto.
- Valores ora em texto brasileiro (`2.400,00`), ora em número (`2400.0`).

**Teste feito (protótipo de leitura, sem gravar nada):** lendo os blocos da FOCO e unindo as páginas partidas, a soma dos 16 holerites deu **vencimentos R$ 52.914,96 / descontos R$ 13.371,82 / líquido R$ 39.543,14** — **igual ao arquivo de Totais**. O mesmo vale para a ISLIGHT (R$ 2.480,00 / 222,89 / 2.257,11). Ou seja, a conferência "holerites × totais" é possível e confiável.

### O que cada empresa precisa pagar (medido nos Totais de 10/2026)

| Obrigação | MANOELLA (0043) | ISLIGHT (0120) | FOCO (0200) |
|---|---|---|---|
| Líquido dos funcionários (rubrica 9900) | 33.311,52 | 2.257,11 | 39.543,14 |
| GPS (INSS) a recolher | 4.032,93 | 888,33 | 4.649,62 |
| FGTS (rubrica 9930) | 3.161,37 | 198,40 | 4.200,06 |
| IRRF (rubrica 9870) | 1.828,48 | — | 910,76 |
| Contribuição assistencial/sindical (05841) | 344,63 | 24,00 | 497,95 |
| Empréstimo consignado em folha (08801–08807, 08927) | — | — | 3.687,87 |
| **Total a desembolsar no mês** | **42.678,93** | **3.367,84** | **53.489,40** |

Total geral do mês: **R$ 99.536,17** (hoje nada disso está no Contas a Pagar). Conferências: na MANOELLA, líquido + descontos (INSS 4.032,93 + IRRF 1.828,48 + assistencial 344,63 = 6.206,04) = vencimentos 39.517,56. Na FOCO, a GPS (4.649,62) = INSS + INSS s/ férias (4.333,97 + 315,65).
Diferenças entre as empresas: MANOELLA e FOCO são Simples ("GPS ME/EPP": só o INSS do segurado vai na GPS); a ISLIGHT paga também a parte da empresa e terceiros (GPS = 198,89 + 545,60 + 143,84).

### O que existe hoje no sistema

- **RH › Folha (`Folha.tsx`)**: "gera" a folha por conta própria (calcula em cima de cadastro, faltas, VR/VT). A consulta usa colunas que **não existem** em `funcionarios` (`salario_base`, `valor_vr`, `valor_vt`, `comissao_padrao`) — a geração está quebrada e, de qualquer forma, **não é a folha oficial** (quem calcula é a contabilidade).
- **`folha_pagamento`**: 771 linhas (26 funcionários, anos de 2026 a 2030, 1 linha com ano 204) — dado de teste/projetado, não é folha real. Só guarda líquido/descontos/adicionais. RLS: só quem tem o acesso `rh`.
- **`financeiro_titulos`**: já tem `folha_pagamento_id`, `funcionario_id`, `empresa_id`, `plano_contas_id`, espécie `salario`/`comissao` e a função `financeiro_criar_titulo(p_titulo jsonb, p_parcelas jsonb)` já prevê a origem folha. A política de leitura **esconde `salario`/`comissao` de quem só tem o Financeiro** (precisa do `rh`) — é exatamente o que a regra "folha só RH" pede.
- **Plano de contas já existente** (`plano_de_contas`): SALARIOS E ORDENADOS (2010001), FÉRIAS (2010003), FGTS (2010012), SINDICATO (2010014), 13º SALÁRIO (2010023), DARF/FGPS (10000000), INSS (90000018), EMPRÉSTIMO (2020041).
- **Cadastro de pessoas**: dos 17 CPFs das folhas, **13 batem** com `funcionarios_detalhes.cpf` e **4 não** (sem CPF no cadastro, funcionário novo ou CPF diferente). Dos 37 funcionários ativos, 26 têm CPF e **10 estão sem empresa** (`empresa_id` nulo).
- **Quem vê RH hoje**: Pedro, Filippo, `financeiro@` e Vinicius (que saiu em 17/11). A SPEC-258 dizia "quem vê folha e comissão: Vinicius e Lana" — **precisa de nova decisão**.

## Decisões em aberto (precisam do usuário — recomendação em negrito)

1. **Como lançar no Contas a Pagar:** (a) **líquido por funcionário/mês (só RH) + guias por empresa/mês (INSS, FGTS, IRRF, sindicato, consignado) visíveis ao financeiro** (recomendado, é o desenho da SPEC-258 e deixa o financeiro pagar as guias sem ver salário); (b) um único título por empresa/mês; (c) só líquido, guias fora do sistema.
2. **Vencimentos:** salário no 5º dia útil do mês seguinte; INSS (GPS), FGTS e IRRF (DARF) no dia 20 do mês seguinte; sindicato e consignado conforme guia. **Confirmar com a contabilidade** (a planilha não traz data de vencimento). Vencimento editável antes de gerar.
3. **Outubro/2026:** lançar como **já pago** (histórico) ou em aberto? O salário de outubro já foi pago em novembro; as guias vencem dia 20/11. Recomendação: salário como pago (baixa interna, sem movimento de caixa a definir) e guias em aberto — **o usuário decide**.
4. **Quem enxerga e opera a folha** depois da saída do Vinicius e da Lana (`rh`): hoje Pedro, Filippo e `financeiro@`. Manter só o RH atual?
5. **Falta a planilha de holerites da MANOELLA (0043)**: só veio o "Totais" (8 funcionários, líquido R$ 33.311,52). Pedir à contabilidade. Sem ela, o salário individual da MANOELLA não pode ser lançado (as guias podem).
6. **Perfil (SP/Ribeirão)** dos títulos de folha: hoje 6.992 títulos a pagar são Ribeirão e 6 São Paulo. Qual perfil para folha? (Recomendação: o da empresa de cada funcionário — confirmar.)
7. **Rubricas de férias, 13º, rescisão, adiantamento:** outubro teve férias e descontos de férias recebidas. Falta ver **um mês com 13º e uma rescisão** para saber se a planilha tem o mesmo desenho (ou outro arquivo).
8. **Funcionário sem CPF/sem cadastro:** ficam numa **fila de pendências** e o mês não gera os títulos dessa pessoa até o RH ligar/cadastrar (recomendado) — ou gera com nome solto?
9. O arquivo é **.xlsx** (o usuário falou "XLS"): aceitar `.xlsx` e, se a contabilidade mandar, `.xls` antigo?
10. **Efeito sindical de outubro/2026 (esclarecido pelo usuário em 18/11):** não houve reajuste salarial; foi só uma questão sindical do mês. Os salários da planilha batem com o cadastro. Fica **sem regra especial**: rubricas sindicais (05841 contribuição assistencial, 01006 dia de classe sindical) geram a guia `SINDICATO` quando aparecem na planilha, sem valor ou percentual fixo.

## Definição da SPEC (proposta)

### 1. Banco (migration nova; ensaio com ROLLBACK antes de aplicar)

- `folha_importacoes`: empresa, competência (ano/mês), arquivos (nome + hash SHA-256), quem importou e quando, situação (`conferida`, `gerada`, `cancelada`), totais lidos, versão (nova importação da mesma empresa/mês cancela a anterior, nunca apaga).
- `folha_holerites`: importação, funcionário (por CPF, `funcionario_id` pode ficar nulo na fila), matrícula da contabilidade, nome, cargo, admissão/demissão, vencimentos, descontos, **líquido**, bases (INSS, FGTS, IRRF), `folha_pagamento_id` (liga à tabela atual para não quebrar relatórios).
- `folha_holerite_rubricas`: holerite, código da rubrica (5 dígitos), descrição, tipo (provento/desconto/base), referência, valor.
- `folha_totais_empresa`: importação, totais por rubrica, líquido, GPS (segurados/empresa/terceiros/RAT), FGTS, IRRF, nº de funcionários por situação.
- `folha_rubricas_plano` (de-para editável): código da rubrica → plano de contas e se gera título (ex.: 09860/09850 → INSS; 09930 → FGTS; 09870 → IRRF; 05841 → SINDICATO; 0880x/08927 → EMPRÉSTIMO; 00001/01006… → SALARIOS; férias → FÉRIAS).
- Funções `SECURITY DEFINER` (`REVOKE ALL … FROM PUBLIC, anon`): `folha_importar_conferir(p_importacao jsonb)` (grava a importação em modo conferência e devolve o relatório), `folha_importar_gerar_titulos(p_importacao_id, p_vencimentos jsonb)` (tudo ou nada, idempotente), `folha_importar_cancelar(p_importacao_id, p_motivo)`.
- RLS ligada em todas as tabelas, `REVOKE ALL … FROM anon`, leitura/escrita só por `(SELECT pode_acessar_sistema('rh'))`; nunca `USING (true)`. Salário/rubricas individuais **nunca** em view do financeiro geral.
- Geração do título: `origem_tipo = 'folha'`, `folha_pagamento_id` preenchido, `origem_seq` por tipo de título, espécie `salario` (líquido) ou `despesa`/`outro` (guias), `empresa_id` da planilha, `funcionario_id` no salário, **chave única por empresa + competência + tipo** (reimportar não duplica). Parcela única com o vencimento escolhido.
- Teste de integridade novo (soma com a SPEC-258 item 11, "folha-mês sem título"): para cada importação gerada, soma dos títulos de salário = soma dos líquidos; guias = totais da contabilidade.

### 2. Leitura da planilha (RH)

- Lê o `.xlsx` **no navegador** (biblioteca `exceljs` já usada no Log de Atividade), localiza os blocos pelos **rótulos** ("PROVENTOS", "DESCONTOS", "BASES", "TOTAL LÍQUIDO", "CPF:"), não por célula fixa; une blocos da mesma matrícula quebrados em duas páginas; converte `2.400,00` e `2400.0`; normaliza a codificação.
- Reconhece o tipo do arquivo (Folha × Totais) e a empresa pelo cabeçalho (`0200-FOCO ILUMINACAO LTDA` + CNPJ) e pelo nome; **recusa layout desconhecido** com mensagem clara (nunca grava "no chute").
- Envia ao banco o conteúdo já estruturado (JSON) — o servidor revalida tudo (não confia no navegador).

### 3. Tela no RH (substitui a "Gerar folha" quebrada)

1. **Enviar arquivos** (arrastar os 5 de uma vez; mês/empresa detectados automaticamente).
2. **Conferência**: por empresa, "holerites somam R$ X × totais da contabilidade R$ Y" (verde/vermelho), nº de funcionários lidos × "ativos" do arquivo de totais, funcionários **sem cadastro** (fila), rubricas **sem plano de contas**, empresa/mês **já importados**.
3. **Resolver pendências**: ligar CPF a funcionário existente, cadastrar, ou excluir da geração com motivo.
4. **Prévia do Contas a Pagar**: lista dos títulos que serão criados (salário por funcionário; guias por empresa) com vencimento editável e plano de contas.
5. **Gerar**: cria tudo numa transação; mostra o resultado e o link para o Contas a Pagar.
6. **Histórico** das importações por mês/empresa, com cancelamento (cancela os títulos só se não houver baixa; se houver, exige estorno antes).
7. Exportar a conferência (CSV) para a contabilidade.

### 4. Contas a Pagar e Dashboard

- Os títulos de folha aparecem no Contas a Pagar com selo "Folha"; salário só para quem tem o RH; guias para o financeiro (SPEC-258/196).
- A baixa usa o fluxo normal (conta bancária, comprovante); a remessa CNAB de pagamento de salário fica **fora** desta SPEC.
- Dashboard financeiro: folha entra **agregada** por empresa/mês (sem nome nem valor individual).

### 5. Regras

- Nunca apagar: reimportar cancela a versão anterior (com motivo) e cria a nova; cancelamento bloqueado se houver baixa.
- Salário individual nunca sai do RH; relatórios do financeiro só enxergam guias e totais.
- A planilha é a fonte: o sistema **não recalcula** a folha (a tela antiga de cálculo sai ou vira só consulta).
- **Rubricas sindicais eventuais:** valor sempre lido da planilha; a conferência só mostra a variação do salário-base × mês anterior como aviso informativo (tolerância R$ 0,02).
- Competência e empresa do arquivo mandam; o usuário não escolhe mês manualmente (evita lançar no mês errado).

## Checklist de Ação

- [ ] Fechar com o usuário as decisões em aberto (seção acima), principalmente 1, 3, 4 e 5.
- [ ] Obter da contabilidade a planilha de **holerites da MANOELLA (0043)** de outubro e um mês com **13º e rescisão**.
- [ ] Banco: migration (rascunho + dry-run com ROLLBACK) com as 5 tabelas, de-para de rubricas, RLS e as 3 funções; teste como usuário `rh`, usuário só-financeiro (não vê salário) e `anon` (sem acesso).
- [ ] Prototipar o leitor de planilha com os 5 arquivos de outubro e fixar como teste (somas iguais às medidas aqui).
- [ ] RH: tela "Importar folha" (enviar, conferir, pendências, prévia, gerar, histórico); retirar ou desativar a "Gerar folha" quebrada.
- [ ] Contas a Pagar: selo "Folha", filtro, garantia de que salário não aparece sem o RH.
- [ ] Limpar os dados de teste de `folha_pagamento` (anos 204 e 2027–2030) **com backup no schema `backup`** — só depois de confirmar com o usuário.
- [ ] Resolver os 4 CPFs sem cadastro e as 10 pessoas sem empresa no cadastro de funcionários.
- [ ] Atualizar SPEC-258 (Fase 4 passo "folha"), CHANGELOG e Sumário de Sistemas; revisor e auditor; teste real com outubro/2026.

### Passos manuais do usuário

- [ ] Responder as 9 decisões.
- [ ] Pedir à contabilidade as planilhas que faltam (MANOELLA individual; mês com 13º/rescisão) e confirmar os vencimentos.
- [ ] Aplicar a migration quando o dry-run estiver limpo; conferir outubro em tela.

## Critérios de aceite

- Importar os 5 arquivos de outubro/2026 e ver: FOCO 16 holerites = R$ 39.543,14, ISLIGHT 1 = R$ 2.257,11, MANOELLA só totais (R$ 33.311,52), sem diferença para os totais da contabilidade.
- Gerar os títulos: salários por funcionário (só RH) e as guias das tabelas acima; soma geral dos títulos de outubro = R$ 99.536,17 (se a MANOELLA individual não vier, o salário dela entra pelo total e fica marcado).
- Importar de novo o mesmo arquivo: nada duplica (mostra "já importado").
- Usuário só do Financeiro vê as guias, não vê salário nem holerite.
- Arquivo com layout diferente ou soma divergente: recusado, nada gravado.

## Fora do escopo

- Calcular folha, férias, 13º ou rescisão no sistema (quem calcula é a contabilidade).
- Remessa bancária (CNAB) de pagamento de salário; DAS/Simples e demais impostos (não vêm na folha).
- Comissão de funcionário e RT (ficam na SPEC-258 / 4c-2).
- Ponto, faltas, vale-transporte (SPEC-056/058/065).

## Realizado

- 18/11/2026: análise dos 5 arquivos, do RH, do Contas a Pagar e do banco (somente leitura); protótipo de leitura conferido contra os totais; SPEC criada. Nada implementado, nenhuma migration criada.

## Pendências

- [ ] Decisões 1–9 do usuário (seção "Decisões em aberto").
- [ ] Planilha de holerites da MANOELLA (0043) de outubro/2026 e exemplo de mês com 13º/rescisão, da contabilidade.
- [ ] Definir quem vê a folha depois da saída do Vinicius e da Lana.
