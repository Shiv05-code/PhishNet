
const {
    initializeApp,
    getApps,
    getApp,
  } = require("firebase-admin/app");

  const {
    getFirestore,
  } = require("firebase-admin/firestore");

  function initializeTestFirestore() {
    const host = process.env.FIRESTORE_EMULATOR_HOST;
    const projectId = process.env.FIREBASE_PROJECT_ID;

    if (host !== "127.0.0.1:8080") {
      throw new Error(
        "Tests require the local Firestore Emulator"
      );
    }

    if (projectId !== "demo-phishnet") {
      throw new Error(
        "Tests require the demo-phishnet project"
      );
    }

    const appName = "phishnet-emulator-tests";

    const existingApp = getApps().find(
      (app) => app.name === appName
    );

    const app = existingApp ?? initializeApp(
      { projectId },
      appName
    );

    return getFirestore(app);
  }

  module.exports = { initializeTestFirestore };
