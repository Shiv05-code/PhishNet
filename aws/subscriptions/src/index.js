
const { verifyFirebaseUser } = require("./firebase");
const { getOrCreateAccountToken } = require("./account_token");
const {
    fetchAppleTransactionAutomatically,
    verifyAppleTransaction,
    getVerifiedSubscriptionStatus,
  } = require("./apple");
const { evaluateEntitlement } = require("./entitlement");
function respond(statusCode, data) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
    body: JSON.stringify(data),
  };
}

const AUTH_ERRORS = new Set([
  "auth/id-token-expired",
  "auth/argument-error",
  "auth/id-token-revoked",
  "auth/invalid-id-token",
  "auth/user-disabled",
  "auth/user-not-found",
]);
const {
  selectCurrentEntitlement,
} = require("./select_entitlement");

const {
  beginReconciliation,
} = require("./reconciliation");

const {
  saveVerifiedSubscription,
} = require("./subscription_store");

exports.handler = async (event) => {
  const method =
    event.requestContext?.http?.method ?? event.httpMethod;

  const path = event.rawPath ?? event.path;

  const supported =
    (method === "GET" &&
      path === "/subscriptions/account-token") ||
    (method === "POST" &&
      path === "/subscriptions/verify");

  if (!supported) {
    return respond(404, { error: "Endpoint not found" });
  }

  const authorization =
    event.headers?.authorization ??
    event.headers?.Authorization;

  if (
    typeof authorization !== "string" ||
    !authorization.startsWith("Bearer ")
  ) {
    return respond(401, { error: "Authentication required" });
  }

  try {
    const idToken = authorization.slice(7).trim();

    if (!idToken) {
      return respond(401, {
        error: "Authentication required",
      });
    }

    const uid = await verifyFirebaseUser(idToken);

    if (method === "GET") {
      const appAccountToken =
        await getOrCreateAccountToken(uid);

      return respond(200, { appAccountToken });
    }

    // POST /subscriptions/verify
    let body;

    try {
      if (event.isBase64Encoded) {
        body = JSON.parse(
          Buffer.from(event.body ?? "", "base64").toString("utf8")
        );
      } else {
        body = JSON.parse(event.body ?? "");
      }
    } catch {
      return respond(400, { error: "Invalid JSON body" });
    }

    const transactionId = body?.transactionId;

    if (
      typeof transactionId !== "string" ||
      !/^[0-9]{1,30}$/.test(transactionId)
    ) {
      return respond(400, {
        error: "Invalid Apple transaction ID",
      });
    }

    // Verification and ownership checks are not implemented yet.
    // Never grant Plus access from this placeholder.
    const appleResponse =
  await fetchAppleTransactionAutomatically(transactionId);

const verifiedTransaction = await verifyAppleTransaction(
  appleResponse.signedTransactionInfo,
  appleResponse.environment
);

if (verifiedTransaction.transactionId !== transactionId) {
  return respond(400, {
    verified: false,
    error: "Apple transaction mismatch",
  });
}

const accountToken = await getOrCreateAccountToken(uid);

if (verifiedTransaction.appAccountToken !== accountToken) {
  return respond(403, {
    verified: false,
    error: "Purchase does not belong to this account",
  });
}

const statuses = await getVerifiedSubscriptionStatus(
  verifiedTransaction.originalTransactionId,
  appleResponse.environment
);

const matchingStatuses = statuses.filter(
  (item) =>
    item.transaction.originalTransactionId ===
      verifiedTransaction.originalTransactionId &&
    item.transaction.appAccountToken === accountToken
);

if (matchingStatuses.length === 0) {
  return respond(409, {
    verified: false,
    error: "No matching subscription status found",
  });
}

const evaluatedStatuses = matchingStatuses.map((item) => ({
  transactionId: item.transaction.transactionId,
  originalTransactionId: item.transaction.originalTransactionId,
  signedDate: item.transaction.signedDate,
  verifiedTransaction: item.transaction,
  appleStatus: item.status,
  entitlement: evaluateEntitlement(
    item.status,
    item.transaction,
    item.renewalInfo
  ),
}));




const selected = selectCurrentEntitlement(evaluatedStatuses);

const selectedTransaction = selected.verifiedTransaction;
const entitlement = selected.entitlement;

if (
  selectedTransaction.originalTransactionId !==
    verifiedTransaction.originalTransactionId ||
  selectedTransaction.appAccountToken !== accountToken ||
  selectedTransaction.environment !== appleResponse.environment
) {
  return respond(403, {
    verified: false,
    entitlementGranted: false,
    error: "Subscription ownership or environment mismatch",
  });
}

const revision = await beginReconciliation({
  environment: selectedTransaction.environment,
  originalTransactionId: selectedTransaction.originalTransactionId,
});

const saved = await saveVerifiedSubscription({
  uid,
  accountToken,
  verifiedTransaction: selectedTransaction,
  entitlement,
  revision,
});

if (!saved.success) {
  return respond(503, {
    verified: true,
    entitlementGranted: false,
    error: "Subscription could not be saved",
  });
}

return respond(200, {
  verified: true,
  entitlementGranted: entitlement.hasPlusAccess,
  eligibleForPlus: entitlement.hasPlusAccess,
  plan: saved.plan,
  status: saved.status,
});


  } catch (error) {
    if (AUTH_ERRORS.has(error?.code)) {
      return respond(401, {
        error: "Invalid authentication token",
      });
    }

    console.error(
      "Subscription handler failed:",
      error?.code ?? "internal_error"
    );

    return respond(500, {
      error: "Unable to process subscription request",
    });
  }
};
