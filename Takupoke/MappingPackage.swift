import Foundation
import CryptoKit
import ZIPFoundation

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
        guard [1, 2].contains(manifest.schemaVersion), manifest.version == version,
              manifest.mappings.bytes == mappingBytes.count,
              manifest.mappings.sha256 == sha256(mappingBytes),
              manifest.publishedAt.range(of: "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", options: .regularExpression) != nil,
              ISO8601DateFormatter().date(from: manifest.publishedAt) != nil else { throw MappingError.invalidPackage }
        let mappingObject = try object(mappingBytes, keys: manifest.schemaVersion == 2
            ? ["subjects", "teachers", "rooms", "teacherContexts"]
            : ["subjects", "teachers", "rooms"])
        for key in ["subjects", "teachers", "rooms"] {
            guard let rows = mappingObject[key] as? [[String: Any]] else { throw MappingError.invalidPackage }
            for row in rows {
                guard Set(row.keys).isSubset(of: ["alias", "fullName", "classes", "internationalStudent"]),
                      !(row["classes"] is NSNull), !(row["internationalStudent"] is NSNull) else {
                    throw MappingError.invalidPackage
                }
            }
        }
        if manifest.schemaVersion == 2 {
            guard let rows = mappingObject["teacherContexts"] as? [[String: Any]] else {
                throw MappingError.invalidPackage
            }
            for row in rows {
                guard Set(row.keys) == ["alias", "fullName", "subject", "className", "schoolYear"],
                      row["schoolYear"] is Int else { throw MappingError.invalidPackage }
            }
        }
        let rules = try decode(MappingRules.self, from: mappingBytes)
        try validate(rules, schemaVersion: manifest.schemaVersion)
        return SavedMapping(revision: revision, version: version, schemaVersion: manifest.schemaVersion,
                            archiveETag: archiveETag, archiveSHA256: sha256(zip),
                            publishedAt: manifest.publishedAt, fetchedAt: fetchedAt, rules: rules)
    }

    static func validate(_ rules: MappingRules, schemaVersion: Int) throws {
        guard [1, 2].contains(schemaVersion), (schemaVersion == 2 || rules.teacherContexts.isEmpty),
              rules.subjects.count + rules.teachers.count + rules.rooms.count + rules.teacherContexts.count <= 10_000 else {
            throw MappingError.invalidPackage
        }
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
        var seenContexts: Set<String> = []
        for rule in rules.teacherContexts {
            guard !rule.alias.isEmpty, !rule.fullName.isEmpty, !rule.subject.isEmpty,
                  rule.alias.count <= 512, rule.fullName.count <= 512, rule.subject.count <= 512,
                  [rule.alias, rule.fullName, rule.subject, rule.className].allSatisfy({
                      $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines)
                  }),
                  (2000...2099).contains(rule.schoolYear),
                  TimetableSchedule.selectableClasses.contains(rule.className) else { throw MappingError.invalidPackage }
            let key = [rule.alias, String(rule.schoolYear), rule.className,
                       rule.subject.precomposedStringWithCompatibilityMapping].joined(separator: "\u{0}")
            guard seenContexts.insert(key).inserted else { throw MappingError.invalidPackage }
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
