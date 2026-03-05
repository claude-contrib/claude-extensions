#!/usr/bin/env bash
set -euo pipefail

duplicates=$(jq -r '.plugins[].name' .claude-plugin/marketplace.json | sort | uniq -d)
if [ -n "$duplicates" ]; then
  echo "✗ Duplicate plugin names: $duplicates"
  exit 1
fi
echo "✓ No duplicate plugin names"
