import SwiftUI

@MainActor
final class TimetableTimesModel: ObservableObject {
    @Published private(set) var current: SavedTimetableTimes?
    @Published private(set) var updateAvailable = false
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var failed = false
    @Published private(set) var message: String?
    private var generation = UUID()
    private let baseURL: URL
    private var file: URL?
    private var storedReadWarning: String?
    private let directoryOverride: URL?

    init(directory: URL? = nil, baseURL: URL = URL(string: "https://takupoke-api.n624.jp")!) {
        directoryOverride = directory
        self.baseURL = baseURL
    }

    func loadIfNeeded() {
        guard !ready else { return }
        do {
            let directory: URL
            if let directoryOverride { directory = directoryOverride }
            else {
                let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                directory = base.appendingPathComponent("TimetableTimes", isDirectory: true)
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
            #endif
            var protectedDirectory = directory
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try protectedDirectory.setResourceValues(values)
            let file = directory.appendingPathComponent("current.json")
            // An unreadable cache must not prevent a user-requested replacement.
            // Directory setup failures still leave the model unavailable.
            if FileManager.default.fileExists(atPath: file.path) {
                do {
                    guard let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 132 * 1024 else { throw TimetableTimesError.storage }
                    let saved = try JSONDecoder().decode(SavedTimetableTimes.self, from: Data(contentsOf: file))
                    guard MappingPackage.validRevision(saved.revision) else { throw TimetableTimesError.storage }
                    _ = try saved.data.validated()
                    current = saved
                } catch {
                    storedReadWarning = "保存済みの授業時刻を読み込めませんでした。学校アカウントで取得し直してください。"
                }
            }
            self.file = file
            failed = storedReadWarning != nil
            message = storedReadWarning
            ready = true
        } catch { report(TimetableTimesError.storage) }
    }

    func revision(using network: URLSession) async throws -> MappingRevisionResult {
        loadIfNeeded()
        guard ready else { throw TimetableTimesError.storage }
        let operation = generation
        let result = try await TimetableTimesService(baseURL: baseURL, network: network).revision(installed: current?.revision)
        try Task.checkCancellation()
        guard operation == generation else { throw CancellationError() }
        updateAvailable = result != .unchanged
        failed = storedReadWarning != nil
        message = storedReadWarning ?? (updateAvailable ? nil : "授業時刻は最新です。")
        return result
    }

    func check() async {
        guard !busy, !Task.isCancelled else { return }
        busy = true
        let operation = generation
        let network = LinksModel.networkSession()
        defer { network.invalidateAndCancel(); if operation == generation { busy = false } }
        do { _ = try await revision(using: network) }
        catch { if !Task.isCancelled, operation == generation { report(error) } }
    }

    func download(token: String, revision: String, network: URLSession) async throws {
        guard let file else { throw TimetableTimesError.storage }
        let operation = generation
        let saved = try await TimetableTimesService(baseURL: baseURL, network: network).download(token: token, revision: revision)
        try Task.checkCancellation()
        guard operation == generation else { throw CancellationError() }
        do {
            try JSONEncoder().encode(saved).write(to: file, options: [.atomic, .completeFileProtection])
        } catch { throw TimetableTimesError.storage }
        storedReadWarning = nil
        current = saved; updateAvailable = false; failed = false; message = "授業時刻を更新しました。"
    }

    func report(_ error: Error) {
        failed = true
        let warning = storedReadWarning.map { $0 + "\n" } ?? ""
        message = warning + (error as? TimetableTimesError ?? .unavailable).localizedDescription
    }

    func resetForRetention() {
        generation = UUID(); current = nil; file = nil; ready = false; busy = false
        storedReadWarning = nil
        updateAvailable = false; failed = false; message = nil
    }
}
