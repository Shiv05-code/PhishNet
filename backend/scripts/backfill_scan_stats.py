"""One-time backfill: build daily scan counters for scans saved before
the stats fields existed. Safe to re-run: it overwrites counters with the
totals computed from each user's current scans.

Usage (with Firebase Admin credentials available):
  python backfill_scan_stats.py
"""

from collections import defaultdict

import firebase_admin
from firebase_admin import credentials, firestore

RISK_KEYS = ("high", "medium", "low")


def _day_key(moment):
    return moment.strftime("%Y-%m-%d")


def backfill_user(db, user_ref):
    days = defaultdict(lambda: {"total": 0, "high": 0, "medium": 0, "low": 0})
    latest = None

    for scan in user_ref.collection("scans").stream():
        data = scan.to_dict() or {}
        created = data.get("createdAt")
        if created is None:
            continue
        day = days[_day_key(created)]
        day["total"] += 1
        risk = data.get("risk_level")
        if risk in RISK_KEYS:
            day[risk] += 1
        if latest is None or created > latest:
            latest = created

    if not days:
        return 0

    batch = db.batch()
    for key, counts in days.items():
        batch.set(user_ref.collection("stats").document(key), counts)
    if latest is not None:
        batch.set(user_ref, {"last_checked_at": latest}, merge=True)
    batch.commit()
    return len(days)


def main():
    firebase_admin.initialize_app(credentials.ApplicationDefault())
    db = firestore.client()
    users = 0
    for user_ref in db.collection("users").stream():
        backfill_user(db, user_ref.reference)
        users += 1
    print(f"Processed {users} users.")


if __name__ == "__main__":
    main()
