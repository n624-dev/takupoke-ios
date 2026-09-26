import SwiftUI

struct TimetableView: View {
    @ObservedObject var model: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("timetableSelectedClasses") var selectedClassesValue = ""
    @AppStorage("timetableChangeClasses") var changeClassesValue = ""
    @AppStorage("timetableInternationalStudent") var isInternationalStudent = false
    @State var weekStart = SchoolDate.today().displayWeekStart
    @State var navigationHalfAnchor = SchoolDate.today()
    @State var today = SchoolDate.today()
    @AppStorage("timetableIncludesChanges") var includesChanges = true
    @AppStorage("timetableChangeRange") var changeRangeValue = ChangeRange.today.rawValue
    @State var selectedLesson: LessonSelection?
    @State var selectedSpecial: SpecialSelection?
    @State var selectedChange: ChangeSelection?
    @State var showingWeekPicker = false
    @State var weekPickerDate = Date()
    @State var dayHeaderHeight: CGFloat = 0

    var timetable: PDFAnalysis? { model.state.pdfAnalyses?[MaterialKind.timetable.rawValue] }
    var events: PDFAnalysis? { schoolEvents.analysis }
    var changes: ChangeAnalysis? { model.state.changeAnalysis }
    var specials: [SpecialScheduleAnalysis] {
        specialSchedules.records.values.map(\.analysis).sorted { $0.kind.rawValue < $1.kind.rawValue }
    }
    var classes: [String] { TimetableSchedule.selectableClasses }
    var availableClasses: [String] { TimetableSchedule.classes(in: model.state, specials: specials) }
    var savedClasses: [String] { Self.decode(selectedClassesValue) }
    var selectedClasses: [String] { savedClasses.filter(classes.contains) }
    var savedChangeClasses: [String] { Self.decode(changeClassesValue) }
    var listClasses: [String] {
        changeClassesValue.isEmpty ? selectedClasses : savedChangeClasses.filter(classes.contains)
    }
    var changeRange: ChangeRange { ChangeRange(rawValue: changeRangeValue) ?? .today }
    func isMappedInternational(_ subject: String, _ className: String) -> Bool {
        guard let rules = mappings.current?.rules else { return false }
        return rules.isInternationalStudentSubject(rules.separatingChangeField(subject).subject,
                                                   className: className)
    }
    let weekdayNames = ["月", "火", "水", "木", "金", "土", "日"]
    let dayColumnWidth: CGFloat = 58
    let periodColumnWidth: CGFloat = 34
    let gridRowHeight: CGFloat = 80
    let gridSpacing: CGFloat = 4

    struct DayGridLayout {
        let day: SchoolDate
        let positioned: [[TimetableSchedule.PositionedBlock]]
        let width: CGFloat
        let fullDayEventTitle: String?
    }

    var body: some View {
        NavigationStack {
            List {
                if !model.ready {
                    Section { HStack { ProgressView(); Text("保存済み資料を読み込み中…") } }
                } else if classes.isEmpty {
                    Section {
                        ContentUnavailableViewPlaceholder()
                        if !savedClasses.isEmpty {
                            LabeledContent("保存したクラス", value: TimetableDisplayText.classNames(savedClasses))
                        }
                    }
                } else {
                    Section("表示クラス") {
                        NavigationLink {
                            TimetablePrimaryClassSelection(classes: classes, value: $selectedClassesValue)
                        } label: {
                            LabeledContent("クラス", value: savedClasses.isEmpty ? "未選択" : TimetableDisplayText.classNames(savedClasses))
                        }
                        if savedClasses.contains(where: { !availableClasses.contains($0) }) {
                            Label("保存したクラスの一部は現在の資料にありません。選択は保持しています。", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        Toggle("留学生向けの授業も表示", isOn: $isInternationalStudent)
                    }
                    weekSection
                    changesSection
                }
            }
            .navigationTitle("時間割")
            .task { model.loadIfNeeded() }
            .task { specialSchedules.loadIfNeeded() }
            .task { schoolEvents.loadIfNeeded() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { today = SchoolDate.today() }
            }
            .onChange(of: weekBounds) { bounds in
                weekStart = min(max(weekStart, bounds.lowerBound), bounds.upperBound)
                if showingWeekPicker {
                    weekPickerDate = min(max(weekPickerDate, weekPickerRange.lowerBound),
                                         weekPickerRange.upperBound)
                }
            }
            .sheet(item: $selectedLesson) { selection in
                NavigationStack { lessonDetail(selection) }
            }
            .sheet(item: $selectedChange) { selection in
                NavigationStack { changeDetail(selection) }
            }
            .sheet(item: $selectedSpecial) { selection in
                NavigationStack { specialDetail(selection) }
            }
            .sheet(isPresented: $showingWeekPicker) {
                NavigationStack {
                    DatePicker("移動する日付", selection: $weekPickerDate, in: weekPickerRange,
                               displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .navigationTitle("週を選ぶ")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("キャンセル") { showingWeekPicker = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("この週へ移動") { selectPickedWeek() }
                                    .disabled(!pickerWeekIsReachable)
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var weekSection: some View {
        Section {
            HStack {
                if canMovePrevious { Button("前週") { moveWeek(-7) } }
                Spacer()
                Button {
                    openWeekPicker()
                } label: {
                    Label("\(weekStart.month)/\(weekStart.day)〜\(weekStart.addingDays(6)!.month)/\(weekStart.addingDays(6)!.day)",
                          systemImage: "calendar")
                        .font(.subheadline.monospacedDigit())
                }
                .accessibilityLabel("表示する週を選ぶ")
                Spacer()
                if canMoveNext { Button("翌週") { moveWeek(7) } }
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
            if events == nil {
                Label("学校行事は未取得です。設定から学校行事を取得できます。", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
            if let sourceCheckMessage = schoolEvents.sourceCheckMessage {
                Label(sourceCheckMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            ForEach(SpecialScheduleKind.allCases) { kind in
                if let source = specialSchedules.sources[kind],
                   let record = specialSchedules.records[kind],
                   source.digest != record.digest {
                    Label("\(kind.title)は前回の解析結果です。", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            if selectedClasses.isEmpty {
                Text(savedClasses.isEmpty ? "クラスを設定すると時間割を表示します。" :
                     "保存したクラスは現在の資料に見つかりません。資料を再解析するか、クラスを選び直してください。")
                    .foregroundStyle(.secondary)
            } else {
                weekGrid
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
            weekEvents
        } header: { Text("週の時間割") }
    }

}

private struct ContentUnavailableViewPlaceholder: View {
    var body: some View {
        Label("時間割の解析結果がありません。設定の「ファイル選択」でファイルを選んで解析してください。", systemImage: "calendar.badge.exclamationmark")
            .foregroundStyle(.secondary)
    }
}
