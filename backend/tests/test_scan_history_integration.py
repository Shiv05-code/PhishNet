
import importlib.util
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

import pytest
from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore as google_firestore


HANDLER_PATH = (
    Path(__file__).resolve().parents[1]
    / "lambda"
    / "handler.py"
)

spec = importlib.util.spec_from_file_location(
    "phishnet_handler_integration",
    HANDLER_PATH,
)
handler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handler)


def test_scan_history_firestore_integration():
    # Never run this test against production Firestore.
    if (
        os.environ.get("FIRESTORE_EMULATOR_HOST") != "127.0.0.1:8080"
        or os.environ.get("GOOGLE_CLOUD_PROJECT") != "demo-phishnet"
    ):
        pytest.skip("Firestore Emulator configuration required")

    db = google_firestore.Client(
        project="demo-phishnet",
        credentials=AnonymousCredentials(),
    )

    # Unique IDs prevent collisions with other tests.
    user_a = f"test-user-a-{uuid4().hex}"
    user_b = f"test-user-b-{uuid4().hex}"

    now = datetime.now(timezone.utc)

    records = [
        (user_a, "old", now - timedelta(days=2), "low"),
        (user_a, "middle", now - timedelta(days=1), "medium"),
        (user_a, "new", now, "high"),
        (user_b, "private", now, "high"),
    ]

    try:
        for uid, scan_id, created_at, risk in records:
            db.collection("users").document(uid).collection(
                "scans"
            ).document(scan_id).set({
                "brief_description": "Test scan",
                "scam_percentage": {
                    "low": 10,
                    "medium": 50,
                    "high": 90,
                }[risk],
                "risk_level": risk,
                "summary": "Integration test result",
                "red_flags": [],
                "next_steps": ["Verify the sender"],
                "createdAt": created_at,
                "raw_message": "Do not expose this private text",
            })

        with patch.object(
            handler.firestore,
            "client",
            return_value=db,
        ):
            results_a = handler._get_scan_history(user_a)
            results_b = handler._get_scan_history(user_b)

        assert [scan["id"] for scan in results_a] == [
            "new", "middle", "old"
        ]
        assert [scan["id"] for scan in results_b] == ["private"]

        assert all(
            "raw_message" not in scan
            for scan in results_a + results_b
        )

        assert results_a[0]["risk_level"] == "high"
        assert results_a[0]["scam_percentage"] == 90

    finally:
        # Clean up only the documents created by this test.
        for uid, scan_id, _, _ in records:
            db.collection("users").document(uid).collection(
                "scans"
            ).document(scan_id).delete()
