#!/usr/bin/env bash
# install.sh — instala ply no diretório alvo (default: cwd).
# Local: rode a partir do clone. Remoto: curl …/install.sh | bash
set -euo pipefail

REPO_SLUG="${PLY_REPO:-adrianomirandaa/ply}"
BRANCH="${PLY_BRANCH:-master}"
TARBALL_URL="${PLY_TARBALL_URL:-https://github.com/${REPO_SLUG}/archive/refs/heads/${BRANCH}.tar.gz}"

die() { echo "erro: $*" >&2; exit 1; }

TARGET="${1:-.}"
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

SELF_DIR=""
# Quando vem de curl|bash, BASH_SOURCE pode ser vazio ou /dev/fd — não há clone local
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

install_from_dir() { # install_from_dir <srcdir>
  local src="$1"
  [ -f "$src/ply" ] && [ -d "$src/kit" ] || die "fonte incompleta em $src"
  cp "$src/ply" "$TARGET/ply"
  chmod +x "$TARGET/ply"
  (cd "$TARGET" && ./ply init --kit "$src/kit")
}

if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/ply" ] && [ -d "$SELF_DIR/kit" ]; then
  install_from_dir "$SELF_DIR"
else
  command -v curl >/dev/null || die "curl necessário para install remoto"
  command -v tar  >/dev/null || die "tar necessário para install remoto"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "$TARBALL_URL" | tar -xz -C "$tmp"
  # GitHub extrai como <repo>-<branch>
  src=$(echo "$tmp"/*-"$BRANCH")
  [ -d "$src" ] || src=$(echo "$tmp"/ply-*)
  [ -d "$src" ] || die "não achei diretório extraído do tarball em $tmp"
  install_from_dir "$src"
fi

echo "ok: ply instalado em $TARGET"
