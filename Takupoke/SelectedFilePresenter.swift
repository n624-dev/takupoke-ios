#if canImport(Darwin)
import Foundation

/// Notification callbacks never perform I/O or wait for the main thread.
final class SelectedFilePresenter: NSObject, NSFilePresenter {
    private let lock = NSLock()
    private var url: URL
    private let changed: () -> Void
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

    func presentedItemDidChange() { changed() }

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
