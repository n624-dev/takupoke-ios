#if canImport(Darwin)
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

struct SelectedFileCopy {
    let count: Int
    let digest: String
    let modifiedAt: Date?
    let receipt: SelectedFilePresenter.ReadReceipt
}
protocol SelectedFileProviding {
    func copy(_ url: URL, to staged: URL, source: FileRefreshDiagnostics.Source?, workbook: Bool,
              control: AcquisitionControl) throws -> SelectedFileCopy
}
struct SystemSelectedFileProvider: SelectedFileProviding {
    func copy(_ url: URL, to staged: URL, source: FileRefreshDiagnostics.Source?, workbook: Bool,
              control: AcquisitionControl) throws -> SelectedFileCopy {
        control.pipelineTicket?.enter(.access)
        try control.check()
        let access = SelectedFilePresenter.readAccess(for: url, source: source)
        let coordinator = access.coordinator
        control.attach(coordinator)
        defer { control.attach(nil) }
        var error: NSError?
        var result: Result<SelectedFileCopy, Error>?
        coordinator.coordinate(readingItemAt: url, options: [], error: &error) { safeURL in
            guard result == nil else { return } // A duplicate accessor never copies or completes twice.
            result = Result {
                let read = try access.read(at: safeURL) {
                    try control.check()
                    control.pipelineTicket?.enter(.acquiring)
                    let values = try safeURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true else { throw MaterialError.invalidFile }
                    let bytes = try MaterialFileReader.copy(safeURL, to: staged, isWorkbook: workbook, check: control.check,
                        progress: { control.pipelineTicket?.progress() }, digesting: { control.pipelineTicket?.enter(.checkingDigest) })
                    try control.check()
                    control.pipelineTicket?.enter(.access)
                    return (bytes, values.contentModificationDate)
                }
                return SelectedFileCopy(count: read.value.0.count, digest: read.value.0.digest,
                                        modifiedAt: read.value.1, receipt: read.receipt)
            }
        }
        try control.check()
        if let error { throw error }
        guard let result else { throw MaterialError.unavailable }
        return try result.get()
    }
}
#endif
