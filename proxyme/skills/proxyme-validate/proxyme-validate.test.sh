#!/usr/bin/env bash
#
# Real-run evidence for the proxyme-validate skill (skill-validation-before-merge).
#
# Validates fixtures/sample-scorecard.json — the documented observed result of one
# real adversarial actor/critic run — against the rubric/threshold schema:
#   - five per-dimension scores per held-out question, each in [0,10]
#   - each question average == mean of its dimension scores
#   - run average == mean of the per-question averages
#   - the 8.5/10 acceptance threshold and accept/iterate logic are consistent
#   - the loop actually iterated (first pass below threshold, last pass at/above)
#   - the anti-overfit invariant: specific_case_inserted == false
#
# Exits 0 only when every assertion holds.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="${SCRIPT_DIR}/fixtures/sample-scorecard.json"
SKILL="${SCRIPT_DIR}/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq is required to run this test"
[ -f "$FIXTURE" ] || fail "fixture not found: $FIXTURE"
[ -f "$SKILL" ]   || fail "skill not found: $SKILL"

jq -e . "$FIXTURE" >/dev/null 2>&1 || fail "fixture is not valid JSON"

# All schema + arithmetic + threshold + anti-overfit checks run inside one jq pass.
JQ_CHECKS='
def absdiff($a;$b): ($a-$b) | if . < 0 then -. else . end;
def approx($a;$b): absdiff($a;$b) < 0.05;
. as $sc
| $sc.rubric.threshold as $th
| $sc.rubric.dimensions as $dims
| [ $sc.held_out_questions[] | . as $q | ($dims|map($q.scores[.])) | (add/length) ] as $qavgs
| [
    (if $th == 8.5 then empty else "threshold is not 8.5/10: \($th)" end),
    (if ($dims|length) >= 3 then empty else "need at least 3 rubric dimensions" end),
    ( $sc.held_out_questions[] | . as $q | ($dims|map($q.scores[.])) as $v
      | (if ($v|any(. == null)) then "\($q.id): missing dimension score" else empty end),
        (if ($v|any(. < 0 or . > 10)) then "\($q.id): score out of [0,10] range" else empty end),
        (if approx(($v|add/($v|length)); $q.average) then empty
         else "\($q.id): stored average \($q.average) != mean of dimension scores" end)
    ),
    (if approx(($qavgs|add/($qavgs|length)); $sc.result.average) then empty
     else "result.average \($sc.result.average) != mean of per-question averages" end),
    (if $sc.result.accepted == ($sc.result.average >= $th) then empty
     else "result.accepted is inconsistent with average vs threshold" end),
    (if $sc.result.accepted then empty else "documented run did not pass the 8.5/10 threshold" end),
    (if $sc.result.specific_case_inserted == false then empty
     else "anti-overfit violated: specific case inserted into identity" end),
    (if ($sc.iterations[0].average < $th) then empty
     else "first iteration should be below threshold (loop must iterate)" end),
    (if ($sc.iterations[-1].average >= $th) then empty
     else "final iteration is below threshold" end),
    (if approx($sc.iterations[-1].average; $sc.result.average) then empty
     else "result.average != final iteration average" end)
  ]
| if length == 0 then "PASS" else (.[]|tostring) end
'

RESULT="$(jq -r "$JQ_CHECKS" "$FIXTURE")"
[ "$RESULT" = "PASS" ] || fail "scorecard validation:
$RESULT"

# The skill must document the 8.5/10 threshold and the observed real run.
grep -q '8.5/10' "$SKILL"        || fail "SKILL.md does not document the 8.5/10 threshold"
grep -q 'Observed result' "$SKILL" || fail "SKILL.md does not document the observed real-run result"

echo "PASS: scorecard schema, 8.5/10 threshold, accept/iterate logic and anti-overfit invariant verified"
exit 0
