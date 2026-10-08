---
titulo: "SPEC-187 — Contas novas da equipe + página Minha senha na Central"
status: concluído
data_ultima_modificacao: 2026-10-08
sistemas_envolvidos:
  - Central Lucenera (central-lucenera-dashboard-1c9ba, Skip 37750)
  - Supabase Auth / usuarios
---

# SPEC-187 — Contas novas da equipe + página Minha senha na Central

## Checklist de Ação

- [x] Criar 14 contas com a senha padrão via `criar_usuario` (RPC oficial, chamada como admin), papel legado `funcionario`.
- [x] Central: página `/minha-conta` ("Minha senha") + botão no cabeçalho para qualquer usuário logado.
- [x] Publicar a Central.

### Passos manuais do usuário

- [ ] Marcar em Central › Administração › Acesso a Sistemas o que cada conta nova vê (SPEC-183: sem marcação, a pessoa não vê nenhum sistema).
- [ ] Pedir a cada pessoa que troque a senha padrão em "Minha senha".

## Decisões aprovadas (2026-10-08)

- Senha padrão `Lucenera2026!` para as contas novas.
- Terezinha **não** recebe conta (saiu da empresa).
- Marina, Thairine, Mariane e Filippo já tinham conta: senha mantida.

## Definição

- Contas criadas: rafaela@, alexandrecosta490@gmail.com, giovana@, isabella@, ketlyn@, giovanna.nori@, tricia@, thais@, murillo@, helena@, adriana@, moara@, vitoria@, matheus@ (domínio lucenera.com.br salvo indicação).
- "Minha senha": confere a senha atual (`signInWithPassword`) antes de `updateUser`; mínimo 8 caracteres; nova ≠ atual; confirmação igual.

## Realizado

### 2026-10-08

- 14 contas criadas numa transação; login conferido no Auth (rafaela, alexandre).
- Central Skip 37750 v0.0.49 (`8ea27a6`) publicada; textos no bundle; troca de senha testada pela API (trocou, senha antiga deixou de entrar, voltou para a padrão).

## Pendências

- [ ] Contas novas ainda não vinculadas a `funcionarios.usuario_id` (autoatendimento do RH), se for desejado.
