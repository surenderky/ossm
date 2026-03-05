#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <junit.xml>"
  exit 1
fi

JUNIT_FILE="$1"

if [[ ! -f "$JUNIT_FILE" ]]; then
  echo "Error: file not found: $JUNIT_FILE"
  exit 1
fi

# -------- Per-suite summary (hide tests=0) --------
xmllint --xpath '//testsuite' "$JUNIT_FILE" \
| sed 's/></>\n</g' \
| awk '
  /<testsuite/ {
    name=""; tests="0"; failures="0"; skipped="0"; errors="0"

    if (match($0, /name="([^"]+)"/, m))      name=m[1]
    if (match($0, /tests="([^"]+)"/, m))     tests=m[1]
    if (match($0, /failures="([^"]+)"/, m))  failures=m[1]
    if (match($0, /skipped="([^"]+)"/, m))   skipped=m[1]
    if (match($0, /errors="([^"]+)"/, m))    errors=m[1]

    # hide suites with zero tests
    if (tests == "0") next

    sub(".*/tests/integration/", "", name)

    printf "%s  tests=\"%s\" failures=\"%s\" errors=\"%s\" skipped=\"%s\"\n",
           name, tests, failures, errors, skipped
  }
'

# -------- Totals --------
TOTAL=$(xmllint --xpath 'sum(//testsuite/@tests)' "$JUNIT_FILE")
FAIL=$(xmllint --xpath 'sum(//testsuite/@failures)' "$JUNIT_FILE")
ERROR=$(xmllint --xpath 'sum(//testsuite/@errors)' "$JUNIT_FILE")
SKIP=$(xmllint --xpath 'sum(//testsuite/@skipped)' "$JUNIT_FILE")

PASS=$((TOTAL - FAIL - ERROR - SKIP))

echo
echo "TOTAL  tests=\"$TOTAL\" failures=\"$FAIL\" errors=\"$ERROR\" skipped=\"$SKIP\" passed=\"$PASS\""

# -------- Failed test names (from embedded logs) --------
echo

if grep -q '=== DONE (failed):' "$JUNIT_FILE"; then
  echo "FAILED TESTS:"
  grep '=== DONE (failed):' "$JUNIT_FILE" \
  | sed -n "s/.*Test: '\([^']*\) (.*/\1/p" \
  | sort -u \
  | sed 's/^/  - /'
fi
