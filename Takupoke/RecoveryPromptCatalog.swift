import Foundation
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

/// The same verified instruction bytes are bundled in the app and iOS 27 runtime.
enum RecoveryPromptCatalog {
    static let promptVersion = "4"
    static let fieldExtractionSHA256 = "c24039ae4317a433a14f01697d77813424a3a1c20a70327189964b2fc60bb188"
    private enum Failure: Error { case missingResource, invalidResource }

    private static let loaded: Result<String, Error> = Result {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "field-extraction-v4", withExtension: "txt") else {
            throw Failure.missingResource
        }
        return try validateFieldExtraction(Data(contentsOf: url))
    }

    static func fieldExtraction() throws -> String { try loaded.get() }

    static func validateFieldExtraction(_ data: Data) throws -> String {
        guard data.count == 2939,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == fieldExtractionSHA256,
              let text = String(data: data, encoding: .utf8) else { throw Failure.invalidResource }
        return text
    }
}
