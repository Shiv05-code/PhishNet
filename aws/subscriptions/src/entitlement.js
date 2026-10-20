
const { Status } = require("@apple/app-store-server-library");

function evaluateEntitlement(status, transaction, renewalInfo = null) {
  if (!transaction || typeof transaction !== "object") {
    throw new Error("Missing verified Apple transaction");
  }

  const expiresAt = transaction.expiresAt;

  if (!(expiresAt instanceof Date) ||
      !Number.isFinite(expiresAt.getTime())) {
    throw new Error("Invalid subscription expiration date");
  }

  const now = Date.now();
  const isRevoked = transaction.revocationDate != null;
  const isUnexpired = expiresAt.getTime() > now;

  let hasPlusAccess = false;
  let entitlementExpiresAt = expiresAt;

  if (!isRevoked && status === Status.ACTIVE && isUnexpired) {
    hasPlusAccess = true;
  }

  if (!isRevoked && status === Status.BILLING_GRACE_PERIOD) {
    const gracePeriodExpiresDate =
      renewalInfo?.gracePeriodExpiresDate;

    if (typeof gracePeriodExpiresDate === "number" &&
        gracePeriodExpiresDate > now) {
      hasPlusAccess = true;
      entitlementExpiresAt = new Date(gracePeriodExpiresDate);
    }
  }

  return {
    hasPlusAccess,
    plan: hasPlusAccess ? "plus" : "free",
    status: hasPlusAccess
      ? "active"
      : isRevoked || status === Status.REVOKED
        ? "revoked"
        : status === Status.EXPIRED ||
            expiresAt.getTime() <= now
          ? "expired"
          : status === Status.BILLING_RETRY
            ? "billing_retry"
            : "inactive",
    productId: transaction.productId,
    expiresAt: entitlementExpiresAt,
    appleStatus: status,
  };
}

module.exports = { evaluateEntitlement };
