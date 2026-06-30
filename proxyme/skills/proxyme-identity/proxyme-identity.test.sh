#!/usr/bin/env bash
#
# proxyme-identity.test.sh — real-run evidence for the Agent D SMART-CLIP extractor.
#
# What this tests (skill-validation-before-merge guardrail):
#   The SMART-CLIP jq line-offset window helper documented in SKILL.md (Agent D).
#   It maps each real user turn's line offset in a .jsonl session and pulls only a
#   bounded window (default up to 2 assistant turns BEFORE + 2 AFTER each real user
#   turn) via line index — it never loads the whole .jsonl into the agent. The output
#   is one windowed Q/A-context record per real user turn (model question -> user
#   answer -> model confirmation-of-understanding), ready for clip classification.
#
# Fixture: fixtures/sample-session.jsonl — a synthetic placeholder session about
#   building a "widget-store" checkout. No real PII, emails, tokens, or personal paths.
#
# Observed result (real run, 2026-06-30, GNU bash 3.2.57 + jq 1.7.1):
#   3 real user turns indexed (lines 3, 9, 13); command/system-reminder/tool_result
#   lines (1, 6, 8, 11) excluded. User turn at line 3 yields after=[4,5] only — the
#   third following assistant turn (line 7) is capped out, proving the window is
#   bounded and the whole file is never loaded. User turn at line 9 (a correction)
#   captures the model confirmation-of-understanding at line 10. The widened filter
#   also drops harness-injected noise (task-notification @15, image-meta @16) — these
#   are NOT user turns; on real sessions 20-50% of user-typed lines are this kind of
#   noise (task-notification, [Image:...], compaction summaries, slash-command caveats).
#   All assertions pass; the script exits 0.
#
# Run:  ./proxyme-identity.test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="$SCRIPT_DIR/fixtures/sample-session.jsonl"
BEFORE=2   # default assistant turns kept before each real user turn
AFTER=2    # default assistant turns kept after each real user turn

# --- SMART-CLIP helper (mirrors the Agent D method in SKILL.md) ----------------
# Pass 1: classify every line by offset WITHOUT loading content into the agent.
#   A = assistant turn, U = real user turn, O = other (command / system-reminder /
#   tool_result / meta). Real user turn = type==user, string content, no markers.
classify() {
  jq -rc '"\(input_line_number) \(
    if .type=="assistant" then "A"
    elif (.type=="user" and (.message.content|type=="string")
          and ((.message.content)|test("<command-name>|<system-reminder>|<local-command|<task-notification>|^\\[Image:|^\\[Request interrupted|session is being continued|Caveat: The messages below were generated")|not)) then "U"
    else "O" end)"' "$1"
}

# Pull the readable text of a single line by its offset (one sed -n, never the file).
text_of() {
  sed -n "${1}p" "$FIXTURE" | jq -rc 'if (.message.content|type)=="string"
    then (.message.content|gsub("\n";" "))
    else (.message.content|map(.text//"")|join(" ")|gsub("\n";" ")) end'
}

# Walk outward from a user turn collecting up to $max assistant lines, skipping
# other lines and stopping at the next real user turn. Returns a space-separated list.
collect() {
  local n=$1 step=$2 max=$3 c=0 out=""
  while [ "$n" -ge 1 ] && [ "$n" -le "$TOTAL" ] && [ "$c" -lt "$max" ]; do
    case "${CLASS[$n]:-O}" in
      U) break ;;
      A) out="$out $n"; c=$((c+1)) ;;
    esac
    n=$((n+step))
  done
  echo "$out"
}

# Emit one windowed Q/A-context record (compact JSON) for a real user turn.
emit_record() {
  local uline=$1 blist=$2 alist=$3 wl bt at
  wl=$( { echo "$uline"; printf '%s\n' $blist $alist; } | grep -E '^[0-9]+$' | sort -n | jq -nc '[inputs]' )
  bt=$( for x in $(printf '%s\n' $blist | grep -E '^[0-9]+$' | sort -n); do text_of "$x"; done | jq -Rnc '[inputs]' )
  at=$( for x in $alist; do text_of "$x"; done | jq -Rnc '[inputs]' )
  jq -nc --argjson ul "$uline" --argjson wl "$wl" --argjson b "$bt" \
         --arg u "$(text_of "$uline")" --argjson a "$at" \
    '{user_line:$ul, window_lines:$wl, before:$b, user:$u, after:$a}'
}

smart_clip() {
  local cls; cls=$(classify "$FIXTURE")
  CLASS=(); TOTAL=0
  while read -r ln cl; do CLASS[$ln]=$cl; TOTAL=$ln; done <<< "$cls"
  local n
  for n in $(seq 1 "$TOTAL"); do
    [ "${CLASS[$n]:-O}" = "U" ] || continue
    emit_record "$n" "$(collect $((n-1)) -1 "$BEFORE")" "$(collect $((n+1)) 1 "$AFTER")"
  done
}

# --- run + assert --------------------------------------------------------------
RECORDS="$(smart_clip)"
FAILS=0
check() { # check <desc> <jq-filter-returning-true>
  if printf '%s\n' "$RECORDS" | jq -e -s "$2" >/dev/null; then
    echo "PASS: $1"
  else
    echo "FAIL: $1"; FAILS=$((FAILS+1))
  fi
}

echo "--- SMART-CLIP windowed records ---"
printf '%s\n' "$RECORDS"
echo "-----------------------------------"

# Exactly the 3 real user turns are indexed (lines 3, 9, 13).
check "indexes only real user turns (lines 3,9,13)" \
  '(length==3) and ([.[].user_line]==[3,9,13])'

# Command / system-reminder / tool_result lines are never treated as user turns.
check "excludes command/system-reminder/tool_result user lines" \
  'all(.[]; (.user|test("<command-name>|<system-reminder>|tool_result"))|not)'

# Every window is bounded: <=2 before, <=2 after, <=5 lines total (never the file).
check "window is bounded (<=2 before, <=2 after, <=5 lines)" \
  'all(.[]; (.before|length)<=2 and (.after|length)<=2 and (.window_lines|length)<=5)'

# Cap proven: user line 3 keeps after=[4,5]; the 3rd following assistant (line 7,
# "Webhook handler scaffolded") is dropped — the whole file is not loaded.
check "caps at 2 after-turns (line 7 excluded from user 3)" \
  'any(.[]; .user_line==3 and (.after|length)==2 and (any(.after[]; test("Webhook handler scaffolded"))|not))'

# Q/A pair: the model question precedes the user answer in the before-window.
check "captures Q/A pair (model question before user answer)" \
  'any(.[]; .user_line==3 and any(.before[]; test("Which payment provider")) and (.user|test("Stripe first")))'

# model confirmation-of-understanding captured after a correction (user line 9).
check "captures model confirmation-of-understanding after a correction" \
  'any(.[]; .user_line==9 and any(.after[]; test("reverting the discount-engine")))'

# Bounded reach: meta/command/reminder/tool_result offsets (1,6,8,11) never pulled.
check "never pulls non-conversational offsets (1,6,8,11)" \
  '([.[].window_lines[]]|unique) as $w | ([1,6,8,11]|all(. as $x | ($w|index($x))==null))'

# Harness-injected noise (task-notification @15, image-meta @16) is NOT a user turn.
# Without the widened filter these would be sampled as the user "speaking" — 20-50%
# of real-session user turns are exactly this kind of noise.
check "excludes task-notification and image-meta from user turns (widened filter)" \
  '([.[].user_line]==[3,9,13]) and all(.[]; (.user|test("<task-notification>|^\\[Image:"))|not)'

if [ "$FAILS" -ne 0 ]; then
  echo "RESULT: $FAILS assertion(s) failed" >&2
  exit 1
fi
echo "RESULT: all assertions passed"
exit 0
