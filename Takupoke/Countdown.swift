import Foundation

struct CountdownRange: Codable, Equatable {
    let start: SchoolDate
    let end: SchoolDate

    var valid: Bool { start.isValidCalendarDay && end.isValidCalendarDay && start <= end }
    var label: String { start == end ? start.iso8601 : "\(start.iso8601)〜\(end.iso8601)" }
}

struct CountdownDates: Codable, Equatable {
    let title: String
    let ranges: [CountdownRange]

    var start: SchoolDate { ranges[0].start }
    var end: SchoolDate { ranges[ranges.count - 1].end }

    var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.utf8.count <= 4096 &&
            !ranges.isEmpty && ranges.allSatisfy(\.valid) &&
            zip(ranges, ranges.dropFirst()).allSatisfy { $0.end < $1.start }
    }

    init(title: String, ranges: [CountdownRange]) {
        self.title = title
        self.ranges = ranges
    }

    init?(_ event: SchoolEventsPayload.IdentifiedEvent) {
        let dates = event.ranges.compactMap { range -> CountdownRange? in
            guard let start = SchoolDate(iso8601: range.startDate),
                  let end = SchoolDate(iso8601: range.endDate) else { return nil }
            return .init(start: start, end: end)
        }
        self.init(title: event.title, ranges: dates)
        guard dates.count == event.ranges.count, valid else { return nil }
    }

    func phase(on day: SchoolDate) -> CountdownPhase {
        if day < start { return .upcoming(day.days(until: start)) }
        if day > end { return .finished }
        if start == end { return .today }
        if day == start { return .firstDay }
        if day == end { return .lastDay }
        return .inProgress
    }

    func progress(from origin: SchoolDate?, on day: SchoolDate) -> CountdownProgress {
        guard let origin else { return .hidden }
        let total = origin.days(until: start)
        guard total > 0 else { return .invalid }
        return .value(min(1, max(0, Double(origin.days(until: day)) / Double(total))))
    }
}

enum CountdownPhase: Equatable {
    case upcoming(Int), today, firstDay, inProgress, lastDay, finished

    var label: String {
        switch self {
        case .upcoming(let days): return "まで あと\(days)日"
        case .today: return "今日"
        case .firstDay: return "今日から"
        case .inProgress: return "期間中"
        case .lastDay: return "最終日"
        case .finished: return "終了"
        }
    }

    var active: Bool {
        switch self {
        case .upcoming, .finished: return false
        default: return true
        }
    }
}

enum CountdownProgress: Equatable { case hidden, invalid, value(Double) }

enum CountdownLookahead: Int, Codable, CaseIterable, Identifiable {
    case always = 0, month = 30, fortnight = 14, week = 7
    var id: Int { rawValue }
    var label: String { self == .always ? "常時" : "\(rawValue)日前" }

    func includes(_ phase: CountdownPhase) -> Bool {
        switch phase {
        case .finished: return false
        case .upcoming(let days): return self == .always || days <= rawValue
        default: return true
        }
    }
}

struct CountdownReminder: Codable, Equatable, Hashable {
    static let maximumDaysBefore = 365_000
    var daysBefore: Int
    var hour: Int
    var minute: Int

    static let defaults = [Self(daysBefore: 7, hour: 20, minute: 0), Self(daysBefore: 1, hour: 20, minute: 0)]

    var valid: Bool { (0...Self.maximumDaysBefore).contains(daysBefore) && (0..<24).contains(hour) && (0..<60).contains(minute) }
    var key: String { "\(daysBefore)-\(hour)-\(minute)" }
    var label: String { "\(daysBefore == 0 ? "当日" : "\(daysBefore)日前") \(String(format: "%02d:%02d", hour, minute))" }

    func fireDate(start: SchoolDate) -> Date? {
        guard valid, let day = start.addingDays(-daysBefore) else { return nil }
        return day.dateInJapan(hour: hour, minute: minute)
    }
}

struct CountdownReminderDayEdits {
    private struct Input {
        let text: String
        let days: Int?
    }

    private var inputs: [Int: Input] = [:]

    var hasInvalidInput: Bool { inputs.values.contains { $0.days == nil } }

    func text(at index: Int) -> String? { inputs[index]?.text }

    mutating func enter(_ text: String, at index: Int, locale: Locale = .current) -> Int? {
        let format = IntegerFormatStyle<Int>.number.locale(locale)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = try? format.parseStrategy.parse(trimmed)
        let days: Int?
        if let parsed, (0...CountdownReminder.maximumDaysBefore).contains(parsed),
           trimmed.unicodeScalars.allSatisfy({ $0.properties.numericType == .decimal }) ||
           trimmed == parsed.formatted(format) {
            days = parsed
        } else {
            days = nil
        }
        inputs[index] = Input(text: text, days: days)
        return days
    }

    mutating func endEditing(at index: Int) {
        if inputs[index]?.days != nil { inputs.removeValue(forKey: index) }
    }

    mutating func remove(at index: Int) {
        inputs.removeValue(forKey: index)
        inputs = Dictionary(uniqueKeysWithValues: inputs.map { key, input in
            (key > index ? key - 1 : key, input)
        })
    }
}

struct CountdownPreferences: Codable, Equatable {
    var showsOnHome = true
    var lookahead: CountdownLookahead = .always
    var progressStart: SchoolDate?
    var notifications = false
    var reminders = CountdownReminder.defaults

    var valid: Bool {
        progressStart?.isValidCalendarDay != false && !reminders.isEmpty &&
            Set(reminders).count == reminders.count && reminders.allSatisfy(\.valid)
    }
}

struct CountdownEventReference: Codable, Hashable {
    let year: Int
    let eventID: String

    var valid: Bool { (1900...9998).contains(year) && SchoolEventsPayload.validEventID(eventID) }
    var key: String { "\(year):\(eventID)" }
}

struct CountdownRegistration: Codable, Equatable, Identifiable {
    let id: UUID
    var target: Target
    var preferences = CountdownPreferences()

    enum Target: Codable, Equatable {
        case school(CountdownEventReference, lastSaved: CountdownDates, alias: String?)
        case personal(CountdownDates)
    }

    var reference: CountdownEventReference? {
        if case .school(let reference, _, _) = target { return reference }
        return nil
    }

    var valid: Bool {
        guard preferences.valid else { return false }
        switch target {
        case .personal(let dates): return dates.valid && dates.ranges.count == 1
        case .school(let reference, let lastSaved, let alias):
            return reference.valid && lastSaved.valid && lastSaved.ranges.allSatisfy {
                $0.start.schoolYear == reference.year && $0.end.schoolYear == reference.year
            } && alias.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 4096 } != false
        }
    }
}

enum CountdownExamMode: String, Codable, CaseIterable, Identifiable {
    case school, selectedClass
    var id: String { rawValue }
    var label: String { self == .school ? "次の試験期間" : "選択クラスの次の試験日" }
}

struct CountdownAutomatic: Codable, Equatable, Identifiable {
    static let identity = UUID(uuidString: "4a725859-effc-456a-9669-43ee2dbd2bf4")!
    var id: UUID { Self.identity }
    var enabled = false
    var mode: CountdownExamMode = .school
    var preferences = CountdownPreferences(lookahead: .week)
}

struct CountdownLibrary: Codable, Equatable {
    var version = 1
    var registrations: [CountdownRegistration] = []
    var automatic = CountdownAutomatic()

    var valid: Bool {
        version == 1 && automatic.preferences.valid && registrations.allSatisfy(\.valid) &&
            registrations.allSatisfy { $0.id != automatic.id } &&
            Set(registrations.map(\.id)).count == registrations.count &&
            Set(registrations.compactMap(\.reference)).count == registrations.compactMap(\.reference).count
    }
}

enum CountdownAvailability: Equatable {
    case available, loading, missingYear, missingEvent, sourcePending, sourceDifference
    case noClass, noExam, noDocument, notAnalysed, analysisFailed, expired, previousResult

    var label: String? {
        switch self {
        case .available: return nil
        case .loading: return "資料を確認中"
        case .missingYear: return "行事ID付きの学校行事を取得してください。"
        case .missingEvent: return "元の行事を確認できません。対象を選び直してください。"
        case .sourcePending: return "原本の状態を確認中です。通知は保留しています。"
        case .sourceDifference: return "原本の内容確認待ちです。保存済み日程を表示しています。"
        case .noClass: return "時間割でクラスを選択してください。"
        case .noExam: return "保存済みの資料に該当する試験がありません。"
        case .noDocument: return "試験時間割は未取得です。"
        case .notAnalysed: return "試験時間割は未解析です。"
        case .analysisFailed: return "試験時間割を解析できませんでした。"
        case .expired: return "試験時間割の保存期間が終了しました。"
        case .previousResult: return "試験時間割は前回の正常な解析結果です。"
        }
    }
    var allowsNotification: Bool { self == .available || self == .previousResult }
    var presentsDatesOnHome: Bool {
        self == .available || self == .sourcePending || self == .sourceDifference || self == .previousResult
    }
}

struct CountdownCard: Identifiable, Equatable {
    let id: UUID
    let title: String
    let dates: CountdownDates?
    let preferences: CountdownPreferences
    let availability: CountdownAvailability
    var reference: CountdownEventReference?
    var expiry: Date?
    var classSubjects: [String] = []
    var evidence: String = ""

    var targetKey: String { reference?.key ?? (expiry == nil ? id.uuidString : evidence) }
    var isPrivate: Bool { expiry != nil }

    func isFinished(on today: SchoolDate) -> Bool {
        availability.presentsDatesOnHome && dates?.phase(on: today) == .finished
    }

    static func sorted(_ cards: [Self], today: SchoolDate) -> [Self] {
        cards.sorted { lhs, rhs in
            guard let left = lhs.dates, let right = rhs.dates else {
                if (lhs.dates == nil) != (rhs.dates == nil) { return lhs.dates != nil }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            let leftPhase = left.phase(on: today), rightPhase = right.phase(on: today)
            if leftPhase.active != rightPhase.active { return leftPhase.active }
            if left.start != right.start { return left.start < right.start }
            if left.end != right.end { return left.end < right.end }
            return (lhs.targetKey, lhs.id.uuidString) < (rhs.targetKey, rhs.id.uuidString)
        }
    }

    static func home(_ cards: [Self], today: SchoolDate) -> [Self] {
        Array(sorted(cards.filter { card in
            guard card.preferences.showsOnHome, card.availability.presentsDatesOnHome, let dates = card.dates else { return false }
            return card.preferences.lookahead.includes(dates.phase(on: today))
        }, today: today).prefix(3))
    }
}

struct CountdownNotice: Equatable {
    static let prefix = "takupoke.countdown."
    static let privatePrefix = prefix + "private."
    let identifier: String
    let targetID: UUID
    let targetKey: String
    let title: String
    let fireAt: Date

    static func planned(for cards: [CountdownCard], at now: Date) -> [Self] {
        let today = TimetableDaySchedule.schoolDay(at: now)
        return cards.flatMap { card -> [Self] in
            guard card.preferences.notifications, card.availability.allowsNotification, let dates = card.dates,
                  dates.phase(on: today) != .finished else { return [] }
            return card.preferences.reminders.compactMap { reminder in
                guard let fireAt = reminder.fireDate(start: dates.start), fireAt > now,
                      card.expiry.map({ fireAt < $0 && now < $0 }) != false else { return nil }
                let scope = card.isPrivate ? privatePrefix : prefix + "personal."
                return Self(identifier: scope + card.id.uuidString + "." + reminder.key, targetID: card.id,
                            targetKey: card.targetKey, title: card.title, fireAt: fireAt)
            }
        }.sorted { ($0.fireAt, $0.identifier) < ($1.fireAt, $1.identifier) }
    }
}

struct CountdownStore {
    private let path: URL
    private static let maximumBytes = 2_000_000
    init(root: URL) { path = root.appendingPathComponent("Countdown.json") }

    func load() throws -> CountdownLibrary {
        guard FileManager.default.fileExists(atPath: path.path) else { return .init() }
        let info = try path.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true,
              let size = info.fileSize, size <= Self.maximumBytes else { throw CocoaError(.fileReadCorruptFile) }
        let bytes = try Data(contentsOf: path)
        guard bytes.count <= Self.maximumBytes else { throw CocoaError(.fileReadCorruptFile) }
        let value = try JSONDecoder().decode(CountdownLibrary.self, from: bytes)
        guard value.valid else { throw CocoaError(.fileReadCorruptFile) }
        return value
    }

    func save(_ library: CountdownLibrary) throws {
        guard library.valid else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
        let bytes = try JSONEncoder().encode(library)
        guard bytes.count <= Self.maximumBytes else { throw CocoaError(.fileWriteOutOfSpace) }
        #if os(iOS)
        try bytes.write(to: path, options: [.atomic, .completeFileProtection])
        #else
        try bytes.write(to: path, options: .atomic)
        #endif
    }
}
