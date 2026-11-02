#!/bin/bash
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
CATALOG="$ROOT/providers/catalog.json"

command -v jq >/dev/null 2>&1
jq -e '
  .schema_version == 1
  and ([.research_sources[].id] | sort) == ["opencode", "orca"]
  and ([.adapters[] | select(.status == "implemented") | .id] | sort)
      == ["claude-code-subscription", "codex-subscription"]
  and all(.adapters[]; (.kind | length) > 0 and (.contract | length) > 0)
' "$CATALOG" >/dev/null

echo "Provider catalog checks passed"
