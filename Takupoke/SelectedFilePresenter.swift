#if canImport(Darwin)
import Foundation

/// Notification callbacks never perform I/O or wait for the main thread.
final class SelectedFilePresenter: NSObject, NSFilePresenter {
    private let lock = NSLock()
    private var url: URL
    private let changed: () -> Void
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

    init(url: URL, changed: @escaping () -> Void) {
        self.url = url
        self.changed = changed
    }

    func presentedItemDidChange() {
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
            var version: FileContentVersion?
            coordinator.coordinate(readingItemAt: url, options: .immediatelyAvailableMetadataOnly,
                                   error: &error) { safeURL in
                version = Self.contentVersion(at: safeURL)
            }
            self.lock.lock()
            self.metadataCoordinator = nil
            let needsRefresh = self.active && self.contentGate.shouldRefresh(error == nil ? version : nil)
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

    func recordContentVersion(at url: URL) {
        let version = Self.contentVersion(at: url)
        lock.lock()
        contentGate.record(version)
        lock.unlock()
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

    static func coordinator(for url: URL) -> NSFileCoordinator {
        let presenter = NSFileCoordinator.filePresenters.compactMap { $0 as? SelectedFilePresenter }.first {
            $0.presentedItemURL?.standardizedFileURL == url.standardizedFileURL
        }
        return NSFileCoordinator(filePresenter: presenter)
    }

    func presentedItemDidMove(to newURL: URL) {
        lock.lock()
        url = newURL
        lock.unlock()
        changed()
    }

    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        changed()
        completionHandler(nil)
    }
}
#endif
