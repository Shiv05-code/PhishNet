
function validatePurchaseOwnership({
    existingOwner,
    uid,
    storedAccountToken,
    verifiedAccountToken,
  }) {
    if (
      typeof uid !== "string" ||
      !uid ||
      typeof storedAccountToken !== "string" ||
      !storedAccountToken
    ) {
      throw new Error("Invalid account information");
    }

    if (existingOwner != null && existingOwner !== uid) {
      throw new Error(
        "Apple subscription belongs to another account"
      );
    }

    if (
      typeof verifiedAccountToken !== "string" ||
      verifiedAccountToken !== storedAccountToken
    ) {
      throw new Error("Apple account token mismatch");
    }

    return true;
  }

  module.exports = { validatePurchaseOwnership };
