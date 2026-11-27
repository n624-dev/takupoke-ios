"""Run the production OAuth request encoding with fictional inputs."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from urllib.parse import parse_qs

ROOT = Path(__file__).resolve().parents[1]


class MappingOIDCFormTests(unittest.TestCase):
    def test_browser_cancellation_authentication_and_transport_are_distinct(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift is required to execute the authentication boundary")
        source = (ROOT / "Takupoke/MappingOIDC.swift").read_text(encoding="utf-8")
        models = (ROOT / "Takupoke/MappingModels.swift").read_text(encoding="utf-8")
        browser = source[source.index("    private static func browserResult"):source.index("    private func finish")]
        errors = models[models.index("enum MappingError:"):models.index("struct MappingRule:")]
        program = r'''import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(AuthenticationServices)
import AuthenticationServices
#else
struct ASWebAuthenticationSessionError: Error {
    enum Code { case canceledLogin }
    static let errorDomain = "fictional.web-auth"
    let code: Code
}
#endif

final class Transport: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, url.host == "auth.example.invalid",
              let status = Int(url.lastPathComponent) else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main struct Fixture {
''' + browser + r'''
    static func main() async throws {
        let callback = URL(string: "fictional:/oauth/callback")!
        #if canImport(AuthenticationServices)
        let cancelled: Error = NSError(domain: ASWebAuthenticationSessionError.errorDomain,
                                       code: ASWebAuthenticationSessionError.Code.canceledLogin.rawValue)
        #else
        let cancelled: Error = ASWebAuthenticationSessionError(code: .canceledLogin)
        #endif
        switch browserResult(url: nil, error: cancelled) {
        case .failure(let error) where error is CancellationError: break
        default: preconditionFailure("Browser cancellation must preserve cancellation")
        }
        switch browserResult(url: nil, error: URLError(.badURL)) {
        case .failure(MappingError.authentication): break
        default: preconditionFailure("A browser failure must remain an authentication failure")
        }
        let returned = try browserResult(url: callback, error: nil).get()
        precondition(returned == callback)
        precondition(MappingError.authentication.authenticationFailureDescription !=
                     MappingError.authenticationNetwork.authenticationFailureDescription)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Transport.self]
        let network = URLSession(configuration: configuration)
        defer { network.invalidateAndCancel() }
        func request(_ suffix: String) -> URLRequest {
            URLRequest(url: URL(string: "https://auth.example.invalid/" + suffix)!)
        }
        for suffix in ["offline", "429", "503"] {
            do {
                _ = try await fetch(request(suffix), using: network)
                preconditionFailure("Transport and service errors must be classified consistently")
            } catch MappingError.authenticationNetwork {}
        }
        let (_, rejected) = try await fetch(request("401"), using: network)
        precondition((rejected as? HTTPURLResponse)?.statusCode == 401)
        let stopping = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await fetch(request("200"), using: network)
        }
        do { _ = try await stopping.value; preconditionFailure("Explicit app cancellation must stay a cancellation") }
        catch is CancellationError {}
    }
}
''' + errors
        with tempfile.TemporaryDirectory(prefix="takupoke-oauth-result-") as scratch:
            root = Path(scratch)
            script = root / "Fixture.swift"
            probe = root / "probe"
            script.write_text(program, encoding="utf-8")
            subprocess.run([compiler, "-parse-as-library", str(script), "-o", str(probe)], check=True, timeout=60)
            subprocess.run([str(probe)], check=True, timeout=15)

    def test_exchange_preserves_opaque_code_in_form_body(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift is required to execute the request encoder")
        source = (ROOT / "Takupoke/MappingOIDC.swift").read_text(encoding="utf-8")
        start = source.index("        var form = URLComponents()")
        end = source.index("        let tokenRequestedAt =", start)
        program = '''import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum Fixture {
    static let clientID = "fictional-app"
    static let redirectURI = "fictional:/oauth/callback"
    static let issuer = "https://issuer.example.invalid"

    static func body(code: String, verifier: String) -> Data {
''' + source[start:end] + '''        precondition(request.httpMethod == "POST")
        precondition(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        return request.httpBody!
    }
}
let body = Fixture.body(code: CommandLine.arguments[1], verifier: "fictional-verifier")
print(String(decoding: body, as: UTF8.self))
'''
        with tempfile.TemporaryDirectory(prefix="takupoke-oauth-form-") as scratch:
            root = Path(scratch)
            script = root / "Fixture.swift"
            probe = root / "probe"
            script.write_text(program, encoding="utf-8")
            subprocess.run([compiler, str(script), "-o", str(probe)], check=True, timeout=60)
            for code in ("fictional-base64url_1", "fictional+code=& 日本語 %20"):
                with self.subTest(code=code):
                    result = subprocess.run([str(probe), code], check=True, timeout=5,
                                            capture_output=True, text=True, encoding="utf-8")
                    self.assertEqual(parse_qs(result.stdout.strip(), strict_parsing=True), {
                        "grant_type": ["authorization_code"], "code": [code],
                        "client_id": ["fictional-app"], "redirect_uri": ["fictional:/oauth/callback"],
                        "code_verifier": ["fictional-verifier"],
                    })
