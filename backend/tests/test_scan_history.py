import json
import importlib.util
from pathlib import Path
from unittest.mock import MagicMock, patch


HANDLER_PATH = (
    Path(__file__).resolve().parents[1]
    / "lambda"
    / "handler.py"
)

spec = importlib.util.spec_from_file_location(
    "phishnet_handler",
    HANDLER_PATH,
)
handler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handler)


def test_scan_history_returns_saved_results():
    scan = MagicMock()
    scan.id = "scan123"
    scan.to_dict.return_value = {
        "brief_description": "Suspicious delivery message",
        "scam_percentage": 85,
        "risk_level": "high",
        "summary": "Possible phishing attempt",
        "red_flags": [],
        "next_steps": ["Do not click links"],
        "createdAt": None,
    }

    db = MagicMock()

    query = (
        db.collection.return_value
        .document.return_value
        .collection.return_value
    )

    query.order_by.return_value.limit.return_value.stream.return_value = [
        scan
    ]

    with patch.object(handler.firestore, "client", return_value=db):
        results = handler._get_scan_history("test-user-123")

    assert len(results) == 1
    assert results[0]["id"] == "scan123"
    assert results[0]["risk_level"] == "high"
    assert results[0]["scam_percentage"] == 85

    db.collection.assert_called_with("users")
    db.collection.return_value.document.assert_called_with(
        "test-user-123"
    )

def test_scan_history_returns_empty_list():
    db = MagicMock()

    query = (
        db.collection.return_value
        .document.return_value
        .collection.return_value
    )

    query.order_by.return_value.limit.return_value.stream.return_value = []

    with patch.object(handler.firestore, "client", return_value=db):
        results = handler._get_scan_history("test-user-123")

    assert results == []

def test_scan_history_uses_newest_first_and_limit_20():
    db = MagicMock()

    query = (
        db.collection.return_value
        .document.return_value
        .collection.return_value
    )

    ordered_query = query.order_by.return_value
    limited_query = ordered_query.limit.return_value
    limited_query.stream.return_value = []

    with patch.object(handler.firestore, "client", return_value=db):
        results = handler._get_scan_history("test-user-123")

    assert results == []

    query.order_by.assert_called_once_with(
        "createdAt",
        direction=handler.firestore.Query.DESCENDING,
    )

    ordered_query.limit.assert_called_once_with(20)
    limited_query.stream.assert_called_once()

def test_scan_history_uses_authenticated_user_only():
    db = MagicMock()

    query = (
        db.collection.return_value
        .document.return_value
        .collection.return_value
    )

    query.order_by.return_value.limit.return_value.stream.return_value = []

    with patch.object(handler.firestore, "client", return_value=db):
        handler._get_scan_history("user-A")

    db.collection.assert_called_once_with("users")
    db.collection.return_value.document.assert_called_once_with(
        "user-A"
    )

    db.collection.return_value.document.return_value.collection.assert_called_once_with(
        "scans"
    )

def test_history_rejects_missing_authentication():
    event = {
        "headers": {},
        "body": json.dumps({"action": "scan_history"}),
    }

    with patch.object(handler, "_init", return_value={}):
        response = handler.handler(event, None)

    assert response["statusCode"] == 401
    assert json.loads(response["body"])["error"] == "unauthorized"


def test_history_uses_verified_uid_not_requested_uid():
    event = {
        "headers": {"Authorization": "Bearer test-token"},
        "body": json.dumps({
            "action": "scan_history",
            "uid": "another-user",
        }),
    }

    with (
        patch.object(handler, "_init", return_value={}),
        patch.object(handler.auth, "verify_id_token",
                     return_value={"uid": "authenticated-user"}),
        patch.object(handler, "_get_scan_history",
                     return_value=[]) as get_history,
        patch.object(handler, "_db_ready", True),
    ):
        response = handler.handler(event, None)

    assert response["statusCode"] == 200
    assert json.loads(response["body"]) == {"scans": []}
    get_history.assert_called_once_with("authenticated-user")


def test_history_returns_503_when_firestore_fails():
    event = {
        "headers": {"Authorization": "Bearer test-token"},
        "body": json.dumps({"action": "scan_history"}),
    }

    with (
        patch.object(handler, "_init", return_value={}),
        patch.object(handler.auth, "verify_id_token",
                     return_value={"uid": "test-user"}),
        patch.object(handler, "_get_scan_history",
                     side_effect=RuntimeError("Firestore unavailable")),
        patch.object(handler, "_db_ready", True),
    ):
        response = handler.handler(event, None)

    assert response["statusCode"] == 503

    body = json.loads(response["body"])
    assert body["error"] == "history_unavailable"
    assert body["retryable"] is True

def test_history_rejects_invalid_firebase_token():
    event = {
        "headers": {"Authorization": "Bearer invalid-token"},
        "body": json.dumps({"action": "scan_history"}),
    }

    with (
        patch.object(handler, "_init", return_value={}),
        patch.object(
            handler.auth,
            "verify_id_token",
            side_effect=handler.auth.InvalidIdTokenError(
                "Invalid token"
            ),
        ),
        patch.object(handler, "_get_scan_history") as get_history,
    ):
        response = handler.handler(event, None)

    assert response["statusCode"] == 401
    assert json.loads(response["body"])["error"] == "unauthorized"
    get_history.assert_not_called()
