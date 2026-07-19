#!/usr/bin/env bash
# install.sh — instala ply no diretório alvo (default: cwd).
# Local: rode a partir do clone. Remoto: curl …/install.sh | bash
set -euo pipefail

REPO_SLUG="${PLY_REPO:-adrianomirandaa/ply}"
BRANCH="${PLY_BRANCH:-master}"

die() { echo "erro: $*" >&2; exit 1; }

resolve_github_token() {
  [ -n "${PLY_GITHUB_TOKEN:-}" ] && { echo "$PLY_GITHUB_TOKEN"; return; }
  [ -n "${GITHUB_TOKEN:-}" ] && { echo "$GITHUB_TOKEN"; return; }
  command -v gh >/dev/null 2>&1 && gh auth token 2>/dev/null || true
}

find_extracted_src() { # find_extracted_src <tmpdir>
  local tmp="$1" d
  for d in "$tmp"/*/; do
    [ -f "${d}ply" ] && [ -d "${d}kit" ] && { echo "${d%/}"; return 0; }
  done
  return 1
}

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

  token="$(resolve_github_token || true)"
  tarball="${PLY_TARBALL_URL:-}"
  curl_args=()
  if [ -z "$tarball" ]; then
    if [ -n "$token" ]; then
      tarball="https://api.github.com/repos/${REPO_SLUG}/tarball/${BRANCH}"
      curl_args=(-H "Authorization: Bearer ${token}" -H "Accept: application/vnd.github+json")
    else
      tarball="https://github.com/${REPO_SLUG}/archive/refs/heads/${BRANCH}.tar.gz"
    fi
  fi

  if [ ${#curl_args[@]} -gt 0 ]; then
    dl=(curl -fsSL "${curl_args[@]}" "$tarball")
  else
    dl=(curl -fsSL "$tarball")
  fi
  if ! "${dl[@]}" | tar -xz -C "$tmp"; then
    if [ -z "$token" ]; then
      die "falha ao baixar ${tarball} (404? verifique PLY_REPO/PLY_BRANCH ou clone o repo e rode ./install.sh localmente)"
    fi
    die "falha ao baixar ${tarball}"
  fi

  src="$(find_extracted_src "$tmp")" || die "não achei diretório extraído do tarball em $tmp"
  install_from_dir "$src"
fi

echo "ok: ply instalado em $TARGET"
