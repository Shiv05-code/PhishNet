import importlib.util
import json
from pathlib import Path

MONITOR = Path(__file__).resolve().parents[1] / "monitor"


def _load(name, filename):
    import sys
    sys.path.insert(0, str(MONITOR))
    sys.path.insert(0, str(MONITOR.parent / "lambda"))
    spec = importlib.util.spec_from_file_location(name, MONITOR / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


connect = _load("connect_under_test", "connect.py")


class _Db:
    def __init__(self):
        self.writes = []

    def collection(self, *_):
        return self

    def document(self, *_):
        return self

    def set(self, data):
        self.writes.append(data)


def test_register_device_rejects_bad_token_and_platform():
    db = _Db()
    assert connect.register_device("u", "short", "ios", db)["statusCode"] == 400
    assert connect.register_device("u", "x" * 40, "web", db)["statusCode"] == 400
    assert db.writes == []


def test_register_device_stores_hashed_doc_without_logging_token():
    db = _Db()
    resp = connect.register_device("u", "x" * 40, "android", db)
    assert resp["statusCode"] == 200
    assert db.writes[0]["platform"] == "android"
    assert db.writes[0]["token"] == "x" * 40
    assert json.loads(resp["body"]) == {"registered": True}
