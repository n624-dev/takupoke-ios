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

    private let oidc = MappingOIDC()
    private var store: MappingStore?
    private var checkedAtStartup = false
    private let baseURL = URL(string: "https://takupoke-api.n624.jp")!

    func loadIfNeeded() {
        guard !ready else { return }
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
            let directory = base.appendingPathComponent("NameMappings", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var protectedDirectory = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try protectedDirectory.setResourceValues(values)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
            #endif
            let file = directory.appendingPathComponent("mappings.sqlite")
            let store = try MappingStore(url: file)
            let saved = try store.load()
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
            #endif
            self.store = store
            current = saved
            ready = true
            failed = false
            message = nil
        } catch {
            failed = true
            message = MappingError.storage.localizedDescription
        }
    }

    func checkAtStartup() {
        loadIfNeeded()
        guard ready, !checkedAtStartup, !busy else { return }
        checkedAtStartup = true
        busy = true
        Task {
            let network = Self.networkSession()
            defer { network.invalidateAndCancel(); busy = false }
            do {
                let result = try await MappingService(baseURL: baseURL, network: network)
                    .checkRevision(installed: current?.revision)
                apply(result)
            } catch {
                failed = true
                message = "名称対応表の更新を確認できませんでした。" +
                    (current == nil ? "" : "保存済みの対応表を使用します。")
            }
        }
    }

    func refresh() {
        loadIfNeeded()
        guard ready, !busy, let store else { return }
        busy = true
        failed = false
        message = nil
        Task {
            let network = Self.networkSession()
            defer { network.invalidateAndCancel(); busy = false }
            do {
                let service = MappingService(baseURL: baseURL, network: network)
                let result = try await service.checkRevision(installed: current?.revision)
                switch result {
                case .unchanged:
                    updateAvailable = false
                    message = "名称対応表は最新です。"
                case .available(let revision):
                    updateAvailable = true
                    let token = try await oidc.accessToken(using: network)
                    let package = try await service.download(accessToken: token, expectedRevision: revision)
                    do { try store.save(package) } catch { throw MappingError.storage }
                    current = package
                    updateAvailable = false
                    message = "名称対応表を更新しました。"
                }
            } catch {
                failed = true
                message = (error as? MappingError ?? .unavailable).localizedDescription +
                    (current == nil ? "" : "保存済みの対応表を使用します。")
            }
        }
    }

    func names(for lesson: PDFLesson) -> TimetableLessonNames {
        current?.rules.applying(to: lesson.names, className: lesson.className) ?? lesson.names
    }

    func names(for change: ScheduleChange) -> ChangePresentation {
        current?.rules.presenting(change) ?? .source(change)
    }

    private func apply(_ result: MappingRevisionResult) {
        failed = false
        switch result {
        case .unchanged:
            updateAvailable = false
            message = nil
        case .available:
            updateAvailable = true
            message = nil
        }
    }

    private static func networkSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        return URLSession(configuration: configuration)
    }
}
