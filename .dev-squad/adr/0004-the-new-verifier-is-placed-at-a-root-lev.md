# ADR-0004: The new verifier is placed at a root-level scripts/ directory, but ev...

- Status: proposed
- Date: 2026-06-30

## Context
Raised during decompose: The new verifier is placed at a root-level scripts/ directory, but every existing project script (bump-version.sh, sync-marketplace-cache.sh, install-hooks.sh) lives under proxyme/scripts/. The plan correctly follows the spec deliverable path and AC-1 (./scripts/verify-profile-design.sh), so this is non-blocking, but it introduces a second scripts location and diverges from the established convention.

## Decision
Consider co-locating the verifier under proxyme/scripts/ (and updating the spec/AC path) to keep a single scripts directory, unless a root-level repo-wide scripts/ is intentionally being introduced.

## Consequences
(to be assessed on acceptance)

## Alternatives
(to be enumerated on acceptance)
