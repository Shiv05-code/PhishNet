# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

from firebase_functions import https_fn
from firebase_functions.options import set_global_options
from firebase_admin import auth, firestore, initialize_app

set_global_options(max_instances=10)
initialize_app()


def _anonymize_user_scans(uid: str) -> None:
    db = firestore.client()

    user_ref = db.collection("users").document(uid)
    scans_ref = user_ref.collection("scans")
    anonymous_ref = db.collection("anonymized_training_scans")

    batch = db.batch()
    operations = 0

    for scan in scans_ref.stream():
        data = scan.to_dict() or {}

        anonymous_scan = {
            "risk_level": data.get("risk_level"),
            "summary": data.get("summary"),
            "red_flags": data.get("red_flags", []),
            "next_steps": data.get("next_steps", []),
        }

        batch.set(anonymous_ref.document(), anonymous_scan)
        batch.delete(scan.reference)
        operations += 2

        if operations >= 250:
            batch.commit()
            batch = db.batch()
            operations = 0

    if operations:
        batch.commit()

    user_ref.delete()


@https_fn.on_call()
def delete_account(req: https_fn.CallableRequest):
    if req.auth is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="You must be signed in to delete your account.",
        )

    uid = req.auth.uid

    try:
        _anonymize_user_scans(uid)
        auth.delete_user(uid)
        return {"deleted": True}

    except Exception as error:
        print(f"Account deletion failed: {type(error).__name__}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="The account could not be deleted.",
        )