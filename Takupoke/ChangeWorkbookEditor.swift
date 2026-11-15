import Foundation

extension XLSXReader {
    static func editableWorkbook(_ url: URL, layout: ChangeColumnLayout?, sheet requested: String? = nil,
                                 headerRow requestedRow: Int? = nil, check: @escaping () throws -> Void) throws -> ChangeWorkbookReview {
        try withSheet(url, requested: requested ?? layout?.sheet, editing: true, check: check) { sheet, strings, names, name, uses1904 in
            let source = try readCells(sheet, strings: strings, editing: true, check: check)
            let rows = source.rows
            if rows.isEmpty {
                guard names.count > 1 else { throw ChangeParseError(code: .empty) }
                let table = ChangeEditTable(sheet: name, headers: [], rows: [], headerRow: 0)
                let layout = ChangeColumnLayout(sheet: name, headerRow: 0, original: [], headers: [])
                return ChangeWorkbookReview(sheets: names, table: table, layout: layout, requiresLayoutConfirmation: true)
            }
            let likely = try? ChangeNormalizer.headerIndex(rows)
            let old = layout.flatMap { $0.sheet == name ? $0 : nil }
            let matches = old.map { previous in rows.indices.filter { rows[$0] == previous.original } } ?? []
            if let requestedRow, !(1...rows.count).contains(requestedRow) { throw ChangeParseError(code: .headers) }
            let position = requestedRow.map { $0 - 1 } ?? (matches.count == 1 ? matches[0] : likely ?? rows.firstIndex(where: { !$0.isEmpty }) ?? 0)
            guard rows.indices.contains(position) else { throw ChangeParseError(code: .headers) }
            let original = rows[position]
            let width = max(original.count, rows.dropFirst(position + 1).map(\.count).max() ?? 0)
            let required = ["学 年", "学科・クラス", "月日"]
            var headers = original + Array(repeating: "", count: width - original.count)
            let reuse = old.map { $0.original == original && $0.headers.count >= width && (position + 1 == $0.headerRow || matches.count == 1) } == true
            if let old, reuse {
                headers = old.headers
            } else {
                let names = Set(headers.map(ChangeNormalizer.text))
                let tokens = headers.map(ChangeNormalizer.token)
                let missing = required.filter { !names.contains($0) }
                    + ChangeNormalizer.OptionalColumn.allCases.filter { $0.index(in: tokens) == nil }.map(\.rawValue)
                headers.append(contentsOf: missing.prefix(ChangeNormalizer.maximumColumns - headers.count))
            }
            for i in headers.indices where headers[i].isEmpty { headers[i] = "列\(i + 1)" }
            let proposed = ChangeColumnLayout(sheet: name, headerRow: position + 1, original: original, headers: headers)
            var issues = source.issues
            var sources = source.sources
            // Record only relative merge geometry so inserting rows preserves identities.
            var mergedArea = 0
            for merge in sheet.child("mergeCells")?.children ?? [] where merge.name == "mergeCell" {
                try check()
                let parts = merge.attributes["ref", default: ""].split(separator: ":")
                guard parts.count == 2 else { throw ChangeParseError(code: .invalidXML) }
                let start = try coordinate(String(parts[0])), end = try coordinate(String(parts[1]))
                guard start.row <= end.row, start.column <= end.column, end.row <= rows.count,
                      end.column < ChangeNormalizer.maximumColumns else { throw ChangeParseError(code: .mergedCells) }
                mergedArea += (end.row-start.row+1) * (end.column-start.column+1)
                guard mergedArea <= 100_000 else { throw ChangeParseError(code: .limit) }
                for row in start.row...end.row where row > position + 1 {
                    for column in start.column...end.column {
                        issues[row, default: [:]][column] = .mergedCells
                        sources[row, default: [:]][column, default: ""] += "/merge/\(start.row-row)/\(end.row-row)/\(start.column-column)/\(end.column-column)"
                    }
                }
            }
            let table = ChangeEditTable(sheet: name, headers: headers, rows: rows, headerRow: position + 1,
                cellIssues: issues, cellSources: sources, originalHeaders: original,
                uses1904: uses1904, numericCells: source.numericCells, dateCells: source.dateCells)
            let confirm = !reuse && (name != "時間割変更" || likely != position || Set(original.filter { !$0.isEmpty }).count != original.filter { !$0.isEmpty }.count || source.issues[position + 1] != nil)
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
        do { view = try XLSXReader.editableWorkbook(url, layout: layout, sheet: sheet, headerRow: headerRow, check: check) }
        catch let failure as ChangeParseError where failure.code == .missingSheet && layout != nil && sheet == nil {
            view = try XLSXReader.editableWorkbook(url, layout: nil, check: check)
            view.requiresLayoutConfirmation = true
        }
        view.baseline = ChangeEditBaseline(source: record.source)
        let restored = view.table.restoreDetailed(personal?.rows, sourceIdentity: identity, digest: record.digest, defaultYear: year)
        view.edits = restored.edits
        view.conflicts = restored.conflicts
        if personal?.reviewedDigest == record.digest { view.conflicts.formUnion(personal?.ambiguousRows ?? []) }
        view.previous = restored.unmatched + (personal?.history ?? [])
        if let personal, personal.reviewedDigest != record.digest, personal.ambiguousRows?.isEmpty == false {
            let ambiguous = Set(personal.history.map(\.original))
            for row in view.table.rowIDs where ambiguous.contains(view.table.original(at: row)) { view.conflicts.insert(row) }
        }
        // A school update may introduce a new weekday warning on a different row.
        // Use only the date-derived value and recalculate it on every new original.
        if personal != nil, personal?.rows?.digest != record.digest {
            for (row, correction) in view.table.suggestedEdits(defaultYear: year) where view.edits[row] == nil && !view.conflicts.contains(row) {
                view.edits[row] = correction
            }
        }
        if personal == nil {
            let weekday = record.source.weekdayConsent
            let skip = record.source.rowSkipConsent
            view.edits = view.table.legacyEdits(weekday: weekday?.digest == record.digest && weekday?.defaultYear == year,
                excluded: Set(skip?.identifies(sourceIdentity: identity, digest: record.digest, defaultYear: year) == true ? skip?.rows ?? [] : []),
                defaultYear: year)
        }
        return view
    }

    func saveChangeEditor(_ view: ChangeWorkbookReview, year: Int, expectedIdentity: String, expectedDigest: String,
                          edits: [Int: ChangeRowEdit], manual: Bool, check: @escaping () throws -> Void) throws {
        guard let record = state.record(for: .changes), record.digest == expectedDigest,
              (record.source.selectionID ?? record.storedName) == expectedIdentity,
              !manual || view.baseline == ChangeEditBaseline(source: record.source) else { throw ChangeParseError(code: .staleConfirmation) }
        let records = try view.table.records(edits: edits, defaultYear: year, check: check)
        let rows = try view.table.savedEdits(sourceIdentity: expectedIdentity, digest: expectedDigest, defaultYear: year, edits: edits)
        let personal = PersonalChangeSettings(year: year, layout: view.layout, rows: rows, history: view.previous, reviewedDigest: record.digest)
        var analysis = ChangeAnalysis(sourceDigest: record.digest, sourceName: record.originalName, defaultYear: year, parsedAt: Date(), records: records)
        analysis.personalEdit = manual
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
        let rows = try view.table.savedEdits(sourceIdentity: record.source.selectionID ?? record.storedName,
            digest: record.digest, defaultYear: year, edits: view.edits)
        var next = state
        var updated = previous
        updated.rows = rows
        updated.history = view.previous
        updated.reviewedDigest = record.digest
        updated.ambiguousRows = view.conflicts.sorted()
        next.records[index].source.personalChanges = updated
        try persist(next)
    }

    /// Snapshot legacy permissions while the exact original XLSX is still on disk.
    func captureLegacyChangeEdits() throws {
        guard let i = state.records.firstIndex(where: { $0.kind == .changes }) else { return }
        let source = state.records[i]
        guard source.source.personalChanges == nil,
              let year = source.source.rowSkipConsent?.defaultYear ?? source.source.weekdayConsent?.defaultYear else { return }
        let view = try changeEditor(year: year)
        let rows = try view.table.savedEdits(sourceIdentity: source.source.selectionID ?? source.storedName,
            digest: source.digest, defaultYear: year, edits: view.edits)
        guard rows != nil else { return }
        var next = state
        next.records[i].source.personalChanges = PersonalChangeSettings(year: year, layout: view.layout, rows: rows, history: [])
        try persist(next)
    }
}
