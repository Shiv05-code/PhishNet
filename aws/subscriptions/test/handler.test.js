
const test = require("node:test");
const assert = require("node:assert/strict");

const { handler } = require("../src/index");

function makeEvent({
  method = "POST",
  path = "/subscriptions/verify",
  authorization = null,
  body = { transactionId: "1234567890" },
} = {}) {
  return {
    requestContext: {
      http: { method },
    },
    rawPath: path,
    headers: authorization
      ? { authorization }
      : {},
    body: JSON.stringify(body),
    isBase64Encoded: false,
  };
}

test("Rejects unsupported endpoints", async () => {
  const response = await handler(
    makeEvent({ path: "/unknown" })
  );

  assert.equal(response.statusCode, 404);
});

test("Rejects requests without authentication", async () => {
  const response = await handler(makeEvent());

  assert.equal(response.statusCode, 401);
  assert.equal(
    JSON.parse(response.body).error,
    "Authentication required"
  );
});

test("Rejects empty bearer tokens", async () => {
  const response = await handler(
    makeEvent({ authorization: "Bearer " })
  );

  assert.equal(response.statusCode, 401);
});
