"""Gmail poll core for one user. Pure logic; all I/O is injected for tests.

  mail.changes(history_id) -> (history_id, [message_id])   # may raise HistoryExpired
  mail.recent(limit)       -> (history_id, [message_id])   # resync path
  mail.metadata(id)        -> {"labels", "unread", "bulk"}
  mail.full(id)            -> {"subject", "from", "text"}
  store.load(uid) -> State ; store.save(uid, State)
  analyze(text) -> assessment dict with "risk_level"
  already_scanned(uid, key) -> bool ; save_scan(uid, key, assessment) -> None
  alert(uid, keys) -> None  (one batched alert per run, high risk only)

Logs carry outcome counts and error type names only: never subjects,
senders, message IDs, bodies, or tokens.
"""

import hashlib
import logging
import time
from dataclasses import dataclass

from gmail import AuthError, HistoryExpired, PermanentError, TransientError

log = logging.getLogger("monitor.worker")

LEASE_SECONDS = 300
MAX_ATTEMPTS = 2             # analysis attempts per message (transient errors)
BACKOFF_SECONDS = (1,)
RESYNC_LIMIT = 50            # newest messages considered on a resync


@dataclass
class State:
    history_id: str | None = None   # checkpoint; None = never polled
    lease_until: float = 0.0
    status: str = "ok"              # "ok" or "reauth_needed"


def dedupe_key(uid: str, message_id: str) -> str:
    """Stable per user and message. Used as the scan document ID source."""
    return hashlib.sha256(f"gmail:{uid}:{message_id}".encode()).hexdigest()


def build_text(subject: str, sender: str, body: str) -> str:
    return f"Subject: {subject}\nFrom: {sender}\n\n{body}"


def _analyze_with_retry(analyze, text, sleep):
    for attempt in range(MAX_ATTEMPTS):
        try:
            return analyze(text)
        except TransientError:
            if attempt == MAX_ATTEMPTS - 1:
                raise
            sleep(BACKOFF_SECONDS[min(attempt, len(BACKOFF_SECONDS) - 1)])
    raise AssertionError("unreachable")


def _select(mail, ids, cap, summary):
    """Cheap metadata pass. Unread first, bulk last. Extras are counted, not analyzed."""
    rows = []
    for mid in ids:
        meta = mail.metadata(mid)  # TransientError/AuthError propagate
        if "SENT" in meta["labels"] and "INBOX" not in meta["labels"]:
            continue  # the user's own sent mail
        rows.append((meta["bulk"], not meta["unread"], mid))
    rows.sort()
    chosen = [mid for _, _, mid in rows[:cap]]
    summary["skipped_over_cap"] += max(0, len(rows) - cap)
    return chosen


def run_once(uid, store, mail, analyze, save_scan, already_scanned, alert,
             cap=1, now=time.time, sleep=time.sleep):
    """One daily check for one user. Returns a summary dict (no content)."""
    state = store.load(uid)
    if state.status == "reauth_needed":
        return {"result": "reauth_needed"}
    if state.lease_until > now():
        log.info("poll skipped: another run holds the lease")
        return {"result": "busy"}

    state.lease_until = now() + LEASE_SECONDS
    store.save(uid, state)
    summary = {"result": "ok", "saved": 0, "duplicates": 0, "failed": 0,
               "skipped_over_cap": 0}
    high_keys = []
    try:
        if state.history_id is None:
            new_checkpoint, ids = mail.recent(RESYNC_LIMIT)
        else:
            try:
                new_checkpoint, ids = mail.changes(state.history_id)
            except HistoryExpired:
                log.info("checkpoint expired; resyncing recent mail")
                new_checkpoint, ids = mail.recent(RESYNC_LIMIT)

        for mid in _select(mail, ids, cap, summary):
            key = dedupe_key(uid, mid)
            if already_scanned(uid, key):
                summary["duplicates"] += 1
                continue
            try:
                body = mail.full(mid)
                text = build_text(body["subject"], body["from"], body["text"])
                assessment = _analyze_with_retry(analyze, text, sleep)
            except PermanentError:
                summary["failed"] += 1
                continue
            save_scan(uid, key, assessment)  # idempotent on key
            summary["saved"] += 1
            if assessment.get("risk_level") == "high":
                high_keys.append(key)

        if high_keys:
            alert(uid, high_keys)
        state.history_id = new_checkpoint
    except AuthError:
        state.status = "reauth_needed"
        summary["result"] = "reauth_needed"
        log.warning("poll stopped: Google token rejected")
    except TransientError as e:
        # Checkpoint does not move, so the next run retries the same window.
        summary["result"] = "retry"
        log.warning("poll stopped: transient error %s", type(e).__name__)
    finally:
        state.lease_until = 0.0
        store.save(uid, state)
    log.info("poll finished: %s saved=%d dup=%d failed=%d over_cap=%d high=%d",
             summary["result"], summary["saved"], summary["duplicates"],
             summary["failed"], summary["skipped_over_cap"], len(high_keys))
    summary["high_risk"] = len(high_keys)
    return summary
