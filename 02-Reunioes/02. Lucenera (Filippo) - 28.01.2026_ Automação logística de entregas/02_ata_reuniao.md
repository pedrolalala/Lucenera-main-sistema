# Ata de reunião

- Reunião: 02. Lucenera (Filippo) - 28.01.2026: Automação logística de entregas
- Data: 2026-01-28
- Horário: 15:10
- Duração aproximada: 01:19:47
- Link tl;dv: https://tldv.io/app/meetings/697a512613f5310013e3b29e
- Fonte: transcrição e metadados retornados pela API do tl;dv.

## Assunto principal

Desenho mais detalhado do processo de logística e entrega, com separação de materiais, criação de rotas, confirmação via WhatsApp/Teams, perfis de usuários e uso de IA/prompts para estruturar o sistema.

## Participantes identificados

- Kimberly Prestes
- Filippo Giorgi
- Pedro / LAGHI Live

## Áreas envolvidas

- Logística
- Estoque
- Equipes de entrega
- Obra
- IA/Automação

## Ferramentas e sistemas citados

- WhatsApp
- Teams
- Supabase
- Logo/Expert citado
- Gira citado
- n8n citado indiretamente
- Banco de dados

## Contexto

- A conversa retomou a automação de entregas citada na reunião anterior.
- Filippo enquadrou o processo como uma automação em várias fases, separada do chatbot geral.
- Pedro detalhou que informações de WhatsApp já eram salvas no Supabase.

## Processo operacional discutido

- Separação dos materiais pelo estoque, com Mateus como pessoa-chave na operação.
- Criação de rotas a partir dos pedidos/endereço/obra.
- Confirmação de entrega com responsáveis e comunicação via WhatsApp/Teams.
- Necessidade de registrar status e evidência de entrega.

## Dores principais

- Informações dispersas em WhatsApp, mensagens e planilhas.
- Reentrada manual de dados em vários sistemas.
- Falta de rastreabilidade em tempo real.
- Custo e complexidade de ferramentas externas.
- Dependência de telefone pessoal/equipe para automações.

## Encaminhamentos

- Estruturar o sistema por fases: separação, rotas e mensagens de confirmação.
- Criar perfis de usuário como separador, gerente de logística e entregador.
- Usar um Expert/prompt estruturado para definir intenções, entradas e regras de cada etapa.

## Decisões

- Tratar o fluxo de entrega como processo em três fases: separação, rota e confirmação/mensagem.
- Começar de forma gradual e iterativa, com Pedro implementando e Kimberly apoiando.
- Considerar perfis de usuário com permissões diferentes.

## Pendências / próximos passos

- Definir campos mínimos para cada pedido/entrega: obra, código, endereço, responsável, telefone, itens e urgência.
- Definir critérios de otimização de rota: horários, urgência, capacidade e confirmação.
- Separar o que fica em Teams, WhatsApp e banco de dados.
