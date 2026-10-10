import CryptoKit
import Foundation

/// Verifies the Ed25519 signature over the canonical JSON of every field except `signature`.
enum ConfigVerifier {
    static func verify(_ config: [String: Any], publicKey: Data) -> Bool {
        guard publicKey.count == 32,
              let encoded = config["signature"] as? String,
              let signature = Data(base64Encoded: encoded), !signature.isEmpty,
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey) else { return false }
        var body = config
        body.removeValue(forKey: "signature")
        guard let canonical = try? CanonicalJSON.string(from: body) else { return false }
        return key.isValidSignature(signature, for: Data(canonical.utf8))
    }
}
