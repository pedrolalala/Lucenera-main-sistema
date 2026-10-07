"""
Importa o conteúdo de `01-Documento/01 - Planilhas/Mamoria_lucenera.txt` para
o schema `memoria` (sistema "Memória Lucenera", Skip projectId 57204),
diretamente via SUPABASE_DB_URL — contornando o app.

Contexto: o usuário tentou duas vezes colocar esse conteúdo no app (upload do
.docx + "interpretar com IA", e cadastro manual pelos formulários) e nenhuma
das duas gerou registro nenhum em `entities`/`knowledge_items`/`decisions`/
`experiences`/`projects`/`sources` (conferido ao vivo: 0 linhas nas seis
tabelas). Causa raiz confirmada no banco: as Edge Functions de fase 2
(`process-document`, `interpret-memory`, `consolidate-document-run`) nunca
foram deployadas — só as 12 tabelas do núcleo (`20260909_130_...`) existem,
nenhuma das tabelas de `document-ingestion.sql`/`long-document-ingestion.sql`.
O upload de hoje (`memoria.files` id 3bc36681-66bf-4b5c-a9e7-e93b19d27d91,
`memoria.inbox_items` id df8efc1e-6632-43ef-8769-c1579ab8e965) ficou com
`extracted_text` vazio e `processed_at` nulo — o pipeline de IA não existe,
então o upload não tem como virar conhecimento estruturado sozinho.

Decisão (com o usuário): transcrever o conteúdo à mão para os tipos de
registro certos — a maior parte em `knowledge_items` (diretrizes técnicas,
regras comerciais, modelos de texto, processos internos), cadastro
institucional e fornecedores em `entities` (com `relations` ligando as 3
razões sociais ao grupo), e os 2 links em `sources` — em vez de esperar a
fase 2 (documento grande + IA) ser construída.

`Mamoria_lucenera.txt` está duplicado por inteiro (linhas 1–509 == 510–1018,
byte a byte, conferido); só a primeira metade foi usada.

owner_id = 99b32325-87bb-4387-9c75-610cd9fef816 (pedro@lucenera.com.br) — a
mesma conta que fez o upload do .docx hoje, já logada no app da Memória
Lucenera.

Idempotente: cada registro carrega `metadata.import_batch = IMPORT_BATCH`;
antes de inserir, verifica se já existe (por título/nome + import_batch) e
pula. Rodar de novo não duplica.

Uso:
  python scripts/importar_memoria_base_conhecimento.py --dry-run
  python scripts/importar_memoria_base_conhecimento.py
"""

import argparse
import json
import sys
from pathlib import Path

import psycopg2
import psycopg2.extras

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from _supabase_client import SUPABASE_DB_URL  # noqa: E402

OWNER_ID = "99b32325-87bb-4387-9c75-610cd9fef816"  # pedro@lucenera.com.br
IMPORT_BATCH = "base_conhecimento_2026_09_21"
ORIGEM_FILE_ID = "3bc36681-66bf-4b5c-a9e7-e93b19d27d91"
ORIGEM_INBOX_ID = "df8efc1e-6632-43ef-8769-c1579ab8e965"

BASE_META = {"import_batch": IMPORT_BATCH, "origem_arquivo": "Mamoria_lucenera.txt"}


def meta(**extra):
    d = dict(BASE_META)
    d.update(extra)
    return json.dumps(d, ensure_ascii=False)


# ---------------------------------------------------------------------------
# knowledge_items
# ---------------------------------------------------------------------------

KNOWLEDGE_ITEMS = [
    dict(
        knowledge_type="diretriz_tecnica",
        title="Spots Embutidos — Especificação de Fornecedores e Modelos",
        summary="Linhas Dessine/Iluminar como padrão, Metalspot descontinuado, Hole com colmeia para spots ajustáveis, facho 10° para bancadas gourmet.",
        domain="tecnico-materiais",
        subcategory="spots",
        content=(
            "1. Especificação de fornecedores e modelos: Priorizar o uso de luminárias com LED "
            "incorporado, selecionando entre as linhas Dessine e Iluminar, por apresentarem a "
            "melhor combinação entre conforto visual e eficácia no controle de ofuscamento "
            "atualmente disponível. O uso do spot Metalspot foi descontinuado por obsolescência "
            "técnica e não deve mais constar nas especificações da Lucenera. Em casos de "
            "necessidade de spots ajustáveis com lâmpada, deve-se utilizar o Hole com colmeia; "
            "embora tecnicamente válido, o desempenho em termos de conforto visual é inferior à "
            "solução de facho fixo.\n\n"
            "2. Iluminação de áreas de tarefa — bancadas gourmet: Para iluminação de áreas de "
            "tarefa, especificamente bancadas gourmet, o padrão técnico da Lucenera estabelece o "
            "uso de fachos fechados (10° ou o mais próximo possível). Esta diretriz aplica-se "
            "tanto a luminárias tipo spot com lâmpadas dicroicas LED MR16 quanto a luminárias com "
            "LED integrado.\n\n"
            "3. Densidade e espaçamento: O espaçamento entre os spots deve ser rigorosamente "
            "calculado para garantir a continuidade da luz sobre o tampo, eliminando interrupções "
            "ou fachos marcados. Devido à abertura estreita (10°), é mandatória uma maior "
            "densidade de luminárias acima da bancada, assegurando que a luz seja entregue como "
            "matéria contínua e funcional, sem áreas de sombra.\n\n"
            "4. Controle de ofuscamento — risco de facho secundário: Fachos mais abertos, como "
            "36°, geram uma luz espalhada conhecida como facho secundário. Em bancadas, mesas de "
            "jantar ou de trabalho, esse facho secundário incide diretamente no campo de visão "
            "dos usuários, causando ofuscamento. O uso do facho de 10° elimina esse excedente "
            "luminoso, focando a luz estritamente no plano de trabalho. O uso do Hole fixo com "
            "colmeia permanece como padrão para garantir o máximo conforto visual e controle de "
            "ofuscamento."
        ),
    ),
    dict(
        knowledge_type="diretriz_tecnica",
        title="Luminária Fiore — Padronização de Modelos",
        summary="Modelos 80/130/180cm; fonte de luz mini dicroica ou dicroica comum conforme o tamanho.",
        domain="tecnico-materiais",
        subcategory="luminarias",
        content=(
            "Modelos definidos: 80cm, 130cm e 180cm.\n"
            "Fontes de luz indicadas:\n"
            "- Modelo de 80cm: Mini dicroica\n"
            "- Modelos de 130cm e 180cm: Dicroica comum, com o maior facho de luz possível"
        ),
    ),
    dict(
        knowledge_type="diretriz_tecnica",
        title="Iluminação de Paisagismo — Diretrizes Gerais",
        summary="Integração visual na vegetação, posicionamento de espetos/fincos, distância x abertura de facho, efeito \"chapado\", diretrizes para palmeiras, método de leitura visual/celular, controle de qualidade em obra e filosofia de projeto.",
        domain="tecnico-materiais",
        subcategory="paisagismo",
        content=(
            "Integração visual das luminárias no paisagismo\n"
            "A luminária deve estar o mais integrada possível à vegetação. Evitar hastes aparentes "
            "e peças \"peladas\" fora da folhagem. Sempre priorizar instalação saindo de dentro da "
            "vegetação ou escondida pelo paisagismo. O objetivo é que a percepção principal seja da "
            "luz e do efeito, não da peça instalada. Quando possível, usar a própria vegetação ou "
            "elementos naturais para esconder equipamentos.\n\n"
            "Posicionamento de espetos e fincos\n"
            "Em floreiras estreitas, espetos devem ser instalados inclinados para que a luz incida "
            "mais frontalmente na vegetação. Nunca priorizar facilidade de instalação em detrimento "
            "do resultado visual. Espetos inclinados tendem a gerar resultado mais natural e "
            "discreto. Em vegetações densas, avaliar cuidadosamente interferência das folhas no "
            "facho. Em vegetações abertas e leves, é possível esconder melhor a peça sem "
            "comprometer a luz.\n\n"
            "Distância da luminária em relação à vegetação\n"
            "Distância inadequada compromete abertura do facho e leitura da vegetação.\n"
            "Muito próximo: iluminação estourada; facho concentrado; pouca abertura da luz; perda "
            "de profundidade.\n"
            "Mais distante: melhora abertura do facho; amplia cobertura; suaviza iluminação; "
            "melhora leitura volumétrica.\n\n"
            "Efeito \"chapado\"\n"
            "Quando a luminária está distante demais e o facho abre excessivamente, a iluminação "
            "fica \"chapada\": ilumina tudo por igual, reduz contraste, elimina drama entre luz e "
            "sombra, empobrece percepção espacial. Nem todo cenário deve ser homogêneo — o "
            "equilíbrio entre contraste e preenchimento deve ser analisado caso a caso.\n\n"
            "Relação entre tipo de vegetação e posicionamento\n"
            "Vegetações abertas/vazadas: permitem efeitos internos de luz e contraluz, geram "
            "profundidade visual interessante, possibilitam luminárias mais próximas.\n"
            "Vegetações densas/fechadas: exigem maior distanciamento, podem bloquear completamente "
            "o facho quando a luminária está muito próxima, favorecem uso de fachos mais abertos.\n\n"
            "Diretrizes específicas para palmeiras\n"
            "Palmeiras finas podem receber luminárias próximas ao caule. Distância recomendada: "
            "entre 15 cm e 30 cm do tronco. Quanto maior a altura da palmeira, maior deve ser o "
            "distanciamento. Muito próximo: ilumina apenas base e copa, perde leitura do tronco "
            "superior. Muito distante: ilumina apenas copa, perde verticalidade do tronco.\n\n"
            "Uso estratégico do distanciamento\n"
            "Em áreas abertas ou gramados: é possível afastar luminárias, o que otimiza quantidade "
            "de peças e reduz custo. Em áreas com circulação: evitar distanciamentos que prejudiquem "
            "passagem ou manutenção. Sempre considerar: ponto de vista principal, circulação, "
            "interferências físicas, crescimento futuro da vegetação.\n\n"
            "Leitura geométrica da vegetação\n"
            "Antes de definir posição da luminária: analisar geometria da planta, imaginar "
            "trajetória da luz, prever áreas de sombra. A luz ilumina aquilo que \"enxerga\" — "
            "elementos escondidos da luminária permanecerão em sombra.\n\n"
            "Método Lucenera para prever efeito da iluminação\n"
            "Técnica de leitura visual: posicionar o olhar no ponto onde ficará a luminária. O que "
            "for visível deste ponto tende a ser iluminado; o que não for visível ficará sombreado.\n"
            "Uso do celular como ferramenta de análise: utilizar a câmera do celular na altura e "
            "posição da luminária. A imagem capturada antecipa áreas iluminadas, áreas ocultas, "
            "sombras e profundidade do efeito.\n\n"
            "Altura das peças no paisagismo\n"
            "Alturas devem ser avaliadas no projeto, na marcação em obra e durante instalação. "
            "Luminárias aparentes em excesso comprometem o resultado final — preferir peças mais "
            "baixas sempre que possível. Crescimento futuro da vegetação deve ser considerado; "
            "melhor deixar a peça inicialmente mais escondida do que excessivamente aparente.\n\n"
            "Controle de qualidade em obra\n"
            "A Lucenera deve validar posicionamentos antes da entrega final. Recomenda-se visita de "
            "conferência e marcação prévia em obra. Ajustes de altura e posicionamento devem "
            "ocorrer antes da finalização — pequenos erros de implantação comprometem fortemente o "
            "resultado visual.\n\n"
            "Estratégia de estoque e padronização\n"
            "Algumas peças podem demandar adaptações específicas da Lucenera; soluções "
            "customizadas podem virar padrão interno. O estoque deve considerar reposições "
            "rápidas, ajustes de obra, peças de diferentes alturas e necessidades recorrentes de "
            "campo.\n\n"
            "Filosofia de projeto em paisagismo\n"
            "A iluminação deve parecer natural e integrada ao jardim. A peça nunca deve competir "
            "visualmente com o paisagismo — o efeito da luz é mais importante que a presença da "
            "luminária. Cada vegetação possui comportamento próprio e exige análise individual; "
            "não existe regra fixa universal: cada planta, cada jardim, cada ponto de vista e cada "
            "arquitetura exigem solução específica."
        ),
    ),
    dict(
        knowledge_type="diretriz_tecnica",
        title="Testes em Andamento — Fita LED 5000K",
        summary="Teste de alternância de tonalidade com fita LED 5000K em sancas e lonas tensionadas (provisório).",
        domain="tecnico-materiais",
        subcategory="fitas-led",
        status="review",
        content=(
            "Implementação de testes com fita LED 5000K para validação de alternância de "
            "tonalidade de luz.\n"
            "Aplicações foco: sancas e lonas tensionadas.\n"
            "Objetivo: análise de comportamento cromático e integração arquitetônica."
        ),
    ),
    dict(
        knowledge_type="modelo_comunicacao",
        title="Modelo de E-mail — Pedido de Garantia de Produtos",
        summary="Template de e-mail para formalizar pedido de garantia junto ao fabricante/fornecedor.",
        domain="comercial",
        subcategory="garantia",
        content=(
            "Assunto: Solicitação de Garantia - [Nome do Cliente] - [Material Adquirido]\n\n"
            "Prezados,\n\n"
            "Gostaríamos de formalizar o pedido de garantia referente ao material abaixo, conforme "
            "os dados registrados em nosso sistema:\n"
            "Nome do Cliente: [Nome do Cliente]\n"
            "Material Adquirido: [Material Adquirido]\n"
            "Data da Compra: [Data da Compra]\n"
            "Número da Venda: [Número da Venda]\n\n"
            "Solicitamos o início dos procedimentos necessários para a avaliação e atendimento "
            "desta garantia.\n\n"
            "Atenciosamente,\n"
            "Equipe Lucenera"
        ),
    ),
    dict(
        knowledge_type="diretriz_tecnica",
        title="Fitas LED 2700K — Padrões de Temperatura e Fidelidade Cromática",
        summary="STL24845/27 é a fita padrão para sancas com Dessine/Stella 2700K; STL21834/27 evitada nessas composições (desvio rosado); testar in loco em madeira/marcenaria colorida.",
        domain="tecnico-materiais",
        subcategory="fitas-led",
        content=(
            "A temperatura de cor de 2700K é fundamental para a atmosfera de projetos "
            "residenciais e de hospitalidade, porém apresenta variações significativas entre "
            "modelos:\n\n"
            "- STL24845/27 (16W/m | All Light 24V PRO): É a fita padrão para sancas em forros de "
            "gesso com fundo branco. Apresenta o melhor desempenho cromático quando combinada a "
            "spots da marca Dessine (2700K) e lâmpadas dicroicas Stella (6W 36° 2700K).\n"
            "- STL21834/27 (14.5W/m | Full LED 24V PRO): Deve ser evitada em composições diretas "
            "com Dessine ou Stella, pois apresenta um desvio cromático para tons rosados, "
            "comprometendo a unidade visual do ambiente.\n"
            "- Superfícies Especiais: Em forros de madeira ou marcenarias coloridas, é obrigatória "
            "a realização de testes in loco. A interação da luz com a pigmentação do material pode "
            "alterar a percepção da temperatura de cor, exigindo ajustes na especificação para "
            "manter a coerência do conceito."
        ),
    ),
    dict(
        knowledge_type="diretriz_tecnica",
        title="Fitas LED — Detalhamento e Aplicações em Marcenaria",
        summary="STL24845/27 (16W/m) para bancadas de trabalho; combinar com STL24842/27 (8W/m) para uniformidade tonal entre escalas de marcenaria.",
        domain="tecnico-materiais",
        subcategory="fitas-led",
        content=(
            "A iluminação de mobiliário exige precisão para evitar ofuscamento e garantir "
            "funcionalidade:\n\n"
            "- Bancadas de Trabalho: A fita STL24845/27 (16W/m) é recomendada pela intensidade "
            "adequada para tarefas que exigem acuidade visual.\n"
            "- Composição de Potências: Para garantir uniformidade tonal em diferentes escalas de "
            "marcenaria, utilize a combinação entre STL24845/27 (16W/m) e STL24842/27 (8W/m), "
            "ambos da linha All Light 24V PRO."
        ),
    ),
    dict(
        knowledge_type="diretriz_tecnica",
        title="Fitas LED — Sistemas de Iluminação Difusa (Lonas Tensionadas)",
        summary="Luz de fundo: 8W/m em 4000K/5000K. Luz perimetral: potência média/alta dimerizável em 2700K (STL24845/27 ou STL21834/27). Penumbra: tom âmbar ou STL25845/24.",
        domain="tecnico-materiais",
        subcategory="fitas-led",
        content=(
            "A especificação para sistemas tensionados varia conforme a posição da fonte e o "
            "cenário desejado:\n\n"
            "- Luz de Fundo (Sistema Total): Priorizar fitas de baixa potência (8W/m) com "
            "temperaturas neutras ou frias (4000K ou 5000K) para garantir uma base de luz limpa e "
            "eficiente.\n"
            "- Luz Perimetral: Utilizar fitas de média ou alta potência (dimerizáveis) em 2700K. "
            "Modelos indicados: STL24845/27 ou STL21834/27.\n"
            "- Cenários de Penumbra: Para níveis de iluminância reduzidos, recomenda-se a "
            "aplicação perimetral em tom âmbar ou STL25845/24 (16W/m | 2400K), proporcionando "
            "maior conforto visual."
        ),
    ),
    dict(
        knowledge_type="diretriz_tecnica",
        title="Fitas LED — Ambientes de Alta Performance e Luz Natural",
        summary="STL21836/40 (19W/m 4000K) para escritórios; STL24845/30 (3000K) restrito, não usar em sancas residenciais; alta intensidade: STL21838/27 ou STL24857/30.",
        domain="tecnico-materiais",
        subcategory="fitas-led",
        content=(
            "Em espaços como escritórios ou locais com forte incidência de luz natural, a "
            "intensidade e a temperatura devem compensar o contraste diurno:\n\n"
            "- STL21836/40 (19W/m | 4000K): Apresenta o melhor resultado para ambientes "
            "corporativos, superando a versão de 16W/m, que pode se mostrar insuficiente em "
            "cenários diurnos.\n"
            "- Restrições: O modelo STL24845/30 (3000K) não deve ser aplicado em sancas "
            "residenciais, sendo restrito a usos específicos onde essa temperatura de cor seja "
            "tecnicamente justificada.\n"
            "- Alta Intensidade: Para projetos com demandas luminosas excepcionais, utilizar "
            "STL21838/27 (30W/m) ou STL24857/30 (25W/m)."
        ),
    ),
    dict(
        knowledge_type="diretriz_tecnica",
        title="Fitas LED — Integridade Técnica e Proteção (IP)",
        summary="Em ambientes com áreas úmidas (ex. banheiro), todas as fitas do mesmo ambiente devem seguir o mesmo padrão IP (ex. IP67) para não alterar a tonalidade.",
        domain="tecnico-materiais",
        subcategory="fitas-led",
        content=(
            "A manutenção da tonalidade da luz está diretamente ligada ao índice de proteção "
            "(IP) dos componentes: ao especificar fitas IP67 para áreas de contato direto com "
            "umidade (ex. banheiros), todas as demais fitas do mesmo ambiente devem "
            "obrigatoriamente seguir o padrão IP67. A diferença de encapsulamento entre IP20 e "
            "IP67 altera sensivelmente a tonalidade da luz; a padronização é a única forma de "
            "garantir a integridade visual do espaço."
        ),
    ),
    dict(
        knowledge_type="modelo_comunicacao",
        title="Modelos de Contrato — Resposta Padrão ao Cliente (Contrato de Projeto x Contrato de Sinal)",
        summary="Texto padrão explicando a diferença entre Contrato de Projeto (consultoria independente) e Contrato de Sinal (integra projeto + compra de materiais).",
        domain="comercial",
        subcategory="contratos",
        content=(
            "Prezado(a) [Nome do Cliente],\n\n"
            "A Lucenera oferece dois modelos de contrato para o desenvolvimento de projetos de "
            "iluminação, ambos com o mesmo rigor técnico e qualidade de entrega. A diferença está "
            "na estrutura comercial e no escopo de responsabilidade técnica.\n\n"
            "CONTRATO DE PROJETO\n"
            "Neste modelo, a Lucenera atua como consultora técnica independente. O projeto é "
            "desenvolvido em três etapas sequenciais: 1. Estudo Preliminar (análise dos projetos "
            "existentes, reconhecimento do espaço e apresentação do conceito luminotécnico); "
            "2. Pré-Executivo (definição do conceito, compatibilização com os demais projetos e "
            "adequação ao orçamento); 3. Executivo (especificação técnica completa com fichas "
            "técnicas, memorial descritivo e projeto executivo). A remuneração é estruturada em "
            "duas parcelas: uma na assinatura do contrato e outra com a aprovação do projeto "
            "executivo. O cliente mantém total liberdade para adquirir as luminárias especificadas "
            "junto a qualquer fornecedor, sem restrições comerciais ou técnicas da Lucenera.\n\n"
            "CONTRATO DE SINAL\n"
            "Este modelo integra o desenvolvimento do projeto com a possibilidade de aquisição de "
            "materiais junto à Lucenera. As três etapas de projeto são idênticas ao modelo "
            "anterior. A diferença está na estrutura de pagamento: caso o cliente adquira todas as "
            "luminárias especificadas junto à Lucenera (respeitando um valor mínimo estabelecido), "
            "a segunda parcela dos honorários é dispensada, e a primeira parcela é integralmente "
            "descontada do valor da compra dos materiais. Se optar por adquirir as luminárias em "
            "outro fornecedor, o cliente paga a integralidade dos honorários, sem desconto, e a "
            "Lucenera não assume responsabilidade técnica por incompatibilidades ou inadequações "
            "que possam surgir com produtos diferentes dos especificados no projeto."
        ),
    ),
    dict(
        knowledge_type="diretriz_tecnica",
        title="Iluminação de Colunas e Embutidos",
        summary="Embutidos de piso Picco assimétricos não servem para colunas isoladas (só em sequência contínua sobre paredes). Para colunas: facho 10°/15°, potência 8W padrão.",
        domain="tecnico-materiais",
        subcategory="colunas",
        content=(
            "Embutidos de piso Picco Assimétricos: luminárias embutidas com distribuição "
            "assimétrica não são adequadas para iluminar colunas isoladas, independentemente de "
            "sua largura — a dispersão lateral dessa óptica é incompatível com a concentração de "
            "luz necessária para destacar elementos verticais.\n\n"
            "Aplicação correta de embutidos assimétricos: devem ser utilizados exclusivamente em "
            "sequência contínua. Quando dispostos em série, criam iluminação difusa e uniforme, "
            "proporcionando conforto visual e distribuição homogênea de luz sobre superfícies "
            "verticais como paredes.\n\n"
            "Solução para iluminação de colunas: luminárias com facho concentrado (10° ou 15°), "
            "potência de 8W como padrão; potências menores apenas em casos específicos, quando a "
            "coluna apresentar dimensões reduzidas. Essa abordagem garante precisão óptica, "
            "controle de luz e hierarquia visual adequada ao projeto."
        ),
    ),
    dict(
        knowledge_type="regra_comercial",
        title="Orçamentos de Espelhos — Modelo de Venda Direta",
        summary="Venda direta ao cliente final: comissão Lucenera 20% + RT arquiteto 10% (com NF de serviço), fonte de luz LED por conta da Lucenera, frete incluso no orçamento do fornecedor.",
        domain="comercial",
        subcategory="espelhos",
        content=(
            "1. Modalidade de venda: os orçamentos de espelhos seguem o modelo de venda direta "
            "ao cliente final. A Lucenera atua como intermediadora técnica da compra; o pagamento "
            "ocorre diretamente entre cliente e fornecedor.\n\n"
            "2. Estrutura de comissionamento: o valor do orçamento apresentado ao cliente já "
            "contempla as comissões — Lucenera 20%, Responsabilidade Técnica (RT) ao arquiteto "
            "10%. Ambas as comissões exigem emissão de nota fiscal de serviço como condição "
            "obrigatória para recebimento.\n\n"
            "3. Fornecimento dos componentes de iluminação: a fonte de luz LED é de "
            "responsabilidade integral da Lucenera (perfil, driver, fita LED). Duas alternativas "
            "operacionais em avaliação, a definir com o fornecedor: (a) manutenção de estoque "
            "Lucenera nas instalações do fornecedor; ou (b) envio do material após aprovação do "
            "orçamento pelo cliente.\n\n"
            "4. Diretrizes para elaboração de orçamentos: o fornecedor deve incluir o cálculo de "
            "frete do produto já na composição do orçamento; solicitações de itens especiais são "
            "previamente sinalizadas pela equipe comercial da Lucenera para serem corretamente "
            "incorporadas.\n\n"
            "5. Medidas e tabela de referência: o fabricante envia à Lucenera uma tabela de "
            "referência com as medidas indicadas (valor do produto, frete, comissionamento "
            "aplicado), formando uma base consolidada de valores de partida para apresentação ao "
            "cliente final."
        ),
    ),
    dict(
        knowledge_type="diretriz_tecnica",
        title="Spots Dessine em Pé-Direito Duplo (até 8m)",
        summary="Em ambientes de pé-direito duplo (até 8m) com spots Dessine, é obrigatório usar potências ≥12W — condição de validação do projeto.",
        domain="tecnico-materiais",
        subcategory="spots",
        content=(
            "Aplicação: projetos luminotécnicos de ambientes com pé-direito duplo, com altura de "
            "até 8 metros.\n"
            "Fornecedor: Dessine.\n"
            "Especificação mínima: quando a marca Dessine for selecionada para composição dos "
            "spots nesses ambientes, é obrigatório considerar potências iguais ou superiores a "
            "12W.\n"
            "Justificativa técnica: a distância entre a fonte luminosa e o plano útil em "
            "ambientes de até 8 metros reduz significativamente a iluminância no ponto de "
            "incidência. Potências inferiores a 12W, nesse contexto, comprometem a função "
            "luminotécnica pretendida e descaracterizam o resultado do projeto.\n"
            "Condição de validação: esta diretriz deve ser observada em todas as fases de "
            "especificação e detalhamento, sendo condição de validação do projeto sempre que a "
            "combinação Dessine + pé-direito duplo até 8 metros estiver presente."
        ),
    ),
    dict(
        knowledge_type="regra_comercial",
        title="Comissões — Regra Geral Sem Arquiteto",
        summary="Se o orçamento não tiver arquiteto envolvido, o percentual total de comissão (Lucenera + arquiteto) fica inteiro para a Lucenera.",
        domain="comercial",
        subcategory="comissoes",
        content="Se não tiver arquiteto, a porcentagem total de comissão vem inteira para a Lucenera.",
    ),
    dict(
        knowledge_type="regra_comercial",
        title="Figueiredo Nunes — Cálculo de Câmbio para Orçamentos",
        summary="Fórmula: câmbio do dia + 3,5% de spread + arredondamento; considerar valor com IPI. Exemplo: 6,00 → 6,21 → arredondar para 6,35/6,40.",
        domain="comercial",
        subcategory="fornecedores",
        content=(
            "FIGUEIREDO NUNES - considerar valor com IPI + 3,5% no dólar + arredondamento.\n"
            "Como fazer o cálculo de venda dos orçamentos: Euro/dólar do dia + 3,5% de spread + "
            "arredondamento. Exemplo: 6,00 + 3,5% = 6,21 + arredondamento, usar 6,35/6,40. "
            "Achado o valor do euro, multiplica pelo valor do orçamento enviado pelo fornecedor."
        ),
    ),
    dict(
        knowledge_type="modelo_comunicacao",
        title="Modelo de Texto — Clientes que Adquiriram Luminárias com a Figueiredo Nunes",
        summary="Template explicando que a peça é importada via Figueiredo Nunes, pagamento 50% sinal + 50% no desembaraço, frete por conta do cliente, prazo 90-120 dias.",
        domain="comercial",
        subcategory="fornecedores",
        content=(
            "Boa tarde, XXXX. Tudo bem com você?\n"
            "Segue orçamento da luminária XXXXXX.\n"
            "Essa peça é importada, e a empresa responsável pela compra e importação para nós é a "
            "Figueiredo Nunes.\n"
            "Essa importadora trabalha com apenas uma forma de pagamento, sendo ela: 50% de sinal "
            "agora e os 50% restantes no desembaraço, que é quando o material chega ao porto no "
            "Brasil.\n"
            "Na etapa final, pode ocorrer uma pequena variação no valor, para mais ou para menos, "
            "conforme a cotação do euro no dia. Essa diferença, quando existente, é ajustada no "
            "último pagamento.\n"
            "Quando o material estiver disponível, será realizada a cotação do frete considerando "
            "o envio direto para vocês, sendo esse custo por conta do cliente.\n"
            "Por se tratar de uma peça importada, o prazo médio para o produto chegar no Brasil é "
            "em torno de 90 a 120 dias."
        ),
    ),
    dict(
        knowledge_type="processo_interno",
        title="Checklist — Solicitação de Orçamento Fasa Fibra Ótica",
        summary="Dados padrão a coletar do cliente/obra antes de pedir orçamento de fibra ótica à Fasa.",
        domain="comercial",
        subcategory="fornecedores",
        content=(
            "Dados padrão para solicitação de orçamento Fasa Fibra Ótica:\n"
            "- Nome do cliente\n"
            "- Endereço da obra\n"
            "- Arquivo em DWG com planta baixa e cortes\n"
            "- Considerar instalação ou não\n"
            "- Se na obra já tiver pontos executados, confirmar se foi deixado rosca ou tubo de "
            "3/4\"\n"
            "- Em pontos já executados, confirmar se as tubulações são individuais ou não\n"
            "- Revestimento\n"
            "- Troca de cor ou não\n"
            "- Confirmar sobre local de alojamento do iluminador"
        ),
    ),
    dict(
        knowledge_type="processo_interno",
        title="Apresentação de Projetos em Reuniões Online",
        summary="Modelo padrão de apresentação para reuniões à distância deve sempre incluir a planta.",
        domain="processo",
        subcategory="apresentacao",
        content="Modelo padrão de apresentação de projetos para reuniões online: modelo com planta sempre incluída para apresentações de projeto à distância.",
    ),
    dict(
        knowledge_type="diretriz_tecnica",
        title="Regras de Espaçamento para Efeito de Luz Homogênea",
        summary="Embutido de piso assimétrico: 1,10m a 1,20m. Picco de solo: 35 a 40cm.",
        domain="tecnico-materiais",
        subcategory="espacamento",
        content=(
            "Regras de uso para efeito de luz homogênea:\n"
            "- Embutido de piso assimétrico: usar de 1,10m a 1,20m para efeito homogêneo.\n"
            "- Picco de solo: usar de 35 a 40cm para efeito homogêneo."
        ),
    ),
    dict(
        knowledge_type="regra_comercial",
        title="Política de Aluguel de Peças",
        summary="Lucenera não estuda aluguel de luminárias como modelo; empréstimos longos avaliados caso a caso pelo perfil do profissional; material devolvido pode ser vendido com desconto de 20-50%.",
        domain="comercial",
        subcategory="politica-interna",
        content=(
            "Não é viável estudar o aluguel de luminárias. Para novos casos de empréstimos a "
            "longo prazo, devemos avaliar o quão parceiro é o profissional para aceitar ou não o "
            "empréstimo. Quando o material voltar, ele pode ser vendido com desconto de 20% a "
            "50%, de acordo com o estado atual da luminária e a embalagem."
        ),
    ),
    dict(
        knowledge_type="processo_interno",
        title="Padronização de Relatórios de Cenas",
        summary="Priorizar projetos com automação, padronizar e automatizar relatórios de cenas (uso, cenários, aplicações). Cenas sugeridas: Geral, Intimista, Festa. Cobrança conforme faturamento do cliente (regra ainda a definir).",
        domain="processo",
        subcategory="automacao",
        content=(
            "Priorizar projetos com automação; identificar clientes importantes; padronizar "
            "relatórios de cenas; automatizar a geração desses relatórios; criar modelo "
            "replicável. Incluir: uso, cenários, aplicações.\n\n"
            "Cenas sugeridas para testes: 1. Geral; 2. Intimista; 3. Festa.\n\n"
            "Clientes com maior faturamento não serão cobrados; clientes com faturamento menor "
            "devem ser cobrados por esse serviço — padrão de cobrança ainda a definir."
        ),
    ),
    dict(
        knowledge_type="processo_interno",
        title="Processos Internos — Orçamentos, Produção de Peças e Entrega de Materiais",
        summary="Orçamento sem código de fornecedor (código só sai na formalização via DocuSign); sugestão de foto de peça montada; lista de componentes quando entrega seccionada.",
        domain="processo",
        subcategory="operacional",
        content=(
            "Orçamentos: padrão de envio sem código de fornecedor. Os códigos são apresentados "
            "somente na formalização via DocuSign. Sugestão registrada: incluir um aviso no "
            "sistema, antes de salvar o orçamento, indicando qual versão (com ou sem código) "
            "deverá ser impressa.\n\n"
            "Produção de Peças Lucenera: sugestão de ter foto da luminária montada + acessórios "
            "juntos da peça, para facilitar a identificação dos volumes na obra.\n\n"
            "Entrega de Materiais (Versa e Terceiros): quando a luminária for entregue seccionada "
            "em mais de uma embalagem, deverá acompanhar uma lista separada de componentes. Essa "
            "conferência é feita no momento da entrega na obra."
        ),
    ),
    dict(
        knowledge_type="regra_comercial",
        title="Cálculo de Sinal e Projeto por Área (m²)",
        summary="Tabela de faixas por m² (R$40/35/30/25, 50% sinal + 50% executivo) e paisagismo R$12-15/m²; sinal = 50% do valor total do cálculo de projeto.",
        domain="comercial",
        subcategory="precificacao",
        content=(
            "Regras para cálculo de valores de sinal e projeto para montagem de contrato de "
            "serviços Lucenera:\n"
            "- até 500m²: R$ 40,00/m² — 50% sinal / 50% executivo\n"
            "- acima de 500m²: R$ 35,00/m² — 50% sinal / 50% executivo\n"
            "- acima de 1.000m²: R$ 30,00/m² — 50% sinal / 50% executivo\n"
            "- acima de 1.200m²: R$ 25,00/m² — 50% sinal / 50% executivo\n"
            "- projeto de paisagismo: entre R$ 12,00/m² e R$ 15,00/m²\n\n"
            "Para cálculo do sinal de projeto, considerar 50% do valor total referente ao "
            "cálculo de projeto."
        ),
    ),
    dict(
        knowledge_type="modelo_comunicacao",
        title="Modelo de Texto — Envio de Documentos no DocuSign",
        summary="Template padrão para acompanhar o envio de documentos para assinatura via DocuSign.",
        domain="comercial",
        subcategory="docusign",
        content=(
            "Boa tarde! Obrigado pela confiança e por fecharem conosco.\n"
            "Segue o link para assinatura e conferência. Se tiver algo a ser revisado, por favor "
            "nos sinalizem antes de assinar, para que eu possa ajustar.\n"
            "Qualquer dúvida, estou à disposição.\n"
            "Att.,"
        ),
    ),
    dict(
        knowledge_type="modelo_comunicacao",
        title="Resposta Padrão — Processo de Garantia",
        summary="Template de resposta interna confirmando material dentro da garantia e explicando o processo de troca.",
        domain="comercial",
        subcategory="garantia",
        content=(
            "Verificamos que o material está dentro do prazo de cobertura de garantia pelo "
            "fabricante, e temos para reposição em nosso estoque. O processo de garantia exige "
            "que sejam retiradas as peças queimadas e levadas até nosso estoque no endereço "
            "abaixo. No momento serão avaliadas e testadas; caso estejam aptas à garantia, serão "
            "substituídas no ato sem cobrança."
        ),
    ),
    dict(
        knowledge_type="processo_interno",
        title="Cadastro de Cliente no Sistema Connect",
        summary="Pessoa física sempre como NÃO CONTRIBUINTE; orçamento em \"vendas\" (não \"entregas futuras\"); revisar dados; deixar cadastro como \"ativo\".",
        domain="processo",
        subcategory="connect",
        content=(
            "Para cadastro de cliente pessoa física no sistema Connect, sempre cadastrar como "
            "NÃO CONTRIBUINTE no campo \"tipo cliente\" (final da página) — senão dá problema na "
            "parte fiscal.\n"
            "- Montar orçamentos em \"vendas\", não em \"entregas futuras\".\n"
            "- Revisar dados do cliente no cadastro para as informações saírem corretas.\n"
            "- Deixar cadastro do cliente como \"ativo\"."
        ),
    ),
    dict(
        knowledge_type="regra_comercial",
        title="Nota Fiscal — Sinal de Projeto",
        summary="Não se emite NF para o valor de sinal de projeto; NF é vinculada à compra dos produtos (ou NF de serviços se a compra não for feita com a Lucenera).",
        domain="comercial",
        subcategory="fiscal",
        content=(
            "Não será emitida nota fiscal para o valor pago como sinal de projeto — a nota "
            "fiscal é vinculada à compra dos produtos. Caso não venha a ser feita a compra do "
            "material com a Lucenera, será emitida a NF de serviços."
        ),
    ),
    dict(
        knowledge_type="regra_comercial",
        title="Pontuação Clube Mais",
        summary="Pontua no mês em que a venda é enviada ao financeiro, integral e independente da forma/parcelamento; financeiro tem até o 5º dia útil do mês seguinte para considerar.",
        domain="comercial",
        subcategory="clube-mais",
        content=(
            "A pontuação é considerada com base no mês em que a venda é enviada ao financeiro "
            "(ex.: vendas encaminhadas em fevereiro pontuam em fevereiro). A pontuação não está "
            "vinculada ao pagamento e é aplicada de forma integral, independentemente da forma ou "
            "do parcelamento. O financeiro tem até o 5º dia do mês seguinte para considerar a "
            "pontuação referente ao mês anterior."
        ),
    ),
    dict(
        knowledge_type="regra_comercial",
        title="Modelos de Contratação Lucenera — Contrato de Sinal e Contrato de Projeto (detalhado)",
        summary="Detalhamento interno dos 2 modelos: Contrato de Sinal (sinal abatido se comprar com a Lucenera, ex. R$80.000 com R$7.500 de sinal) e Contrato de Projeto (parcelado por etapa, sem vínculo de fornecimento).",
        domain="comercial",
        subcategory="contratos",
        content=(
            "A Lucenera oferece dois modelos de contratação distintos, estruturados para atender "
            "diferentes momentos de decisão do cliente e diferentes níveis de vínculo com o "
            "escritório. Ambos preservam o rigor técnico do desenvolvimento projetual, "
            "diferenciando-se quanto ao escopo de entrega e à relação com o fornecimento de "
            "luminárias.\n\n"
            "1. Contrato de Sinal\n"
            "Indicado para clientes que consideram desenvolver o projeto luminotécnico e, ao "
            "final do processo, adquirir as luminárias com a Lucenera.\n"
            "Como funciona: o contrato prevê o pagamento antecipado de um valor de sinal, que "
            "viabiliza o desenvolvimento integral do estudo luminotécnico até a etapa de "
            "pré-executivo. Continuidade com aquisição de luminárias: caso o cliente prossiga com "
            "a compra por meio da Lucenera, o valor pago como sinal é integralmente abatido do "
            "orçamento final e a segunda parcela do contrato é desconsiderada — o projeto "
            "executivo completo é entregue como parte do fornecimento. Exemplo prático: para um "
            "orçamento de R$ 80.000,00, os R$ 7.500,00 já pagos como sinal são descontados do "
            "valor total, e a segunda parcela de R$ 7.500,00 prevista em contrato é dispensada. "
            "Alternativas de encerramento se o cliente não seguir com a compra: (a) aquisição do "
            "projeto executivo isolado — paga pelo executivo e recebe o projeto completo, podendo "
            "executá-lo com fornecedores de sua escolha; (b) rescisão contratual — o valor pago "
            "como sinal permanece com a Lucenera como remuneração pelo trabalho técnico já "
            "desenvolvido até aquela etapa.\n\n"
            "2. Contrato de Projeto\n"
            "Indicado para clientes que desejam o projeto luminotécnico completo, sem vínculo com "
            "o fornecimento de luminárias. A contratação abrange a entrega integral do projeto "
            "(especificações gerais, cadernos técnicos, detalhamentos executivos), com escopo "
            "dimensionado com base em horas técnicas. Estrutura de pagamento: valor parcelado "
            "conforme as etapas de entrega, garantindo previsibilidade financeira e "
            "correspondência direta entre pagamento e produção técnica entregue."
        ),
    ),
    dict(
        knowledge_type="regra_comercial",
        title="Custos de Viagem — Cálculo de Sinal por Zona de Distância",
        summary="Adicional sobre o valor por m² conforme distância de Ribeirão Preto: Zona 1 sem acréscimo, Zona 2 +R$500, Zona 3 (até São Paulo) +R$1.500, Zona 4 caso a caso; hospedagem recalcula o adicional.",
        domain="comercial",
        subcategory="precificacao",
        content=(
            "O valor do sinal de futura compra é calculado com base em uma tabela de custos de "
            "projeto por m², acrescido de um valor considerando a distância do projeto até "
            "Ribeirão Preto (custos de deslocamento da equipe).\n\n"
            "Zona 1 — Ribeirão Preto: projetos na própria cidade. Cálculo: apenas valores por m², "
            "sem adição de deslocamento (não há necessidade de visita externa).\n"
            "Zona 2 — Região Metropolitana Expandida (até 250 km): valores por m² + R$ 500,00 "
            "(cobre visita em regime de bate/volta, sem hospedagem).\n"
            "Zona 3 — Região Ampliada (até 350 km, incluindo São Paulo): valores por m² + R$ "
            "1.500,00 (deslocamento mais complexo/distante, ainda em bate/volta).\n"
            "Zona 4 — Acima de 350 km: valores por m² + valor de visita estipulado caso a caso, "
            "calculado individualmente conforme as particularidades do deslocamento.\n\n"
            "Condição crítica — hospedagem: todas as visitas acima são em regime de bate/volta, "
            "sem hospedagem incluída. Se a hospedagem for necessária, os adicionais de "
            "deslocamento (R$ 500,00, R$ 1.500,00 ou valor caso a caso) devem ser revisados e "
            "recalculados para incorporar hospedagem, alimentação e demais despesas correlatas — "
            "revisão feita antes da formalização do contrato."
        ),
    ),
]

# ---------------------------------------------------------------------------
# sources (links)
# ---------------------------------------------------------------------------

SOURCES = [
    dict(
        source_type="link_drive",
        title="Arquivos IFC — Dessine",
        url="https://drive.google.com/drive/u/1/folders/1J2xKEHz3OKbZF_a3e5_Jt4JnWPzDvHuc",
        domain="tecnico-materiais",
        notes="Link para acesso e download de arquivos em formato IFC da marca Dessine.",
    ),
    dict(
        source_type="sistema_interno",
        title="Sistema Lucenera — Solicitação/Acompanhamento de Entrega e Separação de Material",
        url="https://lucenera.lovable.app/login",
        domain="processo",
        notes=(
            "Sistema para solicitação de entrega de material de iluminação para obra, "
            "acompanhamento do processo de entrega, ou separação de material para retirada no "
            "estoque ou showroom Lucenera."
        ),
    ),
]

# ---------------------------------------------------------------------------
# entities
# ---------------------------------------------------------------------------

GRUPO_METADATA = {
    "nome_fantasia": "LUCENERA ATELIER DA LUZ",
    "endereco_sede_faturamento": "R. Ayrton Roxo, 867 — Alto da Boa Vista — Ribeirão Preto/SP — CEP 14025-270",
    "endereco_suprimentos": "R. Doutor Hugo Fortes, 1010 — Pq. Ind. Lagoinha — Ribeirão Preto/SP",
    "telefone_geral": "(16) 3442-3545",
    "site": "https://lucenera.com.br/",
    "email_geral": "contato@lucenera.com.br",
    "emails_nfe": ["financeiro@lucenera.com.br", "caroline@lucenera.com.br", "vinicius@lucenera.com.br"],
    "contatos": {
        "faturamento_financeiro": [
            {"nome": "Lana Bispo", "email": "financeiro@lucenera.com.br", "telefone": "(16) 99777-5789"},
            {"nome": "Caroline S. Foresto", "email": "caroline@lucenera.com.br", "telefone": "(16) 99777-5789"},
            {"nome": "Vinicius Bortolin", "email": "vinicius@lucenera.com.br", "telefone": "(16) 99777-5789"},
        ],
        "suprimentos": [
            {"nome": "Matheus Luzente", "email": "matheus@lucenera.com.br", "telefone": "(16) 99107-1430"},
            {"nome": "Debora B. Souza", "email": "debora@lucenera.com.br", "telefone": "(16) 99314-5209"},
            {"nome": "Vinicius Bortolin", "email": "vinicius@lucenera.com.br", "telefone": "(16) 99777-5789"},
        ],
        "recebimento_mercadoria": [
            {"nome": "Matheus Luzente", "email": "matheus@lucenera.com.br", "telefone": "(16) 99107-1430"},
            {"nome": "Vinicius Bortolin", "email": "vinicius@lucenera.com.br", "telefone": "(16) 99777-5789"},
        ],
        "comercial": [
            {"nome": "Terezinha Figueiredo", "email": "contato@lucenera.com.br", "telefone": "(16) 3442-3545"},
        ],
    },
    "dados_bancarios_comuns": {
        "banco": "BRADESCO",
        "agencia": "3427",
        "gerente": "Luciana",
        "telefone_gerente": "(16) 99331-3022",
    },
    "principais_fornecedores_institucionais": [
        "ACEND ILUMINAÇÃO LTDA ME",
        "EVOSTORE ILUMINAÇÃO LTDA (EVOLED)",
        "INTERLIGHT SISTEMAS DE ILUMINAÇÃO",
        "CLICK ILUMINAÇÃO LTDA (ILUMINAR)",
        "STELLA IMPORTAÇÃO E EXPORTAÇÃO DE LUMINÁRIAS LTDA",
    ],
    "diretriz_uso": (
        "Ao enviar ficha cadastral a um novo fornecedor ou cliente, identificar previamente "
        "qual razão social deve ser utilizada na operação (regime tributário, tipo de nota e "
        "enquadramento fiscal aplicável). Endereço, contatos, banco e fornecedores permanecem "
        "constantes entre as três empresas."
    ),
}

RAZOES_SOCIAIS = [
    dict(
        canonical_name="FOCO ILUMINAÇÃO EIRELI",
        metadata={
            "cnpj": "24.090.967/0001-70",
            "inscricao_estadual": "797.184.330.116",
            "inscricao_municipal": "20037021",
            "conta_corrente_bradesco_ag_3427": "415646-3",
        },
    ),
    dict(
        canonical_name="ISLIGHT COMÉRCIO E SERVIÇOS DE ILUMINAÇÃO LTDA",
        metadata={
            "cnpj": "21.585.885/0001-08",
            "inscricao_estadual": "797.098.390.118",
            "inscricao_municipal": "20026686",
            "conta_corrente_bradesco_ag_3427": "417778-9",
        },
    ),
    dict(
        canonical_name="MANOELLA ZAUITH LEITE LOPES ME",
        metadata={
            "cnpj": "11.258.465/0001-63",
            "inscricao_estadual": "582.827.840.118",
            "inscricao_municipal": "13879101",
            "conta_corrente_bradesco_ag_3427": "412999-7",
        },
    ),
]

FORNECEDORES_INSTITUCIONAIS = [
    dict(canonical_name="ACEND ILUMINAÇÃO LTDA ME", metadata={"cidade": "Monte Azul Paulista/SP", "telefone": "(17) 3361-9595"}),
    dict(canonical_name="EVOSTORE ILUMINAÇÃO LTDA (EVOLED)", metadata={"cidade": "Catanduva/SP", "telefone": "(17) 3572-9898"}),
    dict(canonical_name="INTERLIGHT SISTEMAS DE ILUMINAÇÃO", metadata={"cidade": "Itapevi/SP", "telefone": "(11) 4789-9966"}),
    dict(canonical_name="CLICK ILUMINAÇÃO LTDA (ILUMINAR)", metadata={"cidade": "Nova Lima/MG", "telefone": "(31) 3589-1401"}),
    dict(canonical_name="STELLA IMPORTAÇÃO E EXPORTAÇÃO DE LUMINÁRIAS LTDA", metadata={"cidade": "Itajaí/SC", "telefone": "(51) 3529-7044"}),
]

FORNECEDORES_COMISSAO = [
    dict(
        canonical_name="La Lamp",
        status="descontinuado",
        metadata={"observacao": "Não trabalharemos mais com luminárias La Lamp — vender apenas itens presentes no estoque físico."},
    ),
    dict(
        canonical_name="Tensoflex",
        metadata={"observacao": "Lonas. Podemos trabalhar com lonas da Tensoflex e da Dressall, avaliar conforme projeto e não criar concorrência entre parceiros."},
    ),
    dict(
        canonical_name="Dressall",
        metadata={
            "comissao_lucenera_pct": 20,
            "comissao_arquiteto_pct": 10,
            "observacao": "Lonas — passou no teste de qualidade de lonas, de acordo com Filippo. Avaliar conforme projeto junto com a Tensoflex, sem criar concorrência entre parceiros.",
        },
    ),
    dict(
        canonical_name="Tensil",
        status="em_teste",
        metadata={"observacao": "Empresa nova de lonas, ainda em fase de testes — aguardar para saber se trabalharemos com eles ou não."},
    ),
    dict(
        canonical_name="Fasa",
        metadata={
            "comissao_lucenera_pct": 20,
            "comissao_arquiteto_pct": 5,
            "observacao": "O pagamento de RT da Fasa para arquitetos parceiros é feito diretamente da Fasa para o arquiteto. O arquiteto precisa ser indicado no momento do orçamento e os dados enviados no fechamento do pedido.",
        },
    ),
    dict(canonical_name="Lumini", metadata={"comissao_lucenera_pct": 20, "comissao_arquiteto_pct": 10}),
    dict(canonical_name="Adriana Yazbek", metadata={"comissao_lucenera_pct": 15, "comissao_arquiteto_pct": 10}),
    dict(
        canonical_name="Figueiredo Nunes",
        metadata={
            "comissao_lucenera_pct": 20,
            "comissao_arquiteto_pct": 5,
            "observacao": "Considerar valor com IPI + 3,5% no dólar + arredondamento (ver regra de câmbio em knowledge_items).",
        },
    ),
    dict(canonical_name="FAS", metadata={"comissao_lucenera_pct": 10, "comissao_arquiteto_pct": 5}),
    dict(
        canonical_name="OEG",
        metadata={
            "comissao_lucenera_pct": 20,
            "comissao_arquiteto_pct": 10,
            "observacao": "O valor para o cliente final fica mais caro em relação ao da Figueiredo Nunes.",
        },
    ),
    dict(canonical_name="Soneres", metadata={"comissao_lucenera_pct": 10, "comissao_arquiteto_pct": 0, "observacao": "Sem arquiteto."}),
    dict(canonical_name="Lightsource", metadata={"comissao_lucenera_pct": 30, "comissao_arquiteto_pct": 0, "observacao": "Sem arquiteto."}),
]


def build_entities():
    entities = [
        dict(
            entity_type="empresa_grupo",
            canonical_name="Lucenera Atelier da Luz",
            domain="institucional",
            short_description="Nome fantasia e estrutura operacional unificada das 3 razões sociais do grupo Lucenera.",
            metadata=GRUPO_METADATA,
        )
    ]
    for r in RAZOES_SOCIAIS:
        entities.append(
            dict(
                entity_type="razao_social",
                canonical_name=r["canonical_name"],
                domain="institucional",
                short_description="Razão social do grupo Lucenera Atelier da Luz.",
                metadata=r["metadata"],
            )
        )
    for f in FORNECEDORES_INSTITUCIONAIS:
        entities.append(
            dict(
                entity_type="fornecedor",
                canonical_name=f["canonical_name"],
                domain="institucional",
                short_description="Fornecedor institucional (lista de referência do cadastro Lucenera).",
                metadata=f["metadata"],
            )
        )
    for f in FORNECEDORES_COMISSAO:
        entities.append(
            dict(
                entity_type="fornecedor",
                canonical_name=f["canonical_name"],
                domain="comercial",
                status=f.get("status"),
                short_description="Fornecedor com regra de comissionamento em venda direta/RT de arquiteto.",
                metadata=f["metadata"],
            )
        )
    return entities


ENTITIES = build_entities()

RELATIONS = [
    dict(source_name=r["canonical_name"], relation_type="parte_de", target_name="Lucenera Atelier da Luz")
    for r in RAZOES_SOCIAIS
]


# ---------------------------------------------------------------------------


def existing_knowledge_titles(cur):
    cur.execute(
        "select title from memoria.knowledge_items where owner_id = %s and metadata->>'import_batch' = %s",
        (OWNER_ID, IMPORT_BATCH),
    )
    return {r[0] for r in cur.fetchall()}


def existing_source_titles(cur):
    cur.execute(
        "select title from memoria.sources where owner_id = %s and metadata->>'import_batch' = %s",
        (OWNER_ID, IMPORT_BATCH),
    )
    return {r[0] for r in cur.fetchall()}


def existing_entity_names(cur):
    cur.execute(
        "select canonical_name from memoria.entities where owner_id = %s and metadata->>'import_batch' = %s",
        (OWNER_ID, IMPORT_BATCH),
    )
    return {r[0] for r in cur.fetchall()}


def insert_knowledge_items(cur):
    existing = existing_knowledge_titles(cur)
    inserted = 0
    for item in KNOWLEDGE_ITEMS:
        if item["title"] in existing:
            continue
        cur.execute(
            """
            insert into memoria.knowledge_items
                (owner_id, knowledge_type, title, summary, content, domain, subcategory,
                 status, confidence, visibility, source_mode, metadata)
            values (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'company', 'personal', %s)
            """,
            (
                OWNER_ID,
                item["knowledge_type"],
                item["title"],
                item["summary"],
                item["content"],
                item["domain"],
                item["subcategory"],
                item.get("status", "approved"),
                item.get("confidence", 90),
                meta(),
            ),
        )
        inserted += 1
    return inserted


def insert_sources(cur):
    existing = existing_source_titles(cur)
    inserted = 0
    for s in SOURCES:
        if s["title"] in existing:
            continue
        cur.execute(
            """
            insert into memoria.sources (owner_id, source_type, title, url, domain, notes, visibility, metadata)
            values (%s, %s, %s, %s, %s, %s, 'company', %s)
            """,
            (OWNER_ID, s["source_type"], s["title"], s["url"], s["domain"], s["notes"], meta()),
        )
        inserted += 1
    return inserted


def insert_entities(cur):
    existing = existing_entity_names(cur)
    inserted = 0
    for e in ENTITIES:
        if e["canonical_name"] in existing:
            continue
        cur.execute(
            """
            insert into memoria.entities
                (owner_id, entity_type, canonical_name, domain, short_description, status,
                 visibility, metadata)
            values (%s, %s, %s, %s, %s, %s, 'company', %s)
            """,
            (
                OWNER_ID,
                e["entity_type"],
                e["canonical_name"],
                e["domain"],
                e["short_description"],
                e.get("status") or "active",
                json.dumps(dict(BASE_META, **e["metadata"]), ensure_ascii=False),
            ),
        )
        inserted += 1
    return inserted


def insert_relations(cur):
    inserted = 0
    for rel in RELATIONS:
        cur.execute(
            "select id from memoria.entities where owner_id = %s and canonical_name = %s",
            (OWNER_ID, rel["source_name"]),
        )
        src = cur.fetchone()
        cur.execute(
            "select id from memoria.entities where owner_id = %s and canonical_name = %s",
            (OWNER_ID, rel["target_name"]),
        )
        tgt = cur.fetchone()
        if not src or not tgt:
            print(f"  [aviso] relação pulada, entidade não encontrada: {rel}")
            continue
        cur.execute(
            """
            select 1 from memoria.relations
            where owner_id = %s and source_type = 'entity' and source_id = %s
              and target_type = 'entity' and target_id = %s and relation_type = %s
            """,
            (OWNER_ID, src[0], tgt[0], rel["relation_type"]),
        )
        if cur.fetchone():
            continue
        cur.execute(
            """
            insert into memoria.relations
                (owner_id, source_type, source_id, relation_type, target_type, target_id, confidence)
            values (%s, 'entity', %s, %s, 'entity', %s, 100)
            """,
            (OWNER_ID, src[0], rel["relation_type"], tgt[0]),
        )
        inserted += 1
    return inserted


def mark_original_upload_imported(cur):
    cur.execute(
        """
        update memoria.files
           set processing_status = 'approved',
               processed_at = now(),
               extracted_text = %s
         where id = %s
        """,
        (
            f"Conteúdo transcrito manualmente para knowledge_items/entities/sources "
            f"(import_batch={IMPORT_BATCH}) — ver scripts/importar_memoria_base_conhecimento.py.",
            ORIGEM_FILE_ID,
        ),
    )
    cur.execute(
        "update memoria.inbox_items set metadata = metadata || %s::jsonb where id = %s",
        (json.dumps({"import_batch": IMPORT_BATCH}), ORIGEM_INBOX_ID),
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Roda tudo dentro de uma transação e dá ROLLBACK no final.")
    args = parser.parse_args()

    if not SUPABASE_DB_URL:
        raise RuntimeError("Configure SUPABASE_DB_URL no .env da raiz do repositório.")

    conn = psycopg2.connect(SUPABASE_DB_URL)
    conn.autocommit = False
    try:
        with conn.cursor() as cur:
            n_know = insert_knowledge_items(cur)
            n_src = insert_sources(cur)
            n_ent = insert_entities(cur)
            n_rel = insert_relations(cur)
            mark_original_upload_imported(cur)

            print(f"knowledge_items inseridos: {n_know} (de {len(KNOWLEDGE_ITEMS)} definidos)")
            print(f"sources inseridos:         {n_src} (de {len(SOURCES)} definidos)")
            print(f"entities inseridos:        {n_ent} (de {len(ENTITIES)} definidos)")
            print(f"relations inseridos:       {n_rel} (de {len(RELATIONS)} definidos)")

            if args.dry_run:
                conn.rollback()
                print("\n[DRY-RUN] Nada foi salvo (ROLLBACK).")
            else:
                conn.commit()
                print("\nCOMMIT feito. Dados gravados no schema memoria.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
