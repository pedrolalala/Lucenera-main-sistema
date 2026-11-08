# Guia: enviar codigo local para o GitHub

Passo a passo para publicar um projeto local em um repositorio do GitHub.

## 1. Inicializar o repositorio local

Se o projeto ainda nao for um repositorio Git:

```bash
cd /caminho/do/seu/projeto
git init
```

Verifique qual branch foi criada (`main` ou `master`) — o nome e usado no passo 5:

```bash
git branch --show-current
```

## 2. Adicionar arquivos e fazer o primeiro commit

```bash
git add .
git commit -m "Primeiro commit"
```

O ponto depois de `git add` e obrigatorio. `git add` sozinho nao adiciona nada e o commit
sai vazio.

Antes de commitar, confira o que vai entrar:

```bash
git status
```

## 3. Criar o repositorio no GitHub

No GitHub: **New repository** → nome → visibilidade → **Create repository**.
Nao marque "Add a README" se o projeto local ja tiver arquivos, para evitar conflito no
primeiro push.

## 4. Conectar o repositorio local ao remoto

```bash
git remote add origin https://github.com/SEU-USUARIO/SEU-REPOSITORIO.git
git remote -v
```

Se ja existir um remoto configurado, troque a URL em vez de adicionar outro:

```bash
git remote set-url origin https://github.com/SEU-USUARIO/SEU-REPOSITORIO.git
```

## 5. Enviar o codigo

```bash
git push -u origin main
```

Substitua `main` por `master` se a branch principal tiver esse nome. O `-u` liga a branch
local a remota, e nos proximos envios basta `git push`.

## 6. Autenticacao

O GitHub nao aceita mais senha de conta no terminal. Use uma das duas formas:

**Token de acesso pessoal (HTTPS)**

1. github.com/settings/tokens → **Generate new token (classic)**
2. Marque o escopo `repo`
3. No primeiro push, informe o token como senha (ou o usuario `x-access-token`)

Para nao digitar a cada push:

```bash
git config --global credential.helper store
```

**Chave SSH**

```bash
ssh-keygen -t ed25519 -C "seu-email@lucenera"
# adicione o conteudo de ~/.ssh/id_ed25519.pub em github.com/settings/keys
```

## 7. Atualizacoes futuras

```bash
git add .
git commit -m "Descricao da alteracao"
git push
```

## 8. Regras deste repositorio (Lucenera)

- **Nunca commitar `.env`.** Segredos reais ja vazaram por `.env.example` no passado; use
  sempre valores vazios ou de exemplo.
- **Nao commitar** `node_modules/`, `dist/`, `__pycache__/` nem arquivos acima de 100 MB.
- **Codigo de sistema nao mora aqui.** Vai no repositorio proprio do sistema. Este
  repositorio guarda o ponteiro do submodule, a SPEC, o changelog e o contexto.
- **Nunca commitar ponteiro de submodule para um commit que ainda nao foi enviado** ao
  GitHub do sistema. Se isso acontecer, ninguem mais consegue clonar aquele commit.
- Depois de qualquer alteracao, atualizar `CHANGELOG.md` e a documentacao afetada
  (ver `FLUXO_DE_TRABALHO.md`).

## Problemas comuns

| Mensagem | Causa | Solucao |
| --- | --- | --- |
| `could not read Username` | sem credencial no terminal | configurar token ou SSH (passo 6) |
| `Authentication failed` | token expirado ou sem escopo `repo` | gerar novo token |
| `rejected (fetch first)` | remoto tem commits novos | `git pull --rebase` e depois `git push` |
| `remote origin already exists` | remoto ja configurado | `git remote set-url origin <url>` |
| `src refspec main does not match any` | branch local tem outro nome | conferir com `git branch` e usar o nome certo |
