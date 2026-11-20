#!/bin/bash
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command')

# If running tests, keep only the last 100 lines
pattern='^(npm test|pytest|go test|(bash )?(\./)?scripts/check(-[a-z]+)?(\.sh)?)( [^;&|<>`$#\\[:cntrl:]]*)?$'
if [[ "$cmd" =~ $pattern ]]; then
  filtered_cmd="(set -o pipefail; $cmd 2>&1 | tail -n 100)"
  echo "$input" | jq --arg filtered "$filtered_cmd" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", updatedInput: (.tool_input + {command: $filtered})}}'
else
  echo "{}"
fi
