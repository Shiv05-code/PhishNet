
const test = require("node:test");
const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");
const { initializeTestFirestore } = require("./emulator_setup");
const {
  saveVerifiedSubscription,
} = require("../src/subscription_store");
const db = initializeTestFirestore();
const { beginReconciliation } = require("../src/reconciliation");
function makeTransactionId() {
    return String(
      BigInt("100000000000") +
      BigInt(Math.floor(Math.random() * 100000000000))
    );
  }
function makeSubscription(uid, accountToken, originalId, environment = "Sandbox", revision) {
  return {
    uid,
    accountToken,
    revision,
    verifiedTransaction: {
      originalTransactionId: originalId,
      transactionId: originalId,
      environment,
      appAccountToken: accountToken,
    },
    entitlement: {
      hasPlusAccess: true,
      plan: "plus",
      status: "active",
      productId: "com.phishnet.plus.monthly",
      expiresAt: new Date(Date.now() + 86400000),
      appleStatus: 1,
    },
    db,
  };
}

test("First purchase creates ownership and subscription", async () => {
  const uid = `test-${randomUUID()}`;
  const token = randomUUID();
  const originalId = makeTransactionId();

  await db.collection("users").doc(uid).set({
    appAccountToken: token,
  });

  const revision = await beginReconciliation({
    environment: "Sandbox",
    originalTransactionId: originalId,
    db,
  });

  const result = await saveVerifiedSubscription(
    makeSubscription(uid, token, originalId, "Sandbox", revision)
  );

  assert.equal(result.success, true);

  const ownership = await db
    .collection("appleSubscriptionOwnership")
    .doc(`Sandbox_${originalId}`)
    .get();

  assert.equal(ownership.get("uid"), uid);

  const subscription = await db
    .collection("users")
    .doc(uid)
    .collection("subscriptions")
    .doc("sandbox")
    .get();

  assert.equal(subscription.get("plan"), "plus");
  assert.equal(subscription.get("environment"), "sandbox");
});

test("Different Firebase account cannot claim the same purchase", async () => {
  const uidA = `test-${randomUUID()}`;
  const uidB = `test-${randomUUID()}`;
  const tokenA = randomUUID();
  const tokenB = randomUUID();
  const originalId = makeTransactionId();

  await db.collection("users").doc(uidA).set({
    appAccountToken: tokenA,
  });

  await db.collection("users").doc(uidB).set({
    appAccountToken: tokenB,
  });

  const revision = await beginReconciliation({
    environment: "Sandbox",
    originalTransactionId: originalId,
    db,
  });

  await saveVerifiedSubscription(
    makeSubscription(uidA, tokenA, originalId, "Sandbox", revision)
  );

  await assert.rejects(
    saveVerifiedSubscription(
      makeSubscription(uidB, tokenB, originalId, "Sandbox", revision)
    ),
    /belongs to another account/
  );
})

test("Sandbox purchase does not create production entitlement", async () => {
  const uid = `test-${randomUUID()}`;
  const token = randomUUID();
  const originalId = makeTransactionId();

  await db.collection("users").doc(uid).set({
    appAccountToken: token,
  });

  const revision = await beginReconciliation({
    environment: "Sandbox",
    originalTransactionId: originalId,
    db,
  });

  await saveVerifiedSubscription(
    makeSubscription(uid, token, originalId, "Sandbox", revision)
  );

  const productionSubscription = await db
    .collection("users")
    .doc(uid)
    .collection("subscriptions")
    .doc("current")
    .get();

  assert.equal(productionSubscription.exists, false);
});

test("Concurrent claims cannot assign one purchase to two users", async () => {
    const uidA = `test-${randomUUID()}`;
    const uidB = `test-${randomUUID()}`;
    const tokenA = randomUUID();
    const tokenB = randomUUID();
    const originalId = makeTransactionId();

    await Promise.all([
      db.collection("users").doc(uidA).set({
        appAccountToken: tokenA,
      }),
      db.collection("users").doc(uidB).set({
        appAccountToken: tokenB,
      }),
    ]);
    const revision = await beginReconciliation({
      environment: "Sandbox",
      originalTransactionId: originalId,
      db,
    });

const results = await Promise.allSettled([
  saveVerifiedSubscription(
    makeSubscription(uidA, tokenA, originalId, "Sandbox", revision)
  ),
  saveVerifiedSubscription(
    makeSubscription(uidB, tokenB, originalId, "Sandbox", revision)
  ),
]);


    const successful = results.filter(
      (result) => result.status === "fulfilled"
    );

    const rejected = results.filter(
      (result) => result.status === "rejected"
    );

    assert.equal(successful.length, 1);
    assert.equal(rejected.length, 1);

    const ownership = await db
      .collection("appleSubscriptionOwnership")
      .doc(`Sandbox_${originalId}`)
      .get();

    const ownerUid = ownership.get("uid");

    assert.ok(ownerUid === uidA || ownerUid === uidB);

    const loserUid = ownerUid === uidA ? uidB : uidA;

    const loserSubscription = await db
      .collection("users")
      .doc(loserUid)
      .collection("subscriptions")
      .doc("sandbox")
      .get();

    assert.equal(loserSubscription.exists, false);
  });

test("Older active result must not restore a revoked subscription", async () => {
    const uid = `test-${randomUUID()}`;
    const token = randomUUID();
    const originalId = makeTransactionId();

    await db.collection("users").doc(uid).set({
      appAccountToken: token,
    });

    const active = makeSubscription(uid, token, originalId);

    const revoked = makeSubscription(uid, token, originalId);

    revoked.entitlement = {
      ...revoked.entitlement,
      hasPlusAccess: false,
      plan: "free",
      status: "revoked",
      appleStatus: 5,
    };


    // First, an active subscription is recorded.
    const activeRevision = await beginReconciliation({
      environment: "Sandbox",
      originalTransactionId: originalId,
      db,
    });

    active.revision = activeRevision;
    await saveVerifiedSubscription(active);

    // Apple subsequently reports the subscription as revoked.
    const revokedRevision = await beginReconciliation({
      environment: "Sandbox",
      originalTransactionId: originalId,
      db,
    });

    revoked.revision = revokedRevision;
    await saveVerifiedSubscription(revoked);

    // An older active verification arrives after revocation.
    await assert.rejects(
      saveVerifiedSubscription(active),
      /Stale reconciliation revision/
    );


    const snapshot = await db
      .collection("users")
      .doc(uid)
      .collection("subscriptions")
      .doc("sandbox")
      .get();

    assert.equal(snapshot.get("plan"), "free");
    assert.equal(snapshot.get("status"), "revoked");
  });

test("Older active result must not restore an expired subscription", async () => {
    const uid = `test-${randomUUID()}`;
    const token = randomUUID();
    const originalId = makeTransactionId();

    await db.collection("users").doc(uid).set({
      appAccountToken: token,
    });

    const active = makeSubscription(uid, token, originalId);

    const expired = makeSubscription(uid, token, originalId);

    expired.entitlement = {
      ...expired.entitlement,
      hasPlusAccess: false,
      plan: "free",
      status: "expired",
      appleStatus: 2,
      expiresAt: new Date(Date.now() - 86400000),
    };


    // First, an active subscription is recorded.
    const activeRevision = await beginReconciliation({
      environment: "Sandbox",
      originalTransactionId: originalId,
      db,
    });

    active.revision = activeRevision;
    await saveVerifiedSubscription(active);

    // Apple subsequently reports the subscription as expired.
    const expiredRevision = await beginReconciliation({
      environment: "Sandbox",
      originalTransactionId: originalId,
      db,
    });

    expired.revision = expiredRevision;
    await saveVerifiedSubscription(expired);

    // An older active verification must not restore Plus.
    await assert.rejects(
      saveVerifiedSubscription(active),
      /Stale reconciliation revision/
    );

    const snapshot = await db
      .collection("users")
      .doc(uid)
      .collection("subscriptions")
      .doc("sandbox")
      .get();

    assert.equal(snapshot.get("plan"), "free");
    assert.equal(snapshot.get("status"), "expired");
  });
