"""Daily Gmail check (AWS Lambda, Python 3.12). Function: phishnet-monitor-poll.

Runs only when MONITOR_ENABLED=true and today is on or before MONITOR_UNTIL.
Each connected user gets at most MONITOR_MAX_PER_RUN analyses (1 to 3).
Only Plus users are checked. A high-risk result writes one unread alert
document per run. Sends one FCM push per run when new high-risk results exist.

Zip layout: this file, worker.py, gmail.py, store.py, connect.py at the root,
plus lambda/handler.py (imported for analysis, scan save, and secrets).

Environment:
  MONITOR_ENABLED=false           master switch (default off)
  MONITOR_UNTIL=2026-12-19        last UTC date a run may happen (fails closed if unset)
  MONITOR_MAX_PER_RUN=1           1 to 3 messages per user per run
"""

import hashlib
import logging
import os
import time
from datetime import datetime, timezone

import boto3
from firebase_admin import firestore, messaging

import gmail
import handler
import worker
from store import MonitorStore

log = logging.getLogger("monitor.poll")
log.setLevel(logging.INFO)

SCAN_PREFIX = "gmail_"
ALERT_PREFIX = "gmail_run_"


def _config(today):
    """Return (enabled, max_per_run). Off unless every check passes."""
    if os.environ.get("MONITOR_ENABLED", "false").lower() != "true":
        return False, 0
    try:
        until = datetime.fromisoformat(os.environ["MONITOR_UNTIL"]).date()
    except (KeyError, ValueError):
        return False, 0  # fail closed on a missing or bad date
    if today > until:
        return False, 0
    try:
        cap = int(os.environ.get("MONITOR_MAX_PER_RUN", "1"))
    except ValueError:
        cap = 1
    return True, min(max(cap, 1), 3)


class _StoreAdapter:
    """Maps the worker's State onto one user's entry in the monitor secret."""

    def __init__(self, store, uid):
        self._store, self._uid = store, uid

    def load(self, uid):
        entry = self._store.get(uid)
        return worker.State(
            history_id=entry.get("history_id"),
            lease_until=float(entry.get("lease_until", 0)),
            status=entry.get("status", "ok"),
        )

    def save(self, uid, state):
        entry = self._store.get(uid)
        entry.update({"history_id": state.history_id,
                      "lease_until": state.lease_until,
                      "status": state.status})
        self._store.put(uid, entry)


class _GmailMail:
    """Gmail adapter for the worker. Holds one short-lived access token."""

    def __init__(self, token):
        self._token = token

    def changes(self, history_id):
        return gmail.changes(self._token, history_id)

    def recent(self, limit):
        return gmail.recent_ids(self._token, limit)

    def metadata(self, message_id):
        return gmail.metadata(self._token, message_id)

    def full(self, message_id):
        return gmail.full(self._token, message_id)


def _scan_doc_id(key):
    return SCAN_PREFIX + key


def _already_scanned(db, uid, key):
    snap = (db.collection("users").document(uid).collection("scans")
            .document(_scan_doc_id(key)).get())
    return snap.exists


def _save_scan(uid, key, assessment):
    try:
        handler._save_scan(uid, assessment, doc_id=_scan_doc_id(key),
                           source="gmail_monitor")
    except Exception as e:
        # AlreadyExists means a retry already saved this message. Not an error.
        if type(e).__name__ == "AlreadyExists":
            return
        raise


def _write_alert(db, uid, keys):
    """One unread alert per run. The ID is derived from its scans, so retries are no-ops."""
    scan_ids = sorted(_scan_doc_id(k) for k in keys)
    alert_id = ALERT_PREFIX + hashlib.sha256("".join(scan_ids).encode()).hexdigest()[:32]
    ref = (db.collection("users").document(uid).collection("monitorAlerts")
           .document(alert_id))
    if ref.get().exists:
        return
    ref.set({"scanIds": scan_ids, "count": len(scan_ids), "read": False,
             "createdAt": firestore.SERVER_TIMESTAMP})
    _push_alert(db, uid, alert_id, len(scan_ids))


def _push_alert(db, uid, alert_id, count):
    """Push for a new high-risk alert. Never raises: a failed push must not fail the run.

    Sends no email content. Tokens FCM reports as dead are removed.
    """
    try:
        devices = list(db.collection("users").document(uid).collection("devices").stream())
        tokens = {d.id: (d.to_dict() or {}).get("token") for d in devices}
        tokens = {k: v for k, v in tokens.items() if v}
        if not tokens:
            return
        if count == 1:
            body = "1 message in your inbox looks dangerous. Tap to review."
        else:
            body = f"{count} messages in your inbox look dangerous. Tap to review."
        messages = [
            messaging.Message(
                token=token,
                notification=messaging.Notification(
                    title="Possible scam found",
                    body=body,
                ),
                data={"type": "monitor_alert", "alertId": alert_id},
            )
            for token in tokens.values()
        ]
        response = messaging.send_each(messages)
        for doc_id, result in zip(tokens.keys(), response.responses):
            if not result.success and isinstance(
                result.exception, (messaging.UnregisteredError, messaging.SenderIdMismatchError)
            ):
                db.collection("users").document(uid).collection("devices").document(doc_id).delete()
    except Exception as e:
        log.warning("alert push failed: %s", type(e).__name__)


def _set_status(db, uid, status):
    db.collection("users").document(uid).collection("monitoring").document("status").set(
        {"status": status, "updatedAt": firestore.SERVER_TIMESTAMP}
    )


def lambda_handler(event, context):
    today = datetime.now(timezone.utc).date()
    enabled, cap = _config(today)
    if not enabled:
        log.info("monitor disabled; no work done")
        return {"status": "disabled"}

    secrets_map = handler._init()
    store = MonitorStore(boto3.client("secretsmanager"))
    db = firestore.client()
    counts = {"users": 0, "skipped_not_plus": 0, "reauth": 0, "saved": 0, "high_risk": 0}

    for uid in store.users():
        counts["users"] += 1
        if not handler._has_active_plus(db, uid, datetime.now(timezone.utc)):
            counts["skipped_not_plus"] += 1
            continue
        entry = store.get(uid)
        if entry.get("status") == "reauth_needed":
            counts["reauth"] += 1
            continue
        try:
            token = gmail.access_token(entry["refresh_token"],
                                       secrets_map["gmail_client_id"],
                                       secrets_map["gmail_client_secret"])
        except gmail.TransientError:
            continue  # try again on the next daily run
        except gmail.AuthError:
            entry["status"] = "reauth_needed"
            store.put(uid, entry)
            _set_status(db, uid, "reauth_needed")
            counts["reauth"] += 1
            continue

        result = worker.run_once(
            uid,
            _StoreAdapter(store, uid),
            _GmailMail(token),
            analyze=lambda text: handler._analyze(text, secrets_map["anthropic_api_key"]),
            save_scan=lambda u, k, a: _save_scan(u, k, a),
            already_scanned=lambda u, k: _already_scanned(db, u, k),
            alert=lambda u, keys: _write_alert(db, u, keys),
            cap=cap,
            now=time.time,
        )
        counts["saved"] += result.get("saved", 0)
        counts["high_risk"] += result.get("high_risk", 0)
        if result.get("result") == "reauth_needed":
            counts["reauth"] += 1
            _set_status(db, uid, "reauth_needed")

    log.info("monitor run: %s", counts)
    return {"status": "ran", **counts}
