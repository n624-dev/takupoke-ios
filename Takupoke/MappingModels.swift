import Foundation

enum MappingRevisionResult: Equatable, Sendable {
    case unchanged
    case available(String)
}

enum MappingError: Error, LocalizedError {
    case invalidPackage, invalidResponse, authentication, unavailable, storage, changedDuringDownload

    var errorDescription: String? {
        switch self {
        case .invalidPackage: return "名称データの形式または整合性を確認できませんでした。"
        case .invalidResponse: return "名称データの配信応答を確認できませんでした。"
        case .authentication: return "認証を完了できませんでした。"
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
