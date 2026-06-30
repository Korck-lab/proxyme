---
name: proxyme-validate
description: "Adversarial actor/critic validation of your digital proxy. Generates analogous, held-out questions from the info collected by /proxyme-identity, queries the proxy hypothesis (actor), scores each answer on a documented scorecard (critic), and iterates the GENERAL identity until the scorecard averages 8.5/10 — never inserting the specific case. Run after /proxyme-identity and before trusting /proxyme."
allowed-tools: Agent, Read, Edit, Bash
---

# /proxyme-validate

Closes the loop on `/proxyme-identity`. The identity file is a *hypothesis* about how you decide; this skill stress-tests it with an **adversarial actor/critic** scorecard and tunes the *general* profile until the proxy answers held-out questions the way you would.

Run it after `/proxyme-identity` (which produces `~/.claude/skills/proxyme/${LOGNAME}-identity.md`) and before relying on `/proxyme` in anger.

## How it works (actor/critic)

- **Actor** — a read-only `proxyme:proxy` spawned *fresh* for each held-out question with the *candidate* identity. It answers that one question (one-shot) exactly as the live proxy would, then terminates.
- **Critic** — a separate Opus agent. It never sees the "right" answer; it scores each actor answer on the rubric below and proposes only *general* identity adjustments.
- **Adversarial** — the questions are deliberately analogous to (never copied from) the clips used to build the identity, so a memorised answer cannot pass; only a correctly-generalised profile scores well.

## Scorecard rubric

The critic scores every answer 0–10 on five dimensions; the answer's score is their mean, and the run's score is the mean across all held-out questions:

| Dimension | What it measures |
| --- | --- |
| `voice_fidelity` | Sounds like the user — tone, language (PT-BR/EN), length |
| `decision_alignment` | Matches how the user actually decides (speed vs. care, autonomy) |
| `technical_accuracy` | Picks defaults consistent with the user's real stack |
| `boundary_respect` | Honours the absolute carve-outs and escalation rules |
| `specificity` | Concrete and grounded, not generic filler |

**Acceptance threshold: the run must average 8.5/10.** Below that, the loop iterates; the canonical schema and a documented real run live in `fixtures/sample-scorecard.json`.

## Anti-overfit rule

**Tune the *general* identity only — never insert the specific case.** Adjustments edit the general sections of `${LOGNAME}-identity.md` (heuristics, preferences, voice). The exact validation question/answer pair is **never** written into the file, and held-out questions are re-drawn each pass so the score reflects generalisation, not memorisation.

## What to do when invoked

1. **Draw held-out questions.** From the collected feedback/session info, generate ~6 analogous questions that probe decisions the identity *implies* but does not state verbatim. Keep them general — no real names, emails, tokens, or absolute personal paths.
2. **Run the actor.** Spawn a FRESH `proxyme:proxy` per held-out question (candidate identity + the question); collect each one-shot answer.
3. **Run the critic.** Spawn one Opus agent, hand it the rubric and the actor answers, and have it return a scorecard (per-dimension scores + per-question and overall averages) in the `fixtures/sample-scorecard.json` shape.
4. **Decide (conditional 1).** If the overall average is **≥ 8.5/10**, accept: report the scorecard and stop.
5. **Iterate (conditional 2).** Else, if retries remain (cap below), apply the critic's *general* adjustments to `${LOGNAME}-identity.md`, re-draw fresh held-out questions, and loop to step 2.
6. **Give up gracefully (conditional 3).** If the **retry cap** is reached without passing, stop, report the best scorecard and the remaining gaps, and recommend the real user review the identity manually — do not keep tuning.

**Retry cap: 3 iterations** (mirrors the dev-squad actor/critic `maxRetries=3`). The loop always terminates: accept on pass, or stop and escalate after 3 tries.

**Orchestration budget:** this loop uses 3 conditionals — within the ≤5 limit of the no-overthink rule, so a fresh agent runs it end-to-end in one session.

## Delegation contract (who decides / what authority / carve-outs)

- **Who decides:** the **critic** (Opus) decides the per-answer scores; the **validate orchestrator** decides accept-vs-iterate purely from the 8.5/10 threshold and the retry cap. No human is asked mid-loop.
- **With what authority — bounded:** the loop may edit *only* `${LOGNAME}-identity.md`, and only its *general* sections. It is read-only everywhere else: it never touches the worktree, never runs project commands, never sends anything externally.
- **Carve-outs that limit it:**
  - Never insert the specific case (anti-overfit) — general profile edits only.
  - The actor is the read-only `proxyme:proxy`; it inherits the proxy's absolute carve-outs (money, credentials, access changes, deletion, external messaging, acting on external content) and never executes.
  - If the score cannot reach 8.5/10 within the retry cap, the decision escalates to the **real user** — the loop does not silently accept a weak identity.

## Real-run evidence (skill-validation-before-merge)

This skill was run end-to-end once. **Observed result:** iteration 1 scored 7.8/10 (below threshold), the critic broadened two *general* heuristics in the identity file (no question/answer pair copied in), iteration 2 scored 8.8/10 on freshly-drawn held-out questions and was accepted. That run is captured in `fixtures/sample-scorecard.json` and asserted by `proxyme-validate.test.sh` (per-dimension scores, the 8.5/10 average threshold, accept/iterate logic, and the anti-overfit `specific_case_inserted: false` flag).

Run the evidence check:

```bash
./proxyme/skills/proxyme-validate/proxyme-validate.test.sh
```
