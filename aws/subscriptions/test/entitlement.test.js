
const test = require("node:test");
const assert = require("node:assert/strict");

const { Status } = require("@apple/app-store-server-library");
const { evaluateEntitlement } = require("../src/entitlement");

function makeTransaction(overrides = {}) {
  return {
    productId: "com.phishnet.plus.monthly",
    expiresAt: new Date(Date.now() + 86400000),
    revocationDate: null,
    ...overrides,
  };
}

test("Active subscription grants Plus", () => {
  const result = evaluateEntitlement(
    Status.ACTIVE,
    makeTransaction()
  );

  assert.equal(result.hasPlusAccess, true);
  assert.equal(result.plan, "plus");
  assert.equal(result.status, "active");
});

test("Expired status denies Plus", () => {
  const result = evaluateEntitlement(
    Status.EXPIRED,
    makeTransaction()
  );

  assert.equal(result.hasPlusAccess, false);
  assert.equal(result.plan, "free");
  assert.equal(result.status, "expired");
});

test("Billing retry denies Plus", () => {
  const result = evaluateEntitlement(
    Status.BILLING_RETRY,
    makeTransaction()
  );

  assert.equal(result.hasPlusAccess, false);
  assert.equal(result.status, "billing_retry");
});

test("Revoked status denies Plus", () => {
  const result = evaluateEntitlement(
    Status.REVOKED,
    makeTransaction()
  );

  assert.equal(result.hasPlusAccess, false);
  assert.equal(result.status, "revoked");
});

test("Revocation date denies Plus", () => {
  const result = evaluateEntitlement(
    Status.ACTIVE,
    makeTransaction({
      revocationDate: Date.now(),
    })
  );

  assert.equal(result.hasPlusAccess, false);
});

test("Expired transaction denies Plus even with ACTIVE status", () => {
  const result = evaluateEntitlement(
    Status.ACTIVE,
    makeTransaction({
      expiresAt: new Date(Date.now() - 86400000),
    })
  );

  assert.equal(result.hasPlusAccess, false);
});

test("Valid billing grace period grants temporary Plus", () => {
  const gracePeriodExpiresDate = Date.now() + 3600000;

  const result = evaluateEntitlement(
    Status.BILLING_GRACE_PERIOD,
    makeTransaction({
      expiresAt: new Date(Date.now() - 1000),
    }),
    { gracePeriodExpiresDate }
  );

  assert.equal(result.hasPlusAccess, true);
  assert.equal(result.plan, "plus");
});

test("Expired billing grace period denies Plus", () => {
  const result = evaluateEntitlement(
    Status.BILLING_GRACE_PERIOD,
    makeTransaction({
      expiresAt: new Date(Date.now() - 86400000),
    }),
    {
      gracePeriodExpiresDate: Date.now() - 3600000,
    }
  );

  assert.equal(result.hasPlusAccess, false);
});

test("Invalid expiration date is rejected", () => {
  assert.throws(
    () =>
      evaluateEntitlement(
        Status.ACTIVE,
        makeTransaction({
          expiresAt: new Date("invalid"),
        })
      ),
    /Invalid subscription expiration date/
  );
});
