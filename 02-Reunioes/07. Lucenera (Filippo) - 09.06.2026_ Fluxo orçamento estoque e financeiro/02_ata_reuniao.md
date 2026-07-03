# Ata de reunião

- Reunião: 07. Lucenera (Filippo) - 09.06.2026: Fluxo orçamento estoque e financeiro
- Data: 2026-06-09
- Horário: 14:00
- Duração aproximada: 01:19:29
- Link tl;dv: https://tldv.io/app/meetings/6a2846baebc00200127220aa
- Fonte: transcrição e metadados retornados pela API do tl;dv.

## Assunto principal

Reunião sobre fluxo completo de orçamento aprovado, reserva/baixa de estoque, necessidade de compra, financeiro e estrutura correta no Supabase antes de criar interfaces no Skip.

## Participantes identificados

- Kimberly Prestes
- Filippo Giorgi
- Pedro / LAGHI Live

## Áreas envolvidas

- Orçamentos
- Estoque
- Compras
- Financeiro
- Supabase
- Projetos
- CAD/AutoCAD

## Ferramentas e sistemas citados

- Supabase
- Skip
- VS Code
- Miro
- SQL
- Views
- Connecta
- Ubiqua
- AutoCAD
- Plugin/skill de fluxo citado

## Contexto

- A reunião começou com a hipótese de orçamento aprovado disparando estoque e financeiro.
- Pedro queria desenhar fluxos por atividade para Felipe visualizar melhor.
- Filippo reforçou a necessidade de dominar o Supabase antes de avançar só por interface/vibe coding.

## Fluxo operacional discutido

- Orçamento aprovado deve retirar/reservar peça de estoque.
- Se não houver peça em estoque, financeiro/compras deve ser avisado para compra.
- Banco precisa separar produto de estoque: produto é o item/cadastro; estoque é quantidade/disponibilidade.
- Projeto, orçamento, itens, estoque e necessidades de compra precisam estar relacionados.

## Problemas e riscos

- Skip pode criar padrões incorretos se não for instruído a usar tabelas existentes.
- Dashboard não estava puxando 100% das informações.
- Nuances operacionais de negociação, aprovação e compra ainda não estavam totalmente documentadas.
- Equipe interna ainda estava aprendendo Supabase.

## Encaminhamentos

- Criar diagramas no Miro do caminho da informação.
- Incluir Vinícius e secretários para validar regras de preço, imposto, negociação e estoque.
- Finalizar normalização de produtos, estoque, orçamentos, projetos, itens e necessidades de compra.
- Usar instruções explícitas ao Skip para não criar tabelas novas indevidas.

## Decisões

- Dominar e normalizar o Supabase antes de avançar nas interfaces.
- Separar tabela de produtos da tabela de estoque.
- Documentar o fluxo orçamento-estoque-financeiro visualmente.
- Incluir Vinícius nas próximas validações.

## Pendências / próximos passos

- Criar Miro/diagrama do fluxo por atividade.
- Validar regras de preço, imposto e negociação com Vinícius.
- Validar processos de estoque e aprovações com equipe operacional/secretários.
- Ajustar dashboard para puxar todas as informações corretas.
- Finalizar relações entre projetos, orçamentos, itens, estoque e necessidades de compra.
