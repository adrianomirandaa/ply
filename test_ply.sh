#!/usr/bin/env bash
# test_ply.sh — testes do ply. bash puro, sem framework. Roda em <5s.
set -uo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)/ply"
REPO="$(cd "$(dirname "$0")" && pwd)"
KIT="$REPO/kit"
pass=0; fail=0
t()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $d"; fi; }
tf() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then fail=$((fail+1)); echo "FAIL(esperava erro): $d"; else pass=$((pass+1)); fi; }
sandbox() { S=$(mktemp -d); cp "$SRC" "$S/ply"; (cd "$S" && ./ply init --kit "$KIT" >/dev/null); }

# --- Task 1: init ---
sandbox
t "init cria dirs"            test -d "$S/tasks" -a -d "$S/specs" -a -d "$S/journal" -a -d "$S/.ply/claims"
t "init cria config"          test -f "$S/.ply/config"
t "init cria template task"   test -f "$S/tasks/_template.md"
t "init cria template spec"   test -f "$S/specs/_template.md"
t "init é idempotente"        bash -c "cd '$S' && ./ply init --kit '$KIT'"

# --- Task 2: new / spec ---
sandbox
t "new cria 001"        bash -c "cd '$S' && ./ply new 'Parser XML' && test -f tasks/001-parser-xml.md"
t "new incrementa id"   bash -c "cd '$S' && ./ply new 'Outra' && test -f tasks/002-outra.md"
t "new grava título"    bash -c "cd '$S' && grep -q '^title: Parser XML' tasks/001-parser-xml.md"
t "new aceita --spec/--dep" bash -c "cd '$S' && ./ply new 'Com deps' --spec 001 --dep '001 002' && grep -q '^depends: 001 002' tasks/003-com-deps.md && grep -q '^spec: 001' tasks/003-com-deps.md"
t "spec cria specs/001"  bash -c "cd '$S' && ./ply spec 'Autenticação' && ls specs/001-*.md"
tf "new --spec sem valor falha limpo" bash -c "cd '$S' && ./ply new 'X' --spec 2>/dev/null"
tf "id corrompido falha com mensagem" bash -c "cd '$S' && printf -- '---\nid: XYZ\ntitle: c\nstatus: todo\n---\n' > tasks/009-corrompida.md && ./ply new 'Y' 2>/dev/null; r=\$?; rm -f tasks/009-corrompida.md; exit \$r"

# --- Task 3: status ---
sandbox
t "status vazio roda"   bash -c "cd '$S' && ./ply status | grep -q 'todo:0'"
t "status conta todo"   bash -c "cd '$S' && ./ply new 'A' >/dev/null && ./ply new 'B' >/dev/null && ./ply status | grep -q 'todo:2'"
t "status marca blocked" bash -c "cd '$S' && ./ply new 'C' --dep '009' >/dev/null && ./ply status | grep -q 'blocked:1'"

# --- Task 4: claim / release ---
sandbox
bash -c "cd '$S' && ./ply new 'Alvo' >/dev/null"
tf "claim exige --as"      bash -c "cd '$S' && ./ply claim 001"
t  "claim com --as"        bash -c "cd '$S' && ./ply claim 001 --as a1"
tf "claim duplo falha"     bash -c "cd '$S' && ./ply claim 001 --as a2"
t  "release do dono"       bash -c "cd '$S' && ./ply release 001 --as a1"
t  "corrida: 1 vence"      bash -c "cd '$S'
  ( ./ply claim 001 --as r1 >/dev/null 2>&1; echo \$? > r1 ) &
  ( ./ply claim 001 --as r2 >/dev/null 2>&1; echo \$? > r2 ) &
  wait; s=\"\$(cat r1)\$(cat r2)\"; [ \"\$s\" = 01 ] || [ \"\$s\" = 10 ]"
t  "release humano (sem --as)" bash -c "cd '$S' && ./ply release 001"

# --- Task 5: next ---
sandbox
bash -c "cd '$S' &&
  ./ply new 'Base' >/dev/null &&
  ./ply new 'Dependente' --dep '001' >/dev/null &&
  ./ply new 'Livre' >/dev/null"
t  "next devolve 001"      bash -c "cd '$S' && [ \"\$(./ply next)\" = 001 ]"
t  "next pula claimed"     bash -c "cd '$S' && ./ply claim 001 --as a1 >/dev/null && [ \"\$(./ply next)\" = 003 ]"
# overlap: 003 e 004 compartilham arquivo → com 003 claimed, next pula 004
bash -c "cd '$S' && ./ply release 001 >/dev/null 2>&1; true"
bash -c "cd '$S' && ./ply new 'Colide' >/dev/null &&
  awk '{ if (\$0 ~ /^files:/) print \"files: src/x.py\"; else print }' tasks/003-livre.md > t3 && mv t3 tasks/003-livre.md &&
  awk '{ if (\$0 ~ /^files:/) print \"files: src/x.py\"; else print }' tasks/004-colide.md > t4 && mv t4 tasks/004-colide.md"
t  "veto por overlap"      bash -c "cd '$S' && ./ply claim 003 --as a1 >/dev/null && [ \"\$(./ply next)\" = 001 ]"
t  "NONE quando nada"      bash -c "cd '$S' && ./ply claim 001 --as a2 >/dev/null && [ \"\$(./ply next)\" = NONE ]"

# --- Task 6: brief + proxy ---
sandbox
bash -c "cd '$S' && ./ply new 'Com AC' >/dev/null"
t "brief mostra campos"   bash -c "cd '$S' && ./ply brief 001 | grep -q '^id:      001' && ./ply brief 001 | grep -q 'critério testável'"
t "brief registra usage"  bash -c "cd '$S' && test -f .ply/usage.tsv && awk -F'\t' '\$2==\"001\" && \$3==\"brief\" && \$4>0' .ply/usage.tsv | grep -q ."
t "next registra usage"   bash -c "cd '$S' && ./ply next >/dev/null && awk -F'\t' '\$3==\"next\"' .ply/usage.tsv | grep -q ."

# --- Task 7: start/check/done ---
sandbox
bash -c "cd '$S' && printf 'TEST_CMD=\"bash\"\n' > .ply/config && ./ply new 'Gate' >/dev/null &&
  awk '{ if (\$0 ~ /^files:/) print \"files: src/ok.sh\"; else if (\$0 ~ /^test:/) print \"test: t/run.sh\"; else print }' tasks/001-gate.md > t1 && mv t1 tasks/001-gate.md &&
  ./ply claim 001 --as a1 >/dev/null"
tf "start sem ownership"   bash -c "cd '$S' && ./ply start 001 --as intruso"
t  "start do dono"         bash -c "cd '$S' && ./ply start 001 --as a1 && grep -q '^status: doing' tasks/001-gate.md"
tf "check: arquivo fantasma" bash -c "cd '$S' && ./ply check 001"
tf "done não passa com gate vermelho" bash -c "cd '$S' && ./ply done 001 --as a1"
t  "check verde"           bash -c "cd '$S' && mkdir -p src t && echo true > src/ok.sh && echo 'exit 0' > t/run.sh && ./ply check 001"
t  "done fecha e libera"   bash -c "cd '$S' && ./ply done 001 --as a1 && grep -q '^status: done' tasks/001-gate.md && [ ! -d .ply/claims/001 ]"
t  "journal registrou"     bash -c "cd '$S' && grep -q 'done' journal/001.md && grep -q 'start' journal/001.md"

# --- Task 8: log / lesson / journal ---
sandbox
bash -c "cd '$S' && ./ply new 'Diário' >/dev/null && ./ply claim 001 --as a1 >/dev/null"
tf "log sem ownership"  bash -c "cd '$S' && ./ply log 001 --as outro 'x'"
t  "log do dono"        bash -c "cd '$S' && ./ply log 001 --as a1 'escolhi X porque Y' && grep -q 'escolhi X porque Y' journal/001.md"
t  "journal imprime"    bash -c "cd '$S' && ./ply journal 001 | grep -q 'escolhi X'"
t  "lesson appenda"     bash -c "cd '$S' && ./ply lesson 'PEM, não PFX' && grep -q 'PEM, não PFX' tasks/LESSONS.md"

# --- Task 9: fsck ---
sandbox
bash -c "cd '$S' && ./ply new 'A' >/dev/null && ./ply new 'B' --dep '001' >/dev/null"
t  "fsck OK em ledger são"  bash -c "cd '$S' && ./ply fsck"
tf "fsck pega dep fantasma" bash -c "cd '$S' && ./ply new 'C' --dep '099' >/dev/null && ./ply fsck"
tf "fsck pega ciclo"        bash -c "cd '$S' && rm tasks/003-*.md &&
  awk '{ if (\$0 ~ /^depends:/) print \"depends: 002\"; else print }' tasks/001-a.md > t && mv t tasks/001-a.md &&
  ./ply fsck"
tf "fsck pega claim órfão"  bash -c "cd '$S' && mkdir -p .ply/claims/077 && ./ply fsck"

# --- Task 10: metrics ---
sandbox
bash -c "cd '$S' && printf 'TEST_CMD=\"bash\"\n' > .ply/config && ./ply new 'Medida' >/dev/null &&
  ./ply claim 001 --as a1 >/dev/null && ./ply start 001 --as a1 >/dev/null &&
  mkdir -p fx && cat > fx/s1.jsonl <<'JEOF'
{\"timestamp\":\"2000-01-01T00:00:00.000Z\",\"message\":{\"usage\":{\"input_tokens\":10,\"output_tokens\":5,\"cache_read_input_tokens\":100}}}
{\"timestamp\":\"2099-01-01T00:00:00.000Z\",\"message\":{\"usage\":{\"input_tokens\":7,\"output_tokens\":3,\"cache_read_input_tokens\":50}}}
JEOF
  ./ply done 001 --as a1 >/dev/null 2>&1 || true"
# a task não tem files/test → done passa com AVISO; se falhar, força done p/ o teste:
bash -c "cd '$S' && grep -q '^status: done' tasks/001-medida.md || { awk '{ if (\$0 ~ /^status:/) print \"status: done\"; else print }' tasks/001-medida.md > t && mv t tasks/001-medida.md; echo \"- \$(date -u '+%FT%T') done a1 (gate PASS)\" >> journal/001.md; }"
bash -c "cd '$S' && awk '{ if (\$0 ~ / done /) print \"- 2100-01-01T00:00:00 done a1 (gate PASS)\"; else print }' journal/001.md > j && mv j journal/001.md"
t "metrics proxy roda"     bash -c "cd '$S' && ./ply metrics | grep -q 'proxy'"
t "metrics real filtra por janela" bash -c "cd '$S' && PLY_TRANSCRIPTS=fx ./ply metrics 001 | grep -q 'input:7 output:3 cache_read:50'"
# exit code: dir de transcripts sem *.jsonl não pode derrubar o comando (glob não-casado + pipefail)
t "metrics real: dir vazio → exit 0" bash -c "cd '$S' && mkdir -p fxempty && PLY_TRANSCRIPTS=fxempty ./ply metrics 001"

# --- init + kit ---
S=$(mktemp -d); cp "$SRC" "$S/ply"
tf "init sem kit falha" bash -c "cd '$S' && ./ply init"
t  "init --kit cria skill" bash -c "cd '$S' && ./ply init --kit '$KIT' >/dev/null && test -f .claude/skills/ply-flow/SKILL.md"
t  "init --kit escreve bloco CLAUDE" bash -c "cd '$S' && grep -q '<!-- ply:start -->' CLAUDE.md && grep -q '<!-- ply:end -->' CLAUDE.md && grep -q 'ply — processo' CLAUDE.md"
bash -c "cd '$S' && printf 'KEEPME\n' > CLAUDE.md && ./ply init --kit '$KIT' >/dev/null"
t  "init preserva texto fora do bloco" bash -c "cd '$S' && grep -q '^KEEPME$' CLAUDE.md && grep -q '<!-- ply:start -->' CLAUDE.md"
bash -c "cd '$S' && ./ply init --kit '$KIT' >/dev/null && c1=\$(grep -c '<!-- ply:start -->' CLAUDE.md) && echo mudou > kitfake 2>/dev/null; ./ply init --kit '$KIT' >/dev/null && c2=\$(grep -c '<!-- ply:start -->' CLAUDE.md) && [ \"\$c1\" = 1 ] && [ \"\$c2\" = 1 ]"
t  "init upsert não duplica marcadores" bash -c "cd '$S' && c=\$(grep -c '<!-- ply:start -->' CLAUDE.md) && [ \"\$c\" = 1 ]"
S=$(mktemp -d); cp "$SRC" "$S/ply"
bash -c "cd '$S' && printf 'BEFORE\n<!-- ply:start -->\nORPHAN\n' > CLAUDE.md && ./ply init --kit '$KIT' >/dev/null"
t  "init fecha bloco órfão e preserva texto" bash -c "cd '$S' && grep -q '^BEFORE$' CLAUDE.md && grep -q '<!-- ply:end -->' CLAUDE.md && grep -q '^ORPHAN$' CLAUDE.md && grep -q 'ply — processo' CLAUDE.md"

# auto-detect: ply clone tem kit/ ao lado do script? simular copiando kit para S
S2=$(mktemp -d); cp "$SRC" "$S2/ply"; cp -R "$KIT" "$S2/kit"
t  "init acha \$ROOT/kit" bash -c "cd '$S2' && ./ply init >/dev/null && test -f .claude/skills/ply-flow/SKILL.md"

# Task 11 checks de orçamento do kit (mantém; usa REPO)
t "kit completo"        test -f "$KIT/CLAUDE.md" -a -f "$KIT/skills/ply-flow/SKILL.md" -a -f "$KIT/skills/ply-flow/references/ladder.md" -a -f "$KIT/skills/ply-flow/references/decompose.md" -a -f "$KIT/skills/ply-flow/references/dod.md"
t "CLAUDE.md ≤1600 bytes" bash -c "[ \$(wc -c < '$KIT/CLAUDE.md') -le 1600 ]"
t "descr. skill ≤400 bytes" bash -c "[ \$(awk '/^description:/{print length(\$0)}' '$KIT/skills/ply-flow/SKILL.md') -le 400 ]"

# --- Task 12: e2e ---
sandbox
t "e2e: loop completo com 2 agentes" bash -c "cd '$S' &&
  printf 'TEST_CMD=\"bash\"\n' > .ply/config &&
  ./ply spec 'Feature X' >/dev/null &&
  ./ply new 'Parte A' --spec 001 >/dev/null &&
  ./ply new 'Parte B' --spec 001 >/dev/null &&
  ./ply new 'Integra' --spec 001 --dep '001 002' >/dev/null &&
  for i in 1 2; do
    awk -v n=\$i '{ if (\$0 ~ /^files:/) print \"files: src/p\" n \".sh\"; else if (\$0 ~ /^test:/) print \"test: t/t\" n \".sh\"; else print }' tasks/00\$i-*.md > x && mv x tasks/00\$i-parte-*.md 2>/dev/null || mv x \$(ls tasks/00\$i-*.md)
  done &&
  a=\$(./ply next) && [ \"\$a\" = 001 ] && ./ply claim 001 --as ag1 >/dev/null &&
  b=\$(./ply next) && [ \"\$b\" = 002 ] && ./ply claim 002 --as ag2 >/dev/null &&
  [ \"\$(./ply next)\" = NONE ] &&
  mkdir -p src t && echo true > src/p1.sh && echo 'exit 0' > t/t1.sh &&
  echo true > src/p2.sh && echo 'exit 0' > t/t2.sh &&
  ./ply start 001 --as ag1 >/dev/null && ./ply done 001 --as ag1 >/dev/null &&
  ./ply start 002 --as ag2 >/dev/null && ./ply done 002 --as ag2 >/dev/null &&
  [ \"\$(./ply next)\" = 003 ] &&
  ./ply fsck >/dev/null && ./ply metrics | grep -q proxy"

# --- install.sh local ---
S=$(mktemp -d)
t "install.sh local" bash -c "
  '$REPO/install.sh' '$S' >/dev/null &&
  test -x '$S/ply' &&
  test -f '$S/.claude/skills/ply-flow/SKILL.md' &&
  grep -q '<!-- ply:start -->' '$S/CLAUDE.md' &&
  test -d '$S/tasks'
"

# --- install.sh remoto (tarball local, sem rede) ---
S=$(mktemp -d)
TB=$(mktemp -d)
mkdir -p "$TB/ply-master"
cp "$SRC" "$TB/ply-master/ply"
cp -R "$KIT" "$TB/ply-master/kit"
tar -czf "$TB/ply.tar.gz" -C "$TB" ply-master
IDIR=$(mktemp -d)
cp "$REPO/install.sh" "$IDIR/install.sh"
chmod +x "$IDIR/install.sh"
t "install.sh remoto (tarball local)" bash -c "
  PLY_TARBALL_URL='file://$TB/ply.tar.gz' '$IDIR/install.sh' '$S' >/dev/null &&
  test -x '$S/ply' && test -f '$S/.claude/skills/ply-flow/SKILL.md' &&
  grep -q '<!-- ply:start -->' '$S/CLAUDE.md'
"

echo "pass=$pass fail=$fail"; [ "$fail" = 0 ]
