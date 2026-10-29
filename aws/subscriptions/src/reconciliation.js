
const { getFirestore } = require("./firebase");
const { FieldValue } = require("firebase-admin/firestore");

function getReconciliationRef(db, environment, originalTransactionId) {
  if (!["Production", "Sandbox"].includes(environment)) {
    throw new Error("Invalid Apple environment");
  }

  if (
    typeof originalTransactionId !== "string" ||
    !/^[0-9]+$/.test(originalTransactionId)
  ) {
    throw new Error("Invalid original transaction ID");
  }

  return db
    .collection("appleSubscriptionReconciliations")
    .doc(`${environment}_${originalTransactionId}`);
}

async function beginReconciliation({
  environment,
  originalTransactionId,
  db: providedDb = null,
}) {
  const db = providedDb ?? await getFirestore();

  const ref = getReconciliationRef(
    db,
    environment,
    originalTransactionId
  );

  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const revision = (snapshot.get("revision") ?? 0) + 1;

    tx.set(
      ref,
      {
        revision,
        startedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return revision;
  });
}

module.exports = {
  beginReconciliation,
  getReconciliationRef,
};
