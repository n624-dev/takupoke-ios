import Foundation

enum SchoolEventsError: LocalizedError {
    case invalidResponse, unavailable, unsupportedYear, cancelled

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "学校行事APIの内容を確認できません。保存済みの結果は保持しています。"
        case .unavailable: return "学校行事APIに接続できません。通信状態を確認して再試行してください。保存済みの結果は保持しています。"
        case .unsupportedYear: return "この年度の学校行事はAPIでまだ公開されていません。"
        case .cancelled: return "学校行事の取得を中止しました。保存済みの結果は保持しています。"
        }
    }
}

enum SchoolEventsFormat: String, Codable {
    case v1, v2
}

struct SchoolEventsPayload: Codable, Equatable {
    struct Event: Codable, Equatable {
        let startDate: String
        let endDate: String
        let title: String
        let tag: String
    }

    struct Range: Codable, Equatable {
        let startDate: String
        let endDate: String
    }

    struct IdentifiedEvent: Codable, Equatable, Identifiable {
        let eventId: String
        let title: String
        let tag: String
        let ranges: [Range]

        var id: String { eventId }
    }

    let version: String
    let schoolYear: Int
    let sourcePdfSha256: String
    let sourcePdfETag: String?
    private let legacyEvents: [Event]?
    let identifiedEvents: [IdentifiedEvent]?
    var format: SchoolEventsFormat? { SchoolEventsFormat(rawValue: version) }
    var events: [Event] {
        legacyEvents ?? identifiedEvents?.flatMap { event in
            event.ranges.map { Event(startDate: $0.startDate, endDate: $0.endDate, title: event.title, tag: event.tag) }
        } ?? []
    }

    init(version: String, schoolYear: Int, sourcePdfSha256: String, sourcePdfETag: String?, events: [Event]) {
        self.version = version; self.schoolYear = schoolYear
        self.sourcePdfSha256 = sourcePdfSha256; self.sourcePdfETag = sourcePdfETag
        legacyEvents = events; identifiedEvents = nil
    }

    init(schoolYear: Int, sourcePdfSha256: String, sourcePdfETag: String?, identifiedEvents: [IdentifiedEvent]) {
        version = SchoolEventsFormat.v2.rawValue; self.schoolYear = schoolYear
        self.sourcePdfSha256 = sourcePdfSha256; self.sourcePdfETag = sourcePdfETag
        legacyEvents = nil; self.identifiedEvents = identifiedEvents
    }

    private enum CodingKeys: String, CodingKey { case version, schoolYear, sourcePdfSha256, sourcePdfETag, events }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(String.self, forKey: .version)
        schoolYear = try values.decode(Int.self, forKey: .schoolYear)
        sourcePdfSha256 = try values.decode(String.self, forKey: .sourcePdfSha256)
        sourcePdfETag = try values.decodeIfPresent(String.self, forKey: .sourcePdfETag)
        if version == SchoolEventsFormat.v2.rawValue {
            identifiedEvents = try values.decode([IdentifiedEvent].self, forKey: .events)
            legacyEvents = nil
        } else {
            legacyEvents = try values.decode([Event].self, forKey: .events)
            identifiedEvents = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(version, forKey: .version)
        try values.encode(schoolYear, forKey: .schoolYear)
        try values.encode(sourcePdfSha256, forKey: .sourcePdfSha256)
        try values.encodeIfPresent(sourcePdfETag, forKey: .sourcePdfETag)
        if let identifiedEvents { try values.encode(identifiedEvents, forKey: .events) }
        else { try values.encode(legacyEvents ?? [], forKey: .events) }
    }

    static let supportedTags: Set<String> = [
        "授業なし", "曜日振替", "補講日", "行事（授業なし）", "行事（授業あり）",
        "行事", "行事（時間割変更）", "テスト", "テスト返却", "行事メモ"
    ]

    static func decode(_ data: Data, requestedYear: Int, requestedFormat: SchoolEventsFormat? = nil) throws -> Self {
        guard data.count <= 1_000_000, let payload = try? JSONDecoder().decode(Self.self, from: data),
              requestedFormat == nil || payload.format == requestedFormat,
              payload.isValid(for: requestedYear) else { throw SchoolEventsError.invalidResponse }
        return payload
    }

    private func isValid(for requestedYear: Int) -> Bool {
        guard let format, schoolYear == requestedYear, (1900...9998).contains(schoolYear),
              sourcePdfSha256.utf8.count == 64,
              sourcePdfSha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              sourcePdfETag == nil || Self.validETag(sourcePdfETag!),
              let startOfYear = SchoolDate(year: schoolYear, month: 4, day: 1),
              let endOfYear = SchoolDate(year: schoolYear + 1, month: 3, day: 31) else { return false }
        if format == .v1 {
            guard let legacyEvents, !legacyEvents.isEmpty, legacyEvents.count <= 2_000 else { return false }
        } else {
            guard let identifiedEvents, identifiedEvents.count <= 2_000 else { return false }
            var ids = Set<String>(), rangeCount = 0
            for event in identifiedEvents {
                guard Self.validEventID(event.eventId), ids.insert(event.eventId).inserted,
                      Self.validTitle(event.title, tag: event.tag), !event.ranges.isEmpty else { return false }
                rangeCount += event.ranges.count
                guard rangeCount <= 2_000 else { return false }
                for (previous, next) in zip(event.ranges, event.ranges.dropFirst()) {
                    guard previous.endDate < next.startDate else { return false }
                }
            }
        }
        return events.allSatisfy { event in
            guard let start = SchoolDate(iso8601: event.startDate),
                  let end = SchoolDate(iso8601: event.endDate),
                  startOfYear <= start, start <= end, end <= endOfYear,
                  Self.validTitle(event.title, tag: event.tag) else { return false }
            return true
        }
    }

    private static func validTitle(_ title: String, tag: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 200
            && supportedTags.contains(tag) && (tag != "曜日振替" || overrideDay(title) != nil)
    }

    static func validEventID(_ id: String) -> Bool {
        func alphanumeric(_ byte: UInt8) -> Bool {
            (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
        }
        let bytes = id.utf8
        guard bytes.count <= 128, let first = bytes.first, alphanumeric(first) else { return false }
        return bytes.allSatisfy { alphanumeric($0) || [45, 46, 95].contains($0) }
    }

    private static func validETag(_ value: String) -> Bool {
        value.count >= 3 && value.count <= 256 && value.first == "\"" && value.last == "\"" &&
            !value.dropFirst().dropLast().contains(where: { $0 == "\"" || $0 == "\r" || $0 == "\n" })
    }

    private static func overrideDay(_ title: String) -> Int? {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let days: [Character: Int] = ["月": 1, "火": 2, "水": 3, "木": 4, "金": 5]
        guard value.count == 5, value.hasSuffix("曜日授業"), let first = value.first else { return nil }
        return days[first]
    }

    var projectedEvents: [PDFSchoolEvent] {
        events.map { item in
            let classification: PDFEventClassification
            switch item.tag {
            case "授業なし": classification = .init(type: .noClass)
            case "行事（授業なし）": classification = .init(type: .schoolEventNoClass)
            case "補講日": classification = .init(type: .supplementary)
            case "曜日振替": classification = .init(type: .weekdayOverride,
                                                scheduleDay: Self.overrideDay(item.title))
            default: classification = .init(type: .special)
            }
            return PDFSchoolEvent(date: item.startDate, scope: "全クラス", title: item.title, page: 0,
                                  endDate: item.endDate == item.startDate ? nil : item.endDate,
                                  periodEvidence: item.endDate == item.startDate ? nil : "学校行事API",
                                  classification: classification, apiTag: item.tag)
        }
    }
}

struct SavedSchoolEvents: Codable {
    let fetchedAt: Date
    let payload: SchoolEventsPayload
    let apiETag: String?
    let responseDataVersion: String?
    let lastEventsCheckedAt: Date?

    init(fetchedAt: Date, payload: SchoolEventsPayload, apiETag: String?, responseDataVersion: String? = nil,
         lastEventsCheckedAt: Date? = nil) {
        self.fetchedAt = fetchedAt; self.payload = payload; self.apiETag = apiETag
        self.responseDataVersion = responseDataVersion; self.lastEventsCheckedAt = lastEventsCheckedAt
    }

    private enum CodingKeys: String, CodingKey { case fetchedAt, payload, apiETag, responseDataVersion, lastEventsCheckedAt }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        fetchedAt = try values.decode(Date.self, forKey: .fetchedAt)
        payload = try values.decode(SchoolEventsPayload.self, forKey: .payload)
        apiETag = try values.decodeIfPresent(String.self, forKey: .apiETag)
        responseDataVersion = try values.decodeIfPresent(String.self, forKey: .responseDataVersion)
        lastEventsCheckedAt = try? values.decode(Date.self, forKey: .lastEventsCheckedAt)
    }

    /// The published API contract binds dataVersion to the events JSON hash,
    /// also carried inside its weak ETag. Legacy arbitrary validators do not
    /// identify a data version; never substitute the source PDF's hash.
    var dataVersion: String? {
        if let responseDataVersion, SchoolEventsSourceStatus.isDataVersion(responseDataVersion) { return responseDataVersion }
        guard let apiETag, SchoolEventsResponse.validETag(apiETag) else { return nil }
        let tag = apiETag.hasPrefix("W/") ? String(apiETag.dropFirst(2)) : apiETag
        let hash = String(tag.dropFirst().dropLast())
        return SchoolEventsSourceStatus.isHash(hash) ? "sha256-" + hash : nil
    }
}

enum SchoolEventsResponse {
    private static func opaqueTag(_ value: String) -> Substring {
        value.hasPrefix("W/") ? value.dropFirst(2) : value[...]
    }

    static func validETag(_ value: String) -> Bool {
        let tag = value.hasPrefix("W/\"") ? String(value.dropFirst(2)) : value
        return tag.utf8.count >= 3 && tag.utf8.count <= 256 && tag.first == "\"" && tag.last == "\"" &&
            tag.utf8.dropFirst().dropLast().allSatisfy { (32...126).contains($0) && $0 != 34 }
    }

    static func isNotModified(status: Int, data: Data, sentETag: String?, receivedETag: String?,
                              hasSavedResult: Bool) throws -> Bool {
        guard status == 304 else { return false }
        guard data.isEmpty, hasSavedResult,
              let sentETag, validETag(sentETag),
              let receivedETag, validETag(receivedETag),
              opaqueTag(sentETag) == opaqueTag(receivedETag) else {
            throw SchoolEventsError.invalidResponse
        }
        return true
    }
}
