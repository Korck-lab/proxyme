#!/bin/bash
# Install a git pre-commit hook that auto-bumps the proxyme version
# when any proxyme/ files are staged.
# Safe to run multiple times — skips if the hook call already exists.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_NAME="${1:-pre-commit}"
HOOK_FILE="${REPO_ROOT}/.git/hooks/${HOOK_NAME}"
MARKER="# proxyme-auto-version-bump"

if [ -f "$HOOK_FILE" ] && grep -qF "$MARKER" "$HOOK_FILE"; then
  echo "Hook already installed in ${HOOK_FILE}"
  exit 0
fi

if [ ! -f "$HOOK_FILE" ]; then
  cat > "$HOOK_FILE" <<'HOOK'
#!/bin/bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
# proxyme-auto-version-bump
exec "$REPO_ROOT/proxyme/scripts/bump-version.sh"
HOOK
else
  cp "$HOOK_FILE" "${HOOK_FILE}.bak"
  cat >> "$HOOK_FILE" <<'HOOK'

# proxyme-auto-version-bump
REPO_ROOT="$(git rev-parse --show-toplevel)"
"$REPO_ROOT/proxyme/scripts/bump-version.sh"
HOOK
fi

chmod +x "$HOOK_FILE"
echo "Installed ${HOOK_NAME} hook at ${HOOK_FILE}"
