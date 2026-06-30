# Design: Proxyme Profile End-to-End Review

**Date:** 2026-06-30
**Status:** draft
**Scope:** `proxyme/skills/{proxyme-identity,proxyme,proxyme-validate}`, `proxyme/agents/proxy.md`

---

## Objective

Review end-to-end how the proxyme plugin turns Claude Code session history into a
usable identity profile, and harden the three weak links: a token-bounded
extractor (Levantamento), an explicit interpretation contract, and a closed-loop
validation scorecard. All examples below use placeholders only — no real emails,
tokens, or absolute personal paths. Session files live under `$HOME/.claude/projects/`
and the identity file is written to `$HOME/.claude/skills/proxyme/${LOGNAME}-identity.md`.

---

## 1. Levantamento (SMART-CLIP extraction)

Today Agent D is naive: it picks the 5 longest `.jsonl` files by line count and
extracts bare user messages, losing the surrounding question and confirmation. The
SMART-CLIP method replaces this with a token-bounded, context-aware pull.

- **Line-offset mapping.** Each `.jsonl` line is one JSON event. Build a
  `line-offset` index of every *real* user turn (`role:"user"`, no `<command-name>`,
  `<system-reminder>`, or `<local-command>`) by its 1-based line number — never load
  the whole file into the agent.
- **Bounded context window.** Around each indexed user turn clip a small window
  (default up to 2 assistant turns before + 2 after). The preceding assistant turn is
  usually the question being answered; the following one carries the result.
- **Q/A pair.** Pair the model's preceding question to the user's answer so intent is
  preserved instead of an orphaned message.
- **Model confirmation-of-understanding.** Capture the assistant turn where the model
  restates or acknowledges the user's instruction — this records whether the user
  accepted or corrected the model's reading.
- **jq windowed pull.** Extract each window deterministically by line index with `jq`,
  e.g. `jq -c "select(.__line >= ($n-2) and .__line <= ($n+2))"` over a
  line-numbered stream (`nl`/`awk` to inject `__line`), so cost scales with clip count,
  not file size.
- **Token budget.** Cap to the most informative ~40 clips and <=600 consolidated
  words. Classify each clip as request / correction-rejection / confirmation / answer
  so the synthesizer keeps the highest-signal turns within budget.

Output: classified Q/A-context records (not bare messages) handed to the existing
Opus synthesis step. Pointer: run `proxyme-validate` next.

---

## 2. Interpretation

The interpretation runtime is the proxy briefing (`proxyme/SKILL.md`) plus the agent
contract (`proxyme/agents/proxy.md`). It must answer questions for which no exact
answer was memorized — common in long-run sessions whose specifics were never clipped.

- **Extrapolate from the technical profile.** For a novel question, the proxy
  reconstructs the likely answer from the identity's decision heuristics, technical
  preferences, and project context rather than guessing or deferring.
- **Construct an answer from the profile.** The briefing instructs the proxy to
  construct an answer from the profile and state the basis (which heuristic/section it
  extrapolated from), keeping the response traceable and read-only.
- **Long-run sessions.** Because clipping is bounded, the profile is a *general* model,
  not a transcript; interpretation is expected to generalize beyond memorized cases.

Authority remains unchanged: the proxy decides and advises via `SendMessage`; the main
agent is the sole executor; absolute carve-outs (money, credentials, publication,
permanent deletion) escalate to the real user.

---

## 3. Validation (scorecard)

A new standalone `proxyme-validate` skill closes the loop with an adversarial
**actor/critic** scorecard so the identity is provably general, not overfit.

- **Adversarial generation.** From the collected info the actor generates *analogous*,
  held-out questions the identity should be able to answer but that were not used to
  build it.
- **Actor/critic loop.** The proxy hypothesis answers each question (actor); a separate
  critic scores every answer on a documented rubric (fidelity to heuristics, technical
  correctness, tone, autonomy calibration).
- **Threshold.** Iterate until the scorecard averages **8.5/10** or better across the
  held-out set, with a retry cap (default 3) to stay executable in one session.
- **Anti-overfit rule.** When a score is low, adjust the *general* identity profile
  only — **never insert the specific case** (the exact validation Q/A) into the
  identity. Re-test against fresh held-out questions to confirm the gain generalizes.

Delegation (who decides / authority / carve-outs):

- **Who decides:** the critic agent owns the pass/fail and the iterate-or-stop call.
- **Authority:** bounded to editing the *general* identity sections; it may not insert
  specific cases, touch Section 7 operational rules, or commit any identity file.
- **Carve-outs:** stops at the retry cap and reports the final scorecard even if below
  threshold; never weakens the read-only, no-PII, never-insert-the-specific-case rules.

---

## Out of scope

- No cross-session messaging, persistent daemon, or global single-instance proxy.
- No execute/write tools for the proxy — it stays read-only and consultative.
- No version bump, marketplace-cache sync, or README rewrite (handled by release flow).
