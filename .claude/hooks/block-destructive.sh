#!/bin/bash
set -euo pipefail
# Read tool input JSON from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Strip quoted strings and heredocs to avoid false positives
# (e.g., a commit message mentioning "rm -rf" as documentation)
STRIPPED=$(echo "$COMMAND" | sed -E \
  -e "/<<['\"]?EOF/,/^EOF/d" \
  -e "s/\"([^\"\\\\]|\\\\.)*\"//g" \
  -e "s/'[^']*'//g")

# Match destructive patterns
if echo "$STRIPPED" | grep -qE \
  'rm -rf|git push --force|git push.*-f\b|git reset --hard|DROP TABLE|DROP DATABASE|db\.dropDatabase|db\.\w+\.drop\('; then
  echo '{"decision":"block","reason":"Destructive command blocked by safety hook."}'
  exit 2
fi
exit 0
