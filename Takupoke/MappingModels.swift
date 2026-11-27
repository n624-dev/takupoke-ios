import Foundation

enum MappingRevisionResult: Equatable, Sendable {
    case unchanged
    case available(String)

    static func isValidRevision(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil
    }
}

/// Each observation belongs to the exact installation inspected by the request.
struct DistributedRevisionConfirmation: Codable, Equatable {
    struct Installation: Codable, Equatable {
        let revision: String?
        let acquiredAt: Date
    }

    struct Observation: Codable, Equatable {
        let revision: String
        let checkedAt: Date
    }

    enum Outcome: String, Codable {
        case unchanged, updateAvailable, adopted, failed
    }

    let installation: Installation
    private(set) var lastSuccess: Observation?
    private(set) var lastAttemptAt: Date
    private(set) var outcome: Outcome

    var hasNewerRevision: Bool {
        guard let lastSuccess else { return false }
        return lastSuccess.revision != installation.revision
    }

    init(installation: Installation, result: MappingRevisionResult, at time: Date) {
        self.installation = installation
        self.lastAttemptAt = time
        switch result {
        case .unchanged:
            self.lastSuccess = installation.revision.map { .init(revision: $0, checkedAt: time) }
            self.outcome = .unchanged
        case .available(let revision):
            self.lastSuccess = .init(revision: revision, checkedAt: time)
            self.outcome = .updateAvailable
        }
    }

    init(adopted installation: Installation, at time: Date) {
        self.installation = installation
        self.lastAttemptAt = time
        self.outcome = .adopted
    }

    init(failed installation: Installation, previous: Self?, at time: Date) {
        self.installation = installation
        self.lastAttemptAt = time
        self.lastSuccess = previous?.installation == installation ? previous?.lastSuccess : nil
        self.outcome = .failed
    }

    static func load(beside dataFile: URL, installation: Installation) -> Self? {
        let url = confirmationURL(beside: dataFile)
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 4096,
              let data = try? Data(contentsOf: url), data.count <= 4096,
              let record = try? JSONDecoder().decode(Self.self, from: data),
              record.installation == installation, record.isValid else { return nil }
        return record
    }

    func save(beside dataFile: URL?) {
        guard isValid, let dataFile, let data = try? JSONEncoder().encode(self) else { return }
        let url = Self.confirmationURL(beside: dataFile)
        #if os(iOS)
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try? data.write(to: url, options: .atomic)
        #endif
    }

    private static func confirmationURL(beside dataFile: URL) -> URL {
        dataFile.appendingPathExtension("revision-check.json")
    }

    private var isValid: Bool {
        guard installation.revision.map(MappingRevisionResult.isValidRevision) ?? true,
              lastSuccess.map({ MappingRevisionResult.isValidRevision($0.revision) }) ?? true else { return false }
        switch outcome {
        case .unchanged:
            return lastSuccess?.revision != nil && lastSuccess?.revision == installation.revision
        case .updateAvailable:
            return lastSuccess?.revision != nil && lastSuccess?.revision != installation.revision
        case .adopted:
            return installation.revision != nil && lastSuccess == nil
        case .failed:
            return true
        }
    }
}

enum MappingError: Error, LocalizedError {
    case invalidPackage, invalidResponse, authentication, unavailable, storage, changedDuringDownload
    case authenticationTimedOut, authenticationNetwork

    var authenticationFailureDescription: String? {
        switch self {
        case .authentication: return "認証を完了できませんでした。"
        case .authenticationTimedOut: return "認証の待ち時間を超えました。"
        case .authenticationNetwork: return "認証サービスに接続できませんでした。"
        default: return nil
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidPackage: return "名称データの形式または整合性を確認できませんでした。"
        case .invalidResponse: return "名称データの配信応答を確認できませんでした。"
        case .authentication, .authenticationTimedOut, .authenticationNetwork: return authenticationFailureDescription
        case .unavailable: return "名称データを取得できませんでした。"
        case .storage: return "名称データを保存できませんでした。"
        case .changedDuringDownload: return "取得中に名称データが更新されました。もう一度お試しください。"
        }
    }
}

struct MappingRule: Codable, Equatable {
    let alias: String
    let fullName: String
    let classes: [String]?
    let internationalStudent: Bool?
}

struct TeacherContextRule: Codable, Equatable {
    let alias: String
    let fullName: String
    let subject: String
    let className: String
    let schoolYear: Int
}

struct ChangePresentation: Equatable {
    let before: TimetableLessonNames
    let after: TimetableLessonNames

    static func source(_ change: ScheduleChange) -> Self {
        Self(before: TimetableLessonNames(subject: change.before_subject),
             after: TimetableLessonNames(subject: change.after_subject,
                                         teacher: change.teacher, room: change.room))
    }
}

struct SavedMapping: Codable, Equatable {
    let revision: String
    let version: String
    let schemaVersion: Int
    let archiveETag: String
    let archiveSHA256: String
    let publishedAt: String
    let fetchedAt: Date
    let rules: MappingRules
}

/// A candidate belongs to one period of the selected row, even when that row
/// also changes a nonadjacent period.
struct ChangeBaseCandidate: Equatable {
    let names: TimetableLessonNames
    let source: String
}

struct ChangeComparison {
    enum Field: String, CaseIterable {
        case subject = "科目", teacher = "教員", room = "教室"

        func value(_ names: TimetableLessonNames) -> String {
            switch self {
            case .subject: return names.detailSubject
            case .teacher: return names.detailTeacher
            case .room: return names.detailRoom
            }
        }
    }
    struct Pair: Equatable {
        let field: Field
        let before: String
        let after: String
        let source: String?
        var changed: Bool { !before.isEmpty && !after.isEmpty && before != after }
    }
    struct Group: Equatable {
        var periods: [Int]
        let pairs: [Pair]
        let unresolved: [ChangeBaseCandidate]
    }

    let change: ScheduleChange
    let groups: [Group]

    init(change: ScheduleChange, names: ChangePresentation, candidates: [Int: [ChangeBaseCandidate]]) {
        self.change = change
        var result: [Group] = []
        let periods = change.detailPeriods ?? []
        for period in periods.isEmpty ? [0] : periods {
            let available = candidates[period] ?? []
            let compatible = available.filter { base in
                Field.allCases.allSatisfy { field in
                    let explicit = field.value(names.before), candidate = field.value(base.names)
                    return explicit.isEmpty || candidate.isEmpty || explicit == candidate
                }
            }
            let original = compatible.count == 1 ? compatible.first : nil
            let pairs = Field.allCases.map { field in
                let printed = field.value(names.before)
                let infer = printed.isEmpty ? original : nil
                let before = infer.map { field.value($0.names) } ?? printed
                return Pair(field: field, before: before, after: field.value(names.after),
                            source: before.isEmpty ? nil : infer?.source)
            }
            let unresolved = original == nil ? available : []
            if let index = result.firstIndex(where: { $0.pairs == pairs && $0.unresolved == unresolved }) {
                result[index].periods.append(period)
            } else {
                result.append(Group(periods: period == 0 ? [] : [period], pairs: pairs, unresolved: unresolved))
            }
        }
        groups = result
    }

    var heading: String {
        if change.isCancellation || change.isMakeup { return change.cardKindLabel }
        let fields = Field.allCases.filter { field in groups.contains { group in group.pairs.contains { $0.field == field && $0.changed } } }
        return fields.isEmpty ? "時間割変更" : fields.map(\.rawValue).joined(separator: "・") + "変更"
    }

    var summary: String {
        if change.isCancellation || change.isMakeup {
            let subjects = groups.compactMap { $0.pairs.first }.map { change.isCancellation ? $0.before : $0.after }
            var seen = Set<String>()
            return ([heading] + subjects.filter { !$0.isEmpty && seen.insert($0).inserted }).joined(separator: "　")
        }
        for field in Field.allCases {
            for group in groups {
                if let pair = group.pairs.first(where: { $0.field == field && $0.changed }) {
                    let period = groups.count > 1 ? group.periods.map(String.init).joined(separator: "・") + "限　" : ""
                    return heading + "　" + period + pair.before + " → " + pair.after
                }
            }
        }
        if let first = groups.first {
            for pair in first.pairs where !pair.after.isEmpty || !pair.before.isEmpty {
                if pair.before == pair.after { return heading + "　" + pair.field.rawValue + " " + pair.after }
                if !pair.after.isEmpty { return heading + "　変更後の" + pair.field.rawValue + " " + pair.after }
                return heading + "　変更前の" + pair.field.rawValue + " " + pair.before
            }
        }
        return heading
    }
}
