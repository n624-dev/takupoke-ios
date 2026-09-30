import XCTest
import Foundation
@testable import TakupokeParsing

final class TimetableTimesServiceTests: XCTestCase {
    private final class Stub: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            guard request.url?.host == "times.example.test" else {
                client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
            }
            let revision = String(repeating: "T", count: 43)
            let unchanged = request.value(forHTTPHeaderField: "If-None-Match") == "\"\(revision)\""
            let isRevision = request.url?.path == "/timetable-times-revision"
            let authorized = request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-token"
            let status = isRevision ? (unchanged ? 304 : 200) : (authorized ? 200 : 401)
            let headers = isRevision ? ["ETag": "\"\(revision)\""] :
                ["Content-Type": "application/json", "X-Timetable-Times-Revision": revision]
            let payload = TimetableTimes(schemaVersion: 1, days: [.init(date: "2032-05-12", periods: (1...8).map {
                .init(period: $0, start: String(format: "%02d:00", $0 + 7), end: String(format: "%02d:40", $0 + 7))
            })])
            let body = isRevision ? Data() : (try! JSONEncoder().encode(payload))
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status,
                httpVersion: "HTTP/1.1", headerFields: headers)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body); client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }
    private func service() -> (TimetableTimesService, URLSession) {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [Stub.self]
        let session = URLSession(configuration: config)
        return (.init(baseURL: URL(string: "https://times.example.test")!, network: session), session)
    }
    func testPublicConditionalRevision() async throws {
        let (service, session) = service(); defer { session.invalidateAndCancel() }
        let revision = String(repeating: "T", count: 43)
        let fresh = try await service.revision(installed: nil)
        XCTAssertEqual(fresh, .available(revision))
        let unchanged = try await service.revision(installed: revision)
        XCTAssertEqual(unchanged, .unchanged)
    }
    func testAuthenticatedDownloadAndChangedRevisionRejection() async throws {
        let (service, session) = service(); defer { session.invalidateAndCancel() }
        let saved = try await service.download(token: "synthetic-token", revision: String(repeating: "T", count: 43))
        XCTAssertEqual(saved.data.days.count, 1)
        do {
            _ = try await service.download(token: "synthetic-token", revision: String(repeating: "U", count: 43))
            XCTFail("Changed revision must be rejected")
        } catch { XCTAssertTrue(error is TimetableTimesError) }
        do {
            _ = try await service.download(token: "invalid", revision: String(repeating: "T", count: 43))
            XCTFail("Authentication must be required")
        } catch { XCTAssertTrue(error is TimetableTimesError) }
    }
}
