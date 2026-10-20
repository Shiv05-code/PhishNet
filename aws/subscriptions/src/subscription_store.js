
const { getFirestore } = require("./firebase");

async function saveVerifiedSubscription({
  uid,
  accountToken,
  verifiedTransaction,
  entitlement,
}) {
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
    !["free", "plus"].includes(entitlement.plan)
  ) {
    throw new Error("Invalid verified entitlement");
  }

  const db = await getFirestore();

  const ownershipRef = db
    .collection("appleSubscriptionOwnership")
    .doc(`${environment}_${originalTransactionId}`);

  const userRef = db.collection("users").doc(uid);

  const subscriptionRef = userRef
    .collection("subscriptions")
    .doc("current");

  return db.runTransaction(async (tx) => {
    const [ownershipSnapshot, userSnapshot] =
      await Promise.all([
        tx.get(ownershipRef),
        tx.get(userRef),
      ]);

    const existingOwner = ownershipSnapshot.get("uid");

    if (existingOwner && existingOwner !== uid) {
      throw new Error(
        "Apple subscription belongs to another account"
      );
    }

    if (userSnapshot.get("appAccountToken") !== accountToken) {
      throw new Error("Firebase account token mismatch");
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
