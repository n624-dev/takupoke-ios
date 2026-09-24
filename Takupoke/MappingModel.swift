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

struct MappingSettingsView: View {
    @ObservedObject var model: MappingModel

    var body: some View {
        List {
            Section("名称対応表") {
                if let current = model.current {
                    LabeledContent("バージョン", value: current.version)
                    LabeledContent("最終取得") {
                        Text(current.fetchedAt, format: .dateTime.year().month().day().hour().minute())
                    }
                    LabeledContent("件数", value: "\(current.rules.subjects.count + current.rules.teachers.count + current.rules.rooms.count)件")
                } else {
                    Text("未取得").foregroundStyle(.secondary)
                }
                if model.updateAvailable {
                    Label(model.current == nil ? "名称対応表を取得できます。" : "名称対応表に更新があります。",
                          systemImage: "arrow.down.circle")
                        .foregroundStyle(.orange)
                }
                if model.busy { HStack { ProgressView(); Text("確認中…") } }
                if let message = model.message {
                    Label {
                        Text(message)
                    } icon: {
                        Image(systemName: model.failed ? "exclamationmark.triangle" : "info.circle")
                    }
                    .foregroundStyle(model.failed ? Color.orange : Color.secondary)
                }
                if !model.ready { Button("保存情報を再読み込み") { model.loadIfNeeded() } }
                Button(model.current == nil ? "名称対応表を取得" : "更新を確認") { model.refresh() }
                    .disabled(model.busy || !model.ready)
            } footer: {
                Text("起動時は更新の有無だけを確認します。取得時に学校アカウントで認証し、通常授業の詳細に正式名称を表示します。")
            }
        }
        .navigationTitle("名称対応表")
        .task { model.loadIfNeeded() }
    }
}
