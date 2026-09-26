import Foundation
import GRDB

/// The validated package and its corresponding public revision change in one SQLite transaction.

final class MappingStore {
    private let queue: DatabaseQueue

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
            let saved = try JSONDecoder().decode(SavedMapping.self, from: data)
            guard [1, 2].contains(saved.schemaVersion), MappingPackage.validRevision(saved.revision) else {
                throw MappingError.storage
            }
            try MappingPackage.validate(saved.rules, schemaVersion: saved.schemaVersion)
            return saved
        }
    }

    func save(_ mapping: SavedMapping) throws {
        let data = try JSONEncoder().encode(mapping)
        try queue.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO currentMapping (id, payload) VALUES (1, ?)", arguments: [data])
        }
    }
}
