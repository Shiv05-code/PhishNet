# Live Monitoring setup (Gmail)

Status: built and verified on iPhone (connect, status, push alerts, Turn Off, reconnect, one manual check). Scheduled checks are **not** enabled. Live Monitoring works with **Gmail accounts only**. Yahoo and other providers are not supported.

Plan and progress: [`live-monitoring.md`](live-monitoring.md).

## Google setup (one time)

1. In Google Cloud (project `phishnet-b93e0`), create a **Web application** OAuth client.
2. Add the connect Function URL as an **Authorized redirect URI**, with the trailing slash, exactly as the deploy script prints it.
3. Keep the consent screen in **Testing** mode. Add each tester's Gmail address under **Test users**. Testing-mode refresh tokens expire about every 7 days, so testers reconnect when prompted.
4. Scope: `gmail.readonly` only.

## AWS setup

Run `backend/scripts/deploy_monitor.sh`. It creates or updates:

- `phishnet-monitor-connect` (OAuth start and callback, device registration, status, Turn Off). Public Function URL, protected by a Firebase ID token on each request.
- `phishnet-monitor-poll` (Gmail checks and push alerts). No public URL.

Secrets:

- `phishnet/prod`: `gmail_client_id`, `gmail_client_secret`, `monitor_state_key`
- `phishnet/monitor-tokens`: one JSON map of user refresh tokens and mailbox checkpoints. Never in the app, never logged.

## Poll controls (keep off by default)

| Variable | Normal value | Meaning |
| --- | --- | --- |
| `MONITOR_ENABLED` | `false` | Master switch. Off means no Gmail checks |
| `MONITOR_UNTIL` | a date | Last UTC date a run may happen |
| `MONITOR_MAX_PER_RUN` | `1` | Messages analyzed per user per run (1 to 3) |

There is no schedule. Enable for one manual run to test, then turn `MONITOR_ENABLED` back to `false` and restore the cap to `1`.

## App build

The connect URL is built into the app. `flutter run` and `flutter run --profile` both connect without extra flags. `--dart-define=MONITOR_API_URL=...` still overrides it.

## Manual test checklist

1. **Connect:** Home card, tap Connect Gmail, approve, return. The card says "Monitoring your Gmail."
2. **Alert:** send a suspicious email to the Gmail account, run one check, and confirm a single notification and a Home card.
3. **Safe email:** a normal email produces no notification.
4. **Turn Off:** tap Turn Off, confirm. The card returns to "Live Monitoring is off."
5. **Reconnect:** tap Connect Gmail again and confirm the card returns to monitoring.

## Notes

- Turn Off revokes the token at Google (best effort), deletes the stored token, and stops monitoring. Revocation at Google is not yet verified on device, so check the Google Account's third-party access page if in doubt.
- A signed-out device still receives alerts, because the device token stays registered until the account is deleted.
