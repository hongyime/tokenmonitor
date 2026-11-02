# Provider research and implementation plan

Updated 2026-11-02. OpenCode and Orca are research sources only. Runtime adapters target the underlying service or coding-plan account directly.

## What OpenCode contributes

OpenCode uses AI SDK and Models.dev metadata to describe 75+ providers. Its integration system separates:

- provider identity and display metadata;
- authentication methods such as API key, OAuth, command, external flow, and environment variables;
- stored credentials and active connections;
- provider configuration such as custom base URLs and model allow/deny lists.

This is useful for our catalog and auth discovery, but it does not provide a universal quota endpoint. The same upstream provider can also be configured with a custom proxy, so provider identity and endpoint identity must remain separate in our model.

Sources:

- OpenCode provider docs: <https://opencode.ai/docs/providers/>
- OpenCode integration model: `packages/core/src/integration.ts`
- OpenCode auth handlers: `packages/cli/src/commands/handlers/auth/`
- OpenCode provider implementations: `packages/ai/src/providers/`

## What Orca contributes

Orca has a reusable design pattern: each usage source has its own credential reader, request client, response validator, mapper, error classification, and tests. Its usage documentation says it tracks:

| Provider/source | Orca evidence | Likely monitor capability | Priority |
|---|---|---|---:|
| Claude Code | `api.anthropic.com/api/oauth/usage` | Subscription windows | Already implemented |
| OpenAI Codex | `chatgpt.com/backend-api/wham/usage` | Subscription windows and reset credits | Already implemented |
| Gemini CLI | `cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota` | Model quota buckets and reset times | P0 |
| Grok | CLI proxy billing endpoints | Weekly/monthly allowance or credits | P1 |
| Cursor | Cursor dashboard usage endpoints with session cookie | Current-period allowance | P1 |
| Kimi Code | CLI-selected `/usages` endpoint | Weekly and short rolling windows | P1 |
| OpenCode Go | Provider-specific usage source | Subscription windows | P1 |
| Z.ai Coding Plan | Dedicated usage endpoint | Subscription windows | P2 |
| Antigravity | Dedicated usage command/fetcher | Subscription/runtime quota | P2 |
| MiniMax | Dedicated usage source | Subscription windows | P2 |

Important Orca patterns to copy conceptually, not code:

1. Read credentials without taking ownership of refresh when the CLI owns refresh.
2. Keep account provenance attached to every snapshot so switching accounts cannot display stale data.
3. Validate response shape before mapping numbers.
4. Preserve stale data only for transient failures, and distinguish it from unavailable or unauthorized.
5. Treat unlimited plans and missing denominators as unknown, not as 0% or 100%.
6. Map provider-specific windows into a common envelope while retaining provider-specific metadata.

Sources:

- Orca usage docs: <https://www.onorca.dev/docs/agents/usage-tracking>
- Orca rate-limit modules: `src/main/rate-limits/`
- Orca normalized rate-limit types: `src/shared/rate-limit-types.ts`

## Adapter contract for this repository

Each adapter should have:

```text
discover()       -> whether the native account/config exists
read_auth()      -> redacted auth material or an explicit auth error
fetch_raw()      -> provider request with timeout and status classification
validate(raw)    -> schema/required-field check
normalize(raw)   -> ProviderSnapshot
cache_key()      -> provider + account identity, never the secret
```

The shared snapshot must support:

- `status`: `live`, `cached`, `unavailable`, `auth_error`, `unsupported`;
- zero or more windows with optional percentage, reset, duration, and scope;
- credits/spend as provider-specific optional values;
- account and plan labels;
- error/failure metadata;
- source and fetch timestamp.

The renderer must only calculate pace, burnout, threshold alerts, and reset reminders for windows with valid percentages and reset timestamps.

## Implementation sequence

### Phase 1: extraction without UI change

Extract Claude and Codex parsing into adapter-shaped functions and add redacted fixtures for:

- live success;
- stale-cache fallback;
- 401 and token refresh;
- 429;
- malformed JSON;
- missing primary/secondary windows;
- reset timestamps in each supported format.

Keep the current shell and PowerShell output unchanged.

### Phase 2: shared snapshot engine

Create one provider-neutral snapshot schema and make both platform scripts consume serialized snapshots. Keep platform-specific credential readers only where the OS requires it (Keychain versus Windows credential files).

### Phase 3: Gemini CLI

Implement the first new adapter because Orca demonstrates a concrete quota response with `remainingFraction`, `resetTime`, and `modelId`, plus OAuth refresh handling. Mark the endpoint as a private CLI contract and gate it behind strict schema validation.

### Phase 4: Grok, Cursor, and Kimi

Add these independently. Do not combine them merely because Orca supports them: their credentials, endpoints, failure states, and quota semantics differ.

### Phase 5: public API/billing adapters

Add OpenRouter, OpenAI API usage, and Anthropic organization usage separately from Codex/Claude subscription adapters. API spend is not interchangeable with subscription quota.

## Research rules

- OpenCode and Orca source is architectural prior art, not a runtime dependency.
- Prefer official documented APIs; label private CLI/dashboard endpoints explicitly.
- Never copy provider secrets, raw credentials, or live response data into fixtures.
- Never infer a quota percentage from tokens or dollars unless the provider supplies both numerator and denominator.
- Do not show a number for an unsupported or unknown capability.
- Every adapter must have a contract test before it appears in the user-facing catalog as implemented.
