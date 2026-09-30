import SwiftUI

struct TimetableView: View {
    @EnvironmentObject var times: TimetableTimesModel
    @ObservedObject var model: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @Binding var todayRequest: UUID?
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("mainColor") private var mainColor = MainColor.blue.rawValue
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
    @State var gridViewportWidth: CGFloat = 0
    @State var periodColumnWidth: CGFloat = 34

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
    var dayColumnWidth: CGFloat {
        guard gridViewportWidth > 0 else { return 58 }
        // Five inter-column gaps plus one trailing gap inside the scroll content.
        return max(1, (gridViewportWidth - periodColumnWidth - 6 * gridSpacing) / 5)
    }
    let gridRowHeight: CGFloat = 72
    let gridSpacing: CGFloat = 2

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
                    Section { LoadingRow(title: "読み込み中⋯") }
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
                    }
                    weekSection
                    changesSection
                }
            }
            .navigationTitle("時間割")
            .onAppear { consumeTodayRequest() }
            .onChange(of: todayRequest) { _ in consumeTodayRequest() }
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

    var weekControlColor: Color { (MainColor(rawValue: mainColor) ?? .blue).color }


}

private struct ContentUnavailableViewPlaceholder: View {
    var body: some View {
        Label("時間割の解析結果がありません。", systemImage: "calendar.badge.exclamationmark")
            .foregroundStyle(.secondary)
    }
}
