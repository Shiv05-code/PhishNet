
const test = require("node:test");
const assert = require("node:assert/strict");

const {
  validatePurchaseOwnership,
} = require("../src/ownership");

const uid = "firebase-user-a";
const accountToken = "550e8400-e29b-41d4-a716-446655440000";

function check(overrides = {}) {
  return validatePurchaseOwnership({
    existingOwner: null,
    uid,
    storedAccountToken: accountToken,
    verifiedAccountToken: accountToken,
    ...overrides,
  });
}

test("First subscription claim is accepted", () => {
  assert.equal(check(), true);
});

test("Existing owner can verify again", () => {
  assert.equal(check({ existingOwner: uid }), true);
});

test("Different Firebase user cannot claim subscription", () => {
  assert.throws(
    () => check({ existingOwner: "firebase-user-b" }),
    /belongs to another account/
  );
});

test("Mismatched Apple account token is rejected", () => {
  assert.throws(
    () => check({
      verifiedAccountToken:
        "123e4567-e89b-42d3-a456-426614174000",
    }),
    /Apple account token mismatch/
  );
});

test("Missing Apple account token is rejected", () => {
  assert.throws(
    () => check({ verifiedAccountToken: null }),
    /Apple account token mismatch/
  );
});

test("Missing Firebase UID is rejected", () => {
  assert.throws(
    () => check({ uid: "" }),
    /Invalid account information/
  );
});
