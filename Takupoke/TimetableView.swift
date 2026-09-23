import SwiftUI

struct TimetableView: View {
    @ObservedObject var model: MaterialsModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("timetableSelectedClasses") private var selectedClassesValue = ""
    @AppStorage("timetableChangeClasses") private var changeClassesValue = ""
    @State private var weekStart = SchoolDate.today().monday
    @State private var today = SchoolDate.today()
    @State private var includesChanges = true
    @State private var changeRange: ChangeRange = .today
    @State private var selectedLesson: LessonSelection?
    @State private var selectedChange: ChangeSelection?

    private var timetable: PDFAnalysis? { model.state.pdfAnalyses?[MaterialKind.timetable.rawValue] }
    private var changes: ChangeAnalysis? { model.state.changeAnalysis }
    private var classes: [String] { TimetableSchedule.classes(in: model.state) }
    private var selectedClasses: [String] { Self.decode(selectedClassesValue).filter(classes.contains) }
    private var listClasses: [String] {
        changeClassesValue.isEmpty ? selectedClasses : Self.decode(changeClassesValue).filter(classes.contains)
    }
    private let weekdayNames = ["月", "火", "水", "木", "金", "土", "日"]

    var body: some View {
        NavigationStack {
            List {
                if !model.ready {
                    Section { HStack { ProgressView(); Text("保存済み資料を読み込み中…") } }
                } else if classes.isEmpty {
                    Section {
                        ContentUnavailableViewPlaceholder()
                        NavigationLink("学校資料を選ぶ") { MaterialsView(model: model) }
                    }
                } else {
                    Section("表示クラス") {
                        NavigationLink {
                            TimetablePrimaryClassSelection(classes: classes, value: $selectedClassesValue)
                        } label: {
                            LabeledContent("クラス", value: selectedClasses.isEmpty ? "未選択" : selectedClasses.joined(separator: "・"))
                        }
                    }
                    weekSection
                    changesSection
                }
            }
            .navigationTitle("時間割")
            .task { model.loadIfNeeded() }
            .onAppear { syncClasses() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { today = SchoolDate.today() }
            }
            .onChange(of: classes) { values in
                syncClasses(values)
            }
            .sheet(item: $selectedLesson) { selection in
                NavigationStack { lessonDetail(selection.lesson, date: selection.date) }
            }
            .sheet(item: $selectedChange) { selection in
                NavigationStack { changeDetail(selection) }
            }
        }
    }

    private var weekSection: some View {
        Section {
            HStack {
                Button("前週") { moveWeek(-7) }
                Spacer()
                Text("\(weekStart.month)/\(weekStart.day)〜\(weekStart.addingDays(6)!.month)/\(weekStart.addingDays(6)!.day)")
                    .font(.subheadline.monospacedDigit())
                Spacer()
                Button("翌週") { moveWeek(7) }
            }
            .buttonStyle(.bordered)
            Picker("表示モード", selection: $includesChanges) {
                Text("通常").tag(false)
                Text("変更込み").tag(true)
            }
            .pickerStyle(.segmented)
            if let timetable, TimetableSchedule.termRange(for: timetable) == nil {
                Label("通常時間割の学期を確認できません。元PDFを再解析してください。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if timetable == nil {
                Label("通常時間割の解析結果がありません。", systemImage: "doc.questionmark")
                    .foregroundStyle(.secondary)
            }
            if includesChanges && changes == nil {
                Label("時間割変更の解析結果がありません。", systemImage: "doc.questionmark")
                    .foregroundStyle(.secondary)
            }
            if let timetable, timetable.sourceDigest != model.state.record(for: .timetable)?.digest ||
                timetable.version != PDFAnalysis.currentVersion(for: .timetable) {
                Label("通常時間割は前回の解析結果です。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if let changes, changes.sourceDigest != model.state.record(for: .changes)?.digest ||
                changes.version != ChangeAnalysis.parserVersion {
                Label("時間割変更は前回の解析結果です。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            weekGrid
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        } header: { Text("週の時間割") }
    }

    private var weekGrid: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .topLeading, horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    Text("時限").frame(width: 38)
                    ForEach(0..<7, id: \.self) { offset in
                        let day = weekStart.addingDays(offset)!
                        VStack(spacing: 2) {
                            Text(weekdayNames[offset]).font(.caption.bold())
                            Text("\(day.month)/\(day.day)").font(.caption2.monospacedDigit())
                        }
                        .frame(width: 124)
                        .accessibilityLabel("\(day.month)月\(day.day)日 \(weekdayNames[offset])曜日")
                    }
                }
                ForEach(1...8, id: \.self) { period in
                    GridRow {
                        Text("\(period)").font(.caption.bold()).frame(width: 38, alignment: .top)
                        ForEach(0..<7, id: \.self) { offset in
                            let day = weekStart.addingDays(offset)!
                            timetableCell(on: day, period: period)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .accessibilityLabel("\(selectedClasses.joined(separator: "・"))の週の時間割")
    }

    private func timetableCell(on day: SchoolDate, period: Int) -> some View {
        let hasItems = selectedClasses.contains { className in
            let slot = TimetableSchedule.slot(on: day, period: period, className: className,
                                              timetable: timetable, changes: changes,
                                              includesChanges: includesChanges)
            return !slot.displayedLessons.isEmpty || !slot.changes.isEmpty
        }
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(selectedClasses, id: \.self) { className in
                classSlot(on: day, period: period, className: className)
            }
            if !hasItems { Text("—").foregroundStyle(.tertiary) }
        }
        .padding(6)
        .frame(width: 124, alignment: .topLeading)
        .frame(minHeight: 64, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func classSlot(on day: SchoolDate, period: Int, className: String) -> some View {
        let slot = TimetableSchedule.slot(on: day, period: period, className: className,
                                          timetable: timetable, changes: changes,
                                          includesChanges: includesChanges)
        return VStack(alignment: .leading, spacing: 4) {
            if selectedClasses.count > 1 && (!slot.displayedLessons.isEmpty || !slot.changes.isEmpty) {
                Text(className).font(.caption2.bold()).foregroundStyle(.secondary)
            }
            ForEach(Array(slot.displayedLessons.enumerated()), id: \.offset) { _, lesson in
                Button {
                    selectedLesson = LessonSelection(lesson: lesson, date: day)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(PDFDisplayText.continuous(lesson.names.cellSubject)).font(.caption.bold()).lineLimit(3)
                        if !lesson.names.cellRoom.isEmpty {
                            Text(PDFDisplayText.continuous(lesson.names.cellRoom)).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(period)限 \(lesson.names.cellSubject)の詳細")
            }
            ForEach(Array(slot.changes.enumerated()), id: \.offset) { _, change in
                Button { selectedChange = ChangeSelection(change: change, baseLessons: slot.baseLessons) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(change.after_subject.isEmpty ? "変更を確認" : change.after_subject,
                              systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption2.bold()).lineLimit(3)
                        if !change.teacher.isEmpty { Text(change.teacher).font(.caption2).lineLimit(2) }
                        if !change.room.isEmpty { Text(change.room).font(.caption2).lineLimit(2) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
                .accessibilityLabel("\(period)限の変更後の授業詳細。通常の時間割も表示")
            }
        }
    }

    private var changesSection: some View {
        let visible = listClasses.flatMap { className in
            TimetableSchedule.changes(in: changes, className: className, range: changeRange,
                                      today: today, weekStart: weekStart)
        }.sorted { ($0.change_date, $0.period, $0.displayClassName) < ($1.change_date, $1.period, $1.displayClassName) }
        return Section {
            Picker("表示範囲", selection: $changeRange) {
                ForEach(ChangeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            NavigationLink {
                TimetableChangeClassSelection(classes: classes, value: Binding(
                    get: { changeClassesValue.isEmpty ? selectedClassesValue : changeClassesValue },
                    set: { changeClassesValue = $0 }))
            } label: {
                LabeledContent("対象クラス", value: listClasses.isEmpty ? "未選択" : listClasses.joined(separator: "・"))
            }
            if !changeClassesValue.isEmpty {
                Button("時間割設定に戻す") { changeClassesValue = "" }
            }
            if listClasses.isEmpty {
                Text("対象クラスを選んでください。")
                    .foregroundStyle(.secondary)
            } else if changes == nil {
                Text("時間割変更の解析結果がありません。")
                    .foregroundStyle(.secondary)
            } else if visible.isEmpty {
                Text("この範囲の時間割変更はありません。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, change in
                    Button { selectedChange = ChangeSelection(change: change, baseLessons: baseLessons(for: change)) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(change.change_date) · \(change.displayClassName) · \(change.period.isEmpty ? "時限未記載" : change.period + "限")")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(changeSummary(change)).font(.subheadline)
                            if !change.note.isEmpty { Text(change.note).font(.caption).foregroundStyle(.secondary) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: { Text("時間割変更一覧") }
    }

    private func moveWeek(_ days: Int) {
        if let next = weekStart.addingDays(days), next.addingDays(7) != nil { weekStart = next }
    }

    private func syncClasses(_ values: [String]? = nil) {
        let values = values ?? classes
        let selected = Self.decode(selectedClassesValue).filter(values.contains)
        let primary = selected.first ?? values.first ?? ""
        let additional = selected.dropFirst().first.flatMap { TimetablePrimaryClassSelection.compatible($0, with: primary) ? $0 : nil }
        selectedClassesValue = ([primary] + (additional.map { [$0] } ?? [])).filter { !$0.isEmpty }.joined(separator: "|")
        changeClassesValue = Self.decode(changeClassesValue).filter(values.contains).prefix(30).joined(separator: "|")
    }

    private static func decode(_ value: String) -> [String] {
        Array(Set(value.split(separator: "|").map(String.init))).sorted()
    }

    private func changeSummary(_ change: ScheduleChange) -> String {
        let before = change.before_subject.isEmpty ? "記載なし" : change.before_subject
        let after = change.after_subject.isEmpty ? "記載なし" : change.after_subject
        return "\(before) → \(after)"
    }

    private func baseLessons(for change: ScheduleChange) -> [PDFLesson] {
        guard let day = SchoolDate(iso8601: change.change_date), let period = Int(change.period) else { return [] }
        return TimetableSchedule.lessons(on: day, className: change.displayClassName, analysis: timetable)
            .filter { $0.period == period }
    }

    private func lessonDetail(_ lesson: PDFLesson, date: SchoolDate) -> some View {
        List {
            Section("通常の授業") {
                LabeledContent("日付", value: date.iso8601)
                LabeledContent("クラス", value: lesson.className)
                LabeledContent("時限", value: "\(lesson.period)限")
                LabeledContent("科目", value: PDFDisplayText.continuous(lesson.names.detailSubject))
                LabeledContent("教員", value: lesson.names.detailTeacher.isEmpty ? "記載なし" : PDFDisplayText.continuous(lesson.names.detailTeacher))
                LabeledContent("教室", value: lesson.names.detailRoom.isEmpty ? "記載なし" : PDFDisplayText.continuous(lesson.names.detailRoom))
            }
        }
        .navigationTitle("授業詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func changeDetail(_ selection: ChangeSelection) -> some View {
        let change = selection.change
        return List {
            Section("変更内容") {
                LabeledContent("日付", value: change.change_date)
                LabeledContent("クラス", value: change.displayClassName)
                LabeledContent("時限", value: change.period.isEmpty ? "記載なし" : change.period)
                LabeledContent("変更前", value: change.before_subject.isEmpty ? "記載なし" : change.before_subject)
                LabeledContent("変更後", value: change.after_subject.isEmpty ? "記載なし" : change.after_subject)
                LabeledContent("教員", value: change.teacher.isEmpty ? "記載なし" : change.teacher)
                LabeledContent("教室", value: change.room.isEmpty ? "記載なし" : change.room)
                if !change.note.isEmpty { LabeledContent("備考", value: change.note) }
            }
            if !selection.baseLessons.isEmpty {
                Section("通常の時間割") {
                    ForEach(Array(selection.baseLessons.enumerated()), id: \.offset) { _, lesson in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.names.detailSubject).font(.headline)
                            if !lesson.names.detailTeacher.isEmpty { Text("教員：" + lesson.names.detailTeacher) }
                            if !lesson.names.detailRoom.isEmpty { Text("教室：" + lesson.names.detailRoom) }
                        }
                    }
                }
            }
        }
        .navigationTitle("時間割変更")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LessonSelection: Identifiable {
    let id = UUID()
    let lesson: PDFLesson
    let date: SchoolDate
}

private struct ChangeSelection: Identifiable {
    let id = UUID()
    let change: ScheduleChange
    let baseLessons: [PDFLesson]
}

private struct ContentUnavailableViewPlaceholder: View {
    var body: some View {
        Label("時間割の解析結果がありません。学校資料を選んで解析してください。", systemImage: "calendar.badge.exclamationmark")
            .foregroundStyle(.secondary)
    }
}

private struct TimetablePrimaryClassSelection: View {
    let classes: [String]
    @Binding var value: String

    private var selected: [String] { value.split(separator: "|").map(String.init) }
    private var primary: String { selected.first ?? "" }
    private var additional: String { selected.dropFirst().first ?? "" }

    // The local parser writes class IDs with underscores. A first-year numeric
    // homeroom can be paired with a first-year alphabetic department.
    static func compatible(_ candidate: String, with primary: String) -> Bool {
        func homeroom(_ name: String) -> Bool { name.range(of: "^1_[1-3]$", options: .regularExpression) != nil }
        func department(_ name: String) -> Bool { name.range(of: "^1_[A-Z]{2}$", options: .regularExpression) != nil }
        return (homeroom(primary) && department(candidate)) || (department(primary) && homeroom(candidate))
    }

    private var additionalClasses: [String] { classes.filter { Self.compatible($0, with: primary) } }

    var body: some View {
        Form {
            Picker("クラス", selection: Binding(get: { primary }, set: { value = $0 })) {
                ForEach(classes, id: \.self) { Text($0).tag($0) }
            }
            Picker("追加クラス（1年生のみ・任意）", selection: Binding(
                get: { additionalClasses.contains(additional) ? additional : "" },
                set: { value = $0.isEmpty ? primary : primary + "|" + $0 })) {
                Text("追加なし").tag("")
                ForEach(additionalClasses, id: \.self) { Text($0).tag($0) }
            }
            .disabled(additionalClasses.isEmpty)
        }
        .navigationTitle("クラスを選ぶ")
    }
}

private struct TimetableChangeClassSelection: View {
    let classes: [String]
    @Binding var value: String

    private var selected: Set<String> { Set(value.split(separator: "|").map(String.init)) }
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
                        Toggle(className, isOn: Binding(
                            get: { selected.contains(className) },
                            set: { update(className, selected: $0) }))
                            .disabled(!selected.contains(className) && selected.count >= 30)
                    }
                } header: {
                    HStack {
                        Text(group.0)
                        Spacer()
                        Button(group.1.allSatisfy(selected.contains) ? "すべて解除" : "すべて選択") {
                            toggleGroup(group.1)
                        }
                    }
                }
            }
        }
        .navigationTitle("変更一覧のクラス")
    }

    private func update(_ className: String, selected isSelected: Bool) {
        var next = selected
        if isSelected { next.insert(className) } else { next.remove(className) }
        value = Array(next).sorted().joined(separator: "|")
    }

    private func toggleGroup(_ group: [String]) {
        var next = selected
        if group.allSatisfy(next.contains) {
            next.subtract(group)
        } else {
            for className in group where next.count < 30 { next.insert(className) }
        }
        value = Array(next).sorted().joined(separator: "|")
    }
}
