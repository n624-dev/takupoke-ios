import Foundation
import SwiftUI

@MainActor
final class SchoolEventsModel: ObservableObject {
    @Published private(set) var saved: [Int: SavedSchoolEvents] = [:]
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var failed = false
    @Published private(set) var message: String?
    @Published private(set) var sourceCheckMessage: String?

    private var store: SchoolEventsStore?
    private var task: Task<Void, Never>?
    private var checkedSourceAtStartup = false

    func checkSourceAtStartup() {
        loadIfNeeded()
        guard ready, !checkedSourceAtStartup else { return }
        checkedSourceAtStartup = true
        guard let saved = saved[2026] else { return }
        guard let expected = saved.payload.sourcePdfETag else {
            sourceCheckMessage = "保存済み行事予定には元PDFのETagがありません。APIから取得し直すと起動時の更新確認ができます。"
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 15
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            do {
                var request = URLRequest(url: WebPDFDownloader.eventsURL)
                request.httpMethod = "HEAD"
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                let (_, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                      let current = response.value(forHTTPHeaderField: "ETag") else {
                    throw SchoolEventsError.unavailable
                }
                self.sourceCheckMessage = current == expected ? nil :
                    "学校サイトの行事予定PDFがAPIの元資料から更新された可能性があります。APIの更新を確認してください。保存済み行事は表示しています。"
            } catch {
                self.sourceCheckMessage = "学校サイトの行事予定PDFを確認できませんでした。保存済み行事は表示しています。"
            }
        }
    }

    var analysis: PDFAnalysis? {
        guard !saved.isEmpty else { return nil }
        let values = saved.values.sorted { $0.payload.schoolYear < $1.payload.schoolYear }
        return PDFAnalysis(version: PDFAnalysis.currentVersion(for: .events), kind: .events,
                           sourceDigest: values.map(\.payload.sourcePdfSha256).joined(separator: ":"),
                           sourceName: "行事予定API", parsedAt: values.map(\.fetchedAt).max() ?? Date(),
                           schoolYear: values[0].payload.schoolYear, term: nil, lessons: [],
                           events: values.flatMap { $0.payload.projectedEvents }, notices: [])
    }

    func loadIfNeeded() {
        guard !ready else { return }
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask, appropriateFor: nil, create: true)
            let opened = try SchoolEventsStore(root: base.appendingPathComponent("SchoolEventsAPI", isDirectory: true))
            saved = try opened.loadAll()
            store = opened
            ready = true
        } catch {
            failed = true
            message = "保存済みの行事予定を読み取れません。端末内の結果は削除していません。"
        }
    }

    func fetch(year: Int) {
        loadIfNeeded()
        guard ready, !busy, (1900...9998).contains(year) else { return }
        busy = true
        failed = false
        message = nil
        task = Task { [weak self] in
            guard let self else { return }
            await self.fetchTask(year: year)
        }
    }

    func cancel() { task?.cancel() }

    private func fetchTask(year: Int) async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
            busy = false
            task = nil
        }
        do {
            var components = URLComponents(string: "https://takupoke-api.n624.jp/events")!
            components.queryItems = [URLQueryItem(name: "schoolYear", value: String(year))]
            var request = URLRequest(url: components.url!)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else { throw SchoolEventsError.unavailable }
            if response.statusCode == 404 { throw SchoolEventsError.unsupportedYear }
            guard response.statusCode == 200,
                  response.expectedContentLength <= 1_000_000,
                  data.count <= 1_000_000 else { throw SchoolEventsError.unavailable }
            let payload = try SchoolEventsPayload.decode(data, requestedYear: year)
            guard let store else { throw SchoolEventsError.unavailable }
            let fetchedAt = Date()
            try store.save(payload, fetchedAt: fetchedAt)
            saved[year] = SavedSchoolEvents(fetchedAt: fetchedAt, payload: payload)
            sourceCheckMessage = nil
            message = "\(year)年度の行事予定を取得しました。元PDFの更新確認は次回起動時に行います。"
        } catch {
            failed = true
            message = Task.isCancelled ? SchoolEventsError.cancelled.localizedDescription :
                (error as? SchoolEventsError)?.localizedDescription ?? SchoolEventsError.unavailable.localizedDescription
        }
    }
}
