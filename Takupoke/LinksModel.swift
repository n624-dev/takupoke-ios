import Foundation
import SwiftUI

@MainActor
final class LinksModel: ObservableObject {
    @Published private(set) var updateAvailable = false
    private var generation = UUID()
    @Published private(set) var saved: SavedLinks? {
        didSet {
            searchPreparation?.cancel()
            searchPreparation = nil
            searchRevision = UUID()
        }
    }
    @Published private(set) var preferences = LinkPreferences()
    @Published private(set) var ready = false
    @Published private(set) var preferencesReady = true
    @Published private(set) var busy = false
    @Published private(set) var failed = false
    @Published private(set) var message: String?
    @Published private(set) var revisionConfirmation: DistributedRevisionConfirmation?

    private var store: LinksStore?
    private var storedReadWarning: String?
    private let preferencesStore: LinkPreferencesStore
    private let storeRoot: URL?
    private let revisions = DistributedRevisionCoordinator()
    private let revisionNetwork: () -> URLSession
    private var revisionBusyOwner: UUID?
    private var searchPreparation: Task<LinkSearch.Index, Error>?
    private(set) var searchRevision = UUID()
    var pendingRevisionWaiters: Int { revisions.pendingWaiterCount }
    @Published private(set) var preferencesError: String?

    init(preferencesStore: LinkPreferencesStore = LinkPreferencesStore(), storeRoot: URL? = nil,
         revisionNetwork:(() -> URLSession)? = nil,
         endpoint:URL = URL(string:"https://takupoke-api.n624.jp/links")!) {
        self.preferencesStore = preferencesStore
        self.storeRoot = storeRoot
        self.revisionNetwork = revisionNetwork ?? { Self.networkSession() }
        self.endpoint = endpoint
    }
    private let endpoint: URL

    private var installation: DistributedRevisionConfirmation.Installation? {
        saved.map { .init(revision: $0.revision, acquiredAt: $0.checkedAt) }
    }

    private func recordConfirmation(_ confirmation: DistributedRevisionConfirmation) {
        revisionConfirmation = confirmation
        confirmation.save(beside: store?.file)
    }

    var visibleFavorites: [LinkItem] {
        (saved?.payload.categories ?? []).flatMap(\.buttons)
            .filter { $0.visible && !isHidden($0.id) && isFavorite($0.id) }
    }

    var visibleRecommendations: [LinkItem] {
        saved?.payload.recommendations(hiddenIDs: preferences.hiddenIDs) ?? []
    }

    func search(normalizedQuery: String, revision: UUID, excluding hidden: Set<String>) async -> [LinkSearch.Hit]? {
        guard revision == searchRevision, let saved, !normalizedQuery.isEmpty, !Task.isCancelled else { return nil }
        if searchPreparation == nil {
            let categories = saved.payload.categories
            searchPreparation = Task.detached(priority:.userInitiated) { try LinkSearch.Index(categories:categories) }
        }
        guard let index = try? await searchPreparation?.value, revision == searchRevision, !Task.isCancelled else { return nil }
        let task = Task.detached(priority:.userInitiated) {
            try index.search(normalizedQuery:normalizedQuery,excluding:hidden)
        }
        return await withTaskCancellationHandler {
            guard let results = try? await task.value, revision == searchRevision, !Task.isCancelled else { return nil }
            return results
        } onCancel: { task.cancel() }
    }

    func loadIfNeeded() {
        guard !ready else {
            if !preferencesReady { reloadPreferences() }
            return
        }
        do {
            let base = try storeRoot ?? FileManager.default.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask, appropriateFor: nil, create: true)
            let opened = try LinksStore(root: base.appendingPathComponent("LinksAPI", isDirectory: true))
            store = opened
            do {
                saved = try opened.load()
                if let installation {
                    revisionConfirmation = .load(beside: opened.file, installation: installation)
                    updateAvailable = revisionConfirmation?.hasNewerRevision == true
                }
            }
            catch {
                failed = true
                storedReadWarning = "保存済みの一覧を読み込めませんでした。更新を試してください。"
                message = storedReadWarning
            }
            reloadPreferences()
            ready = true
        } catch {
            failed = true
            message = "一覧の保存先を開けませんでした。再試行してください。"
        }
    }

    func reloadPreferences() {
        do {
            preferences = try preferencesStore.load()
            preferencesReady = true
            preferencesError = nil
        } catch {
            preferencesReady = false
            preferencesError = "一覧の設定を読み込めませんでした。保存済みの設定は変更していません。"
        }
    }

    func refresh(force: Bool = false) async {
        guard !Task.isCancelled else { return }
        loadIfNeeded()
        guard ready else { return }
        let operation = generation
        do {
            _ = try await revision(force:force)
        } catch {
            guard operation == generation, !Task.isCancelled else { return }
            report(error)
        }
    }

    func revision(force:Bool = true) async throws -> MappingRevisionResult {
        loadIfNeeded()
        guard ready else { throw LinksError.storage }
        let operation = generation
        let inspected = installation
        let installed = saved?.revision
        return try await revisions.value(installed:installed,force:force) { [self] in
            guard operation == generation else { throw CancellationError() }
            let network = revisionNetwork()
            let owner = UUID(); revisionBusyOwner = owner
            busy = true
            defer {
                network.invalidateAndCancel()
                if operation == generation, revisionBusyOwner == owner { revisionBusyOwner = nil; busy = false }
            }
            let result: MappingRevisionResult
            do {
                result = try await MappingService(baseURL:endpoint.deletingLastPathComponent(),network:network)
                    .checkRevision(installed:installed,path:"links-revision")
                try Task.checkCancellation()
                guard operation == generation, installation == inspected else { throw CancellationError() }
            } catch {
                guard !Task.isCancelled, !(error is CancellationError),
                      operation == generation, installation == inspected else { throw CancellationError() }
                if let inspected { recordConfirmation(.init(failed: inspected, previous: revisionConfirmation, at: Date())) }
                throw error
            }
            if let inspected { recordConfirmation(.init(installation: inspected, result: result, at: Date())) }
            updateAvailable = result != .unchanged
            failed = storedReadWarning != nil
            message = storedReadWarning ?? (updateAvailable
                ? (saved == nil ? "認証して一覧を取得してください。学内ネットワークではMicrosoft認証を省略できます。" : "一覧に更新があります。")
                : "一覧は最新です。")
            return result
        }
    }

    func download(token: String, revision: String, network: URLSession) async throws {
        guard let store else { throw LinksError.storage }
        let operation = generation
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, rawResponse) = try await network.data(for: request)
        try Task.checkCancellation()
        guard operation == generation else { throw CancellationError() }
        guard let response = rawResponse as? HTTPURLResponse,
              response.expectedContentLength <= LinksPayload.maximumBytes,
              data.count <= LinksPayload.maximumBytes else { throw LinksError.unavailable }
        if response.statusCode == 401 || response.statusCode == 403 { throw MappingError.authentication }
        guard response.statusCode == 200 else { throw LinksError.unavailable }
        guard let receivedRevision = response.value(forHTTPHeaderField: "X-Links-Revision"),
              MappingPackage.validRevision(receivedRevision) else { throw LinksError.invalidResponse }
        guard receivedRevision == revision else { throw MappingError.changedDuringDownload }
        var replacement = try LinksResponse.decode(status: response.statusCode, data: data,
            receivedETag: response.value(forHTTPHeaderField: "ETag"), saved: nil)
        replacement.revision = revision
        do { try store.save(replacement) } catch { throw LinksError.storage }
        revisions.reset()
        storedReadWarning = nil
        saved = replacement; updateAvailable = false; failed = false
        if let installation { recordConfirmation(.init(adopted: installation, at: replacement.checkedAt)) }
        message = "一覧を更新しました。"
    }

    func report(_ error: Error) {
        guard !(error is CancellationError) else { return }
        failed = true
        let description: String
        if let failure = (error as? MappingError)?.authenticationFailureDescription {
            description = failure
        } else if case MappingError.changedDuringDownload = error {
            description = "取得中に一覧が更新されました。もう一度お試しください。"
        } else {
            description = (error as? LinksError ?? .unavailable).localizedDescription
        }
        let warning = storedReadWarning.map { $0 + "\n" } ?? ""
        message = warning + description + (saved == nil ? "" : " 保存済みの一覧を表示しています。")
    }

    func resetForRetention() {
        generation = UUID()
        revisions.reset()
        revisionBusyOwner = nil
        storedReadWarning = nil
        saved = nil; store = nil; ready = false; busy = false
        revisionConfirmation = nil
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
    func color(for item: LinkItem) -> String {
        guard let color = preferences.colorOverrides[item.id], LinksPayload.colors.contains(color) else { return item.color }
        return color
    }

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
            preferencesError = nil
        } catch {
            preferencesError = "一覧の設定を保存できませんでした。保存済みの設定は変更していません。"
        }
    }
}
