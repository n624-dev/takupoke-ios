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
    private let baseURL = URL(string: "https://takupoke-api.n624.jp")!
    private var file: URL?

    func loadIfNeeded() {
        guard !ready else { return }
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let directory = base.appendingPathComponent("TimetableTimes", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
            var protectedDirectory = directory
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try protectedDirectory.setResourceValues(values)
            let file = directory.appendingPathComponent("current.json")
            if FileManager.default.fileExists(atPath: file.path) {
                guard let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 132 * 1024 else { throw TimetableTimesError.storage }
                let saved = try JSONDecoder().decode(SavedTimetableTimes.self, from: Data(contentsOf: file))
                guard MappingPackage.validRevision(saved.revision) else { throw TimetableTimesError.storage }
                _ = try saved.data.validated()
                current = saved
            }
            self.file = file
            ready = true; failed = false; message = nil
        } catch { report(TimetableTimesError.storage) }
    }

    func revision(using network: URLSession) async throws -> MappingRevisionResult {
        loadIfNeeded()
        guard ready else { throw TimetableTimesError.storage }
        let operation = generation
        let result = try await TimetableTimesService(baseURL: baseURL, network: network).revision(installed: current?.revision)
        try Task.checkCancellation()
        guard operation == generation else { throw CancellationError() }
        failed = false
        switch result {
        case .unchanged: updateAvailable = false; message = "授業時刻は最新です。"
        case .available: updateAvailable = true; message = nil
        }
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
        current = saved; updateAvailable = false; failed = false; message = "授業時刻を更新しました。"
    }

    func report(_ error: Error) {
        failed = true
        message = (error as? TimetableTimesError ?? .unavailable).localizedDescription
    }

    func resetForRetention() {
        generation = UUID(); current = nil; file = nil; ready = false; busy = false
        updateAvailable = false; failed = false; message = nil
    }
}
