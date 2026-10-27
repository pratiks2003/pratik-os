/**
 * Text normalisation and keyed hashing shared by the confidentiality guard,
 * the skill engine and scripts/compliance/add-blocked-term.mjs. The Node
 * script must normalise exactly the same way.
 */
public inherited sharing class TextFingerprint {
  public static String normalize(String value) {
    if (value == null) {
      return '';
    }
    return value.toLowerCase().replaceAll('[^a-z0-9]+', ' ').trim();
  }

  public static List<String> tokens(String value) {
    String normalized = normalize(value);
    return String.isBlank(normalized)
      ? new List<String>()
      : normalized.split(' ');
  }

  public static String keyedHash(String normalized, String key) {
    Blob mac = Crypto.generateMac(
      'hmacSHA256',
      Blob.valueOf(normalized),
      Blob.valueOf(key)
    );
    return EncodingUtil.convertToHex(mac);
  }
}
