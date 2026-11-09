---
titulo: "SPEC-266 — Permissões da Débora (Cadastro, Compras, Entregas, CRM só Fornecedores, Produção, Garantia, Solicitações)"
status: migration 319 APLICADA em SP e CRM no ar (09/11)
data_ultima_modificacao: 2026-11-09
sistemas_envolvidos:
  - Banco (papeis, papel_permissoes, modulos, usuario_papeis)
  - CRM (lucenera-crm-3bd29): use-auth.tsx, Layout.tsx
---

# SPEC-266 — O que a Débora pode e não pode

## Decisão do usuário (09/11)
| Sistema | Débora |
|---|---|
| Cadastro / Consulta de peças | criar, editar, visualizar (sem excluir) |
| Necessidade de Compra | tudo |
| Sistema de Entregas | só visualizar |
| CRM | só a aba Fornecedores: ver, adicionar e editar fornecedor |
| Controle de Produção / Garantia | visualizar (como todos) |
| Central de Solicitações | criar e visualizar (padrão) |
| Venda Parcial | mantém como está (decisão do usuário) |

## Como fica
- Papel novo `compras_cadastro_fornecedores` substitui `funcionario` + `compras_e_entregas` só para ela (`usuarios.role` continua `funcionario`).
  O papel `funcionario` dava TOTAL em CRM e Entregas; era isso que sobrava.
- CRM: novo módulo `crm.fornecedores`. Permissão só do módulo não abre o resto (RLS de projetos e das abas de cliente/arquiteto/engenheiro
  continua exigindo `crm` completo). Criar/editar fornecedor segue a Necessidade de Compra (políticas `spec069_contatos_*` olham o tipo do contato).
- CRM (tela): `use-auth` checa também o módulo `fornecedores`; `Layout` mostra só "Fornecedores" no menu e redireciona qualquer outra rota para ela.

## Limite conhecido
A leitura de `contatos` e `projetos` é `SELECT true` para qualquer logado (várias políticas antigas). Ocultar as outras abas é da TELA; quem
chamar a API direto ainda consegue LER clientes/projetos. Escrita fica bloqueada pelo banco. Fechar a leitura exige revisar as políticas de
SELECT de contatos/projetos (usadas por todos os sistemas) — não feito.

## Checklist
- [x] Dry-run da migration 319 (matriz antes × depois por sistema/ação) em ROLLBACK
- [x] CRM: código local (tsc sem erro novo)
- [x] Aplicar a 319
- [x] CRM: commit 166e719, deploy 6d4567c6 (crm-lucenera) e ponteiro
- [ ] Débora conferir cada sistema
