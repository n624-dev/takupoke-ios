import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct SchoolEventsSourceStatus: Codable, Equatable {
    enum Status: String, Codable { case matched, source_differs, unavailable, unknown }
    let version: String
    let schoolYear: Int
    let dataVersion: String
    let adoptedSourcePdfSha256: String
    let status: Status
    let lastSuccessfulStatus: Status?
    let lastSuccessAt: String?
    let lastAttemptAt: String?
    let nextAttemptAt: String?
    let checking: Bool
    let stale: Bool

    static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    static func decode(_ data: Data, year: Int) throws -> Self {
        guard data.count <= 8_192, let value = try? JSONDecoder().decode(Self.self, from: data),
              value.version == "v1", value.schoolYear == year,
              value.dataVersion.hasPrefix("sha256-"), validHash(String(value.dataVersion.dropFirst(7))),
              validHash(value.adoptedSourcePdfSha256),
              [value.lastSuccessAt, value.lastAttemptAt, value.nextAttemptAt].allSatisfy({ $0 == nil || date($0) != nil }),
              value.lastSuccessfulStatus == nil || [.matched, .source_differs].contains(value.lastSuccessfulStatus!),
              (value.lastSuccessAt == nil) == (value.lastSuccessfulStatus == nil),
              ![.matched, .source_differs].contains(value.status) ||
                (value.lastSuccessAt != nil && value.lastSuccessfulStatus == value.status) else {
            throw SchoolEventsError.invalidResponse
        }
        return value
    }

    private static func validHash(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    func applies(to saved: SavedSchoolEvents) -> Bool {
        guard schoolYear == saved.payload.schoolYear, adoptedSourcePdfSha256 == saved.payload.sourcePdfSha256,
              let etag = saved.apiETag else { return false }
        let opaque = etag.hasPrefix("W/") ? String(etag.dropFirst(2)) : etag
        return opaque == "\"\(dataVersion.dropFirst(7))\""
    }

    func message(for saved: SavedSchoolEvents, now: Date, networkFailed: Bool = false) -> String {
        guard applies(to: saved) else {
            return "元PDFの確認結果は保存済み行事と異なる配信版です。学校行事を更新して再確認してください。"
        }
        var parts: [String] = []
        switch status {
        case .matched: parts.append("元PDFの本文は登録元と一致しています。")
        case .source_differs: parts.append("元PDFの本文に差異があります。内容確認待ちです。保存済みの学校行事を表示しています。")
        case .unavailable: parts.append("元PDFの更新状況を確認できませんでした。保存済みの学校行事を表示しています。")
        case .unknown: parts.append("元PDFの更新状況は未確認です。")
        }
        if let date = Self.date(lastSuccessAt) {
            if status == .unavailable, let previous = lastSuccessfulStatus {
                parts.append(previous == .matched ? "前回は登録元と一致していました。" : "前回は元PDFに差異がありました。")
            }
            parts.append("最終成功確認: \(date.formatted(JapaneseDateDisplay.timestamp))（日本時間）。")
            if stale || now.timeIntervalSince(date) >= 24 * 60 * 60 { parts.append("確認結果は古くなっています。") }
        }
        if checking { parts.append("サーバーで確認中です。") }
        if networkFailed { parts.append("状態APIに接続できません。前回の確認結果を表示しています。") }
        return parts.joined(separator: " ")
    }
}

struct CachedSchoolEventsSourceStatus: Codable {
    let fetchedAt: Date
    let value: SchoolEventsSourceStatus

    func isFresh(for saved: SavedSchoolEvents, now: Date) -> Bool {
        let age = now.timeIntervalSince(fetchedAt)
        // A checking response is briefly cached so the completed observation can be obtained.
        let lifetime: TimeInterval = value.checking ? 60 : 12 * 60 * 60
        return age >= 0 && age < lifetime && value.applies(to: saved)
    }
}

struct SchoolEventsSourceStatusClient {
    static func fetch(year: Int, session: URLSession) async throws -> SchoolEventsSourceStatus {
        var components = URLComponents(string: "https://takupoke-api.n624.jp/events/source-status")!
        components.queryItems = [URLQueryItem(name: "schoolYear", value: String(year))]
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.url?.host == "takupoke-api.n624.jp", data.count <= 8_192,
              response.expectedContentLength <= 8_192 else { throw SchoolEventsError.unavailable }
        return try SchoolEventsSourceStatus.decode(data, year: year)
    }
}

struct SchoolEventsSourceStatusStore {
    let root: URL
    private func file(_ year: Int) -> URL { root.appendingPathComponent("source-status-\(year).json") }

    func load(year: Int) -> CachedSchoolEventsSourceStatus? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file(year).path),
              let size = attributes[.size] as? NSNumber, size.intValue <= 16_384,
              let data = try? Data(contentsOf: file(year)), data.count <= 16_384,
              let cached = try? JSONDecoder().decode(CachedSchoolEventsSourceStatus.self, from: data),
              let encoded = try? JSONEncoder().encode(cached.value),
              (try? SchoolEventsSourceStatus.decode(encoded, year: year)) != nil else { return nil }
        return cached
    }

    func save(_ cached: CachedSchoolEventsSourceStatus) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(cached).write(to: file(cached.value.schoolYear), options: .atomic)
    }
}
