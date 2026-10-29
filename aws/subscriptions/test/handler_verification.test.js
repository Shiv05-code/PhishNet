
const test = require("node:test");
const assert = require("node:assert/strict");
const Module = require("node:module");

const handlerPath = require.resolve("../src/index");

function loadHandlerWithMocks(overrides = {}) {
  const originalLoad = Module._load;
  const calls = {
    firestoreWrites: 0,
    reconciliations: 0,
    savedSubscription: null,
  };

  const transaction = {
    transactionId: "1234567890",
    originalTransactionId: "1234567890",
    productId: "com.phishnet.plus.monthly",
    environment: "Sandbox",
    appAccountToken: "test-account-token",
    signedDate: Date.now(),
    expiresAt: new Date(Date.now() + 86400000),
    revocationDate: null,
  };

  const mocks = {
    "./firebase": {
      verifyFirebaseUser: async () => "test-user",
    },
    "./account_token": {
      getOrCreateAccountToken: async () => "test-account-token",
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
        productId: "com.phishnet.plus.monthly",
        expiresAt: transaction.expiresAt,
        appleStatus: 1,
      }),
    },

"./reconciliation": {
    beginReconciliation: async () => {
      calls.reconciliations++;
      return 1;
    },
  },
  "./subscription_store": {
    saveVerifiedSubscription: async (subscription) => {
      calls.firestoreWrites++;
      calls.savedSubscription = subscription;

      return {
        success: true,
        plan: subscription.entitlement.plan,
        status: subscription.entitlement.status,
      };
    },
  },

  };

  Object.assign(mocks, overrides);

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
    const loaded = require(handlerPath);

    return { handler: loaded.handler, calls };
  } finally {
    Module._load = originalLoad;
    delete require.cache[handlerPath];
  }
}

function makeEvent(transactionId = "1234567890") {
  return {
    requestContext: { http: { method: "POST" } },
    rawPath: "/subscriptions/verify",
    headers: { authorization: "Bearer mock-token" },
    body: JSON.stringify({ transactionId }),
    isBase64Encoded: false,
  };
}


test("Firestore failure does not grant Plus", async () => {
    const { handler, calls } = loadHandlerWithMocks({
      "./subscription_store": {
        saveVerifiedSubscription: async () => {
          throw new Error("Simulated Firestore failure");
        },
      },
    });

    const response = await handler(makeEvent());
    const body = JSON.parse(response.body);

    assert.equal(response.statusCode, 500);
    assert.notEqual(body.entitlementGranted, true);
    assert.equal(calls.reconciliations, 1);
  });


test("Rejects an Apple transaction ID mismatch", async () => {
  const { handler, calls } = loadHandlerWithMocks({
    "./apple": {
      fetchAppleTransactionAutomatically: async () => ({
        signedTransactionInfo: "mock",
        environment: "Sandbox",
      }),
      verifyAppleTransaction: async () => ({
        transactionId: "9999999999",
        originalTransactionId: "1234567890",
        appAccountToken: "test-account-token",
      }),
    },
  });

  const response = await handler(makeEvent());

  assert.equal(response.statusCode, 400);
  assert.equal(calls.firestoreWrites, 0);
});

test("Verified active purchase saves Plus entitlement", async () => {
    const { handler, calls } = loadHandlerWithMocks();

    const response = await handler(makeEvent());
    const body = JSON.parse(response.body);

    assert.equal(response.statusCode, 200);
    assert.equal(body.verified, true);
    assert.equal(body.entitlementGranted, true);

    assert.equal(calls.reconciliations, 1);
    assert.equal(calls.firestoreWrites, 1);

    assert.equal(calls.savedSubscription.uid, "test-user");
    assert.equal(
      calls.savedSubscription.accountToken,
      "test-account-token"
    );
    assert.equal(calls.savedSubscription.revision, 1);
    assert.equal(
      calls.savedSubscription.entitlement.plan,
      "plus"
    );
    assert.equal(
      calls.savedSubscription.entitlement.status,
      "active"
    );
  });
