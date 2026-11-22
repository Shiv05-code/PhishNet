"""Gmail connection endpoint (AWS Lambda, Python 3.12). Function: phishnet-monitor-connect.

  POST (Firebase ID token) {"action": "start"}   -> Google authorization URL
  GET  ?code=...&state=...  (Google redirect)    -> exchange code, store refresh token
  GET  ?error=access_denied (Google redirect)    -> monitoring stays off
  POST {"action": "status"}                      -> connection status only
  POST {"action": "disconnect"}                  -> revoke, delete token, stop monitoring

Refresh tokens live only in the phishnet/monitor-tokens secret (see store.py).
Firestore holds only a status string. Tokens and client secrets are never
returned, logged, or written to Firestore.

Environment (optional unless noted):
  SECRET_ID=phishnet/prod          gmail_client_id, gmail_client_secret, monitor_state_key
  GMAIL_REDIRECT_URI               this function's Function URL (required)
  FIREBASE_PROJECT_ID              defaults to phishnet-b93e0
"""

import base64
import hashlib
import hmac
import html
import json
import os
import re
import secrets as pysecrets
import time

import boto3
import firebase_admin
from firebase_admin import auth, credentials, firestore

import gmail
from store import MonitorStore

SECRET_ID = os.environ.get("SECRET_ID", "phishnet/prod")
PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "phishnet-b93e0")
REDIRECT_URI = os.environ.get("GMAIL_REDIRECT_URI", "")
PENDING_TTL_SECONDS = 600
UID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{1,128}$")

_secrets = None
_db = None
_sm = None


def _resp(code, body):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json", "Cache-Control": "no-store"},
        "body": json.dumps(body),
    }


def _html(code, title, message):
    page = (
        "<!doctype html><meta name='viewport' content='width=device-width,initial-scale=1'>"
        f"<title>{html.escape(title)}</title>"
        "<body style='font-family:system-ui;font-size:20px;padding:24px'>"
        f"<h2>{html.escape(title)}</h2><p>{html.escape(message)}</p></body>"
    )
    return {"statusCode": code, "headers": {"Content-Type": "text/html; charset=utf-8",
                                             "Cache-Control": "no-store"}, "body": page}


def _init():
    """Load app secrets and initialize Firebase once per cold start."""
    global _secrets, _db, _sm
    if _secrets is None:
        _sm = boto3.client("secretsmanager")
        raw = _sm.get_secret_value(SecretId=SECRET_ID)["SecretString"]
        _secrets = json.loads(raw)
        if not firebase_admin._apps:
            sa = _secrets["firebase_service_account"]
            if isinstance(sa, str):
                sa = json.loads(sa)
            cred = credentials.Certificate(sa)
            firebase_admin.initialize_app(cred, {"projectId": PROJECT_ID})
        _db = firestore.client()
    return _secrets


# ---------- state (CSRF protection for the redirect) ----------


def _sign_state(uid, nonce, key):
    payload = f"{uid}.{nonce}"
    sig = hmac.new(key.encode(), payload.encode(), hashlib.sha256).hexdigest()
    return base64.urlsafe_b64encode(f"{payload}.{sig}".encode()).decode().rstrip("=")


def _parse_state(state, key):
    """Return (uid, nonce) when the signature is valid, else None."""
    if not state:
        return None
    try:
        raw = base64.urlsafe_b64decode(state + "=" * (-len(state) % 4)).decode()
        uid, nonce, sig = raw.rsplit(".", 2)
    except (ValueError, UnicodeDecodeError):
        return None
    expected = hmac.new(key.encode(), f"{uid}.{nonce}".encode(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(sig, expected) or not UID_PATTERN.match(uid):
        return None
    return uid, nonce


def _b64url(raw):
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


# ---------- Firestore status and plan ----------


def _set_status(db, uid, status):
    db.collection("users").document(uid).collection("monitoring").document("status").set(
        {"status": status, "updatedAt": firestore.SERVER_TIMESTAMP}
    )


def _get_status(db, uid):
    snap = (db.collection("users").document(uid)
            .collection("monitoring").document("status").get())
    if not snap.exists:
        return "disconnected"
    return snap.to_dict().get("status", "disconnected")


def _has_plus(db, uid, now):
    """Same rule as handler._has_active_plus. Keep the two in sync."""
    snap = (db.collection("users").document(uid)
            .collection("subscriptions").document("current").get())
    data = (snap.to_dict() or {}) if snap.exists else {}
    expires_at = data.get("expiresAt")
    return (
        data.get("plan") == "plus"
        and data.get("status") == "active"
        and data.get("environment") == "production"
        and hasattr(expires_at, "timestamp")
        and expires_at.timestamp() > now
    )


# ---------- actions ----------


def start(uid, secrets_map, store, db):
    if not REDIRECT_URI:
        return _resp(503, {"error": "monitoring_unavailable", "retryable": True})
    if not _has_plus(db, uid, time.time()):
        return _resp(403, {"error": "plus_required"})
    nonce = pysecrets.token_urlsafe(16)
    verifier = pysecrets.token_urlsafe(48)
    challenge = _b64url(hashlib.sha256(verifier.encode()).digest())
    state = _sign_state(uid, nonce, secrets_map["monitor_state_key"])

    entry = store.get(uid)
    entry["pending"] = {"nonce": nonce, "verifier": verifier,
                        "exp": int(time.time()) + PENDING_TTL_SECONDS}
    store.put(uid, entry)

    url = gmail.auth_url(secrets_map["gmail_client_id"], REDIRECT_URI, state, challenge)
    return _resp(200, {"authorizationUrl": url})


def callback(params, secrets_map, store, db):
    """Handle Google's redirect. Returns a page, never a token."""
    parsed = _parse_state(params.get("state"), secrets_map["monitor_state_key"])

    if params.get("error"):
        # Consent denied or cancelled. Keep monitoring off.
        if parsed:
            uid, _ = parsed
            entry = store.get(uid)
            if entry.pop("pending", None) is not None:
                store.put(uid, entry)
            _set_status(db, uid, "disconnected")
        return _html(200, "Monitoring needs access",
                     "PhishNet needs permission to read new emails to check them. "
                     "Monitoring stays off until you connect again.")

    code = params.get("code")
    if not parsed or not code:
        return _html(400, "Connection failed", "Please try connecting again.")
    uid, nonce = parsed

    entry = store.get(uid)
    pending = entry.get("pending") or {}
    if (not hmac.compare_digest(str(pending.get("nonce", "")), nonce)
            or int(pending.get("exp", 0)) < int(time.time())):
        return _html(400, "Connection expired", "Please try connecting again.")

    try:
        refresh = gmail.exchange_code(code, pending["verifier"], REDIRECT_URI,
                                      secrets_map["gmail_client_id"],
                                      secrets_map["gmail_client_secret"])
    except (gmail.AuthError, gmail.TransientError, gmail.PermanentError):
        _set_status(db, uid, "error")
        return _html(502, "Connection failed", "Please try connecting again.")

    # New connection: no checkpoint yet, so the first check looks back one day only.
    store.put(uid, {"refresh_token": refresh, "history_id": None,
                    "lease_until": 0, "status": "ok"})
    _set_status(db, uid, "connected")
    return _html(200, "Monitoring connected", "You can return to PhishNet.")


def status(uid, db):
    return _resp(200, {"status": _get_status(db, uid)})


def register_device(uid, token, platform, db):
    """Store one push token for the user. Doc ID is a hash, so the raw token is never a key."""
    if not isinstance(token, str) or not (20 <= len(token) <= 4096):
        return _resp(400, {"error": "invalid_token"})
    if platform not in ("ios", "android"):
        return _resp(400, {"error": "invalid_platform"})
    doc_id = hashlib.sha256(token.encode()).hexdigest()[:32]
    (db.collection("users").document(uid).collection("devices").document(doc_id)
     .set({"token": token, "platform": platform,
           "updatedAt": firestore.SERVER_TIMESTAMP}))
    return _resp(200, {"registered": True})


def disconnect(uid, store, db):
    """Revoke at Google, delete the stored token, then mark disconnected. Idempotent.

    If the local delete fails, status is NOT changed and the caller is asked to
    retry, so the app never reports a disconnect that did not happen.
    """
    entry = store.get(uid)
    if entry.get("refresh_token"):
        gmail.revoke(entry["refresh_token"])  # best effort; local delete still runs
    try:
        store.delete(uid)
    except Exception as e:
        print(f"monitor store delete failed: {type(e).__name__}")
        return _resp(503, {"error": "disconnect_failed", "retryable": True})
    _set_status(db, uid, "disconnected")
    return _resp(200, {"status": "disconnected"})


# ---------- entry point ----------


def _verify_uid(event):
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    authz = headers.get("authorization", "")
    if not authz.startswith("Bearer "):
        return None, _resp(401, {"error": "unauthorized"})
    try:
        decoded = auth.verify_id_token(authz[7:])
    except Exception:
        return None, _resp(401, {"error": "unauthorized"})
    if decoded.get("firebase", {}).get("sign_in_provider") == "anonymous":
        return None, _resp(403, {"error": "account_required"})
    return decoded["uid"], None


def handler(event, context):
    try:
        secrets_map = _init()
        store = MonitorStore(_sm)
        method = (
            (event.get("requestContext") or {}).get("http", {}).get("method")
            or event.get("httpMethod") or "POST"
        ).upper()

        if method == "GET":
            return callback(event.get("queryStringParameters") or {}, secrets_map, store, _db)

        uid, err = _verify_uid(event)
        if err:
            return err

        body = event.get("body") or "{}"
        if event.get("isBase64Encoded"):
            body = base64.b64decode(body).decode("utf-8")
        payload = json.loads(body)
        action = payload.get("action")

        if action == "register_device":
            return register_device(uid, payload.get("token"), payload.get("platform"), _db)
        if action == "start":
            return start(uid, secrets_map, store, _db)
        if action == "status":
            return status(uid, _db)
        if action == "disconnect":
            return disconnect(uid, store, _db)
        return _resp(400, {"error": "unknown_action"})
    except Exception as e:
        print(f"unhandled error: {type(e).__name__}")
        return _resp(500, {"error": "server_error", "retryable": True})
