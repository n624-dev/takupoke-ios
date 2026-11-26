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
    struct ChangeTarget: Codable, Hashable {
        let date: String
        let className: String
        let period: String
        let expectedFingerprints: [String]
        var key: String { [date,className,period].joined(separator: "|") }
    }
    struct Pending: Codable, Equatable {
        let fingerprint: String
        let count: Int
        // Legacy count-only notices cannot prove that their target still exists.
        var changeTargets: [ChangeTarget]? = nil
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

    func changeTargets(comparedWith next: Set<Change>, today: SchoolDate, classes: Set<String>) -> [ChangeTarget] {
        guard let changes else { return [] }
        let changed = changes.symmetricDifference(next)
        let slots = Set(changed.map { ChangeTarget(date:$0.date,className:$0.className,period:$0.period,expectedFingerprints:[]) })
        return validTargets(slots.map { slot in
            ChangeTarget(date:slot.date,className:slot.className,period:slot.period,
                         expectedFingerprints:next.filter { $0.date == slot.date && $0.className == slot.className && $0.period == slot.period }.map(\.fingerprint).sorted())
        }, in:next,today:today,classes:classes)
    }

    func validTargets(_ targets: [ChangeTarget], in next: Set<Change>, today: SchoolDate, classes: Set<String>) -> [ChangeTarget] {
        targets.filter { target in
            guard let date = SchoolDate(iso8601:target.date), date >= today, classes.contains(target.className) else { return false }
            return target.expectedFingerprints == next.filter { $0.date == target.date && $0.className == target.className && $0.period == target.period }.map(\.fingerprint).sorted()
        }.sorted { $0.key < $1.key }
    }

    func pendingChangeTargets(in next: Set<Change>, today: SchoolDate, classes: Set<String>) -> [ChangeTarget] {
        var bySlot = [String:ChangeTarget]()
        for target in validTargets(pending["changes"]?.changeTargets ?? [],in:next,today:today,classes:classes) { bySlot[target.key] = target }
        for target in changeTargets(comparedWith:next,today:today,classes:classes) { bySlot[target.key] = target }
        return bySlot.values.sorted { $0.key < $1.key }
    }

    func changeCount(comparedWith next: Set<Change>, today: SchoolDate, classes: Set<String>) -> Int {
        changeTargets(comparedWith:next,today:today,classes:classes).count
    }

    func specialChanged(kind: String, digest: String) -> Bool {
        guard let previous = specialDigests[kind] else { return false }
        return previous != digest
    }
}
