# ply

`ply` é um ledger de tarefas **token-frugal**, **observável** e **paralelo por pull**:
o estado do trabalho vive em arquivos Markdown e o agente LLM consome apenas a
saída mínima de cada comando. O script é bash puro + coreutils — **nunca chama
LLM e nunca faz rede**; toda decisão de gate é determinística.

## Instalação num repo

No diretório do projeto (repo **público** no GitHub):

```bash
curl -fsSL https://raw.githubusercontent.com/adrianomirandaa/ply/master/install.sh | bash
```

Repo **privado** — use token (`PLY_GITHUB_TOKEN` ou `GITHUB_TOKEN`) ou clone local:

```bash
export PLY_GITHUB_TOKEN=ghp_…   # fine-grained ou classic, escopo repo
curl -fsSL \
  -H "Authorization: Bearer $PLY_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw+json" \
  "https://api.github.com/repos/adrianomirandaa/ply/contents/install.sh?ref=master" | bash
```

O `install.sh` remoto detecta o token e baixa o tarball via API do GitHub. Com `gh` autenticado, o token é inferido automaticamente.

Se você já clonou este repositório:

```bash
./install.sh /caminho/do/seu-repo   # default: cwd
```

Os dois caminhos copiam `ply`, rodam `./ply init --kit …` (ledger em `.ply/` + skill
`ply-flow` + bloco marcado em `AGENTS.md` na raiz, com `CLAUDE.md` como symlink).
Depois edite `.ply/config` e ajuste `TEST_CMD` para o comando de teste do projeto
(o campo `test:` de cada task vira argumento dele).

Reinstalar / atualizar kit: rode o mesmo comando de novo (idempotente; o bloco
entre `<!-- ply:start -->` e `<!-- ply:end -->` em `AGENTS.md` é atualizado in-place).

## Primeiros 5 minutos

```bash
export PLY_AS=voce                       # identidade do agente na sessão
./ply spec "Autenticação"                # spec enxuta (1 página)
./ply new "Login por senha" --spec 001   # cria a task 001
id=$(./ply next)                         # próxima task desbloqueada
./ply claim "$id" --as voce              # lock atômico (pull)
./ply brief "$id"                        # o contrato: leia SÓ isto
./ply start "$id" --as voce              # todo → doing
# ... TDD: teste do AC (RED) → código mínimo (GREEN) → refatore ...
./ply done "$id" --as voce               # gate: arquivos existem + teste verde
./ply metrics                            # custo proxy (bytes) por task
```

## A economia de token

| Camada | Quando entra no contexto | Custo |
|--------|--------------------------|-------|
| `AGENTS.md` (canônico) / `CLAUDE.md` (symlink) | sempre (é o processo) | ~400 tokens, teto travado por teste |
| `ply brief <id>` | 1 task por vez, sob demanda | pequeno; só o contrato da task |
| `.ply/specs/*.md` | só se o AC do brief não bastar | opcional |
| `.ply/journal/*.md`, `.ply/tasks/LESSONS.md` | nunca no loop; leitura humana / skim inicial | fora do caminho quente |

O agente **nunca** lê o backlog inteiro: puxa só a task da vez. `./ply metrics`
mede o proxy (bytes servidos por task, em `.ply/usage.tsv`) e, com `<id>`, o
custo real somando os tokens dos transcripts do Claude Code na janela `start→done`.

## Paralelismo

Rode N sessões com `PLY_AS` distintos. Cada uma faz `./ply next` (pull) e
`./ply claim` (lock atômico via `mkdir`): quem perde a corrida simplesmente pega
a próxima. Tasks que declaram os mesmos `files:` **nunca** são servidas em
paralelo — é o veto por overlap do `ply next`. Convenção recomendada: 1 worktree
git por agente.

```bash
git worktree add ../repo-ag2 -b ag2 && (cd ../repo-ag2 && export PLY_AS=ag2 && ./ply next)
```
