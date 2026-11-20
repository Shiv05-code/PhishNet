"""Tests for the Gmail client and the Gmail connect endpoint (no network).

Run from backend/: .venv-test/bin/python -m pytest -q tests/test_monitor_gmail.py
"""

import base64
import io
import json
import sys
import urllib.error
import urllib.parse
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

MONITOR_DIR = Path(__file__).resolve().parents[1] / "monitor"
sys.path[:0] = [str(MONITOR_DIR)]

import connect  # noqa: E402
import gmail  # noqa: E402
from store import MonitorStore  # noqa: E402

UID = "user_abc123"
KEY = "test-state-key"  # fake value, never a real credential
SECRETS = {"gmail_client_id": "fake-id", "gmail_client_secret": "fake-secret",
           "monitor_state_key": KEY}


def b64(text):
    return base64.urlsafe_b64encode(text.encode()).decode()


def http_error(code, url="https://gmail.googleapis.com/gmail/v1/users/me/x"):
    return urllib.error.HTTPError(url, code, "x", {}, io.BytesIO(b"{}"))


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


# ---------- gmail.py ----------


def test_auth_url_requests_read_only_offline_consent():
    url = gmail.auth_url("cid", "https://x/cb", "STATE", "CHAL")
    q = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)
    assert q["scope"] == [gmail.SCOPE] and gmail.SCOPE.endswith("gmail.readonly")
    assert q["access_type"] == ["offline"] and q["prompt"] == ["consent"]
    assert q["state"] == ["STATE"] and q["code_challenge_method"] == ["S256"]


@pytest.mark.parametrize("code,url,expected", [
    (401, gmail.API + "/messages", gmail.AuthError),
    (404, gmail.API + "/history?x=1", gmail.HistoryExpired),
    (404, gmail.API + "/messages/m1", gmail.PermanentError),
    (429, gmail.API + "/messages", gmail.TransientError),
    (503, gmail.API + "/messages", gmail.TransientError),
    (403, gmail.API + "/messages", gmail.PermanentError),
])
def test_http_errors_map_to_worker_error_types(code, url, expected):
    with patch("urllib.request.urlopen", side_effect=http_error(code, url)):
        with pytest.raises(expected):
            gmail._call(url)


def test_token_endpoint_rejection_means_reconnect():
    with patch("urllib.request.urlopen", side_effect=http_error(400, gmail.TOKEN_URL)):
        with pytest.raises(gmail.AuthError):
            gmail.access_token("rt", "cid", "cs")


def test_network_failure_is_transient():
    with patch("urllib.request.urlopen", side_effect=urllib.error.URLError("down")):
        with pytest.raises(gmail.TransientError):
            gmail._call(gmail.API + "/profile")


def test_plain_text_is_preferred_over_html():
    payload = {"mimeType": "multipart/alternative", "parts": [
        {"mimeType": "text/html", "body": {"data": b64("<p>html only</p>")}},
        {"mimeType": "text/plain", "body": {"data": b64("plain body")}},
    ]}
    assert gmail._extract_text(payload) == "plain body"


def test_html_fallback_drops_scripts_and_tags():
    payload = {"mimeType": "text/html",
               "body": {"data": b64("<style>x{}</style><script>bad()</script>"
                                    "<p>Click &amp; pay</p>")}}
    assert gmail._extract_text(payload) == "Click & pay"


def test_full_truncates_body_to_cost_limit():
    long_body = "a" * (gmail.BODY_CHAR_LIMIT + 800)
    message = {"payload": {"headers": [{"name": "Subject", "value": "S"},
                                       {"name": "From", "value": "f@x"}],
                           "mimeType": "text/plain", "body": {"data": b64(long_body)}}}
    with patch.object(gmail, "_call", return_value=message):
        out = gmail.full("tok", "m1")
    assert len(out["text"]) == gmail.BODY_CHAR_LIMIT
    assert out["subject"] == "S" and out["from"] == "f@x"


def test_metadata_flags_bulk_and_unread():
    body = {"labelIds": ["INBOX", "UNREAD"],
            "payload": {"headers": [{"name": "List-Unsubscribe", "value": "<x>"}]}}
    with patch.object(gmail, "_call", return_value=body):
        meta = gmail.metadata("tok", "m1")
    assert meta["bulk"] is True and meta["unread"] is True


def test_changes_follows_pages_and_dedupes_ids():
    pages = [
        {"historyId": "9", "nextPageToken": "p2", "history": [
            {"messagesAdded": [{"message": {"id": "a"}}, {"message": {"id": "b"}}]}]},
        {"historyId": "10", "history": [
            {"messagesAdded": [{"message": {"id": "b"}}, {"message": {"id": "c"}}]}]},
    ]
    with patch.object(gmail, "_call", side_effect=pages):
        latest, ids = gmail.changes("tok", "5")
    assert latest == "10" and ids == ["a", "b", "c"]


def test_revoke_is_best_effort_and_never_raises():
    with patch.object(gmail, "_call", side_effect=gmail.TransientError()):
        assert gmail.revoke("rt") is False


# ---------- connect.py ----------


class FakeStore:
    def __init__(self):
        self.data = {}

    def get(self, uid):
        return dict(self.data.get(uid) or {})

    def put(self, uid, entry):
        self.data[uid] = dict(entry)

    def delete(self, uid):
        self.data.pop(uid, None)


def test_state_round_trips_and_tampering_is_rejected():
    state = connect._sign_state(UID, "nonce1", KEY)
    assert connect._parse_state(state, KEY) == (UID, "nonce1")
    assert connect._parse_state(state, "other-key") is None
    assert connect._parse_state("garbage", KEY) is None


def test_start_requires_plus_and_never_returns_secrets():
    store = FakeStore()
    with patch.object(connect, "REDIRECT_URI", "https://fn/cb"), \
            patch.object(connect, "_has_plus", return_value=False):
        resp = connect.start(UID, SECRETS, store, db=None)
    assert resp["statusCode"] == 403
    assert store.data == {}  # nothing stored without Plus


def test_start_returns_google_url_and_stores_only_pending_state():
    store = FakeStore()
    with patch.object(connect, "REDIRECT_URI", "https://fn/cb"), \
            patch.object(connect, "_has_plus", return_value=True):
        resp = connect.start(UID, SECRETS, store, db=None)
    body = json.loads(resp["body"])
    assert body["authorizationUrl"].startswith(gmail.AUTH_URL)
    assert "fake-secret" not in resp["body"]
    assert "pending" in store.data[UID] and "refresh_token" not in store.data[UID]


def test_denied_consent_keeps_monitoring_off():
    store = FakeStore()
    store.put(UID, {"pending": {"nonce": "n", "verifier": "v", "exp": 9e12}})
    state = connect._sign_state(UID, "n", KEY)
    with patch.object(connect, "_set_status") as set_status:
        resp = connect.callback({"error": "access_denied", "state": state},
                                SECRETS, store, db=None)
    assert resp["statusCode"] == 200
    assert "pending" not in store.data[UID] and "refresh_token" not in store.data[UID]
    set_status.assert_called_once_with(None, UID, "disconnected")


def test_successful_callback_stores_refresh_token_and_returns_no_token():
    store = FakeStore()
    store.put(UID, {"pending": {"nonce": "n", "verifier": "v", "exp": 9e12}})
    state = connect._sign_state(UID, "n", KEY)
    with patch.object(connect, "REDIRECT_URI", "https://fn/cb"), \
            patch.object(connect.gmail, "exchange_code", return_value="RT-SECRET") as ex, \
            patch.object(connect, "_set_status") as set_status:
        resp = connect.callback({"code": "c", "state": state}, SECRETS, store, db=None)
    assert resp["statusCode"] == 200
    assert store.data[UID]["refresh_token"] == "RT-SECRET"
    assert "RT-SECRET" not in resp["body"]
    assert ex.call_args.args[1] == "v"  # PKCE verifier sent
    set_status.assert_called_once_with(None, UID, "connected")


def test_callback_with_wrong_nonce_is_rejected():
    store = FakeStore()
    store.put(UID, {"pending": {"nonce": "real", "verifier": "v", "exp": 9e12}})
    state = connect._sign_state(UID, "forged", KEY)
    resp = connect.callback({"code": "c", "state": state}, SECRETS, store, db=None)
    assert resp["statusCode"] == 400
    assert "refresh_token" not in store.data[UID]


def test_disconnect_revokes_then_deletes_token():
    store = FakeStore()
    store.put(UID, {"refresh_token": "RT"})
    with patch.object(connect.gmail, "revoke", return_value=True) as rev, \
            patch.object(connect, "_set_status") as set_status:
        resp = connect.disconnect(UID, store, db=None)
    rev.assert_called_once_with("RT")
    assert resp["statusCode"] == 200 and store.data == {}
    set_status.assert_called_once_with(None, UID, "disconnected")


def test_disconnect_failure_does_not_claim_success():
    store = FakeStore()
    store.put(UID, {"refresh_token": "RT"})
    store.delete = MagicMock(side_effect=RuntimeError("boom"))
    with patch.object(connect.gmail, "revoke", return_value=False), \
            patch.object(connect, "_set_status") as set_status:
        resp = connect.disconnect(UID, store, db=None)
    assert resp["statusCode"] == 503
    set_status.assert_not_called()


def test_monitor_store_writes_one_secret_for_all_users():
    class SM:
        class exceptions:
            class ResourceNotFoundException(Exception):
                pass

        def __init__(self):
            self.value = None
            self.writes = 0

        def get_secret_value(self, SecretId):
            if self.value is None:
                raise self.exceptions.ResourceNotFoundException()
            return {"SecretString": self.value}

        def put_secret_value(self, SecretId, SecretString):
            self.writes += 1
            self.value = SecretString

        def create_secret(self, Name, SecretString):
            self.value = SecretString

    sm = SM()
    store = MonitorStore(sm)
    store.put("u1", {"refresh_token": "a"})
    store.put("u2", {"refresh_token": "b"})
    assert sorted(store.users()) == ["u1", "u2"]
    store.delete("u1")
    assert store.users() == ["u2"]
    assert json.loads(sm.value).keys() == {"u2"}
