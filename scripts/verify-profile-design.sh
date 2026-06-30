#!/usr/bin/env bash
# Verify the proxyme profile e2e design doc has its three required sections
# and load-bearing anchors. Run from the project root: ./scripts/verify-profile-design.sh
# Exits 0 when every assertion passes, non-zero (with the missing anchor named) otherwise.
set -euo pipefail

# Resolve paths relative to this script so it works from any cwd (no personal paths).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOC="$ROOT/docs/superpowers/specs/2026-06-30-proxyme-profile-e2e.md"

if [ ! -f "$DOC" ]; then
  echo "FAIL: design doc not found at $DOC" >&2
  exit 1
fi

# Literal anchors (fixed strings) that must appear in the doc.
ANCHORS=(
  "## 1. Levantamento (SMART-CLIP extraction)"
  "## 2. Interpretation"
  "## 3. Validation (scorecard)"
  "8.5/10"
  "never insert the specific case"
)

missing=0
for anchor in "${ANCHORS[@]}"; do
  if ! grep -Fq -- "$anchor" "$DOC"; then
    echo "FAIL: missing anchor: $anchor" >&2
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  exit 1
fi

echo "OK: $(basename "$DOC") has all 3 sections and anchors (8.5/10, never insert the specific case)"
