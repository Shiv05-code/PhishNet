"""Scheduled Yahoo polling core (Phase 2). Not deployed; schedules stay off.

All I/O is injected so the logic can be tested with fakes:
  store.load(uid) -> State ; store.save(uid, State)
  mail.list_uids(after_uid, limit) -> (uid_validity, [int, ...])
  mail.fetch(uid) -> Message(message_id, text)   (raises TransientError/AuthError)
  analyze(text) -> assessment dict with "risk_level"  (same as the scan API)
  save_scan(uid, key, assessment) -> must be idempotent on `key`

Logs carry outcome counts and error type names only: never message text,
Message-IDs, or tokens.
"""

import hashlib
import logging
import time
from dataclasses import dataclass, field

log = logging.getLogger("monitor.worker")

LEASE_SECONDS = 300          # a run that crashes frees its lock after this
MAX_MESSAGES_PER_RUN = 25    # bounded work per invocation; the rest waits
MAX_ATTEMPTS = 3             # per message, for transient errors
BACKOFF_SECONDS = (1, 3)     # sleeps between attempts
SEEN_LIMIT = 500             # dedupe window kept per user


class TransientError(Exception):
    """Retry later (rate limit, timeout, 5xx). Checkpoint does not move past it."""


class PermanentError(Exception):
    """This message can't be processed. Skip it; never retry it."""


class AuthError(Exception):
    """Yahoo rejected the token. Stop and ask the user to reconnect."""


@dataclass
class Message:
    message_id: str | None
    text: str


@dataclass
class State:
    uid_validity: int | None = None
    last_uid: int = 0
    seen: list = field(default_factory=list)  # dedupe keys, oldest first
    lease_until: float = 0.0
    status: str = "ok"                         # "ok" or "reauth_needed"


def dedupe_key(message: Message, mail_uid: int) -> str:
    """Same email in two folders or re-fetched after a reset maps to one key."""
    if message.message_id:
        return hashlib.sha256(message.message_id.encode()).hexdigest()
    return hashlib.sha256(f"uid:{mail_uid}".encode()).hexdigest()


def _analyze_with_retry(analyze, text, sleep):
    for attempt in range(MAX_ATTEMPTS):
        try:
            return analyze(text)
        except PermanentError:
            raise
        except TransientError:
            if attempt == MAX_ATTEMPTS - 1:
                raise
            sleep(BACKOFF_SECONDS[min(attempt, len(BACKOFF_SECONDS) - 1)])


def run_once(uid, store, mail, analyze, save_scan, now=time.time, sleep=time.sleep):
    """Poll one user's inbox once. Returns a dict summary (no content)."""
    state = store.load(uid)
    if state.status == "reauth_needed":
        return {"result": "reauth_needed"}
    if state.lease_until > now():
        log.info("poll skipped: another run holds the lease")
        return {"result": "busy"}

    state.lease_until = now() + LEASE_SECONDS
    store.save(uid, state)
    summary = {"result": "ok", "saved": 0, "duplicates": 0,
               "skipped": 0, "high_risk": []}
    try:
        _poll(uid, state, store, mail, analyze, save_scan, sleep, summary)
    except AuthError:
        state.status = "reauth_needed"
        summary["result"] = "reauth_needed"
        log.warning("poll stopped: Yahoo token rejected")
    except TransientError as e:
        summary["result"] = "retry"
        log.warning("poll stopped: transient error %s", type(e).__name__)
    finally:
        state.lease_until = 0.0
        store.save(uid, state)
    log.info("poll finished: %s saved=%d dup=%d skipped=%d",
             summary["result"], summary["saved"],
             summary["duplicates"], summary["skipped"])
    return summary


def _poll(uid, state, store, mail, analyze, save_scan, sleep, summary):
    processed = 0
    while processed < MAX_MESSAGES_PER_RUN:
        validity, uids = mail.list_uids(state.last_uid,
                                        MAX_MESSAGES_PER_RUN - processed)
        if state.uid_validity is not None and validity != state.uid_validity:
            # Mailbox was rebuilt: UIDs restart. Dedupe keys prevent repeats.
            state.uid_validity = validity
            state.last_uid = 0
            continue
        state.uid_validity = validity
        if not uids:
            return

        for mail_uid in uids:
            if processed >= MAX_MESSAGES_PER_RUN:
                return
            processed += 1
            message = mail.fetch(mail_uid)  # TransientError/AuthError propagate
            key = dedupe_key(message, mail_uid)
            if key in state.seen:
                summary["duplicates"] += 1
            else:
                try:
                    assessment = _analyze_with_retry(analyze, message.text, sleep)
                except PermanentError:
                    summary["skipped"] += 1
                    log.info("message skipped: permanent analysis error")
                else:
                    save_scan(uid, key, assessment)  # idempotent on key
                    summary["saved"] += 1
                    if assessment.get("risk_level") == "high":
                        summary["high_risk"].append(key)
                    state.seen.append(key)
                    state.seen = state.seen[-SEEN_LIMIT:]
            state.last_uid = mail_uid
            store.save(uid, state)  # checkpoint after each message
