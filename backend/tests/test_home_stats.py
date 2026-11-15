import importlib.util
from datetime import datetime, timezone
from pathlib import Path

HANDLER_PATH = Path(__file__).resolve().parents[1] / "lambda" / "handler.py"
spec = importlib.util.spec_from_file_location("phishnet_handler", HANDLER_PATH)
handler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handler)

NOW = datetime(2026, 11, 14, 12, 0, tzinfo=timezone.utc)


def _scan(scan_id, risk="high", reviewed=False):
    return {
        "reviewed": reviewed,
        "item": {
            "id": scan_id,
            "risk_level": risk,
            "brief_description": f"msg {scan_id}",
            "summary": "s",
        },
    }


def test_day_keys_cover_seven_utc_days_newest_first():
    keys = handler._recent_day_keys(NOW)
    assert keys[0] == "2026-11-14"
    assert keys[-1] == "2026-11-08"
    assert len(keys) == 7


def test_empty_history_returns_zeros():
    stats = handler._build_home_stats([{}] * 7, [], None, mock=False)
    assert stats["week_total"] == 0
    assert stats["scam_rate"] == 0
    assert stats["attention_48h"] == 0
    assert stats["recent_high"] == []
    assert stats["last_checked_at"] is None
    assert stats["data_source"] == "claude"


def test_counts_sum_across_days_and_scam_rate_is_whole_percent():
    days = [
        {"total": 3, "high": 1, "medium": 1, "low": 1},
        {"total": 1, "high": 0, "medium": 0, "low": 1},
        {},
    ]
    stats = handler._build_home_stats(days, [], NOW, mock=False)
    assert stats["week_total"] == 4
    assert stats["week_high"] == 1
    assert stats["week_low"] == 2
    assert stats["scam_rate"] == 25
    assert stats["last_checked_at"] == NOW.isoformat()


def test_attention_lists_unreviewed_high_risk_and_caps_at_three():
    recent = [_scan(f"s{i}") for i in range(5)] + [
        _scan("low1", risk="low"),
    ]
    stats = handler._build_home_stats([{}] * 7, recent, NOW, mock=False)
    assert stats["attention_48h"] == 5
    assert len(stats["recent_high"]) == 3
    assert stats["recent_high"][0]["id"] == "s0"


def test_reviewed_scans_leave_attention_but_stay_in_counts():
    days = [{"total": 2, "high": 2, "medium": 0, "low": 0}]
    recent = [_scan("a", reviewed=True), _scan("b")]
    stats = handler._build_home_stats(days, recent, NOW, mock=False)
    assert stats["attention_48h"] == 1
    assert [item["id"] for item in stats["recent_high"]] == ["b"]
    assert stats["week_high"] == 2


def test_mock_mode_is_labeled():
    stats = handler._build_home_stats([{}] * 7, [], None, mock=True)
    assert stats["data_source"] == "mock_analysis"


def test_scan_id_validation():
    assert handler._valid_scan_id("abc123")
    assert not handler._valid_scan_id("")
    assert not handler._valid_scan_id(None)
    assert not handler._valid_scan_id("a/b")
    assert not handler._valid_scan_id("x" * 129)
