import Foundation

/// Cancellation can be requested from the UI while the serial worker is
/// waiting for the File Provider. No UI work is performed under file coordination.
final class AcquisitionControl {
    private let lock = NSLock()
    var cancelled = false
    var coordinator: NSFileCoordinator?

    func cancel() {
        lock.lock()
        cancelled = true
        let active = coordinator
        lock.unlock()
        active?.cancel()
    }

    func check() throws {
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
