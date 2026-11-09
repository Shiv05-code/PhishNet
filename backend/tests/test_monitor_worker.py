import importlib.util
import logging
from pathlib import Path

import pytest

WORKER_PATH = Path(__file__).resolve().parents[1] / "monitor" / "worker.py"
spec = importlib.util.spec_from_file_location("phishnet_worker", WORKER_PATH)
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)

SECRET_TEXT = "pay the fee at http://evil.example now SECRET-TOKEN-123"


class FakeStore:
    def __init__(self):
        self.states = {}
        self.saves = 0

    def load(self, uid):
        import copy
        return copy.deepcopy(self.states.get(uid, worker.State()))

    def save(self, uid, state):
        import copy
        self.saves += 1
        self.states[uid] = copy.deepcopy(state)


class FakeMail:
    """messages: list of (message_id, text) indexed by IMAP-style uid 1..n."""

    def __init__(self, messages, validity=7, errors=None):
        self.messages = {i + 1: m for i, m in enumerate(messages)}
        self.validity = validity
        self.errors = errors or {}  # uid -> exception to raise on fetch
        self.fetched = []

    def list_uids(self, after_uid, limit):
        uids = sorted(u for u in self.messages if u > after_uid)[:limit]
        return self.validity, uids

    def fetch(self, uid):
        self.fetched.append(uid)
        if uid in self.errors:
            err = self.errors[uid]
            if isinstance(err, list):
                raise err.pop(0)
            raise err
        mid, text = self.messages[uid]
        return worker.Message(mid, text)


class Recorder:
    def __init__(self, risk="low", fail=None):
        self.calls = []
        self.risk = risk
        self.fail = fail or []  # list of exceptions raised in order first

    def analyze(self, text):
        if self.fail:
            raise self.fail.pop(0)
        return {"risk_level": self.risk, "scam_percentage": 10}


class SaveLog:
    def __init__(self):
        self.docs = {}
        self.writes = 0

    def __call__(self, uid, key, assessment):
        self.writes += 1
        self.docs[key] = assessment  # idempotent on key


def _run(store, mail, rec, saves, now=lambda: 1000.0):
    return worker.run_once("u1", store, mail, rec.analyze, saves,
                           now=now, sleep=lambda s: None)


def test_new_messages_are_saved_and_checkpoint_advances():
    store, saves = FakeStore(), SaveLog()
    mail = FakeMail([("<a@x>", "one"), ("<b@x>", "two")])
    out = _run(store, mail, Recorder(), saves)
    assert out["result"] == "ok" and out["saved"] == 2
    assert store.states["u1"].last_uid == 2
    assert store.states["u1"].lease_until == 0.0


def test_second_run_with_no_new_mail_is_a_noop():
    store, saves = FakeStore(), SaveLog()
    mail = FakeMail([("<a@x>", "one")])
    _run(store, mail, Recorder(), saves)
    out = _run(store, mail, Recorder(), saves)
    assert out["saved"] == 0 and saves.writes == 1


def test_same_message_id_in_two_places_is_saved_once():
    store, saves = FakeStore(), SaveLog()
    mail = FakeMail([("<dup@x>", "one"), ("<dup@x>", "one again")])
    out = _run(store, mail, Recorder(), saves)
    assert out["saved"] == 1 and out["duplicates"] == 1
    assert saves.writes == 1


def test_overlapping_run_is_rejected_while_lease_is_held():
    store, saves = FakeStore(), SaveLog()
    store.states["u1"] = worker.State(lease_until=2000.0)
    out = _run(store, FakeMail([("<a@x>", "one")]), Recorder(), saves,
               now=lambda: 1000.0)
    assert out["result"] == "busy" and saves.writes == 0


def test_expired_lease_is_taken_over():
    store, saves = FakeStore(), SaveLog()
    store.states["u1"] = worker.State(lease_until=500.0)
    out = _run(store, FakeMail([("<a@x>", "one")]), Recorder(), saves,
               now=lambda: 1000.0)
    assert out["result"] == "ok"


def test_lease_is_released_even_when_run_fails():
    store, saves = FakeStore(), SaveLog()
    mail = FakeMail([("<a@x>", "one")], errors={1: worker.AuthError()})
    _run(store, mail, Recorder(), saves)
    assert store.states["u1"].lease_until == 0.0


def test_transient_error_is_retried_then_succeeds():
    store, saves = FakeStore(), SaveLog()
    rec = Recorder(fail=[worker.TransientError(), worker.TransientError()])
    out = _run(store, FakeMail([("<a@x>", "one")]), rec, saves)
    assert out["result"] == "ok" and out["saved"] == 1


def test_exhausted_transient_error_stops_without_skipping_message():
    store, saves = FakeStore(), SaveLog()
    rec = Recorder(fail=[worker.TransientError()] * worker.MAX_ATTEMPTS)
    mail = FakeMail([("<a@x>", "one"), ("<b@x>", "two")])
    out = _run(store, mail, rec, saves)
    assert out["result"] == "retry" and saves.writes == 0
    assert store.states["u1"].last_uid == 0  # next run starts from here


def test_permanent_error_skips_only_that_message():
    store, saves = FakeStore(), SaveLog()
    rec = Recorder(fail=[worker.PermanentError()])
    out = _run(store, FakeMail([("<a@x>", "one"), ("<b@x>", "two")]), rec, saves)
    assert out["skipped"] == 1 and out["saved"] == 1
    assert store.states["u1"].last_uid == 2


def test_auth_error_marks_reauth_needed_and_later_runs_stop():
    store, saves = FakeStore(), SaveLog()
    mail = FakeMail([("<a@x>", "one")], errors={1: worker.AuthError()})
    out = _run(store, mail, Recorder(), saves)
    assert out["result"] == "reauth_needed"
    fetched_before = len(mail.fetched)
    out2 = _run(store, mail, Recorder(), saves)
    assert out2["result"] == "reauth_needed"
    assert len(mail.fetched) == fetched_before


def test_pagination_is_bounded_per_run_and_continues_next_run(monkeypatch):
    monkeypatch.setattr(worker, "MAX_MESSAGES_PER_RUN", 3)
    store, saves = FakeStore(), SaveLog()
    mail = FakeMail([(f"<m{i}@x>", f"t{i}") for i in range(5)])
    out = _run(store, mail, Recorder(), saves)
    assert out["saved"] == 3 and store.states["u1"].last_uid == 3
    out2 = _run(store, mail, Recorder(), saves)
    assert out2["saved"] == 2 and store.states["u1"].last_uid == 5


def test_uid_validity_change_resets_checkpoint_without_duplicate_saves():
    store, saves = FakeStore(), SaveLog()
    _run(store, FakeMail([("<a@x>", "one")], validity=7), Recorder(), saves)
    out = _run(store, FakeMail([("<a@x>", "one")], validity=9), Recorder(), saves)
    assert out["duplicates"] == 1 and saves.writes == 1
    assert store.states["u1"].uid_validity == 9


def test_high_risk_keys_are_reported_for_alerts():
    store, saves = FakeStore(), SaveLog()
    out = _run(store, FakeMail([("<a@x>", "one")]),
               Recorder(risk="high"), saves)
    assert out["high_risk"] == [worker.dedupe_key(worker.Message("<a@x>", ""), 1)]


def test_seen_window_is_capped(monkeypatch):
    monkeypatch.setattr(worker, "SEEN_LIMIT", 2)
    monkeypatch.setattr(worker, "MAX_MESSAGES_PER_RUN", 10)
    store, saves = FakeStore(), SaveLog()
    mail = FakeMail([(f"<m{i}@x>", "t") for i in range(4)])
    _run(store, mail, Recorder(), saves)
    assert len(store.states["u1"].seen) == 2


def test_logs_never_contain_message_text_or_tokens(caplog):
    caplog.set_level(logging.DEBUG, logger="monitor.worker")
    store, saves = FakeStore(), SaveLog()
    mail = FakeMail([("<secret-id@x>", SECRET_TEXT)],
                    errors={})
    rec = Recorder(fail=[worker.PermanentError("boom " + SECRET_TEXT)])
    _run(store, mail, rec, saves)
    logged = " ".join(r.getMessage() for r in caplog.records)
    assert "SECRET-TOKEN-123" not in logged
    assert "evil.example" not in logged
    assert "secret-id" not in logged


@pytest.mark.parametrize("mid,expected_same", [
    ("<a@x>", True), ("<a@x>", True),
])
def test_dedupe_key_is_stable_for_same_message_id(mid, expected_same):
    k1 = worker.dedupe_key(worker.Message(mid, "x"), 1)
    k2 = worker.dedupe_key(worker.Message(mid, "y"), 99)
    assert (k1 == k2) is expected_same


def test_dedupe_key_falls_back_to_uid_without_message_id():
    k1 = worker.dedupe_key(worker.Message(None, "x"), 1)
    k2 = worker.dedupe_key(worker.Message(None, "x"), 2)
    assert k1 != k2
