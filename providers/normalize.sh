#!/bin/bash

# Provider-native response -> capability-based snapshot normalization.
# Functions print one compact JSON snapshot and return non-zero for invalid data.

JQ_BIN="${JQ_BIN:-jq}"

valid_snapshot_status() {
  case "$1" in
    live|cached|stale|unavailable|auth_error|unsupported) return 0 ;;
    *) return 1 ;;
  esac
}

normalize_claude_snapshot() {
  local raw="$1"
  local status="${2:-live}"
  local cache_key="${3:-claude-code-subscription}"
  local account_id="${4:-}"
  local fetched_at="${5:-}"
  valid_snapshot_status "$status" || return 2
  printf '%s' "$raw" | "$JQ_BIN" -e '
    if (
      (.five_hour.utilization | type) == "number"
      and .five_hour.utilization >= 0
      and .five_hour.utilization <= 100
    ) then {
      provider_id: "claude-code-subscription",
      status: $status,
      source: "anthropic-oauth-usage",
      fetched_at: (if $fetched_at == "" then null else $fetched_at end),
      cache_key: $cache_key,
      windows: (
        [
          {
            id: "five_hour",
            label: "5h",
            used_percent: (.five_hour.utilization | tonumber),
            remaining_percent: (100 - (.five_hour.utilization | tonumber)),
            reset_at: (.five_hour.resets_at // null),
            duration_seconds: 18000,
            scope: "account"
          }
        ]
        + (if (
          (.seven_day.utilization | type) == "number"
          and .seven_day.utilization >= 0
          and .seven_day.utilization <= 100
        ) then [{
          id: "seven_day",
          label: "7d",
          used_percent: (.seven_day.utilization | tonumber),
          remaining_percent: (100 - (.seven_day.utilization | tonumber)),
          reset_at: (.seven_day.resets_at // null),
          duration_seconds: 604800,
          scope: "account"
        }] else [] end)
        + ([
          { id: "seven_day_opus", label: "7d Opus", value: .seven_day_opus },
          { id: "seven_day_sonnet", label: "7d Sonnet", value: .seven_day_sonnet }
        ] | map(select(
          (.value.utilization | type) == "number"
          and .value.utilization >= 0
          and .value.utilization <= 100
        ) | {
          id,
          label,
          used_percent: (.value.utilization | tonumber),
          remaining_percent: (100 - (.value.utilization | tonumber)),
          reset_at: (.value.resets_at // null),
          duration_seconds: 604800,
          scope: "model"
        }))
      ),
      credits: [],
      spend: (if .spend then [{
        used_minor: (.spend.used.amount_minor // null),
        limit_minor: (.spend.limit.amount_minor // null),
        currency: (.spend.limit.currency // null)
      }] else [] end),
      metadata: {
        subscription_type: (.subscriptionType // null),
        account_id: (if $account_id == "" then null else $account_id end)
      }
    } else error("invalid Claude usage payload") end
  ' --arg status "$status" --arg cache_key "$cache_key" \
    --arg account_id "$account_id" --arg fetched_at "$fetched_at"
}

normalize_codex_snapshot() {
  local raw="$1"
  local status="${2:-live}"
  local cache_key="${3:-codex-subscription}"
  local account_id="${4:-}"
  local fetched_at="${5:-}"
  valid_snapshot_status "$status" || return 2
  printf '%s' "$raw" | "$JQ_BIN" -e '
    if (
      (.rate_limit.primary_window.used_percent | type) == "number"
      and .rate_limit.primary_window.used_percent >= 0
      and .rate_limit.primary_window.used_percent <= 100
    ) then {
      provider_id: "codex-subscription",
      status: $status,
      source: "chatgpt-wham-usage",
      fetched_at: (if $fetched_at == "" then null else $fetched_at end),
      cache_key: $cache_key,
      windows: (
        [
          {
            id: "primary",
            label: "primary",
            used_percent: (.rate_limit.primary_window.used_percent | tonumber),
            remaining_percent: (100 - (.rate_limit.primary_window.used_percent | tonumber)),
            reset_at: (.rate_limit.primary_window.reset_at // null),
            duration_seconds: (.rate_limit.primary_window.limit_window_seconds // null),
            scope: "account"
          }
        ]
        + (if (
          (.rate_limit.secondary_window.used_percent | type) == "number"
          and .rate_limit.secondary_window.used_percent >= 0
          and .rate_limit.secondary_window.used_percent <= 100
        ) then [{
          id: "secondary",
          label: "secondary",
          used_percent: (.rate_limit.secondary_window.used_percent | tonumber),
          remaining_percent: (100 - (.rate_limit.secondary_window.used_percent | tonumber)),
          reset_at: (.rate_limit.secondary_window.reset_at // null),
          duration_seconds: (.rate_limit.secondary_window.limit_window_seconds // null),
          scope: "account"
        }] else [] end)
      ),
      credits: (if .credits then [{
        balance: (.credits.balance // null),
        unlimited: (.credits.unlimited // null)
      }] else [] end),
      spend: [],
      metadata: {
        plan_type: (.plan_type // null),
        account_id: (if $account_id == "" then null else $account_id end)
      }
    } else error("invalid Codex usage payload") end
  ' --arg status "$status" --arg cache_key "$cache_key" \
    --arg account_id "$account_id" --arg fetched_at "$fetched_at"
}
