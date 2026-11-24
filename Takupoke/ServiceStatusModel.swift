import Foundation
import Combine

@MainActor
final class ServiceStatusModel: ObservableObject {
    static let pageURL = URL(string: "https://status.n624.jp/")!
    nonisolated static let endpoint = URL(string: "https://status.n624.jp/index.json")!
    static let refreshNanoseconds: UInt64 = 180_000_000_000
    @Published private(set) var cache = ServiceStatusCache()
    @Published private(set) var checking = false
    private var request: Task<Void, Never>?
    private var requestID: UUID?
    private var observers = Set<UUID>()
    private var expiry: Task<Void, Never>?

    func beginObserving(_ owner: UUID) { observers.insert(owner) }
    func endObserving(_ owner: UUID) {
        observers.remove(owner)
        if observers.isEmpty { stop() }
    }

    func refresh() async {
        guard !Task.isCancelled, !observers.isEmpty else { return }
        if let request { await request.value; return }
        let id = UUID()
        requestID = id
        checking = true
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.requestID == id { self.request = nil; self.requestID = nil; self.checking = false }
            }
            do {
                let result = try await Self.download(etag: self.cache.etag)
                try Task.checkCancellation()
                guard self.requestID == id else { return }
                switch result {
                case .notModified(let etag): try self.cache.revalidate(responseETag: etag, at: Date())
                case .snapshot(let snapshot, let etag): self.cache.accept(snapshot, etag: etag, at: Date())
                }
                self.scheduleExpiry()
            } catch {
                guard self.requestID == id, !Task.isCancelled else { return }
                self.cache.recordFailure()
            }
        }
        request = task
        await task.value
    }

    private enum Download {
        case notModified(String?)
        case snapshot(ServiceStatusSnapshot, String?)
    }

    private func scheduleExpiry() {
        expiry?.cancel()
        expiry = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: Self.refreshNanoseconds) }
            catch { return }
            // Invalidate cached labels even while Settings is idle. This does
            // not perform network work or keep off-screen polling alive.
            self?.objectWillChange.send()
        }
    }

    // Streaming and JSON decoding run away from MainActor; no file or account data is sent.
    private nonisolated static func download(etag: String?) async throws -> Download {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (bytes, response) = try await session.bytes(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw ServiceStatusSnapshot.Failure.invalidResponse }
        if response.statusCode == 304 {
            guard etag?.isEmpty == false else { throw ServiceStatusSnapshot.Failure.invalidResponse }
            return .notModified(response.value(forHTTPHeaderField: "ETag"))
        }
        guard response.statusCode == 200,
              response.mimeType == "application/json" || response.mimeType == "application/vnd.api+json",
              response.expectedContentLength <= ServiceStatusSnapshot.maximumBytes else {
            throw ServiceStatusSnapshot.Failure.invalidResponse
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < ServiceStatusSnapshot.maximumBytes else { throw ServiceStatusSnapshot.Failure.invalidResponse }
            data.append(byte)
        }
        try Task.checkCancellation()
        let snapshot = try ServiceStatusSnapshot.decode(data)
        let value = response.value(forHTTPHeaderField: "ETag")
        let etag = value.flatMap { !$0.isEmpty && $0.utf8.count <= 512 && !$0.contains("\r") && !$0.contains("\n") ? $0 : nil }
        return .snapshot(snapshot, etag)
    }

    /// View disappearance and backgrounding stop this screen's network work.
    private func stop() {
        requestID = nil
        request?.cancel()
        request = nil
        checking = false
    }
}
