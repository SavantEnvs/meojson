#!/usr/bin/env bash
#
# mayhem/test.sh — RUN this repo's OWN functional test suite (already built by mayhem/build.sh).
# exit 0 = pass. EDIT per repo. PATCH-grade oracle: after an agent patches the source, the grader
# rebuilds (build.sh) then runs this. DELETE this file if the repo has no meaningful tests.
#
# IMPORTANT:
#  * Must assert BEHAVIOR/OUTPUT, not just exit status. The oracle has to check asserted values /
#    golden-output diffs / known-answer results — so a PATCH that "fixes" a bug by making the program
#    exit(0) (or any no-op) FAILS here. Running inputs and checking only "exit 0 / didn't crash" is
#    NOT a functional test (it's trivially reward-hackable) — use the project's real assertion suite.
#  * Do NOT build here — mayhem/build.sh already compiled the test suite (with the project's normal
#    flags). This script only RUNS the pre-built tests and reports counts. If the test runner is
#    missing, that's a build.sh bug — fail loudly rather than silently rebuilding.
#  * REQUIRED OUTPUT — a CTRF (https://ctrf.io) summary so Mayhem/the PATCH grader reads the counts:
#      - writes a CTRF JSON report to ${CTRF_REPORT:-$SRC/ctrf-report.json}, and
#      - prints a one-line `CTRF {...}` marker to stdout (same JSON, compact).
#    Only `results.summary` (with tests/passed/failed/pending/skipped/other) is required.
#    Use the emit_ctrf helper below; it computes tests = passed+failed+skipped and sets the exit
#    code (0 iff failed==0). Map your framework's output to passed/failed/skipped.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# Run upstream's own assertion suite (test/*.cpp, built by build.sh with normal flags). It prints one
# "*** <name> ***" banner per suite and "Test passed" only when every assertion held. A neutered binary
# prints nothing, so every banner check below fails loudly.
WORK="$SRC/build/mayhem"
[ -x "$WORK/testing" ] || { echo "missing $WORK/testing (build.sh bug)" >&2; emit_ctrf "meojson-testing" 0 1 0; exit 1; }
[ -x "$WORK/kat" ] || { echo "missing $WORK/kat (build.sh bug)" >&2; emit_ctrf "meojson-testing" 0 1 0; exit 1; }

passed=0 failed=0
check() { # <name> <ok:0|1>
  if [ "$2" -eq 0 ]; then passed=$((passed + 1)); else failed=$((failed + 1)); echo "FAIL: $1" >&2; fi
}

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
cd "$scratch"

out="$("$WORK/testing" 2>&1)"; rc=$?
echo "$out" | tail -n 20
for suite in parsing serializing jsonizing include_test precision_test unicode_test value_test \
             enum_test object_test array_test jsonc_test smart_ptr_test; do
  case "$out" in *"*** $suite ***"*) check "suite $suite ran" 0 ;; *) check "suite $suite ran" 1 ;; esac
done
case "$out" in *"****** Test passed ******"*) check "upstream suite reports pass" 0 ;; *) check "upstream suite reports pass" 1 ;; esac
check "upstream suite exit code" "$rc"

# Known-answer probe: exact values for fixed inputs, compared here in bash.
kat="$("$WORK/kat" 2>&1)"; krc=$?
check "kat exit code" "$krc"
expect() { # <label> <exact line>
  if printf '%s\n' "$kat" | grep -Fxq -- "$2"; then check "$1" 0; else check "$1" 1; echo "  expected line: $2" >&2; fi
}
expect "kat nested string"   'b=cé'
expect "kat integer"         'a1=2'
expect "kat boolean"         'd=1'
expect "kat array size"      'size=3'
expect "kat double"          'f=-12.5'
expect "kat serialization"   'dump={"a":[1,2,{"b":"cé"}],"d":true,"e":null,"f":-12.5}'
expect "kat jsonc"           'jsonc={"k":[1,2],"z":"s"}'
expect "kat rejects invalid" 'bad=rejected'

emit_ctrf "meojson-testing" "$passed" "$failed" 0
