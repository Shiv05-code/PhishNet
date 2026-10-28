
function selectCurrentEntitlement(evaluatedStatuses) {
    if (!Array.isArray(evaluatedStatuses) ||
        evaluatedStatuses.length === 0) {
      throw new Error("No subscription statuses available");
    }

    for (const item of evaluatedStatuses) {
      if (!item.entitlement ||
          typeof item.entitlement.hasPlusAccess !== "boolean") {
        throw new Error("Invalid subscription entitlement");
      }

      if (!Number.isSafeInteger(item.signedDate) ||
          item.signedDate < 0) {
        throw new Error("Missing authoritative signed date");
      }
    }

    const sorted = [...evaluatedStatuses].sort(
      (a, b) => b.signedDate - a.signedDate
    );

    if (
      sorted.length > 1 &&
      sorted[0].signedDate === sorted[1].signedDate &&
      sorted[0].entitlement.hasPlusAccess !==
        sorted[1].entitlement.hasPlusAccess
    ) {
      throw new Error("Conflicting subscription statuses");
    }

    return sorted[0];
  }

  module.exports = { selectCurrentEntitlement };
