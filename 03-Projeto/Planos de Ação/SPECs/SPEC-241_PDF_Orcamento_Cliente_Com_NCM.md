---
titulo: "SPEC-241 — PDF do orçamento para o cliente com NCM (reforma tributária)"
status: publicada
data_ultima_modificacao: 2026-11-11
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb (1)) — menu de impressão em BudgetTableRow.tsx
  - Edge Function generate-report (código no repositório do Orçamentos, supabase/functions/generate-report/index.ts)
---

# SPEC-241 — PDF do orçamento para o cliente com NCM (reforma tributária)

> Origem: mensagem do Vinicius (03/11/2026):
> *"está acontecendo de alguns cliente PJ pedirem o NCM dos produtos, isso devido a nova reforma. veja de criar um outro
> modelo impressão lá no orçamento, para que aparece o NCM dos produtos. seria aquele modelo de enviar ao cliente, com NCM"*
>
> Relacionadas: SPEC-109 (criou os 2 modelos de PDF "cliente" e "interno"), SPEC-067 (PDF automático ao enviar ao
> cliente), SPEC-164 (PDF aprovado sai com número da venda), SPEC-154 (emissão de NF-e pela Focus).

## Checklist de Ação

- [x] Edge Function `generate-report`: buscar `ncm` do produto e aceitar o modelo novo `cliente_ncm`
- [x] Modelo `cliente_ncm`: igual ao "PDF para o cliente", com a coluna **NCM** logo depois de "Código"
- [x] NCM formatado `9405.19.90`; peça sem NCM ou item sem cadastro mostra `-`
- [x] Aviso curto logo abaixo da tabela, no modelo novo: "NCM conforme cadastro do produto. A classificação fiscal definitiva é a da nota fiscal."
- [x] Orçamentos: 3ª opção no menu da impressora — **"PDF para o cliente com NCM"**
- [ ] Testar os 3 modelos com um orçamento real (layout não pode quebrar com descrição longa)
- [x] Publicar a Edge Function e o Orçamentos (Orçamentos já estava no ar com o menu; Edge Function `generate-report` publicada em 11/11 a partir da main)

### Passos manuais do usuário

- [x] Responder as perguntas da seção "Para decidir" (03/11)
- [x] ~~Rodar `supabase login`~~ (não foi preciso: publicação feita pela conexão do Claude com o Supabase)
- [x] Autorizar a publicação da Edge Function `generate-report` (Filippo, 11/11)
- [ ] Vinicius testar mandando para um cliente PJ que pediu o NCM

## Objetivo

Clientes **pessoa jurídica** estão pedindo o **NCM** de cada produto no orçamento. Criar um terceiro modelo de impressão,
igual ao que vai para o cliente hoje, com a coluna NCM. Os modelos atuais não mudam.

## Por que os clientes PJ estão pedindo (reforma tributária)

- A reforma do consumo (EC 132/2023, regulamentada pela **LC 214/2025**) troca PIS/Cofins pela **CBS** (federal) e
  ICMS/ISS pelo **IBS** (estados/municípios). **2026 é o ano de teste:** a nota já tem de trazer CBS e IBS destacados,
  mas, para quem cumpre as obrigações acessórias, a apuração é só informativa e o recolhimento é dispensado.
- Na NF-e, o IBS/CBS é informado **por item**, com CST e **cClassTrib** (classificação tributária). Essa classificação
  parte do **NCM** do produto: reduções de alíquota e regimes específicos da LC 214 são definidos por NCM, e o cClassTrib
  ainda precisa ser escolhido conforme a lei, além do NCM.
- **Cronograma:** destaque obrigatório na NF-e a partir de **03/08/2026** para o regime regular (lucro presumido e real),
  pelo Ato Conjunto RFB/CGIBS nº 4/2026. As validações que rejeitam a nota sem esses campos foram adiadas (Ato Técnico
  Conjunto nº 1/2026), mas a obrigação continua. Para o **Simples Nacional**, a obrigatoriedade começa em
  **01/01/2027**.
- **Para o cliente PJ:** a CBS/IBS é **não cumulativa** (crédito amplo do que a empresa compra) e, pela LC 214, o
  crédito do comprador fica ligado ao imposto da operação. Com o NCM no orçamento, a empresa compradora já consegue
  conferir, **antes de comprar**, como a mercadoria vai ser tributada e quanto de crédito terá, e lançar no sistema
  dela com a classificação certa. Por isso o pedido chega no orçamento, e não só na nota.
- **Na Lucenera:** ISLIGHT é **Lucro Presumido**, então já está no cronograma de 2026. FOCO e MANOELLA são **Simples
  Nacional**, então entram em 2027. Para o cliente, o NCM serve nos três casos.

> Datas conferidas em fontes secundárias (Contábeis, COAD, Sefaz-ES, Ozai). Antes de usar em comunicação oficial,
> conferir no texto do ato no gov.br. O PDF desta SPEC **não** calcula imposto; ele só informa o NCM do cadastro.

## Estado encontrado (03/11)

- **NCM já existe:** `produtos.ncm` está preenchido em **4.907 das 4.918 peças**. 4.904 estão no formato de 8 dígitos;
  há 78 NCMs diferentes, principalmente da família 9405 (luminárias) e 8539/8504. Não precisa de coluna nova nem de
  migration.
- **PDF de hoje:** a Edge Function `generate-report` (`reportType: 'orcamento'`) aceita `modelo: 'cliente' | 'interno'`
  (SPEC-109):
  - "cliente" mostra as colunas L, Código, Descrição, Qtd., Vl. Unit. e Subtotal;
  - "interno" acrescenta Referência, com posições de coluna próprias e descrição cortada em 35 caracteres.

  A consulta dos itens busca `produto:produtos(nome, referencia, sku, codigo_produto)`, sem `ncm`.
- **Onde fica o código:** a versão certa está no repositório do Orçamentos,
  `04-Sistemas/gestao-financeira-clone-544cb (1)/supabase/functions/generate-report/index.ts` (987 linhas, com os
  modelos). A cópia em `supabase/functions/generate-report/` na raiz é antiga (590 linhas, sem modelo) e **não deve
  ser editada**.
- **Menu:** em `BudgetTableRow.tsx`, o botão da impressora abre "PDF para o cliente" e "PDF interno (com código e
  referência)". "Enviar para o Cliente" (`lib/envio-inicial-cliente.ts`, SPEC-067) baixa sempre o modelo "cliente".

## Definição

### Edge Function `generate-report`

1. Incluir `ncm` na consulta do produto (`produto:produtos(nome, referencia, sku, codigo_produto, ncm)`), também no
   ramo dos itens que vêm da Connect, quando houver `produto_id`.
2. Modelo novo `cliente_ncm`:
   - colunas: `L | Código | NCM | Descrição | Qtd. | Vl. Unit. | Subtotal`;
   - usar as mesmas posições de coluna do modelo "interno", com NCM no lugar da Referência, e o mesmo corte de
     descrição em 35 caracteres;
   - NCM com 8 dígitos sai `9405.19.90`; vazio ou fora do formato sai como está, ou `-` se vazio;
   - aviso de uma linha **logo abaixo da tabela de itens** (antes dos totais, para não disputar espaço com a caixa de totais): *"NCM conforme cadastro do produto. A classificação fiscal definitiva é a
     da nota fiscal."*
3. Qualquer outro valor de `modelo` continua caindo no "cliente", como hoje.

### Orçamentos

- `handleDownloadPdf(modelo: 'cliente' | 'cliente_ncm' | 'interno')`.
- Menu da impressora: incluir **"PDF para o cliente com NCM"** entre as duas opções atuais.
- Nome do arquivo igual ao de hoje (`Orcamento_ORC-xxxx.pdf` / `Venda_VENDA-xxxx.pdf`).

### Fora do escopo

- Calcular CBS/IBS ou mostrar cClassTrib/CST no orçamento.
- Corrigir o NCM das 11 peças sem NCM; isso é feito no Cadastro.
- Mudar a NF-e (Focus); isso é da SPEC-154.

## Decisões aprovadas (03/11, usuário)

- Só no **menu da impressora**; "Enviar para o Cliente" continua baixando o modelo sem NCM.
- **Com** o aviso "NCM conforme cadastro…".
- O "interno" continua sem NCM (proposta mantida).

## Perguntas feitas (respondidas acima)

1. **Enviar para o Cliente:** hoje esse botão sempre baixa o PDF sem NCM. Basta a opção no menu da impressora (proposta
   desta SPEC) ou o "Enviar" também deve perguntar qual modelo usar?
2. **Também no "interno"?** A proposta é **não**: o interno continua igual.
3. **Rodapé de aviso:** pode sair como proposto ou prefere sem rodapé?

## Critérios de aceite

- Os 3 modelos geram PDF válido para o mesmo orçamento, e os modelos "cliente" e "interno" ficam idênticos aos de hoje.
- No "com NCM", cada linha mostra o NCM da peça (ex.: `9405.19.90`). Peça sem NCM mostra `-`.
- Descrição longa não invade a coluna Qtd., e o orçamento com muitos itens continua quebrando página.
- O PDF de venda aprovada sai com o número da venda também no modelo novo (SPEC-164).

## Realizado

### 2026-11-03

- `generate-report/index.ts` (repositório do Orçamentos): `ncm` na consulta dos itens, modelo `cliente_ncm` (colunas L | Código | NCM | Descrição | Qtd. | Vl. Unit. | Subtotal, posições do interno), `formatarNcm` e aviso abaixo da tabela. Os modelos "cliente" e "interno" não mudaram.
- `BudgetTableRow.tsx`: opção "PDF para o cliente com NCM" entre as duas atuais. `tsc --noEmit` ok.
- Não publicado: o `SUPABASE_ACCESS_TOKEN` do `.env` deu 401, e por isso não deu para baixar a versão no ar para comparar nem para publicar. O Orçamentos só vai para o ar junto com a função, senão a opção nova baixaria o PDF sem NCM.

## Pendências

- [ ] SPEC-241: publicar a Edge Function `generate-report` depois de `supabase login`. Antes, baixar a versão no ar e comparar com a do repositório do Orçamentos, porque a função pode estar diferente; depois publicar o Orçamentos.
- [ ] SPEC-241: gerar os 3 PDFs de um orçamento real e conferir o layout (descrição longa, quebra de página e número da venda).
