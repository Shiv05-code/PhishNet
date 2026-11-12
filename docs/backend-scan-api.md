# Scan API (backend)

The scan endpoint is an AWS Lambda function URL served by `backend/lambda/handler.py`.
Flow: app -> Lambda -> verify Firebase ID token (account or anonymous guest) -> Claude Haiku (or mock) -> Firestore (accounts only) -> JSON.

## Request

- Method: `POST`
- Header: `Authorization: Bearer <Firebase ID token>` (required, else `401`)
- Body (JSON):

```json
{"text": "message text from manual entry or OCR"}
```

Manual entry and OCR output send the same payload. Text is trimmed and truncated to 8000 characters. Empty text returns `400 {"error": "empty_message"}`.

Account deletion uses `{"action": "delete_account"}` and is unchanged.

## Free-tier daily limit

Free accounts, including guests, can make **10 requests per day** across Capture scans and AI Chat questions. Active Plus subscribers have no limit.

- A scan counts as 1 and each chat question counts as 1. A photo sent with a question in AI Chat is a scan plus a question, so it counts as 2. `chat_title` never counts.
- The day runs midnight to midnight Pacific time (`America/Los_Angeles`, including daylight saving), so usage resets at midnight Pacific.
- The count is checked **before** Claude is called. Requests that fail validation (`400`) do not count, and a request that fails because Claude failed (`502`) is given back.
- Counts are stored at `users/{uid}/usage/{YYYY-MM-DD}` as `{day, count, updatedAt}`. Only the backend can reach this collection, because `firestore.rules` has no rule for it. The documents are deleted with the account.
- A guest is counted on their anonymous Firebase account, so deleting and reinstalling the app gives a guest a fresh count.
- Plus means `users/{uid}/subscriptions/current` has `plan == "plus"`, `status == "active"`, `environment == "production"` and an `expiresAt` in the future. Guests are never Plus.
- If Firestore is not set up (local or placeholder service account), no limit is applied. If it is set up but the count cannot be read, the request is refused with `503 {"error": "usage_unavailable", "retryable": true}` rather than letting it through to Claude.
- `FREE_DAILY_LIMIT` (environment variable, default `10`) changes the number without a code change.

Past the limit, scans and chat questions return:

```json
{
  "error": "daily_limit_reached",
  "message": "You've reached today's limit of 10 free requests.",
  "limit": 10,
  "resets_at": "2026-11-13T08:00:00Z",
  "retryable": false
}
```

with status `429`. `resets_at` is the next midnight Pacific in UTC; the app shows it in the phone's own time zone.

## Who can call it

Every request needs `Authorization: Bearer <Firebase ID token>`.

| Caller | Token | Scan | Saved to Firestore | `scan_history` / `delete_account` |
| --- | --- | --- | --- | --- |
| Account user | Firebase ID token | Allowed | Yes | Allowed |
| Guest | Firebase Anonymous token | Allowed | No | `403 {"error": "account_required"}` |
| No or invalid token | none | `401` | No | `401` |

Guests get a token from `AuthService.signInAsGuest()`, used by both the Login and Sign Up "Continue as guest" links. **Anonymous** sign-in must be enabled in the Firebase console (Authentication > Sign-in method).

## Success response (`200`)

```json
{
  "brief_description": "A delivery message asks you to pay a fee.",
  "scam_percentage": 80,
  "risk_level": "high",
  "summary": "This may be a fake delivery notice. Check with the delivery company before paying.",
  "red_flags": [
    {
      "category": "money_request",
      "label": "Money request",
      "description": "Asks you to pay a fee.",
      "icon": "payments"
    },
    {
      "category": "suspicious_link_or_contact",
      "label": "Suspicious link or contact",
      "description": "Uses an unfamiliar link.",
      "icon": "link"
    }
  ],
  "next_steps": ["Do not click the link", "Contact the store directly"]
}
```

- `scam_percentage`: integer 0-100. A heuristic estimate, not a calibrated probability.
- `risk_level`: derived from the score: `low` 0-33, `medium` 34-66, `high` 67-100.
- `red_flags`: may be empty. Each flag has a stable `category` for analytics, a plain `label`, a short `description`, and a stable Material icon name. `next_steps`: at least one item.
- Output is intentionally concise and plain-language: one short description, a 1-2 sentence summary, at most 4 red flags and 3 next steps.
- The engine uses a warm, respectful helper tone without greetings or filler. Categories are fixed: `money_request`, `credential_request`, `personal_information_request`, `urgency_or_pressure`, `suspicious_link_or_contact`, `impersonation`, `unusual_payment_method`, `unexpected_attachment`, `mismatched_context`, and `other`. The `category` is the analytics key; icon names are presentation hints and should be mapped to available app icons.

| Category | Reader-friendly label | Icon key |
| --- | --- | --- |
| `money_request` | Money request | `payments` |
| `credential_request` | Password or sign-in request | `lock` |
| `personal_information_request` | Personal information request | `person` |
| `urgency_or_pressure` | Pressure or urgency | `schedule` |
| `suspicious_link_or_contact` | Suspicious link or contact | `link` |
| `impersonation` | Possible impersonation | `person_search` |
| `unusual_payment_method` | Unusual payment method | `currency_exchange` |
| `unexpected_attachment` | Unexpected attachment | `attach_file` |
| `mismatched_context` | Unexpected or mismatched details | `compare_arrows` |
| `other` | Other warning sign | `warning_amber` |

Claude's output is validated before it is returned. Missing fields, wrong types, a score out of range, a risk level that does not match the score, or no tool output all produce the error below.

## Retryable error (`502`)

```json
{
  "error": "analysis_unavailable",
  "message": "We couldn't check this message right now. Please try again.",
  "retryable": true
}
```

Raw provider errors are never returned. Logs record only the error type, never the message text.

## Other responses

- `401 {"error": "unauthorized"}`: missing or invalid token.
- `400 {"error": "empty_message"}`: no text.
- `500 {"error": "server_error", "retryable": true}`: unexpected failure.
- `403 {"error": "account_required"}`: a guest called `scan_history` or `delete_account`.
- `502 {"error": "chat_unavailable", "retryable": true}`: chat answer failed.
- `429 {"error": "daily_limit_reached", ...}`: a free user used all of today's requests (see Free-tier daily limit).
- `503 {"error": "usage_unavailable", "retryable": true}`: today's count could not be read.

### How the app handles errors

| Situation | App message | Retry |
| --- | --- | --- |
| Offline | "No internet connection. Check your connection and try again." | Yes |
| Timeout (60 s client limit) | "The check is taking longer than expected. Please try again." | Yes |
| 5xx | "PhishNet could not check this message right now. Please try again." | Yes |
| 401 / 403 | "Your session could not be verified. Please sign in again." | No |
| 429 `daily_limit_reached` | "You've reached today's limit of 10 free requests. It resets tomorrow at 12:00 AM." (reset time in the phone's time zone) | No |

Capture keeps the submitted text on failure and offers a Retry action.

## Mock mode

Set `MOCK_CLAUDE=true` to skip Claude. Returns one of three fixed sample results (high, medium, low).

Limits: the mock verifies the endpoint, auth, request handling, and response shape. It does not test whether Claude can tell different messages apart. Use real mode for that.

## AWS configuration

Checked on 11/03/26.

| Item | Value |
| --- | --- |
| Function | `phishnet-scan` |
| Region | `us-east-2` |
| Runtime / handler | Python 3.12 / `handler.handler` |
| Function URL auth type | `NONE` (the handler verifies the Firebase token itself) |
| Timeout | 35 seconds. Raise it if scans start timing out |
| Environment variables | `MOCK_CLAUDE` only. Optional: `SECRET_ID` (default `phishnet/prod`), `FIREBASE_PROJECT_ID` (default `phishnet-b93e0`), `CHAT_MODEL` (default `claude-sonnet-5-5`), `FREE_DAILY_LIMIT` (default `10`) |
| Execution role | `phishnet-scan-execution-role` |

The app uses the Function URL as the default in `lib/services/scan_service.dart` and can override it with `--dart-define=SCAN_API_URL=<url>`.

### Secrets

Credentials are read from AWS Secrets Manager at cold start. They are never in the app, the repository, or environment variables, and the code never logs them.

| Secret name | Region | Required keys |
| --- | --- | --- |
| `phishnet/prod` | `us-east-2` | `anthropic_api_key`, `firebase_service_account` |

If `firebase_service_account` is missing or a placeholder, token verification still works but Firestore writes are disabled.

### IAM (least privilege)

Execution role for `phishnet-scan`:

- AWS managed `AWSLambdaBasicExecutionRole` (CloudWatch Logs)
- Inline policy allowing only `secretsmanager:GetSecretValue` on the `phishnet/prod` secret
- `kms:Decrypt` only if the secret uses a customer-managed key

Trust policy: `lambda.amazonaws.com` only. Verified with a real scan on 11/03/26, with no `AccessDenied` in CloudWatch.

### Deploying

1. Change `backend/lambda/handler.py` and run the tests below.
2. Deploy to `phishnet-scan` (upload the zip with its libraries, or paste the handler in the console editor). Deploy from the repo version so AWS and git stay identical.
3. Confirm the environment variables and role are unchanged, then run the smoke tests.

Do not set `MOCK_CLAUDE=true` in production.

## Tests

Tests use `unittest` (no extra dependencies) and mock Claude, Firebase, and Secrets Manager:

```sh
cd backend
python -m unittest discover -s tests
```

The tests need the packages from `requirements.txt` installed. Nothing here calls AWS or Anthropic.

## Curl smoke tests

Replace `$URL` with the function URL and `$TOKEN` with a Firebase ID token.

```sh
# Valid request
curl -sS -X POST "$URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"text":"Your parcel is held. Pay 2 dollars at http://example.test"}'

# No token: expect 401
curl -sS -X POST "$URL" -H "Content-Type: application/json" -d '{"text":"hi"}'

# Empty text: expect 400
curl -sS -X POST "$URL" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{"text":"  "}'

# Invalid token: expect 401
curl -sS -X POST "$URL" -H "Authorization: Bearer not-a-real-token" \
  -H "Content-Type: application/json" -d '{"text":"hi"}'
```

A successful request returns `200` with `brief_description`, `scam_percentage`, `risk_level`, `summary`, `red_flags` and `next_steps`. The easiest way to get `$TOKEN` is to scan from the app while signed in. Guest check: scan as a guest and confirm no document appears under `users/{uid}/scans`.

With `MOCK_CLAUDE=true`, the first request should return a sample mock result. Without it, it calls Claude.

## Live Monitoring: scheduled processing (planned)

The resources exist but are **disabled** and do no real work.

| Resource | Name | Notes |
| --- | --- | --- |
| Worker Lambda | `phishnet-monitor-worker` | Placeholder that logs one line. Own logging-only role |
| EventBridge Scheduler schedule | `phishnet-monitor-schedule` | `rate(2 minutes)` (planned every 1-2 minutes), **Disabled** |
| Scheduler execution role | `Amazon_EventBridge_Scheduler_LAMBDA_...` | `lambda:InvokeFunction` on the worker only |

The schedule does **not** target `phishnet-scan`: that handler requires a Firebase bearer token, which a scheduled event does not carry. Mailbox polling needs its own worker.

- **Enable:** set the schedule to Enabled, only after the worker is implemented.
- **Disable or remove:** toggle it off or delete the schedule.
- **Overlap:** consider reserved concurrency of 1 on the worker.
- **Out of scope for this issue:** Yahoo authorization, mailbox polling, user alerts. The future worker will need its own secrets and a narrowly scoped role.