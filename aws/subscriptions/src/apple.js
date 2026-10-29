
const {
    SecretsManagerClient,
    GetSecretValueCommand,
  } = require("@aws-sdk/client-secrets-manager");

  const {
    AppStoreServerAPIClient,
    SignedDataVerifier,
    Environment,
  } = require("@apple/app-store-server-library");

  const fs = require("node:fs");
  const path = require("node:path");

  const secretsClient = new SecretsManagerClient({
    region: process.env.AWS_REGION || "us-east-2",
  });

  const ALLOWED_PRODUCTS = new Set([
    "com.phishnet.plus.monthly",
    "com.phishnet.plus.yearly",
  ]);
  const certificateDirectory = path.join(__dirname, "../certs");

const appleRootCertificates = [
  "AppleIncRootCertificate.cer",
  "AppleRootCA-G2.cer",
  "AppleRootCA-G3.cer",
].map((filename) =>
  fs.readFileSync(path.join(certificateDirectory, filename))
);
  let appleClientsPromise;

  async function getAppleClients() {
    if (!appleClientsPromise) {
      appleClientsPromise = (async () => {
        const secretId = process.env.APPLE_SECRET_ID;

        if (!secretId) {
          throw new Error("APPLE_SECRET_ID is not configured");
        }

        const response = await secretsClient.send(
          new GetSecretValueCommand({ SecretId: secretId })
        );

        if (!response.SecretString) {
          throw new Error("Apple credentials secret is empty");
        }

        const credentials = JSON.parse(response.SecretString);

        const { keyId, issuerId, privateKey } = credentials;
        const bundleId = process.env.APPLE_BUNDLE_ID;
        const appId = Number(process.env.APPLE_APP_ID);

        if (!keyId || !issuerId || !privateKey || !bundleId ||
            !Number.isSafeInteger(appId) || appId <= 0) {
          throw new Error("Invalid Apple server configuration");
        }

        const signingKey = privateKey.replace(/\\n/g, "\n");

        return {
          production: new AppStoreServerAPIClient(
            signingKey,
            keyId,
            issuerId,
            bundleId,
            Environment.PRODUCTION
          ),
          sandbox: new AppStoreServerAPIClient(
            signingKey,
            keyId,
            issuerId,
            bundleId,
            Environment.SANDBOX
          ),
        };
      })().catch((error) => {
        appleClientsPromise = undefined;
        throw error;
      });
    }

    return appleClientsPromise;
  }

  async function fetchAppleTransaction(transactionId, environment) {
    if (
      typeof transactionId !== "string" ||
      !/^[0-9]+$/.test(transactionId)
    ) {
      throw new Error("Invalid Apple transaction ID");
    }

    if (environment !== "Sandbox" &&
        environment !== "Production") {
      throw new Error("Invalid Apple environment");
    }

    const clients = await getAppleClients();

    const client = environment === "Sandbox"
      ? clients.sandbox
      : clients.production;

    const response = await client.getTransactionInfo(transactionId);

    if (!response.signedTransactionInfo) {
      throw new Error("Apple returned no signed transaction");
    }

    return {
      signedTransactionInfo: response.signedTransactionInfo,
      environment,
    };
  }
  const APPLE_BUNDLE_ID = process.env.APPLE_BUNDLE_ID;
const APPLE_APP_ID = Number(process.env.APPLE_APP_ID);

function createVerifier(environment) {
  if (!APPLE_BUNDLE_ID) {
    throw new Error("APPLE_BUNDLE_ID is not configured");
  }

  if (
    environment === Environment.PRODUCTION &&
    (!Number.isSafeInteger(APPLE_APP_ID) || APPLE_APP_ID <= 0)
  ) {
    throw new Error("APPLE_APP_ID is invalid");
  }

  return new SignedDataVerifier(
    appleRootCertificates,
    true,
    environment,
    APPLE_BUNDLE_ID,
    environment === Environment.PRODUCTION
      ? APPLE_APP_ID
      : undefined
  );
}

async function verifyAppleTransaction(
  signedTransactionInfo,
  environment
) {
  if (
    typeof signedTransactionInfo !== "string" ||
    !signedTransactionInfo
  ) {
    throw new Error("Missing signed Apple transaction");
  }

  if (environment !== "Sandbox" &&
      environment !== "Production") {
    throw new Error("Invalid Apple environment");
  }

  const appleEnvironment =
    environment === "Sandbox"
      ? Environment.SANDBOX
      : Environment.PRODUCTION;

  const verifier = createVerifier(appleEnvironment);

  const transaction =
    await verifier.verifyAndDecodeTransaction(
      signedTransactionInfo
    );

  if (transaction.bundleId !== APPLE_BUNDLE_ID) {
    throw new Error("Apple bundle ID mismatch");
  }

  if (!ALLOWED_PRODUCTS.has(transaction.productId)) {
    throw new Error("Unrecognized subscription product");
  }

  if (
    !transaction.originalTransactionId ||
    !transaction.transactionId
  ) {
    throw new Error("Missing Apple transaction identifiers");
  }

  if (transaction.type !== "Auto-Renewable Subscription") {
    throw new Error("Transaction is not a subscription");
  }

  if (
    typeof transaction.expiresDate !== "number" ||
    !Number.isFinite(transaction.expiresDate)
  ) {
    throw new Error("Invalid subscription expiration date");
  }
  if (
    transaction.purchaseDate != null &&
    (!Number.isSafeInteger(transaction.purchaseDate) ||
      transaction.purchaseDate < 0)
  ) {
    throw new Error("Invalid Apple purchase date");
  }

  if (
    transaction.signedDate != null &&
    (!Number.isSafeInteger(transaction.signedDate) ||
      transaction.signedDate < 0)
  ) {
    throw new Error("Invalid Apple signed date");
  }
  return {
    transactionId: transaction.transactionId,
    originalTransactionId: transaction.originalTransactionId,
    productId: transaction.productId,

    purchaseDate: transaction.purchaseDate ?? null,
    signedDate: transaction.signedDate ?? null,

    expiresAt: new Date(transaction.expiresDate),
    revocationDate: transaction.revocationDate ?? null,

    environment,
    appAccountToken: transaction.appAccountToken ?? null,
  };
}
async function verifyAppleRenewalInfo(
    signedRenewalInfo,
    environment
  ) {
    if (
      typeof signedRenewalInfo !== "string" ||
      !signedRenewalInfo
    ) {
      throw new Error("Missing signed Apple renewal information");
    }

    if (environment !== "Sandbox" &&
        environment !== "Production") {
      throw new Error("Invalid Apple environment");
    }

    const appleEnvironment =
      environment === "Sandbox"
        ? Environment.SANDBOX
        : Environment.PRODUCTION;

    const verifier = createVerifier(appleEnvironment);

    return await verifier.verifyAndDecodeRenewalInfo(
      signedRenewalInfo
    );
  }
async function getVerifiedSubscriptionStatus(
    originalTransactionId,
    environment
  ) {
    if (
      typeof originalTransactionId !== "string" ||
      !/^[0-9]+$/.test(originalTransactionId)
    ) {
      throw new Error("Invalid original transaction ID");
    }

    if (environment !== "Sandbox" &&
        environment !== "Production") {
      throw new Error("Invalid Apple environment");
    }

    const clients = await getAppleClients();

    const client = environment === "Sandbox"
      ? clients.sandbox
      : clients.production;

    const response = await client.getAllSubscriptionStatuses(
      originalTransactionId
    );

    if (response.environment !== environment) {
      throw new Error("Apple subscription environment mismatch");
    }

    if (response.bundleId !== process.env.APPLE_BUNDLE_ID) {
      throw new Error("Apple subscription bundle ID mismatch");
    }

    const matches = [];

    for (const group of response.data ?? []) {
      for (const item of group.lastTransactions ?? []) {
        if (!item.signedTransactionInfo) continue;

        const transaction = await verifyAppleTransaction(
          item.signedTransactionInfo,
          environment
        );

        if (
          transaction.originalTransactionId !==
          originalTransactionId
        ) {
          continue;
        }

        let renewalInfo = null;

if (item.signedRenewalInfo) {
  renewalInfo = await verifyAppleRenewalInfo(
    item.signedRenewalInfo,
    environment
  );

  if (
    renewalInfo.originalTransactionId !==
      transaction.originalTransactionId ||
    renewalInfo.productId !== transaction.productId
  ) {
    throw new Error(
      "Apple renewal information does not match transaction"
    );
  }
}

matches.push({
  subscriptionGroupIdentifier: group.subscriptionGroupIdentifier,
  status: item.status,
  transaction,
  renewalInfo,
});
      }
    }

    return matches;
  }

const {
    APIException,
    APIError,
  } = require("@apple/app-store-server-library");

  async function fetchAppleTransactionAutomatically(transactionId) {
    try {
      return await fetchAppleTransaction(
        transactionId,
        "Production"
      );
    } catch (error) {
      const transactionNotFound =
        error instanceof APIException &&
        error.apiError === APIError.TRANSACTION_ID_NOT_FOUND;

      if (!transactionNotFound) {
        throw error;
      }

      // The production lookup did not find this transaction.
      // Try Sandbox, but do not assume the transaction is valid.
      return await fetchAppleTransaction(
        transactionId,
        "Sandbox"
      );
    }
  }

  module.exports = {
    ALLOWED_PRODUCTS,
    getAppleClients,
    fetchAppleTransaction,
    fetchAppleTransactionAutomatically,
    verifyAppleTransaction,
    verifyAppleRenewalInfo,
    getVerifiedSubscriptionStatus,
  };
