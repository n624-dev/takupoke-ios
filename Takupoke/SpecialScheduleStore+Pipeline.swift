import Foundation
import GRDB

extension SpecialScheduleStore {
    struct PipelineSnapshot {
        let sources: [SpecialScheduleKind: SpecialScheduleSource]
        let records: [SpecialScheduleKind: SpecialScheduleRecord]
        let acquisitionAttempts: [SpecialScheduleKind: AcquisitionAttempt]
        let inputs: [(URL, String)]
        func open(at root: URL) throws -> SpecialScheduleStore {
            let copy = try SpecialScheduleStore(root: root)
            for (url, name) in inputs { try PipelineWorkspace.copyIfPresent(url, to: copy.files.appendingPathComponent(name)) }
            try copy.queue.write { db in
                for (kind, source) in sources {
                    try db.execute(sql: "INSERT INTO specialSource (kind,payload) VALUES (?,?)", arguments: [kind.rawValue, try JSONEncoder().encode(source)])
                }
                for (kind, record) in records {
                    try db.execute(sql: "INSERT INTO specialSchedule (kind,payload) VALUES (?,?)", arguments: [kind.rawValue, try JSONEncoder().encode(record)])
                }
                for (kind, attempt) in acquisitionAttempts {
                    try SpecialScheduleStore.writeAcquisitionAttempt(attempt, kind: kind, db: db)
                }
            }
            copy.sources = sources; copy.records = records; copy.acquisitionAttempts = acquisitionAttempts
            return copy
        }
    }
    func pipelineSnapshot(_ kind: SpecialScheduleKind? = nil) -> PipelineSnapshot {
        let sources = self.sources.filter { kind == nil || $0.key == kind }
        let records = self.records.filter { kind == nil || $0.key == kind }
        let attempts = acquisitionAttempts.filter { kind == nil || $0.key == kind }
        let names = Set(sources.values.map(\.storedName) + records.values.map(\.storedName))
        return PipelineSnapshot(sources: sources, records: records, acquisitionAttempts: attempts,
                                inputs: names.map { (files.appendingPathComponent($0), $0) })
    }
    func isolatedCopy(at root: URL) throws -> SpecialScheduleStore { try pipelineSnapshot().open(at: root) }
    func pipelineIdentity(_ kind: SpecialScheduleKind) throws -> Data {
        struct Identity: Encodable { let source: SpecialScheduleSource?; let record: SpecialScheduleRecord? }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        var source = sources[kind]
        source?.acquisitionFailure = nil
        return try encoder.encode(Identity(source: source, record: records[kind]))
    }
    func acceptPipeline(_ copy: SpecialScheduleStore, kind: SpecialScheduleKind, expected: Data, ticket: FilePipeline.Ticket) throws {
        guard try pipelineIdentity(kind) == expected else { throw FilePipeline.Failure.stale }
        try ticket.beginCommit(period: .current())
        let oldNames = Set([sources[kind]?.storedName, records[kind]?.storedName].compactMap { $0 })
        let source = copy.sources[kind], record = copy.records[kind]
        let names = Set([source?.storedName, record?.storedName].compactMap { $0 })
        var imported: [URL] = []
        do {
            for name in names where !FileManager.default.fileExists(atPath: files.appendingPathComponent(name).path) {
                let destination = files.appendingPathComponent(name)
                let input = copy.files.appendingPathComponent(name)
                if oldNames.contains(name), !FileManager.default.fileExists(atPath: input.path) { continue }
                try FileManager.default.moveItem(at: input, to: destination)
                imported.append(destination)
            }
            try queue.write { db in
                if let source {
                    try db.execute(sql: "INSERT INTO specialSource(kind,payload) VALUES (?,?) ON CONFLICT(kind) DO UPDATE SET payload=excluded.payload", arguments: [kind.rawValue, try JSONEncoder().encode(source)])
                }
                if let record {
                    try db.execute(sql: "INSERT INTO specialSchedule(kind,payload) VALUES (?,?) ON CONFLICT(kind) DO UPDATE SET payload=excluded.payload", arguments: [kind.rawValue, try JSONEncoder().encode(record)])
                }
                try Self.writeAcquisitionAttempt(copy.acquisitionAttempts[kind], kind: kind, db: db)
            }
            if sources[kind]?.storedName != source?.storedName { pipelineEvidence.removeValue(forKey: kind) }
            if let source { sources[kind] = source }
            if let record { records[kind] = record }
            acquisitionAttempts[kind] = copy.acquisitionAttempts[kind]
            if let evidence = copy.pipelineEvidence[kind] { pipelineEvidence[kind] = evidence }
            ticket.didCommit()
            let retired = oldNames.subtracting(Set(sources.values.map(\.storedName) + records.values.map(\.storedName)))
            let directory = files
            DispatchQueue.global(qos: .utility).async {
                for name in retired { try? FileManager.default.removeItem(at: directory.appendingPathComponent(name)) }
            }
        } catch {
            for url in imported { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }
}

struct SpecialPipelineEvidence {
    let storedName: String?
    let digest: String?
    let report: String?
    let failure: PDFParseError?
    let pages: [RecoveryReadPage]?
}
