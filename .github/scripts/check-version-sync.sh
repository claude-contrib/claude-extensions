#!/usr/bin/env bash
set -euo pipefail

error=0
while IFS= read -r name; do
  marketplace_ver=$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .version' .claude-plugin/marketplace.json)
  plugin_ver=$(jq -r '.version' "plugins/${name}/.claude-plugin/plugin.json")
  if [ "$marketplace_ver" != "$plugin_ver" ]; then
    echo "✗ Version mismatch for '$name': marketplace=$marketplace_ver plugin.json=$plugin_ver"
    error=1
  else
    echo "✓ $name version $plugin_ver in sync"
  fi
done < <(jq -r '.plugins[].name' .claude-plugin/marketplace.json)
exit $error
