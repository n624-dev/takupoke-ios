import XCTest
import Foundation
@testable import TakupokeParsing

final class MappingServiceTests: XCTestCase {
    private let revision = String(repeating: "A", count: 43)

    private final class StubProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            let revision = String(repeating: "A", count: 43)
            let status: Int
            let headers: [String: String]
            let body: Data
            switch (request.url?.host ?? "", request.url?.path ?? "") {
            case ("unchanged.example.test", "/mapping-revision")
                where request.value(forHTTPHeaderField: "If-None-Match") == "\"\(revision)\"" &&
                      request.value(forHTTPHeaderField: "Authorization") == nil:
                status = 304; headers = ["ETag": "\"\(revision)\""]; body = Data()
            case ("changed.example.test", "/mapping-revision")
                where request.value(forHTTPHeaderField: "Authorization") == nil:
                status = 200; headers = ["ETag": "\"\(revision)\""]; body = Data()
            case ("mismatch.example.test", "/mappings/current")
                where request.value(forHTTPHeaderField: "Authorization") == "Bearer fake-access-token":
                status = 200
                headers = ["Content-Type": "application/zip", "X-Mapping-Version": "v1",
                           "X-Mapping-Revision": String(repeating: "B", count: 43), "ETag": "\"zip\""]
                body = Data([0x50, 0x4B, 0x03, 0x04])
            default:
                status = 400; headers = [:]; body = Data()
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                           headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private func service(host: String) -> (MappingService, URLSession) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: configuration)
        return (MappingService(baseURL: URL(string: "https://\(host)/")!, network: session), session)
    }

    func testRevisionCheckUsesConditionalRequestAndNoCredentials() async throws {
        let (service, network) = service(host: "unchanged.example.test")
        defer { network.invalidateAndCancel() }
        let result = try await service.checkRevision(installed: revision)
        XCTAssertEqual(result, .unchanged)
    }

    func testChangedRevisionDoesNotDownloadZip() async throws {
        let (service, network) = service(host: "changed.example.test")
        defer { network.invalidateAndCancel() }
        let result = try await service.checkRevision(installed: nil)
        XCTAssertEqual(result, .available(revision))
    }

    func testDifferentPrivateRevisionCannotBeAdopted() async throws {
        let (service, network) = service(host: "mismatch.example.test")
        defer { network.invalidateAndCancel() }
        do {
            _ = try await service.download(accessToken: "fake-access-token", expectedRevision: revision)
            XCTFail("Different revisions must not be stored")
        } catch MappingError.changedDuringDownload {
            // The model never reaches its save call.
        }
    }
}
