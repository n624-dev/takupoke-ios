import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

extension XLSXReader {
    static func editableWorkbook(_ url: URL, layout: ChangeColumnLayout?, sheet requested: String? = nil,
                                 headerRow requestedRow: Int? = nil, confirmedDigest: Bool = false, check: @escaping () throws -> Void) throws -> ChangeWorkbookReview {
        try withSheet(url, requested: requested ?? layout?.sheet, editing: true, check: check) { sheet, strings, names, name, uses1904, formats in
            let source = try readCells(sheet, strings: strings, editing: true, formats: formats, check: check)
            var rows = source.rows
            if rows.isEmpty {
                guard names.count > 1 else { throw ChangeParseError(code: .empty) }
                let table = ChangeEditTable(sheet: name, headers: [], rows: [], headerRow: 0)
                let layout = ChangeColumnLayout(sheet: name, headerRow: 0, original: [], headers: [])
                return ChangeWorkbookReview(sheets: names, table: table, layout: layout, requiresLayoutConfirmation: true)
            }
            var issues = source.issues
            var sources = source.sources
            var mergedArea = 0
            for merge in sheet.child("mergeCells")?.children ?? [] where merge.name == "mergeCell" {
                try check()
                let parts = merge.attributes["ref", default: ""].split(separator: ":", omittingEmptySubsequences: false)
                guard (1...2).contains(parts.count) else { throw ChangeParseError(code: .invalidXML) }
                let start = try coordinate(String(parts[0])), end = try coordinate(String(parts[parts.count - 1]))
                guard start.row <= end.row, start.column <= end.column else { throw ChangeParseError(code: .mergedCells) }
                mergedArea += (end.row - start.row + 1) * (end.column - start.column + 1)
                guard mergedArea <= 100_000 else { throw ChangeParseError(code: .limit) }
                if end.row > rows.count { rows += Array(repeating: [], count: end.row - rows.count) }
                let anchorRow = rows[start.row - 1]
                let anchor = anchorRow.indices.contains(start.column) ? anchorRow[start.column] : ""
                let dependency = [anchor, source.sources[start.row]?[start.column] ?? "",
                                  source.issues[start.row]?[start.column]?.rawValue ?? ""]
                let fingerprint = SHA256.hash(data: Data(dependency.map { "\($0.utf8.count):" + $0 }.joined().utf8))
                    .map { String(format: "%02x", $0) }.joined()
                for row in start.row...end.row {
                    try check()
                    for column in start.column...end.column {
                        issues[row, default: [:]][column] = .mergedCells
                        sources[row, default: [:]][column, default: ""] += "/merge/\(start.row-row)/\(end.row-row)/\(start.column-column)/\(end.column-column)/\(fingerprint)"
                    }
                }
            }
            func meaningfulWidth(_ index: Int) -> Int {
                max((rows[index].lastIndex(where: { !$0.isEmpty }) ?? -1) + 1,
                    (sources[index + 1]?.keys.max() ?? -1) + 1)
            }
            func physicalHeader(_ index: Int) -> [String] {
                let width = meaningfulWidth(index)
                return Array(rows[index].prefix(width)) + Array(repeating: "", count: max(0, width - rows[index].count))
            }
            let likely = try? ChangeNormalizer.headerIndex(rows)
            let old = layout.flatMap { $0.sheet == name ? $0 : nil }
            let matches = old.map { previous in rows.indices.filter { physicalHeader($0) == previous.original } } ?? []
            if let requestedRow, !(1...rows.count).contains(requestedRow) { throw ChangeParseError(code: .headers) }
            let position = requestedRow.map { $0 - 1 } ?? (matches.count == 1 ? matches[0] : likely ?? rows.indices.first(where: { meaningfulWidth($0) > 0 }) ?? 0)
            let original = physicalHeader(position)
            let width = (position..<rows.count).map(meaningfulWidth).max() ?? original.count
            let headerSources = sources[position + 1, default: [:]]
            let oldWidth = old.map { $0.physicalWidth ?? $0.original.count } ?? 0
            let sameSchema = old.map { $0.original == original && ($0.headerSources ?? [:]) == headerSources && oldWidth >= width } == true
            let reuse = sameSchema && (matches.count == 1 || (old?.headerRow == position + 1 && (confirmedDigest || requestedRow != nil)))
            var headers = original + Array(repeating: "", count: width - original.count)
            if let old, reuse {
                headers = old.headers
            } else {
                let names = Set(headers.map(ChangeNormalizer.text))
                let tokens = headers.map(ChangeNormalizer.token)
                let missing = ["学 年", "学科・クラス", "月日"].filter { !names.contains($0) }
                    + ChangeNormalizer.OptionalColumn.allCases.filter { $0.index(in: tokens) == nil }.map(\.rawValue)
                headers.append(contentsOf: missing.prefix(ChangeNormalizer.maximumColumns - headers.count))
            }
            for i in headers.indices where headers[i].isEmpty { headers[i] = "列\(i + 1)" }
            let proposed = ChangeColumnLayout(sheet: name, headerRow: position + 1, original: original, headers: headers,
                physicalWidth: reuse ? oldWidth : width, headerSources: headerSources.isEmpty ? nil : headerSources)
            let table = ChangeEditTable(sheet: name, headers: headers, rows: rows, headerRow: position + 1,
                cellIssues: issues, cellSources: sources, originalHeaders: original,
                headerSources: proposed.headerSources, physicalWidth: proposed.physicalWidth, uses1904: uses1904, numericCells: source.numericCells, dateCells: source.dateCells, formattedDates: source.formattedDates)
            let named = original.map(ChangeNormalizer.text).filter { !$0.isEmpty }
            let ambiguousWeekdays = named.filter { ["曜日", "曜"].contains(ChangeNormalizer.token($0)) }.count > 1
            let confirm = !reuse && (old != nil || name != "時間割変更" || likely != position || width > original.count ||
                Set(named).count != named.count || ambiguousWeekdays || issues[position + 1] != nil)
            return ChangeWorkbookReview(sheets: names, table: table, layout: proposed, requiresLayoutConfirmation: confirm)
        }
    }
}

extension MaterialLibrary {
    func changeEditor(year: Int, sheet: String? = nil, headerRow: Int? = nil,
                      check: @escaping () throws -> Void = {}) throws -> ChangeWorkbookReview {
        guard let record = state.record(for: .changes), let url = localURL(for: .changes) else { throw ChangeParseError(code: .invalidArchive) }
        let identity = record.source.selectionID ?? record.storedName
        let personal = record.source.personalChanges.flatMap { $0.year == year ? $0 : nil }
        let layout = personal?.layout
        var view: ChangeWorkbookReview
        do { view = try XLSXReader.editableWorkbook(url, layout: layout, sheet: sheet, headerRow: headerRow,
            confirmedDigest: personal?.reviewedDigest == record.digest, check: check) }
        catch let failure as ChangeParseError where failure.code == .missingSheet && layout != nil && sheet == nil {
            view = try XLSXReader.editableWorkbook(url, layout: nil, check: check)
            view.requiresLayoutConfirmation = true
        }
        view.baseline = ChangeEditBaseline(source: record.source)
        let restored = view.table.restoreDetailed(personal?.rows, sourceIdentity: identity, digest: record.digest, defaultYear: year)
        view.edits = restored.edits
        view.conflicts = restored.conflicts

        view.previous = restored.unmatched
        if let personal {
            view.previous += personal.history.map { $0.withDateContext(headers: personal.layout.headers, year: personal.year) }
        }
        if let personal, personal.ambiguousRows?.isEmpty == false {
            let scope = personal.ambiguousLayout ?? personal.layout
            let sameLayout = scope.sheet == view.layout.sheet && scope.headers == view.layout.headers &&
                scope.original == view.layout.original && scope.headerSources == view.layout.headerSources
            if sameLayout, personal.reviewedDigest == record.digest, scope.headerRow == view.layout.headerRow {
                view.conflicts.formUnion(Set(personal.ambiguousRows ?? []).intersection(view.table.rowIDs))
            } else if sameLayout {
                let unresolved = Set(personal.ambiguousOriginals ?? personal.history.map(\.original))
                for row in view.table.rowIDs where unresolved.contains(view.table.original(at: row)) { view.conflicts.insert(row) }
            }
        }
        if personal == nil {
            let weekday = record.source.weekdayConsent
            let skip = record.source.rowSkipConsent
            view.edits = try view.table.legacyEdits(weekday: weekday?.digest == record.digest && weekday?.defaultYear == year,
                excluded: Set(skip?.identifies(sourceIdentity: identity, digest: record.digest, defaultYear: year) == true ? skip?.rows ?? [] : []),
                defaultYear: year, check: check)
        }
        return view
    }

    func saveChangeEditor(_ view: ChangeWorkbookReview, year: Int, expectedIdentity: String, expectedDigest: String,
                          edits: [Int: ChangeRowEdit], manual: Bool, check: @escaping () throws -> Void) throws {
        guard let record = state.record(for: .changes), record.digest == expectedDigest,
              (record.source.selectionID ?? record.storedName) == expectedIdentity,
              !view.requiresLayoutConfirmation, view.conflicts.isEmpty,
              !manual || view.baseline == ChangeEditBaseline(source: record.source) else { throw ChangeParseError(code: .staleConfirmation) }
        let records = try view.table.records(edits: edits, defaultYear: year, check: check)
        if records.isEmpty, !manual, record.source.personalChanges?.reviewedDigest != expectedDigest {
            throw ChangeParseError(code: .staleConfirmation)
        }
        let rows = try view.table.savedEdits(sourceIdentity: expectedIdentity, digest: expectedDigest, defaultYear: year, edits: edits, check: check)
        let personal = PersonalChangeSettings(year: year, layout: view.layout, rows: rows, history: view.previous, reviewedDigest: record.digest)
        var analysis = ChangeAnalysis(sourceDigest: record.digest, sourceName: record.originalName, defaultYear: year, parsedAt: Date(), records: records)
        analysis.sourceModifiedAt = record.sourceModifiedAt
        analysis.personalEdit = manual
        analysis.personalSourceIdentity = expectedIdentity
        try check()
        var next = state
        guard let i = next.records.firstIndex(where: { $0.kind == .changes }) else { throw ChangeParseError(code: .staleConfirmation) }
        next.records[i].source.personalChanges = personal
        next.records[i].source.weekdayConsent = nil
        next.records[i].source.rowSkipConsent = nil
        next.changeAnalysis = analysis
        next.changeParseAttempt = ChangeParseAttempt(date: analysis.parsedAt, sourceDigest: record.digest, defaultYear: year,
                                                    failure: nil, parserVersion: ChangeAnalysis.parserVersion)
        try persist(next)
    }

    /// Re-anchor active edits even when another row in the new source is invalid.
    /// An intervening official correction must not reactivate when its old spelling returns.
    func reconcileChangeEdits(_ view: ChangeWorkbookReview, year: Int) throws {
        guard let index = state.records.firstIndex(where: { $0.kind == .changes }),
              let previous = state.records[index].source.personalChanges else { return }
        let record = state.records[index]
        guard previous.year == year, previous.reviewedDigest != record.digest else { return }
        if records.isEmpty, !manual, record.source.personalChanges?.reviewedDigest != expectedDigest {
            throw ChangeParseError(code: .staleConfirmation)
        }
        let rows = try view.table.savedEdits(sourceIdentity: record.source.selectionID ?? record.storedName,
            digest: record.digest, defaultYear: year, edits: view.edits)
        var next = state
        var updated = previous
        updated.rows = rows
        updated.history = view.previous
        updated.reviewedDigest = record.digest
        updated.ambiguousRows = view.conflicts.sorted()
        updated.ambiguousOriginals = view.conflicts.sorted().map(view.table.original(at:))
        updated.ambiguousLayout = view.conflicts.isEmpty ? nil : view.layout
        next.records[index].source.personalChanges = updated
        try persist(next)
    }

    /// Prepare the old edits from the original XLSX before replacing its bytes.
    func legacyChangeSettings(check: @escaping () throws -> Void = {}) throws -> PersonalChangeSettings? {
        guard let source = state.record(for:.changes), source.source.personalChanges == nil,
              let year = source.source.rowSkipConsent?.defaultYear ?? source.source.weekdayConsent?.defaultYear else { return nil }
        let view = try changeEditor(year: year, check: check)
        if records.isEmpty, !manual, record.source.personalChanges?.reviewedDigest != expectedDigest {
            throw ChangeParseError(code: .staleConfirmation)
        }
        let rows = try view.table.savedEdits(sourceIdentity: source.source.selectionID ?? source.storedName,
            digest: source.digest, defaultYear: year, edits: view.edits, check: check)
        guard let rows else { return nil }
        return PersonalChangeSettings(year:year,layout:view.layout,rows:rows,history:[])
    }

    func captureLegacyChangeEdits(check: @escaping () throws -> Void = {}) throws {
        guard let i = state.records.firstIndex(where:{ $0.kind == .changes }),
              let settings = try legacyChangeSettings(check:check) else { return }
        try check()
        var next = state
        next.records[i].source.personalChanges = settings
        try persist(next)
    }
}
