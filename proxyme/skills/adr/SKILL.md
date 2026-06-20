---
name: adr
description: "Record Architecture Decision Records for your project. Documents the WHY behind design decisions — proxy carve-outs, operation mode choices, delegation boundaries, identity customizations. /squad-proxy:adr add <title> creates a new ADR; /squad-proxy:adr list shows all; /squad-proxy:adr show <id> displays one."
argument-hint: "add <title> | list | show <id>"
allowed-tools: Read, Write, Bash
---

# /squad-proxy:adr

Records Architecture Decision Records (ADRs) for your project — documents the WHY behind your design decisions about proxy configuration, delegation scope, and identity choices.

## Subcommands

```
/squad-proxy:adr add <title>    → create a new ADR interactively
/squad-proxy:adr list           → list all ADRs in current project
/squad-proxy:adr show <id>      → display a specific ADR
```

## Storage

ADRs are stored in `.claude/adrs/ADR-NNNN-<slug>.md` in the current project.

## ADR Template

```markdown
---
id: NNNN
title: <title>
date: <ISO date>
status: proposed | accepted | deprecated | superseded-by ADR-XXXX
---

## Context
What situation or problem prompted this decision?

## Decision
What was decided?

## Consequences
What are the effects — positive, negative, and neutral?
```

## Implementation

### `add <title>` subcommand

1. Determine next ID:
   ```bash
   next_id=$(($(ls .claude/adrs/ADR-*.md 2>/dev/null | wc -l) + 1))
   printf "%04d" $next_id
   ```

2. Generate slug from title: lowercase, spaces→hyphens, special chars removed

3. Ask user interactively (one question at a time):
   - "Context: What situation prompted this decision?"
   - "Decision: What was decided?"
   - "Consequences: What are the effects (positive, negative, neutral)?"

4. Write file to `.claude/adrs/ADR-NNNN-<slug>.md` and confirm path:
   ```
   "ADR created: [path]"
   ```

### `list` subcommand

List all ADRs in `.claude/adrs/`:
```bash
ls -1 .claude/adrs/ADR-*.md 2>/dev/null | while read f; do
  id=$(grep "^id:" "$f" | cut -d: -f2 | xargs)
  title=$(grep "^title:" "$f" | cut -d: -f2 | xargs)
  status=$(grep "^status:" "$f" | cut -d: -f2 | xargs)
  printf "ADR-%s: %s [%s]\n" "$id" "$title" "$status"
done
```

If no ADRs exist, respond: "No ADRs found in this project."

### `show <id>` subcommand

1. Look for `.claude/adrs/ADR-<id>-*.md`
2. Read and display the file
3. If not found, respond: "ADR-<id> not found."

## Notes

- ADRs document project-specific decisions, not plugin decisions
- Good ADR candidates: custom carve-outs via `/squad-proxy <exception>`, choice of operation mode (--nonew?), proxy identity customizations, delegation boundaries
- ADRs are local to each project and should be committed to your project repository
