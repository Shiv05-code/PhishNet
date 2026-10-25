# Scan API (backend)

The scan endpoint is an AWS Lambda function URL served by `backend/lambda/handler.py`.
Flow: app -> Lambda -> verify Firebase ID token -> Claude Haiku (or mock) -> Firestore -> JSON.

## Request

- Method: `POST`
- Header: `Authorization: Bearer <Firebase ID token>` (required, else `401`)
- Body (JSON):

```json
{"text": "message text from manual entry or OCR"}
```

Manual entry and OCR output send the same payload. Text is trimmed and truncated to 8000 characters. Empty text returns `400 {"error": "empty_message"}`.

Account deletion uses `{"action": "delete_account"}` and is unchanged.

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

## Mock mode

Set `MOCK_CLAUDE=true` to skip Claude. The handler then returns a fixed, deterministic result (score 85, `high`).

Limits: the mock verifies the endpoint, auth, request handling, and response shape. It does not test whether Claude can tell different messages apart. Use real mode for that.

## Deployment prerequisites

- Lambda env: `SECRET_ID` (defaults to `phishnet/prod`) and optionally `FIREBASE_PROJECT_ID`.
- Secrets Manager secret must contain `anthropic_api_key` and `firebase_service_account`.
- Lambda execution role needs `secretsmanager:GetSecretValue` on that secret.
- Dependencies from `backend/lambda/requirements.txt` plus `boto3` (provided by the Lambda runtime).
- Do not set `MOCK_CLAUDE=true` in production.

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
```

With `MOCK_CLAUDE=true`, the first request should return the fixed mock result. Without it, it calls Claude.
