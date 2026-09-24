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
    private var checkedAtStartup = false

    func refreshAtStartup() {
        loadIfNeeded()
        guard ready, !checkedAtStartup, !busy else { return }
        checkedAtStartup = true
        let years = saved.keys.sorted()
        guard !years.isEmpty else { return }
        busy = true
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.busy = false; self.task = nil }
            var failures: [Int] = []
            var updated: [Int] = []
            for year in years {
                do {
                    if try await self.fetchOne(year: year) { updated.append(year) }
                } catch {
                    failures.append(year)
                }
            }
            if !Task.isCancelled { await self.checkSourceTask() }
            self.failed = !failures.isEmpty
            if !failures.isEmpty {
                self.message = "\(failures.map(String.init).joined(separator: "、"))年度の学校行事を更新確認できませんでした。保存済みの結果を表示しています。"
            } else if !updated.isEmpty {
                self.message = "\(updated.map(String.init).joined(separator: "、"))年度の学校行事を更新しました。"
            }
        }
    }

    private func checkSourceTask() async {
        guard let expected = saved[2026]?.payload.sourcePdfETag else {
            if saved[2026] != nil {
                sourceCheckMessage = "保存済みの学校行事には元PDFのETagがありません。APIから取得し直すと起動時の更新確認ができます。"
            }
            return
        }
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
            sourceCheckMessage = current == expected ? nil :
                "学校サイトの学校行事PDFがAPIの元PDFから更新された可能性があります。APIの更新を確認してください。保存済みの学校行事は表示しています。"
        } catch {
            sourceCheckMessage = "学校サイトの学校行事PDFを確認できませんでした。保存済みの学校行事は表示しています。"
        }
    }

    var analysis: PDFAnalysis? {
        guard !saved.isEmpty else { return nil }
        let values = saved.values.sorted { $0.payload.schoolYear < $1.payload.schoolYear }
        return PDFAnalysis(version: PDFAnalysis.currentVersion(for: .events), kind: .events,
                           sourceDigest: values.map(\.payload.sourcePdfSha256).joined(separator: ":"),
                           sourceName: "学校行事API", parsedAt: values.map(\.fetchedAt).max() ?? Date(),
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
            message = "保存済みの学校行事を読み取れません。端末内の結果は削除していません。"
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
            do {
                let changed = try await self.fetchOne(year: year)
                self.message = changed ? "\(year)年度の学校行事を取得しました。元PDFの更新確認は次回起動時に行います。" :
                    "\(year)年度の学校行事に更新はありません。"
            } catch {
                self.failed = true
                self.message = Task.isCancelled ? SchoolEventsError.cancelled.localizedDescription :
                    (error as? SchoolEventsError)?.localizedDescription ?? SchoolEventsError.unavailable.localizedDescription
            }
            self.busy = false
            self.task = nil
        }
    }

    func cancel() { task?.cancel() }

    private func fetchOne(year: Int) async throws -> Bool {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var components = URLComponents(string: "https://takupoke-api.n624.jp/events")!
        components.queryItems = [URLQueryItem(name: "schoolYear", value: String(year))]
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let sentETag = saved[year]?.apiETag
        if let sentETag { request.setValue(sentETag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw SchoolEventsError.unavailable }
        let receivedETag = response.value(forHTTPHeaderField: "ETag")
        if try SchoolEventsResponse.isNotModified(status: response.statusCode, data: data,
                                                   sentETag: sentETag, receivedETag: receivedETag,
                                                   hasSavedResult: saved[year] != nil) {
            return false
        }
        if response.statusCode == 404 { throw SchoolEventsError.unsupportedYear }
        guard response.statusCode == 200,
              response.expectedContentLength <= 1_000_000,
              data.count <= 1_000_000 else { throw SchoolEventsError.unavailable }
        guard receivedETag == nil || SchoolEventsResponse.validETag(receivedETag!) else {
            throw SchoolEventsError.invalidResponse
        }
        let payload = try SchoolEventsPayload.decode(data, requestedYear: year)
        guard let store else { throw SchoolEventsError.unavailable }
        let fetchedAt = Date()
        try store.save(payload, apiETag: receivedETag, fetchedAt: fetchedAt)
        saved[year] = SavedSchoolEvents(fetchedAt: fetchedAt, payload: payload, apiETag: receivedETag)
        sourceCheckMessage = nil
        return true
    }
}
