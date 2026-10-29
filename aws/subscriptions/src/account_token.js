
const { randomUUID } = require("node:crypto");
const { getFirestore } = require("./firebase");

async function getOrCreateAccountToken(uid) {
  if (typeof uid !== "string" || !uid) {
    throw new Error("Invalid Firebase UID");
  }

  const db = await getFirestore();
  const userRef = db.collection("users").doc(uid);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(userRef);
    const existingToken = snapshot.get("appAccountToken");

    if (existingToken) {
      if (
        typeof existingToken !== "string" ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(existingToken)
      ) {
        throw new Error("Invalid stored account token");
      }

      return existingToken;
    }

    const accountToken = randomUUID();

    transaction.set(
      userRef,
      {
        appAccountToken: accountToken,
      },
      { merge: true }
    );

    return accountToken;
  });
}

module.exports = { getOrCreateAccountToken };
