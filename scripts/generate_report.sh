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
    name=""; tests="0"; failures="0"; skipped="0"

    if (match($0, /name="([^"]+)"/, m))      name=m[1]
    if (match($0, /tests="([^"]+)"/, m))     tests=m[1]
    if (match($0, /failures="([^"]+)"/, m))  failures=m[1]
    if (match($0, /skipped="([^"]+)"/, m))   skipped=m[1]

    # hide suites with zero tests
    if (tests == "0") next

    sub(".*/tests/integration/", "", name)

    printf "%s  tests=\"%s\" failures=\"%s\" skipped=\"%s\"\n",
           name, tests, failures, skipped
  }
'

# -------- Totals --------
TOTAL=$(xmllint --xpath 'sum(//testsuite/@tests)' "$JUNIT_FILE")
FAIL=$(xmllint --xpath 'sum(//testsuite/@failures)' "$JUNIT_FILE")
SKIP=$(xmllint --xpath 'sum(//testsuite/@skipped)' "$JUNIT_FILE")
PASS=$((TOTAL - FAIL - SKIP))

echo
echo "TOTAL  tests=\"$TOTAL\" failures=\"$FAIL\" skipped=\"$SKIP\" passed=\"$PASS\""
