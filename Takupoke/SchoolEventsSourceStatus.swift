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
    // Old status envelopes did not include a format and only represented v1.
    let format: SchoolEventsFormat?
    init(_ saved: SavedSchoolEvents) {
        year = saved.payload.schoolYear; hash = saved.payload.sourcePdfSha256; version = saved.dataVersion
        format = saved.payload.format == .v2 ? .v2 : nil
    }

    func isValid(year: Int) -> Bool {
        self.year == year && (1900...9998).contains(year) && SchoolEventsSourceStatus.isHash(hash) &&
            version.map(SchoolEventsSourceStatus.isDataVersion) != false
    }
}

struct SchoolEventsRetry: Codable, Equatable {
    private(set) var consecutiveFailures = 0
    private(set) var firstFailureAt: Date?
    private(set) var lastAttemptAt: Date?
    private(set) var retryAt: Date?

    mutating func fail(at date: Date) {
        consecutiveFailures = min(consecutiveFailures + 1, 3)
        if firstFailureAt == nil || firstFailureAt! > date { firstFailureAt = date }
        lastAttemptAt = date
        retryAt = date.addingTimeInterval([900, 1800, 3600][consecutiveFailures - 1])
    }

    mutating func adjustClock(at date: Date) {
        guard let lastAttemptAt, lastAttemptAt > date else { return }
        if let retryAt { self.retryAt = date.addingTimeInterval(max(0, retryAt.timeIntervalSince(lastAttemptAt))) }
        if let firstFailureAt, firstFailureAt > date { self.firstFailureAt = date }
        self.lastAttemptAt = date
    }

    var isValid: Bool {
        (0...3).contains(consecutiveFailures) &&
            [firstFailureAt, lastAttemptAt, retryAt].compactMap { $0 }.allSatisfy { $0.timeIntervalSince1970.isFinite }
    }
}

/// The adopted events and observation files can still be read when this
/// separately stored scheduling metadata is missing or damaged.
struct SchoolEventsRefreshState: Codable, Equatable {
    let target: SchoolEventsSourceTarget
    let requestedBodyFormat: SchoolEventsFormat
    var body = SchoolEventsRetry()
    var source = SchoolEventsRetry()
    var followUpAt: Date?
    var followUpsRemaining: Int?
    var deferredReconciliation = false
    var targetMismatch = false
    var differenceCheckedAt: Date?

    func isValid(year: Int) -> Bool {
        target.isValid(year: year) && body.isValid && source.isValid &&
            followUpsRemaining.map { (0...3).contains($0) } != false &&
            [followUpAt, differenceCheckedAt].compactMap { $0 }.allSatisfy { $0.timeIntervalSince1970.isFinite }
    }

    mutating func adjustClock(at date: Date) {
        body.adjustClock(at: date)
        source.adjustClock(at: date)
        if let followUpAt, followUpAt.timeIntervalSince(date) > 60 { self.followUpAt = date.addingTimeInterval(60) }
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
        if let candidate, (previous?.requestedTarget?.format ?? .v1) == (requestedTarget?.format ?? .v1),
           candidate.schoolYear == response.schoolYear,
           candidate.adoptedSourcePdfSha256 == response.adoptedSourcePdfSha256,
           candidate.dataVersion == response.dataVersion,
           let oldDate = SchoolEventsSourceStatus.date(candidate.lastSuccessAt),
           SchoolEventsSourceStatus.date(response.lastSuccessAt).map({ next in
               next < oldDate || (next == oldDate && candidate.lastSuccessfulStatus != response.lastSuccessfulStatus)
           }) ?? true {
            previousSuccess = candidate
        } else { previousSuccess = nil }
    }

    var successfulResponse: SchoolEventsSourceStatus? {
        previousSuccess ?? (response.lastSuccessAt == nil ? nil : response)
    }

    func isValid(year: Int) -> Bool {
        guard response.isValid(year: year), receivedAt.timeIntervalSince1970.isFinite,
              requestedTarget.map({ $0.isValid(year: year) }) ?? true else { return false }
        guard let previousSuccess else { return true }
        return previousSuccess.isValid(year: year) && previousSuccess.lastSuccessAt != nil &&
            previousSuccess.adoptedSourcePdfSha256 == response.adoptedSourcePdfSha256 &&
            previousSuccess.dataVersion == response.dataVersion
    }

    func isFresh(at now: Date) -> Bool {
        let age = now.timeIntervalSince(receivedAt)
        return age >= 0 && age < (response.checking ? 60 : 12 * 60 * 60)
    }

    var nextRegularCheck: Date {
        var dates = [receivedAt.addingTimeInterval(12 * 60 * 60)]
        if let success = SchoolEventsSourceStatus.date(successfulResponse?.lastSuccessAt) {
            dates.append(success.addingTimeInterval(24 * 60 * 60))
        }
        if let next = SchoolEventsSourceStatus.date(response.nextAttemptAt) { dates.append(next) }
        return dates.min() ?? receivedAt
    }

    func matches(_ saved: SavedSchoolEvents) -> Bool {
        (requestedTarget?.format ?? .v1) == saved.payload.format && response.matches(saved)
    }
}

struct SchoolEventsSourcePresentation {
    let message: String
    let warningMessage: String?
    var warning: Bool { warningMessage != nil }
    let lastSuccessfulMessage: String?
    let lastSuccessAt: Date?
    let receivedAt: Date?

    static func make(saved: SavedSchoolEvents, cached: SavedSchoolEventsSourceStatus?,
                     error: String?, now: Date, firstFailureAt: Date? = nil, checking: Bool = false) -> Self {
        let mismatch = cached.map { !$0.matches(saved) } ?? false
        let cached = cached.flatMap { $0.matches(saved) ? $0 : nil }
        let successful = cached?.successfulResponse
        let success = SchoolEventsSourceStatus.date(successful?.lastSuccessAt).flatMap { $0 <= now ? $0 : nil }
        let longUnconfirmed = firstFailureAt != nil && (success ?? firstFailureAt).map {
            now.timeIntervalSince($0) >= 48 * 60 * 60
        } == true
        let warning: String?
        if success != nil, successful?.lastSuccessfulStatus == .source_differs {
            warning = description(.source_differs)
        } else if longUnconfirmed {
            warning = "学校行事の更新確認がしばらくできていません。保存済みの行事を表示しています。"
        } else {
            warning = nil
        }
        guard let cached else {
            let detail = mismatch ? "APIと保存済み行事の配信版が一致しないため、更新状況は未確認です。"
                : checking ? "元PDFの更新状況を確認中です。" : "元PDFの更新状況は未確認です。"
            return .init(message: error ?? detail,
                         warningMessage: warning, lastSuccessfulMessage: nil, lastSuccessAt: nil, receivedAt: nil)
        }
        let value = cached.response
        let old = value.stale || !cached.isFresh(at: now) || success.map { now.timeIntervalSince($0) >= 24 * 60 * 60 } != false
        let message: String
        if let error { message = error }
        else if checking { message = "元PDFの更新状況を確認中です。" }
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
        return .init(message: message, warningMessage: warning,
                     lastSuccessfulMessage: success == nil ? nil : successful?.lastSuccessfulStatus.map(description),
                     lastSuccessAt: success, receivedAt: cached.receivedAt)
    }

    private static func description(_ status: SchoolEventsSourceStatus.Status) -> String {
        switch status {
        case .matched: return "元PDFの本文は登録元と一致しています。"
        case .source_differs: return "学校の元PDFに差異があります。行事内容への影響は確認待ちです。保存済みの行事を表示しています。"
        case .unavailable: return "更新状況を確認できません。"
        case .unknown: return "未確認です。"
        }
    }
}
