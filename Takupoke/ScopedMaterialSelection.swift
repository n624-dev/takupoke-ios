import Foundation

/// Cancellation can be requested from the UI while the serial worker is
/// waiting for the File Provider. No UI work is performed under file coordination.
final class AcquisitionControl: @unchecked Sendable {
    var provider: any SelectedFileProviding = SystemSelectedFileProvider()
    let intentSnapshot: [String: UInt64]
    let period: SchoolDataPeriod
    let operationID: UUID
    init(intents: [String: UInt64] = [:], period: SchoolDataPeriod = .current(), operationID: UUID = UUID()) {
        intentSnapshot = intents; self.period = period; self.operationID = operationID
    }
    private var ticket: FilePipeline.Ticket?
    private var cancellationTargets: [FilePipeline.Ticket] = []
    var usedPipeline: Bool { lock.lock(); defer { lock.unlock() }; return !cancellationTargets.isEmpty }
    func registerCancellationTarget(_ target: FilePipeline.Ticket) {
        lock.lock(); cancellationTargets.append(target); let stop = cancelled; lock.unlock()
        if stop { target.cancel() }
    }
    var pipelineTicket: FilePipeline.Ticket? {
        get { lock.lock(); defer { lock.unlock() }; return ticket }
        set {
            lock.lock(); ticket = newValue; let stop = cancelled; lock.unlock()
            if stop { newValue?.cancel() }
        }
    }
    private let lock = NSLock()
    private var cancelled = false
    private var coordinator: NSFileCoordinator?
    private var acquiredProviders = Set<String>()

    var acquiredProviderSources: Set<String> {
        lock.lock(); defer { lock.unlock() }
        return acquiredProviders
    }

    func recordProviderAcquisition(_ id: String) {
        pipelineTicket?.acquired()
        lock.lock(); defer { lock.unlock() }
        acquiredProviders.insert(id)
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let active = coordinator, currentTicket = ticket
        let targets = cancellationTargets
        lock.unlock()
        currentTicket?.cancel()
        targets.forEach { $0.cancel() }
        if let active { DispatchQueue.global(qos: .utility).async { active.cancel() } }
    }

    func check() throws {
        try pipelineTicket?.check()
        lock.lock()
        let value = cancelled
        lock.unlock()
        if value { throw MaterialError.cancelled }
    }

    func attach(_ value: NSFileCoordinator?) {
        lock.lock()
        coordinator = value
        let shouldCancel = cancelled
        lock.unlock()
        pipelineTicket?.onAbort(value.map { coordinator in { coordinator.cancel() } })
        if shouldCancel { value?.cancel() }
    }
}

/// Acquire the picker URL before its callback returns; retain the lease until
/// the worker finishes copying and saving the bookmark. URL and lease are immutable.
final class ScopedMaterialSelection: @unchecked Sendable {
    let url: URL
    private let granted: Bool

    init(_ url: URL) {
        self.url = url
        granted = url.startAccessingSecurityScopedResource()
    }

    deinit { if granted { url.stopAccessingSecurityScopedResource() } }

    func access<T>(_ body: (URL) throws -> T) throws -> T {
        guard granted else { throw MaterialError.accessExpired }
        return try withExtendedLifetime(self) { try body(url) }
    }
}
