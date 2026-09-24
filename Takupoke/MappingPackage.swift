import Foundation
import CryptoKit
import ZIPFoundation
import GRDB

enum MappingError: Error, LocalizedError {
    case invalidPackage, invalidResponse, authentication, unavailable, storage, changedDuringDownload

    var errorDescription: String? {
        switch self {
        case .invalidPackage: return "名称対応表の形式または整合性を確認できませんでした。"
        case .invalidResponse: return "名称対応表の配信応答を確認できませんでした。"
        case .authentication: return "認証を完了できませんでした。"
        case .unavailable: return "名称対応表を取得できませんでした。"
        case .storage: return "名称対応表を保存できませんでした。"
        case .changedDuringDownload: return "取得中に名称対応表が更新されました。もう一度お試しください。"
        }
    }
}

struct MappingRule: Codable, Equatable {
    let alias: String
    let fullName: String
    let classes: [String]?
    let internationalStudent: Bool?
}

struct ChangePresentation: Equatable {
    let before: TimetableLessonNames
    let after: TimetableLessonNames

    static func source(_ change: ScheduleChange) -> Self {
        Self(before: TimetableLessonNames(subject: change.before_subject),
             after: TimetableLessonNames(subject: change.after_subject,
                                         teacher: change.teacher, room: change.room))
    }
}

struct MappingRules: Codable, Equatable {
    let subjects: [MappingRule]
    let teachers: [MappingRule]
    let rooms: [MappingRule]

    func applying(to names: TimetableLessonNames, className: String) -> TimetableLessonNames {
        TimetableLessonNames(subject: names.subject, teacher: names.teacher, room: names.room,
            subjectFullName: match(names.subject, in: subjects, className: className) ?? names.subjectFullName,
            teacherFullName: match(names.teacher, in: teachers) ?? names.teacherFullName,
            roomFullName: match(names.room, in: rooms) ?? names.roomFullName)
    }

    func isInternationalStudentSubject(_ alias: String, className: String) -> Bool {
        guard !alias.isEmpty else { return false }
        func matching(_ rules: [MappingRule]) -> MappingRule? {
            rules.first(where: { $0.classes?.contains(className) == true }) ??
                rules.first(where: { $0.classes == nil })
        }
        if let exact = matching(subjects.filter({ $0.alias == alias })) {
            return exact.internationalStudent == true
        }
        let derived = subjects.filter { rule in
            rule.internationalStudent == true && rule.alias.hasPrefix("留 ") &&
                String(rule.alias.dropFirst(2)) == alias
        }
        return matching(derived)?.internationalStudent == true
    }

    /// Split only trailing metadata confirmed by the installed mapping. A
    /// subject component such as 「架空科目X（分野A）」 remains part of the subject.
    func separatingChangeField(_ source: String) -> TimetableLessonNames {
        var remaining = source.trimmingCharacters(in: .whitespacesAndNewlines)
        var teacher = ""
        var room = ""
        while let closing = remaining.last, closing == ")" || closing == "）" {
            let opening: Character = closing == ")" ? "(" : "（"
            var depth = 0
            var openingIndex: String.Index?
            for index in remaining.indices.reversed() {
                let character = remaining[index]
                if character == closing { depth += 1 }
                else if character == opening {
                    depth -= 1
                    if depth == 0 { openingIndex = index; break }
                }
            }
            guard let openingIndex, depth == 0 else { break }
            let token = String(remaining[remaining.index(after: openingIndex)..<remaining.index(before: remaining.endIndex)])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let isTeacher = teachers.contains { $0.alias == token }
            let isRoom = rooms.contains { $0.alias == token }
            guard isTeacher != isRoom else { break }
            if isTeacher {
                guard teacher.isEmpty else { break }
                teacher = token
            } else {
                guard room.isEmpty else { break }
                room = token
            }
            remaining = String(remaining[..<openingIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return TimetableLessonNames(subject: remaining, teacher: teacher, room: room)
    }

    func presenting(_ change: ScheduleChange) -> ChangePresentation {
        let before = separatingChangeField(change.before_subject)
        let inlineAfter = separatingChangeField(change.after_subject)
        let teacherConflict = !change.teacher.isEmpty && !inlineAfter.teacher.isEmpty &&
            change.teacher != inlineAfter.teacher
        let roomConflict = !change.room.isEmpty && !inlineAfter.room.isEmpty &&
            change.room != inlineAfter.room
        // A rare disagreement between two explicit source fields is left in
        // source form; the app must not silently discard either value.
        let after: TimetableLessonNames
        if teacherConflict || roomConflict {
            after = TimetableLessonNames(subject: change.after_subject,
                teacher: change.teacher, room: change.room)
        } else {
            after = TimetableLessonNames(subject: inlineAfter.subject,
                teacher: change.teacher.isEmpty ? inlineAfter.teacher : change.teacher,
                room: change.room.isEmpty ? inlineAfter.room : change.room)
        }
        return ChangePresentation(before: applying(to: before, className: change.displayClassName),
                                  after: applying(to: after, className: change.displayClassName))
    }

    private func match(_ alias: String, in rules: [MappingRule], className: String? = nil) -> String? {
        guard !alias.isEmpty else { return nil }
        let matches = rules.filter { $0.alias == alias }
        if let className, let specific = matches.first(where: { $0.classes?.contains(className) == true }) {
            return specific.fullName
        }
        return matches.first(where: { $0.classes == nil })?.fullName
    }
}

struct SavedMapping: Codable, Equatable {
    let revision: String
    let version: String
    let schemaVersion: Int
    let archiveETag: String
    let archiveSHA256: String
    let publishedAt: String
    let fetchedAt: Date
    let rules: MappingRules
}

enum MappingPackage {
    private struct Digest: Decodable { let sha256: String; let bytes: Int }
    private struct Manifest: Decodable {
        let schemaVersion: Int
        let version: String
        let publishedAt: String
        let mappings: Digest
    }

    static func validRevision(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil
    }

    static func decode(_ zip: Data, version: String, revision: String, archiveETag: String,
                       fetchedAt: Date = Date()) throws -> SavedMapping {
        guard !zip.isEmpty, zip.count <= 8 * 1024 * 1024,
              validRevision(revision), !archiveETag.isEmpty, archiveETag.count <= 256,
              version.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", options: .regularExpression) != nil,
              let archive = try? Archive(data: zip, accessMode: .read) else { throw MappingError.invalidPackage }
        var entries: [String: Entry] = [:]
        for entry in archive {
            guard entry.type == .file, entry.uncompressedSize <= 4 * 1024 * 1024,
                  entries[entry.path] == nil, ["manifest.json", "mappings.json"].contains(entry.path) else {
                throw MappingError.invalidPackage
            }
            entries[entry.path] = entry
        }
        guard entries.count == 2 else { throw MappingError.invalidPackage }
        func extract(_ name: String) throws -> Data {
            guard let entry = entries[name] else { throw MappingError.invalidPackage }
            var data = Data()
            do {
                let crc = try archive.extract(entry, bufferSize: 32 * 1024, skipCRC32: false) { chunk in
                    guard data.count + chunk.count <= 4 * 1024 * 1024 else { throw MappingError.invalidPackage }
                    data.append(chunk)
                }
                guard data.count == entry.uncompressedSize, crc == entry.checksum else { throw MappingError.invalidPackage }
                return data
            } catch { throw MappingError.invalidPackage }
        }
        let manifestBytes = try extract("manifest.json")
        let mappingBytes = try extract("mappings.json")
        let manifestObject = try object(manifestBytes, keys: ["schemaVersion", "version", "publishedAt", "mappings"])
        guard let digest = manifestObject["mappings"] as? [String: Any], Set(digest.keys) == ["sha256", "bytes"] else {
            throw MappingError.invalidPackage
        }
        let manifest = try decode(Manifest.self, from: manifestBytes)
        guard manifest.schemaVersion == 1, manifest.version == version,
              manifest.mappings.bytes == mappingBytes.count,
              manifest.mappings.sha256 == sha256(mappingBytes),
              manifest.publishedAt.range(of: "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", options: .regularExpression) != nil,
              ISO8601DateFormatter().date(from: manifest.publishedAt) != nil else { throw MappingError.invalidPackage }
        let mappingObject = try object(mappingBytes, keys: ["subjects", "teachers", "rooms"])
        for key in ["subjects", "teachers", "rooms"] {
            guard let rows = mappingObject[key] as? [[String: Any]] else { throw MappingError.invalidPackage }
            for row in rows {
                guard Set(row.keys).isSubset(of: ["alias", "fullName", "classes", "internationalStudent"]),
                      !(row["classes"] is NSNull), !(row["internationalStudent"] is NSNull) else {
                    throw MappingError.invalidPackage
                }
            }
        }
        let rules = try decode(MappingRules.self, from: mappingBytes)
        try validate(rules)
        return SavedMapping(revision: revision, version: version, schemaVersion: 1,
                            archiveETag: archiveETag, archiveSHA256: sha256(zip),
                            publishedAt: manifest.publishedAt, fetchedAt: fetchedAt, rules: rules)
    }

    static func validate(_ rules: MappingRules) throws {
        guard rules.subjects.count + rules.teachers.count + rules.rooms.count <= 10_000 else { throw MappingError.invalidPackage }
        for (kind, group) in [("subject", rules.subjects), ("teacher", rules.teachers), ("room", rules.rooms)] {
            var seen: Set<String> = []
            for rule in group {
                guard !rule.alias.isEmpty, !rule.fullName.isEmpty,
                      rule.alias.count <= 512, rule.fullName.count <= 512,
                      rule.alias == rule.alias.trimmingCharacters(in: .whitespacesAndNewlines),
                      rule.fullName == rule.fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                      rule.internationalStudent != false else { throw MappingError.invalidPackage }
                if kind != "subject" && rule.classes != nil { throw MappingError.invalidPackage }
                if rule.internationalStudent == true && !rule.alias.hasPrefix("留 ") { throw MappingError.invalidPackage }
                if let classes = rule.classes {
                    guard !classes.isEmpty, classes.count <= 100,
                          classes.allSatisfy({ !$0.isEmpty && $0.count <= 128 }) else { throw MappingError.invalidPackage }
                }
                for className in rule.classes ?? [""] {
                    guard seen.insert(rule.alias + "\u{0}" + className).inserted else { throw MappingError.invalidPackage }
                }
            }
        }
    }

    private static func object(_ data: Data, keys: Set<String>) throws -> [String: Any] {
        guard let value = try? JSONSerialization.jsonObject(with: data),
              let object = value as? [String: Any], Set(object.keys) == keys else { throw MappingError.invalidPackage }
        return object
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw MappingError.invalidPackage }
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

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
            guard saved.schemaVersion == 1, MappingPackage.validRevision(saved.revision) else { throw MappingError.storage }
            try MappingPackage.validate(saved.rules)
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
