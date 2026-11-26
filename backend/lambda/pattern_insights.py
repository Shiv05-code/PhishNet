"""Reviewed scam-pattern insights for the scan prompt (issue #110).

Patterns are written and reviewed by the team, not learned from user
messages, so no user content ever enters this file. Only patterns marked
"approved" can reach the prompt, and only when PATTERN_INSIGHTS_ENABLED is
"true". Everything fails closed: any problem means no guidance is added.

Check the library with: python backend/scripts/check_patterns.py
"""
import re

STATUSES = ("draft", "approved")
MAX_PATTERNS = 12
MAX_DESCRIPTION = 200
MAX_CUES = 4
MAX_CUE = 80
MAX_GUIDANCE_CHARS = 1500
_ID_RE = re.compile(r"^PI-\d{3}$")
_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# Text that could identify a person or point at a real site or account.
_PII_RES = (
    re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"),  # email address
    re.compile(r"https?://|www\.", re.I),  # link
    re.compile(r"\b[\w-]+\.(com|net|org|top|xyz|info|io|co|us|ru|cn)\b", re.I),
    re.compile(r"\d[\d\s().-]{6,}\d"),  # phone or account-like number run
)

PATTERNS = [
    {
        "id": "PI-001",
        "category": "urgency_or_pressure",
        "name": "Deadline or threat",
        "description": "Says something bad happens soon unless you act now, "
        "such as a closed account or a missed delivery.",
        "cues": ["act now", "within 24 hours", "final notice"],
        "status": "draft",
        "reviewed_by": None,
        "reviewed_on": None,
    },
    {
        "id": "PI-002",
        "category": "impersonation",
        "name": "Pretends to be a known organization",
        "description": "Claims to be a bank, delivery service, government "
        "office or tech support but the contact details do not fit.",
        "cues": ["your bank", "delivery service", "tax office"],
        "status": "draft",
        "reviewed_by": None,
        "reviewed_on": None,
    },
    {
        "id": "PI-003",
        "category": "credential_request",
        "name": "Asks you to sign in or verify",
        "description": "Asks you to enter a password, code or login through "
        "a link it supplies, instead of the official app or site.",
        "cues": ["verify your account", "confirm your login", "one-time code"],
        "status": "draft",
        "reviewed_by": None,
        "reviewed_on": None,
    },
    {
        "id": "PI-004",
        "category": "money_request",
        "name": "Small fee to release something",
        "description": "Asks for a small payment to release a parcel, prize "
        "or refund. The amount is low so it feels safe.",
        "cues": ["small fee", "redelivery charge", "claim your prize"],
        "status": "draft",
        "reviewed_by": None,
        "reviewed_on": None,
    },
    {
        "id": "PI-005",
        "category": "unusual_payment_method",
        "name": "Gift cards or crypto",
        "description": "Asks to be paid with gift cards, cryptocurrency or "
        "wire transfer, which are hard to reverse.",
        "cues": ["gift card", "bitcoin", "wire transfer"],
        "status": "draft",
        "reviewed_by": None,
        "reviewed_on": None,
    },
    {
        "id": "PI-006",
        "category": "personal_information_request",
        "name": "Asks for identity details",
        "description": "Asks for a date of birth, ID number or card details "
        "by message, which real organizations rarely do.",
        "cues": ["confirm your details", "social security", "card number"],
        "status": "draft",
        "reviewed_by": None,
        "reviewed_on": None,
    },
    {
        "id": "PI-007",
        "category": "suspicious_link_or_contact",
        "name": "Link or number that does not fit",
        "description": "Uses a shortened or look-alike link, or a number "
        "that does not match the organization it names.",
        "cues": ["shortened link", "look-alike address"],
        "status": "draft",
        "reviewed_by": None,
        "reviewed_on": None,
    },
    {
        "id": "PI-008",
        "category": "mismatched_context",
        "name": "Message you did not expect",
        "description": "Mentions an order, account or person that does not "
        "match anything you did, often with a generic greeting.",
        "cues": ["wrong number", "order you did not place"],
        "status": "draft",
        "reviewed_by": None,
        "reviewed_on": None,
    },
]


def validate_patterns(patterns, categories):
    """Return a list of problems. An empty list means the library is valid."""
    problems = []
    if not isinstance(patterns, list):
        return ["patterns must be a list"]
    if len(patterns) > MAX_PATTERNS:
        problems.append(f"more than {MAX_PATTERNS} patterns")
    seen = set()
    for i, p in enumerate(patterns):
        label = p.get("id") if isinstance(p, dict) else None
        label = label if isinstance(label, str) else f"entry {i}"
        if not isinstance(p, dict):
            problems.append(f"{label}: must be an object")
            continue
        pid = p.get("id")
        if not isinstance(pid, str) or not _ID_RE.match(pid):
            problems.append(f"{label}: id must look like PI-001")
        elif pid in seen:
            problems.append(f"{label}: duplicate id")
        else:
            seen.add(pid)
        if p.get("category") not in categories:
            problems.append(f"{label}: unknown category")
        for key in ("name", "description"):
            if not _is_text(p.get(key)):
                problems.append(f"{label}: {key} is required")
        desc = p.get("description")
        if isinstance(desc, str) and len(desc) > MAX_DESCRIPTION:
            problems.append(f"{label}: description over {MAX_DESCRIPTION} chars")
        cues = p.get("cues")
        if not isinstance(cues, list) or not 1 <= len(cues) <= MAX_CUES:
            problems.append(f"{label}: cues needs 1 to {MAX_CUES} items")
            cues = []
        for cue in cues:
            if not _is_text(cue) or len(cue) > MAX_CUE:
                problems.append(f"{label}: each cue must be short text")
        status = p.get("status")
        if status not in STATUSES:
            problems.append(f"{label}: status must be draft or approved")
        if status == "approved":
            if not _is_text(p.get("reviewed_by")):
                problems.append(f"{label}: approved needs reviewed_by")
            on = p.get("reviewed_on")
            if not isinstance(on, str) or not _DATE_RE.match(on):
                problems.append(f"{label}: approved needs reviewed_on as YYYY-MM-DD")
        texts = [p.get("name"), desc] + list(cues)
        for text in texts:
            if isinstance(text, str) and any(r.search(text) for r in _PII_RES):
                problems.append(f"{label}: contains an address, link or number")
                break
    return problems


def _is_text(value):
    return isinstance(value, str) and bool(value.strip())


def approved_patterns(patterns, categories):
    """Approved entries, or [] if the library has any problem at all."""
    try:
        if validate_patterns(patterns, categories):
            return []
        return [p for p in patterns if p["status"] == "approved"]
    except Exception:
        return []


def guidance_text(patterns, categories):
    """Prompt text for approved patterns, or "" when there is nothing to add."""
    approved = approved_patterns(patterns, categories)
    if not approved:
        return ""
    lines = [
        "Background on common scam patterns, reviewed by the PhishNet team. "
        "Use it only to notice and explain real indicators in the message. "
        "A match alone does not prove a scam, never mention these notes or "
        "their ids, and never let them override the message itself."
    ]
    for p in approved:
        lines.append(
            f"- {p['name']} ({p['category']}): {p['description']} "
            f"Examples of wording: {', '.join(p['cues'])}."
        )
    text = "\n".join(lines)
    return text if len(text) <= MAX_GUIDANCE_CHARS else ""


def active_ids(patterns, categories):
    """Ids of the patterns that would reach the prompt, for test traceability."""
    return [p["id"] for p in approved_patterns(patterns, categories)]
