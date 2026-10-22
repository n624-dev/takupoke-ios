import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

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

    enum Readiness { case unavailable, absent, available }
    struct Availability {
        var changes: Readiness
        var specials: [String: Readiness]
        func state(for kind: String) -> Readiness { kind == "changes" ? changes : specials[kind] ?? .unavailable }
    }

    static func availability(materialsReady: Bool, specialsReady: Bool, state: MaterialLibraryState,
                             records: [SpecialScheduleKind: SpecialScheduleRecord], sources: [SpecialScheduleKind: SpecialScheduleSource]) -> Availability {
        let changes: Readiness = !materialsReady ? .unavailable : state.record(for: .changes) == nil ? .absent
            : acceptedChanges(in: state) == nil ? .unavailable : .available
        let accepted = acceptedSpecialDigests(records: records, sources: sources)
        return Availability(changes: changes, specials: Dictionary(uniqueKeysWithValues: SpecialScheduleKind.allCases.map { kind in
            (kind.rawValue, !specialsReady ? .unavailable : sources[kind] == nil ? .absent
                : accepted[kind.rawValue] == nil ? .unavailable : .available)
        }))
    }

    static func notice(_ targets: [ChangeTarget]) throws -> Pending {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let hash = SHA256.hash(data: try encoder.encode(targets)).map { String(format: "%02x", $0) }.joined()
        return Pending(fingerprint: hash, count: targets.count, changeTargets: targets)
    }

    func reconciling(changes nextChanges: Set<Change>?, specials: [String: String], availability: Availability,
                     today: SchoolDate, classes: Set<String>, changesEnabled: Bool, specialsEnabled: Bool) throws -> Self {
        var next = self
        switch availability.changes {
        case .available:
            if let nextChanges {
                let targets = next.pendingChangeTargets(in: nextChanges, today: today, classes: classes)
                if changesEnabled, !targets.isEmpty { next.pending["changes"] = try Self.notice(targets) }
                else { next.pending.removeValue(forKey: "changes") }
                next.changes = nextChanges
            }
        case .absent:
            next.pending.removeValue(forKey: "changes"); next.changes = nil
        case .unavailable: break
        }
        for kind in SpecialScheduleKind.allCases {
            switch availability.state(for: kind.rawValue) {
            case .available:
                guard let digest = specials[kind.rawValue] else { continue }
                if specialsEnabled, next.specialChanged(kind: kind.rawValue, digest: digest) {
                    next.pending[kind.rawValue] = Pending(fingerprint: digest, count: 1)
                } else if next.pending[kind.rawValue]?.fingerprint != digest { next.pending.removeValue(forKey: kind.rawValue) }
                next.specialDigests[kind.rawValue] = digest
            case .absent:
                next.pending.removeValue(forKey: kind.rawValue); next.specialDigests.removeValue(forKey: kind.rawValue)
            case .unavailable: break
            }
        }
        if !changesEnabled { next.pending.removeValue(forKey: "changes") }
        if !specialsEnabled { for kind in SpecialScheduleKind.allCases { next.pending.removeValue(forKey: kind.rawValue) } }
        return next
    }

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
