import Foundation
import GRDB
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Local storage for completed acquisitions and analyses. No timetable adoption or legacy fallback.
final class LocalMaterialDatabase: MaterialLibraryPersistence {
    enum StoreError: Error { case invalidDatabase, unsupportedSchema, incompleteMigration, staleState }
    static let schemaVersion = 2
    private static let applicationID = 0x544B504B // TKPK
    let queue: DatabaseQueue
    var generation: Int64?
    private var libraryLock: LibraryLock?
    // Tests inject a failure inside the transaction, before the current state commits.
    var beforeCommit: () throws -> Void = {}

    /// Creation is explicit: opening a missing database must never silently initialize it.
    init(url: URL, create: Bool = false) throws {
        let exists = FileManager.default.fileExists(atPath: url.path)
        guard create != exists else { throw StoreError.invalidDatabase }
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.publicStatementArguments = false
        config.prepareDatabase { db in
            if !create {
                guard try Int.fetchOne(db, sql: "PRAGMA application_id") == Self.applicationID else {
                    throw StoreError.invalidDatabase
                }
                guard try Int.fetchOne(db, sql: "PRAGMA user_version") == Self.schemaVersion else {
                    throw StoreError.unsupportedSchema
                }
                guard try String.fetchOne(db, sql: "PRAGMA journal_mode") == "delete" else {
                    throw StoreError.invalidDatabase
                }
            } else {
                try db.execute(sql: "PRAGMA journal_mode = DELETE")
            }
            try db.execute(sql: "PRAGMA synchronous = FULL")
            guard try Int.fetchOne(db, sql: "PRAGMA foreign_keys") == 1,
                  try Int.fetchOne(db, sql: "PRAGMA synchronous") == 2 else {
                throw StoreError.invalidDatabase
            }
        }
        queue = try DatabaseQueue(path: url.path, configuration: config)
        if create {
            try queue.write { db in
                try db.execute(sql: Self.schema)
                try db.execute(sql: "PRAGMA application_id = \(Self.applicationID)")
                try db.execute(sql: "PRAGMA user_version = \(Self.schemaVersion)")
            }
        }
    }

    func close() throws {
        try queue.close()
        libraryLock = nil
    }

}

extension LocalMaterialDatabase {
    /// Called by the single acquisition worker, before any jobs or PDF views exist.
    /// Publish a complete empty store with a directory rename. Never initialize an
    /// existing store, even if its database is missing, locked, or unreadable.
    static func openLibrary(root: URL) throws -> MaterialLibrary {
        let manager = FileManager.default
        let lockURL = root.deletingLastPathComponent().appendingPathComponent(root.lastPathComponent + ".lock")
        let lease = try LibraryLock(url: lockURL)
        try protect(lockURL)
        let pending = root.deletingLastPathComponent()
            .appendingPathComponent(root.lastPathComponent + ".initializing", isDirectory: true)
        if manager.fileExists(atPath: pending.path) {
            try manager.removeItem(at: pending) // Only this initializer owns this sibling.
        }
        if !manager.fileExists(atPath: root.path) {
            try manager.createDirectory(at: pending, withIntermediateDirectories: false)
            defer { try? manager.removeItem(at: pending) }
            try protect(pending)
            for name in ["files", "staging"] {
                let directory = pending.appendingPathComponent(name, isDirectory: true)
                try manager.createDirectory(at: directory, withIntermediateDirectories: false)
                try protect(directory)
            }
            let url = pending.appendingPathComponent("library.sqlite")
            let database = try LocalMaterialDatabase(url: url, create: true)
            do {
                try database.initializeCurrentLibrary()
                try database.close()
            } catch {
                try? database.close()
                throw error
            }
            try protect(url)
            let verified = try LocalMaterialDatabase(url: url)
            do {
                _ = try verified.load()
                try verified.close()
            } catch {
                try? verified.close()
                throw error
            }
            try manager.moveItem(at: pending, to: root)
        }
        let recovered = root.appendingPathComponent("recovered", isDirectory: true)
        let activeRoot = manager.fileExists(atPath: recovered.path) ? recovered : root
        func open(_ directory: URL) throws -> MaterialLibrary {
            let database = try LocalMaterialDatabase(url: directory.appendingPathComponent("library.sqlite"))
            database.libraryLock = lease
            return try MaterialLibrary(root: directory, persistence: database)
        }
        do {
            return try open(activeRoot)
        } catch {
            if activeRoot == root, (try? recoverReadableMaterials(from: root, to: recovered)) == true,
               let library = try? open(recovered) {
                return library
            }
            throw MaterialError.invalidState
        }
    }

    private static func recoverReadableMaterials(from root: URL, to recovered: URL) throws -> Bool {
        let manager = FileManager.default
        let original = try LocalMaterialDatabase(url: root.appendingPathComponent("library.sqlite"))
        defer { try? original.close() }
        guard try original.queue.read({ try String.fetchOne($0, sql: "PRAGMA quick_check") }) == "ok" else { return false }
        let pending = root.appendingPathComponent("recovery-staging", isDirectory: true)
        if manager.fileExists(atPath: pending.path) { try manager.removeItem(at: pending) }
        try manager.createDirectory(at: pending, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: pending) }
        try protect(pending)
        let databaseURL = pending.appendingPathComponent("library.sqlite")
        let candidate = try LocalMaterialDatabase(url: databaseURL, create: true)
        defer { try? candidate.close() }
        try original.queue.backup(to: candidate.queue)
        try protect(databaseURL)
        let files = root.appendingPathComponent("files", isDirectory: true)
        var readable = Set<MaterialKind>()
        var damaged = Set<MaterialKind>()
        for kind in MaterialKind.allCases {
            do {
                let hasRecord = try candidate.queue.writeWithoutTransaction { db in
                    var hasRecord = false
                    try db.inSavepoint {
                        try discardTypes(in: db, keeping: [kind])
                        let (state, _) = try currentSnapshot(db)
                        let originals = try verifiedOriginals(in: db, directory: files)
                        if let record = state.record(for: kind) {
                            guard originals.contains(record.storedName) else { throw StoreError.invalidDatabase }
                            hasRecord = true
                        }
                        return .rollback
                    }
                    return hasRecord
                }
                if hasRecord { readable.insert(kind) }
            } catch StoreError.invalidDatabase {
                damaged.insert(kind)
            } catch MaterialError.invalidState {
                damaged.insert(kind)
            } catch is DecodingError {
                damaged.insert(kind)
            }
        }
        guard !readable.isEmpty, !damaged.isEmpty else { return false }
        let names = try candidate.queue.write { db in
            try discardTypes(in: db, keeping: Set(MaterialKind.allCases).subtracting(damaged))
            guard try Row.fetchAll(db, sql: "PRAGMA foreign_key_check").isEmpty else { throw StoreError.invalidDatabase }
            _ = try currentSnapshot(db)
            return try verifiedOriginals(in: db, directory: files)
        }
        let destination = pending.appendingPathComponent("files", isDirectory: true)
        try manager.createDirectory(at: destination, withIntermediateDirectories: false)
        try protect(destination)
        for name in names {
            let target = destination.appendingPathComponent(name)
            try manager.copyItem(at: files.appendingPathComponent(name), to: target)
            try protect(target)
        }
        let verified = try MaterialLibrary(root: pending, persistence: candidate)
        guard Set(verified.state.records.map(\.kind)) == readable else { return false }
        try candidate.close()
        try manager.moveItem(at: pending, to: recovered)
        return true
    }

    private static func discardTypes(in db: Database, keeping kept: Set<MaterialKind>) throws {
        for kind in MaterialKind.allCases where !kept.contains(kind) {
            for table in ["currentRecord", "currentAnalysis", "lesson", "changeRow", "analysis", "original", "source", "attempt"] {
                try db.execute(sql: "DELETE FROM \(table) WHERE kind = ?", arguments: [kind.rawValue])
            }
        }
    }

    private static func verifiedOriginals(in db: Database, directory: URL) throws -> Set<String> {
        var names = Set<String>()
        for row in try Row.fetchAll(db, sql: "SELECT record, kind, storedName, digest FROM original") {
            guard let bytes: Data = row["record"] else { throw StoreError.invalidDatabase }
            let record = try decode(MaterialRecord.self, bytes)
            var manifest = MaterialLibraryState()
            manifest.records = [record]
            _ = try MaterialLibrary.decodeLegacyManifest(encode(manifest))
            guard row["kind"] as String == record.kind.rawValue, row["storedName"] as String == record.storedName,
                  row["digest"] as String == record.digest else { throw StoreError.invalidDatabase }
            guard try MaterialFileReader.matchesStoredCopy(directory.appendingPathComponent(record.storedName),
                byteCount: record.byteCount, digest: record.digest, isWorkbook: record.kind == .changes)
            else { throw StoreError.invalidDatabase }
            names.insert(record.storedName)
        }
        return names
    }

    static func protect(_ url: URL) throws {
        #if os(iOS) || os(macOS)
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try target.setResourceValues(values)
        #endif
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
    }


}

/// Keep acquisition, startup collection and PDF-view lifetimes in one owner.
/// A second worker/process must fail before touching staging or initialization.
private final class LibraryLock {
    private let descriptor: Int32

    init(url: URL) throws {
        descriptor = open(url.path, O_CREAT | O_RDWR, mode_t(0o600))
        guard descriptor >= 0 else { throw MaterialError.invalidState }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            _ = close(descriptor)
            throw MaterialError.invalidState
        }
    }

    deinit {
        _ = flock(descriptor, LOCK_UN)
        _ = close(descriptor)
    }
}
