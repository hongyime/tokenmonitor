# Provider adapter contract

OpenCode and Orca are not monitor providers. They are research sources for discovering upstream services, authentication methods, account handling, and usage patterns. Runtime adapters must target the underlying provider directly.

Every adapter must define:

- a stable provider ID and display name;
- discovery and authentication rules;
- endpoint URLs and required headers;
- token refresh behavior, if applicable;
- a raw response fixture with secrets removed;
- normalization into optional usage windows, credits, spend, and metadata;
- a provider-specific cache key and stale-data policy;
- tests for valid, malformed, unauthorized, rate-limited, and unavailable responses.

The current first-party normalizers live in `providers/normalize.sh`. They are deliberately pure: they accept provider-native JSON and emit a snapshot without performing network requests, reading credentials, or writing cache state.

Adapters must never invent percentages. If a provider does not report a quota or reset window, expose an explicit unsupported/unavailable capability instead.

The normalized shape is intentionally capability-based:

```json
{
  "provider_id": "example",
  "status": "live",
  "source": "provider-endpoint",
  "fetched_at": "2026-11-02T18:00:00Z",
  "cache_key": "example-account",
  "windows": [
    {
      "id": "primary",
      "used_percent": 42.5,
      "remaining_percent": 57.5,
      "reset_at": "2026-11-02T18:00:00Z",
      "duration_seconds": 18000,
      "scope": "account"
    }
  ],
  "credits": [],
  "spend": [],
  "metadata": {
    "account_id": "non-secret-account-identity"
  }
}
```

`status` describes provenance rather than quota health. Allowed values are
`live`, `cached`, `stale`, `unavailable`, `auth_error`, and `unsupported`;
`live` came from a successful request, `cached` came from a fresh cache entry,
and `stale` came from a cache retained after a transient fetch failure.
Account IDs and cache keys must be non-secret identities; never place access
or refresh tokens in a snapshot.
