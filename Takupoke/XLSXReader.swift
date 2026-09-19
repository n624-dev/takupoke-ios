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

    static func read(_ url: URL, defaultYear: Int? = nil, check: @escaping () throws -> Void = {}) throws -> [[String]] {
        let table = try readForPreview(url, defaultYear: defaultYear, check: check)
        if let warning = table.warnings.first { throw warning }
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
        guard let data = sheet.child("sheetData") else { throw ChangeParseError(code: .invalidXML) }
        var rows: [[String]] = []
        var cellCount = 0
        var cellBytes = 0
        var formulas: [(row: Int, column: Int, hasCachedValue: Bool)] = []
        for row in data.children where row.name == "row" {
            try check()
            guard let number = Int(row.attributes["r", default: ""]), number > rows.count,
                  number <= ChangeNormalizer.maximumRows else { throw ChangeParseError(code: .limit) }
            var cells: [String] = []
            var seen: Set<Int> = []
            for cell in row.children where cell.name == "c" {
                cellCount += 1
                guard cellCount <= 100_000, let ref = cell.attributes["r"] else { throw ChangeParseError(code: .limit) }
                let position = try coordinate(ref)
                guard position.row == number, seen.insert(position.column).inserted else { throw ChangeParseError(code: .invalidXML) }
                let isFormula = cell.child("f") != nil
                let type = cell.attributes["t", default: "n"]
                let value = cell.child("v")?.text ?? ""
                if isFormula {
                    formulas.append((number, position.column, !value.isEmpty && ["n", "str", "s", "b", "d"].contains(type)))
                }
                let decoded: String
                switch type {
                case "inlineStr": decoded = try cell.child("is").map(richText) ?? ""
                case "s":
                    guard let index = Int(value), strings.indices.contains(index) else { throw ChangeParseError(code: .invalidXML, row: number) }
                    decoded = strings[index]
                case "b":
                    guard ["0", "1"].contains(value) else { throw ChangeParseError(code: .invalidXML, row: number) }
                    decoded = value == "1" ? "TRUE" : "FALSE"
                case "n", "str", "d": decoded = value
                default:
                    // Formula metadata above the header is not part of the table.
                    // Formula errors within the table are handled after locating that header.
                    if isFormula { decoded = "" }
                    else { throw ChangeParseError(code: .cellType, row: number) }
                }
                cellBytes += decoded.utf8.count
                guard cellBytes <= ChangeNormalizer.maximumTextBytes else { throw ChangeParseError(code: .limit) }
                if cells.count <= position.column { cells += Array(repeating: "", count: position.column + 1 - cells.count) }
                cells[position.column] = decoded
            }
            rows += Array(repeating: [], count: number - rows.count - 1)
            rows.append(cells)
        }
        // Locate literal required headers without accepting a formula's cached
        // text as a header. All metadata before that row stays outside the table.
        var headerRows = rows
        for formula in formulas { headerRows[formula.row - 1][formula.column] = "" }
        let header = try ChangeNormalizer.headerIndex(headerRows) + 1
        let headers = rows[header - 1].map(ChangeNormalizer.token)
        let dateColumn = headers.firstIndex(of: "月日")!
        var warnings: [ChangeParseError] = []
        for formula in formulas {
            try check()
            if formula.row < header {
                rows[formula.row - 1][formula.column] = ""
                continue
            }
            guard formula.row > header, headers.indices.contains(formula.column),
                  ["曜日", "曜"].contains(headers[formula.column]) else {
                throw ChangeParseError(code: .formula, row: formula.row)
            }
            guard rows[formula.row - 1].indices.contains(dateColumn) else { throw ChangeParseError(code: .date, row: formula.row) }
            let date: String
            do { date = try ChangeNormalizer.date(rows[formula.row - 1][dateColumn], defaultYear: defaultYear) }
            catch { throw ChangeParseError(code: .date, row: formula.row) }
            if !formula.hasCachedValue {
                warnings.append(ChangeParseError(code: .formulaCache, row: formula.row))
            } else if !ChangeNormalizer.weekdayMatches(rows[formula.row - 1][formula.column], normalizedDate: date) {
                warnings.append(ChangeParseError(code: .weekdayMismatch, row: formula.row))
            }
        }
        for merge in sheet.child("mergeCells")?.children ?? [] where merge.name == "mergeCell" {
            guard let ref = merge.attributes["ref"] else { throw ChangeParseError(code: .invalidXML) }
            let parts = ref.split(separator: ":")
            guard (1...2).contains(parts.count) else { throw ChangeParseError(code: .invalidXML) }
            let end = try coordinate(String(parts.last!))
            if end.row >= header { throw ChangeParseError(code: .mergedCells, row: end.row) }
        }
        return PreviewTable(rows: rows, warnings: warnings)
    }

    private static func richText(_ node: XMLNode) throws -> String {
        // rPh is a phonetic guide, not the displayed value.
        let result = node.children.map { child -> String in
            if child.name == "t" { return child.text }
            if child.name == "r" { return child.children.filter { $0.name == "t" }.map(\.text).joined() }
            return ""
        }.joined()
        guard result.utf8.count <= 4096 else { throw ChangeParseError(code: .limit) }
        return result
    }

    private static func coordinate(_ ref: String) throws -> (row: Int, column: Int) {
        guard ChangeNormalizer.matches(ref, "^[A-Z]{1,3}[1-9][0-9]{0,6}$") else { throw ChangeParseError(code: .invalidXML) }
        let letters = ref.prefix { $0.isLetter }
        var col = 0
        for letter in letters.utf8 { col = col * 26 + Int(letter - 65) + 1 }
        guard let row = Int(ref.dropFirst(letters.count)), col <= ChangeNormalizer.maximumColumns,
              row <= ChangeNormalizer.maximumRows else { throw ChangeParseError(code: .limit) }
        return (row, col - 1)
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
                             records: records, warnings: table.warnings)
    }
}

private final class XMLNode {
    let name: String
    let namespace: String
    let attributes: [String: String]
    var allChildren: [XMLNode] = []
    var children: [XMLNode] { allChildren.filter { $0.namespace == namespace } }
    var text = ""
    init(_ name: String, namespace: String, attributes: [String: String]) {
        self.name = name; self.namespace = namespace; self.attributes = attributes
    }
    func child(_ name: String) -> XMLNode? { children.first { $0.name == name && $0.namespace == namespace } }
}

private final class BoundedXML: NSObject, XMLParserDelegate {
    var stack: [XMLNode] = []
    var root: XMLNode?
    var failure: Error?
    var count = 0
    var prefixes: [String: [String]] = [:]
    let check: () throws -> Void
    init(check: @escaping () throws -> Void) { self.check = check }

    static func parse(_ data: Data, root: String, namespace: String, check: @escaping () throws -> Void) throws -> XMLNode {
        // Reject declarations before parsing, including internal entity expansion.
        guard let text = String(data: data, encoding: .utf8),
              text.range(of: "<!DOCTYPE", options: .caseInsensitive) == nil,
              text.range(of: "<!ENTITY", options: .caseInsensitive) == nil else {
            throw ChangeParseError(code: .unsupported)
        }
        let delegate = BoundedXML(check: check)
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        let success = parser.parse()
        if let failure = delegate.failure { throw failure }
        guard success, let node = delegate.root, node.name == root, node.namespace == namespace,
              delegate.stack.isEmpty else { throw ChangeParseError(code: .invalidXML) }
        return node
    }
    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) {
        prefixes[prefix, default: []].append(namespaceURI)
    }
    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) { _ = prefixes[prefix]?.popLast() }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        do { try check() } catch { failure = error; parser.abortParsing(); return }
        count += 1
        guard count <= 200_000, stack.count < 64 else { failure = ChangeParseError(code: .limit); parser.abortParsing(); return }
        var attrs: [String: String] = [:]
        for (key, value) in attributes {
            let parts = key.split(separator: ":", maxSplits: 1)
            if parts.count == 2, let uri = prefixes[String(parts[0])]?.last { attrs["{\(uri)}\(parts[1])"] = value }
            else { attrs[key] = value }
        }
        let node = XMLNode(name, namespace: namespaceURI ?? "", attributes: attrs)
        if let parent = stack.last {
            // A duplicate singleton element would make first-match interpretation ambiguous.
            if node.namespace == parent.namespace,
               ["workbookPr", "sheets", "sheetData", "v", "is", "f", "mergeCells"].contains(name),
               parent.children.contains(where: { $0.name == name }) {
                failure = ChangeParseError(code: .invalidXML); parser.abortParsing(); return
            }
            parent.allChildren.append(node)
        } else { root = node }
        stack.append(node)
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) { _ = stack.popLast() }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let node = stack.last, ["t", "v"].contains(node.name) else { return }
        guard node.text.utf8.count + string.utf8.count <= 4096 else { failure = ChangeParseError(code: .limit); parser.abortParsing(); return }
        node.text += string
    }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let value = String(data: CDATABlock, encoding: .utf8) else { failure = ChangeParseError(code: .invalidXML); parser.abortParsing(); return }
        self.parser(parser, foundCharacters: value)
    }
}
