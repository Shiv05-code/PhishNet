# Live Monitoring (Gmail) — Plan

Status: **PLAN ONLY. Not approved for implementation.** Do not change
production-facing app copy or legal text until Gmail monitoring passes
end-to-end verification.

Branch: `Sk-live-monitoring` (merged with `main` in `495930c`).
Issue: [#70](https://github.com/Shiv05-code/PhishNet/issues/70), with Gmail
replacing Yahoo. Sub-issues: #71 Connect, #72 Checks, #73 Notification.

## 1. Decision

Gmail API with `gmail.readonly`, polled by the existing AWS Lambda pattern,
running in Google Cloud **Testing** mode with a small allowlist of test users.

Why this option:
- **Free and no approval wait.** Gmail API calls are free. Test users are
  added in the Console immediately. Google's verification and paid CASA
  assessment are skipped.
- **Right size.** Expected users: the 5 team members, the professor, and up to
  about 10–20 classmates by semester end. That's well under the 100 test-user
  cap.
- **Reuses what we have.** Same connect pattern as
  `backend/monitor/connect.py`, same scan path as `backend/lambda/handler.py`,
  Firebase Admin for FCM, Firestore for scans.

Accepted tradeoffs:
- Refresh tokens expire about every **7 days** in Testing mode. Users must
  reconnect with a Google sign-in. (Verify the exact behavior in Google's
  current OAuth docs before Phase 1.)
- Each tester must be added by email in the Google Cloud Console. The
  "unverified app" screen appears during consent. Users click **Advanced →
  Continue**. Provide a screenshot guide.

Rejected: Apps Script (script runs as its owner, so one central script can't
read other users' mail; per-user copies are too hard). Gmail forwarding to SES
(needs a domain and an 8-tap filter setup per user). IMAP app passwords
(stores user passwords). Yahoo (approval never came back).

## 2. Architecture (reuses existing pieces)

```
Home monitoring card ──(Firebase ID token)──▶ connect Lambda (existing pattern)
                                                  │ refresh token → ONE Secrets Manager secret (map: uid → token)
                                                  ▼
EventBridge Scheduler (one schedule, daily 12:00 Pacific) ──▶ poll Lambda
                                                  │ history.list since per-user historyId
                                                  │ messages.get → existing analyze pipeline
                                                  ▼
                              Firestore users/{uid}/scans (source = "gmail_monitor")
                                                  │ high-risk only, deduped, batched
                                                  ▼
                                       FCM via existing firebase_admin
```

- **One secret, not one per user.** Secrets Manager charges about $0.40 per
  secret per month. A single JSON map of `uid → refresh token, historyId,
  status` costs about $0.40/month total, regardless of user count.
- **One schedule, not one per user.** The poll Lambda loops over connected
  users with a per-run cap.
- **Checkpoint** per user (`historyId`). If Gmail returns 404 for an expired
  `historyId`, do a bounded resync (`newer_than:1d`) and store the new ID.
- **Daily cap** per user on scans (for example 50/day) so cost stays bounded.
- **Dedupe** key: `gmail:{uid}:{messageId}`. Scan writes are idempotent, so
  retries can't double-count.
- **Scan provenance:** `source` = `gmail_monitor` or `manual`, written by the
  backend only. Firestore rules already block client writes to scans.

## 3. Phased plan

Phase 4 (provenance badges) is partly done: History badges are built (Plus only). The Results badge is still open. History filtering was approved 2026-11-21 and is built (Plus only).

### Phase 0 — Google Cloud setup (manual, team)
- Create a Google Cloud project. Enable the Gmail API.
- Configure the OAuth consent screen (External, Testing), add the
  `gmail.readonly` scope, and add test users (team + professor + volunteers).
- Create an OAuth client for the Lambda callback.
- Record setup steps in `docs/live-monitoring-setup.md`.

### Phase 1 — Backend
- Replace `backend/monitor/connect.py` Yahoo specifics with Gmail
  (`authorize` URL, `gmail.readonly`, `access_type=offline`, `prompt=consent`).
  Keep signed `state`, the Firebase ID token check, and the token storage
  pattern, but write to the single shared secret.
- Poll Lambda: bounded per run, `historyId` checkpoint, idempotent writes,
  per-user daily cap, retries with backoff, reauth state on `invalid_grant`.
- Scan write sets `source`.
- High-risk-only FCM, batched per run, one alert per scan ID.
- Disconnect: revoke the token at Google, remove the user's entry from the
  secret, clear checkpoint state.
- Schedule stays **disabled** until Phase 5.
- Tests: auth boundary, token never logged, expired `historyId` resync, dedupe,
  safe-email silence, batching, cap, reauth, disconnect.
- **Pause for review.**

### Phase 2 — App flow
- Status: built and verified on iPhone (2026-11-19 to 2026-11-21). Commit `f575e6f`.
- Remove the monitoring card from History. Done (card and local prefs removed).
- Use the Home card as the only entry point. States: Off, Connected, Checking,
  **Paused — reconnect needed (token expired)**, Error, Unavailable. Tap to
  connect or reconnect. Done.
- Home attention cards for high-risk alerts. Tap opens that analysis in
  Results. Done.
- Large tap targets (48pt buttons), plain language, status announced to screen
  readers.
- Status comes from the backend (`status` action), never from local prefs.
  Done. Yahoo wording removed from the Home card and monitoring service.
- Non-Plus users see generic copy and never trigger a status call. Done.
- Turning off asks for confirmation. Done.
- Fixed: a build without `--dart-define=MONITOR_API_URL` now shows "Live Monitoring unavailable." The connect URL is also the default, so `flutter run` and `flutter run --profile` both connect.
- Loading state: show the existing `SwimmingFish` animation with short rotating
  phrases (for example "Casting a line…", "Reeling in your inbox…",
  "Checking the waters…", "Scanning the depths…"). Approved idea, not built yet.
- **Pause for review.**

### Phase 3 — Notifications
- Status: verified on iPhone (2026-11-21): foreground, background, closed, locked, and signed out. Commit `f575e6f`. Android deferred.
- Add `firebase_messaging`. Configure iOS (APNs). Android deferred: the app is
  iOS-only for now.
- Device tokens are stored by the backend (`register_device` action) under
  `users/{uid}/devices`, hashed doc IDs. Client rules are unchanged, and the
  client never reads that path.
- Push text is generic ("Possible scam found") and never includes email content.
  Sent only for new high-risk alerts, one per run. Dead tokens are removed.
- The menu and Home show the unread count only for Plus users, and only for
  live-monitoring alerts. Manual checks never count toward it.
- Persisted unread count. Red menu badge when unread and not on Home. Drawer
  emphasizes Home. Selecting Home shows status and the attention card.
- System notification tap → Home → alert card → Results.
- Verify foreground, background, and terminated launch. No duplicates, no lost
  navigation.
- **Pause for review.**

### Phase 4 — Provenance badges (DEFERRED)
- Until Live Monitoring is complete. `source` is already stored from Phase 1.

### Phase 5 — End-to-end verification
- Connect and deny; monitoring check; scan saved with source; safe (no alert)
  and high-risk (one alert) outcomes; both notification paths; deep links;
  retries; token expiry shows the reconnect state; disconnect and revocation.
- Enable the schedule only after this passes.
- **Pause for review.**

### Phase 6 — Yahoo cleanup, then docs (done 2026-11-21: Gmail-only wording in app copy, privacy, terms, setup guide, README; sign-up still accepts Yahoo addresses)
- Keep provider-neutral pieces (state signing, dedupe, worker loop) under
  neutral names. Remove Yahoo connect, `mail-r`, Yahoo config, and tests.
- Replace History-based monitoring tests with Home-flow tests.
- Inspect branch and remote state before any history change.
- Docs and legal copy last: README, setup guide, backend docs, privacy policy
  (Markdown and in-app), Terms. Claims must match verified behavior.
- **Pause for review.**

## 3.1 Access, limits, and schedule (decided)

**Entitlement: Plus only.**
- Live Monitoring is available only when `_has_active_plus` is true
  (`backend/lambda/handler.py:265`): `users/{uid}/subscriptions/current` with
  `plan == "plus"`, `status == "active"`, `environment == "production"`, and a
  future `expiresAt`. Reuse this gate. Do not add a new plan name.
- **Team grants:** an admin script (Admin SDK, run locally, not in the app)
  writes that same document for the team's primary account, with a
  `grantedBy: "team"` field so these records are easy to find and remove.
  Firestore rules already block client writes, so users can't grant themselves.
- **Real entitlement, not a demo mode.** The team's primary account gets a real
  `plus` record (`grantedBy: "team"`, `expiresAt` set). The app shows the same
  Plus UI a paying user would see. No yellow demo banner.
- **Plus badge:** a small "Plus" pill in the app bar, beside the title. It stays
  fixed while scrolling and doesn't cover content or taps. Shown only when the
  entitlement is active.
- **Non-paid users** see the Home card as a locked state with plain text
  ("Live Monitoring is part of PhishNet Plus"). No Gmail connect, no reads.
- **Demo account:** the non-paid test account stays unpaid, so the team can
  test both UIs.

**Read limit: 1 check per user per day.**
- Scheduled at **12:00 Pacific**, using EventBridge Scheduler with a timezone
  setting (not a fixed UTC cron), so daylight saving time is handled.
- Each run reads only mail since that user's last checkpoint. The first run
  after connecting looks back **24 hours only**, never a full backfill.
- The check counts against a separate per-user monitoring counter, not the
  free daily scan limit (`FREE_DAILY_LIMIT`).
- Manual "check now": **not in the app for now.** For the class demo, the
  admin script can trigger one run for a named user. Adding a user-facing
  button would add cost and needs its own limit.
- Mail that arrives after 12:00 is checked the next day. Say this in the UI
  ("Checks once a day at noon").
- Keep the 12:00 run. It costs nothing when there is no mail. For a manual
  demo, the admin script can run a check on demand.

## 3.2 Claude cost controls and analysis input

Goal: robust analysis for real phishing signals, with predictable cost.

**Per-run caps (per user):**
- Max **`MONITOR_MAX_PER_RUN`** messages analyzed per user per run. Default **1**,
  hard ceiling **3**. Extra messages are recorded as
  `skipped_over_cap`, never analyzed or alerted. Checkpoint still advances, so
  the backlog can't pile up.
- Process in priority order: unread first, then mail from senders not in the
  user's contacts, then the rest. Newsletters and bulk mail (`List-Unsubscribe`
  header, or `Precedence: bulk`) go last.
- Skip only what can't be phishing: messages the user sent, and duplicates.
  Don't skip mail just because it has no links. Many phishing messages have
  none.

**Text sent to the model:**
- Prefer `text/plain`. If only HTML, strip tags and scripts first.
- Truncate the body to a fixed limit (proposed: **6,000 characters**) and
  record that it was truncated. Keep the subject, sender display name, sender
  address, reply-to, and up to 20 URLs (domain and path only in the prompt).
- Do not send attachments, inline images, or base64 blobs.
- Strip quoted replies and long signatures where it's easy to detect.
- Reuse the existing analysis prompt and JSON schema. Don't create a second
  prompt that could drift.

**Model and cost:**
- Use the same model and analysis path as manual scans, so verdicts are
  consistent. Watch the cost per scan in Phase 5 before raising caps.
- Keep the system prompt identical across calls and enable prompt caching if
  the SDK supports it, so the static part is billed at the cached rate.
- Record tokens in and out per run and per user, so the team can see spend.
- **Rough budget:** 1–3 monitored accounts × 1 run × up to 3 messages ×
  ~2,000 input tokens ≈ 6,000 input tokens per day at the absolute worst case,
  about 2,000 on a typical day with the default of 1.
  Confirm against current model pricing before enabling.

**Retries and failures:**
- Model or network error: retry once. If it fails again, leave that message
  unchecked (no checkpoint past it) so the next daily run tries again.
- Model returns invalid JSON or a `risk_level` that doesn't match the score:
  treat as a failed analysis, not as safe. Log the error type only.

## 3.3 Edge cases and performance

- **Token expiry during a run:** mark the user `reauth_needed`, stop only that
  user, continue others. Home shows the reconnect state.
- **Revoked at Google:** same as expiry, found on the next call.
- **Account deleted (`delete_account`):** delete the token from the secret and
  the user's monitor entry. Verify this runs in the existing delete flow.
- **Plus lapses or is removed:** stop checks, delete the token. Keep scans
  already saved.
- **Offline for more than a week:** `historyId` expires (HTTP 404). Do a
  24-hour resync, not a full inbox scan.
- **Concurrent runs:** a lease per user (like `LEASE_SECONDS` in
  `backend/monitor/worker.py`) so a retried or overlapping run can't double
  scan.
- **Lambda timeout:** the run saves its checkpoint after each message, so a
  timeout loses at most one message.
- **Gmail rate limits (429):** back off and stop that user for the run. Gmail
  per-user quota is far above our volume, so this should be rare.
- **Claude rate limit or outage:** stop the run, keep checkpoints, retry next
  day. Don't mark messages as safe.
- **Caching:**
  - Secrets: read the token map once per Lambda run. The existing `_init()`
    cache covers the rest.
  - Analysis: dedupe by `gmail:{uid}:{messageId}` so a message is never
    analyzed twice, even across runs.
  - Home status: read from one small status document, not from Gmail, so the
    card loads fast and doesn't spend Gmail quota.
- **Secret size:** one map of about 20 tokens stays well under Secrets
  Manager's size limit. Keep one secret for the whole project.
- **Time zones:** store all checkpoints and timestamps in UTC. Show local time
  in the UI only.
- **Multiple devices:** the monitoring state lives on the server, so the same
  account shows the same status on every device.
- **Non-English or encoded mail:** decode MIME and charset. If decoding fails,
  mark as `unreadable`, not safe.
- **Empty or huge mail:** empty bodies go to "couldn't read" status. Huge
  bodies are truncated (see §3.2).

## 3.4 Feature flags (cost control)

Set in Lambda environment config, same style as `MOCK_CLAUDE`:
- `MONITOR_ENABLED` (`true`/`false`): turns scheduled runs off with no code
  change. Set to `true` for the always-on poller (2026-11-22).
- `MONITOR_MAX_PER_RUN` (1–3, default 1): per-user cap on messages analyzed
  per run.
- `MONITOR_UNTIL` (date, UTC): each run checks it and stops itself after that
  date. Backstop only. Set it to a near date (for example 2026-12-19, about 30
  days from 2026-11-19) so monitoring can't run past the window even if the
  schedule is left on. `MONITOR_ENABLED=false` is the normal off switch.
- Runs log the flag state and the date they will stop. No user data in logs.

## 3.5 Schedule and demo plan

- EventBridge schedule `phishnet-monitor-daily` runs every 5 minutes, always
  on, for all connected Gmail accounts (cap 1 per account). Enabled 2026-11-22.
- Live Monitoring is turned off in the app UI, so no monitoring runs for users
  who have it off. Only the owner's account is Plus today.
- For a manual check: send a test email, wait for the next 5-minute run, and
  show the Home card and the alert. Or run the admin trigger for that user.

## 4. Acceptance (issue #70, Gmail)

- **AC1 Connect:** consent grants read-only access. Refresh token only in the
  Secrets Manager map.
- **AC2 Denied:** clear message; monitoring stays off.
- **AC3 Polling:** checks only new mail since the checkpoint, no user action.
- **AC4 Handoff:** new mail goes to the existing scan pipeline.
- **AC5 High-risk:** one deduplicated alert. Tap → Home → Results (supersedes
  #70's direct-to-Results route).
- **AC6 Safe:** scan saved with `source`; no alert.
- **AC7 Batching:** several high-risk messages in one run → one batched alert.
- **AC8 Status and disconnect:** status shows connected and checking.
  Disconnect stops checks and removes the token.
- **AC9 Reliability:** failures logged without content or tokens; user
  notified only when they must act (for example, reconnect).

## 5. Growth path (later, not now)

- **Past about 100 users or going public:** submit OAuth verification and the
  CASA assessment. This removes the test-user cap and the 7-day expiry, and
  the "unverified" screen. Budget for the CASA fee and timeline.
- **Lower-latency checks:** switch from polling to Gmail push
  (`users.watch` + Pub/Sub). Watches expire and must be renewed, so this adds
  a renewal job. Only worth it if 15–30 minute polling isn't good enough.
- **Per-user secrets:** only if compliance requires isolation. Costs about
  $0.40 per user per month.
- **History filtering:** on the `source` field, after Live Monitoring ships.

## 6. Risks and open checks

- Verify in current Google docs before Phase 1: Testing-mode token expiry,
  `history.list` and `historyId` behavior, and Gmail API quotas.
- Claude analysis per scan is the real variable cost. The daily cap bounds it.
- Test-user list is manual. Keep it in the setup doc.
- Yahoo sign-up domain check (`auth_validation.dart`) is unrelated to this
  flow and stays as is.

## 7. Suggestions for discussion

1. **Team Plus record in billing UI.** The team grant is a real `plus` record,
   so check whether billing or subscription screens treat it as a payment. If
   they do, add a `grantedBy` check to hide it there. Decide once we see those
   screens.
2. **One run per day.** Recommended. A second run would double Claude cost.
   If the demo needs a live result, use the admin trigger, not a user button.
3. **Priority of over-cap mail.** The default is unread and non-contacts first.
   Alternative: score cheaply (links, urgency words) before analysis. This adds
   code and a risk of missing things, so I don't recommend it yet.
4. **Model choice for monitoring.** A smaller model would cut cost but could
   give different verdicts from manual scans. I'd keep one model until Phase 5
   shows real costs.
5. **Personal emails in the repo.** This doc is in the repo. I've used
   placeholders (team primary account, non-paid test account), not real
   addresses. Keep addresses in the admin script or a private config, not in
   committed docs.

## 8. Manual tests

Given per phase, after implementation. Phase 0 is the setup checklist in
`docs/live-monitoring-setup.md`.

## 9. Approved decisions and progress log (running)

Updated as work lands. Items marked "approved" were agreed in conversation.

### Decisions
- Architecture and schedule: unchanged from sections 1 to 3.4.
- Google redirect URI: the Function URL with trailing slash is registered in the
  Google console, and the test account is added (approved).
- Platform: iOS only for now. Android push is deferred (approved).
- Attention cards and the Home alert count are Plus-only and cover live-monitoring
  alerts only (approved).
- Non-Plus Home status: positive phrases ("Hooray! No messages need your
  attention.") and a neutral pointer to Results when a recent manual check was
  high risk. No alert styling or attention cards (approved).
- Locked Live Monitoring card for non-Plus users: generic copy, grayed out, tap
  opens the upgrade popup that links to the plans page (approved).
- PLUS badge: plain text pill in the app bar, on the right. No star icon
  (star was tried and rejected). Title shrinks only when space is short
  (approved).
- Loading state: fish animation plus rotating short phrases (approved in idea,
  not built).
- Privacy: no email content in logs or push text. Tokens are never printed.

### Progress (as of 2026-11-21)
- Commits: `99cca91` backend (Phase 1). `f575e6f` app, Phases 2 and 3 together (the files depend on each other). `4122c98` loading state.
- Verified on iPhone: Home card states, device registration, in-app banner, background banner, closed-app tap opens PhishNet, attention card opens Results, one real high-risk alert from one manual run (3 checked, 1 high-risk), menu badge.
- Built, not yet on device: menu badge (26px, centered on the icon's right edge, slightly outside it). Attention clears after 5s on Results, or on return, without waiting for a server refresh. History source badges ("Live Monitor" / "In-app check") and a filter (All / Live Monitor / In-app check), both Plus only. Backend history now returns `source`. `phishnet-scan` was updated with only `handler.py` swapped into the existing zip.
- Fixed: alert text now says "1 message ... looks dangerous" or "N messages ... look dangerous." Poll redeployed; still off.
- Not verified yet: closed-app tap to Home, card, Results (via a Console test with `type` = `monitor_alert`, which needs no scan). Locked phone (via `flutter run --profile`). Safe emails produce no alert. Duplicate check (needs a second run). Turn Off and reconnect. Token expiry.
- Still open: Results badge (Phase 4). Skipped for now: Home live update while open (future refinement). Android is deferred. Schedule stays off until Phase 5 passes.

### Verified 2026-11-21 (final batch)
- Locked phone and signed out: lock-screen banner, tap opens sign-in, sign-in shows Home at 3, menu badge 3.
- Scan run: 3 checked, 1 high-risk. Polling turned off afterward.
- Commits: `bfd5ea5`, `85ee788`, `79bb237`.

### Open bugs (retest later)
- **Home stays stale after an alert push.** Fix written: a forced reload that arrives mid-load runs once more. Sign-in case verified 2026-11-21. Live case (Home open while a push arrives) not yet verified.
- **Menu count lags on non-Home screens.** Verified fixed 2026-11-21 (menu showed 2 on tap). A live alert that arrives while the user is on Capture (or a tap that opens Home) does not update the menu badge until Home finishes loading. Fix written (`push_service.dart` refreshes the count on every alert push), not yet verified on device. Retest with a real push on Capture (lock-screen or closed-app batch steps).
- **Retest path:** the gcloud account lacks `cloudmessaging.messages.create`, so manual FCM sends via curl are blocked. Options: grant "Firebase Cloud Messaging Admin" to that account, or re-run a monitored check with a new email.

### Ideas (not approved)
- Show the same source badge on the Results page (Plus only).
- Optional: make the 5-second clear instant when the user opens the card.

### Deploy notes
- `backend/scripts/deploy_monitor.sh` (connect and poll functions): required
  for device registration, push sending, and any status change to take effect
  live. Run it before testing.
- `backend/lambda/handler.py` (`phishnet-scan`): deploy last, at the end of the
  project.
- Builds that test Live Monitoring need `--dart-define=MONITOR_API_URL=<Function
  URL>`.

