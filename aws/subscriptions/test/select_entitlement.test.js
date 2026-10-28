
const test = require("node:test");
const assert = require("node:assert/strict");

const {
  selectCurrentEntitlement,
} = require("../src/select_entitlement");

function makeStatus(signedDate, hasPlusAccess) {
  return {
    signedDate,
    entitlement: {
      hasPlusAccess,
      plan: hasPlusAccess ? "plus" : "free",
    },
  };
}

test("Selects the most recently signed status", () => {
  const statuses = [
    makeStatus(1000, true),
    makeStatus(3000, false),
    makeStatus(2000, true),
  ];

  const selected = selectCurrentEntitlement(statuses);

  assert.equal(selected.signedDate, 3000);
  assert.equal(selected.entitlement.plan, "free");
});

test("Selects active Plus when it is most recent", () => {
  const statuses = [
    makeStatus(1000, false),
    makeStatus(3000, true),
  ];

  const selected = selectCurrentEntitlement(statuses);

  assert.equal(selected.entitlement.plan, "plus");
});

test("Rejects empty subscription statuses", () => {
  assert.throws(
    () => selectCurrentEntitlement([]),
    /No subscription statuses available/
  );
});

test("Rejects conflicting statuses with equal dates", () => {
  const statuses = [
    makeStatus(3000, true),
    makeStatus(3000, false),
  ];

  assert.throws(
    () => selectCurrentEntitlement(statuses),
    /Conflicting subscription statuses/
  );
});

test("Rejects missing signed dates", () => {
  const statuses = [
    {
      entitlement: {
        hasPlusAccess: true,
        plan: "plus",
      },
    },
  ];

  assert.throws(
    () => selectCurrentEntitlement(statuses),
    /Missing authoritative signed date/
  );
});
