"""Tests for the Gmail poll core and poll configuration.

Run from backend/: .venv-test/bin/python -m pytest -q tests/test_monitor_worker.py
"""

import copy
import os
import sys
from datetime import date
from pathlib import Path
from unittest.mock import patch

import pytest

MONITOR_DIR = Path(__file__).resolve().parents[1] / "monitor"
LAMBDA_DIR = Path(__file__).resolve().parents[1] / "lambda"
sys.path[:0] = [str(MONITOR_DIR), str(LAMBDA_DIR)]

import gmail  # noqa: E402
import poll  # noqa: E402
import worker  # noqa: E402

UID = "user_abc123"
SECRET_BODY = "pay the fee at http://evil.example now SECRET-BODY-123"


class FakeStore:
    def __init__(self, state=None):
        self.state = state or worker.State()
        self.saves = 0

    def load(self, uid):
        return copy.deepcopy(self.state)

    def save(self, uid, state):
        self.saves += 1
        self.state = copy.deepcopy(state)


class FakeMail:
    def __init__(self, ids=(), labels=None, unread=None, bulk=(), changes=None,
                 recent=None, full_error=None):
        self.ids = list(ids)
        self.labels = labels or {}
        self.unread = set(unread or [])
        self.bulk = set(bulk)
        self._changes = changes  # callable or None
        self._recent = recent or ("H-RECENT", self.ids)
        self.full_error = full_error
        self.full_calls = []
        self.recent_calls = 0

    def changes(self, history_id):
        if self._changes:
            return self._changes(history_id)
        return ("H-NEW", self.ids)

    def recent(self, limit):
        self.recent_calls += 1
        return self._recent

    def metadata(self, mid):
        return {
            "labels": set(self.labels.get(mid, {"INBOX"})),
            "unread": mid in self.unread,
            "bulk": mid in self.bulk,
        }

    def full(self, mid):
        self.full_calls.append(mid)
        if self.full_error:
            raise self.full_error
        return {"subject": "Hello", "from": "a@example.com", "text": SECRET_BODY}


def _run(store, mail, risk="low", save=None, scanned=(), alerts=None,
         analyze=None, cap=1):
    saved = save if save is not None else []
    alerted = alerts if alerts is not None else []
    analyze = analyze or (lambda text: {"risk_level": risk})
    summary = worker.run_once(
        UID, store, mail, analyze,
        save_scan=lambda u, k, a: saved.append((k, a["risk_level"])),
        already_scanned=lambda u, k: k in scanned,
        alert=lambda u, keys: alerted.append(list(keys)),
        cap=cap, now=lambda: 1000.0, sleep=lambda s: None,
    )
    return summary, saved, alerted


def test_first_run_resyncs_recent_mail_and_sets_checkpoint():
    store, mail = FakeStore(), FakeMail(ids=["m1"])
    summary, saved, _ = _run(store, mail)
    assert mail.recent_calls == 1
    assert summary["result"] == "ok" and summary["saved"] == 1
    assert store.state.history_id == "H-RECENT"


def test_safe_email_is_saved_but_never_alerted():
    store, mail = FakeStore(), FakeMail(ids=["m1"])
    summary, saved, alerted = _run(store, mail, risk="low")
    assert len(saved) == 1 and alerted == []
    assert summary["high_risk"] == 0


def test_high_risk_is_batched_into_one_alert_per_run():
    store = FakeStore(worker.State(history_id="H0"))
    mail = FakeMail(ids=["m1", "m2"])
    _, saved, alerted = _run(store, mail, risk="high", cap=3)
    assert len(saved) == 2
    assert len(alerted) == 1 and len(alerted[0]) == 2


def test_already_scanned_message_is_not_analyzed_again():
    key = worker.dedupe_key(UID, "m1")
    store, mail = FakeStore(worker.State(history_id="H0")), FakeMail(ids=["m1"])
    summary, saved, _ = _run(store, mail, scanned={key})
    assert summary["duplicates"] == 1
    assert saved == [] and mail.full_calls == []


def test_cap_limits_analyses_and_extra_mail_is_counted_not_scanned():
    store = FakeStore(worker.State(history_id="H0"))
    mail = FakeMail(ids=["m1", "m2", "m3"])
    summary, saved, _ = _run(store, mail, cap=1)
    assert len(saved) == 1
    assert summary["skipped_over_cap"] == 2
    assert store.state.history_id == "H-NEW"  # checkpoint still advances


def test_unread_first_and_bulk_last_before_the_cap():
    store = FakeStore(worker.State(history_id="H0"))
    mail = FakeMail(ids=["bulk", "read", "unread"], unread=["unread"], bulk=["bulk"])
    _run(store, mail, cap=1)
    assert mail.full_calls == ["unread"]


def test_sent_mail_is_ignored():
    store = FakeStore(worker.State(history_id="H0"))
    mail = FakeMail(ids=["sent"], labels={"sent": {"SENT"}})
    summary, saved, _ = _run(store, mail)
    assert saved == [] and mail.full_calls == []


def test_expired_checkpoint_resyncs_recent_mail():
    def expired(_):
        raise gmail.HistoryExpired()

    store = FakeStore(worker.State(history_id="OLD"))
    mail = FakeMail(ids=["m1"], changes=expired)
    _run(store, mail)
    assert mail.recent_calls == 1
    assert store.state.history_id == "H-RECENT"


def test_transient_error_keeps_checkpoint_so_next_run_retries():
    def flaky(_):
        raise gmail.TransientError()

    store = FakeStore(worker.State(history_id="H0"))
    summary, _, _ = _run(store, FakeMail(ids=["m1"], changes=flaky))
    assert summary["result"] == "retry"
    assert store.state.history_id == "H0"


def test_auth_error_marks_reauth_and_stops():
    def revoked(_):
        raise gmail.AuthError()

    store = FakeStore(worker.State(history_id="H0"))
    summary, saved, _ = _run(store, FakeMail(changes=revoked))
    assert summary["result"] == "reauth_needed"
    assert store.state.status == "reauth_needed" and saved == []


def test_reauth_state_is_not_polled_again():
    store = FakeStore(worker.State(history_id="H0", status="reauth_needed"))
    mail = FakeMail(ids=["m1"])
    summary, saved, _ = _run(store, mail)
    assert summary["result"] == "reauth_needed" and mail.full_calls == []


def test_permanent_message_error_is_skipped_and_run_continues():
    store = FakeStore(worker.State(history_id="H0"))
    mail = FakeMail(ids=["m1"], full_error=gmail.PermanentError())
    summary, saved, _ = _run(store, mail)
    assert summary["failed"] == 1 and saved == []
    assert store.state.history_id == "H-NEW"


def test_transient_analysis_error_retries_then_gives_up_without_checkpoint_move():
    calls = []

    def analyze(text):
        calls.append(text)
        raise gmail.TransientError()

    store = FakeStore(worker.State(history_id="H0"))
    summary, saved, _ = _run(store, FakeMail(ids=["m1"]), analyze=analyze)
    assert len(calls) == worker.MAX_ATTEMPTS
    assert summary["result"] == "retry" and store.state.history_id == "H0"


def test_busy_lease_skips_the_run():
    store = FakeStore(worker.State(history_id="H0", lease_until=2000.0))
    summary, _, _ = _run(store, FakeMail(ids=["m1"]))
    assert summary["result"] == "busy"


def test_logs_and_summaries_never_contain_content():
    store = FakeStore(worker.State(history_id="H0"))
    with patch.object(worker.log, "info") as info, patch.object(worker.log, "warning") as warn:
        summary, _, _ = _run(store, FakeMail(ids=["m1"]))
    text = repr(info.call_args_list) + repr(warn.call_args_list) + repr(summary)
    assert "SECRET-BODY" not in text and "m1" not in text


# ---------- poll configuration ----------


@pytest.mark.parametrize("env,today,expected", [
    ({}, date(2026, 11, 20), (False, 0)),                                   # off by default
    ({"MONITOR_ENABLED": "true"}, date(2026, 11, 20), (False, 0)),           # no end date: fail closed
    ({"MONITOR_ENABLED": "true", "MONITOR_UNTIL": "2026-12-19"},
     date(2026, 12, 20), (False, 0)),                                       # past the window
    ({"MONITOR_ENABLED": "true", "MONITOR_UNTIL": "2026-12-19"},
     date(2026, 11, 20), (True, 1)),                                        # default cap is 1
    ({"MONITOR_ENABLED": "true", "MONITOR_UNTIL": "2026-12-19",
      "MONITOR_MAX_PER_RUN": "9"}, date(2026, 11, 20), (True, 3)),          # hard ceiling 3
    ({"MONITOR_ENABLED": "true", "MONITOR_UNTIL": "2026-12-19",
      "MONITOR_MAX_PER_RUN": "0"}, date(2026, 11, 20), (True, 1)),          # floor 1
    ({"MONITOR_ENABLED": "TRUE", "MONITOR_UNTIL": "not-a-date"},
     date(2026, 11, 20), (False, 0)),                                       # bad date: fail closed
])
def test_poll_config_fails_closed(env, today, expected):
    with patch.dict(os.environ, env, clear=True):
        assert poll._config(today) == expected


# ---------- retry safety in the poll wiring ----------


class AlreadyExists(Exception):
    pass


def test_retry_of_an_already_saved_scan_is_not_an_error():
    with patch.object(poll.handler, "_save_scan", side_effect=AlreadyExists()):
        poll._save_scan(UID, "k" * 64, {"risk_level": "high"})  # must not raise


def test_repeat_alert_for_same_scans_is_not_written_twice():
    from unittest.mock import MagicMock
    db = MagicMock()
    ref = db.collection.return_value.document.return_value.collection.return_value.document.return_value
    ref.get.return_value.exists = True  # already written on a previous attempt
    poll._write_alert(db, UID, ["a" * 64])
    ref.set.assert_not_called()
