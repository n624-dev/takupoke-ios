#if canImport(Darwin)
import Foundation

/// Notification callbacks never perform I/O or wait for the main thread.
final class SelectedFilePresenter: NSObject, NSFilePresenter {
    private let lock = NSLock()
    private var url: URL
    private let changed: () -> Void
    private let diagnosticSource: FileRefreshDiagnostics.Source?
    private var contentGate = FileContentChangeGate()
    private var active = true
    private var metadataCoordinator: NSFileCoordinator?
    let presentedItemOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()

    var presentedItemURL: URL? {
        lock.lock()
        defer { lock.unlock() }
        return url
    }

    init(url: URL, source: FileRefreshDiagnostics.Source? = nil, changed: @escaping () -> Void) {
        self.url = url
        self.changed = changed
        diagnosticSource = source
    }

    func presentedItemDidChange() {
        FileRefreshDiagnostics.shared.record(.providerChange, source: diagnosticSource)
        // The notification can mean that download status or another attribute
        // changed. Probe metadata without downloading the document or showing
        // the app as busy. Use this presenter to avoid notifying ourselves.
        presentedItemOperationQueue.addOperation { [weak self] in
            guard let self, let url = self.presentedItemURL else { return }
            let coordinator = NSFileCoordinator(filePresenter: self)
            self.lock.lock()
            guard self.active else { self.lock.unlock(); return }
            self.metadataCoordinator = coordinator
            self.lock.unlock()
            var error: NSError?
            var needsRefresh = false
            coordinator.coordinate(readingItemAt: url, options: .immediatelyAvailableMetadataOnly,
                                   error: &error) { safeURL in
                // Capture and compare under the same lock as read completion.
                // A delayed metadata probe must not overwrite a newer baseline.
                self.lock.lock()
                defer { self.lock.unlock() }
                guard self.active else { return }
                let version = Self.contentVersion(at: safeURL)
                needsRefresh = self.contentGate.shouldRefresh(version)
                FileRefreshDiagnostics.shared.record(version == nil ? .metadataUnavailable :
                    (needsRefresh ? .metadataChanged : .metadataUnchanged), source: self.diagnosticSource)
            }
            self.lock.lock()
            self.metadataCoordinator = nil
            if error != nil && self.active {
                needsRefresh = true
                FileRefreshDiagnostics.shared.record(.metadataUnavailable, source: self.diagnosticSource)
            }
            needsRefresh = self.active && needsRefresh
            self.lock.unlock()
            if needsRefresh { self.changed() }
        }
    }

    func deactivate() {
        lock.lock()
        active = false
        let coordinator = metadataCoordinator
        metadataCoordinator = nil
        lock.unlock()
        presentedItemOperationQueue.cancelAllOperations()
        coordinator?.cancel()
    }

    @discardableResult
    func recordContentVersion(at url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard active else { return false }
        let version = Self.contentVersion(at: url)
        contentGate.record(version)
        return version != nil
    }

    private static func contentVersion(at url: URL) -> FileContentVersion? {
        // A new URL value avoids reusing cached resource values from a previous
        // notification. Both keys must exist before an event can be skipped.
        let freshURL = URL(fileURLWithPath: url.path)
        guard let values = try? freshURL.resourceValues(forKeys: [.fileResourceIdentifierKey, .generationIdentifierKey]),
              let identity = values.fileResourceIdentifier as? NSObject,
              let generation = values.generationIdentifier as? NSObject else { return nil }
        return FileContentVersion(identity: identity, generation: generation)
    }

    /// Keep the presenter matched at the start of a read. Never acknowledge a
    /// different observation that replaced it while this operation was running.
    struct ReadAccess {
        let coordinator: NSFileCoordinator
        fileprivate let presenter: SelectedFilePresenter?

        /// Call inside the coordinated accessor, after all source handles close.
        /// A later external write cannot be mistaken for the bytes just read.
        func read<T>(at url: URL, body: () throws -> T) rethrows -> T {
            let result = try body()
            if let presenter {
                let recorded = presenter.recordContentVersion(at: url)
                FileRefreshDiagnostics.shared.record(recorded ? .readVersionRecorded : .readVersionUnavailable,
                                                     source: presenter.diagnosticSource)
            }
            return result
        }
    }

    static func readAccess(for url: URL) -> ReadAccess {
        let presenter = NSFileCoordinator.filePresenters.compactMap { $0 as? SelectedFilePresenter }.first {
            $0.presentedItemURL?.standardizedFileURL == url.standardizedFileURL
        }
        FileRefreshDiagnostics.shared.record(presenter == nil ? .coordinatorUnmatched : .coordinatorMatched,
                                             source: presenter?.diagnosticSource)
        return ReadAccess(coordinator: NSFileCoordinator(filePresenter: presenter), presenter: presenter)
    }

    static func coordinator(for url: URL) -> NSFileCoordinator {
        readAccess(for: url).coordinator
    }

    func presentedItemDidMove(to newURL: URL) {
        FileRefreshDiagnostics.shared.record(.providerMove, source: diagnosticSource)
        lock.lock()
        url = newURL
        lock.unlock()
        changed()
    }

    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        FileRefreshDiagnostics.shared.record(.providerDelete, source: diagnosticSource)
        changed()
        completionHandler(nil)
    }
}
#endif
