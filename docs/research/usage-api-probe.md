# Live OAuth Usage API Probe (wayfinder #6)

Probe date: 2026-08-04. Machine: Linux (Arch). All identifiers sanitized.

## Environment

- Installed Claude Code version: **2.1.221** (`claude --version`)
  - Bounds for stdin-field decisions: `rate_limits` (v2.1.80+) and `effort.level`/`fast_mode` (v2.1.140+) are safe to assume; `thinking` (~v2.2.0) is NOT available on this machine yet.
- Token resolution: env var `CLAUDE_CODE_OAUTH_TOKEN` was unset; token came from `~/.claude/.credentials.json` (`.claudeAiOauth.accessToken`). File exists and is current. `secret-tool` fallback not needed.

## Request

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <token>
anthropic-beta: oauth-2025-04-20
User-Agent: claude-code/2.1.221
Accept: application/json
```

HTTP 200. Sanitized response (structure preserved, identifiers replaced):

```json
{
  "five_hour": {
    "utilization": 10.0,
    "resets_at": "2026-08-04T16:20:00.001100+00:00",
    "limit_dollars": null,
    "used_dollars": null,
    "remaining_dollars": null
  },
  "seven_day": {
    "utilization": 29.0,
    "resets_at": "2026-08-06T19:00:00.001127+00:00",
    "limit_dollars": null,
    "used_dollars": null,
    "remaining_dollars": null
  },
  "seven_day_oauth_apps": null,
  "seven_day_opus": null,
  "seven_day_sonnet": null,
  "seven_day_cowork": null,
  "seven_day_omelette": null,
  "tangelo": null,
  "iguana_necktie": null,
  "omelette_promotional": null,
  "nimbus_quill": null,
  "cinder_cove": null,
  "amber_ladder": null,
  "extra_usage": {
    "is_enabled": false,
    "monthly_limit": 4000,
    "used_credits": 0.0,
    "utilization": 0.0,
    "currency": "EUR",
    "decimal_places": 2,
    "disabled_reason": "out_of_credits",
    "user_disabled": false,
    "spend_limit_reached": false,
    "credits_ever_enabled": true,
    "daily": null,
    "weekly": null
  },
  "limits": [
    {
      "kind": "session",
      "group": "session",
      "percent": 10,
      "severity": "normal",
      "resets_at": "2026-08-04T16:20:00.001100+00:00",
      "scope": null,
      "is_active": false
    },
    {
      "kind": "weekly_all",
      "group": "weekly",
      "percent": 29,
      "severity": "normal",
      "resets_at": "2026-08-06T19:00:00.001127+00:00",
      "scope": null,
      "is_active": false
    },
    {
      "kind": "weekly_scoped",
      "group": "weekly",
      "percent": 32,
      "severity": "normal",
      "resets_at": "2026-08-06T19:00:00.001438+00:00",
      "scope": {
        "model": { "id": "[REDACTED-MODEL-ID]", "display_name": "Fable" },
        "surface": null
      },
      "is_active": true
    }
  ],
  "spend": {
    "used": { "amount_minor": 0, "currency": "EUR", "exponent": 2 },
    "limit": { "amount_minor": 4000, "currency": "EUR", "exponent": 2 },
    "percent": 0,
    "severity": "normal",
    "enabled": false,
    "disabled_reason": "out_of_credits",
    "cap": {
      "money": { "amount_minor": 4000, "currency": "EUR", "exponent": 2 },
      "credits": null
    },
    "balance": null,
    "auto_reload": null,
    "disclaimer": "Usage credits cover you when you hit your plan limits. [Learn more](https://support.claude.com/articles/12429409)",
    "can_purchase_credits": false,
    "can_toggle": false
  },
  "member_dashboard_available": false
}
```

## Field presence

| Field | Present? | Value on this account |
|---|---|---|
| `five_hour` | yes (object) | utilization 10.0, resets_at, dollar fields all null |
| `seven_day` | yes (object) | utilization 29.0, resets_at, dollar fields all null |
| `seven_day_sonnet` | present, **null** | — |
| `seven_day_opus` | present, **null** | — |
| `seven_day_oauth_apps` | present, **null** | — |
| `seven_day_cowork` | present, **null** | — |
| `extra_usage.is_enabled` | yes | `false` (disabled_reason `out_of_credits`) |
| `extra_usage.monthly_limit` | yes | `4000` (minor units, EUR, 2 decimal places → €40.00) |
| `extra_usage.used_credits` | yes | `0.0` |
| `extra_usage.utilization` | yes, populated | `0.0` |

Undocumented fields observed:

- Top-level nulls that look like feature-flag/codename slots: `seven_day_omelette`, `tangelo`, `iguana_necktie`, `omelette_promotional`, `nimbus_quill`, `cinder_cove`, `amber_ladder`.
- **`limits[]`** — an array form of the same data, richer than the named objects: `{kind, group, percent, severity, resets_at, scope, is_active}`. Kinds seen: `session`, `weekly_all`, `weekly_scoped` (scoped carries `scope.model.display_name`, e.g. per-model weekly cap). `percent` is an integer 0-100. `is_active` marks which limit currently binds. This is arguably a better data source than the named `five_hour`/`seven_day` objects for a status line: it includes per-model scoped limits (32% here) that the named fields do NOT expose.
- **`spend`** — money-typed mirror of `extra_usage` (`amount_minor` + `exponent` + `currency`), plus `cap`, `balance`, `auto_reload`, `can_purchase_credits`, `can_toggle`, `disclaimer`.
- `extra_usage` extras: `currency`, `decimal_places`, `disabled_reason`, `user_disabled`, `spend_limit_reached`, `credits_ever_enabled`, `daily`, `weekly`.
- `member_dashboard_available` (bool).

## Utilization scale

Confirmed **0-100**: `five_hour.utilization` = 10.0, `seven_day.utilization` = 29.0 (floats), and `limits[].percent` = 10 / 29 / 32 (ints). Matching values across both representations confirm percent semantics, not 0-1 fractions.

## Error shape (invalid/expired token)

`Authorization: Bearer invalid` → **HTTP 401**:

```json
{
  "type": "error",
  "error": {
    "type": "authentication_error",
    "message": "Invalid bearer token",
    "details": { "error_visibility": "user_facing" }
  },
  "request_id": "req_..."
}
```

Standard Anthropic error envelope. v2 degradation can key on HTTP status 401 + `error.type == "authentication_error"`.

## Takeaways for the data-source decision

1. Utilization scale is 0-100; render as percent directly.
2. Model-scoped seven-day fields (`seven_day_sonnet`/`seven_day_opus`) are null on this account — but the `limits[]` array DOES carry a live per-model scoped weekly limit. Prefer `limits[]` if per-model display matters.
3. `extra_usage.utilization` is populated (0.0) even when `is_enabled` is false; don't treat presence as "extra usage active" — check `is_enabled`.
4. Installed version 2.1.221 → statusline stdin `rate_limits` and `effort`/`fast_mode` fields are available; `thinking` is not.
