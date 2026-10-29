
function selectCurrentEntitlement(evaluatedStatuses) {
    if (!Array.isArray(evaluatedStatuses) ||
        evaluatedStatuses.length === 0) {
      throw new Error("No subscription statuses available");
    }

    if (evaluatedStatuses.length !== 1) {
      throw new Error(
        "Multiple subscription statuses require reconciliation"
      );
    }

    const selected = evaluatedStatuses[0];

    if (
      !selected.entitlement ||
      typeof selected.entitlement.hasPlusAccess !== "boolean" ||
      !selected.verifiedTransaction ||
      !selected.originalTransactionId
    ) {
      throw new Error("Invalid subscription status");
    }

    return selected;
  }

  module.exports = { selectCurrentEntitlement };
