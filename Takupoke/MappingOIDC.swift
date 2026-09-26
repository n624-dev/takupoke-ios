import Foundation
import AuthenticationServices
import CryptoKit
import Security
import UIKit

@MainActor
final class MappingOIDC: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let issuer = "https://takuma-gakunin.n624.jp"
    static let clientID = "takupoke-ios"
    static let redirectURI = "jp.n624.takupoke:/oauth/callback"
    private var completion: ((Result<URL, Error>) -> Void)?
    private var session: ASWebAuthenticationSession?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    func accessToken(using network: URLSession) async throws -> String {
        defer { session = nil }
        let verifier = try Self.randomURLToken()
        let state = try Self.randomURLToken()
        let nonce = try Self.randomURLToken()
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        var authorize = URLComponents(string: Self.issuer + "/oauth/authorize")!
        authorize.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "scope", value: "openid mapping.read links.read"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let authorizeURL = authorize.url else { throw MappingError.authentication }
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            self.completion = { continuation.resume(with: $0) }
            let browser = ASWebAuthenticationSession(url: authorizeURL, callbackURLScheme: "jp.n624.takupoke") { url, error in
                Task { @MainActor in
                    if let url, error == nil { self.finish(.success(url)) }
                    else { self.finish(.failure(MappingError.authentication)) }
                }
            }
            self.session = browser
            browser.presentationContextProvider = self
            if !browser.start() { finish(.failure(MappingError.authentication)) }
        }
        guard callback.scheme == "jp.n624.takupoke", callback.host == nil,
              callback.path == "/oauth/callback",
              let query = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
              query.filter({ $0.name == "state" }).count == 1,
              query.first(where: { $0.name == "state" })?.value == state,
              query.filter({ $0.name == "code" }).count == 1,
              let code = query.first(where: { $0.name == "code" })?.value, !code.isEmpty,
              !query.contains(where: { $0.name == "error" }) else { throw MappingError.authentication }

        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "code_verifier", value: verifier),
        ]
        var request = URLRequest(url: URL(string: Self.issuer + "/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data((form.percentEncodedQuery ?? "").utf8)
        let (bytes, response) = try await network.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              bytes.count <= 64 * 1024,
              let value = try? JSONDecoder().decode(TokenResponse.self, from: bytes),
              value.token_type == "Bearer", value.expires_in > 0, value.expires_in <= 600,
              value.scope.split(separator: " ").contains("mapping.read"),
              value.scope.split(separator: " ").contains("links.read"),
              !value.access_token.isEmpty else { throw MappingError.authentication }
        try await verifyIDToken(value.id_token, nonce: nonce, network: network)
        return value.access_token
    }

    private func finish(_ result: Result<URL, Error>) {
        let callback = completion
        completion = nil
        callback?(result)
    }

    func cancel() {
        session?.cancel()
        finish(.failure(CancellationError()))
        session = nil
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let token_type: String
        let expires_in: Int
        let scope: String
        let id_token: String
    }

    private func verifyIDToken(_ jwt: String, nonce: String, network: URLSession) async throws {
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let headerBytes = Self.decodeURL(String(parts[0])),
              let payloadBytes = Self.decodeURL(String(parts[1])),
              let signatureBytes = Self.decodeURL(String(parts[2])),
              let header = try? JSONSerialization.jsonObject(with: headerBytes) as? [String: Any],
              let payload = try? JSONSerialization.jsonObject(with: payloadBytes) as? [String: Any],
              header["alg"] as? String == "ES256", header["typ"] as? String == "JWT",
              let kid = header["kid"] as? String, !kid.isEmpty,
              payload["iss"] as? String == Self.issuer,
              payload["aud"] as? String == Self.clientID,
              payload["nonce"] as? String == nonce,
              payload["acr"] as? String == "urn:takunin:assurance:strict",
              let amr = payload["amr"] as? [String], amr == ["microsoft"],
              let subject = payload["sub"] as? String, !subject.isEmpty,
              let exp = payload["exp"] as? TimeInterval,
              let iat = payload["iat"] as? TimeInterval,
              exp > Date().timeIntervalSince1970, iat <= Date().timeIntervalSince1970 + 30,
              exp > iat, exp - iat <= 600 else { throw MappingError.authentication }

        var request = URLRequest(url: URL(string: Self.issuer + "/oauth/jwks")!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await network.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              bytes.count <= 64 * 1024,
              let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let keys = object["keys"] as? [[String: Any]],
              let key = keys.first(where: { $0["kid"] as? String == kid && $0["kty"] as? String == "EC" &&
                                           $0["crv"] as? String == "P-256" && $0["alg"] as? String == "ES256" &&
                                           $0["use"] as? String == "sig" }),
              let x = (key["x"] as? String).flatMap(Self.decodeURL),
              let y = (key["y"] as? String).flatMap(Self.decodeURL),
              x.count == 32, y.count == 32,
              let publicKey = try? P256.Signing.PublicKey(x963Representation: Data([4]) + x + y),
              let signature = try? P256.Signing.ECDSASignature(rawRepresentation: signatureBytes),
              publicKey.isValidSignature(signature, for: Data((String(parts[0]) + "." + String(parts[1])).utf8)) else {
            throw MappingError.authentication
        }
    }

    private static func randomURLToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBufferPointer { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw MappingError.authentication
        }
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private static func decodeURL(_ value: String) -> Data? {
        let base = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        return Data(base64Encoded: base + String(repeating: "=", count: (4 - base.count % 4) % 4))
    }
}
