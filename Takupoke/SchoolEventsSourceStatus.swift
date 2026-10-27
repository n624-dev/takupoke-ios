import Foundation

/// Advisory metadata only. Neither the observed hash nor this response can
/// replace an adopted events payload.
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

    static func isHash(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    static func isDataVersion(_ value: String) -> Bool {
        value.hasPrefix("sha256-") && isHash(String(value.dropFirst(7)))
    }

    static func date(_ value: String?) -> Date? {
        guard let value, value.utf8.count <= 40 else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    static func decode(_ data: Data, year: Int) throws -> Self {
        guard data.count <= 16_384, let result = try? JSONDecoder().decode(Self.self, from: data),
              result.isValid(year: year) else { throw SchoolEventsError.invalidResponse }
        return result
    }

    func isValid(year: Int) -> Bool {
        guard version == "v1", schoolYear == year, (1900...9998).contains(year),
              Self.isDataVersion(dataVersion), Self.isHash(adoptedSourcePdfSha256),
              [lastSuccessAt, lastAttemptAt, nextAttemptAt].allSatisfy({ $0 == nil || Self.date($0) != nil }),
              (lastSuccessfulStatus == nil) == (lastSuccessAt == nil),
              lastSuccessfulStatus == nil || lastSuccessfulStatus == .matched || lastSuccessfulStatus == .source_differs else { return false }
        if status == .matched || status == .source_differs {
            return lastSuccessfulStatus == status && lastSuccessAt != nil
        }
        return true
    }

    func matches(_ saved: SavedSchoolEvents) -> Bool {
        schoolYear == saved.payload.schoolYear && adoptedSourcePdfSha256 == saved.payload.sourcePdfSha256 &&
            dataVersion == saved.dataVersion
    }
}

struct SchoolEventsSourceTarget: Codable, Equatable {
    let year: Int
    let hash: String
    let version: String?
    init(_ saved: SavedSchoolEvents) {
        year = saved.payload.schoolYear; hash = saved.payload.sourcePdfSha256; version = saved.dataVersion
    }
}

struct SavedSchoolEventsSourceStatus: Codable, Equatable {
    let receivedAt: Date
    let response: SchoolEventsSourceStatus
    let previousSuccess: SchoolEventsSourceStatus?
    let requestedTarget: SchoolEventsSourceTarget?

    init(receivedAt: Date, response: SchoolEventsSourceStatus,
         requestedTarget: SchoolEventsSourceTarget? = nil, previous: Self? = nil) {
        self.receivedAt = receivedAt; self.response = response
        self.requestedTarget = requestedTarget
        let candidate = previous?.successfulResponse
        if let candidate, candidate.schoolYear == response.schoolYear,
           candidate.adoptedSourcePdfSha256 == response.adoptedSourcePdfSha256,
           candidate.dataVersion == response.dataVersion,
           let oldDate = SchoolEventsSourceStatus.date(candidate.lastSuccessAt),
           SchoolEventsSourceStatus.date(response.lastSuccessAt).map({ $0 < oldDate }) ?? true {
            previousSuccess = candidate
        } else { previousSuccess = nil }
    }

    var successfulResponse: SchoolEventsSourceStatus? {
        previousSuccess ?? (response.lastSuccessAt == nil ? nil : response)
    }

    func isValid(year: Int) -> Bool {
        guard response.isValid(year: year), receivedAt.timeIntervalSince1970.isFinite,
              requestedTarget.map({ $0.year == year && SchoolEventsSourceStatus.isHash($0.hash) &&
                  ($0.version == nil || SchoolEventsSourceStatus.isDataVersion($0.version!)) }) ?? true else { return false }
        guard let previousSuccess else { return true }
        return previousSuccess.isValid(year: year) && previousSuccess.lastSuccessAt != nil &&
            previousSuccess.adoptedSourcePdfSha256 == response.adoptedSourcePdfSha256 &&
            previousSuccess.dataVersion == response.dataVersion
    }

    func isFresh(at now: Date) -> Bool {
        let age = now.timeIntervalSince(receivedAt)
        return age >= 0 && age < (response.checking ? 60 : 12 * 60 * 60)
    }

    var presentationDeadlines: [Date] {
        var dates = [receivedAt.addingTimeInterval(response.checking ? 60 : 12 * 60 * 60)]
        if let success = SchoolEventsSourceStatus.date(successfulResponse?.lastSuccessAt) {
            dates.append(success.addingTimeInterval(24 * 60 * 60))
        }
        return dates
    }

    func canReuse(for saved: SavedSchoolEvents, at now: Date) -> Bool {
        isFresh(at: now) && (response.matches(saved) || requestedTarget == SchoolEventsSourceTarget(saved))
    }
}

struct SchoolEventsSourcePresentation {
    let message: String
    let warning: Bool
    let lastSuccessfulMessage: String?
    let lastSuccessAt: Date?
    let receivedAt: Date?

    static func make(saved: SavedSchoolEvents, cached: SavedSchoolEventsSourceStatus?,
                     error: String?, now: Date) -> Self {
        guard let cached else {
            return .init(message: error ?? "元PDFの更新状況は未確認です。", warning: true,
                         lastSuccessfulMessage: nil, lastSuccessAt: nil, receivedAt: nil)
        }
        let value = cached.response
        guard value.matches(saved) else {
            return .init(message: "現在のAPIと保存済み行事の年度・元PDF・配信版が一致しないため、更新状況は未確認です。学校行事を更新してください。",
                         warning: true, lastSuccessfulMessage: nil, lastSuccessAt: nil, receivedAt: cached.receivedAt)
        }
        let successful = cached.successfulResponse
        let success = SchoolEventsSourceStatus.date(successful?.lastSuccessAt)
        let successAge = success.map { now.timeIntervalSince($0) }
        let old = value.stale || !cached.isFresh(at: now) || successAge.map { $0 < 0 || $0 >= 24 * 60 * 60 } == true
        let message: String
        if let error { message = error }
        else if value.checking {
            message = cached.isFresh(at: now)
                ? "APIが元PDFを確認中です。前回の確認結果を表示しています。"
                : "前回確認時は元PDFを確認中でした。現在の更新状況は未確認です。"
        }
        else if value.status == .unavailable { message = "APIで元PDFの更新状況を確認できませんでした。" }
        else if value.status == .unknown { message = "元PDFの更新状況は未確認です。" }
        else if cached.previousSuccess != nil { message = "APIから以前の確認結果が返りました。新しい成功結果を保持しています。現在の更新状況は未確認です。" }
        else if old { message = "元PDFの確認結果は古くなっています。現在の更新状況は未確認です。" }
        else { message = description(value.status) }
        return .init(message: message,
                     warning: error != nil || old || value.checking || cached.previousSuccess != nil || value.status != .matched,
                     lastSuccessfulMessage: successful?.lastSuccessfulStatus.map(description),
                     lastSuccessAt: success, receivedAt: cached.receivedAt)
    }

    private static func description(_ status: SchoolEventsSourceStatus.Status) -> String {
        switch status {
        case .matched: return "元PDFの本文は登録元と一致しています。"
        case .source_differs: return "元PDFの本文に差異があります。行事内容は確認待ちです。保存済みの行事を表示しています。"
        case .unavailable: return "更新状況を確認できません。"
        case .unknown: return "未確認です。"
        }
    }
}
