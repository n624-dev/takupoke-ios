import Foundation

enum SchoolEventsError: LocalizedError {
    case invalidResponse, unavailable, unsupportedYear, cancelled

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "行事予定APIの内容を確認できません。保存済みの結果は保持しています。"
        case .unavailable: return "行事予定APIに接続できません。通信状態を確認して再試行してください。保存済みの結果は保持しています。"
        case .unsupportedYear: return "この年度の行事予定はAPIでまだ公開されていません。"
        case .cancelled: return "行事予定の取得を中止しました。保存済みの結果は保持しています。"
        }
    }
}

struct SchoolEventsPayload: Codable, Equatable {
    struct Event: Codable, Equatable {
        let startDate: String
        let endDate: String
        let title: String
        let tag: String
    }

    let version: String
    let schoolYear: Int
    let sourcePdfSha256: String
    let sourcePdfETag: String?
    let events: [Event]

    static let supportedTags: Set<String> = [
        "授業なし", "曜日振替", "補講日", "行事（授業なし）", "行事（授業あり）",
        "行事", "行事（時間割変更）", "テスト", "テスト返却", "行事メモ"
    ]

    static func decode(_ data: Data, requestedYear: Int) throws -> Self {
        guard data.count <= 1_000_000, let payload = try? JSONDecoder().decode(Self.self, from: data),
              payload.isValid(for: requestedYear) else { throw SchoolEventsError.invalidResponse }
        return payload
    }

    private func isValid(for requestedYear: Int) -> Bool {
        guard version == "v1", schoolYear == requestedYear, (1900...9998).contains(schoolYear),
              sourcePdfSha256.utf8.count == 64,
              sourcePdfSha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              sourcePdfETag == nil || Self.validETag(sourcePdfETag!),
              !events.isEmpty, events.count <= 2_000,
              let startOfYear = SchoolDate(year: schoolYear, month: 4, day: 1),
              let endOfYear = SchoolDate(year: schoolYear + 1, month: 3, day: 31) else { return false }
        return events.allSatisfy { event in
            guard let start = SchoolDate(iso8601: event.startDate),
                  let end = SchoolDate(iso8601: event.endDate),
                  startOfYear <= start, start <= end, end <= endOfYear,
                  !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  event.title.count <= 200, Self.supportedTags.contains(event.tag) else { return false }
            if event.tag == "曜日振替" { return Self.overrideDay(event.title) != nil }
            return true
        }
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
                                  periodEvidence: item.endDate == item.startDate ? nil : "行事予定API",
                                  classification: classification, apiTag: item.tag)
        }
    }
}

struct SavedSchoolEvents: Codable {
    let fetchedAt: Date
    let payload: SchoolEventsPayload
    let apiETag: String?
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

final class SchoolEventsStore {
    private let root: URL

    init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        #if os(iOS) || os(macOS)
        var directory = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        #endif
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: root.path)
        #endif
    }

    func loadAll() throws -> [Int: SavedSchoolEvents] {
        let files = try FileManager.default.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        var saved: [Int: SavedSchoolEvents] = [:]
        for file in files {
            guard file.lastPathComponent.hasPrefix("events-"), file.pathExtension == "json",
                  let year = Int(file.deletingPathExtension().lastPathComponent.dropFirst(7)),
                  (1900...9998).contains(year) else { continue }
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true,
                  let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= 1_000_000 else { throw SchoolEventsError.invalidResponse }
            let value = try JSONDecoder().decode(SavedSchoolEvents.self, from: Data(contentsOf: file))
            let verified = try SchoolEventsPayload.decode(JSONEncoder().encode(value.payload), requestedYear: year)
            saved[year] = SavedSchoolEvents(fetchedAt: value.fetchedAt, payload: verified,
                                            apiETag: value.apiETag.flatMap {
                                                SchoolEventsResponse.validETag($0) ? $0 : nil
                                            })
        }
        return saved
    }

    func save(_ payload: SchoolEventsPayload, apiETag: String? = nil, fetchedAt: Date = Date()) throws {
        let checked = try SchoolEventsPayload.decode(JSONEncoder().encode(payload), requestedYear: payload.schoolYear)
        guard apiETag == nil || SchoolEventsResponse.validETag(apiETag!) else {
            throw SchoolEventsError.invalidResponse
        }
        let url = root.appendingPathComponent("events-\(checked.schoolYear).json")
        try JSONEncoder().encode(SavedSchoolEvents(fetchedAt: fetchedAt, payload: checked, apiETag: apiETag))
            .write(to: url, options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
    }
}
