import Foundation
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

/// Claim checks run before fetching keys. Only a verified signature permits use.
struct MappingIDTokenVerification {
    private let kid: String
    private let signatureBytes: Data
    private let signingInput: Data

    init(jwt: String, issuer: String, clientID: String, nonce: String, selection: AccountDataSelection,
         now: TimeInterval) throws {
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let headerBytes = Self.decodeURL(String(parts[0])),
              let payloadBytes = Self.decodeURL(String(parts[1])),
              let signatureBytes = Self.decodeURL(String(parts[2])),
              let header = try? JSONSerialization.jsonObject(with: headerBytes) as? [String: Any],
              let payload = try? JSONSerialization.jsonObject(with: payloadBytes) as? [String: Any],
              header["alg"] as? String == "ES256", header["typ"] as? String == "JWT",
              let kid = header["kid"] as? String, !kid.isEmpty,
              payload["iss"] as? String == issuer,
              payload["aud"] as? String == clientID,
              payload["nonce"] as? String == nonce,
              let acr = payload["acr"] as? String, let amr = payload["amr"] as? [String],
              selection.acceptsAssurance(acr: acr, amr: amr),
              let subject = payload["sub"] as? String, !subject.isEmpty,
              let exp = payload["exp"] as? TimeInterval,
              let iat = payload["iat"] as? TimeInterval,
              exp > now, iat <= now + 30,
              exp > iat, exp - iat <= 600 else { throw MappingError.authentication }
        self.kid = kid
        self.signatureBytes = signatureBytes
        self.signingInput = Data((String(parts[0]) + "." + String(parts[1])).utf8)
    }

    func verifySignature(using bytes: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let keys = object["keys"] as? [[String: Any]],
              let key = keys.first(where: { $0["kid"] as? String == kid && $0["kty"] as? String == "EC" &&
                                           $0["crv"] as? String == "P-256" && $0["alg"] as? String == "ES256" &&
                                           $0["use"] as? String == "sig" }),
              let x = (key["x"] as? String).flatMap(Self.decodeURL),
              let y = (key["y"] as? String).flatMap(Self.decodeURL),
              x.count == 32, y.count == 32,
              let publicKey = try? P256.Signing.PublicKey(x963Representation: Data([4]) + x + y),
              let signature = try? P256.Signing.ECDSASignature(rawRepresentation: signatureBytes),
              publicKey.isValidSignature(signature, for: signingInput) else {
            throw MappingError.authentication
        }
    }

    private static func decodeURL(_ value: String) -> Data? {
        let base = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        return Data(base64Encoded: base + String(repeating: "=", count: (4 - base.count % 4) % 4))
    }
}

struct MappingAccessTokenCache {
    let value: String
    let scopes: Set<String>
    let expiresAt: Date

    func usableToken(requiring required: Set<String>, now: Date) -> String? {
        guard expiresAt > now.addingTimeInterval(30), required.isSubset(of: scopes) else { return nil }
        return value
    }
}
