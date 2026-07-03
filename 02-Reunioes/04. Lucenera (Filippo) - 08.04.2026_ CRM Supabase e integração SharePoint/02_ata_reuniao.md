# Ata de reunião

- Reunião: 04. Lucenera (Filippo) - 08.04.2026: CRM Supabase e integração SharePoint
- Data: 2026-04-08
- Horário: 11:30
- Duração aproximada: 01:09:25
- Link tl;dv: https://tldv.io/app/meetings/69d66666a5e8fc0013fa5517
- Fonte: transcrição e metadados retornados pela API do tl;dv.

## Assunto principal

Sessão técnica sobre organização do Skip Gold, CRM, estrutura relacional no Supabase e sincronização com SharePoint/Planner, com alerta para mapear dados antes de deixar ferramentas de IA criarem banco e código.

## Participantes identificados

- Kimberly Prestes
- Filippo Giorgi
- Pedro / LAGHI Live

## Áreas envolvidas

- CRM/Comercial
- Projetos
- TI/Automação
- Dados/Supabase
- Microsoft/SharePoint

## Ferramentas e sistemas citados

- Skip Gold
- Supabase
- SharePoint
- Planner
- Teams
- Edge Functions
- Webhooks
- n8n
- Opus/IA

## Contexto

- A reunião iniciou com orientação sobre organização/convites do Skip Gold e uso de conta corporativa.
- Pedro relatou tentativas frustradas de sincronizar SharePoint com o sistema/Skip.
- A empresa queria centralizar ferramentas e fazer o CRM conversar com processos existentes.

## Processo discutido

- CRM cobre a parte de vendas e, quando o negócio fecha, deve acionar o fluxo de projeto.
- Registro de projeto deveria sincronizar com SharePoint, pastas e Planner já usados pela equipe.
- Planilhas existentes de organização de projetos/projetos fechados foram importadas ao Supabase, mas sem relações adequadas.

## Problemas identificados

- Tabelas sem relacionamento causam duplicidade e lentidão.
- Alterações manuais no Supabase sem documentação deixam o Skip/IA sem contexto.
- A equipe precisa entender chaves, relacionamentos, migrations, Edge Functions e views de forma mais simples.
- Limite de membros/contas no Skip criou problema operacional.

## Encaminhamentos

- Mapear em documento todos os dados necessários antes de criar/alterar banco.
- Usar IA para analisar esquema SQL e propor estrutura relacional.
- Avaliar webhooks/Edge Functions e, quando necessário, n8n para integrar APIs complexas.
- Criar documentação visual dos processos, prompts e workflows por pessoa.

## Decisões

- Não depender apenas de criação livre pelo Skip; primeiro mapear dados e estrutura.
- Manter SharePoint/Microsoft enquanto as automações existentes ainda forem úteis.
- Usar Supabase como base relacional e o Skip como interface/código conectado.

## Pendências / próximos passos

- Vinícius configurar convites/organização do Skip.
- Enviar esquema SQL do Supabase para análise.
- Solicitar aumento de limite de membros e migração do CRM para conta corporativa.
- Documentar processos, sistemas e prompts usados por cada pessoa.
