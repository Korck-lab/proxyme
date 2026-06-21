#!/bin/bash
# Sync proxyme source into the local marketplace plugin cache for the given version.
#
# Usage: sync-marketplace-cache.sh [<new_version>] [<repo_root>]
#   <new_version>  defaults to the contents of <repo_root>/proxyme/VERSION
#   <repo_root>    defaults to `git rev-parse --show-toplevel`
#
# Only the runtime payload is copied — dev artifacts and release tooling
# are excluded. Old version directories are pruned, keeping the
# KEEP_VERSIONS most recent by semver order.
#
# CACHE_ROOT_OVERRIDE (env, TEST-ONLY): redirects the cache root.
set -euo pipefail

KEEP_VERSIONS=10

usage() {
  echo "Usage: sync-marketplace-cache.sh [<new_version>] [<repo_root>]" >&2
  exit 1
}

new_version="${1:-}"
repo_root="${2:-}"

if [ -z "$repo_root" ]; then
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: <repo_root> not given and not inside a git repository" >&2
    usage
  }
fi

if [ ! -d "${repo_root}/proxyme" ]; then
  echo "ERROR: '${repo_root}/proxyme' not found — not a proxyme repo root" >&2
  usage
fi

if [ -z "$new_version" ]; then
  new_version="$(tr -d '[:space:]' < "${repo_root}/proxyme/VERSION" 2>/dev/null || true)"
  if [ -z "$new_version" ]; then
    echo "ERROR: <new_version> not given and ${repo_root}/proxyme/VERSION is missing or empty" >&2
    usage
  fi
fi

if ! printf '%s' "$new_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "ERROR: invalid semver version '${new_version}'" >&2
  usage
fi

CACHE_ROOT="${CACHE_ROOT_OVERRIDE:-$HOME/.claude/plugins/cache}"
CACHE_BASE="${CACHE_ROOT}/proxyme-marketplace/proxyme"

[ -d "$CACHE_BASE" ] || exit 0

CACHE_TARGET="${CACHE_BASE}/${new_version}"
mkdir -p "$CACHE_TARGET"

rsync -a --delete \
  --exclude='.claude-plugin/' \
  --exclude='.git/' \
  --exclude='.claude/' \
  --exclude='.remember/' \
  --exclude='graphify-out/' \
  --exclude='__pycache__/' \
  --exclude='CLAUDE.md' \
  --exclude='*.pyc' \
  --exclude='.DS_Store' \
  --exclude='/scripts/' \
  "${repo_root}/proxyme/" "${CACHE_TARGET}/"

echo "Synced cache: ${CACHE_TARGET}"

# --- Prune: keep the KEEP_VERSIONS most recent versions (semver order) ---
versions="$(cd "$CACHE_BASE" && ls -1d ./*/ 2>/dev/null | sed 's|^\./||; s|/$||' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V || true)"
total="$(printf '%s\n' "$versions" | grep -c . || true)"

if [ "${total:-0}" -gt "$KEEP_VERSIONS" ]; then
  pruned=0
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    [ "$v" = "$new_version" ] && continue
    case "$v" in
      */*|.*) continue ;;
    esac
    if [ -d "${CACHE_BASE}/${v}" ]; then
      rm -rf "${CACHE_BASE:?}/${v}"
      pruned=$((pruned + 1))
    fi
  done <<EOF
$(printf '%s\n' "$versions" | head -n "$((total - KEEP_VERSIONS))")
EOF
  [ "$pruned" -gt 0 ] && echo "Pruned ${pruned} old cache version(s); keeping the ${KEEP_VERSIONS} most recent"
fi

exit 0
