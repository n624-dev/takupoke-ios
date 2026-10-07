import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import ZIPFoundation

/// Reads selected ZIP entries in memory. Never extracts files or follows URLs.
enum XLSXReader {
    struct PreviewTable {
        var rows: [[String]]
        var warnings: [ChangeParseError]
    }
    static let spreadsheet = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    static let relationships = "http://schemas.openxmlformats.org/package/2006/relationships"
    static let documentRelationships = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    static let maximumXMLBytes = 8 * 1024 * 1024

    static func read(_ url: URL, defaultYear: Int? = nil, check: @escaping () throws -> Void = {}, dateDerivedWeekdays: Bool = false) throws -> [[String]] {
        let table = try readForPreview(url, defaultYear: defaultYear, check: check)
        if let warning = table.warnings.first(where: { !dateDerivedWeekdays || !$0.canCorrectWeekday }) { throw warning }
        return table.rows
    }

    // Only weekday warnings are recoverable for display. All other structural
    // checks still apply, and this entry point never persists a successful result.
    static func readForPreview(_ url: URL, defaultYear: Int? = nil, check: @escaping () throws -> Void = {}) throws -> PreviewTable {
        do { return try readArchive(url, defaultYear: defaultYear, check: check) }
        catch let error as ChangeParseError { throw error }
        catch { throw ChangeParseError(code: .invalidArchive) }
    }

    private static func readArchive(_ url: URL, defaultYear: Int?, check: @escaping () throws -> Void) throws -> PreviewTable {
        try check()
        guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size <= 50 * 1024 * 1024 else { throw ChangeParseError(code: .limit) }
        let archive = try Archive(url: url, accessMode: .read)
        var entries: [String: Entry] = [:]
        var total: UInt64 = 0
        for entry in archive {
            try check()
            let parts = entry.path.split(separator: "/", omittingEmptySubsequences: false)
            guard entries.count < 2048, entry.uncompressedSize <= 32 * 1024 * 1024 else { throw ChangeParseError(code: .limit) }
            total += entry.uncompressedSize
            guard total <= 64 * 1024 * 1024 else { throw ChangeParseError(code: .limit) }
            guard entries[entry.path] == nil, !entry.path.hasPrefix("/"), !entry.path.contains("\\"),
                  !parts.contains(".."), !parts.contains("."), entry.type != .symlink else {
                throw ChangeParseError(code: .invalidArchive)
            }
            entries[entry.path] = entry
        }
        guard entries["xl/vbaProject.bin"] == nil else { throw ChangeParseError(code: .unsupported) }
        func xml(_ path: String, root: String, namespace: String) throws -> XMLNode {
            guard let entry = entries[path], entry.type == .file else { throw ChangeParseError(code: .invalidArchive) }
            guard entry.uncompressedSize <= maximumXMLBytes else { throw ChangeParseError(code: .limit) }
            var data = Data()
            let crc = try archive.extract(entry, bufferSize: 64 * 1024, skipCRC32: false) { chunk in
                try check()
                guard data.count + chunk.count <= maximumXMLBytes else { throw ChangeParseError(code: .limit) }
                data.append(chunk)
            }
            guard data.count == entry.uncompressedSize, crc == entry.checksum else { throw ChangeParseError(code: .invalidArchive) }
            return try BoundedXML.parse(data, root: root, namespace: namespace, check: check)
        }
        let workbook = try xml("xl/workbook.xml", root: "workbook", namespace: spreadsheet)
        if let setting = workbook.child("workbookPr")?.attributes["date1904"], !["0", "false"].contains(setting) {
            throw ChangeParseError(code: .dateSystem)
        }
        guard workbook.child("externalReferences") == nil else { throw ChangeParseError(code: .unsupported) }
        let sheets = workbook.child("sheets")?.children.filter { $0.name == "sheet" && $0.attributes["name"] == "時間割変更" } ?? []
        guard sheets.count == 1, let id = sheets[0].attributes["{\(documentRelationships)}id"] else {
            throw ChangeParseError(code: .missingSheet)
        }
        let rels = try xml("xl/_rels/workbook.xml.rels", root: "Relationships", namespace: relationships)
        let selected = rels.children.filter { $0.name == "Relationship" && $0.attributes["Id"] == id }
        guard selected.count == 1, selected[0].attributes["Type"] == documentRelationships + "/worksheet",
              selected[0].attributes["TargetMode", default: "Internal"] == "Internal",
              let target = selected[0].attributes["Target"], !target.contains(":"), !target.contains("%"),
              !target.contains("\\"), !target.contains("?"), !target.contains("#") else {
            throw ChangeParseError(code: .unsupported)
        }
        let path = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/" + target
        guard !path.split(separator: "/").contains(".."), !path.split(separator: "/").contains(".") else {
            throw ChangeParseError(code: .invalidArchive)
        }
        var strings: [String] = []
        if entries["xl/sharedStrings.xml"] != nil {
            let sst = try xml("xl/sharedStrings.xml", root: "sst", namespace: spreadsheet)
            for si in sst.children where si.name == "si" {
                guard strings.count < 50_000 else { throw ChangeParseError(code: .limit) }
                strings.append(try richText(si))
            }
        }
        let sheet = try xml(path, root: "worksheet", namespace: spreadsheet)
        return try readSheet(sheet, strings: strings, defaultYear: defaultYear, check: check)
    }

}

// A preview is read-only and is available only for the exact source/year of a
// failed weekday check. Kept with the reader so this path is tested on Linux too.
extension MaterialLibrary {
    func previewChanges(check: @escaping () throws -> Void = {}) throws -> ChangePreview {
        guard let record = state.record(for: .changes),
              let attempt = state.changeParseAttempt, attempt.failure?.permitsPreview == true,
              attempt.sourceDigest == record.digest,
              let url = localURL(for: .changes) else { throw ChangeParseError(code: .unsupported) }
        let table = try XLSXReader.readForPreview(url, defaultYear: attempt.defaultYear, check: check)
        let records = try ChangeNormalizer.parse(table.rows, defaultYear: attempt.defaultYear, check: check)
        try check()
        return ChangePreview(sourceName: record.originalName, defaultYear: attempt.defaultYear,
                             records: records, warnings: table.warnings, sourceIdentity: record.source.selectionID ?? record.storedName, sourceDigest: record.digest)
    }
}
