# Live Monitoring setup (Yahoo connection)

Status: Phase 2 code is written and tested with mocks. Nothing is deployed yet.

## Before you start: Yahoo approval

- Yahoo needs your app to have the **mail** scope. Check this in the Yahoo developer console when you create the app. If it is not offered or needs review, the connection will fail until Yahoo approves it.
- Yahoo app passwords are **not** a substitute. Our flow uses OAuth.
- I could not confirm Yahoo's current approval process. Community reports are dated; see [K-9 Mail issue #1698](https://github.com/thunderbird/thunderbird-android/issues/1698). Confirm in Yahoo's developer docs.

## Do the keys now or later?

Later, in this order. Each step needs the one before it.

1. Create the Yahoo app. You get the client ID and secret.
2. Generate the state key (any random string, never shared):
   `python3 -c "import secrets; print(secrets.token_urlsafe(48))"`
3. Add three keys to `phishnet/prod` in Secrets Manager: `yahoo_client_id`, `yahoo_client_secret`, `monitor_state_key`.
4. Create the Lambda and its Function URL (below), then put that URL into `YAHOO_REDIRECT_URI` and into the Yahoo app's redirect URI.

Do not paste any key into chat, code, or docs.

## Setup, step by step

1. **Yahoo app:** developer.yahoo.com, create an app with the mail scope. Note the client ID and secret.
2. **Secrets:** add the three keys above to `phishnet/prod`.
3. **Lambda:** in us-east-2, create `phishnet-monitor-connect`, Python 3.12, handler `connect.handler`. Upload `backend/monitor/connect.py`.
4. **Function URL:** enable it, auth type `NONE`.
5. **Environment variable:** `YAHOO_REDIRECT_URI` = the Function URL.
6. **Yahoo redirect:** set the Yahoo app's redirect URI to the same Function URL.
7. **Lambda role:** allow `GetSecretValue` on `phishnet/prod`, and `CreateSecret`, `PutSecretValue`, `GetSecretValue`, `DeleteSecret` on `phishnet/monitor/*`.

## Manual verification

Run the app with `--dart-define=MONITOR_API_URL=<Function URL>`, signed in with an account (not guest).

1. **No setup needed (check the screen only):** run the app without the define. Settings → Live Monitoring should show "Unavailable".
2. **Status:** after steps 1–7, the screen shows "Not connected".
3. **Deny:** tap Connect Yahoo, then deny consent. It should say "Access needed", and Secrets Manager should have no `phishnet/monitor/<uid>` secret.
4. **Connect:** tap Try again, approve, return to the app. It should say "Connected" and note that automatic checks aren't active yet.
5. **Disconnect:** tap Disconnect Yahoo and confirm. The `phishnet/monitor/<uid>` secret should be gone.

## Failure handling

- Consent denied: status becomes `disconnected`, and the screen explains access is needed.
- Expired or forged state: the callback is rejected and nothing is stored.
- Token exchange failure: status becomes `error`, and the user can retry.
- Disconnect: the token secret is deleted first. If that fails, status is unchanged and the app asks the user to retry.

## Not done yet

- Disconnect does not call Yahoo's revocation. Revoke the grant in Yahoo's account settings if needed.
- "Actively monitored", the scheduled worker, and FCM alerts are Phases 3 and 4.
