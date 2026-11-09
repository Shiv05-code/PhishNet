# Live Monitoring setup (Yahoo connection)

Status: Yahoo connection code is written and tested with mocks. Nothing is deployed yet. Connecting does not start automatic checks; scheduled scanning is not built yet.

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

The monitoring card is on the **History** screen (not Settings).

1. **Without the define:** run the app without `MONITOR_API_URL`. The card should not appear on History.
2. **Status:** after setup steps 1–7, the card shows "Check my Yahoo email for scams" with a "Connect Yahoo" button.
3. **Deny:** tap Connect Yahoo, then deny consent in Yahoo. Return to the app. It should show "Yahoo email is not connected" with the message "Couldn't reach…" or the consent error, and Secrets Manager should have no `phishnet/monitor/<uid>` secret.
4. **Connect:** tap Connect Yahoo again, approve, return to the app. It should show "Yahoo email is connected" and say automatic checks are not active yet. It must not say emails are being checked.
5. **Turn off:** tap Turn off. The card returns to "Check my Yahoo email for scams", and the `phishnet/monitor/<uid>` secret should be gone.

## Failure handling

- Consent denied: status becomes `disconnected`, and the screen explains access is needed.
- Expired or forged state: the callback is rejected and nothing is stored.
- Token exchange failure: status becomes `error`, and the user can retry.
- Turn off: the token secret is deleted first. If that fails, status is unchanged and the app asks the user to retry.

## Not done yet

- Disconnect does not call Yahoo's revocation. Revoke the grant in Yahoo's account settings if needed.
- "Actively monitored", the scheduled worker, and FCM alerts are Phases 3 and 4.
