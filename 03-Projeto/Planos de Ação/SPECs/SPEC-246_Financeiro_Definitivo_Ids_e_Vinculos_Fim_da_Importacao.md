---
titulo: "SPEC-246 — Financeiro definitivo: ids próprios e vínculos para o fim da importação da planilha da Connect"
status: "ESCRITA (nada implementado/aplicado) — confirmações da seção 7 respondidas em 05/11; falta autorização para aplicar cada migration"
data: 2026-11-05
origem: "Pedido do usuário após a reunião 42 (Filippo): entender o que aconteceu e estruturar o Supabase para que nenhum erro assim se repita, porque esta é a ÚLTIMA importação da planilha: daqui em diante o financeiro é contabilizado pelo nosso sistema."
relacionadas: SPEC-245 (financeiro real e diário), SPEC-244 (operação em paralelo), SPEC-215/220 (entrada de NF e vínculos), SPEC-204 (notas fiscais Connect)
---

# SPEC-246 — Financeiro definitivo: ids próprios e vínculos

## 1. Premissa nova
A planilha ContaReceber/ContaPagar deixa de ser a fonte do dia a dia: **a carga final vira o ponto de partida** e, depois dela, **toda baixa, lançamento e acordo nasce no sistema novo**. Isso muda duas coisas da SPEC-245: a **carga diária (D1) termina** e a **baixa/edição no front deixa de ser opcional (D13)**. O banco precisa ser estruturado para que o dado seja **certo por construção**, e não conferido depois.

## 2. O que estava acontecendo (causas-raiz, em linguagem simples)

| # | Causa | Evidência medida em 05/11 |
|---|---|---|
| R1 | **O número da pessoa da Connect (`cod_pessoa`) não identifica ninguém sozinho.** Clientes e fornecedores têm **códigos separados** (o 278 é a cliente Juliana e também o fornecedor Stella) e a planilha **não diz o tipo** nem traz CPF/CNPJ. | 101 códigos existem como cliente e como fornecedor, todos com nomes diferentes; no Pagar, 37 códigos têm mais de um nome. |
| R2 | **A pessoa só era ligada na criação da duplicata e pelo número, sem olhar o tipo.** As antigas nunca foram revisitadas. | 9.714 de 14.027 negociações sem pessoa; **1.609 de 2.330 despesas ligadas à pessoa errada** (ex.: Adriana Jabur ligada ao cliente "Benedito Gastronomia"). |
| R3 | **Só status e valores eram atualizados nas cargas seguintes; os campos de cadastro (conta, venda, total de parcelas, forma de pagamento) ficaram congelados do dia da criação.** | 2.981 receitas com **a conta de uma despesa** (cópia da duplicata de mesmo número); 1.295 vendas vazias; 753 totais de parcelas desatualizados; 1.858 formas de pagamento desatualizadas. |
| R4 | **O número da duplicata não é único:** existe como despesa e como receita, e em mais de uma empresa. A chave natural + a regra "vencedora/perdedora" misturam dados. | 804 negociações de Receber com número repetido em outra empresa; 878 `cod_itens_duplicata` repetidos no banco. |
| R5 | **Empresa:** a planilha antiga trazia a empresa constante e o importador gravava tudo na MANOELLA. | 6.152 parcelas na empresa errada (corrigido). |
| R6 | **Nada no banco impedia o erro:** sem NOT NULL, sem regra de coerência (receita com conta de despesa, pessoa de tipo impossível) e sem verificação automática. | Os erros só apareceram quando o Filippo olhou a tela. |
| R7 | **A planilha nunca esteve no banco** (sem espelho) e o front só mostrava o que o banco guardava. | "Onde está a planilha no Supabase?" |
| R8 | **Os ids de venda, projeto, nota e conta bancária nunca foram construídos:** a planilha só traz números, e as outras planilhas (Clientes, Pedido de Compra, Produtos, XML, Reserva) ficaram soltas. | Só 272 das 3.122 vendas dos recebíveis existem no sistema; conta bancária ligada em 10%/26%; projeto em 37%. |

## 3. Ids que podemos criar ligando as outras planilhas (inventário medido)

| Id que queremos | Fonte(s) | O que a medição mostrou | Ação |
|---|---|---|---|
| **Cliente exato** | `Clientes (1).xlsx` (`codCliente`, `docCliente`, nome, razão, endereço, e-mail) | `cod_pessoa` do Receber = `codCliente`: **737 de 740 existem; 715 com o nome igual.** Documento (CPF/CNPJ) válido em **só 547 de 2.872 (19%)**, e **nenhum está gravado no CRM** (o CRM tem documento em 346 contatos); 50 documentos aparecem em mais de um cliente (casais/empresas). | Gravar o documento nos contatos pelo `codigo_legado` (onde não conflitar) e usar o documento como id exato daí em diante; revisar os 50 repetidos. |
| **Fornecedor exato** | `PedidoCompra` (`cod_fornecedor`) e `Produtos` (`CodFornecedor`), nome | 112 códigos de fornecedor; no Pagar **73 existem e 69 conferem pelo nome**. Espaço de código **próprio** (colide com o de clientes). Os 357 fornecedores do CRM **não têm** código. | Tabela de mapa **por tipo** (seção 4a); gravar o código nos fornecedores casados pelo nome. Pedir ao Sérgio a exportação de **Fornecedores com CNPJ**. |
| **CPF/CNPJ de quem recebe** | `notas_fiscais_connect` + `..._duplicatas` | 355 NF / 809 duplicatas, **100% com CPF/CNPJ do destinatário**; **690 recebíveis** casam por vencimento + valor; **172** já têm o documento no CRM, **518 não**. | Usar a NF como **fonte do CPF/CNPJ** dos clientes que faltam e como ligação **nota ↔ recebível**. |
| **Venda ↔ orçamento ↔ cliente ↔ projeto** | Reserva/Entrega Futura (314 vendas ↔ 315 orçamentos), XML (391 orçamentos com `cod_cliente`) | Só cobre o que está em aberto. As **2.850 vendas** antigas dos recebíveis não têm par no sistema. | Tabela `vendas_connect` (4e) alimentada por Reserva/XML; **precisa do relatório Vendas × Orçamento da Connect** para o resto. |
| **Conta bancária** | `cod_conta` da planilha (Caixa, Bradesco Lucenera, Islight, Foco) | O código existe em 90–96% das linhas; ligado em 10% (Receber) e 26% (Pagar). | Preencher `transacoes.conta_id` (sem dado novo). |
| **Projeto** | código "NN.NNN" no nome da pessoa | Acha o projeto em 74% das linhas do Receber (391 das 459 em aberto). | Preencher `negociacoes.projeto_id` (sem dado novo). |
| **Plano de contas** | `cod_apropriacao` | 3 contas da planilha não existem no plano (Aluguel São Paulo, Condomínio - São Paulo, Manutenção conta). | Criar as 3 (D10). |
| **Funcionário** | `nm_funcionario` ↔ `funcionarios.nm_connect` | 96% | Cadastrar Katia/Ricardo (ex-Connect). |
| **Pedido de compra ↔ pagar** | `pedidos_compra.fornecedor_id` ↔ contatos fornecedores | Só 16 de 51 pedidos aprovados têm parcelas de pagamento; 17 de 19 fornecedores em comum com o Pagar. | Parcelas obrigatórias no pedido aprovado e previsão visível no Contas a Pagar. |

## 4. Estrutura alvo do Supabase (para o erro não se repetir)

**Princípio:** toda pessoa, duplicata, parcela e venda tem **id próprio (uuid) do nosso sistema**; os ids da Connect ficam em colunas `legado_*` **imutáveis** (um gatilho bloqueia alteração) só para rastrear; o vínculo entre os dois é uma **tabela explícita**, nunca uma dedução por nome a cada carga.

- **4a. `contato_legado_ids`** (mapa explícito): `espaco` (`cliente`/`fornecedor`/`arquiteto`), `cod_connect`, `contato_id` (FK), `metodo` (`documento`/`codigo+nome`/`nome`/`pre_cadastro`), `criado_em`; **UNIQUE (espaco, cod_connect)**. Resolve R1: a pessoa é resolvida **uma vez**, de forma auditável.
- **4b. `negociacoes` (a duplicata):** `contato_id`, `empresa_id`, `plano_contas_id` **NOT NULL** (o que não tiver pessoa vira o cadastro **"PESSOA NÃO IDENTIFICADA (cód. N)"** visível para completar, em vez de nulo); novas colunas `origem` (`connect`/`sistema`), `legado_cod_duplicata`, `venda_id`/`orcamento_id`, `nota_fiscal_id`; `projeto_id` já existe.
- **4c. Regras de coerência no banco (gatilhos/CHECK):** o plano de contas tem que ser do mesmo tipo da duplicata (receita × despesa) — **mata o erro das 2.981 receitas**; empresa da parcela = empresa da duplicata; tipo do contato compatível (Receber: cliente/arquiteto; Pagar: fornecedor/arquiteto/cliente); campos `legado_*` imutáveis.
- **4d. `transacoes` (a parcela):** **UNIQUE parcial (tipo, cod_itens_duplicata) onde não cancelada** — acaba a duplicidade (R4); `origem`; `conta_id` obrigatório quando paga; baixa nativa grava quem/quando/forma.
- **4e. `vendas_connect`:** `cod_venda` (PK legada), `cod_orcamento`, `cod_cliente`, `orcamento_id` (FK), `projeto_id` (FK), `empresa_id`, `fonte` do vínculo. Une as duplicatas às vendas/orçamentos/projetos.
- **4f. `connect_contas_espelho`** (já existe): fica **congelado como arquivo morto da última carga**, só leitura (auditoria).
- **4g. Integridade contínua:** view `vw_financeiro_integridade` (negociação sem pessoa, receita com conta de despesa, empresa divergente, parcela sem conta, venda sem destino…) e **conferência diária do sistema nativo** (não mais da planilha).
- **4h. Marco do financeiro:** como o da operação em paralelo, grava a data da carga final e **trava** o importador e os corretores da planilha.

## 5. Passos (ordem)
1. **Carga final** (planilhas de hoje ou a data combinada) + correções + espelho (**congelar**).
2. **Construir os mapas e ligações** (4a, 4e), conta bancária e projeto; gravar CPF/CNPJ dos clientes pela planilha de Clientes e pelas NF; criar as 3 contas do plano (D10).
3. **Migrations de estrutura** (4b–4d), com ensaio e backup: backfill, depois NOT NULL, gatilhos e índice único.
4. **Marco do financeiro (4h)** e **front nativo** (baixa, edição, cadastro, acordo sobre `transacoes`; pedido de compra e aprovação de orçamento gerando parcelas já com os ids novos).
5. **Integridade diária** (4g) no lugar da conferência da planilha.

## 6. Efeito sobre o que já existe
- **Roteiro de carga diária e `conferencia_diaria_financeiro.py`** passam a valer só **até o marco**; depois viram a **conferência de integridade** do sistema nativo.
- **D13 (baixa da duplicata da Connect no sistema novo) deixa de ser decisão:** passa a ser requisito (a planilha não vai mais sobrescrever).
- **Reserva/herança e XML** seguem as regras da SPEC-243/244.

## 7. Confirmações — RESPONDIDAS em 05/11
1. **Última importação = a de HOJE (05/11).** Era para ser sábado, mas a decisão do chefe é hoje. **Marco do financeiro = 05/11**: depois desta carga o importador e os corretores da planilha são travados (4h).
2. **Os dois sistemas rodam EM PARALELO** (Connect e o novo). Consequência: baixas feitas na Connect depois do marco **não entram** no sistema novo; a equipe precisa baixar nos dois lados até a virada, e a baixa nativa no front vira requisito (D13).
3. **Não pedir novas exportações ao Sérgio.** Usar o que já temos: Clientes, PedidoCompra, Produtos, XML, Reserva/EF, Notas Fiscais Connect e as planilhas de Contas. O que ficar sem id exato fica marcado como pendente, sem inventar.
4. **"PESSOA NÃO IDENTIFICADA" e as 3 contas do plano: NÃO criar ainda.** O usuário precisa averiguar melhor. Enquanto isso, a pessoa sem vínculo continua com o nome da planilha (`nome_pessoa`/`razao_pessoa`), que já aparece nas telas.
5. **As 387 parcelas de projeto de 04/05 NÃO são teste e NADA será apagado.** A ideia do Filippo de "apagar tudo e começar do zero" não é viável: os relatórios dependem do histórico.

## 7b. Achados novos (medidos em 05/11, somente leitura)
- **Regra de coerência plano × tipo da duplicata NÃO pode ser trava dura.** Na própria planilha da Connect, o Receber usa 93 contas de tipo "despesa" (+4 retirada, 1 investimento) e o Pagar usa 107 de "receita" (+225 retirada, 218 investimento, 24 lucro, 542 fora do plano). A regra do 4c vira **alerta na `vw_financeiro_integridade`** para o legado, e **trava só para lançamentos nativos novos**.
- **O sistema tem mais linhas que a planilha:** receita não cancelada 6.623 (parcela R$ 43,03 mi; paga R$ 32,56 mi) contra 5.064 da planilha (R$ 39,07 mi; paga R$ 27,91 mi); despesa 13.614 contra 14.308. Há **28 `cod_itens_duplicata` repetidos não cancelados na receita**. Isso precisa ser explicado antes do índice único (4d) e antes de dizer que o total "contabilizado" está certo.
- **Contas bancárias:** só 4 (Caixa, Bradesco Luce Nera, Islight, Foco), todas com `codigo_connect`; o preenchimento de `transacoes.conta_id` não precisa de dado novo.

## 8. Realizado
- 05/11: análise de causas e inventário de ids concluídos (este documento); **nada foi aplicado**. Commits e pushes pendentes de OK do usuário.
- 05/11 (tarde): respostas do usuário registradas (seção 7); coerência plano × tipo rebaixada para alerta (7b). Ainda nada aplicado.
