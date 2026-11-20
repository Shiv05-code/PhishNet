"""Gmail API client for Live Monitoring (stdlib only, read-only scope).

Error mapping (the worker reacts to these types):
  AuthError       token rejected or revoked         -> user must reconnect
  HistoryExpired  historyId too old (HTTP 404)      -> caller resyncs recent mail
  TransientError  429, 5xx, timeouts                -> retry on the next run
  PermanentError  other 4xx for one message         -> skip that message

Never log tokens, message IDs, headers, or bodies.
"""

import base64
import html
import json
import re
import urllib.error
import urllib.parse
import urllib.request

AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"
REVOKE_URL = "https://oauth2.googleapis.com/revoke"
API = "https://gmail.googleapis.com/gmail/v1/users/me"
SCOPE = "https://www.googleapis.com/auth/gmail.readonly"
TIMEOUT_SECONDS = 10
BODY_CHAR_LIMIT = 6000   # cap on text sent to the model (cost control)
MAX_LIST_PAGES = 5       # bounds history/list paging per run


class TransientError(Exception):
    """Retry later (429, 5xx, timeout)."""


class PermanentError(Exception):
    """This message can't be processed. Skip it."""


class AuthError(Exception):
    """Google rejected the refresh token. Ask the user to reconnect."""


class HistoryExpired(Exception):
    """historyId is too old for history.list. Resync with recent mail."""


def auth_url(client_id, redirect_uri, state, challenge):
    return AUTH_URL + "?" + urllib.parse.urlencode({
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": SCOPE,
        "access_type": "offline",   # needed to receive a refresh token
        "prompt": "consent",        # makes Google return a refresh token again
        "state": state,
        "code_challenge": challenge,
        "code_challenge_method": "S256",
    })


def _call(url, *, data=None, headers=None, method="GET", token_endpoint=False):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
            body = resp.read()
            return json.loads(body.decode()) if body else {}
    except urllib.error.HTTPError as e:
        if token_endpoint and 400 <= e.code < 500:
            raise AuthError() from None   # invalid_grant or bad code
        if e.code == 401:
            raise AuthError() from None
        if e.code == 404 and "/history" in url:
            raise HistoryExpired() from None
        if e.code == 429 or e.code >= 500:
            raise TransientError() from None
        raise PermanentError() from None
    except (urllib.error.URLError, TimeoutError, OSError):
        raise TransientError() from None


def _bearer(token):
    return {"Authorization": f"Bearer {token}"}


def exchange_code(code, verifier, redirect_uri, client_id, client_secret):
    """Trade the consent code for a refresh token (stored, never returned)."""
    data = urllib.parse.urlencode({
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "code_verifier": verifier,
        "client_id": client_id,
        "client_secret": client_secret,
    }).encode()
    body = _call(TOKEN_URL, data=data, method="POST", token_endpoint=True,
                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    refresh = body.get("refresh_token")
    if not refresh:
        raise AuthError()
    return refresh


def access_token(refresh_token, client_id, client_secret):
    data = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "client_id": client_id,
        "client_secret": client_secret,
    }).encode()
    body = _call(TOKEN_URL, data=data, method="POST", token_endpoint=True,
                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    token = body.get("access_token")
    if not token:
        raise AuthError()
    return token


def revoke(refresh_token):
    """Best-effort revoke at Google. Returns True when Google confirmed it."""
    try:
        _call(REVOKE_URL, data=urllib.parse.urlencode({"token": refresh_token}).encode(),
              method="POST", token_endpoint=True,
              headers={"Content-Type": "application/x-www-form-urlencoded"})
        return True
    except (AuthError, PermanentError, TransientError):
        return False


def current_history_id(token):
    return str(_call(f"{API}/profile", headers=_bearer(token))["historyId"])


def recent_ids(token, limit):
    """Resync path: current historyId plus the newest inbox message IDs (1 day)."""
    history_id = current_history_id(token)  # read first so nothing is missed
    query = urllib.parse.urlencode({"q": "in:inbox newer_than:1d", "maxResults": limit})
    body = _call(f"{API}/messages?{query}", headers=_bearer(token))
    return history_id, [m["id"] for m in body.get("messages", [])]


def changes(token, start_history_id):
    """New message IDs added to the inbox since start_history_id."""
    ids, seen, page, latest = [], set(), None, start_history_id
    for _ in range(MAX_LIST_PAGES):
        params = {"startHistoryId": start_history_id, "historyTypes": "messageAdded",
                  "labelId": "INBOX"}
        if page:
            params["pageToken"] = page
        body = _call(f"{API}/history?{urllib.parse.urlencode(params)}",
                     headers=_bearer(token))
        latest = str(body.get("historyId", latest))
        for record in body.get("history", []):
            for added in record.get("messagesAdded", []):
                mid = added["message"]["id"]
                if mid not in seen:
                    seen.add(mid)
                    ids.append(mid)
        page = body.get("nextPageToken")
        if not page:
            break
    return latest, ids


def metadata(token, message_id):
    """Labels and bulk-mail hint only. Cheap: no body is fetched."""
    params = urllib.parse.urlencode({
        "format": "metadata",
        "metadataHeaders": ["From", "Subject", "List-Unsubscribe", "Precedence"],
    }, doseq=True)
    body = _call(f"{API}/messages/{message_id}?{params}", headers=_bearer(token))
    headers = {h["name"].lower(): h["value"] for h in body.get("payload", {}).get("headers", [])}
    bulk = "list-unsubscribe" in headers or headers.get("precedence", "").lower() in {"bulk", "list"}
    labels = set(body.get("labelIds", []))
    return {"labels": labels, "unread": "UNREAD" in labels, "bulk": bulk}


def full(token, message_id):
    """Subject, sender, and a truncated plain-text body for analysis."""
    body = _call(f"{API}/messages/{message_id}?format=full", headers=_bearer(token))
    headers = {h["name"].lower(): h["value"] for h in body.get("payload", {}).get("headers", [])}
    text = _extract_text(body.get("payload", {}))
    return {
        "subject": headers.get("subject", "")[:300],
        "from": headers.get("from", "")[:300],
        "text": text[:BODY_CHAR_LIMIT],
    }


def _decode(data):
    return base64.urlsafe_b64decode(data + "=" * (-len(data) % 4)).decode("utf-8", "replace")


def _extract_text(payload):
    """Prefer text/plain; fall back to HTML with tags removed."""
    plain, rich = [], []

    def walk(part):
        mime = part.get("mimeType", "")
        data = part.get("body", {}).get("data")
        if data and mime == "text/plain":
            plain.append(_decode(data))
        elif data and mime == "text/html":
            rich.append(_decode(data))
        for child in part.get("parts", []) or []:
            walk(child)

    walk(payload)
    if plain:
        return re.sub(r"\s+", " ", "\n".join(plain)).strip()
    html_text = "\n".join(rich)
    html_text = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", html_text, flags=re.S | re.I)
    html_text = re.sub(r"<[^>]+>", " ", html_text)
    return re.sub(r"\s+", " ", html.unescape(html_text)).strip()
