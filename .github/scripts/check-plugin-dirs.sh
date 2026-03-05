#!/usr/bin/env bash
set -euo pipefail

error=0
while IFS= read -r source; do
  path="${source#./}"
  if [ ! -d "$path" ]; then
    echo "✗ Missing directory for plugin source: $source"
    error=1
  else
    echo "✓ $source"
  fi
done < <(jq -r '.plugins[].source' .claude-plugin/marketplace.json)
exit $error
