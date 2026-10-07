import Foundation

extension XLSXReader {
    static func readSheet(_ sheet: XMLNode, strings: [String], defaultYear: Int?,
                          check: () throws -> Void) throws -> PreviewTable {
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
        }
        let weekdayColumns = headers.indices.filter { ["曜日", "曜"].contains(headers[$0]) }
        guard weekdayColumns.count <= 1 else { throw ChangeParseError(code: .headers, row: header) }
        if let column = weekdayColumns.first {
            let weekdayFormulas = Dictionary(uniqueKeysWithValues: formulas.filter { $0.row > header && $0.column == column }.map { ($0.row, $0.hasCachedValue) })
            for number in (header + 1)..<(rows.count + 1) {
                try check()
                let row = rows[number - 1]
                let printed = row.indices.contains(column) ? row[column] : ""
                if weekdayFormulas[number] == nil && printed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
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
        return PreviewTable(rows: rows, warnings: warnings)
    }

    static func richText(_ node: XMLNode) throws -> String {
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
