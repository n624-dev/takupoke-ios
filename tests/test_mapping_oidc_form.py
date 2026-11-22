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
