import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

struct ScheduleUpdateNotice: Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case changes, exam, examReturn
        var identifier: String { "takupoke." + rawValue }
    }

    enum Edition: Equatable { case same, replaced, unavailable }

    let kind: Kind
    let revision: String?
    let documentRevision: String?
    let classRevision: String?
    let days: [SchoolDate]

    init?(identifier: String, revision: String?, documentRevision: String? = nil,
          classRevision: String? = nil, days: [String] = []) {
        guard let kind = Kind.allCases.first(where: { $0.identifier == identifier }) else { return nil }
        self.kind = kind
        self.revision = Self.verifiedRevision(revision)
        self.documentRevision = Self.verifiedRevision(documentRevision)
        self.classRevision = Self.verifiedRevision(classRevision)
        self.days = Array(Set(days.prefix(366).compactMap(SchoolDate.init(iso8601:)))).sorted()
    }

    static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func selectedClassesRevision(_ classes: Set<String>, international: Bool = false,
                                        mappingRevision: String = "no-mapping") -> String {
        digest((classes.sorted() + [String(international), mappingRevision]).joined(separator: "|"))
    }

    func date(today: SchoolDate, upcoming: Set<SchoolDate>, edition: Edition,
              selectedClasses: Set<String>, allowsRememberedDates: Bool, international: Bool = false,
              mappingRevision: String = "no-mapping") -> SchoolDate? {
        if edition == .same, allowsRememberedDates,
           classRevision == Self.selectedClassesRevision(selectedClasses, international: international, mappingRevision: mappingRevision),
           let date = days.first(where: { $0 >= today }) { return date }
        return upcoming.filter { $0 >= today }.min()
    }

    func edition(currentRevision: String?) -> Edition {
        let expected = kind == .changes ? documentRevision : revision
        guard let expected, let current = Self.verifiedRevision(currentRevision) else { return .unavailable }
        return expected == current ? .same : .replaced
    }

    private static func verifiedRevision(_ value: String?) -> String? {
        guard let value, value.utf8.count == 64,
              value.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return nil }
        return value
    }
}

/// Fingerprints contain no subject, teacher, room, file name or original text.
/// Keeping all classes as a baseline prevents class selection from becoming a
/// false data update. Filtering is performed only when comparing snapshots.
struct ScheduleNotificationSnapshot: Codable, Equatable {
    enum ReadError: Error, Equatable { case malformedJSON, invalidStructure, unsupportedFormat }
    private static let currentFormat = 1
    struct Change: Codable, Hashable {
        let date: String
        let className: String
        let period: String
        let fingerprint: String
        fileprivate var slot: Slot { .init(date:date,className:className,period:period) }

        static func from(_ row: ScheduleChange) -> Self {
            // Keep the saved identity for notations that gained display support.
            let newNotation = row.period.precomposedStringWithCompatibilityMapping
                .rangeOfCharacter(from: CharacterSet(charactersIn: "・、限")) != nil
            let period = newNotation ? row.period : row.detailPeriods?.map(String.init).joined(separator: ",") ?? row.period
            var fields = [row.change_date, row.displayClassName, period,
                          row.before_subject, row.after_subject, row.teacher, row.room, row.note]
            let legacy = row.note.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines)
            let oldKind = legacy == "休講" || legacy == "補講" ? legacy : "変更"
            if row.cardKindLabel != oldKind { fields.append(row.cardKindLabel) }
            let data = (try? JSONEncoder().encode(fields)) ?? Data()
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            return Self(date: row.change_date, className: row.displayClassName, period: period, fingerprint: hash)
        }
    }
    struct ChangeTarget: Codable, Hashable {
        let date: String
        let className: String
        let period: String
        let expectedFingerprints: [String]
        var visibilityEvidence: VisibilityEvidence? = nil
        var key: String { [date,className,period].joined(separator: "|") }
        fileprivate var slot: Slot { .init(date:date,className:className,period:period) }
    }
    struct VisibilityEvidence: Codable, Hashable {
        var updatedRows: [String] = []
        var removedVisibleRow = false
        var removedOrdinaryUnderRules: String? = nil
    }
    struct ChangeVisibility: Codable, Equatable {
        let timetable: Set<Change>
        let ordinary: Set<Change>
        let mappingRevision: String

        init(rows: [Change: ScheduleChange], mapping: SavedMapping?) {
            let timetableRows = rows.filter { $0.value.detailPeriods != nil }
            timetable = Set(timetableRows.keys)
            ordinary = Set(timetableRows.compactMap { change, row in
                TimetableSchedule.shouldDisplay(row, isInternationalStudent: false, matchedByRule: { subject, name, year in
                    mapping?.rules.isInternationalStudentChangeField(subject, className: name, schoolYear: year) == true
                }) ? change : nil
            })
            mappingRevision = mapping?.archiveSHA256 ?? "no-mapping"
        }
    }
    struct ChangeScope {
        let visibility: ChangeVisibility
        let international: Bool
        var showsChanges = true
    }
    fileprivate struct Slot: Hashable {
        let date: String
        let className: String
        let period: String

        func isRelevant(today: SchoolDate, classes: Set<String>) -> Bool {
            guard classes.contains(className), let day = SchoolDate(iso8601:date) else { return false }
            return day >= today
        }

        func target(fingerprints: [String]) -> ChangeTarget {
            ChangeTarget(date:date,className:className,period:period,expectedFingerprints:fingerprints)
        }
    }
    struct Pending: Codable, Equatable {
        let fingerprint: String
        let count: Int
        // Legacy count-only notices cannot prove that their target still exists.
        var changeTargets: [ChangeTarget]? = nil
    }

    var changeDocument: String? = nil
    var changes: Set<Change>?
    var changeVisibility: ChangeVisibility?
    var specialDigests: [String: String] = [:]
    var pending: [String: Pending] = [:]
    var formatVersion: Int? = currentFormat

    static func load(from file: URL) throws -> Self {
        let original = URL(fileURLWithPath:file.path)
        guard let bytes = try readBytes(from: original) else { return Self() }
        do { return try decode(bytes) }
        catch ReadError.malformedJSON {
            let empty = Self()
            try replace(bytes, at: original, with: empty, archivePrefix: "baseline-malformed-")
            return empty
        }
    }

    static func restoreKnownStructure(at file: URL, with baseline: Self) throws {
        let original = URL(fileURLWithPath: file.path)
        guard baseline.pending.isEmpty, let bytes = try readBytes(from: original) else { throw ReadError.invalidStructure }
        do { _ = try decode(bytes) }
        catch ReadError.invalidStructure {
            try replace(bytes, at: original, with: baseline, archivePrefix: "baseline-invalid-")
            return
        }
        throw CocoaError(.fileWriteFileExists)
    }

    private static func readBytes(from original: URL) throws -> Data? {
        let info: URLResourceValues
        do { info = try original.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey]) }
        catch let error as CocoaError where [.fileNoSuchFile,.fileReadNoSuchFile].contains(error.code) { return nil }
        guard info.isRegularFile == true, info.isSymbolicLink != true else { throw CocoaError(.fileReadCorruptFile) }
        return try Data(contentsOf: original)
    }

    private static func decode(_ bytes: Data) throws -> Self {
        struct VersionEnvelope: Decodable { let formatVersion: Int? }
        guard let json = try? JSONSerialization.jsonObject(with: bytes, options: .fragmentsAllowed) else {
            throw ReadError.malformedJSON
        }
        guard let fields = json as? [String: Any] else { throw ReadError.unsupportedFormat }
        if fields.keys.contains("formatVersion") {
            guard let version = (try? JSONDecoder().decode(VersionEnvelope.self, from: bytes))?.formatVersion,
                  version == currentFormat else { throw ReadError.unsupportedFormat }
        } else {
            let legacyKeys: Set<String> = ["changeDocument", "changes", "changeVisibility", "specialDigests", "pending"]
            guard Set(fields.keys).isSubset(of: legacyKeys) else { throw ReadError.unsupportedFormat }
        }
        guard var snapshot = try? JSONDecoder().decode(Self.self, from: bytes) else { throw ReadError.invalidStructure }
        snapshot.formatVersion = currentFormat
        return snapshot
    }

    private static func replace(_ bytes: Data, at original: URL, with baseline: Self, archivePrefix: String) throws {
        let retained = original.deletingLastPathComponent().appendingPathComponent(archivePrefix + UUID().uuidString + ".json")
        try write(bytes, to: retained)
        do {
            guard try readBytes(from: original) == bytes else { throw CocoaError(.fileReadCorruptFile) }
            try baseline.save(to: original)
        } catch {
            try? FileManager.default.removeItem(at: retained)
            throw error
        }
    }

    func save(to file: URL) throws {
        try Self.write(JSONEncoder().encode(self),to:file)
    }

    private static func write(_ bytes: Data, to file: URL) throws {
        #if os(iOS)
        try bytes.write(to:file,options:[.atomic,.completeFileProtection])
        #else
        try bytes.write(to:file,options:.atomic)
        #endif
    }

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
        let identity = targets.map { target in
            var value = target
            value.visibilityEvidence = nil
            return value
        }
        let hash = SHA256.hash(data: try encoder.encode(identity)).map { String(format: "%02x", $0) }.joined()
        return Pending(fingerprint: hash, count: targets.count, changeTargets: targets)
    }

    func reconciling(changes nextChanges: Set<Change>?, specials: [String: String], availability: Availability,
                     today: SchoolDate, classes: Set<String>, changesEnabled: Bool, specialsEnabled: Bool,
                     changeDocument: String? = nil, personalEdit: Bool = false, scope: ChangeScope? = nil) throws -> Self {
        var next = self
        switch availability.changes {
        case .available:
            if let nextChanges {
                // Pre-document snapshots already contain the last accepted rows. On the
                // first personal save, adopt its document identity without announcing the edit.
                let rebasePersonalEdit = personalEdit && changeDocument != nil &&
                    (self.changeDocument == nil || self.changeDocument == changeDocument)
                let targets = rebasePersonalEdit
                    ? validTargets(pending["changes"]?.changeTargets ?? [], in: nextChanges, today: today, classes: classes, scope: scope)
                    : next.pendingChangeTargets(in: nextChanges, today: today, classes: classes, scope: scope)
                next.changeDocument = changeDocument
                if changesEnabled, !targets.isEmpty { next.pending["changes"] = try Self.notice(targets) }
                else { next.pending.removeValue(forKey: "changes") }
                next.changes = nextChanges
                next.changeVisibility = scope?.visibility
            }
        case .absent:
            next.pending.removeValue(forKey: "changes"); next.changes = nil; next.changeDocument = nil; next.changeVisibility = nil
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
        guard let analysis = state.changeAnalysis, let source = state.record(for: .changes),
              analysis.matches(record: source, defaultYear: analysis.defaultYear) else { return nil }
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
        let slots = changedSlots(comparedWith:next,today:today,classes:classes)
        let fingerprints = Self.fingerprints(for:slots,in:next)
        return slots.map { $0.target(fingerprints:fingerprints[$0] ?? []) }.sorted { $0.key < $1.key }
    }

    func validTargets(_ targets: [ChangeTarget], in next: Set<Change>, today: SchoolDate, classes: Set<String>, scope: ChangeScope? = nil) -> [ChangeTarget] {
        let eligible = targets.filter { $0.slot.isRelevant(today:today,classes:classes) }
        let fingerprints = Self.fingerprints(for:Set(eligible.map(\.slot)),in:next)
        let visible = scope.map { Self.visibleFingerprints(for: Set(eligible.map(\.slot)), scope: $0) }
        return eligible.filter { target in
            target.expectedFingerprints == (fingerprints[target.slot] ?? []) &&
                Self.isVisible(target, visible: visible?[target.slot] ?? [], in: scope)
        }.sorted { $0.key < $1.key }
    }

    func pendingChangeTargets(in next: Set<Change>, today: SchoolDate, classes: Set<String>,
                              scope: ChangeScope? = nil) -> [ChangeTarget] {
        var bySlot = [String: ChangeTarget]()
        for target in validTargets(pending["changes"]?.changeTargets ?? [], in: next, today: today, classes: classes, scope: scope) {
            bySlot[target.key] = target
        }
        let candidates = changeTargets(comparedWith: next, today: today, classes: classes)
        guard let scope else {
            for target in candidates { bySlot[target.key] = target }
            return bySlot.values.sorted { $0.key < $1.key }
        }
        guard !candidates.isEmpty, let changes else { return bySlot.values.sorted { $0.key < $1.key } }
        let slots = Set(candidates.map(\.slot))
        let added = Self.fingerprints(for: slots, in: next.subtracting(changes))
        let removed = changes.subtracting(next)
        let previous = changeVisibility
        let removedVisible = Set(removed.filter { previous?.timetable.contains($0) == true }.map(\.slot))
        let removedOrdinary = Set(removed.filter { previous?.ordinary.contains($0) == true }.map(\.slot))
        let visible = Self.visibleFingerprints(for: slots, scope: scope)
        for var target in candidates {
            target.visibilityEvidence = .init(updatedRows: added[target.slot] ?? [],
                removedVisibleRow: removedVisible.contains(target.slot),
                removedOrdinaryUnderRules: removedOrdinary.contains(target.slot) ? previous?.mappingRevision : nil)
            if Self.isVisible(target, visible: visible[target.slot] ?? [], in: scope) { bySlot[target.key] = target }
        }
        return bySlot.values.sorted { $0.key < $1.key }
    }

    private static func visibleFingerprints(for slots: Set<Slot>, scope: ChangeScope) -> [Slot: [String]] {
        fingerprints(for: slots, in: scope.international ? scope.visibility.timetable : scope.visibility.ordinary)
    }

    private static func isVisible(_ target: ChangeTarget, visible: [String], in scope: ChangeScope?) -> Bool {
        guard let scope else { return true }
        guard scope.showsChanges else { return false }
        guard let evidence = target.visibilityEvidence else { return !visible.isEmpty }
        if !Set(evidence.updatedRows).isDisjoint(with: visible) { return true }
        if scope.international { return evidence.removedVisibleRow }
        return evidence.removedOrdinaryUnderRules == scope.visibility.mappingRevision
    }

    private func changedSlots(comparedWith next: Set<Change>, today: SchoolDate, classes: Set<String>) -> Set<Slot> {
        guard let changes, !classes.isEmpty else { return [] }
        return Set(changes.symmetricDifference(next).map(\.slot)).filter { $0.isRelevant(today:today,classes:classes) }
    }

    private static func fingerprints(for slots: Set<Slot>, in changes: Set<Change>) -> [Slot:[String]] {
        guard !slots.isEmpty else { return [:] }
        var result = [Slot:[String]]()
        for change in changes {
            let slot = change.slot
            if slots.contains(slot) { result[slot,default:[]].append(change.fingerprint) }
        }
        return result.mapValues { $0.sorted() }
    }

    func changeCount(comparedWith next: Set<Change>, today: SchoolDate, classes: Set<String>) -> Int {
        changeTargets(comparedWith:next,today:today,classes:classes).count
    }

    func specialChanged(kind: String, digest: String) -> Bool {
        guard let previous = specialDigests[kind] else { return false }
        return previous != digest
    }
}
