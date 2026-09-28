import SwiftUI
import Combine

/// Embedded in HomeView's List; every row uses the same saved models as the timetable.
struct HomeTodayView: View {
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @EnvironmentObject private var mappings: MappingModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("timetableSelectedClasses") private var classesValue = ""
    @AppStorage("timetableInternationalStudent") private var international = false
    @AppStorage("mainColor") private var mainColor = MainColor.blue.rawValue
    @State private var now = Date()
    @State private var selectedLesson: LessonSelection?
    @State private var selectedSpecial: SpecialSelection?
    @State private var selectedChange: ChangeSelection?
    let openTimetable: () -> Void
    private let clock = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private var day: SchoolDate { TimetableDaySchedule.schoolDay(at: now) }
    private var classes: [String] { TimetableView.decode(classesValue) }
    private var accent: Color { (MainColor(rawValue: mainColor) ?? .blue).color }
    private var schedule: TimetableDaySchedule {
        TimetableDaySchedule(timetable: materials.state.pdfAnalyses?[MaterialKind.timetable.rawValue],
            changes: materials.state.changeAnalysis, events: schoolEvents.analysis,
            specials: specialSchedules.records.values.map(\.analysis).sorted { $0.kind.rawValue < $1.kind.rawValue },
            includesChanges: true)
    }
    private var presentation: TimetablePresentation { TimetablePresentation(schedule: schedule, mappings: mappings) }
    private var ready: Bool { materials.ready && specialSchedules.ready && schoolEvents.ready && mappings.ready }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(day.month)月\(day.day)日（\(["月", "火", "水", "木", "金", "土", "日"][day.schoolWeekday - 1])）")
                    .font(.headline)
                let titles = TimetableSchedule.events(on: day, analysis: schedule.events).map(\.title)
                if !titles.isEmpty {
                    Text(TimetableDisplayText.kana(titles.joined(separator: "・")))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !ready {
                LoadingRow(title: "読み込み中⋯")
            } else if classes.isEmpty {
                NavigationLink("クラスを選択") {
                    TimetablePrimaryClassSelection(classes: TimetableSchedule.selectableClasses, value: $classesValue)
                }
            } else {
                if schedule.changes == nil { status("時間割変更の解析結果がありません。") }
                if schedule.events == nil { status("学校行事は未取得です。") }
                ForEach(classes, id: \.self) { className in
                    classRows(className)
                }
            }
        } header: {
            HStack {
                Text("今日の予定")
                Spacer()
                Button(action: openTimetable) {
                    HStack(spacing: 4) {
                        Text("時間割を見る")
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.subheadline)
                .buttonStyle(.plain)
                .foregroundStyle(accent)
            }
            .textCase(nil)
        }
        .onAppear { now = Date() }
        .onReceive(clock) { date in if scenePhase == .active { now = date } }
        .onChange(of: scenePhase) { phase in if phase == .active { now = Date() } }
        .sheet(item: $selectedLesson) { selection in
            NavigationStack { presentation.lessonDetail(selection) }
        }
        .sheet(item: $selectedSpecial) { selection in
            NavigationStack { presentation.specialDetail(selection) }
        }
        .sheet(item: $selectedChange) { selection in
            NavigationStack { presentation.changeDetail(selection) }
        }
    }

    @ViewBuilder private func classRows(_ className: String) -> some View {
        let blocks = schedule.blocks(on: day, className: className, international: international) { subject, name in
            guard let rules = mappings.current?.rules else { return false }
            return rules.isInternationalStudentSubject(rules.separatingChangeField(subject).subject, className: name)
        }
        let missing = schedule.missingMessages(on: day, className: className)
        Text(TimetableDisplayText.className(className))
            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
        ForEach(missing, id: \.self) { status($0) }
        if blocks.isEmpty && missing.isEmpty && schedule.changes != nil && schedule.events != nil {
            // The event title is already shown once above all classes.
            Text("授業はありません。")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
            HomeLessonRow(block: block, time: schedule.cardTime(block, on: day, className: className),
                names: names(for: block), inProgress: schedule.isInProgress(block, on: day, className: className, now: now),
                accent: accent) {
                switch block.content {
                case .normal(let lesson):
                    selectedLesson = LessonSelection(lesson: lesson, date: day,
                        startPeriod: block.startPeriod, endPeriod: block.endPeriod)
                case .special(let item):
                    selectedSpecial = SpecialSelection(item: item, startPeriod: block.startPeriod,
                        endPeriod: block.endPeriod, timeRange: schedule.cardTime(block, on: day, className: className))
                case .change(let change): selectedChange = presentation.changeSelection(for: change)
                }
            }
        }
    }

    private func names(for block: TimetableSchedule.GridBlock) -> TimetableLessonNames {
        switch block.content {
        case .normal(let lesson): return mappings.names(for: lesson)
        case .special(let item):
            let source = TimetableLessonNames(subject: item.lesson.subject, teacher: item.lesson.teacher, room: item.lesson.room)
            return mappings.current?.rules.applying(to: source, className: item.lesson.className) ?? source
        case .change(let change): return mappings.names(for: change).after
        }
    }

    private func status(_ message: String) -> some View {
        Text(message).font(.subheadline).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
