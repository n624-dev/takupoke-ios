import Foundation

enum BoundedHTTPResponse {
    enum Failure: LocalizedError {
        case unexpectedResponse, sizeExceeded

        var errorDescription: String? {
            switch self {
            case .unexpectedResponse: return "配信元からの応答を確認できませんでした。"
            case .sizeExceeded: return "受信データのサイズが上限を超えました。"
            }
        }
    }

    static func collect<Body: AsyncSequence>(_ bytes: Body, expectedLength: Int64,
                                              maximum: Int) async throws -> Data where Body.Element == UInt8 {
        guard maximum >= 0, expectedLength <= Int64(maximum) else { throw Failure.sizeExceeded }
        try Task.checkCancellation()
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < maximum else { throw Failure.sizeExceeded }
            data.append(byte)
        }
        try Task.checkCancellation()
        return data
    }

    #if canImport(Darwin)
    static func read(_ request: URLRequest, using session: URLSession, maximum: Int) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        let (bytes, raw) = try await session.bytes(for: request)
        var completed = false
        defer { if !completed { bytes.task.cancel() } }
        guard let response = raw as? HTTPURLResponse else { throw Failure.unexpectedResponse }
        let data: Data
        switch response.statusCode {
        case 200:
            data = try await collect(bytes, expectedLength: response.expectedContentLength, maximum: maximum)
        case 304:
            // A 304 can advertise the length a 200 would have used.
            data = try await collect(bytes, expectedLength: -1, maximum: 0)
        default:
            // Only headers are needed to classify rejected requests.
            return (Data(), response)
        }
        completed = true
        return (data, response)
    }
    #endif
}
