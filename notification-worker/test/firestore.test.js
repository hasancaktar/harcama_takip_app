import { test } from "node:test";
import assert from "node:assert/strict";
import { FirestoreStore, decodeFields, encodeFields } from "../src/firestore.js";
import { isUnregistered } from "../src/fcm.js";

test("Firestore değerleri gidiş-dönüş korunur", () => {
  const data = {
    s: "metin",
    i: 42,
    d: 1.5,
    b: true,
    n: null,
    t: new Date("2026-11-18T10:00:00.000Z"),
    a: ["x", 1],
    m: { iç: "değer" },
  };
  const encoded = encodeFields(data);
  assert.deepEqual(encoded.i, { integerValue: "42" });
  assert.deepEqual(encoded.t, { timestampValue: "2026-11-18T10:00:00.000Z" });
  assert.deepEqual(decodeFields(encoded), data);
});

test("koşullu güncelleme çakışırsa false döner, diğer hatalar fırlatılır", async () => {
  const responses = [
    new Response('{"error":{"status":"FAILED_PRECONDITION"}}', { status: 400 }),
    new Response('{"error":{"status":"PERMISSION_DENIED"}}', { status: 403 }),
  ];
  const bodies = [];
  const store = new FirestoreStore({
    projectId: "demo",
    getAccessToken: async () => "tok",
    fetchFn: async (url, init) => {
      bodies.push(JSON.parse(init.body));
      return responses.shift();
    },
  });
  assert.equal(await store.claimCampaign("c1", "2026-11-18T10:00:00Z", { status: "sending" }), false);
  assert.deepEqual(bodies[0].writes[0].currentDocument, { updateTime: "2026-11-18T10:00:00Z" });
  assert.deepEqual(bodies[0].writes[0].updateMask, { fieldPaths: ["status"] });
  await assert.rejects(store.claimCampaign("c1", "x", { status: "sending" }), /403/);
});

test("kullanıcı listesi sayfalanır ve yalnızca gereken alanlar istenir", async () => {
  const urls = [];
  const pages = [
    { documents: [{ name: "projects/demo/databases/(default)/documents/users/a", fields: { fcmTokens: { arrayValue: { values: [{ stringValue: "t" }] } } } }], nextPageToken: "p2" },
    { documents: [{ name: "projects/demo/databases/(default)/documents/users/b", fields: {} }] },
  ];
  const store = new FirestoreStore({
    projectId: "demo",
    getAccessToken: async () => "tok",
    fetchFn: async (url) => {
      urls.push(url);
      return new Response(JSON.stringify(pages.shift()), { status: 200 });
    },
  });
  const users = await store.listUsers();
  assert.deepEqual(users, [{ uid: "a", data: { fcmTokens: ["t"] } }, { uid: "b", data: {} }]);
  assert.match(urls[0], /mask\.fieldPaths=fcmTokens/);
  assert.doesNotMatch(urls[0], /email/);
  assert.match(urls[1], /pageToken=p2/);
});

test("geçersiz anahtarlar kullanıcı başına tek dönüşümle silinir", async () => {
  let body;
  const store = new FirestoreStore({
    projectId: "demo",
    getAccessToken: async () => "tok",
    fetchFn: async (_url, init) => {
      body = JSON.parse(init.body);
      return new Response("{}", { status: 200 });
    },
  });
  await store.removeTokens([{ uid: "a", token: "t1" }, { uid: "a", token: "t2" }, { uid: "b", token: "t3" }]);
  assert.equal(body.writes.length, 2);
  assert.deepEqual(
    body.writes[0].transform.fieldTransforms[0].removeAllFromArray.values,
    [{ stringValue: "t1" }, { stringValue: "t2" }],
  );
});

test("FCM: hangi hatalar geçersiz anahtar sayılır", () => {
  assert.equal(isUnregistered(404, { error: { details: [{ errorCode: "UNREGISTERED" }] } }), true);
  assert.equal(isUnregistered(400, { error: { message: "The registration token is not a valid FCM registration token" } }), true);
  assert.equal(isUnregistered(400, { error: { message: "Invalid JSON payload" } }), false);
  assert.equal(isUnregistered(503, { error: { status: "UNAVAILABLE" } }), false);
});

test("fetch, depo nesnesinin metodu olarak çağrılmaz (Workers 'Illegal invocation')", async () => {
  let thisValue = "işaretsiz";
  const store = new FirestoreStore({
    projectId: "demo",
    getAccessToken: async () => "tok",
    fetchFn: function (url) {
      thisValue = this;
      return Promise.resolve(new Response(JSON.stringify({ documents: [] }), { status: 200 }));
    },
  });
  await store.listUsers();
  assert.notEqual(thisValue, store);
});
