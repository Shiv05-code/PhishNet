
const { SecretsManagerClient, GetSecretValueCommand } =
  require("@aws-sdk/client-secrets-manager");

const admin = require("firebase-admin");

const secretsClient = new SecretsManagerClient({
  region: process.env.AWS_REGION || "us-east-2",
});

let initializationPromise;

async function initializeFirebase() {
  if (admin.apps.length > 0) {
    return admin;
  }

  if (!initializationPromise) {
    initializationPromise = (async () => {
      const secretId = process.env.FIREBASE_SECRET_ID;

      if (!secretId) {
        throw new Error("FIREBASE_SECRET_ID is not configured");
      }

      const response = await secretsClient.send(
        new GetSecretValueCommand({
          SecretId: secretId,
        })
      );

      if (!response.SecretString) {
        throw new Error("Firebase secret is empty");
      }

      const secret = JSON.parse(response.SecretString);

      let serviceAccount = secret.firebase_service_account;

      if (typeof serviceAccount === "string") {
        serviceAccount = JSON.parse(serviceAccount);
      }

      if (
        !serviceAccount ||
        typeof serviceAccount !== "object" ||
        !serviceAccount.project_id ||
        !serviceAccount.client_email ||
        !serviceAccount.private_key
      ) {
        throw new Error("Invalid Firebase service account");
      }

      const expectedProject = process.env.FIREBASE_PROJECT_ID;

      if (
        !expectedProject ||
        serviceAccount.project_id !== expectedProject
      ) {
        throw new Error("Firebase project mismatch");
      }

      if (admin.apps.length === 0) {
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId: expectedProject,
        });
      }

      return admin;
    })().catch((error) => {
      initializationPromise = undefined;
      throw error;
    });
  }

  return initializationPromise;
}

async function verifyFirebaseUser(idToken) {
  if (!idToken || typeof idToken !== "string") {
    throw new Error("Missing Firebase ID token");
  }

  const firebase = await initializeFirebase();

  const decodedToken = await firebase
    .auth()
    .verifyIdToken(idToken, true);

  return decodedToken.uid;
}

async function getFirestore() {
  const firebase = await initializeFirebase();
  return firebase.firestore();
}

module.exports = {
  initializeFirebase,
  verifyFirebaseUser,
  getFirestore,
};
