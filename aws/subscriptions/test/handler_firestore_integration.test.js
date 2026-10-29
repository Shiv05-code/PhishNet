
const test = require("node:test");
const assert = require("node:assert/strict");
const Module = require("node:module");
const { randomUUID } = require("node:crypto");

const { initializeTestFirestore } = require("./emulator_setup");
const { beginReconciliation } = require("../src/reconciliation");
const {
  saveVerifiedSubscription,
} = require("../src/subscription_store");

const db = initializeTestFirestore();
const handlerPath = require.resolve("../src/index");

test("Verified Apple purchase saves Plus to Firestore", async () => {
  const uid = `integration-${randomUUID()}`;
  const accountToken = randomUUID();
  const transactionId = "12345678901234567890";
  const originalTransactionId = transactionId;

  const transaction = {
    transactionId,
    originalTransactionId,
    productId: "com.phishnet.plus.monthly",
    environment: "Sandbox",
    appAccountToken: accountToken,
    signedDate: Date.now(),
    expiresAt: new Date(Date.now() + 86400000),
    revocationDate: null,
  };

  const userRef = db.collection("users").doc(uid);
  const subscriptionRef = userRef
    .collection("subscriptions")
    .doc("sandbox");

  const ownershipRef = db
    .collection("appleSubscriptionOwnership")
    .doc(`Sandbox_${originalTransactionId}`);

  const reconciliationRef = db
    .collection("appleSubscriptionReconciliations")
    .doc(`Sandbox_${originalTransactionId}`);

  await userRef.set({ appAccountToken: accountToken });

  const originalLoad = Module._load;

  const mocks = {
    "./firebase": {
      verifyFirebaseUser: async () => uid,
    },
    "./account_token": {
      getOrCreateAccountToken: async () => accountToken,
    },
    "./apple": {
      fetchAppleTransactionAutomatically: async () => ({
        signedTransactionInfo: "mock-signed-transaction",
        environment: "Sandbox",
      }),
      verifyAppleTransaction: async () => transaction,
      getVerifiedSubscriptionStatus: async () => [
        {
          status: 1,
          transaction,
          renewalInfo: null,
        },
      ],
    },
    "./entitlement": {
      evaluateEntitlement: () => ({
        hasPlusAccess: true,
        plan: "plus",
        status: "active",
        productId: transaction.productId,
        expiresAt: transaction.expiresAt,
        appleStatus: 1,
      }),
    },
    "./reconciliation": {
      beginReconciliation: (args) =>
        beginReconciliation({ ...args, db }),
    },
    "./subscription_store": {
      saveVerifiedSubscription: (args) =>
        saveVerifiedSubscription({ ...args, db }),
    },
  };

  let handler;

  try {
    Module._load = function(request, parent, isMain) {
      if (
        parent?.filename === handlerPath &&
        Object.hasOwn(mocks, request)
      ) {
        return mocks[request];
      }
      return originalLoad.apply(this, arguments);
    };

    delete require.cache[handlerPath];
    handler = require(handlerPath).handler;
  } finally {
    Module._load = originalLoad;
    delete require.cache[handlerPath];
  }

  try {
    const response = await handler({
      requestContext: { http: { method: "POST" } },
      rawPath: "/subscriptions/verify",
      headers: { authorization: "Bearer test-token" },
      body: JSON.stringify({ transactionId }),
      isBase64Encoded: false,
    });

    assert.equal(response.statusCode, 200);

    const body = JSON.parse(response.body);
    assert.equal(body.verified, true);
    assert.equal(body.entitlementGranted, true);

    const subscription = await subscriptionRef.get();

    assert.equal(subscription.exists, true);
    assert.equal(subscription.get("plan"), "plus");
    assert.equal(subscription.get("status"), "active");
    assert.equal(subscription.get("environment"), "sandbox");

    const production = await userRef
      .collection("subscriptions")
      .doc("current")
      .get();

    assert.equal(production.exists, false);
  } finally {
    await Promise.all([
      subscriptionRef.delete(),
      ownershipRef.delete(),
      reconciliationRef.delete(),
      userRef.delete(),
    ]);
  }
});
