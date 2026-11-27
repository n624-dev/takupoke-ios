import Foundation

enum BoundedHTTPResponse {
    enum Failure: LocalizedError {
        case unexpectedResponse, sizeExceeded, deadlineExceeded

        var errorDescription: String? {
            switch self {
            case .unexpectedResponse: return "配信元からの応答を確認できませんでした。"
            case .sizeExceeded: return "受信データのサイズが上限を超えました。"
            case .deadlineExceeded: return "通信が制限時間を超えました。"
            }
        }
    }

    @TaskLocal static var communicationBudget: CommunicationBudget?

    final class CommunicationBudget: @unchecked Sendable {
        private let lock = NSLock()
        private let now: @Sendable () -> ContinuousClock.Instant
        private let wait: @Sendable (ContinuousClock.Instant) async throws -> Void
        private let requestLimit: Duration
        private var remaining: Duration

        init(total: Duration = .seconds(180), perRequest: Duration = .seconds(60),
             now: @escaping @Sendable () -> ContinuousClock.Instant = { .now },
             wait: @escaping @Sendable (ContinuousClock.Instant) async throws -> Void = {
                 try await ContinuousClock().sleep(until: $0)
             }) {
            self.remaining = total
            self.requestLimit = perRequest
            self.now = now
            self.wait = wait
        }

        func read<Value: Sendable>(_ operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
            let start = now()
            let allowed = lock.withLock { () -> Duration in
                // Reserve the available allowance while this request owns it.
                let allowed = min(requestLimit, remaining)
                remaining -= allowed
                return allowed
            }
            guard allowed > .zero else { throw Failure.deadlineExceeded }
            let end = start.advanced(by: allowed)
            defer {
                let spent = min(allowed, max(.zero, start.duration(to: now())))
                lock.withLock { remaining += allowed - spent }
            }
            return try await Deadline(hasExpired: { [now] in now() >= end },
                                      waitUntilExpired: { [wait] in try await wait(end) }).read(operation)
        }
    }

    struct Deadline: Sendable {
        let hasExpired: @Sendable () -> Bool
        let waitUntilExpired: @Sendable () async throws -> Void

        init<C: Clock>(clock: C, duration: C.Duration) {
            let end = clock.now.advanced(by: duration)
            self.init(hasExpired: { clock.now >= end },
                      waitUntilExpired: { try await clock.sleep(until: end, tolerance: nil) })
        }

        init(hasExpired: @escaping @Sendable () -> Bool,
             waitUntilExpired: @escaping @Sendable () async throws -> Void) {
            self.hasExpired = hasExpired
            self.waitUntilExpired = waitUntilExpired
        }

        // The operation returns a candidate value. Only the caller may apply it
        // after checking its own request identity and current selection.
        func read<Value: Sendable>(_ operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
            try Task.checkCancellation()
            guard !hasExpired() else { throw Failure.deadlineExceeded }
            let (results, continuation) = AsyncStream<Result<Value, any Error>>.makeStream(bufferingPolicy: .bufferingOldest(1))
            let worker = Task.detached {
                do {
                    let value = try await operation()
                    continuation.yield(hasExpired() ? .failure(Failure.deadlineExceeded) : .success(value))
                } catch {
                    continuation.yield(hasExpired() ? .failure(Failure.deadlineExceeded) : .failure(error))
                }
                continuation.finish()
            }
            let timer = Task.detached {
                do {
                    try await waitUntilExpired()
                    continuation.yield(.failure(Failure.deadlineExceeded))
                } catch {
                    guard !Task.isCancelled else { return }
                    continuation.yield(.failure(error))
                }
                continuation.finish()
            }
            defer { worker.cancel(); timer.cancel(); continuation.finish() }
            var iterator = results.makeAsyncIterator()
            let outcome = await iterator.next()
            try Task.checkCancellation()
            guard !hasExpired() else { throw Failure.deadlineExceeded }
            guard let outcome else { throw CancellationError() }
            return try outcome.get()
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
        let budget = communicationBudget ?? CommunicationBudget(total: .seconds(60))
        return try await budget.read { try await readResponse(request, using: session, maximum: maximum) }
    }

    private static func readResponse(_ request: URLRequest, using session: URLSession,
                                     maximum: Int) async throws -> (Data, HTTPURLResponse) {
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
