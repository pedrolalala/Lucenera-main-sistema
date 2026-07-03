# Ata de reunião

- Reunião: 06. Lucenera (Filippo) - 13.05.2026: Limpeza de dados e relacionamentos no Supabase
- Data: 2026-05-13
- Horário: 09:00
- Duração aproximada: 02:09:29
- Link tl;dv: https://tldv.io/app/meetings/6a0467ef097a350013b62060
- Fonte: transcrição e metadados retornados pela API do tl;dv.

## Assunto principal

Sessão técnica de saneamento de dados no Supabase: duplicidade de arquitetos/clientes, vínculo de projetos, canônicos, tabelas desnecessárias, contas a pagar/receber e necessidade de relações confiáveis.

## Participantes identificados

- Kimberly Prestes
- Filippo Giorgi
- Pedro / LAGHI Live

## Áreas envolvidas

- Dados/Supabase
- Projetos
- CRM
- Financeiro
- Estoque

## Ferramentas e sistemas citados

- Supabase
- SQL
- SharePoint
- Connect/Conecta
- Planilhas
- Views
- WhatsApp citado

## Contexto

- A reunião começou diretamente em dois pontos de Supabase: duplicidade de projetos/arquitetos e forma de corrigir relações.
- Filippo pediu uma abordagem manual, auditável e controlada, por receio de automações/IA bagunçarem dados.
- Pedro e Kimberly discutiram como conectar projetos aos contatos corretos.

## Problemas identificados

- Arquitetos/clientes aparecem duplicados com variações de nome.
- Projetos não estão vinculados ao arquiteto/responsável correto.
- Tabela de projetos não possui código de arquiteto suficiente para relação automática.
- Contas a pagar/receber não trazem nome fantasia/projeto, dificultando linkagem.
- Supabase possui tabelas automáticas/desnecessárias que poluem a manutenção.

## Procedimento discutido

- Escolher registro canônico para arquitetos/clientes.
- Linkar registros subsidiários ao principal quando necessário.
- Procurar projetos por nome/código e vincular manualmente ao contato correto.
- Validar contagem/projetos antes e depois de transformações.
- Criar regras/validações no banco para impedir novas inconsistências.

## Encaminhamentos

- Implementar limpeza gradual.
- Relacionar projetos, clientes, arquitetos e transações financeiras.
- Pensar fluxo operacional quando projeto é fechado, incluindo orçamento, parcelas e estoque.

## Decisões

- Preferir correção manual/controlada em pontos críticos de dados.
- Usar registros canônicos para contatos duplicados.
- Validar relações por código e contagem de projetos antes/depois.
- Limpar ou esconder tabelas que não são usadas.

## Pendências / próximos passos

- Conferir arquitetos duplicados, começando por casos como André Calil.
- Relacionar projetos sem arquiteto/responsável correto.
- Definir regra de linkagem entre contas a pagar/receber e projeto.
- Adicionar dados faltantes como nome fantasia/código de projeto onde necessário.
- Documentar fluxo de projeto fechado: orçamento, parcelas, estoque e financeiro.
