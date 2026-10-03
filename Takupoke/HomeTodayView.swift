import SwiftUI
import Combine

/// Embedded in HomeView's List; every row uses the same saved models as the timetable.
struct HomeTodayView: View {
    @EnvironmentObject private var times: TimetableTimesModel
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @EnvironmentObject private var mappings: MappingModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("timetableSelectedClasses") private var classesValue = ""
    @AppStorage("timetableInternationalStudent") private var international = false
    @AppStorage(MainColor.storageKey) private var mainColor = MainColor.systemDefault.rawValue
    @State private var now = Date()
    @Binding var selectedLesson: LessonSelection?
    @Binding var selectedSpecial: SpecialSelection?
    @Binding var selectedChange: ChangeSelection?
    let openTimetable: () -> Void
    private let clock = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private var day: SchoolDate { TimetableDaySchedule.schoolDay(at: now) }
    private var classes: [String] { TimetableView.decode(classesValue) }
    private var accent: Color { (MainColor(rawValue: mainColor) ?? .systemDefault).displayColor }
    private var schedule: TimetableDaySchedule {
        TimetableDaySchedule(timetable: materials.state.pdfAnalyses?[MaterialKind.timetable.rawValue],
            changes: materials.state.changeAnalysis, events: schoolEvents.analysis,
            specials: specialSchedules.records.values.map(\.analysis).sorted { $0.kind.rawValue < $1.kind.rawValue },
            includesChanges: true, customTimes: times.current?.data)
    }
    private var presentation: TimetablePresentation { TimetablePresentation(schedule: schedule, mappings: mappings) }
    private var ready: Bool { materials.ready && specialSchedules.ready && schoolEvents.ready && mappings.ready }

    private var loadFailed: Bool {
        (!materials.ready && !materials.busy && materials.failed) ||
        (!specialSchedules.ready && !specialSchedules.busy && specialSchedules.failed) ||
        (!schoolEvents.ready && !schoolEvents.busy && schoolEvents.failed) ||
        (!mappings.ready && !mappings.busy && mappings.failed)
    }

    private func retryLoading() {
        materials.loadIfNeeded()
        specialSchedules.loadIfNeeded()
        schoolEvents.loadIfNeeded()
        mappings.loadIfNeeded()
    }

    private var unreflectedTitles: [String] {
        var values = [String]()
        if let source = materials.state.record(for:.timetable) {
            let a = materials.state.pdfAnalyses?[MaterialKind.timetable.rawValue]
            if a?.sourceDigest != source.digest || a?.version != PDFAnalysis.currentVersion(for:.timetable) { values.append(MaterialKind.timetable.title) }
        }
        if let source = materials.state.record(for:.changes), materials.state.changeAnalysis?.sourceDigest != source.digest || materials.state.changeAnalysis?.version != ChangeAnalysis.parserVersion { values.append(MaterialKind.changes.title) }
        for kind in SpecialScheduleKind.allCases {
            if let source = specialSchedules.sources[kind], specialSchedules.records[kind]?.digest != source.digest || specialSchedules.records[kind]?.analysis.version != SpecialScheduleAnalysis.parserVersion { values.append(kind.title) }
        }
        return values
    }

    // Selections hold lesson snapshots. Close them when their underlying
    // accepted data or display scope changes; loading status is not a revision.
    private var detailRevision: [String] {
        var values = [day.iso8601, classesValue, String(international)]
        values.append(times.current?.revision ?? "")
        values.append(mappings.current?.revision ?? "")
        for kind: MaterialKind in [.timetable,.changes] {
            let source = materials.state.record(for:kind)
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
            ForEach(unreflectedTitles,id:\.self) { title in
                Label("\(title)の新しい資料をまだ反映できていません。前回の正常結果を表示しています。",systemImage:"exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            if loadFailed {
                Text("データを読み込めませんでした。")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("再試行", action: retryLoading)
            } else if !ready {
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
        .onChange(of: detailRevision) { _ in
            selectedLesson = nil; selectedSpecial = nil; selectedChange = nil
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
