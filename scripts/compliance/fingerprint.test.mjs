// Run: node --test scripts/compliance
import { test } from "node:test";
import assert from "node:assert/strict";
import { normalize, keyedHash } from "./fingerprint.mjs";

test("normalises like TextFingerprint.cls", () => {
  assert.equal(normalize("  ACME-Secret!! "), "acme secret");
  assert.equal(normalize("/some_path/v2"), "some path v2");
});

test("hash matches the Apex test vector", () => {
  // Same vector as ComplianceGuardTest.keyedHashMatchesNodeScript
  assert.equal(
    keyedHash("acme secret", "k"),
    "db42b6119dad0a2f6f9499abbebd04c80e1717523af05fec9d032e97a9407b9c"
  );
});
