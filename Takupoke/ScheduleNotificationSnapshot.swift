import Foundation

/// Fingerprints contain no subject, teacher, room, file name or original text.
/// Keeping all classes as a baseline prevents class selection from becoming a
/// false data update. Filtering is performed only when comparing snapshots.
struct ScheduleNotificationSnapshot: Codable, Equatable {
    struct Change: Codable, Hashable {
        let date: String
        let className: String
        let period: String
        let fingerprint: String
    }
    struct Pending: Codable, Equatable {
        let fingerprint: String
        let count: Int
    }

    var changes: Set<Change>?
    var specialDigests: [String: String] = [:]
    var pending: [String: Pending] = [:]

    static func acceptedChanges(in state: MaterialLibraryState) -> [ScheduleChange]? {
        guard let analysis = state.changeAnalysis, analysis.version == ChangeAnalysis.parserVersion,
              analysis.sourceDigest == state.record(for: .changes)?.digest else { return nil }
        return analysis.records
    }

    static func acceptedSpecialDigests(records: [SpecialScheduleKind: SpecialScheduleRecord],
                                      sources: [SpecialScheduleKind: SpecialScheduleSource]) -> [String: String] {
        var result: [String: String] = [:]
        for kind in SpecialScheduleKind.allCases {
            if let record = records[kind], record.analysis.version == SpecialScheduleAnalysis.parserVersion,
               record.digest == record.analysis.sourceDigest, record.digest == sources[kind]?.digest {
                result[kind.rawValue] = record.digest
            }
        }
        return result
    }

    func changeCount(comparedWith next: Set<Change>, today: SchoolDate, classes: Set<String>) -> Int {
        guard let changes else { return 0 }
        struct Slot: Hashable { let date: String; let className: String; let period: String }
        return Set(changes.symmetricDifference(next).filter { item in
            guard let date = SchoolDate(iso8601: item.date) else { return false }
            return date >= today && classes.contains(item.className)
        }.map { Slot(date: $0.date, className: $0.className, period: $0.period) }).count
    }

    func specialChanged(kind: String, digest: String) -> Bool {
        guard let previous = specialDigests[kind] else { return false }
        return previous != digest
    }
}
