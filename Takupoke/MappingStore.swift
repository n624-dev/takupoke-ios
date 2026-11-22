import Foundation
import GRDB

/// The validated package and its corresponding public revision change in one SQLite transaction.

final class MappingStore {
    enum InvalidPayload: Error { case corrupt }
    private let queue: DatabaseQueue

    struct DamagedFile {
        private static let maximumBytes = 16 * 1024 * 1024
        private static let stagingName = "MappingReplacement"
        private let url: URL
        private let original: Data

        init?(url: URL, error: Error) throws {
            guard let code = (error as? DatabaseError)?.resultCode,
                  code == .SQLITE_NOTADB || code == .SQLITE_CORRUPT,
                  let original = try Self.readIsolatedDatabase(at:url) else { return nil }
            self.url = url
            self.original = original
        }

        func install(_ mapping: SavedMapping) throws {
            try Task.checkCancellation()
            let manager = FileManager.default
            let root = url.deletingLastPathComponent()
            try Self.discardAbandonedStage(in:root)
            let stage = root.appendingPathComponent(Self.stagingName, isDirectory:true)
            try manager.createDirectory(at:stage,withIntermediateDirectories:false)
            defer { try? manager.removeItem(at:stage) }
            #if os(iOS)
            try manager.setAttributes([.protectionKey: FileProtectionType.complete],ofItemAtPath:stage.path)
            #endif
            let stagingFile = stage.appendingPathComponent(url.lastPathComponent)
            do {
                let store = try MappingStore(url:stagingFile)
                try store.save(mapping)
                guard try store.load() == mapping else { throw MappingError.storage }
            }
            let replacement = try Data(contentsOf:stagingFile)
            try Task.checkCancellation()
            guard try Self.readIsolatedDatabase(at:url) == original else { throw MappingError.storage }

            let backup = root.appendingPathComponent("mappings-damaged-\(UUID().uuidString).sqlite")
            try Self.write(original,to:backup)
            do {
                try Task.checkCancellation()
                guard try Self.readIsolatedDatabase(at:url) == original else { throw MappingError.storage }
                try Self.write(replacement,to:url)
            } catch {
                if (try? Self.readIsolatedDatabase(at:url)) == original { try? manager.removeItem(at:backup) }
                throw error
            }
        }

        static func discardAbandonedStage(in root: URL) throws {
            let stage = root.appendingPathComponent(stagingName, isDirectory:true)
            let manager = FileManager.default
            let attributes: [FileAttributeKey:Any]
            do { attributes = try manager.attributesOfItem(atPath:stage.path) }
            catch let error as CocoaError where [.fileNoSuchFile,.fileReadNoSuchFile].contains(error.code) { return }
            guard attributes[.type] as? FileAttributeType == .typeDirectory else { throw MappingError.storage }
            try manager.removeItem(at:stage)
        }

        private static func readIsolatedDatabase(at url: URL) throws -> Data? {
            let manager = FileManager.default
            for suffix in ["-journal", "-wal", "-shm"] {
                do {
                    _ = try manager.attributesOfItem(atPath:url.path + suffix)
                    return nil
                } catch let error as CocoaError where [.fileNoSuchFile,.fileReadNoSuchFile].contains(error.code) {}
            }
            let attributes = try manager.attributesOfItem(atPath:url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? NSNumber, size.intValue <= maximumBytes else { return nil }
            let handle = try FileHandle(forReadingFrom:url)
            defer { try? handle.close() }
            var bytes = Data()
            while let chunk = try handle.read(upToCount:65_536), !chunk.isEmpty {
                guard bytes.count + chunk.count <= maximumBytes else { return nil }
                bytes.append(chunk)
            }
            return bytes.count == size.intValue ? bytes : nil
        }

        private static func write(_ data: Data, to url: URL) throws {
            #if os(iOS)
            try data.write(to:url,options:[.atomic,.completeFileProtection])
            #else
            try data.write(to:url,options:.atomic)
            #endif
        }
    }

    init(url: URL) throws {
        var config = Configuration()
        config.publicStatementArguments = false
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = DELETE")
            try db.execute(sql: "PRAGMA synchronous = FULL")
        }
        queue = try DatabaseQueue(path: url.path, configuration: config)
        try queue.write { db in
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS currentMapping (id INTEGER PRIMARY KEY CHECK (id = 1), payload BLOB NOT NULL)")
        }
    }

    func load() throws -> SavedMapping? {
        try queue.read { db in
            guard let data = try Data.fetchOne(db, sql: "SELECT payload FROM currentMapping WHERE id = 1") else { return nil }
            do {
                let saved = try JSONDecoder().decode(SavedMapping.self, from: data)
                guard [1, 2].contains(saved.schemaVersion), MappingPackage.validRevision(saved.revision) else { throw InvalidPayload.corrupt }
                try MappingPackage.validate(saved.rules, schemaVersion: saved.schemaVersion)
                return saved
            } catch { throw InvalidPayload.corrupt }
        }
    }

    func save(_ mapping: SavedMapping) throws {
        let data = try JSONEncoder().encode(mapping)
        try queue.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO currentMapping (id, payload) VALUES (1, ?)", arguments: [data])
        }
    }
}
