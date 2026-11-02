#!/bin/bash
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/providers/normalize.sh"

claude_snapshot=$(normalize_claude_snapshot "$(cat "$ROOT/tests/fixtures/claude-usage.json")")
codex_snapshot=$(normalize_codex_snapshot "$(cat "$ROOT/tests/fixtures/codex-usage.json")")

jq -e '
  .provider_id == "claude-code-subscription"
  and .status == "live"
  and .source == "anthropic-oauth-usage"
  and .cache_key == "claude-code-subscription"
  and .fetched_at == null
  and .metadata.account_id == null
  and (.windows | length) == 3
  and .windows[0].remaining_percent == 57.5
  and .windows[1].scope == "account"
  and .windows[2].scope == "model"
  and .spend[0].currency == "USD"
' <<<"$claude_snapshot" >/dev/null

jq -e '
  .provider_id == "codex-subscription"
  and .source == "chatgpt-wham-usage"
  and (.windows | length) == 2
  and .windows[0].remaining_percent == 68
  and .windows[1].duration_seconds == 604800
  and .metadata.plan_type == "plus"
' <<<"$codex_snapshot" >/dev/null

claude_context=$(normalize_claude_snapshot \
  "$(cat "$ROOT/tests/fixtures/claude-usage.json")" cached claude-account demo-account \
  "2026-11-02T12:00:00Z")
jq -e '
  .status == "cached"
  and .cache_key == "claude-account"
  and .fetched_at == "2026-11-02T12:00:00Z"
  and .metadata.account_id == "demo-account"
' <<<"$claude_context" >/dev/null

if normalize_claude_snapshot '{"five_hour":{}}' >/dev/null 2>&1; then
  echo "invalid Claude payload unexpectedly normalized" >&2
  exit 1
fi

if normalize_codex_snapshot '{"rate_limit":{}}' >/dev/null 2>&1; then
  echo "invalid Codex payload unexpectedly normalized" >&2
  exit 1
fi

if normalize_claude_snapshot '{"five_hour":{"utilization":101}}' >/dev/null 2>&1; then
  echo "out-of-range Claude payload unexpectedly normalized" >&2
  exit 1
fi

if normalize_codex_snapshot '{"rate_limit":{"primary_window":{"used_percent":-1}}}' >/dev/null 2>&1; then
  echo "out-of-range Codex payload unexpectedly normalized" >&2
  exit 1
fi

if normalize_claude_snapshot "$(cat "$ROOT/tests/fixtures/claude-usage.json")" unknown >/dev/null 2>&1; then
  echo "invalid snapshot status unexpectedly accepted" >&2
  exit 1
fi

echo "Provider normalization checks passed"
