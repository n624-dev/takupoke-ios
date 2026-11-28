import Foundation
import Combine

@MainActor
final class ServiceStatusModel: ObservableObject {
    static let pageURL = URL(string: "https://status.n624.jp/")!
    nonisolated static let endpoint = URL(string: "https://status.n624.jp/index.json")!
    static let refreshNanoseconds: UInt64 = 180_000_000_000
    @Published private(set) var cache = ServiceStatusCache()
    @Published private(set) var checking = false
    @Published private(set) var functional: [MonitoredService: FunctionalStatusSnapshot] = [:]
    @Published private(set) var failedFunctional = Set<MonitoredService>()
    @Published private(set) var eventPublisher = EventPublisherStatus()
    private var request: Task<Void, Never>?
    private var requestID: UUID?
    private var observers = Set<UUID>()
    private var expiry: Task<Void, Never>?

    func beginObserving(_ owner: UUID) { observers.insert(owner) }
    func endObserving(_ owner: UUID) {
        observers.remove(owner)
        if observers.isEmpty { stop() }
    }

    func featureStatus(_ id: String, for service: MonitoredService, at date: Date) -> StatusPresentation {
        guard !failedFunctional.contains(service) else { return FunctionalStatusSnapshot.unknown }
        return functional[service]?.featurePresentation(id, at: date) ?? FunctionalStatusSnapshot.unknown
    }

    func onlineEventVersion(year: Int, format: String, at now: Date) -> FunctionalStatusSnapshot.EventVersion? {
        guard !failedFunctional.contains(.api) else { return nil }
        return functional[.api]?.eventVersion(year: year, format: format, at: now)
    }

    func eventsPresentation(_ events: SchoolEventsModel, year: Int) -> SchoolEventsSourcePresentation? {
        let now = Date()
        let format = events.saved[year]?.payload.format?.rawValue ?? "v2"
        return eventPublisher.presentation(year: year, format: format, online: onlineEventVersion(year: year, format: format, at: now),
                                           previous: events.sourcePresentation(year: year), at: now)
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
            async let api = Self.downloadFunctional(.api)
            async let authentication = Self.downloadFunctional(.authentication)
            do {
                let result = try await Self.download(Self.endpoint, maximumBytes: ServiceStatusSnapshot.maximumBytes,
                                                     etag: self.cache.etag)
                try Task.checkCancellation()
                guard self.requestID == id else { return }
                switch result {
                case .notModified(let etag): try self.cache.revalidate(responseETag: etag, at: Date())
                case .snapshot(let bytes, let etag):
                    let worker = Task.detached { try ServiceStatusSnapshot.decode(bytes) }
                    let snapshot = try await CancellationLinkedTask.value(of: worker)
                    try Task.checkCancellation()
                    guard self.requestID == id else { return }
                    self.cache.accept(snapshot, etag: etag, at: Date())
                }
                self.scheduleExpiry()
            } catch {
                guard self.requestID == id, !Task.isCancelled else { return }
                self.cache.recordFailure()
            }
            let (apiResult, authResult) = await (api, authentication)
            let results: [(MonitoredService, FunctionalStatusSnapshot?)] = [(.api, apiResult), (.authentication, authResult)]
            guard self.requestID == id, !Task.isCancelled else { return }
            for (service, result) in results {
                if let result {
                    self.functional[service] = result
                    self.failedFunctional.remove(service)
                    if service == .api { self.eventPublisher.accept(result, at: Date()) }
                } else { self.failedFunctional.insert(service) }
            }
            self.scheduleExpiry()
        }
        request = task
        await task.value
    }

    private enum Download {
        case notModified(String?)
        case snapshot(Data, String?)
    }

    private func scheduleExpiry() {
        expiry?.cancel()
        let now = Date()
        var deadlines = functional.values.flatMap { snapshot in
            snapshot.features.map(\.validUntil) + [snapshot.validUntil] + [snapshot.data?.events?.validUntil].compactMap { $0 }
        }
        if let checkedAt = cache.checkedAt { deadlines.append(checkedAt.addingTimeInterval(180)) }
        guard let next = deadlines.filter({ $0 > now }).min() else { expiry = nil; return }
        let wait = min(180, next.timeIntervalSince(now))
        expiry = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            catch { return }
            // Invalidate cached labels even while Settings is idle. This does
            // not perform network work or keep off-screen polling alive.
            self?.objectWillChange.send()
            self?.scheduleExpiry()
        }
    }

    // Streaming and JSON decoding run away from MainActor; no file or account data is sent.
    private nonisolated static func downloadFunctional(_ service: MonitoredService) async -> FunctionalStatusSnapshot? {
        let url = URL(string: service == .api ? "https://takupoke-api.n624.jp/status" : "https://takuma-gakunin.n624.jp/status")!
        guard case .snapshot(let data, _)? = try? await download(url, maximumBytes: FunctionalStatusSnapshot.maximumBytes) else { return nil }
        return try? FunctionalStatusSnapshot.decode(data, service: service)
    }

    private nonisolated static func download(_ url: URL, maximumBytes: Int, etag: String? = nil) async throws -> Download {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
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
              response.url == url, response.expectedContentLength <= maximumBytes else {
            throw ServiceStatusSnapshot.Failure.invalidResponse
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw ServiceStatusSnapshot.Failure.invalidResponse }
            data.append(byte)
        }
        try Task.checkCancellation()
        let value = response.value(forHTTPHeaderField: "ETag")
        let etag = value.flatMap { !$0.isEmpty && $0.utf8.count <= 512 && !$0.contains("\r") && !$0.contains("\n") ? $0 : nil }
        return .snapshot(data, etag)
    }

    /// View disappearance and backgrounding stop this screen's network work.
    private func stop() {
        requestID = nil
        request?.cancel()
        request = nil
        checking = false
    }
}
