
const { getFirestore } = require("./firebase");
const {
  validatePurchaseOwnership,
} = require("./ownership");
const { getReconciliationRef } = require("./reconciliation");
async function saveVerifiedSubscription({
  uid,
  accountToken,
  verifiedTransaction,
  entitlement,
  revision,
  db: providedDb = null,
}) {
  const db = providedDb ?? await getFirestore();
  // Validate the reconciliation revision.
  if (!Number.isSafeInteger(revision) || revision < 1) {
    throw new Error("Invalid reconciliation revision");
  }

  // Validate subscription ownership information.
  if (!uid || !accountToken || !verifiedTransaction) {
    throw new Error("Missing subscription ownership information");
  }

  const { originalTransactionId, environment } =
    verifiedTransaction;

  if (
    !/^[0-9]+$/.test(originalTransactionId ?? "") ||
    !["Production", "Sandbox"].includes(environment)
  ) {
    throw new Error("Invalid verified transaction");
  }

  if (verifiedTransaction.appAccountToken !== accountToken) {
    throw new Error("Apple account token mismatch");
  }

  if (
    typeof entitlement?.hasPlusAccess !== "boolean" ||
    !["free", "plus"].includes(entitlement.plan) ||
    !["active", "expired", "revoked", "billing_retry", "inactive"]
      .includes(entitlement.status) ||
    !(entitlement.expiresAt instanceof Date) ||
    !Number.isFinite(entitlement.expiresAt.getTime()) ||
    entitlement.plan !==
      (entitlement.hasPlusAccess ? "plus" : "free") ||
    (entitlement.hasPlusAccess && entitlement.status !== "active")
  ) {
    throw new Error("Invalid verified entitlement");
  }

  const reconciliationRef = getReconciliationRef(
    db,
    environment,
    originalTransactionId
  );

  const ownershipRef = db
    .collection("appleSubscriptionOwnership")
    .doc(`${environment}_${originalTransactionId}`);

  const userRef = db.collection("users").doc(uid);

  const subscriptionDocumentId =
  environment === "Production" ? "current" : "sandbox";

const subscriptionRef = userRef
  .collection("subscriptions")
  .doc(subscriptionDocumentId);

  return db.runTransaction(async (tx) => {
    const [
      ownershipSnapshot,
      userSnapshot,
      subscriptionSnapshot,
      reconciliationSnapshot,
    ] = await Promise.all([
      tx.get(ownershipRef),
      tx.get(userRef),
      tx.get(subscriptionRef),
      tx.get(reconciliationRef),
    ]);
    const currentRevision = reconciliationSnapshot.get("revision");

if (currentRevision !== revision) {
  throw new Error("Stale reconciliation revision");
}

  const existingOwner = ownershipSnapshot.get("uid");

  validatePurchaseOwnership({
    existingOwner,
    uid,
    storedAccountToken: userSnapshot.get("appAccountToken"),
    verifiedAccountToken: verifiedTransaction.appAccountToken,
  });
    const existingEnvironment =
  subscriptionSnapshot.get("environment");

if (
  subscriptionSnapshot.exists &&
  existingEnvironment &&
  existingEnvironment !== environment.toLowerCase()
) {
  throw new Error("Subscription environment mismatch");
}
const existingOriginalTransactionId =
  subscriptionSnapshot.get("originalTransactionId");

if (
  subscriptionSnapshot.exists &&
  existingOriginalTransactionId &&
  existingOriginalTransactionId !== originalTransactionId
) {
  throw new Error(
    "Existing subscription requires reconciliation"
  );
}
const existingStatus = subscriptionSnapshot.get("status");

if (
  subscriptionSnapshot.exists &&
  existingStatus === "revoked" &&
  entitlement.hasPlusAccess
) {
  throw new Error(
    "Revoked subscription requires authoritative reconciliation"
  );
}
    tx.set(
      ownershipRef,
      {
        uid,
        appAccountToken: accountToken,
        environment,
        originalTransactionId,
      },
      { merge: true }
    );

    tx.set(
      subscriptionRef,
      {
        plan: entitlement.plan,
        status: entitlement.status,
        productId: entitlement.productId,
        environment: environment.toLowerCase(),
        expiresAt: entitlement.expiresAt,
        appleStatus: entitlement.appleStatus,
        originalTransactionId,
        updatedAt:
          require("firebase-admin/firestore").FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      plan: entitlement.plan,
      status: entitlement.status,
    };
  });
}

module.exports = { saveVerifiedSubscription };
