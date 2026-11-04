
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

const {
  doc,
  setDoc,
  getDoc,
  updateDoc,
  deleteDoc,
} = require("firebase/firestore");

test("Chat history is accessible only to its owner", async () => {
  const environment = await initializeTestEnvironment({
    projectId: "demo-phishnet-chat-history",
    firestore: {
      host: "127.0.0.1",
      port: 8085,
      rules: fs.readFileSync("../firestore.rules", "utf8"),
    },
  });

  try {
    const alice = environment.authenticatedContext("alice");
    const bob = environment.authenticatedContext("bob");
    const guest = environment.unauthenticatedContext();

    const path = "users/alice/chats/chat-test";

    const aliceRef = doc(alice.firestore(), path);
    const bobRef = doc(bob.firestore(), path);
    const guestRef = doc(guest.firestore(), path);

    await assertSucceeds(
      setDoc(aliceRef, {
        title: "Suspicious email",
        createdAt: new Date(),
        updatedAt: new Date(),
        messages: [],
      }),
    );

    const snapshot = await assertSucceeds(getDoc(aliceRef));

    assert.equal(snapshot.data().title, "Suspicious email");

    await assertFails(getDoc(bobRef));
    await assertFails(getDoc(guestRef));

    await assertFails(
      setDoc(bobRef, {
        title: "Unauthorized change",
      }),
    );

    await assertFails(deleteDoc(bobRef));

    await assertSucceeds(deleteDoc(aliceRef));
  } finally {
    await environment.cleanup();
  }
});
test("AI-generated titles preserve chat messages and timestamps", async () => {
  const environment = await initializeTestEnvironment({
    projectId: "demo-phishnet-chat-titles",
    firestore: {
      host: "127.0.0.1",
      port: 8085,
      rules: fs.readFileSync("../firestore.rules", "utf8"),
    },
  });

  try {
    const alice = environment.authenticatedContext("alice");
    const bob = environment.authenticatedContext("bob");

    const path = "users/alice/chats/title-test";

    const aliceRef = doc(alice.firestore(), path);
    const bobRef = doc(bob.firestore(), path);

    const createdAt = new Date("2026-11-01T10:00:00Z");
    const updatedAt = new Date("2026-11-01T10:05:00Z");

    const messages = [
      {
        fromUser: true,
        text: "I received a USPS delivery text.",
      },
      {
        fromUser: false,
        text: "This message may be suspicious.",
      },
    ];

    await assertSucceeds(
      setDoc(aliceRef, {
        title: "I received a USPS delivery text.",
        createdAt,
        updatedAt,
        messages,
      }),
    );

    await assertSucceeds(
      updateDoc(aliceRef, {
        title: "Suspicious USPS Delivery Text",
      }),
    );

    const snapshot = await assertSucceeds(getDoc(aliceRef));
    const saved = snapshot.data();

    assert.equal(
      saved.title,
      "Suspicious USPS Delivery Text",
    );

    assert.deepEqual(saved.messages, messages);

    assert.equal(
      saved.createdAt.toDate().getTime(),
      createdAt.getTime(),
    );

    assert.equal(
      saved.updatedAt.toDate().getTime(),
      updatedAt.getTime(),
    );

    await assertFails(
      updateDoc(bobRef, {
        title: "Unauthorized Title Change",
      }),
    );

    const verified = await assertSucceeds(getDoc(aliceRef));

    assert.equal(
      verified.data().title,
      "Suspicious USPS Delivery Text",
    );
  } finally {
    await environment.cleanup();
  }
});
