"""URLSession boundary shim for FoundationNetworking-only executable fixtures."""

LINUX_HTTP_FIXTURE = r'''
#if !canImport(Darwin)
extension BoundedHTTPResponse {
    static func read(_ request: URLRequest, using session: URLSession, maximum: Int) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        let (data, raw) = try await session.data(for: request)
        guard let response = raw as? HTTPURLResponse else { throw Failure.unexpectedResponse }
        guard response.statusCode == 200 || response.statusCode == 304 else { return (Data(), response) }
        let limit = response.statusCode == 304 ? 0 : maximum
        guard data.count <= limit,
              response.statusCode == 304 || response.expectedContentLength <= Int64(limit) else { throw Failure.sizeExceeded }
        return (data, response)
    }
}
#endif
'''
