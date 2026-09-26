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
        do {
            let database = try LocalMaterialDatabase(url: root.appendingPathComponent("library.sqlite"))
            database.libraryLock = lease
            return try MaterialLibrary(root: root, persistence: database)
        } catch {
            // Do not expose SQL or payloads in a user-visible acquisition error.
            throw MaterialError.invalidState
        }
    }

    private static func protect(_ url: URL) throws {
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
