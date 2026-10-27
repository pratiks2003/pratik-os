// Must stay identical to TextFingerprint.cls.
import { createHmac } from "node:crypto";

export function normalize(value) {
  return (value ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

export function keyedHash(normalized, key) {
  return createHmac("sha256", key).update(normalized, "utf8").digest("hex");
}
