import SwiftUI

struct ChangeWorkbookEditorView: View {
    @ObservedObject var model: MaterialsModel
    let preview: ChangePreview
    @State private var view: ChangeWorkbookReview
    @State private var edits: [Int: ChangeRowEdit]
    @State private var issues: [Int: [ChangeParseError]] = [:]
    @State private var error: String?
    @State private var headerNumber: String
    @Environment(\.dismiss) private var dismiss

    init(model: MaterialsModel, preview: ChangePreview, initial: ChangeWorkbookReview) {
        self.model = model
        self.preview = preview
        _view = State(initialValue: initial)
        let suggested = initial.table.suggestedEdits(defaultYear: preview.defaultYear ?? 0)
        _edits = State(initialValue: suggested.merging(initial.edits) { _, saved in saved })
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
                let allRows = view.table.rowIDs
                let unresolvedRows = view.conflicts.union(issues.keys)
                if !unresolvedRows.isEmpty {
                    Section("確認が必要な行") {
                        ForEach(allRows.filter(unresolvedRows.contains), id: \.self) { row in rowLink(row) }
                    }
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
                                    LabeledContent(view.table.headers.indices.contains(column) ? view.table.headers[column] : "列\(column + 1)", value: entry.edit.values[column] ?? "")
                                }
                                Button("この履歴を削除", role: .destructive) { view.previous.remove(at: index) }
                            }
                        }
                    }
                }
                Section("原本の行") {
                    ForEach(allRows.filter { !unresolvedRows.contains($0) }, id: \.self) { row in rowLink(row) }
                }
            }
            .navigationDestination(for: Int.self) { row in rowEditor(row) }
            .navigationTitle("個人修正を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() }.disabled(model.busy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("反映する") {
                        verify()
                        guard error == nil, issues.isEmpty else { return }
                        view.layout.headers = view.table.headers
                        error = model.savePersonalChanges(preview, view: view, edits: edits)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(model.busy || view.requiresLayoutConfirmation || !view.conflicts.isEmpty)
                }
            }
            .onAppear { verify() }
        }
        .interactiveDismissDisabled(model.busy)
    }

    @State private var openedLayout = false
    private var layoutExpanded: Binding<Bool> {
        Binding(get: { view.requiresLayoutConfirmation || openedLayout }, set: { openedLayout = $0 })
    }

    private func verify() {
        do {
            issues = try view.table.review(edits: edits, defaultYear: preview.defaultYear ?? 0)
            error = nil
        } catch {
            issues = [:]
            self.error = error.localizedDescription
        }
    }

    private func problemLabel(_ issue: ChangeParseError) -> String {
        let column = issue.column.flatMap { view.table.headers.indices.contains($0) ? view.table.headers[$0] : nil }
        var problem = issue
        problem.row = nil
        let detail = problem.localizedDescription.components(separatedBy: " 前回の正常").first ?? problem.localizedDescription
        return column.map { $0 + "　" + detail } ?? detail
    }

    private func rowLink(_ row: Int) -> some View {
        NavigationLink(value: row) {
            VStack(alignment: .leading) {
                Text("\(row)行目" + (edits[row]?.excluded == true ? "（除外）" : edits[row]?.isEmpty == false ? "（個人修正）" : ""))
                Text(view.table.rows[row - 1].filter { !$0.isEmpty }.joined(separator: " ・ "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if view.conflicts.contains(row) { InlineWarning("同じ内容の行があります。適用する修正を選んでください。") }
                if let problems = issues[row] {
                    ForEach(problems.indices, id: \.self) { i in
                        InlineWarning(problemLabel(problems[i]))
                    }
                }
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
                                let title = view.table.headers.indices.contains(column) ? view.table.headers[column] : "列\(column + 1)"
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
                            if ChangeNormalizer.text(view.table.headers[column]) == "月日" { edits[row, default: ChangeRowEdit()].deriveWeekday = true }
                            if ["曜日", "曜"].contains(ChangeNormalizer.token(view.table.headers[column])) { edits[row, default: ChangeRowEdit()].deriveWeekday = false }
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
                        set: { edits[row, default: ChangeRowEdit()].deriveWeekday = $0 }))
                }
                Toggle("この行を除外", isOn: Binding(get: { edits[row]?.excluded == true },
                    set: { edits[row, default: ChangeRowEdit()].excluded = $0 }))
                Button("この行を原本の値に戻す") { edits.removeValue(forKey: row) }
            }
        }
        .navigationTitle("\(row)行目").onDisappear { verify() }
    }

}
