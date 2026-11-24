"""Tests for scam-pattern insights. Run from backend/: python -m unittest discover -s tests"""
import copy
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lambda"))

import handler  # noqa: E402
import pattern_insights as pi  # noqa: E402

CATS = handler.RED_FLAG_CATEGORIES


def _approved(**over):
    p = {
        "id": "PI-900",
        "category": "money_request",
        "name": "Test pattern",
        "description": "Asks for a small fee.",
        "cues": ["small fee"],
        "status": "approved",
        "reviewed_by": "Payton",
        "reviewed_on": "2026-11-24",
    }
    p.update(over)
    return p


class LibraryTests(unittest.TestCase):
    def test_shipped_library_is_valid(self):
        self.assertEqual(pi.validate_patterns(pi.PATTERNS, CATS), [])

    def test_nothing_shipped_is_approved_yet(self):
        # Flip a pattern to approved only after the team reviews it.
        approved = [p["id"] for p in pi.PATTERNS if p["status"] == "approved"]
        self.assertEqual(approved, [])
        self.assertEqual(pi.guidance_text(pi.PATTERNS, CATS), "")

    def test_every_category_is_a_real_red_flag_category(self):
        for p in pi.PATTERNS:
            self.assertIn(p["category"], CATS)

    def test_rejects_bad_entries(self):
        bad = {
            "duplicate id": [_approved(), _approved()],
            "bad id": [_approved(id="X1")],
            "unknown category": [_approved(category="nope")],
            "empty description": [_approved(description=" ")],
            "no cues": [_approved(cues=[])],
            "too many cues": [_approved(cues=list("abcde"))],
            "bad status": [_approved(status="live")],
            "approved without reviewer": [_approved(reviewed_by=None)],
            "approved without date": [_approved(reviewed_on="Nov 24")],
            "long description": [_approved(description="x" * 201)],
            "not an object": ["text"],
        }
        for name, patterns in bad.items():
            with self.subTest(name):
                self.assertTrue(pi.validate_patterns(patterns, CATS))
        self.assertTrue(pi.validate_patterns("nope", CATS))

    def test_rejects_personal_details(self):
        for text in (
            "write to jane.doe@example.com",
            "visit https://usps-fee.top now",
            "go to usps-fee.top",
            "call 555-123-4567",
            "account 12345678",
        ):
            with self.subTest(text):
                p = _approved(description=text)
                self.assertTrue(pi.validate_patterns([p], CATS))
            with self.subTest("cue " + text):
                p = _approved(cues=[text])
                self.assertTrue(pi.validate_patterns([p], CATS))

    def test_limit_on_pattern_count(self):
        many = [_approved(id=f"PI-{i:03d}") for i in range(pi.MAX_PATTERNS + 1)]
        self.assertTrue(pi.validate_patterns(many, CATS))


class GuidanceTests(unittest.TestCase):
    def test_only_approved_patterns_are_used(self):
        patterns = [
            _approved(id="PI-001", name="Approved one"),
            _approved(id="PI-002", name="Draft two", status="draft",
                      reviewed_by=None, reviewed_on=None),
        ]
        text = pi.guidance_text(patterns, CATS)
        self.assertIn("Approved one", text)
        self.assertNotIn("Draft two", text)
        self.assertEqual(pi.active_ids(patterns, CATS), ["PI-001"])

    def test_ids_are_not_in_the_prompt(self):
        text = pi.guidance_text([_approved(id="PI-123")], CATS)
        self.assertNotIn("PI-123", text.split("never mention")[-1].split("\n", 1)[-1])

    def test_one_bad_entry_turns_everything_off(self):
        patterns = [_approved(id="PI-001"), _approved(id="PI-002", category="x")]
        self.assertEqual(pi.guidance_text(patterns, CATS), "")
        self.assertEqual(pi.active_ids(patterns, CATS), [])

    def test_guidance_has_a_size_cap(self):
        patterns = [
            _approved(id=f"PI-{i:03d}", description="d" * 190, cues=["c" * 70] * 4)
            for i in range(pi.MAX_PATTERNS)
        ]
        self.assertEqual(pi.guidance_text(patterns, CATS), "")


class PromptHookTests(unittest.TestCase):
    def test_off_by_default_changes_nothing(self):
        with mock.patch.object(handler, "PATTERN_INSIGHTS_ENABLED", False):
            self.assertEqual(handler._system_prompt(), handler.SYSTEM)

    def test_on_with_no_approved_patterns_changes_nothing(self):
        with mock.patch.object(handler, "PATTERN_INSIGHTS_ENABLED", True):
            self.assertEqual(handler._system_prompt(), handler.SYSTEM)

    def test_on_adds_only_approved_guidance(self):
        patterns = copy.deepcopy(pi.PATTERNS)
        patterns[0].update(
            status="approved", reviewed_by="Payton", reviewed_on="2026-11-24"
        )
        with mock.patch.object(handler, "PATTERN_INSIGHTS_ENABLED", True), \
                mock.patch.object(pi, "PATTERNS", patterns):
            prompt = handler._system_prompt()
        self.assertTrue(prompt.startswith(handler.SYSTEM))
        self.assertIn(patterns[0]["name"], prompt)
        self.assertNotIn(patterns[1]["name"], prompt)

    def test_a_broken_library_falls_back_to_the_normal_prompt(self):
        with mock.patch.object(handler, "PATTERN_INSIGHTS_ENABLED", True), \
                mock.patch.object(pi, "PATTERNS", None):
            self.assertEqual(handler._system_prompt(), handler.SYSTEM)

    def test_a_missing_module_falls_back_to_the_normal_prompt(self):
        with mock.patch.object(handler, "PATTERN_INSIGHTS_ENABLED", True), \
                mock.patch.dict(sys.modules, {"pattern_insights": None}):
            self.assertEqual(handler._system_prompt(), handler.SYSTEM)

    def test_the_scan_call_uses_the_built_prompt(self):
        seen = {}

        class FakeClient:
            def __init__(self, *a, **k):
                self.messages = self

            def create(self, **kw):
                seen.update(kw)
                raise handler.AnalysisError("stop here")

        with mock.patch.object(handler.anthropic, "Anthropic", FakeClient), \
                mock.patch.object(handler, "_system_prompt", lambda: "PROMPT"):
            with self.assertRaises(handler.AnalysisError):
                handler._analyze_once("hello", "key")
        self.assertEqual(seen["system"], "PROMPT")


if __name__ == "__main__":
    unittest.main()
