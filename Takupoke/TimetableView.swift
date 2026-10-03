import SwiftUI
import Combine

struct TimetableView: View {
    @EnvironmentObject var times: TimetableTimesModel
    @ObservedObject var model: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @Binding var todayRequest: UUID?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) var gridDynamicTypeSize
    @AppStorage(MainColor.storageKey) private var mainColor = MainColor.systemDefault.rawValue
    @AppStorage("timetableSelectedClasses") var selectedClassesValue = ""
    @AppStorage("timetableChangeClasses") var changeClassesValue = ""
    @AppStorage("timetableInternationalStudent") var isInternationalStudent = false
    @State var weekStart = SchoolDate.today().displayWeekStart
    @State var navigationHalfAnchor = SchoolDate.today()
    @State var today = SchoolDate.today()
    private let clock = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    @AppStorage("timetableIncludesChanges") var includesChanges = true
    @AppStorage("timetableChangeRange") var changeRangeValue = ChangeRange.today.rawValue
    @State var selectedLesson: LessonSelection?
    @State var selectedSpecial: SpecialSelection?
    @State var selectedChange: ChangeSelection?
    @State var showingWeekPicker = false
    @State var weekPickerDate = Date()
    @State var dayHeaderHeight: CGFloat = 0
    @State var gridViewportWidth: CGFloat = 0
    @State var standardPeriodColumnWidth: CGFloat = 34
    @State var measuredPeriodColumnWidth: CGFloat = 34
    var periodColumnWidth: CGFloat { max(standardPeriodColumnWidth, measuredPeriodColumnWidth) }

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
    var standardDayColumnWidth: CGFloat {
        guard gridViewportWidth > 0 else { return 58 }
        // Five inter-column gaps plus one trailing gap inside the scroll content.
        return max(1, (gridViewportWidth - standardPeriodColumnWidth - 6 * gridSpacing) / 5)
    }
    var dayColumnWidth: CGFloat { standardDayColumnWidth * gridScale }
    var gridRowHeight: CGFloat { 72 * gridScale }
    let gridSpacing: CGFloat = 2

    struct DayGridLayout {
        let day: SchoolDate
        let positioned: [[TimetableSchedule.PositionedBlock]]
        let width: CGFloat
        let fullDayEventTitle: String?
    }

    // Selections hold lesson snapshots. Close them when their underlying
    // accepted data or display scope changes; loading status is not a revision.
    private var detailRevision: [String] {
        let schedule = daySchedule
        var values = [weekStart.iso8601, today.iso8601, selectedClassesValue, changeClassesValue, String(isInternationalStudent), String(includesChanges), changeRangeValue]
        values.append(times.current?.revision ?? "")
        values.append(mappings.current?.revision ?? "")
        for kind: MaterialKind in [.timetable,.changes] {
            let source = model.state.record(for:kind)
            values.append(source?.digest ?? ""); values.append(source?.storedName ?? "")
        }
        for analysis in [schedule.timetable,schedule.events] {
            values.append(analysis?.sourceDigest ?? "")
            values.append(String(analysis?.version ?? 0))
            values.append(String(analysis?.parsedAt.timeIntervalSinceReferenceDate ?? 0))
        }
        values.append(schedule.changes?.sourceDigest ?? "")
        values.append(String(schedule.changes?.version ?? 0))
        values.append(String(schedule.changes?.parsedAt.timeIntervalSinceReferenceDate ?? 0))
        for kind in SpecialScheduleKind.allCases {
            let source = specialSchedules.sources[kind]
            let analysis = specialSchedules.records[kind]?.analysis
            values.append(source?.digest ?? ""); values.append(source?.storedName ?? "")
            values.append(analysis?.sourceDigest ?? "")
            values.append(String(analysis?.version ?? 0))
            values.append(String(analysis?.parsedAt.timeIntervalSinceReferenceDate ?? 0))
        }
        return values
    }

    var body: some View {
        NavigationStack {
            List {
                if !model.ready {
                    Section {
                        if model.failed && !model.busy {
                            Label(model.message ?? "データを読み込めませんでした。", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Button("再試行") { model.loadIfNeeded() }
                                .buttonStyle(.glass)
                        } else {
                            LoadingRow(title: "読み込み中⋯")
                        }
                    }
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
            .onAppear { refreshToday(); consumeTodayRequest() }
            .onChange(of: todayRequest) { _ in consumeTodayRequest() }
            .onReceive(clock) { _ in refreshToday() }
            .task { model.loadIfNeeded() }
            .task { specialSchedules.loadIfNeeded() }
            .task { schoolEvents.loadIfNeeded() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { refreshToday() }
            }
            .onChange(of: weekBounds) { bounds in
                weekStart = min(max(weekStart, bounds.lowerBound), bounds.upperBound)
                if showingWeekPicker {
                    weekPickerDate = min(max(weekPickerDate, weekPickerRange.lowerBound),
                                         weekPickerRange.upperBound)
                }
            }
            .onChange(of: detailRevision) { _ in
                selectedLesson = nil; selectedSpecial = nil; selectedChange = nil
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

    var weekControlColor: Color { (MainColor(rawValue: mainColor) ?? .systemDefault).displayColor }


}

private struct ContentUnavailableViewPlaceholder: View {
    var body: some View {
        Label("時間割の解析結果がありません。", systemImage: "calendar.badge.exclamationmark")
            .foregroundStyle(.secondary)
    }
}
