import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

extension XLSXReader {
    static func readSheet(_ sheet: XMLNode, strings: [String], defaultYear: Int?,
                          uses1904: Bool = false, formats: [Int: Bool] = [:], check: () throws -> Void) throws -> PreviewTable {
        let content = try readCells(sheet, strings: strings, editing: false, formats: formats, check: check)
        var rows = content.rows
        let formulas = content.formulas
        // Locate literal required headers without accepting cached formula text
        // from either the anchor or a dependent cell.
        var headerRows = rows
        for formula in formulas { headerRows[formula.row - 1][formula.column] = "" }
        for (number, issues) in content.issues {
            for (column, issue) in issues where issue == .formula && headerRows[number - 1].indices.contains(column) {
                headerRows[number - 1][column] = ""
            }
        }
        let header = try ChangeNormalizer.headerIndex(headerRows) + 1
        let headers = rows[header - 1].map(ChangeNormalizer.token)
        let dateColumn = headers.firstIndex(of: "月日")!
        let updated = ChangeNormalizer.OptionalColumn.updated.index(in: headers)
        var workbook = ChangeEditTable(sheet: "時間割変更", headers: rows[header - 1], rows: content.rows, headerRow: header,
                                       cellIssues: content.issues, uses1904: uses1904, numericCells: content.numericCells,
                                       dateCells: content.dateCells, formattedDates: content.formattedDates)
        for (number, issues) in content.issues {
            for (column, issue) in issues where number <= header || column != updated {
                // Metadata outside the table may contain formulas. Only their
                // dependencies that reach the header or data affect acceptance.
                if number < header && issue == .formula { continue }
                throw ChangeParseError(code: issue, row: number)
            }
        }
        for number in (header + 1)..<(rows.count + 1) {
            guard rows[number - 1].indices.contains(dateColumn) else { continue }
            if content.dateCells[number]?.contains(dateColumn) == true {
                rows[number - 1][dateColumn] = String(rows[number - 1][dateColumn].prefix(10))
            } else if uses1904, ChangeNormalizer.matches(ChangeNormalizer.text(rows[number - 1][dateColumn]), #"^[0-9]+(?:\.[0-9]+)?$"#),
                      let serial = Double(ChangeNormalizer.text(rows[number - 1][dateColumn])) {
                rows[number - 1][dateColumn] = String(serial + 1462)
            }
        }
        var warnings: [ChangeParseError] = []
        for formula in formulas {
            try check()
            if formula.row < header {
                rows[formula.row - 1][formula.column] = ""
                continue
            }
            if formula.row > header, formula.column == updated {
                workbook.cellIssues[formula.row, default: [:]][formula.column] = .formula
                continue
            }
            guard formula.row > header, headers.indices.contains(formula.column),
                  ["曜日", "曜"].contains(headers[formula.column]) else {
                throw ChangeParseError(code: .formula, row: formula.row)
            }
        }
        let weekdayColumns = headers.indices.filter { ["曜日", "曜"].contains(headers[$0]) }
        guard weekdayColumns.count <= 1 else { throw ChangeParseError(code: .headers, row: header) }
        if let column = weekdayColumns.first {
            let weekdayFormulas = Dictionary(uniqueKeysWithValues: formulas.filter { $0.row > header && $0.column == column }.map { ($0.row, $0.hasCachedValue) })
            for number in (header + 1)..<(rows.count + 1) {
                try check()
                let row = rows[number - 1]
                guard row.dropFirst(headers.count).allSatisfy({ ChangeNormalizer.text($0).isEmpty }) else {
                    throw ChangeParseError(code: .headers, row: number)
                }
                let printed = row.indices.contains(column) ? row[column] : ""
                if weekdayFormulas[number] == nil && printed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
                if row.enumerated().allSatisfy({ $0.offset == column || ChangeNormalizer.text($0.element).isEmpty }) {
                    warnings.append(ChangeParseError(code: .weekdayOnly, row: number, printedWeekday: printed))
                    continue
                }
                guard row.indices.contains(dateColumn) else { throw ChangeParseError(code: .date, row: number) }
                let date: String
                do { date = try ChangeNormalizer.date(row[dateColumn], defaultYear: defaultYear) }
                catch { throw ChangeParseError(code: .date, row: number) }
                if weekdayFormulas[number] == false { warnings.append(ChangeParseError(code: .formulaCache, row: number)) }
                else if !ChangeNormalizer.weekdayMatches(printed, normalizedDate: date) {
                    warnings.append(ChangeParseError(code: .weekdayMismatch, row: number,
                        printedWeekday: printed, calculatedWeekday: ChangeNormalizer.weekday(date)))
                }
            }
        }
        for merge in sheet.child("mergeCells")?.children ?? [] where merge.name == "mergeCell" {
            guard let ref = merge.attributes["ref"] else { throw ChangeParseError(code: .invalidXML) }
            let parts = ref.split(separator: ":")
            guard (1...2).contains(parts.count) else { throw ChangeParseError(code: .invalidXML) }
            let end = try coordinate(String(parts.last!))
            if end.row >= header { throw ChangeParseError(code: .mergedCells, row: end.row) }
        }
        return PreviewTable(rows: rows, warnings: warnings, workbook: workbook, defaultYear: defaultYear)
    }

    struct WorksheetCells {
        var rows: [[String]]
        var formulas: [(row: Int, column: Int, hasCachedValue: Bool)]
        var issues: [Int: [Int: ChangeParseError.Code]]
        var sources: [Int: [Int: String]]
        var numericCells: [Int: Set<Int>]
        var dateCells: [Int: Set<Int>]
        var formattedDates: [Int: [Int: Bool]]
    }

    static func readCells(_ sheet: XMLNode, strings: [String], editing: Bool, formats: [Int: Bool] = [:],
                          check: () throws -> Void) throws -> WorksheetCells {
        guard let data = sheet.child("sheetData") else { throw ChangeParseError(code: .invalidXML) }
        var rows: [[String]] = []
        var cellCount = 0
        var cellBytes = 0
        var formulas: [(row: Int, column: Int, hasCachedValue: Bool)] = []
        var issues: [Int: [Int: ChangeParseError.Code]] = [:]
        var sources: [Int: [Int: String]] = [:]
        var sharedMasters: [String: (row: Int, column: Int, fingerprint: String)] = [:]
        var rangedMasters: [(firstRow: Int, firstColumn: Int, lastRow: Int, lastColumn: Int, fingerprint: String?)] = []
        var rangedCellCount = 0
        var duplicateMasters = Set<String>()
        var sharedFollowers: [(row: Int, column: Int, group: String)] = []
        var formattedDates: [Int: [Int: Bool]] = [:]
        var numericCells: [Int: Set<Int>] = [:], dateCells: [Int: Set<Int>] = [:]
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
                let formula = cell.child("f")
                let isFormula = formula != nil
                let type = cell.attributes["t", default: "n"]
                let value = cell.child("v")?.text ?? ""
                if isFormula {
                    formulas.append((number, position.column, !value.isEmpty && ["n", "str", "s", "b", "d"].contains(type)))
                }
                if let formula, ["array", "dataTable"].contains(formula.attributes["t"] ?? ""), let ref = formula.attributes["ref"] {
                    let ends = ref.split(separator: ":", omittingEmptySubsequences: false)
                    guard ends.count == 1 || ends.count == 2 else { throw ChangeParseError(code: .invalidXML) }
                    let start = try coordinate(String(ends[0])), end = try coordinate(String(ends[ends.count - 1]))
                    guard start == position, start.row <= end.row, start.column <= end.column else { throw ChangeParseError(code: .invalidXML) }
                    rangedCellCount += (end.row - start.row + 1) * (end.column - start.column + 1)
                    guard rangedCellCount <= 100_000 else { throw ChangeParseError(code: .limit) }
                    var fingerprint: String?
                    if editing {
                        let dependency = [formula.text] + formula.attributes.sorted { $0.key < $1.key }.filter { $0.key != "ref" }.flatMap { [$0.key, $0.value] }
                        let bytes = Data(dependency.map { "\($0.utf8.count):" + $0 }.joined().utf8)
                        fingerprint = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
                    }
                    rangedMasters.append((start.row, start.column, end.row, end.column, fingerprint))
                }
                var decoded: String
                if editing, let formula {
                    // Length-frame each field so separators inside a formula cannot collide
                    // with its attributes, cached error or written cell type.
                    let fields = [type, formula.text] + formula.attributes.keys.sorted().flatMap { [$0, formula.attributes[$0]!] }
                    sources[number, default: [:]][position.column] = "formula/" + fields.map { "\($0.utf8.count):" + $0 }.joined()
                    if formula.attributes["t"] == "shared" {
                        let group = formula.attributes["si"] ?? ""
                        if formula.text.isEmpty {
                            sharedFollowers.append((number, position.column, group))
                        } else if sharedMasters[group] != nil {
                            duplicateMasters.insert(group)
                        } else {
                            let fingerprint = SHA256.hash(data: Data(formula.text.utf8)).map { String(format: "%02x", $0) }.joined()
                            sharedMasters[group] = (number, position.column, fingerprint)
                        }
                    }
                    issues[number, default: [:]][position.column] = .formula
                }
                do {
                    switch type {
                    case "inlineStr": decoded = try cell.child("is").map(richText) ?? ""
                    case "s":
                        guard let index = Int(value), strings.indices.contains(index) else { throw ChangeParseError(code: .invalidXML, row: number) }
                        decoded = strings[index]
                    case "b":
                        guard ["0", "1"].contains(value) else { throw ChangeParseError(code: .invalidXML, row: number) }
                        decoded = value == "1" ? "TRUE" : "FALSE"
                    case "str": decoded = try decodedString(value)
                    case "d":
                        _ = try typedDate(value, row: number)
                        dateCells[number, default: []].insert(position.column)
                        decoded = value
                    case "n":
                        decoded = value
                        if !value.isEmpty {
                            numericCells[number, default: []].insert(position.column)
                            if let style = Int(cell.attributes["s"] ?? "0"), let clock = formats[style] {
                                formattedDates[number, default: [:]][position.column] = clock
                            }
                        }
                    default:
                        // Formula metadata above the header is not part of the table.
                        // Formula errors within the table are handled after locating that header.
                        if isFormula && !editing { decoded = "" }
                        else { throw ChangeParseError(code: .cellType, row: number) }
                    }
                } catch let problem as ChangeParseError {
                    guard [.date, .cellType].contains(problem.code) else { throw problem }
                    decoded = value
                    issues[number, default: [:]][position.column] = problem.code
                }
                if editing, (isFormula || !value.isEmpty || issues[number]?[position.column] != nil),
                   type != "s" && type != "inlineStr" && type != "str" {
                    // Keep the written typed value, including the time portion of a typed date.
                    sources[number, default: [:]][position.column, default: ""] += "/type/" + type + "/" + value
                }
                cellBytes += decoded.utf8.count
                guard cellBytes <= ChangeNormalizer.maximumTextBytes else { throw ChangeParseError(code: .limit) }
                if cells.count <= position.column { cells += Array(repeating: "", count: position.column + 1 - cells.count) }
                cells[position.column] = decoded
            }
            rows += Array(repeating: [], count: number - rows.count - 1)
            rows.append(cells)
        }
        for master in rangedMasters {
            if master.lastRow > rows.count { rows += Array(repeating: [], count: master.lastRow - rows.count) }
            for row in master.firstRow...master.lastRow {
                try check()
                for column in master.firstColumn...master.lastColumn where row != master.firstRow || column != master.firstColumn {
                    if let fingerprint = master.fingerprint {
                        sources[row, default: [:]][column, default: ""] +=
                            "/array/\(fingerprint)/\(master.firstRow-row)/\(master.firstColumn-column)/\(master.lastRow-row)/\(master.lastColumn-column)"
                    }
                    if issues[row]?[column] == nil { issues[row, default: [:]][column] = .formula }
                }
            }
        }
        for follower in sharedFollowers {
            try check()
            if !follower.group.isEmpty, !duplicateMasters.contains(follower.group), let master = sharedMasters[follower.group] {
                sources[follower.row, default: [:]][follower.column, default: ""] +=
                    "/master/\(master.fingerprint)/\(master.row - follower.row)/\(master.column - follower.column)"
            } else {
                sources[follower.row, default: [:]][follower.column] = "unresolved-shared/" + (sources[follower.row]?[follower.column] ?? "")
            }
        }
        return WorksheetCells(rows: rows, formulas: formulas, issues: issues, sources: sources,
                              numericCells: numericCells, dateCells: dateCells, formattedDates: formattedDates)
    }

    private static func typedDate(_ value: String, row: Int) throws -> String {
        // Validate the whole ISO value but keep its written calendar day;
        // a device timezone must never move a spreadsheet lesson to another day.
        guard ChangeNormalizer.matches(value, #"\A[0-9]{4}-[0-9]{2}-[0-9]{2}(?:T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{1,9})?(?:Z|[+-][0-9]{2}:[0-9]{2})?)?\z"#) else {
            throw ChangeParseError(code: .date, row: row)
        }
        if value.count > 10 {
            let clock = value.dropFirst(11).prefix(8).split(separator: ":").compactMap { Int($0) }
            guard clock.count == 3, clock[0] <= 23, clock[1] <= 59, clock[2] <= 59 else {
                throw ChangeParseError(code: .date, row: row)
            }
        }
        if let range = value.range(of: #"[+-][0-9]{2}:[0-9]{2}\z"#, options: .regularExpression) {
            let offset = value[range].dropFirst().split(separator: ":").compactMap { Int($0) }
            guard offset.count == 2, offset[0] <= 14, offset[1] <= 59,
                  offset[0] < 14 || offset[1] == 0 else { throw ChangeParseError(code: .date, row: row) }
        }
        do { return try ChangeNormalizer.date(String(value.prefix(10)), defaultYear: nil) }
        catch { throw ChangeParseError(code: .date, row: row) }
    }

    static func richText(_ node: XMLNode) throws -> String {
        // rPh is a phonetic guide, not the displayed value.
        let result = try node.children.map { child -> String in
            if child.name == "t" { return try decodedString(child.text) }
            if child.name == "r" { return try child.children.filter { $0.name == "t" }.map { try decodedString($0.text) }.joined() }
            return ""
        }.joined()
        guard result.utf8.count <= 4096 else { throw ChangeParseError(code: .limit) }
        return result
    }

    /// SpreadsheetML escapes UTF-16 code units. Scan once so an escaped
    /// underscore protects a literal escape-looking string from a second pass.
    static func decodedString(_ source: String) throws -> String {
        let input = Array(source.utf16)
        var output: [UInt16] = []
        var i = 0
        while i < input.count {
            if i + 6 < input.count, input[i] == 95, input[i+1] == 120, input[i+6] == 95 {
                let digits = input[(i+2)..<(i+6)]
                if digits.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
                   let unit = UInt16(String(decoding: digits, as: UTF16.self), radix: 16) {
                    output.append(unit); i += 7; continue
                }
            }
            output.append(input[i]); i += 1
        }
        i = 0
        while i < output.count {
            if (0xD800...0xDBFF).contains(output[i]) {
                guard i + 1 < output.count, (0xDC00...0xDFFF).contains(output[i+1]) else { throw ChangeParseError(code: .invalidXML) }
                i += 2
            } else {
                guard !(0xDC00...0xDFFF).contains(output[i]) else { throw ChangeParseError(code: .invalidXML) }
                i += 1
            }
        }
        return String(decoding: output, as: UTF16.self)
    }

    static func coordinate(_ ref: String) throws -> (row: Int, column: Int) {
        guard ChangeNormalizer.matches(ref, "^[A-Z]{1,3}[1-9][0-9]{0,6}$") else { throw ChangeParseError(code: .invalidXML) }
        let letters = ref.prefix { $0.isLetter }
        var col = 0
        for letter in letters.utf8 { col = col * 26 + Int(letter - 65) + 1 }
        guard let row = Int(ref.dropFirst(letters.count)), col <= ChangeNormalizer.maximumColumns,
              row <= ChangeNormalizer.maximumRows else { throw ChangeParseError(code: .limit) }
        return (row, col - 1)
    }
}
