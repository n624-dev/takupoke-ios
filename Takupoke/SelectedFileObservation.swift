#if canImport(Darwin)
import Foundation

/// One foreground registration. Stop also invalidates an in-flight registration.
final class SelectedFileObservation: SelectedFileObserving, @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    private var coordinator: NSFileCoordinator?
    private var presenter: SelectedFilePresenter?
    private var scopedURL: URL?
    private let resolve: () throws -> (url: URL, scope: URL?)
    private let changed: () -> Void
    private let registered: (Bool) -> Void
    private let registrationEnded: () -> Void
    private let diagnosticSource: FileRefreshDiagnostics.Source?

    init(source: SelectedFileSource, registered: @escaping (Bool) -> Void = { _ in },
         registrationEnded: @escaping () -> Void = {}, changed: @escaping () -> Void) {
        self.changed = changed; self.registered = registered
        self.registrationEnded = registrationEnded
        diagnosticSource = .init(rawValue: source.id)
        resolve = {
            guard let bookmark = source.bookmark else { throw MaterialError.accessExpired }
            var stale = false
            let root = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil,
                               bookmarkDataIsStale: &stale)
            guard !stale else { throw MaterialError.accessExpired }
            var target = root
            if let child = source.childName {
                guard !child.isEmpty, child != ".", child != "..",
                      !child.contains("/"), !child.contains("\\") else { throw MaterialError.invalidFile }
                target = root.appendingPathComponent(child)
            }
            return (target, root)
        }
    }

    // Local-file injection exercises the real coordination lifecycle in host tests.
    init(resolve: @escaping () throws -> (url: URL, scope: URL?), registered: @escaping (Bool) -> Void = { _ in },
         registrationEnded: @escaping () -> Void = {}, changed: @escaping () -> Void) {
        self.resolve = resolve
        self.changed = changed; self.registered = registered
        self.registrationEnded = registrationEnded
        diagnosticSource = nil
    }

    func start(requestInitialRefresh: Bool = true) {
        DispatchQueue.global(qos: .utility).async { [self] in
            // Stop invalidates publication immediately. The worker is still
            // owned until the real resolver/coordinate call has returned.
            defer { registrationEnded() }
            guard isActive else { return }
            do {
                let target = try resolve()
                guard isActive else { return }
                if let scope = target.scope {
                    guard scope.startAccessingSecurityScopedResource() else { throw MaterialError.accessExpired }
                }
                // Keep access alive even if stop occurs while coordination is unwinding.
                defer { target.scope?.stopAccessingSecurityScopedResource() }
                let newPresenter = SelectedFilePresenter(url: target.url, source: diagnosticSource, changed: changed)
                let newCoordinator = NSFileCoordinator(filePresenter: newPresenter)
                lock.lock()
                guard !stopped else { lock.unlock(); return }
                coordinator = newCoordinator
                lock.unlock()
                var error: NSError?
                newCoordinator.coordinate(readingItemAt: target.url, options: [], error: &error) { safeURL in
                    guard self.isActive else { return }
                    if let scope = target.scope, !scope.startAccessingSecurityScopedResource() { return }
                    // A system registration may block. Do not hold the state
                    // lock while performing it, so a timeout can invalidate it.
                    NSFileCoordinator.addFilePresenter(newPresenter)
                    let retained = self.lock.withLock {
                        guard !self.stopped else { return false }
                        self.scopedURL = target.scope
                        self.presenter = newPresenter
                        return true
                    }
                    if retained {
                        FileRefreshDiagnostics.shared.record(.registrationComplete, source: self.diagnosticSource)
                    } else {
                        newPresenter.deactivate()
                        NSFileCoordinator.removeFilePresenter(newPresenter)
                        target.scope?.stopAccessingSecurityScopedResource()
                    }
                }
                lock.lock()
                coordinator = nil
                let active = !stopped, succeeded = presenter != nil
                lock.unlock()
                if active { registered(succeeded) }
                if !succeeded {
                    FileRefreshDiagnostics.shared.record(.registrationFailure, source: diagnosticSource)
                }
                if requestInitialRefresh { notifyIfActive() }
            } catch {
                FileRefreshDiagnostics.shared.record(.registrationFailure, source: diagnosticSource)
                // The normal refresh records an actionable failure while retaining
                // the last successful analysis. Registration failure is not success.
                lock.lock(); let active = !stopped; lock.unlock()
                if active { registered(false) }
                if requestInitialRefresh { notifyIfActive() }
            }
        }
    }

    private var isActive: Bool { lock.withLock { !stopped } }

    private func notifyIfActive() {
        lock.lock()
        let active = !stopped
        lock.unlock()
        if active {
            FileRefreshDiagnostics.shared.record(.initialRefresh, source: diagnosticSource)
            changed()
        }
    }

    func refreshCompleted() {
        lock.lock(); let current = stopped ? nil : presenter; lock.unlock()
        current?.refreshCompleted()
    }

    func stop() {
        lock.lock()
        stopped = true
        let currentCoordinator = coordinator
        coordinator = nil
        let currentPresenter = presenter
        presenter = nil
        let scope = scopedURL
        scopedURL = nil
        lock.unlock()
        if let currentPresenter {
            currentPresenter.deactivate()
            NSFileCoordinator.removeFilePresenter(currentPresenter)
        }
        currentCoordinator?.cancel()
        scope?.stopAccessingSecurityScopedResource()
    }

    deinit { stop() }
}
#endif
