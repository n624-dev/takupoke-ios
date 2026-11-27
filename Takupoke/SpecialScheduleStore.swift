import Foundation
import GRDB

/// The special PDFs have their own source and parser contract. This sidecar
/// SQLite store leaves the existing material database and parser untouched.
final class SpecialScheduleStore {
    let ownerQueue: DispatchQueue
    var pipelineEvidence: [SpecialScheduleKind: SpecialPipelineEvidence] = [:]
    enum StoreError: Error { case invalidState }

    private let root: URL
    let files: URL
    private let staging: URL
    let queue: DatabaseQueue
    var records: [SpecialScheduleKind: SpecialScheduleRecord] = [:]
    var sources: [SpecialScheduleKind: SpecialScheduleSource] = [:]
    var acquisitionAttempts: [SpecialScheduleKind: AcquisitionAttempt] = [:]

    init(root: URL, ownerQueue: DispatchQueue = DispatchQueue(label: "io.github.n624dev.takupoke.special-owner", qos: .userInitiated)) throws {
        self.ownerQueue = ownerQueue
        self.root = root
        files = root.appendingPathComponent("files", isDirectory: true)
        staging = root.appendingPathComponent("staging", isDirectory: true)
        let manager = FileManager.default
        try manager.createDirectory(at: files, withIntermediateDirectories: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        #if os(iOS) || os(macOS)
        var protectedRoot = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedRoot.setResourceValues(values)
        #endif
        #if os(iOS)
        for directory in [root, files, staging] {
            try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        }
        #endif
        var config = Configuration()
        config.publicStatementArguments = false
        let database = root.appendingPathComponent("specials.sqlite")
        let existingDatabase = manager.fileExists(atPath: database.path)
        let storedFiles = try manager.contentsOfDirectory(at: files, includingPropertiesForKeys: nil)
        guard existingDatabase || storedFiles.isEmpty else { throw StoreError.invalidState }
        queue = try DatabaseQueue(path: database.path, configuration: config)
        let hasSources = try queue.write { db in
            let hasSchedule = try db.tableExists("specialSchedule")
            if existingDatabase && !hasSchedule {
                // Opening SQLite can create the formal file before the first
                // schema transaction. Only that completely blank state is
                // resumable: retained PDFs or any schema/version evidence still
                // require recovery rather than silently reinitializing a store.
                guard storedFiles.isEmpty,
                      try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master") == 0,
                      try Int.fetchOne(db, sql: "PRAGMA user_version") == 0,
                      try Int.fetchOne(db, sql: "PRAGMA application_id") == 0 else {
                    throw StoreError.invalidState
                }
            }
            if !hasSchedule {
                try db.execute(sql: """
                    CREATE TABLE specialSchedule (
                        kind TEXT PRIMARY KEY NOT NULL CHECK (kind IN ('exam', 'examReturn')),
                        payload BLOB NOT NULL
                    );
                    CREATE TABLE specialSource (
                        kind TEXT PRIMARY KEY NOT NULL CHECK (kind IN ('exam', 'examReturn')),
                        payload BLOB NOT NULL
                    )
                    """)
            }
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS specialAcquisitionAttempt (
                    kind TEXT PRIMARY KEY NOT NULL CHECK (kind IN ('exam', 'examReturn')),
                    payload BLOB NOT NULL
                )
                """)
            return try db.tableExists("specialSource")
        }
        acquisitionAttempts = (try? queue.read { db in
            var attempts: [SpecialScheduleKind: AcquisitionAttempt] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT kind, payload FROM specialAcquisitionAttempt WHERE length(payload) <= 4096") {
                let key: String = row["kind"]
                let bytes: Data = row["payload"]
                guard bytes.count <= 4096, let kind = SpecialScheduleKind(rawValue: key),
                      let attempt = try? JSONDecoder().decode(AcquisitionAttempt.self, from: bytes) else { continue }
                attempts[kind] = attempt
            }
            return attempts
        }) ?? [:]
        records = try queue.read { db in
            var result: [SpecialScheduleKind: SpecialScheduleRecord] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT kind, payload FROM specialSchedule") {
                let key: String = row["kind"]
                let data: Data = row["payload"]
                guard let kind = SpecialScheduleKind(rawValue: key),
                      let record = try? JSONDecoder().decode(SpecialScheduleRecord.self, from: data),
                      record.kind == kind, record.analysis.kind == kind,
                      record.digest == record.analysis.sourceDigest,
                      Self.valid(record.analysis),
                      record.storedName.hasSuffix(".pdf"),
                      UUID(uuidString: String(record.storedName.dropLast(4))) != nil,
                      manager.fileExists(atPath: files.appendingPathComponent(record.storedName).path) else {
                    throw StoreError.invalidState
                }
                result[kind] = record
            }
            return result
        }
        // The legacy schema had only accepted analyses. Upgrade it only when
        // those validated records account for every retained PDF copy.
        if !hasSources {
            let known = Set(records.values.map(\.storedName))
            guard storedFiles.allSatisfy({ known.contains($0.lastPathComponent) }) else { throw StoreError.invalidState }
            try queue.write { db in
                try db.execute(sql: """
                    CREATE TABLE specialSource (
                        kind TEXT PRIMARY KEY NOT NULL CHECK (kind IN ('exam', 'examReturn')),
                        payload BLOB NOT NULL
                    )
                    """)
            }
        }
        sources = try queue.read { db in
            var result: [SpecialScheduleKind: SpecialScheduleSource] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT kind, payload FROM specialSource") {
                let key: String = row["kind"]
                let data: Data = row["payload"]
                guard let kind = SpecialScheduleKind(rawValue: key),
                      let source = try? JSONDecoder().decode(SpecialScheduleSource.self, from: data),
                      source.kind == kind, source.byteCount > 0,
                      source.byteCount <= MaterialLibrary.maximumBytes,
                      source.storedName.hasSuffix(".pdf"),
                      UUID(uuidString: String(source.storedName.dropLast(4))) != nil,
                      manager.fileExists(atPath: files.appendingPathComponent(source.storedName).path) else {
                    throw StoreError.invalidState
                }
                result[kind] = source
            }
            return result
        }
        // Older installs stored the selected source together with its analysis.
        for (kind, record) in records where sources[kind] == nil {
            sources[kind] = SpecialScheduleSource(kind: kind, originalName: record.originalName,
                storedName: record.storedName, byteCount: record.byteCount, digest: record.digest,
                acquiredAt: record.acquiredAt, failure: nil, grant: nil)
        }
        try removeUnreferencedFiles()
        for kind in Array(records.keys) { try recertifyAccepted(kind:kind) }
    }

    func displayableRecords() -> (records: [SpecialScheduleKind: SpecialScheduleRecord], rejected: Set<SpecialScheduleKind>) {
        var visible = records
        var rejected = Set<SpecialScheduleKind>()
        for (kind, var record) in records where record.analysis.recovery != nil {
            if let proved = try? RecoveryConversion.recertifiedSpecial(record.analysis,hash:record.digest) {
                record.analysis = proved
                visible[kind] = record
            } else {
                visible.removeValue(forKey:kind)
                rejected.insert(kind)
            }
        }
        return (visible, rejected)
    }

    /// Revalidate only already accepted results; never confirm an old preview.
    @discardableResult
    func recertifyAccepted(kind: SpecialScheduleKind) throws -> Bool {
        guard let old = records[kind], sources[kind]?.digest == old.digest,
              let proved = try RecoveryConversion.recertifiedSpecial(old.analysis,hash:old.digest) else { return false }
        guard proved != old.analysis else { return true }
        let current = SpecialScheduleRecord(kind:old.kind,originalName:old.originalName,storedName:old.storedName,byteCount:old.byteCount,digest:old.digest,acquiredAt:old.acquiredAt,analysis:proved)
        let currentData = try JSONEncoder().encode(current)
        try queue.write { db in
            guard let persisted = try Data.fetchOne(db,sql:"SELECT payload FROM specialSchedule WHERE kind = ?",arguments:[kind.rawValue]),
                  let reread = try? JSONDecoder().decode(SpecialScheduleRecord.self,from:persisted),
                  try RecoveryValidator.fingerprint(reread) == RecoveryValidator.fingerprint(old),
                  let repeated = try RecoveryConversion.recertifiedSpecial(reread.analysis,hash:old.digest),
                  repeated == proved else { throw StoreError.invalidState }
            try db.execute(sql:"UPDATE specialSchedule SET payload = ? WHERE kind = ?",arguments:[currentData,kind.rawValue])
        }
        records[kind] = current
        return true
    }

    func newStagingURL() -> URL { staging.appendingPathComponent(UUID().uuidString) }

    func discardStaging(_ url: URL) {
        guard url.deletingLastPathComponent().standardizedFileURL == staging.standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func savedURL(for kind: SpecialScheduleKind) -> URL? {
        records[kind].map { files.appendingPathComponent($0.storedName) }
    }

    func selectedURL(for kind: SpecialScheduleKind) -> URL? {
        sources[kind].map { files.appendingPathComponent($0.storedName) }
    }

    func hasSelectedFile(_ kind: SpecialScheduleKind) -> Bool {
        selectedURL(for: kind).map { FileManager.default.fileExists(atPath: $0.path) } == true
    }

    func saveSelection(staged: URL, kind: SpecialScheduleKind, originalName: String,
                       byteCount: Int, digest: String, grant: SourceGrant? = nil) throws {
        guard staged.deletingLastPathComponent().standardizedFileURL == staging.standardizedFileURL,
              byteCount > 0, byteCount <= MaterialLibrary.maximumBytes,
              !digest.isEmpty else { throw StoreError.invalidState }
        let storedName = UUID().uuidString + ".pdf"
        let destination = files.appendingPathComponent(storedName)
        try FileManager.default.moveItem(at: staged, to: destination)
        let now = Date()
        let source = SpecialScheduleSource(kind: kind, originalName: originalName,
            storedName: storedName, byteCount: byteCount, digest: digest,
            acquiredAt: now, lastAcquiredAt: now, lastCheckedAt: now, failure: nil, grant: grant)
        do {
            let payload = try JSONEncoder().encode(source)
            try queue.write { db in
                try db.execute(sql: "INSERT INTO specialSource (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload",
                               arguments: [kind.rawValue, payload])
                try Self.writeAcquisitionAttempt(nil, kind: kind, db: db)
            }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        sources[kind] = source
        acquisitionAttempts[kind] = nil
        try? removeUnreferencedFiles()
    }

    func recordSuccessfulCheck(_ kind: SpecialScheduleKind, digest: String, originalName: String? = nil,
                               checkedAt: Date = Date(), renewedGrant: SourceGrant? = nil) throws {
        guard var source = sources[kind], source.digest == digest else { throw StoreError.invalidState }
        if let originalName {
            guard !originalName.isEmpty else { throw StoreError.invalidState }
            source.originalName = originalName
        }
        if let renewedGrant { source.grant = renewedGrant }
        source.lastCheckedAt = checkedAt
        source.lastAcquiredAt = checkedAt
        source.acquisitionFailure = nil
        let payload = try JSONEncoder().encode(source)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO specialSource (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload",
                           arguments: [kind.rawValue, payload])
            try Self.writeAcquisitionAttempt(nil, kind: kind, db: db)
        }
        sources[kind] = source
        acquisitionAttempts[kind] = nil
    }

    func saveAnalysis(_ analysis: SpecialScheduleAnalysis) throws {
        guard let source = sources[analysis.kind], analysis.sourceDigest == source.digest,
              analysis.sourceName == source.originalName,
              analysis.version == SpecialScheduleAnalysis.parserVersion, Self.valid(analysis) else {
            throw StoreError.invalidState
        }
        let record = SpecialScheduleRecord(kind: analysis.kind, originalName: source.originalName,
            storedName: source.storedName, byteCount: source.byteCount, digest: source.digest,
            acquiredAt: source.acquiredAt, analysis: analysis)
        var cleared = source
        cleared.failure = nil
        cleared.recoveryJob = nil
        cleared.attemptParserVersion = SpecialScheduleAnalysis.parserVersion
        let recordPayload = try JSONEncoder().encode(record)
        let sourcePayload = try JSONEncoder().encode(cleared)
        try queue.write { db in
            if analysis.recovery?.previousAcceptance != nil {
                guard let payload = try Data.fetchOne(db,sql:"SELECT payload FROM specialSchedule WHERE kind = ?",arguments:[analysis.kind.rawValue]),
                      let old = try? JSONDecoder().decode(SpecialScheduleRecord.self,from:payload),
                      let proved = try RecoveryConversion.recertifiedSpecial(old.analysis,hash:source.digest),
                      proved == analysis else { throw StoreError.invalidState }
            }
            try db.execute(sql: "INSERT INTO specialSchedule (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload",
                           arguments: [analysis.kind.rawValue, recordPayload])
            try db.execute(sql: "INSERT INTO specialSource (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload",
                           arguments: [analysis.kind.rawValue, sourcePayload])
        }
        records[analysis.kind] = record
        sources[analysis.kind] = cleared
        try? removeUnreferencedFiles()
    }

    static func writeAcquisitionAttempt(_ attempt: AcquisitionAttempt?, kind: SpecialScheduleKind, db: Database) throws {
        if let attempt {
            try db.execute(sql: "INSERT INTO specialAcquisitionAttempt (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload",
                           arguments: [kind.rawValue, try JSONEncoder().encode(attempt)])
        } else {
            try db.execute(sql: "DELETE FROM specialAcquisitionAttempt WHERE kind = ?", arguments: [kind.rawValue])
        }
    }

    func recordAcquisitionFailure(kind: SpecialScheduleKind, error: Error = MaterialError.unavailable) throws {
        let problem = AcquisitionProblem(error)
        let attempt = AcquisitionAttempt(date: Date(), failure: problem.message, problem: problem)
        var source = sources[kind]
        source?.acquisitionFailure = problem.message
        try queue.write { db in
            try Self.writeAcquisitionAttempt(attempt, kind: kind, db: db)
            if let source {
                let payload = try JSONEncoder().encode(source)
                try db.execute(sql: "INSERT INTO specialSource (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload", arguments: [kind.rawValue, payload])
            }
        }
        acquisitionAttempts[kind] = attempt
        sources[kind] = source
    }

    func recordFailure(_ failure: PDFParseError, kind: SpecialScheduleKind) throws {
        guard var source = sources[kind] else { throw StoreError.invalidState }
        let recoveryKind: RecoveryDocumentKind = kind == .exam ? .exam : .return
        let parserVersion = SpecialScheduleAnalysis.parserVersion
        if failure.code == .cancelled, source.recoveryJob?.state == .pending,
           RecoveryPolicy.mayRecover(digest: source.digest, kind: recoveryKind, parserVersion: parserVersion,
                                     attemptDigest: source.digest, attemptVersion: source.attemptParserVersion,
                                     failure: source.failure, job: source.recoveryJob) { return }
        source.failure = failure
        source.attemptParserVersion = parserVersion
        source.recoveryJob = RecoveryPolicy.eligible(failure) && !(records[kind]?.analysis.version == parserVersion && RecoveryValidator.previouslyAccepted(records[kind]?.analysis.recovery,hash:source.digest)) ? RecoveryJob(pdfHash: source.digest,
            kind: recoveryKind, state: .pending, createdAt: Date()) : nil
        let payload = try JSONEncoder().encode(source)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO specialSource (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload",
                           arguments: [kind.rawValue, payload])
        }
        sources[kind] = source
    }

    func save(staged: URL, analysis: SpecialScheduleAnalysis, originalName: String,
              byteCount: Int, digest: String) throws {
        guard staged.deletingLastPathComponent().standardizedFileURL == staging.standardizedFileURL,
              analysis.sourceDigest == digest,
              analysis.sourceName == originalName,
              analysis.version == SpecialScheduleAnalysis.parserVersion, Self.valid(analysis), byteCount > 0,
              byteCount <= MaterialLibrary.maximumBytes else {
            throw StoreError.invalidState
        }
        try saveSelection(staged: staged, kind: analysis.kind, originalName: originalName,
                          byteCount: byteCount, digest: digest)
        try saveAnalysis(analysis)
    }

    private static func valid(_ analysis: SpecialScheduleAnalysis) -> Bool {
        let count = analysis.kind == .exam ? 6 : 8
        func hasStoredTime(_ lesson: SpecialScheduleLesson) -> Bool {
            if analysis.timeRange(for: lesson) != nil { return true }
            // Preserve the previous acceptance contract for legacy cache loads.
            // This validates old bytes only; display never guesses their PDF order.
            guard analysis.version < 33, analysis.kind == .examReturn, analysis.dedicatedTimeDate == nil else { return false }
            func oldClock(_ period: Int) -> String? {
                if lesson.date == analysis.coveredDates.first { return analysis.periodTimes[period] }
                guard (1...TimetableSchedule.normalPeriodTimes.count).contains(period) else { return nil }
                return TimetableSchedule.normalPeriodTimes[period - 1]
            }
            return oldClock(lesson.spanStart)?.components(separatedBy: "〜").first != nil &&
                oldClock(lesson.spanEnd)?.components(separatedBy: "〜").last != nil
        }
        guard (4...SpecialScheduleAnalysis.parserVersion).contains(analysis.version) else { return false }
        if analysis.kind == .examReturn {
            guard analysis.coveredDates.count == 5, analysis.coveredClasses.count == 17 else { return false }
        }
        let scopeIsValid: Bool
        if analysis.scopes != nil {
            scopeIsValid = analysis.validScopes
        } else {
            scopeIsValid = analysis.version < 35 && analysis.coveredDates.count == 5 && analysis.coveredClasses.count == 17
        }
        guard scopeIsValid, analysis.strictComparisonCoverage == nil || analysis.validStrictComparisonCoverage else { return false }
        let dates = Set(analysis.coveredDates)
        let classes = Set(analysis.coveredClasses)
        guard dates.count == analysis.coveredDates.count, classes.count == analysis.coveredClasses.count else { return false }
        guard analysis.periodTimes.count == count, !analysis.lessons.isEmpty else { return false }
        if let dedicated = analysis.dedicatedTimeDate {
            guard dates.contains(dedicated) else { return false }
        }
        if analysis.version >= 33, analysis.kind == .examReturn, analysis.recovery == nil {
            guard analysis.dedicatedTimeDate != nil else { return false }
        }
        for lesson in analysis.lessons {
            guard (1...count).contains(lesson.period) else { return false }
            guard (1...lesson.period).contains(lesson.spanStart),
                  (lesson.period...count).contains(lesson.spanEnd) else { return false }
            guard dates.contains(lesson.date), classes.contains(lesson.sourceClassName ?? lesson.className) else { return false }
            if analysis.version >= 31 {
                guard PDFClassAssignment.assign(lesson) == lesson else { return false }
            }
            guard analysis.applies(date:lesson.date,className:lesson.className) else { return false }
            if analysis.version >= 6 {
                guard hasStoredTime(lesson) else { return false }
            }
        }
        return true
    }

    private func removeUnreferencedFiles() throws {
        let manager = FileManager.default
        let keep = Set(records.values.map(\.storedName) + sources.values.map(\.storedName))
        for file in try manager.contentsOfDirectory(at: files, includingPropertiesForKeys: nil) where !keep.contains(file.lastPathComponent) {
            try SavedPDFLease.retire(file)
        }
        for file in try manager.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil) {
            try manager.removeItem(at: file)
        }
    }
}
