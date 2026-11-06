"""PhishNet Yahoo connection endpoint (AWS Lambda, Python 3.12).

Function: phishnet-monitor-connect (Function URL, auth type NONE).

Flow:
  POST (Firebase ID token) {"action": "start"}   -> Yahoo authorization URL
  GET  ?code=...&state=...  (Yahoo redirect)     -> exchange code, store tokens
  GET  ?error=access_denied (Yahoo redirect)     -> monitoring stays off
  POST {"action": "status"}                      -> connection status only
  POST {"action": "disconnect"}                  -> delete tokens, stop monitoring

Tokens are stored only in Secrets Manager (one secret per user,
phishnet/monitor/<uid>). Firestore holds a status string and a timestamp.
Tokens and the client secret are never returned, logged, or written to
Firestore.

Environment variables (all optional):
  SECRET_ID=phishnet/prod        holds yahoo_client_id, yahoo_client_secret,
                                 monitor_state_key
  YAHOO_REDIRECT_URI             this function's Function URL (required)
  FIREBASE_PROJECT_ID            defaults to phishnet-b93e0
"""

import base64
import hashlib
import hmac
import json
import os
import re
import secrets as pysecrets
import time
import urllib.error
import urllib.parse
import urllib.request

import boto3
import firebase_admin
from firebase_admin import auth, credentials, firestore

SECRET_ID = os.environ.get("SECRET_ID", "phishnet/prod")
PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "phishnet-b93e0")
REDIRECT_URI = os.environ.get("YAHOO_REDIRECT_URI", "")
MONITOR_SECRET_PREFIX = "phishnet/monitor/"
YAHOO_AUTH_URL = "https://api.login.yahoo.com/oauth2/request_auth"
YAHOO_TOKEN_URL = "https://api.login.yahoo.com/oauth2/get_token"
# Yahoo Mail scope. Confirm it is approved for the app before going live.
YAHOO_SCOPE = "mail-r"
PENDING_TTL_SECONDS = 600
UID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{1,128}$")

_secrets = None
_db_ready = False
_sm = None


def _resp(code, body):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def _html(code, title, message):
    # Only fixed strings are rendered here. No request data is echoed.
    body = (
        "<!DOCTYPE html><html><head><meta charset='utf-8'>"
        f"<title>{title}</title></head><body>"
        f"<h2>{title}</h2><p>{message}</p></body></html>"
    )
    return {
        "statusCode": code,
        "headers": {"Content-Type": "text/html; charset=utf-8"},
        "body": body,
    }


def _sm_client():
    global _sm
    if _sm is None:
        _sm = boto3.client("secretsmanager")
    return _sm


def _init():
    """Load app secrets and initialize Firebase once per cold start."""
    global _secrets, _db_ready
    if _secrets is not None:
        return _secrets

    raw = _sm_client().get_secret_value(SecretId=SECRET_ID)["SecretString"]
    secrets_map = json.loads(raw)

    try:
        sa = secrets_map["firebase_service_account"]
        if isinstance(sa, str):
            sa = json.loads(sa)
        firebase_admin.initialize_app(credentials.Certificate(sa))
        _db_ready = True
    except Exception:
        firebase_admin.initialize_app(options={"projectId": PROJECT_ID})
        print("firestore disabled: no usable service account")

    _secrets = secrets_map
    return secrets_map


# ---------- state (CSRF protection for the OAuth redirect) ----------


def _sign_state(uid, nonce, key):
    mac = hmac.new(key.encode(), f"{uid}.{nonce}".encode(), hashlib.sha256)
    return f"{uid}.{nonce}.{mac.hexdigest()}"


def _parse_state(state, key):
    """Return (uid, nonce) if the state was issued by us, else None."""
    parts = (state or "").split(".")
    if len(parts) != 3:
        return None
    uid, nonce, sig = parts
    if not UID_PATTERN.match(uid):
        return None
    expected = _sign_state(uid, nonce, key).rsplit(".", 1)[1]
    if not hmac.compare_digest(sig, expected):
        return None
    return uid, nonce


# ---------- per-user secret storage ----------


def _secret_name(uid):
    if not UID_PATTERN.match(uid or ""):
        raise ValueError("invalid uid")
    return f"{MONITOR_SECRET_PREFIX}{uid}"


def _load_monitor(uid):
    try:
        raw = _sm_client().get_secret_value(SecretId=_secret_name(uid))
    except _sm_client().exceptions.ResourceNotFoundException:
        return None
    return json.loads(raw["SecretString"])


def _save_monitor(uid, data):
    name = _secret_name(uid)
    value = json.dumps(data)
    try:
        _sm_client().put_secret_value(SecretId=name, SecretString=value)
    except _sm_client().exceptions.ResourceNotFoundException:
        _sm_client().create_secret(Name=name, SecretString=value)


def _delete_monitor(uid):
    """Delete the user's token secret. Missing secret counts as deleted."""
    try:
        _sm_client().delete_secret(
            SecretId=_secret_name(uid),
            ForceDeleteWithoutRecovery=True,
        )
    except _sm_client().exceptions.ResourceNotFoundException:
        return


# ---------- Firestore status ----------


def _set_status(uid, status):
    if not _db_ready:
        return
    firestore.client().collection("users").document(uid).collection(
        "monitoring"
    ).document("status").set(
        {"status": status, "updatedAt": firestore.SERVER_TIMESTAMP},
        merge=True,
    )


def _get_status(uid):
    if not _db_ready:
        return "unavailable"
    snap = (
        firestore.client()
        .collection("users")
        .document(uid)
        .collection("monitoring")
        .document("status")
        .get()
    )
    if not snap.exists:
        return "disconnected"
    return snap.to_dict().get("status", "disconnected")


# ---------- Yahoo ----------


def _yahoo_token_request(form, client_id, client_secret):
    basic = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    data = urllib.parse.urlencode(form).encode()
    req = urllib.request.Request(
        YAHOO_TOKEN_URL,
        data=data,
        headers={
            "Authorization": f"Basic {basic}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode())


def _b64url(raw):
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


# ---------- actions ----------


def start(uid, secrets_map):
    """Create a one-time state and PKCE verifier and return the Yahoo URL."""
    if not REDIRECT_URI:
        return _resp(503, {"error": "monitoring_unavailable", "retryable": True})
    nonce = pysecrets.token_urlsafe(16)
    verifier = pysecrets.token_urlsafe(48)
    challenge = _b64url(hashlib.sha256(verifier.encode()).digest())
    state = _sign_state(uid, nonce, secrets_map["monitor_state_key"])

    existing = _load_monitor(uid) or {}
    existing["pending"] = {
        "nonce": nonce,
        "verifier": verifier,
        "exp": int(time.time()) + PENDING_TTL_SECONDS,
    }
    _save_monitor(uid, existing)

    url = YAHOO_AUTH_URL + "?" + urllib.parse.urlencode(
        {
            "client_id": secrets_map["yahoo_client_id"],
            "redirect_uri": REDIRECT_URI,
            "response_type": "code",
            "scope": YAHOO_SCOPE,
            "state": state,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        }
    )
    return _resp(200, {"authorizationUrl": url})


def callback(params, secrets_map):
    """Handle Yahoo's redirect. Returns a page, never a token."""
    if params.get("error"):
        # The user denied or cancelled consent. Keep monitoring off and
        # drop any pending state for that user, if the state is valid.
        print("yahoo consent not granted")
        parsed = _parse_state(params.get("state"), secrets_map["monitor_state_key"])
        if parsed:
            uid = parsed[0]
            monitor = _load_monitor(uid) or {}
            if "pending" in monitor:
                monitor.pop("pending")
                _save_monitor(uid, monitor)
            _set_status(uid, "disconnected")
        return _html(
            200,
            "Monitoring needs access",
            "PhishNet needs permission to read new emails to check them. "
            "Monitoring stays off until you connect again.",
        )

    parsed = _parse_state(params.get("state"), secrets_map["monitor_state_key"])
    code = params.get("code")
    if not parsed or not code:
        return _html(400, "Connection failed", "Please try connecting again.")
    uid, nonce = parsed

    monitor = _load_monitor(uid) or {}
    pending = monitor.get("pending") or {}
    if (
        not hmac.compare_digest(str(pending.get("nonce", "")), nonce)
        or int(pending.get("exp", 0)) < int(time.time())
    ):
        return _html(400, "Connection expired", "Please try connecting again.")

    try:
        token = _yahoo_token_request(
            {
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": REDIRECT_URI,
                "code_verifier": pending["verifier"],
            },
            secrets_map["yahoo_client_id"],
            secrets_map["yahoo_client_secret"],
        )
        refresh = token["refresh_token"]
    except (urllib.error.URLError, KeyError, ValueError) as e:
        print(f"yahoo token exchange failed: {type(e).__name__}")
        _set_status(uid, "error")
        return _html(502, "Connection failed", "Please try connecting again.")

    # Store only what the worker needs. The pending state is cleared.
    _save_monitor(
        uid,
        {
            "refresh_token": refresh,
            "access_token": token.get("access_token", ""),
            "expires_at": int(time.time()) + int(token.get("expires_in", 3600)),
        },
    )
    _set_status(uid, "connected")
    return _html(200, "Monitoring connected", "You can return to PhishNet.")


def status(uid):
    return _resp(200, {"status": _get_status(uid)})


def disconnect(uid):
    """Delete stored tokens, then mark disconnected. Idempotent.

    If deletion fails, the status is NOT changed and the caller is told to
    retry, so the app never reports a disconnect that did not happen.
    """
    try:
        _delete_monitor(uid)
    except Exception as e:
        print(f"monitor secret delete failed: {type(e).__name__}")
        return _resp(503, {"error": "disconnect_failed", "retryable": True})
    _set_status(uid, "disconnected")
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
        method = (
            (event.get("requestContext") or {}).get("http", {}).get("method")
            or event.get("httpMethod")
            or "POST"
        ).upper()

        # Yahoo redirects the browser back here with GET query parameters.
        if method == "GET":
            return callback(event.get("queryStringParameters") or {}, secrets_map)

        uid, err = _verify_uid(event)
        if err:
            return err

        body = event.get("body") or "{}"
        if event.get("isBase64Encoded"):
            body = base64.b64decode(body).decode("utf-8")
        action = json.loads(body).get("action")

        if action == "start":
            return start(uid, secrets_map)
        if action == "status":
            return status(uid)
        if action == "disconnect":
            return disconnect(uid)
        return _resp(400, {"error": "unknown_action"})
    except Exception as e:
        print(f"unhandled error: {type(e).__name__}")
        return _resp(500, {"error": "server_error", "retryable": True})
