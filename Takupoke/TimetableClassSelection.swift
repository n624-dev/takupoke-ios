import SwiftUI

struct TimetablePrimaryClassSelection: View {
    let classes: [String]
    @Binding var value: String
    @AppStorage("timetableInternationalStudent") private var isInternationalStudent = false

    private var selected: [String] { value.split(separator: "|").map(String.init) }
    private var primary: String { selected.first ?? "" }
    private var additional: String { selected.dropFirst().first ?? "" }

    private var additionalClasses: [String] { classes.filter { TimetableSchedule.compatibleAdditionalClass($0, with: primary) } }

    var body: some View {
        Form {
            Picker("クラス", selection: Binding(get: { primary }, set: { value = $0 })) {
                Text("クラスを選択").tag("")
                if !primary.isEmpty && !classes.contains(primary) {
                    Text("\(TimetableDisplayText.className(primary))（保存済み・現在の資料に該当なし）").tag(primary)
                }
                ForEach(classes, id: \.self) { Text(TimetableDisplayText.className($0)).tag($0) }
            }
            Picker("追加クラス（1年生のみ・任意）", selection: Binding(
                get: { additional },
                set: { value = $0.isEmpty ? primary : primary + "|" + $0 })) {
                Text("追加なし").tag("")
                if !additional.isEmpty && !additionalClasses.contains(additional) {
                    Text("\(TimetableDisplayText.className(additional))（保存済み・現在の資料に該当なし）").tag(additional)
                }
                ForEach(additionalClasses, id: \.self) { Text(TimetableDisplayText.className($0)).tag($0) }
            }
            .disabled(additionalClasses.isEmpty && additional.isEmpty)
            Toggle("留学生向けの授業も表示", isOn: $isInternationalStudent)
        }
        .navigationTitle("クラスを選ぶ")
    }
}

struct TimetableChangeClassSelection: View {
    let classes: [String]
    @Binding var value: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    private var selected: Set<String> { Set(draft.split(separator: "|").map(String.init)) }
    private var unavailable: [String] { selected.subtracting(classes).sorted() }
    private var groups: [(String, [String])] {
        let grouped = Dictionary(grouping: classes) { className -> String in
            guard let year = className.split(separator: "_").first, Int(year) != nil else { return "専攻科" }
            return "\(year)年"
        }
        return grouped.keys.sorted().map { ($0, grouped[$0]!.sorted()) }
    }

    var body: some View {
        List {
            Text("\(selected.count)クラス選択中（上限30クラス）")
                .foregroundStyle(.secondary)
            ForEach(groups.indices, id: \.self) { index in
                let group = groups[index]
                Section {
                    ForEach(group.1, id: \.self) { className in
                        Toggle(TimetableDisplayText.className(className), isOn: Binding(
                            get: { selected.contains(className) },
                            set: { update(className, selected: $0) }))
                            .disabled(!selected.contains(className) && selected.count >= 30)
                    }
                } header: {
                    HStack {
                        Text(TimetableDisplayText.kana(group.0))
                        Spacer()
                        Button(group.1.allSatisfy(selected.contains) ? "すべて解除" : "すべて選択") {
                            toggleGroup(group.1)
                        }
                    }
                }
            }
            if !unavailable.isEmpty {
                Section("保存済み・現在の資料に該当なし") {
                    ForEach(unavailable, id: \.self) { className in
                        Toggle(TimetableDisplayText.className(className), isOn: Binding(
                            get: { selected.contains(className) },
                            set: { update(className, selected: $0) }))
                    }
                }
            }
        }
        .navigationTitle("変更一覧のクラス")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("適用") {
                    value = draft
                    dismiss()
                }
                .disabled(selected.isEmpty)
            }
        }
        .onAppear { draft = value }
    }

    private func update(_ className: String, selected isSelected: Bool) {
        var next = selected
        if isSelected { next.insert(className) } else { next.remove(className) }
        draft = Array(next).sorted().joined(separator: "|")
    }

    private func toggleGroup(_ group: [String]) {
        var next = selected
        if group.allSatisfy(next.contains) {
            next.subtract(group)
        } else {
            for className in group where next.count < 30 { next.insert(className) }
        }
        draft = Array(next).sorted().joined(separator: "|")
    }
}
