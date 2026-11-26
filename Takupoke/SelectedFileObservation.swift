#if canImport(Darwin)
import Foundation

/// One foreground registration. Stop also invalidates an in-flight registration.
final class SelectedFileObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    private var coordinator: NSFileCoordinator?
    private var presenter: SelectedFilePresenter?
    private var scopedURL: URL?
    private let resolve: () throws -> (url: URL, scope: URL?)
    private let changed: () -> Void
    private let diagnosticSource: FileRefreshDiagnostics.Source?

    init(source: SelectedFileSource, changed: @escaping () -> Void) {
        self.changed = changed
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
    init(resolve: @escaping () throws -> (url: URL, scope: URL?), changed: @escaping () -> Void) {
        self.resolve = resolve
        self.changed = changed
        diagnosticSource = nil
    }

    func start() {
        DispatchQueue.global(qos: .utility).async { [self] in
            do {
                let target = try resolve()
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
                    self.lock.lock()
                    defer { self.lock.unlock() }
                    guard !self.stopped else { return }
                    // Register inside the coordinated read so a change cannot fall
                    // between establishing the observation and the initial refresh.
                    if let scope = target.scope {
                        guard scope.startAccessingSecurityScopedResource() else { return }
                        self.scopedURL = scope
                    }
                    newPresenter.recordContentVersion(at: safeURL)
                    NSFileCoordinator.addFilePresenter(newPresenter)
                    self.presenter = newPresenter
                    FileRefreshDiagnostics.shared.record(.registrationComplete, source: self.diagnosticSource)
                }
                lock.lock()
                coordinator = nil
                lock.unlock()
                if error != nil {
                    FileRefreshDiagnostics.shared.record(.registrationFailure, source: diagnosticSource)
                }
                notifyIfActive()
            } catch {
                FileRefreshDiagnostics.shared.record(.registrationFailure, source: diagnosticSource)
                // The normal refresh records an actionable failure while retaining
                // the last successful analysis. Registration failure is not success.
                notifyIfActive()
            }
        }
    }

    private func notifyIfActive() {
        lock.lock()
        let active = !stopped
        lock.unlock()
        if active {
            FileRefreshDiagnostics.shared.record(.initialRefresh, source: diagnosticSource)
            changed()
        }
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
