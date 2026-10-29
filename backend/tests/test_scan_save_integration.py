
import importlib.util
import json
import os
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
    "phishnet_handler_save_test",
    HANDLER_PATH,
)
handler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handler)


def test_scan_is_saved_to_firestore():
    if (
        os.environ.get("FIRESTORE_EMULATOR_HOST") != "127.0.0.1:8080"
        or os.environ.get("GOOGLE_CLOUD_PROJECT") != "demo-phishnet"
    ):
        pytest.skip("Firestore Emulator configuration required")

    db = google_firestore.Client(
        project="demo-phishnet",
        credentials=AnonymousCredentials(),
    )

    uid = f"test-scan-save-{uuid4().hex}"
    scans_ref = db.collection("users").document(uid).collection("scans")

    assessment = {
        "brief_description": "A suspicious delivery message.",
        "scam_percentage": 85,
        "risk_level": "high",
        "summary": "This may be a fake delivery notice.",
        "red_flags": [
            {
                "category": "urgency_or_pressure",
                "label": "Pressure or urgency",
                "description": "Creates pressure to act.",
                "icon": "schedule",
            }
        ],
        "next_steps": ["Do not click the link"],
    }

    event = {
        "headers": {"Authorization": "Bearer test-token"},
        "body": json.dumps({
            "text": "Your package is delayed. Click this link.",
        }),
    }

    try:
        with (
            patch.object(handler, "_init", return_value={}),
            patch.object(
                handler.auth,
                "verify_id_token",
                return_value={"uid": uid},
            ),
            patch.object(
                handler,
                "_analyze",
                return_value=assessment,
            ),
            patch.object(
                handler.firestore,
                "client",
                return_value=db,
            ),
            patch.object(handler, "_db_ready", True),
        ):
            response = handler.handler(event, None)

        assert response["statusCode"] == 200
        assert json.loads(response["body"]) == assessment

        saved_scans = list(scans_ref.stream())

        assert len(saved_scans) == 1

        saved = saved_scans[0].to_dict()

        assert saved["risk_level"] == "high"
        assert saved["scam_percentage"] == 85
        assert saved["summary"] == assessment["summary"]
        assert saved["createdAt"] is not None

        # Ensure the original message is not stored.
        assert "text" not in saved
        assert "raw_message" not in saved

    finally:
        for scan in scans_ref.stream():
            scan.reference.delete()
