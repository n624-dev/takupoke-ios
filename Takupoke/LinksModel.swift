import Foundation
import SwiftUI

@MainActor
final class LinksModel: ObservableObject {
    @Published private(set) var updateAvailable = false
    private var generation = UUID()
    @Published private(set) var saved: SavedLinks?
    @Published private(set) var preferences = LinkPreferences()
    @Published private(set) var ready = false
    @Published private(set) var preferencesReady = true
    @Published private(set) var busy = false
    @Published private(set) var failed = false
    @Published private(set) var message: String?

    private var store: LinksStore?
    private let preferencesStore = LinkPreferencesStore()
    private let endpoint = URL(string: "https://takupoke-api.n624.jp/links")!

    var visibleFavorites: [LinkItem] {
        (saved?.payload.categories ?? []).flatMap(\.buttons)
            .filter { $0.visible && !isHidden($0.id) && isFavorite($0.id) }
    }

    var visibleRecommendations: [LinkItem] {
        saved?.payload.recommendations(hiddenIDs: preferences.hiddenIDs) ?? []
    }

    func loadIfNeeded() {
        guard !ready else { return }
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask, appropriateFor: nil, create: true)
            let opened = try LinksStore(root: base.appendingPathComponent("LinksAPI", isDirectory: true))
            store = opened
            do { saved = try opened.load() }
            catch {
                failed = true
                message = "保存済みの一覧を読み込めませんでした。更新を試してください。"
            }
            do { preferences = try preferencesStore.load() }
            catch {
                preferencesReady = false
                failed = true
                message = "一覧の設定を読み込めませんでした。保存済みの設定は変更していません。"
            }
            ready = true
        } catch {
            failed = true
            message = "一覧の保存先を開けませんでした。再試行してください。"
        }
    }

    func refresh(force: Bool = false) async {
        loadIfNeeded()
        guard ready, !busy else { return }
        busy = true
        let operation = generation
        let session = Self.networkSession()
        defer { session.invalidateAndCancel(); if operation == generation { busy = false } }
        do {
            let result = try await revision(using: session)
            guard operation == generation else { return }
            updateAvailable = result != .unchanged
        } catch {
            guard operation == generation else { return }
            report(error)
        }
    }

    func revision(using network: URLSession) async throws -> MappingRevisionResult {
        loadIfNeeded()
        guard ready else { throw LinksError.storage }
        let operation = generation
        let result = try await MappingService(baseURL: endpoint.deletingLastPathComponent(), network: network)
            .checkRevision(installed: saved?.revision, path: "links-revision")
        try Task.checkCancellation()
        guard operation == generation else { throw CancellationError() }
        updateAvailable = result != .unchanged
        failed = false
        message = updateAvailable ? (saved == nil ? "学校アカウントで認証して一覧を取得してください。" : "一覧に更新があります。") : "一覧は最新です。"
        return result
    }

    func download(token: String, revision: String, network: URLSession) async throws {
        guard let store else { throw LinksError.storage }
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, rawResponse) = try await network.data(for: request)
        try Task.checkCancellation()
        guard let response = rawResponse as? HTTPURLResponse,
              response.expectedContentLength <= LinksPayload.maximumBytes,
              data.count <= LinksPayload.maximumBytes else { throw LinksError.unavailable }
        if response.statusCode == 401 || response.statusCode == 403 { throw MappingError.authentication }
        guard response.value(forHTTPHeaderField: "X-Links-Revision") == revision else {
            throw MappingError.changedDuringDownload
        }
        var replacement = try LinksResponse.decode(status: response.statusCode, data: data,
            receivedETag: response.value(forHTTPHeaderField: "ETag"), saved: nil)
        replacement.revision = revision
        do { try store.save(replacement) } catch { throw LinksError.storage }
        saved = replacement; updateAvailable = false; failed = false
        message = "一覧を更新しました。"
    }

    func report(_ error: Error) {
        failed = true
        switch error as? MappingError {
        case .authentication: message = "認証を完了できませんでした。"
        case .changedDuringDownload: message = "取得中に一覧が更新されました。もう一度お試しください。"
        default: message = (error as? LinksError ?? .unavailable).localizedDescription
        }
        if saved != nil { message! += " 保存済みの一覧を表示しています。" }
    }

    func resetForRetention() {
        generation = UUID()
        saved = nil; store = nil; ready = false; busy = false
        updateAvailable = false; message = nil; failed = false
    }

    static func networkSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil; config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }

    func isFavorite(_ id: String) -> Bool { preferences.favoriteIDs.contains(id) }
    func isHidden(_ id: String) -> Bool { preferences.hiddenIDs.contains(id) }
    func color(for item: LinkItem) -> String { preferences.colorOverrides[item.id] ?? item.color }

    func toggleFavorite(_ id: String) {
        changePreferences { draft in
            if !draft.favoriteIDs.insert(id).inserted { draft.favoriteIDs.remove(id) }
        }
    }

    func hide(_ id: String) { changePreferences { _ = $0.hiddenIDs.insert(id) } }
    func restore(_ id: String) { changePreferences { _ = $0.hiddenIDs.remove(id) } }

    func setColor(_ color: String?, for id: String) {
        changePreferences { draft in
            if let color, LinksPayload.colors.contains(color) { draft.colorOverrides[id] = color }
            else { draft.colorOverrides.removeValue(forKey: id) }
        }
    }

    private func changePreferences(_ edit: (inout LinkPreferences) -> Void) {
        guard preferencesReady else { return }
        var draft = preferences
        edit(&draft)
        do {
            try preferencesStore.save(draft)
            preferences = draft
        } catch {
            failed = true
            message = "一覧の設定を保存できませんでした。"
        }
    }
}
