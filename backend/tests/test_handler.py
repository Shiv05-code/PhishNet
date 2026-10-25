"""Tests for the scan handler. Run from backend/: python -m unittest discover -s tests"""
import base64
import io
import json
import os
import sys
import unittest
from contextlib import redirect_stdout
from types import SimpleNamespace
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lambda"))

import handler  # noqa: E402

VALID = {
    "brief_description": "The message appears to be about a package delivery.",
    "scam_percentage": 80,
    "risk_level": "high",
    "summary": "This asks you to pay a fee to get a parcel.",
    "red_flags": [
        {
            "category": "money_request",
            "description": "Asks you to pay a fee.",
        },
        {
            "category": "suspicious_link_or_contact",
            "description": "Uses an unfamiliar link.",
        },
    ],
    "next_steps": ["Do not click the link", "Contact the store directly"],
}


def _event(text=None, token="good-token", raw_body=None):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    body = raw_body if raw_body is not None else json.dumps({"text": text})
    if token:
        headers["Authorization"] = "Bearer " + token
    return {"headers": headers, "body": body}


def _tool_response(tool_input):
    block = SimpleNamespace(type="tool_use", input=tool_input)
    return SimpleNamespace(content=[block])


class HandlerTestCase(unittest.TestCase):
    def setUp(self):
        def verify(token):
            if token != "good-token":
                raise ValueError("bad token")
            return {"uid": "user-1"}

        self.patches = [
            mock.patch.object(handler, "_init", return_value={"anthropic_api_key": "k"}),
            mock.patch.object(handler, "_db_ready", False),
            mock.patch.object(handler, "MOCK", False),
            mock.patch.object(handler.auth, "verify_id_token", side_effect=verify),
        ]
        for p in self.patches:
            p.start()
        self.addCleanup(lambda: [p.stop() for p in self.patches])

        self.client = mock.MagicMock()
        self.client.messages.create.return_value = _tool_response(dict(VALID))
        anthropic_cls = mock.patch.object(handler.anthropic, "Anthropic", return_value=self.client)
        anthropic_cls.start()
        self.addCleanup(anthropic_cls.stop)

    def call(self, **kwargs):
        return handler.handler(_event(**kwargs), None)


class AuthAndInputTests(HandlerTestCase):
    def test_missing_bearer_token_is_rejected_before_analysis(self):
        resp = handler.handler({"headers": {}, "body": json.dumps({"text": "hi"})}, None)
        self.assertEqual(resp["statusCode"], 401)
        self.client.messages.create.assert_not_called()

    def test_invalid_token_is_rejected_before_analysis(self):
        resp = self.call(text="hi", token="bad")
        self.assertEqual(resp["statusCode"], 401)
        self.client.messages.create.assert_not_called()

    def test_empty_text_is_rejected_before_analysis(self):
        resp = self.call(text="   ")
        self.assertEqual(resp["statusCode"], 400)
        self.assertEqual(json.loads(resp["body"]), {"error": "empty_message"})
        self.client.messages.create.assert_not_called()

    def test_text_is_truncated_to_8000_characters(self):
        self.call(text="a" * 9000)
        content = self.client.messages.create.call_args.kwargs["messages"][0]["content"]
        self.assertIn("a" * 8000, content)
        self.assertNotIn("a" * 8001, content)

    def test_base64_encoded_body_is_decoded(self):
        raw = base64.b64encode(json.dumps({"text": "hello"}).encode()).decode()
        resp = handler.handler({"headers": {"authorization": "Bearer good-token"}, "body": raw, "isBase64Encoded": True}, None)
        self.assertEqual(resp["statusCode"], 200)


class SameTextPayloadTests(HandlerTestCase):
    def test_manual_and_ocr_text_use_the_same_text_only_payload(self):
        manual = "Your parcel is held. Pay 2 dollars at http://example.test"
        ocr = "Your pa rcel is he1d.  Pay 2 dol1ars at http://examp1e.test\n"

        self.call(text=manual)
        self.call(text=ocr)

        calls = self.client.messages.create.call_args_list
        for call, source in zip(calls, [manual, ocr]):
            kwargs = call.kwargs
            self.assertEqual(set(kwargs["messages"][0].keys()), {"role", "content"})
            self.assertEqual(kwargs["messages"][0]["role"], "user")
            self.assertIsInstance(kwargs["messages"][0]["content"], str)
            self.assertIn(source.strip(), kwargs["messages"][0]["content"])
            self.assertNotIn("image", json.dumps(kwargs).lower())

    def test_request_body_contract_is_text_only(self):
        resp = self.call(text="hello")
        self.assertEqual(resp["statusCode"], 200)


class PromptAndSchemaTests(unittest.TestCase):
    def test_tool_requires_every_assessment_field(self):
        required = set(handler.TOOL["input_schema"]["required"])
        self.assertEqual(required, set(handler.ASSESSMENT_FIELDS))

    def test_tool_risk_enum_is_low_medium_high(self):
        props = handler.TOOL["input_schema"]["properties"]
        self.assertEqual(props["risk_level"]["enum"], ["low", "medium", "high"])
        self.assertEqual(props["scam_percentage"]["type"], "integer")
        red_flag = props["red_flags"]["items"]
        self.assertEqual(red_flag["type"], "object")
        self.assertEqual(
            red_flag["properties"]["category"]["enum"],
            list(handler.RED_FLAG_CATEGORIES),
        )

    def test_system_prompt_treats_message_as_untrusted(self):
        self.assertIn("untrusted", handler.SYSTEM)
        self.assertIn("not a probability", handler.SYSTEM)
        self.assertIn("OCR errors", handler.SYSTEM)
        self.assertIn("not that the message is guaranteed safe", handler.SYSTEM)
        self.assertIn("avoid jargon, fluff", handler.SYSTEM)
        self.assertIn("calm, kind helper", handler.SYSTEM)
        self.assertIn("without talking down", handler.SYSTEM)
        self.assertIn("15 words max", handler.SYSTEM)
        self.assertIn("30 words", handler.SYSTEM)
        self.assertIn("at most 4 red_flags and 3 next_steps", handler.SYSTEM)
        self.assertIn("A link or urgent wording alone does not prove a scam", handler.SYSTEM)
        self.assertIn("avoid jargon, fluff", handler.SYSTEM)


class MappingTests(HandlerTestCase):
    def test_valid_response_maps_to_full_schema(self):
        resp = self.call(text="hello")
        self.assertEqual(resp["statusCode"], 200)
        body = json.loads(resp["body"])
        self.assertEqual(set(body.keys()), set(handler.ASSESSMENT_FIELDS))
        self.assertEqual(body["scam_percentage"], 80)
        self.assertEqual(body["risk_level"], "high")

    def test_extra_fields_from_claude_are_dropped(self):
        self.client.messages.create.return_value = _tool_response({**VALID, "extra": "x"})
        body = json.loads(self.call(text="hello")["body"])
        self.assertNotIn("extra", body)

    def test_score_boundaries_map_to_risk_levels(self):
        cases = {0: "low", 33: "low", 34: "medium", 66: "medium", 67: "high", 100: "high"}
        for score, risk in cases.items():
            with self.subTest(score=score):
                self.assertEqual(handler.risk_for_score(score), risk)
                self.client.messages.create.return_value = _tool_response(
                    {**VALID, "scam_percentage": score, "risk_level": risk}
                )
                resp = self.call(text="hello")
                self.assertEqual(resp["statusCode"], 200)

    def test_empty_red_flags_is_allowed(self):
        self.client.messages.create.return_value = _tool_response(
            {**VALID, "scam_percentage": 5, "risk_level": "low", "red_flags": []}
        )
        resp = self.call(text="hello")
        self.assertEqual(resp["statusCode"], 200)
        self.assertEqual(json.loads(resp["body"])["red_flags"], [])

    def test_red_flags_receive_stable_labels_and_icon_keys(self):
        body = json.loads(self.call(text="hello")["body"])
        first_flag = body["red_flags"][0]
        self.assertEqual(first_flag["category"], "money_request")
        self.assertEqual(first_flag["label"], "Money request")
        self.assertEqual(first_flag["icon"], "payments")


class InvalidResponseTests(HandlerTestCase):
    def assert_retryable_failure(self, resp):
        self.assertEqual(resp["statusCode"], 502)
        body = json.loads(resp["body"])
        self.assertEqual(body["error"], "analysis_unavailable")
        self.assertTrue(body["retryable"])
        self.assertEqual(body["message"], "We couldn't check this message right now. Please try again.")
        self.assertNotIn("Traceback", resp["body"])

    def test_missing_field_is_retryable_error(self):
        bad = dict(VALID)
        del bad["summary"]
        self.client.messages.create.return_value = _tool_response(bad)
        self.assert_retryable_failure(self.call(text="hello"))

    def test_score_out_of_range_is_retryable_error(self):
        self.client.messages.create.return_value = _tool_response({**VALID, "scam_percentage": 101})
        self.assert_retryable_failure(self.call(text="hello"))

    def test_boolean_and_float_scores_are_rejected(self):
        for bad_score in (True, 80.0, "80"):
            with self.subTest(score=bad_score):
                self.client.messages.create.return_value = _tool_response({**VALID, "scam_percentage": bad_score})
                self.assert_retryable_failure(self.call(text="hello"))

    def test_risk_inconsistent_with_score_is_retryable_error(self):
        self.client.messages.create.return_value = _tool_response({**VALID, "scam_percentage": 10, "risk_level": "high"})
        self.assert_retryable_failure(self.call(text="hello"))

    def test_unknown_risk_level_is_retryable_error(self):
        self.client.messages.create.return_value = _tool_response({**VALID, "risk_level": "critical"})
        self.assert_retryable_failure(self.call(text="hello"))

    def test_empty_next_steps_is_retryable_error(self):
        self.client.messages.create.return_value = _tool_response({**VALID, "next_steps": []})
        self.assert_retryable_failure(self.call(text="hello"))

    def test_unknown_red_flag_category_is_retryable_error(self):
        self.client.messages.create.return_value = _tool_response(
            {**VALID, "red_flags": [{"category": "scam", "description": "Bad"}]}
        )
        self.assert_retryable_failure(self.call(text="hello"))

    def test_too_many_red_flags_is_retryable_error(self):
        flags = [
            {"category": "money_request", "description": "Asks for money."}
        ] * 5
        self.client.messages.create.return_value = _tool_response(
            {**VALID, "red_flags": flags}
        )
        self.assert_retryable_failure(self.call(text="hello"))

    def test_far_overlong_assessment_field_is_retryable_error(self):
        self.client.messages.create.return_value = _tool_response(
            {**VALID, "summary": "word " * (30 * handler.WORD_SLACK + 1)}
        )
        self.assert_retryable_failure(self.call(text="hello"))

    def test_slightly_overlong_fields_are_accepted(self):
        long = {
            **VALID,
            "brief_description": "word " * 20,
            "summary": "word " * 40,
            "red_flags": [{"category": "money_request", "description": "word " * 15}],
            "next_steps": ["word " * 15],
        }
        self.client.messages.create.return_value = _tool_response(long)
        resp = self.call(text="hello")
        self.assertEqual(resp["statusCode"], 200)

    def test_invalid_output_is_retried_once_then_succeeds(self):
        bad = {**VALID, "next_steps": []}
        self.client.messages.create.side_effect = [
            _tool_response(bad),
            _tool_response(dict(VALID)),
        ]
        resp = self.call(text="hello")
        self.assertEqual(resp["statusCode"], 200)
        self.assertEqual(self.client.messages.create.call_count, 2)

    def test_invalid_output_twice_is_retryable_error_after_two_attempts(self):
        bad = {**VALID, "next_steps": []}
        self.client.messages.create.side_effect = [
            _tool_response(bad),
            _tool_response(bad),
        ]
        self.assert_retryable_failure(self.call(text="hello"))
        self.assertEqual(self.client.messages.create.call_count, 2)

    def test_provider_error_is_not_retried(self):
        self.client.messages.create.side_effect = handler.anthropic.APIError(
            "boom", request=None, body=None
        )
        self.assert_retryable_failure(self.call(text="hello"))
        self.assertEqual(self.client.messages.create.call_count, 1)

    def test_validation_reason_is_logged_without_message_text(self):
        self.client.messages.create.return_value = _tool_response({**VALID, "next_steps": []})
        buf = io.StringIO()
        with redirect_stdout(buf):
            self.call(text="very private message 12345")
        self.assertIn("bad list field", buf.getvalue())
        self.assertNotIn("very private", buf.getvalue())
        self.assertNotIn("12345", buf.getvalue())

    def test_missing_tool_output_is_retryable_error(self):
        self.client.messages.create.return_value = SimpleNamespace(
            content=[SimpleNamespace(type="text", text="hi")]
        )
        self.assert_retryable_failure(self.call(text="hello"))

    def test_malformed_tool_response_is_retryable_error(self):
        self.client.messages.create.return_value = SimpleNamespace(
            content=[SimpleNamespace(type="tool_use")]
        )
        self.assert_retryable_failure(self.call(text="hello"))

    def test_provider_error_is_wrapped_without_raw_message(self):
        self.client.messages.create.side_effect = handler.anthropic.APIError(
            "secret provider detail", request=None, body=None
        )
        self.assert_retryable_failure(self.call(text="hello"))


class MockModeTests(HandlerTestCase):
    def test_mock_mode_does_not_call_anthropic(self):
        with mock.patch.object(handler, "MOCK", True):
            resp = self.call(text="hello")
        self.assertEqual(resp["statusCode"], 200)
        self.client.messages.create.assert_not_called()

    def test_mock_result_is_complete_and_deterministic(self):
        with mock.patch.object(handler, "MOCK", True):
            first = json.loads(self.call(text="hello")["body"])
            second = json.loads(self.call(text="something else")["body"])
        self.assertEqual(set(first.keys()), set(handler.ASSESSMENT_FIELDS))
        self.assertEqual(first, second)


class AnonymizationTests(unittest.TestCase):
    def test_anonymized_scan_keeps_new_fields_without_message_or_user_data(self):
        scan_data = {
            "brief_description": "A delivery message asks for payment.",
            "scam_percentage": 85,
            "risk_level": "high",
            "summary": "It asks you to pay using an unfamiliar link.",
            "red_flags": [
                {
                    "category": "money_request",
                    "label": "Money request",
                    "description": "Asks you to pay a fee.",
                    "icon": "payments",
                }
            ],
            "next_steps": ["Do not click the link"],
            "text": "Private message content",
            "uid": "user-1",
        }
        scan = mock.Mock()
        scan.to_dict.return_value = scan_data
        scan.reference = object()
        scans_ref = mock.Mock()
        scans_ref.stream.return_value = [scan]
        user_ref = mock.Mock()
        user_ref.collection.return_value = scans_ref
        anonymous_ref = mock.Mock()
        anonymous_doc_ref = object()
        anonymous_ref.document.return_value = anonymous_doc_ref
        batch = mock.Mock()
        user_collection = mock.Mock()
        user_collection.document.return_value = user_ref
        db = mock.Mock()
        db.collection.side_effect = lambda name: {
            "users": user_collection,
            "anonymized_training_scans": anonymous_ref,
        }[name]
        db.batch.return_value = batch

        with mock.patch.object(handler.firestore, "client", return_value=db):
            handler._anonymize_and_delete_user_data("user-1")

        batch.set.assert_called_once()
        copied = batch.set.call_args.args[1]
        self.assertEqual(copied["brief_description"], scan_data["brief_description"])
        self.assertEqual(copied["scam_percentage"], 85)
        self.assertEqual(copied["red_flags"], scan_data["red_flags"])
        self.assertNotIn("text", copied)
        self.assertNotIn("uid", copied)
        batch.delete.assert_called_once_with(scan.reference)
        batch.commit.assert_called_once()
        user_ref.delete.assert_called_once()


class IndependenceTests(HandlerTestCase):
    def test_distinct_requests_reach_analysis_independently(self):
        self.client.messages.create.side_effect = [
            _tool_response({**VALID, "scam_percentage": 90, "risk_level": "high"}),
            _tool_response({**VALID, "scam_percentage": 5, "risk_level": "low", "red_flags": []}),
        ]
        first = json.loads(self.call(text="first message")["body"])
        second = json.loads(self.call(text="second message")["body"])

        self.assertEqual(first["risk_level"], "high")
        self.assertEqual(second["risk_level"], "low")
        contents = [c.kwargs["messages"][0]["content"] for c in self.client.messages.create.call_args_list]
        self.assertIn("first message", contents[0])
        self.assertIn("second message", contents[1])
        self.assertNotIn("second message", contents[0])

    def test_mock_results_do_not_share_mutable_state(self):
        with mock.patch.object(handler, "MOCK", True):
            first = handler._analyze("a", None)
            first["red_flags"].append("tampered")
            second = handler._analyze("b", None)
        self.assertNotIn("tampered", second["red_flags"])
        self.assertNotIn("tampered", handler.MOCK_RESULT["red_flags"])


class PrivacyTests(HandlerTestCase):
    def test_message_text_is_not_logged_on_failure(self):
        self.client.messages.create.side_effect = handler.anthropic.APIError(
            "boom", request=None, body=None
        )
        buf = io.StringIO()
        with redirect_stdout(buf):
            self.call(text="very private message 12345")
        self.assertNotIn("very private message", buf.getvalue())
        self.assertNotIn("12345", buf.getvalue())

    def test_message_text_is_not_logged_on_success(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            self.call(text="very private message 12345")
        self.assertEqual(buf.getvalue(), "")

    def test_only_text_is_sent_to_claude(self):
        self.call(text="hello")
        kwargs = self.client.messages.create.call_args.kwargs
        self.assertNotIn("image", json.dumps(kwargs).lower())
        self.assertNotIn("base64", json.dumps(kwargs).lower())


def _chat_response(text):
    block = SimpleNamespace(type="text", text=text)
    return SimpleNamespace(content=[block])


SCAN = {
    "message": "Your parcel is held. Pay 2 dollars at http://example.test",
    "assessment": {
        "brief_description": "A delivery message asks you to pay a fee.",
        "scam_percentage": 85,
        "risk_level": "high",
        "summary": "This may be a fake delivery notice.",
        "red_flags": [
            {"category": "money_request", "label": "Money request", "description": "Asks you to pay a fee."}
        ],
        "next_steps": ["Do not click the link"],
    },
}


class ChatTests(HandlerTestCase):
    def setUp(self):
        super().setUp()
        self.client.messages.create.return_value = _chat_response("Please do not click the link.")

    def chat(self, token="good-token", **fields):
        body = json.dumps({"action": "chat", **fields})
        return handler.handler(_event(token=token, raw_body=body), None)

    def sent(self):
        return self.client.messages.create.call_args.kwargs

    def test_answer_is_returned(self):
        resp = self.chat(question="Is this safe?", scan=SCAN)
        self.assertEqual(resp["statusCode"], 200)
        self.assertEqual(json.loads(resp["body"]), {"answer": "Please do not click the link."})

    def test_requires_a_valid_token(self):
        resp = self.chat(token="bad", question="Is this safe?")
        self.assertEqual(resp["statusCode"], 401)
        self.client.messages.create.assert_not_called()

    def test_empty_question_is_rejected_before_claude(self):
        for question in ("", "   ", None):
            resp = self.chat(question=question, scan=SCAN)
            self.assertEqual(resp["statusCode"], 400)
            self.assertEqual(json.loads(resp["body"]), {"error": "empty_question"})
        self.client.messages.create.assert_not_called()

    def test_question_is_truncated(self):
        self.chat(question="q" * 5000)
        content = self.sent()["messages"][-1]["content"]
        self.assertEqual(len(content), handler.CHAT_MAX_QUESTION)

    def test_scan_message_and_assessment_are_sent_as_tagged_context(self):
        self.chat(question="Is this safe?", scan=SCAN)
        system = self.sent()["system"]
        self.assertIn("<message>\nYour parcel is held.", system)
        self.assertIn("<assessment>", system)
        self.assertIn("Risk level: high (score 85/100)", system)
        self.assertIn("Money request", system)
        self.assertIn("Do not click the link", system)
        self.assertIn("untrusted", system)

    def test_scan_is_optional(self):
        resp = self.chat(question="How do I spot a fake text?")
        self.assertEqual(resp["statusCode"], 200)
        self.assertNotIn("<message>\n", self.sent()["system"])

    def test_invalid_scan_is_rejected(self):
        resp = self.chat(question="hi", scan="not an object")
        self.assertEqual(resp["statusCode"], 400)
        self.assertEqual(json.loads(resp["body"]), {"error": "invalid_scan"})

    def test_history_is_included_in_order_with_question_last(self):
        history = [
            {"role": "user", "content": "Is this safe?"},
            {"role": "assistant", "content": "It looks risky."},
        ]
        self.chat(question="What should I do?", scan=SCAN, history=history)
        messages = self.sent()["messages"]
        self.assertEqual([m["role"] for m in messages], ["user", "assistant", "user"])
        self.assertEqual(messages[-1]["content"], "What should I do?")

    def test_history_is_capped_to_recent_turns(self):
        history = []
        for i in range(30):
            history.append({"role": "user", "content": f"q{i}"})
            history.append({"role": "assistant", "content": f"a{i}"})
        self.chat(question="latest", history=history)
        messages = self.sent()["messages"]
        self.assertLessEqual(len(messages), handler.CHAT_MAX_HISTORY + 1)
        self.assertEqual(messages[0]["role"], "user")
        self.assertEqual(messages[-1]["content"], "latest")

    def test_history_always_starts_with_user_and_alternates(self):
        history = [
            {"role": "assistant", "content": "stray"},
            {"role": "user", "content": "one"},
            {"role": "user", "content": "two"},
            {"role": "assistant", "content": "reply"},
        ]
        self.chat(question="three", history=history)
        roles = [m["role"] for m in self.sent()["messages"]]
        self.assertEqual(roles[0], "user")
        for a, b in zip(roles, roles[1:]):
            self.assertNotEqual(a, b)

    def test_history_ending_in_user_turn_is_merged_with_question(self):
        self.chat(question="again", history=[{"role": "user", "content": "first"}])
        messages = self.sent()["messages"]
        self.assertEqual(len(messages), 1)
        self.assertIn("first", messages[0]["content"])
        self.assertIn("again", messages[0]["content"])

    def test_bad_history_is_rejected(self):
        for history in ("text", [{"role": "system", "content": "x"}], [{"role": "user"}], ["x"]):
            resp = self.chat(question="hi", history=history)
            self.assertEqual(resp["statusCode"], 400)
            self.assertEqual(json.loads(resp["body"]), {"error": "invalid_history"})

    def test_uses_chat_model_and_plain_text_not_a_tool(self):
        self.chat(question="hi")
        kwargs = self.sent()
        self.assertEqual(kwargs["model"], handler.CHAT_MODEL)
        self.assertNotIn("tools", kwargs)
        self.assertNotIn("tool_choice", kwargs)

    def test_system_prompt_sets_safety_rules(self):
        text = handler.CHAT_SYSTEM.lower()
        self.assertIn("never promise", text)
        self.assertIn("plain", text)
        self.assertIn("untrusted", text)

    def test_claude_error_returns_retryable_502_without_raw_error(self):
        self.client.messages.create.side_effect = handler.anthropic.APIError("boom secret", request=None, body=None)
        resp = self.chat(question="hi")
        self.assertEqual(resp["statusCode"], 502)
        body = json.loads(resp["body"])
        self.assertEqual(body["error"], "chat_unavailable")
        self.assertTrue(body["retryable"])
        self.assertNotIn("boom", resp["body"])

    def test_empty_answer_returns_retryable_502(self):
        self.client.messages.create.return_value = _chat_response("   ")
        resp = self.chat(question="hi")
        self.assertEqual(resp["statusCode"], 502)
        self.assertTrue(json.loads(resp["body"])["retryable"])

    def test_malformed_response_returns_502(self):
        self.client.messages.create.return_value = SimpleNamespace(content=None)
        resp = self.chat(question="hi")
        self.assertEqual(resp["statusCode"], 502)

    def test_long_answer_is_trimmed(self):
        self.client.messages.create.return_value = _chat_response("a" * 5000)
        resp = self.chat(question="hi")
        self.assertEqual(len(json.loads(resp["body"])["answer"]), handler.CHAT_MAX_ANSWER)

    def test_mock_mode_skips_claude(self):
        with mock.patch.object(handler, "MOCK", True):
            resp = self.chat(question="hi", scan=SCAN)
        self.assertEqual(resp["statusCode"], 200)
        self.assertEqual(json.loads(resp["body"]), {"answer": handler.CHAT_MOCK_ANSWER})
        self.client.messages.create.assert_not_called()

    def test_question_and_answer_are_not_logged(self):
        self.client.messages.create.return_value = _chat_response("secret answer 98765")
        buf = io.StringIO()
        with redirect_stdout(buf):
            self.chat(question="private question 12345", scan=SCAN)
        self.assertEqual(buf.getvalue(), "")

    def test_question_is_not_logged_on_failure(self):
        self.client.messages.create.side_effect = handler.anthropic.APIError("x", request=None, body=None)
        buf = io.StringIO()
        with redirect_stdout(buf):
            self.chat(question="private question 12345", scan=SCAN)
        self.assertNotIn("private question", buf.getvalue())
        self.assertNotIn("12345", buf.getvalue())

    def test_scan_requests_still_work_after_adding_chat(self):
        self.client.messages.create.return_value = _tool_response(dict(VALID))
        resp = self.call(text="hello")
        self.assertEqual(resp["statusCode"], 200)
        self.assertEqual(self.sent()["model"], handler.MODEL)


if __name__ == "__main__":
    unittest.main()
