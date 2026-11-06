import importlib.util
import json
import time
from pathlib import Path
from unittest.mock import MagicMock, patch
import urllib.error

import pytest


CONNECT_PATH = (
    Path(__file__).resolve().parents[1] / "monitor" / "connect.py"
)
spec = importlib.util.spec_from_file_location("phishnet_connect", CONNECT_PATH)
connect = importlib.util.module_from_spec(spec)
spec.loader.exec_module(connect)

KEY = "test-state-key"  # fake value, never a real credential
SECRETS = {
    "yahoo_client_id": "fake-client-id",
    "yahoo_client_secret": "fake-client-secret",
    "monitor_state_key": KEY,
}
UID = "user_abc123"


class NotFound(Exception):
    pass


class FakeSecrets:
    """In-memory stand-in for Secrets Manager (no AWS calls)."""

    def __init__(self):
        self.store = {}
        self.exceptions = MagicMock(ResourceNotFoundException=NotFound)
        self.deleted = []
        self.fail_delete = False

    def get_secret_value(self, SecretId):
        if SecretId not in self.store:
            raise NotFound(SecretId)
        return {"SecretString": self.store[SecretId]}

    def put_secret_value(self, SecretId, SecretString):
        if SecretId not in self.store:
            raise NotFound(SecretId)
        self.store[SecretId] = SecretString

    def create_secret(self, Name, SecretString):
        self.store[Name] = SecretString

    def delete_secret(self, SecretId, ForceDeleteWithoutRecovery=False):
        if self.fail_delete:
            raise RuntimeError("simulated AWS failure")
        if SecretId not in self.store:
            raise NotFound(SecretId)
        self.deleted.append(SecretId)
        del self.store[SecretId]


@pytest.fixture
def fake_sm():
    fake = FakeSecrets()
    with patch.object(connect, "_sm_client", return_value=fake), \
            patch.object(connect, "_set_status") as set_status, \
            patch.object(connect, "_get_status", return_value="disconnected"), \
            patch.object(connect, "REDIRECT_URI", "https://example.test/cb"):
        fake.set_status = set_status
        yield fake


def _start_and_get_state(fake):
    body = connect.start(UID, SECRETS)
    url = json.loads(body["body"])["authorizationUrl"]
    state = url.split("state=")[1].split("&")[0]
    return state


def test_start_returns_yahoo_url_and_stores_pending_only_in_secret(fake_sm):
    resp = connect.start(UID, SECRETS)
    assert resp["statusCode"] == 200
    url = json.loads(resp["body"])["authorizationUrl"]
    assert url.startswith("https://api.login.yahoo.com/oauth2/request_auth?")
    assert "fake-client-secret" not in url
    stored = json.loads(fake_sm.store[f"phishnet/monitor/{UID}"])
    assert "pending" in stored
    assert "refresh_token" not in stored


def test_callback_denied_keeps_monitoring_off(fake_sm):
    state = _start_and_get_state(fake_sm)
    page = connect.callback(
        {"error": "access_denied", "state": state}, SECRETS
    )
    assert page["statusCode"] == 200
    assert "needs access" in page["body"].lower()
    fake_sm.set_status.assert_called_with(UID, "disconnected")
    stored = json.loads(fake_sm.store[f"phishnet/monitor/{UID}"])
    assert "pending" not in stored
    assert "refresh_token" not in stored


def test_callback_success_stores_tokens_in_secret_only(fake_sm):
    state = _start_and_get_state(fake_sm)
    token_reply = {
        "access_token": "fake-access",
        "refresh_token": "fake-refresh",
        "expires_in": 3600,
    }
    with patch.object(connect, "_yahoo_token_request", return_value=token_reply) as req:
        page = connect.callback({"code": "fake-code", "state": state}, SECRETS)
    assert page["statusCode"] == 200
    assert req.call_args[0][0]["grant_type"] == "authorization_code"
    stored = json.loads(fake_sm.store[f"phishnet/monitor/{UID}"])
    assert stored["refresh_token"] == "fake-refresh"
    assert "pending" not in stored
    fake_sm.set_status.assert_called_with(UID, "connected")
    # Tokens must never appear in the HTML page.
    assert "fake-refresh" not in page["body"]


def test_callback_rejects_forged_state(fake_sm):
    _start_and_get_state(fake_sm)
    page = connect.callback({"code": "x", "state": f"{UID}.nonce.forged"}, SECRETS)
    assert page["statusCode"] == 400
    fake_sm.set_status.assert_not_called()


def test_callback_rejects_expired_state(fake_sm):
    state = _start_and_get_state(fake_sm)
    stored = json.loads(fake_sm.store[f"phishnet/monitor/{UID}"])
    stored["pending"]["exp"] = int(time.time()) - 1
    fake_sm.store[f"phishnet/monitor/{UID}"] = json.dumps(stored)
    page = connect.callback({"code": "x", "state": state}, SECRETS)
    assert page["statusCode"] == 400
    assert "refresh_token" not in fake_sm.store[f"phishnet/monitor/{UID}"]


def test_callback_token_exchange_failure_sets_error_without_tokens(fake_sm):
    state = _start_and_get_state(fake_sm)
    err = urllib.error.URLError("network down")
    with patch.object(connect, "_yahoo_token_request", side_effect=err):
        page = connect.callback({"code": "x", "state": state}, SECRETS)
    assert page["statusCode"] == 502
    fake_sm.set_status.assert_called_with(UID, "error")
    assert "refresh_token" not in fake_sm.store[f"phishnet/monitor/{UID}"]


def test_disconnect_deletes_secret_and_marks_disconnected(fake_sm):
    fake_sm.store[f"phishnet/monitor/{UID}"] = json.dumps({"refresh_token": "r"})
    resp = connect.disconnect(UID)
    assert resp["statusCode"] == 200
    assert f"phishnet/monitor/{UID}" not in fake_sm.store
    fake_sm.set_status.assert_called_with(UID, "disconnected")


def test_disconnect_is_idempotent_when_no_secret(fake_sm):
    resp = connect.disconnect(UID)
    assert resp["statusCode"] == 200
    fake_sm.set_status.assert_called_with(UID, "disconnected")


def test_disconnect_failure_does_not_report_success(fake_sm):
    fake_sm.store[f"phishnet/monitor/{UID}"] = json.dumps({"refresh_token": "r"})
    fake_sm.fail_delete = True
    resp = connect.disconnect(UID)
    assert resp["statusCode"] == 503
    assert json.loads(resp["body"])["retryable"] is True
    fake_sm.set_status.assert_not_called()


def test_uid_is_validated_before_building_secret_name():
    with pytest.raises(ValueError):
        connect._secret_name("../other")
    with pytest.raises(ValueError):
        connect._secret_name("")


def test_handler_requires_firebase_token(fake_sm):
    with patch.object(connect, "_init", return_value=SECRETS):
        resp = connect.handler(
            {"requestContext": {"http": {"method": "POST"}}, "body": "{}"},
            None,
        )
    assert resp["statusCode"] == 401


def test_handler_blocks_guest_tokens(fake_sm):
    event = {
        "requestContext": {"http": {"method": "POST"}},
        "headers": {"authorization": "Bearer t"},
        "body": json.dumps({"action": "start"}),
    }
    decoded = {"uid": UID, "firebase": {"sign_in_provider": "anonymous"}}
    with patch.object(connect, "_init", return_value=SECRETS), \
            patch.object(connect.auth, "verify_id_token", return_value=decoded):
        resp = connect.handler(event, None)
    assert resp["statusCode"] == 403
    assert json.loads(resp["body"])["error"] == "account_required"


def test_handler_status_never_returns_tokens(fake_sm):
    event = {
        "requestContext": {"http": {"method": "POST"}},
        "headers": {"authorization": "Bearer t"},
        "body": json.dumps({"action": "status"}),
    }
    decoded = {"uid": UID, "firebase": {"sign_in_provider": "password"}}
    fake_sm.store[f"phishnet/monitor/{UID}"] = json.dumps({"refresh_token": "secret-r"})
    with patch.object(connect, "_init", return_value=SECRETS), \
            patch.object(connect.auth, "verify_id_token", return_value=decoded):
        resp = connect.handler(event, None)
    assert resp["statusCode"] == 200
    assert "secret-r" not in resp["body"]
    assert json.loads(resp["body"]) == {"status": "disconnected"}
