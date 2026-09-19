import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class SyntheticPDFProtocol: URLProtocol, @unchecked Sendable {
    // One request at a time; each scenario is set before starting the session.
    static var status = 200
    static var headers: [String: String] = [:]
    static var chunks = [Data("%PDF-synthetic".utf8)]
    static var seenRequest: URLRequest?
    static var stall = false

    // Capture every request so an accidental real URL cannot reach the network.
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard request.url?.host == "example.invalid" else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        Self.seenRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status,
                                       httpVersion: "HTTP/1.1", headerFields: Self.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if Self.stall { return }
        for chunk in Self.chunks { client?.urlProtocol(self, didLoad: chunk) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

enum WebPDFChecks {
    private enum Failure: Error { case assertion(String) }

    private static func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !value() { throw Failure.assertion(message) }
    }

    static func run(root: URL) throws {
        let library = try MaterialLibrary(root: root)
        let url = URL(string: "https://example.invalid/calendar.pdf")!
        let document = Data("%PDF-synthetic calendar".utf8)
        let modified = "Tue, 07 Apr 2026 15:07:16 GMT"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SyntheticPDFProtocol.self]

        func fetch(cached: WebPDFCacheMetadata? = nil, cancelled: Bool = false,
                   cancelAfterStart: Bool = false) throws -> WebPDFResponse {
            let staged = library.newStagingURL()
            defer { library.discardStaging(staged) }
            var cancellationChecks = 0
            let response = try WebPDFDownloader.fetch(url, to: staged, cached: cached,
                                                      configuration: configuration) {
                cancellationChecks += 1
                if cancelled || (cancelAfterStart && cancellationChecks > 1) { throw MaterialError.cancelled }
            }
            let source = MaterialSource(grant: nil, childName: nil, remoteURL: url,
                                        remoteETag: response.metadata.etag,
                                        remoteLastModified: response.metadata.lastModified)
            if response.notModified {
                try library.recordUnchanged(.events, source: source)
            } else {
                let contents = try Data(contentsOf: staged)
                try library.commit(staged: staged, kind: .events, source: source, originalName: "calendar.pdf",
                                   byteCount: contents.count, digest: "synthetic checksum", modifiedAt: response.modifiedAt)
            }
            return response
        }

        SyntheticPDFProtocol.status = 200
        SyntheticPDFProtocol.headers = ["ETag": "\"revision-one\"", "Last-Modified": modified]
        // The signature can span separate callbacks.
        SyntheticPDFProtocol.chunks = [document.prefix(2), document.dropFirst(2)]
        let first = try fetch()
        try check(!first.notModified && first.modifiedAt != nil, "Initial response metadata missing")
        try check(try Data(contentsOf: library.localURL(for: .events)!) == document, "PDF bytes changed")
        let original = library.state.record(for: .events)!
        let originalURL = library.localURL(for: .events)!

        SyntheticPDFProtocol.status = 304
        SyntheticPDFProtocol.headers = [:]
        SyntheticPDFProtocol.chunks = []
        let unchanged = try fetch(cached: first.metadata)
        try check(unchanged.notModified, "304 not recognized")
        try check(SyntheticPDFProtocol.seenRequest?.value(forHTTPHeaderField: "If-None-Match") == "\"revision-one\"", "ETag not sent")
        try check(SyntheticPDFProtocol.seenRequest?.value(forHTTPHeaderField: "If-Modified-Since") == modified, "Date validator not sent")
        try check(library.localURL(for: .events) == originalURL, "304 replaced saved PDF")
        try check(library.state.record(for: .events)?.acquiredAt == original.acquiredAt, "304 changed acquisition date")
        try check(library.state.record(for: .events)?.source.remoteETag == first.metadata.etag, "304 dropped validator")

        // A failure leaves the last successful document and binding untouched.
        for scenario in ["304-without-copy", "404", "html", "empty", "too-large", "stream-too-large", "cancelled", "in-flight-cancelled"] {
            SyntheticPDFProtocol.status = 200
            SyntheticPDFProtocol.headers = [:]
            SyntheticPDFProtocol.chunks = [document]
            SyntheticPDFProtocol.stall = scenario == "in-flight-cancelled"
            switch scenario {
            case "304-without-copy": SyntheticPDFProtocol.status = 304; SyntheticPDFProtocol.chunks = []
            case "404": SyntheticPDFProtocol.status = 404
            case "html": SyntheticPDFProtocol.chunks = [Data("<html>login</html>".utf8)]
            case "empty": SyntheticPDFProtocol.chunks = []
            case "too-large": SyntheticPDFProtocol.headers = ["Content-Length": String(MaterialLibrary.maximumBytes + 1)]
            case "stream-too-large":
                SyntheticPDFProtocol.chunks = [document] + Array(repeating: Data(repeating: 65, count: 1024 * 1024), count: 50)
            default: break
            }
            var rejected = false
            do {
                _ = try fetch(cancelled: scenario == "cancelled", cancelAfterStart: scenario == "in-flight-cancelled")
            } catch { rejected = true }
            try check(rejected, "Accepted invalid scenario: " + scenario)
            try check(try Data(contentsOf: originalURL) == document, "Failure changed saved PDF")
            try check(library.localURL(for: .events) == originalURL, "Failure changed binding")
            try check(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("staging").path).isEmpty,
                      "Failed request leaked staging")
        }

        SyntheticPDFProtocol.status = 200
        SyntheticPDFProtocol.stall = false
        SyntheticPDFProtocol.headers = ["ETag": "\"revision-two\""]
        SyntheticPDFProtocol.chunks = [Data("%PDF-updated synthetic calendar".utf8)]
        let updated = try fetch(cached: first.metadata)
        try check(updated.metadata.etag == "\"revision-two\"", "Changed PDF validator not saved")
        try check(library.localURL(for: .events) != originalURL, "Changed PDF not committed")
        try check(!FileManager.default.fileExists(atPath: originalURL.path), "Obsolete PDF retained")
        let restored = try MaterialLibrary(root: root)
        try check(restored.state.record(for: .events)?.source.remoteURL == url, "Saved web source lost on reload")

        // Even a wrong URL is intercepted and rejected; no external fallback.
        let blocked = library.newStagingURL()
        defer { library.discardStaging(blocked) }
        var blockedURLRejected = false
        do {
            _ = try WebPDFDownloader.fetch(URL(string: "https://blocked.invalid/calendar.pdf")!,
                                            to: blocked, cached: nil, configuration: configuration) {}
        } catch { blockedURLRejected = true }
        try check(blockedURLRejected, "Unexpected URL escaped the synthetic transport")

        for input in ["http://example.invalid/file.pdf", "file:///tmp/file.pdf", "https://user:secret@example.invalid/file.pdf"] {
            var rejected = false
            do { _ = try WebPDFDownloader.validatedURL(input) } catch { rejected = true }
            try check(rejected, "Unsafe web URL accepted")
        }
        print("Web PDF checks passed: streaming, conditional requests, 304 retention, changed content, failures and limits.")
    }
}
