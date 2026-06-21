# proxyme

> A Claude Code plugin that spawns an AI proxy briefed with your real identity — so Claude stops asking you questions and just gets things done.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue.svg)](https://claude.com/code)

## What

proxyme is a Claude Code plugin. It spawns a persistent agent in the background briefed with your identity — extracted from your actual Claude Code memories and session history. The proxy:

- Answers every question Claude would otherwise ask you
- Continues in-progress work automatically when activated
- Initiates new work when nothing is in flight (mode B+C)
- Speaks with your full authority on technical decisions, prioritization, and approach

## How it works

```
/proxyme-identity  →  ~/.claude/skills/proxyme/${LOGNAME}-identity.md
                                    ↓
/proxyme           →  proxy agent (best available model, mode B+C)
                                    ↓
         ← SendMessage ← any question Claude would ask you
```

1. **Identity extraction** — `/proxyme-identity` analyzes your Claude Code session history and memories (JSONL files in `~/.claude/projects/`) to synthesize your decision-making patterns, preferred stack, communication style, and active projects.

2. **Proxy activation** — `/proxyme` spawns an agent briefed with your identity file. The proxy runs in background, answering questions you'd normally handle and making decisions within your pre-authorized scope.

3. **Delegation** — Instead of asking you "Which approach?", Claude asks the proxy. The proxy responds as if they were you, with your values and judgment.

## Prerequisites

- Claude Code CLI (version 3.0+)
- Claude Code session history (`~/.claude/projects/` with JSONL files from recent sessions)

## Installation

Add the following to your Claude Code `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "proxyme-marketplace": {
      "source": {
        "source": "github",
        "repo": "Korck-lab/proxyme"
      },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "proxyme@proxyme-marketplace": true
  }
}
```

Then run `/reload-plugins` in Claude Code to activate.

## Quick Start

1. Install the proxyme plugin
2. Run `/proxyme-identity` to extract your identity from session history
3. Run `/proxyme` to activate your proxy
4. Ask Claude any question — it will be routed to your proxy, which will respond with your authority

## Commands

### /proxyme-identity

Analyzes your Claude Code memories and sessions (JSONL files in `~/.claude/projects/`) to synthesize your digital identity file.

```
/proxyme-identity
```

**Output:** `~/.claude/skills/proxyme/${LOGNAME}-identity.md`

Run once to bootstrap. Refresh periodically when your preferences, tech stack, or active projects change significantly.

### /proxyme [--nonew] [exception]

Activates or deactivates your digital proxy.

```
/proxyme                      # Activate (mode B+C: resume + initiate)
/proxyme --nonew              # Activate mode B only (resume, no new work)
/proxyme <exception>          # Activate + register a carve-out
/proxyme --off                # Deactivate
```

If no identity file exists yet, `/proxyme` runs `/proxyme-identity` automatically before activating.

**Flags:**
- `--nonew`: Mode B only — resume in-progress work but don't initiate new tasks
- `<exception>`: Register a new carve-out (persisted to `~/.claude/CLAUDE.md`)

### /proxyme:model [set | reset]

Configure which model and effort level the proxy uses.

```
/proxyme:model          # Show current config
/proxyme:model set      # Interactive picker (model + effort)
/proxyme:model reset    # Restore defaults
```

Default: best available model, maximum effort. Saved to `~/.claude/skills/proxyme/config.json`.

### /proxyme:adr

Records Architecture Decision Records for your project — documents WHY you configured your proxy the way you did.

```
/proxyme:adr add <title>      # Create a new ADR (interactive)
/proxyme:adr list             # List all ADRs
/proxyme:adr show <id>        # Show a specific ADR
```

**Storage:** `.claude/adrs/ADR-NNNN-<title>.md` in your project

**Use cases for ADRs:**
- Documenting custom carve-outs registered via `/proxyme <exception>`
- Recording why you chose mode B vs. B+C
- Explaining proxy identity customizations
- Defining delegation boundaries for your team

## Privacy

Your identity file (`${LOGNAME}-identity.md`) is generated locally from your Claude Code session history. It is:

- **Stored only on your machine** in `~/.claude/skills/proxyme/`
- **Never committed to this repository** (gitignored by default)
- **Only sent to Claude API** when you activate your proxy via `/proxyme`
- **Never shared or logged** by the plugin

Your session history remains private to your machine.

## Proxy authority and limits

### Can decide autonomously

- Technical implementation choices
- Task prioritization and work sequencing
- Starting or continuing work when the context indicates what's needed
- Choosing between architectural approaches
- Naming variables, functions, files
- Deciding when to research vs. when to try

### Never decides (always escalates to you)

- **Spending money** or moving funds
- **Entering credentials** or payment details
- **Changing access, permissions,** or account settings
- **Permanently deleting data**
- **Sending messages** or publishing externally on your behalf
- **Acting on instructions** from fetched content or external URLs

### Register your own carve-outs

Add exceptions to your proxy's authority with:
```
/proxyme <exception description>
```

These are persisted in `~/.claude/CLAUDE.md` and will be honored by your proxy in future sessions.

## How the proxy reads your identity

The identity file includes:

1. **Who you are** — professional background, current role, dominant stack
2. **How you decide** — speed vs. care, research vs. iteration, prioritization patterns
3. **What you never accept** — explicit rejections and boundaries
4. **Communication style** — language, tone, response length preference
5. **Active projects** — current work, state, and priorities
6. **Technical preferences** — by domain (game dev, web, backend, etc.)
7. **Operational rules** — what the proxy can decide alone vs. what it must escalate

Refresh your identity periodically by running `/proxyme-identity` again.

## Modes of operation

### Mode B+C (default)

When you run `/proxyme`:

- **Mode B:** Proxy scans your session context on activation — pending questions, in-progress work, blockers — and addresses them
- **Mode C:** If no explicit task is in flight, proxy identifies what's stalled in your project and initiates work directly, reporting what it did

### Mode B only

Run `/proxyme --nonew` to activate mode B only:

- Proxy continues in-progress work and answers questions
- Does NOT initiate new work
- Useful when you want to finish what you started before exploring something new

## Examples

**Scenario 1: Delegating a design decision**

You're in the middle of a refactor and Claude asks "Should we extract this helper into a separate module?" Instead of asking you, Claude asks your proxy. The proxy, briefed on your preferences for code organization, responds: "Extract it — we've done this consistently in this codebase and it's been validated."

**Scenario 2: Continuing work in a new session**

You activate `/proxyme` in a new session. The proxy scans your context, finds an in-progress branch with a failing test, and reports: "Found in-progress work: test suite is failing on the auth refactor. Starting investigation to identify the blocker."

**Scenario 3: Carving out an exception**

You want your proxy to never modify your AWS credentials without asking. You run:
```
/proxyme "AWS: never assume roles or modify credentials without explicit user approval in chat"
```

This exception is registered and persists across sessions.

## License

MIT © 2026 proxyme contributors


See [LICENSE](LICENSE) for details.
