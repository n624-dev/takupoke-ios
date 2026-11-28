import Foundation
import SwiftUI

@MainActor
final class MappingModel: ObservableObject {
    @Published private(set) var current: SavedMapping?
    @Published private(set) var updateAvailable = false
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false
    @Published private(set) var revisionConfirmation: DistributedRevisionConfirmation?

    private var store: MappingStore?
    private var dataFile: URL?
    private let revisions = DistributedRevisionCoordinator()
    private var revisionBusyOwner: UUID?
    private var damagedFile: MappingStore.DamagedFile?
    private var storedReadFailed = false
    private static let storedReadWarning = "保存した名称データを読み込めません。学校アカウントで取得し直してください。"
    private var checkedAtStartup = false
    private var generation = UUID()
    private let directory: URL?
    private let baseURL: URL

    init(directory: URL? = nil, baseURL: URL = URL(string: "https://takupoke-api.n624.jp")!) {
        self.directory = directory; self.baseURL = baseURL
    }

    private var installation: DistributedRevisionConfirmation.Installation? {
        current.map { .init(revision: $0.revision, acquiredAt: $0.fetchedAt) }
    }

    private func recordConfirmation(_ confirmation: DistributedRevisionConfirmation) {
        revisionConfirmation = confirmation
        confirmation.save(beside: dataFile)
    }

    func loadIfNeeded() {
        guard !ready else { return }
        do {
            let directory: URL
            if let configured = self.directory { directory = configured }
            else {
                let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                    appropriateFor: nil, create: true)
                directory = base.appendingPathComponent("NameMappings", isDirectory: true)
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var protectedDirectory = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try protectedDirectory.setResourceValues(values)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
            #endif
            let file = directory.appendingPathComponent("mappings.sqlite")
            dataFile = file
            try? MappingStore.DamagedFile.discardAbandonedStage(in:directory)
            do {
                let store = try MappingStore(url: file)
                #if os(iOS)
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
                #endif
                do {
                    current = try store.load()
                    storedReadFailed = false
                } catch is MappingStore.InvalidPayload {
                    current = nil
                    storedReadFailed = true
                }
                self.store = store
            } catch {
                guard let damage = try? MappingStore.DamagedFile(url:file,error:error) else { throw error }
                damagedFile = damage
                current = nil
                storedReadFailed = true
            }
            failed = storedReadFailed
            if let installation {
                revisionConfirmation = .load(beside: file, installation: installation)
                updateAvailable = revisionConfirmation?.hasNewerRevision == true
            }
            message = storedReadFailed ? Self.storedReadWarning : nil
            ready = true
        } catch {
            failed = true
            message = MappingError.storage.localizedDescription
        }
    }

    func checkAtStartup() {
        loadIfNeeded()
        guard ready, !checkedAtStartup, !busy else { return }
        checkedAtStartup = true
        let operation = generation
        Task {
            guard operation == generation else { return }
            do {
                _ = try await revision()
            } catch {
                guard operation == generation, !(error is CancellationError) else { return }
                reportFailure("名称データの更新を確認できませんでした。")
            }
        }
    }

    func revision(using suppliedNetwork: URLSession? = nil) async throws -> MappingRevisionResult {
        loadIfNeeded()
        guard ready else { throw MappingError.storage }
        let operation = generation
        let inspected = installation
        return try await revisions.value(installed: inspected?.revision, force: true) { [self] in
            guard operation == generation, installation == inspected else { throw CancellationError() }
            let network = suppliedNetwork ?? Self.networkSession()
            let owner = UUID()
            revisionBusyOwner = owner; busy = true
            defer {
                if suppliedNetwork == nil { network.invalidateAndCancel() }
                if revisionBusyOwner == owner { revisionBusyOwner = nil; busy = false }
            }
            let result: MappingRevisionResult
            do {
                result = try await MappingService(baseURL: baseURL, network: network).checkRevision(installed: inspected?.revision)
                try Task.checkCancellation()
                guard operation == generation, installation == inspected else { throw CancellationError() }
            } catch {
                guard !Task.isCancelled, !(error is CancellationError),
                      operation == generation, installation == inspected else { throw CancellationError() }
                if let inspected { recordConfirmation(.init(failed: inspected, previous: revisionConfirmation, at: Date())) }
                throw error
            }
            if let inspected { recordConfirmation(.init(installation: inspected, result: result, at: Date())) }
            apply(result)
            if case .unchanged = result, !failed { message = "名称データは最新です。" }
            return result
        }
    }

    func checkInBackground() async {
        guard !Task.isCancelled else { return }
        let operation = generation
        do { _ = try await revision() }
        catch { if !Task.isCancelled, !(error is CancellationError), operation == generation { report(error) } }
    }

    func download(token: String, revision: String, network: URLSession) async throws {
        let damagedFile = self.damagedFile
        guard store != nil || damagedFile != nil else { throw MappingError.storage }
        let operation = generation
        let package = try await MappingService(baseURL: baseURL, network: network)
            .download(accessToken: token, expectedRevision: revision)
        try Task.checkCancellation()
        guard operation == generation, damagedFile == nil || self.damagedFile != nil else { throw CancellationError() }
        do {
            if let damagedFile {
                try damagedFile.install(package)
                self.damagedFile = nil
                ready = false
                loadIfNeeded()
                guard store != nil, current == package else { throw MappingError.storage }
            } else {
                guard let store else { throw MappingError.storage }
                try store.save(package)
            }
        } catch is CancellationError { throw CancellationError() }
        catch { throw MappingError.storage }
        storedReadFailed = false
        revisions.reset()
        current = package
        updateAvailable = false
        failed = false
        if let installation { recordConfirmation(.init(adopted: installation, at: package.fetchedAt)) }
        message = "名称データを更新しました。"
    }

    func report(_ error: Error) {
        guard !(error is CancellationError) else { return }
        let description = (error as? BoundedHTTPResponse.Failure)?.errorDescription ??
            (error as? MappingError ?? .unavailable).localizedDescription
        reportFailure(description)
    }

    private func reportFailure(_ description: String) {
        failed = true
        let warning = storedReadFailed ? Self.storedReadWarning + "\n" : ""
        message = warning + description + (current == nil ? "" : "保存済みの対応表を使用します。")
    }

    func resetForRetention() {
        generation = UUID()
        revisions.reset()
        revisionBusyOwner = nil
        current = nil; store = nil; damagedFile = nil; ready = false; busy = false
        dataFile = nil; revisionConfirmation = nil
        storedReadFailed = false
        checkedAtStartup = false; updateAvailable = false; message = nil; failed = false
    }

    func names(for lesson: PDFLesson) -> TimetableLessonNames {
        current?.rules.applying(to: lesson.names, className: lesson.className) ?? lesson.names
    }

    func names(for change: ScheduleChange) -> ChangePresentation {
        current?.rules.presenting(change) ?? .source(change)
    }

    private func apply(_ result: MappingRevisionResult) {
        updateAvailable = result != .unchanged
        failed = storedReadFailed
        message = storedReadFailed ? Self.storedReadWarning : nil
    }

    private static func networkSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        return URLSession(configuration: configuration)
    }
}
