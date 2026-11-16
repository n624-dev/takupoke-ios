import SwiftUI

struct ChangeWorkbookEditorView: View {
    @ObservedObject var model: MaterialsModel
    @ObservedObject var mappings: MappingModel
    let preview: ChangePreview
    @State private var view: ChangeWorkbookReview
    @State private var edits: [Int: ChangeRowEdit]
    @State private var issues: [Int: [ChangeParseError]] = [:]
    @State private var groups: [ChangeIssueGroup] = []
    private enum Page: Hashable { case edited, all, preview }
    @State private var suggestions: ChangeIssueGroup?
    @State private var savedGroups: [ChangeIssueGroup] = []
    @State private var confirming = false
    @State private var viable = false
    @State private var error: String?
    @State private var headerNumber: String
    @Environment(\.dismiss) private var dismiss

    init(model: MaterialsModel, mappings: MappingModel, preview: ChangePreview, initial: ChangeWorkbookReview) {
        self.model = model
        self.mappings = mappings
        self.preview = preview
        _view = State(initialValue: initial)
        _edits = State(initialValue: initial.edits)
        _headerNumber = State(initialValue: String(initial.layout.headerRow))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let message = error ?? model.changeFailureMessage ?? model.changePreviewActionFailure(preview) {
                        InlineWarning(message)
                    }
                    if model.busy { LoadingRow(title: "資料を確認中⋯", cancel: { model.cancel() }) }
                    if view.requiresLayoutConfirmation {
                        Text("対象シートと見出しを確認してください。").font(.callout)
                    }
                    DisclosureGroup("シート・見出しの設定", isExpanded: layoutExpanded) {
                        if view.sheets.count > 1 {
                            Picker("対象シート", selection: Binding(get: { view.table.sheet }, set: { model.openChangeEditor(sheet: $0) })) {
                                ForEach(view.sheets, id: \.self) { Text($0).tag($0) }
                            }
                        } else { LabeledContent("シート", value: view.table.sheet) }
                        TextField("見出しの行番号", text: $headerNumber).keyboardType(.numberPad)
                        Button("指定した行を見出しにする") {
                            if let number = Int(headerNumber) { model.openChangeEditor(sheet: view.table.sheet, headerRow: number) }
                        }
                        ForEach(view.table.headers.indices, id: \.self) { column in
                            let original = view.layout.original.indices.contains(column) ? view.layout.original[column] : ""
                            TextField(original.isEmpty ? "列\(column + 1)の項目名" : "列\(column + 1)（\(original)）",
                                      text: $view.table.headers[column])
                                .textFieldStyle(.roundedBorder)
                        }
                        if view.requiresLayoutConfirmation {
                            Button("このシートと見出しを使う") {
                                view.layout.headers = view.table.headers
                                view.requiresLayoutConfirmation = false
                                verify()
                            }
                        }
                    }
                }
                let pending = Set(issues.keys).union(view.conflicts)
                if !pending.isEmpty {
                    Section("確認が必要な行（\(pending.count)行）") {
                        ForEach(groups) { group in
                            NavigationLink(value: group) {
                                VStack(alignment: .leading) {
                                    Text(groupTitle(group))
                                    Text("\(group.rows.count)行　\(ChangeReviewGroup.rangeLabel(group.rows))")
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                            .accessibilityIdentifier("change-group-\(group.id)")
                        }
                        ForEach(view.conflicts.sorted(), id: \.self) { row in rowLink(row) }
                    }
                }
                if let suggestions {
                    Section("日付から補完できる項目") {
                        NavigationLink("空欄の曜日（\(suggestions.rows.count)行）", value: suggestions)
                    }
                }
                Section {
                    if !editedRows.isEmpty {
                        NavigationLink("修正済み（\(editedRows.count)行）", value: Page.edited)
                            .accessibilityIdentifier("change-edited-rows")
                    }
                    NavigationLink("すべての行", value: Page.all)
                    NavigationLink("時間割のプレビュー", value: Page.preview).disabled(view.requiresLayoutConfirmation)
                }
                if !view.previous.isEmpty {
                    Section("更新前の個人修正") {
                        ForEach(view.previous.indices, id: \.self) { index in
                            let entry = view.previous[index]
                            DisclosureGroup("以前の\(entry.row)行目") {
                                Text(entry.original.values.filter { !$0.isEmpty }.joined(separator: " ・ "))
                                if entry.edit.excluded { Text("除外") }
                                if entry.edit.deriveWeekday { Text("曜日を日付から補完") }
                                ForEach(entry.edit.values.keys.sorted(), id: \.self) { column in
                                    LabeledContent(entry.valueLabels?[column] ?? "列\(column + 1)", value: entry.edit.values[column] ?? "")
                                }
                                Button("この履歴を削除", role: .destructive) { view.previous.remove(at: index) }
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .edited:
                    List {
                        ForEach(savedGroups) { group in
                            NavigationLink(value: group) {
                                VStack(alignment: .leading) {
                                    Text(groupTitle(group))
                                    Text("\(group.rows.count)行　\(ChangeReviewGroup.rangeLabel(group.rows))").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }.accessibilityIdentifier("change-saved-\(group.id)")
                        }
                    }.navigationTitle("修正済み")
                case .all: List { ForEach(view.table.rowIDs, id: \.self) { row in rowLink(row) } }.navigationTitle("すべての行")
                case .preview: ChangePreviewView(table: view.table, edits: edits, pending: Set(issues.keys).union(view.conflicts),
                                                 year: preview.defaultYear ?? 0, mappings: mappings)
                }
            }
            .navigationDestination(for: Int.self) { row in rowEditor(row) }
            .navigationDestination(for: ChangeIssueGroup.self) { group in
                ChangeGroupEditor(group: group, title: groupTitle(group), table: view.table,
                    year: preview.defaultYear ?? 0, activeRows: activeRows(in: group), edits: $edits, verify: verify)
            }
            .navigationTitle("内容を確認・修正")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() }.disabled(model.busy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("反映する") { confirming = true }
                        .buttonStyle(.glassProminent)
                        .disabled(!viable || model.busy || model.changePreviewActionFailure(preview) != nil || view.requiresLayoutConfirmation)
                }
            }
            .alert("個人修正を反映しますか？", isPresented: $confirming) {
                Button("反映する") {
                    verify()
                    guard viable, !view.requiresLayoutConfirmation else { return }
                    view.layout.headers = view.table.headers
                    error = model.savePersonalChanges(preview, view: view, edits: edits)
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                let skipped = edits.keys.filter { edits[$0]?.excluded == true }
                Text(skipped.isEmpty ? "確認した内容で時間割を更新します。" :
                       "除外する行：" + ChangeReviewGroup.rangeLabel(skipped))
            }
            .onChange(of: view.table.headers) { _, _ in verify() }
            .onAppear { verify() }
        }
        .interactiveDismissDisabled(model.busy)
    }

    @State private var openedLayout = false
    private var layoutExpanded: Binding<Bool> {
        Binding(get: { view.requiresLayoutConfirmation || openedLayout }, set: { openedLayout = $0 })
    }

    private var editedRows: [Int] { edits.keys.filter { edits[$0]?.isEmpty == false }.sorted() }

    private func activeRows(in group: ChangeIssueGroup) -> Set<Int> {
        if let saved = group.saved {
            return Set(savedGroups.first { $0.saved == saved && $0.column == group.column }?.rows ?? [])
                .intersection(group.rows).subtracting(view.conflicts)
        }
        let live = group.optional ? (suggestions.map { [$0] } ?? []) : groups
        return Set(live.filter {
            $0.code == group.code && $0.column == group.column && $0.printed == group.printed && $0.formula == group.formula
        }.flatMap(\.rows))
            .intersection(group.rows).subtracting(view.conflicts)
    }

    private func verify() {
        savedGroups = ChangeIssueGroup.savedGroups(edits)
        do {
            issues = try view.table.review(edits: edits, defaultYear: preview.defaultYear ?? 0)
            groups = ChangeIssueGroup.groups(issues, table: view.table)
            suggestions = nil
            if let weekday = view.table.headers.firstIndex(where: { ["曜日", "曜"].contains(ChangeNormalizer.token($0)) }) {
                let year = preview.defaultYear ?? 0
                let rows = view.table.rowIDs.filter { row in
                    let edit = edits[row] ?? ChangeRowEdit()
                    guard !edit.excluded, !edit.deriveWeekday, edit.keepPrintedWeekday != true,
                          view.table.cellIssues[row]?[weekday] == nil, !view.conflicts.contains(row) else { return false }
                    let values = view.table.values(at: row, edit: edit, defaultYear: year)
                    return ChangeNormalizer.text(values[weekday]).isEmpty &&
                        view.table.normalizedDate(values, row: row, edit: edit, defaultYear: year) != nil
                }
                if !rows.isEmpty { suggestions = ChangeIssueGroup(code: .weekdayMismatch, column: weekday, rows: rows, optional: true) }
            }
            viable = issues.isEmpty && view.conflicts.isEmpty
            error = nil
            if viable && !view.requiresLayoutConfirmation {
                // Check aggregate limits and the empty result before enabling Apply.
                _ = try view.table.records(edits: edits, defaultYear: preview.defaultYear ?? 0)
            }
        } catch {
            viable = false
            groups = []
            suggestions = nil
            issues = [:]
            self.error = error.localizedDescription
        }
    }

    private func problemLabel(_ issue: ChangeParseError) -> String {
        let column = issue.column.flatMap { view.table.headers.indices.contains($0) ? view.table.headers[$0] : nil }
        var problem = issue
        problem.row = nil
        let detail = problem.localizedDescription
        return column.map { $0 + "　" + detail } ?? detail
    }

    private func groupTitle(_ group: ChangeIssueGroup) -> String {
        if let saved = group.saved {
            switch saved {
            case .excluded: return "除外した行"
            case .derived: return "曜日を補完した行"
            case .printed: return "記載の曜日を使う行"
            case .field(let value): return (view.table.headers.indices.contains(group.column) ? view.table.headers[group.column] : "列") + "　" + (value.isEmpty ? "空欄" : value)
            }
        }
        switch group.code {
        case .weekdayOnly: return group.printed.isEmpty ? "曜日の数式だけの行" : "「\(group.printed)」だけの行"
        case .weekdayMismatch, .formulaCache: return "曜日を日付から補完"
        case .year: return "学年を確認"
        case .classes: return "学科・クラスを確認"
        case .unknownAll: return "「全」の対象クラスを確認"
        default: return problemLabel(ChangeParseError(code: group.code, column: group.column))
        }
    }

    private func rowLink(_ row: Int) -> some View {
        NavigationLink(value: row) {
            VStack(alignment: .leading) {
                Text("\(row)行目" + (edits[row]?.excluded == true ? "（除外）" : ""))
                Text(view.table.summary(row: row, edit: edits[row] ?? ChangeRowEdit(), year: preview.defaultYear ?? 0))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if view.conflicts.contains(row) { InlineWarning("以前の修正を選んでください。") }
            }
        }
        .accessibilityIdentifier("change-editor-row-\(row)")
    }

    private func rowEditor(_ row: Int) -> some View {
        Form {
            if view.conflicts.contains(row) {
                Section("同じ内容の行の確認") {
                    ForEach(view.previous.indices.filter { view.previous[$0].original == view.table.original(at: row) }, id: \.self) { index in
                        let entry = view.previous[index]
                        VStack(alignment: .leading, spacing: 4) {
                            if entry.edit.excluded { Text("除外") }
                            if entry.edit.deriveWeekday { Text("曜日を日付から補完") }
                            ForEach(entry.edit.values.keys.sorted(), id: \.self) { column in
                                let title = entry.valueLabels?[column] ?? "列\(column + 1)"
                                LabeledContent(title, value: entry.edit.values[column] ?? "")
                            }
                            Button("以前の\(entry.row)行目の修正を使う") {
                                edits[row] = entry.edit
                                view.conflicts.remove(row)
                            }
                        }
                    }
                    Button("この行の入力を使う") { view.conflicts.remove(row) }
                }
            }
            if let problems = issues[row], !problems.isEmpty {
                Section("確認する項目") {
                    ForEach(problems.indices, id: \.self) { index in InlineWarning(problemLabel(problems[index])) }
                }
            }
            Section("元の記載と訂正") {
                ForEach(view.table.headers.indices, id: \.self) { column in
                    let original = view.table.rows[row-1].indices.contains(column) ? view.table.rows[row-1][column] : ""
                    VStack(alignment: .leading) {
                        Text(view.table.headers[column]).font(.headline)
                        Text(original.isEmpty ? "原本は空欄" : "原本　" + original).font(.footnote).foregroundStyle(.secondary)
                        TextField("修正値", text: Binding(get: {
                            let values = view.table.values(at: row, edit: edits[row] ?? ChangeRowEdit(), defaultYear: preview.defaultYear ?? 0)
                            return values[column]
                        }, set: { value in
                            edits[row, default: ChangeRowEdit()].values[column] = value
                            if ChangeNormalizer.text(view.table.headers[column]) == "月日", edits[row]?.keepPrintedWeekday != true {
                                edits[row, default: ChangeRowEdit()].deriveWeekday = true
                            }
                            if ["曜日", "曜"].contains(ChangeNormalizer.token(view.table.headers[column])) {
                                edits[row, default: ChangeRowEdit()].chooseDateDerivedWeekday(false)
                            }
                        })).textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("change-editor-field-\(column)")
                        if view.table.cellIssues[row]?[column] != nil && edits[row]?.values[column] == nil {
                            Button("この値で確定") { edits[row, default: ChangeRowEdit()].values[column] = original }
                        }
                    }
                }
            }
            Section {
                if view.table.headers.contains(where: { ["曜日", "曜"].contains(ChangeNormalizer.token($0)) }) {
                    Toggle("曜日を日付から補完", isOn: Binding(get: { edits[row]?.deriveWeekday == true },
                        set: { edits[row, default: ChangeRowEdit()].chooseDateDerivedWeekday($0) }))
                }
                Toggle("この行を除外", isOn: Binding(get: { edits[row]?.excluded == true },
                    set: { edits[row, default: ChangeRowEdit()].excluded = $0 }))
                Button("この行を原本の値に戻す") { edits.removeValue(forKey: row) }
            }
        }
        .navigationTitle("\(row)行目").onDisappear { verify() }
    }

}
