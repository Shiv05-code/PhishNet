
const test = require("node:test");
const assert = require("node:assert/strict");

const {
  selectCurrentEntitlement,
} = require("../src/select_entitlement");

function makeStatus(hasPlusAccess) {
  return {
    originalTransactionId: "1234567890",
    verifiedTransaction: {
      transactionId: "1234567890",
      originalTransactionId: "1234567890",
      environment: "Sandbox",
    },
    entitlement: {
      hasPlusAccess,
      plan: hasPlusAccess ? "plus" : "free",
    },
  };
}

test("Accepts a single active Plus subscription", () => {
  const selected = selectCurrentEntitlement([
    makeStatus(true),
  ]);

  assert.equal(selected.entitlement.plan, "plus");
});

test("Accepts a single inactive subscription", () => {
  const selected = selectCurrentEntitlement([
    makeStatus(false),
  ]);

  assert.equal(selected.entitlement.plan, "free");
});

test("Rejects empty subscription statuses", () => {
  assert.throws(
    () => selectCurrentEntitlement([]),
    /No subscription statuses available/
  );
});

test("Rejects multiple subscription statuses", () => {
  assert.throws(
    () => selectCurrentEntitlement([
      makeStatus(true),
      makeStatus(false),
    ]),
    /Multiple subscription statuses require reconciliation/
  );
});

test("Rejects missing verified transaction", () => {
  const invalid = makeStatus(true);
  delete invalid.verifiedTransaction;

  assert.throws(
    () => selectCurrentEntitlement([invalid]),
    /Invalid subscription status/
  );
});

test("Rejects missing entitlement", () => {
  const invalid = makeStatus(true);
  delete invalid.entitlement;

  assert.throws(
    () => selectCurrentEntitlement([invalid]),
    /Invalid subscription status/
  );
});
