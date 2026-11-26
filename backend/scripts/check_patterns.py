"""Check the scam-pattern library. Run: python backend/scripts/check_patterns.py"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lambda"))

import pattern_insights as pi  # noqa: E402

CATEGORIES = (
    "money_request credential_request personal_information_request "
    "urgency_or_pressure suspicious_link_or_contact impersonation "
    "unusual_payment_method unexpected_attachment mismatched_context other"
).split()


def main():
    problems = pi.validate_patterns(pi.PATTERNS, CATEGORIES)
    for problem in problems:
        print("PROBLEM:", problem)
    approved = pi.active_ids(pi.PATTERNS, CATEGORIES)
    print(f"{len(pi.PATTERNS)} patterns, {len(approved)} approved: {approved}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
