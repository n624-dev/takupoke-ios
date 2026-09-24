import SwiftUI
import UIKit

private struct DayHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct TimetableView: View {
    @ObservedObject var model: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("timetableSelectedClasses") private var selectedClassesValue = ""
    @AppStorage("timetableChangeClasses") private var changeClassesValue = ""
    @AppStorage("timetableInternationalStudent") private var isInternationalStudent = false
    @State private var weekStart = SchoolDate.today().displayWeekStart
    @State private var navigationHalfAnchor = SchoolDate.today()
    @State private var today = SchoolDate.today()
    @AppStorage("timetableIncludesChanges") private var includesChanges = true
    @AppStorage("timetableChangeRange") private var changeRangeValue = ChangeRange.today.rawValue
    @State private var selectedLesson: LessonSelection?
    @State private var selectedSpecial: SpecialSelection?
    @State private var selectedChange: ChangeSelection?
    @State private var showingWeekPicker = false
    @State private var weekPickerDate = Date()
    @State private var dayHeaderHeight: CGFloat = 0

    private var timetable: PDFAnalysis? { model.state.pdfAnalyses?[MaterialKind.timetable.rawValue] }
    private var events: PDFAnalysis? { schoolEvents.analysis }
    private var changes: ChangeAnalysis? { model.state.changeAnalysis }
    private var specials: [SpecialScheduleAnalysis] {
        specialSchedules.records.values.map(\.analysis).sorted { $0.kind.rawValue < $1.kind.rawValue }
    }
    private var classes: [String] { TimetableSchedule.selectableClasses }
    private var availableClasses: [String] { TimetableSchedule.classes(in: model.state, specials: specials) }
    private var savedClasses: [String] { Self.decode(selectedClassesValue) }
    private var selectedClasses: [String] { savedClasses.filter(classes.contains) }
    private var savedChangeClasses: [String] { Self.decode(changeClassesValue) }
    private var listClasses: [String] {
        changeClassesValue.isEmpty ? selectedClasses : savedChangeClasses.filter(classes.contains)
    }
    private var changeRange: ChangeRange { ChangeRange(rawValue: changeRangeValue) ?? .today }
    private func isMappedInternational(_ subject: String, _ className: String) -> Bool {
        guard let rules = mappings.current?.rules else { return false }
        return rules.isInternationalStudentSubject(rules.separatingChangeField(subject).subject,
                                                   className: className)
    }
    private let weekdayNames = ["月", "火", "水", "木", "金", "土", "日"]
    private let dayColumnWidth: CGFloat = 58
    private let periodColumnWidth: CGFloat = 44
    private let gridRowHeight: CGFloat = 100
    private let gridSpacing: CGFloat = 4

    private struct DayGridLayout {
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

    private var weekGrid: some View {
        let days = TimetableSchedule.displayedDays(weekStart: weekStart, classes: selectedClasses,
                                                   timetable: timetable, changes: changes, events: events,
                                                   includesChanges: includesChanges,
                                                   isInternationalStudent: isInternationalStudent,
                                                   specials: specials, matchedByRule: isMappedInternational)
        let columns = days.map(dayLayout)
        let eventsOnly = !columns.isEmpty && columns.allSatisfy { $0.fullDayEventTitle != nil }
        return ScrollView(.horizontal) {
            if eventsOnly {
                HStack(alignment: .top, spacing: gridSpacing) {
                    ForEach(columns, id: \.day) { column in
                        VStack(spacing: gridSpacing) {
                            dayHeaderCell(column)
                            if let title = column.fullDayEventTitle {
                                fullDayEventCard(title, width: column.width, height: nil)
                            }
                        }
                    }
                }
            } else {
                Grid(alignment: .topLeading, horizontalSpacing: gridSpacing, verticalSpacing: gridSpacing) {
                    GridRow {
                        Text("時限")
                            .font(.caption.bold())
                            .frame(width: periodColumnWidth, alignment: .center)
                            .gridCellAnchor(.center)
                        ForEach(columns, id: \.day) { column in
                            dayHeaderCell(column).gridCellAnchor(.center)
                        }
                    }
                    GridRow {
                        VStack(spacing: gridSpacing) {
                            ForEach(1...8, id: \.self) { period in
                                let commonTime = commonPeriodTime(period, days: days)
                                VStack(spacing: 2) {
                                    Text("\(period)").font(.system(size: 15, weight: .semibold))
                                    if let commonTime {
                                        Text(TimetableDisplayText.periodTime(commonTime))
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .multilineTextAlignment(.center)
                                .frame(width: periodColumnWidth, height: gridRowHeight, alignment: .center)
                            }
                        }
                        ForEach(columns, id: \.day) { column in
                            dayColumn(column, days: days)
                        }
                    }
                }
            }
        }
        .onPreferenceChange(DayHeaderHeightKey.self) { height in
            if abs(dayHeaderHeight - height) > 0.5 { dayHeaderHeight = height }
        }
        .accessibilityLabel("\(selectedClasses.map(TimetableDisplayText.className).joined(separator: "・"))の週の時間割")
    }

    private func dayHeaderCell(_ column: DayGridLayout) -> some View {
        dayHeader(on: column.day)
            .frame(width: column.width, height: dayHeaderHeight > 0 ? dayHeaderHeight : nil,
                   alignment: .top)
            .background(column.day == today ? Color.accentColor.opacity(0.14) :
                        Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10))
    }

    private func dayLayout(_ day: SchoolDate) -> DayGridLayout {
        let positioned = selectedClasses.map { className in
            TimetableSchedule.positioned(TimetableSchedule.blocks(on: day, className: className,
                timetable: timetable, changes: changes, includesChanges: includesChanges, events: events,
                specials: specials, isInternationalStudent: isInternationalStudent,
                matchedByRule: isMappedInternational))
        }
        let widths = positioned.map { laneWidth($0) }
        let width = widths.reduce(0, +) + gridSpacing * CGFloat(max(0, widths.count - 1))
        return DayGridLayout(day: day, positioned: positioned, width: width,
                             fullDayEventTitle: TimetableSchedule.fullDayEventTitle(
                                plan: TimetableSchedule.dayPlan(on: day, events: events), layouts: positioned))
    }

    private func dayColumn(_ column: DayGridLayout, days: [SchoolDate]) -> some View {
        Group {
            if let title = column.fullDayEventTitle {
                fullDayEventCard(title, width: column.width,
                                 height: 8 * gridRowHeight + 7 * gridSpacing)
            } else {
                HStack(alignment: .top, spacing: gridSpacing) {
                    ForEach(selectedClasses.indices, id: \.self) { index in
                        classLane(on: column.day, className: selectedClasses[index], days: days,
                                  positioned: column.positioned[index])
                    }
                }
            }
        }
        .frame(width: column.width, height: 8 * gridRowHeight + 7 * gridSpacing, alignment: .topLeading)
    }

    private func fullDayEventCard(_ title: String, width: CGFloat, height: CGFloat?) -> some View {
        Text(TimetableDisplayText.kana(title))
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(width: width, height: height, alignment: .center)
            .frame(minHeight: height == nil ? gridRowHeight : nil)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.3)))
            .accessibilityLabel(title)
    }

    private func dayHeader(on day: SchoolDate) -> some View {
        let plan = TimetableSchedule.dayPlan(on: day, events: events)
        return VStack(alignment: .center, spacing: 2) {
            VStack(spacing: 0) {
                Text("\(day.month)/\(day.day)").font(.subheadline.bold().monospacedDigit())
                Text("(\(weekdayNames[day.schoolWeekday - 1]))").font(.caption)
                if day == today { Text("今日").font(.caption2.bold()) }
            }
            ForEach(Array(plan.events.filter { $0.apiTag != "行事メモ" }.enumerated()), id: \.offset) { _, event in
                Text(TimetableDisplayText.kana(event.title))
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if plan.apiTest && selectedClasses.contains(where: { className in
                !specials.contains { $0.kind == .exam && $0.applies(date: day.iso8601, className: className) }
            }) {
                Text("試験時間割：未公開または未解析です")
                    .font(.caption2).foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if plan.apiTestReturn && selectedClasses.contains(where: { className in
                !specials.contains { $0.kind == .examReturn && $0.applies(date: day.iso8601, className: className) }
            }) {
                Text("試験返却時間割：未公開または未解析です")
                    .font(.caption2).foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: DayHeaderHeightKey.self, value: proxy.size.height)
        })
        .accessibilityElement(children: .combine)
    }

    private func laneWidth(_ blocks: [TimetableSchedule.PositionedBlock]) -> CGFloat {
        let lanes = max(1, (blocks.map(\.lane).max() ?? -1) + 1)
        return CGFloat(lanes) * dayColumnWidth + CGFloat(lanes - 1) * gridSpacing
    }

    private func classLane(on day: SchoolDate, className: String, days: [SchoolDate],
                           positioned: [TimetableSchedule.PositionedBlock]) -> some View {
        let width = laneWidth(positioned)
        let plan = TimetableSchedule.dayPlan(on: day, events: events)
        return ZStack(alignment: .topLeading) {
            VStack(spacing: gridSpacing) {
                ForEach(1...8, id: \.self) { period in
                    let occupied = positioned.contains { $0.block.startPeriod <= period && period <= $0.block.endPeriod }
                    Group {
                        if occupied || plan.isNoClass { Color.clear }
                        else { Text("—").foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .center) }
                    }
                    .padding(6)
                    .frame(width: width, height: gridRowHeight, alignment: .center)
                    .background(plan.isNoClass ? Color.orange.opacity(0.10) : Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
                }
            }
            ForEach(positioned.indices, id: \.self) { index in
                let entry = positioned[index]
                let span = entry.block.endPeriod - entry.block.startPeriod + 1
                let height = CGFloat(span) * gridRowHeight + CGFloat(span - 1) * gridSpacing
                gridCard(entry.block, on: day, className: className, days: days, height: height)
                    .offset(x: CGFloat(entry.lane) * (dayColumnWidth + gridSpacing),
                            y: CGFloat(entry.block.startPeriod - 1) * (gridRowHeight + gridSpacing))
            }
        }
        .frame(width: width, height: 8 * gridRowHeight + 7 * gridSpacing, alignment: .topLeading)
    }

    private func commonPeriodTime(_ period: Int, days: [SchoolDate]) -> String? {
        var times: Set<String> = []
        for day in days {
            let plan = TimetableSchedule.dayPlan(on: day, events: events)
            if plan.isNoClass && !plan.apiNoClass { continue }
            for className in selectedClasses {
                let slot = TimetableSchedule.slot(on: day, period: period, className: className,
                                                  timetable: timetable, changes: changes,
                                                  includesChanges: includesChanges, events: events,
                                                  specials: specials)
                let visible = slot.displayedLessons.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent,
                                                                                                matchedByRule: isMappedInternational) } ||
                    slot.displayedSpecialLessons.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent,
                                                                                               matchedByRule: isMappedInternational) } ||
                    slot.changes.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent,
                                                                              matchedByRule: isMappedInternational) }
                guard visible else { continue }
                guard let time = slotTime(slot, on: day, className: className, period: period) else { return nil }
                times.insert(time)
                if times.count > 1 { return nil }
            }
        }
        return times.first
    }

    private func slotTime(_ slot: TimetableSchedule.Slot, on day: SchoolDate,
                          className: String, period: Int) -> String? {
        if !slot.specialLessons.isEmpty {
            let times = Set(slot.specialLessons.compactMap(\.timeRange))
            return times.count == 1 && slot.specialLessons.allSatisfy({ $0.timeRange != nil })
                ? times.first : nil
        }
        let applicable = specials.filter { $0.applies(date: day.iso8601, className: className) }
        if applicable.isEmpty { return TimetableSchedule.normalPeriodTimes[period - 1] }
        let times = Set(applicable.compactMap { $0.periodTimes[period] })
        return times.count == 1 && applicable.allSatisfy({ $0.periodTimes[period] != nil })
            ? times.first : nil
    }

    private func gridCard(_ block: TimetableSchedule.GridBlock, on day: SchoolDate,
                          className: String, days: [SchoolDate], height: CGFloat) -> some View {
        let time = cardTime(block, on: day, className: className)
        let isChange: Bool = {
            if case .change = block.content { return true }
            return false
        }()
        let showTime = block.startPeriod != block.endPeriod ||
            commonPeriodTime(block.startPeriod, days: days) == nil
        return Button {
            switch block.content {
            case .normal(let lesson):
                selectedLesson = LessonSelection(lesson: lesson, date: day,
                                                 startPeriod: block.startPeriod, endPeriod: block.endPeriod)
            case .special(let item):
                selectedSpecial = SpecialSelection(item: item, startPeriod: block.startPeriod,
                                                   endPeriod: block.endPeriod, timeRange: time)
            case .change(let change):
                selectedChange = changeSelection(for: change)
            }
        } label: {
            VStack(alignment: .center, spacing: 1) {
                switch block.content {
                case .normal(let lesson):
                    Text(cardText(TimetableDisplayText.continuous(lesson.names.cellSubject),
                                  fontSize: 11, weight: .semibold, lines: 2))
                        .font(.system(size: 11, weight: .semibold)).lineLimit(2)
                    if showTime, let time {
                        Text(TimetableDisplayText.periodTime(time))
                            .font(.system(size: 8.5)).foregroundStyle(.secondary).lineLimit(3)
                    }
                    if !lesson.names.cellTeacher.isEmpty {
                        Text(cardText(TimetableDisplayText.continuous(lesson.names.cellTeacher), fontSize: 9))
                            .font(.system(size: 9)).lineLimit(1)
                    }
                    if !lesson.names.cellRoom.isEmpty {
                        Text(cardRoom(lesson.names.cellRoom)).font(.system(size: 9)).lineLimit(1)
                    }
                case .special(let item):
                    Text(cardText(TimetableDisplayText.kana(item.lesson.subject),
                                  fontSize: 11, weight: .semibold, lines: 2))
                        .font(.system(size: 11, weight: .semibold)).lineLimit(2)
                    if showTime, let time {
                        Text(TimetableDisplayText.periodTime(time))
                            .font(.system(size: 8.5)).foregroundStyle(.secondary).lineLimit(3)
                    }
                    if !item.lesson.teacher.isEmpty {
                        Text(cardText(TimetableDisplayText.kana(item.lesson.teacher), fontSize: 9))
                            .font(.system(size: 9)).lineLimit(1)
                    }
                    if !item.lesson.room.isEmpty {
                        Text(cardRoom(item.lesson.room)).font(.system(size: 9)).lineLimit(1)
                    }
                case .change(let change):
                    let names = mappings.names(for: change).after
                    HStack(spacing: 1) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 8))
                        Text(cardText(names.cellSubject.isEmpty ? "変更を確認" :
                                      TimetableDisplayText.kana(names.cellSubject),
                                      fontSize: 11, weight: .semibold, lines: 2,
                                      width: dayColumnWidth - 19))
                            .font(.system(size: 11, weight: .semibold)).lineLimit(2)
                    }
                    if showTime, let time {
                        Text(TimetableDisplayText.periodTime(time))
                            .font(.system(size: 8.5)).foregroundStyle(.secondary).lineLimit(3)
                    }
                    if !names.cellTeacher.isEmpty {
                        Text(cardText(TimetableDisplayText.kana(names.cellTeacher), fontSize: 9))
                            .font(.system(size: 9)).lineLimit(1)
                    }
                    if !names.cellRoom.isEmpty {
                        Text(cardRoom(names.cellRoom)).font(.system(size: 9)).lineLimit(1)
                    }
                }
            }
            .padding(3)
            .frame(width: dayColumnWidth, height: height, alignment: .center)
            .multilineTextAlignment(.center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: dayColumnWidth, height: height)
        .foregroundStyle(isChange ? Color.orange : Color.primary)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("\(TimetableDisplayText.className(className)) " +
            (block.startPeriod == block.endPeriod ? "\(block.startPeriod)限" :
                "\(block.startPeriod)〜\(block.endPeriod)限") + "の授業詳細")
    }

    private func cardRoom(_ source: String) -> String {
        let full = TimetableDisplayText.continuous(source)
        let compact = PDFDisplayText.continuous(TimetableDisplayText.halfwidthKana(source))
        return cardText(full, fontSize: 9, alternative: compact)
    }

    private func cardText(_ value: String, fontSize: CGFloat, weight: UIFont.Weight = .regular,
                          lines: Int = 1, width: CGFloat? = nil, alternative: String? = nil) -> String {
        let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        let available = (width ?? dayColumnWidth - 8) - 2
        func fits(_ text: String) -> Bool {
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            if lines == 1 { return (text as NSString).size(withAttributes: attributes).width <= available }
            let bounds = (text as NSString).boundingRect(
                with: CGSize(width: available, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
            return bounds.height <= font.lineHeight * CGFloat(lines) + 0.5
        }
        let primary = value.replacingOccurrences(of: "\n", with: " ")
        if fits(primary) { return primary }
        let fallback = (alternative ?? primary).replacingOccurrences(of: "\n", with: " ")
        if fits(fallback) { return fallback }
        let characters = Array(fallback)
        var lower = 0, upper = characters.count
        while lower < upper {
            let middle = (lower + upper + 1) / 2
            if fits(String(characters.prefix(middle)) + "⋯") { lower = middle }
            else { upper = middle - 1 }
        }
        return String(characters.prefix(lower)) + "⋯"
    }

    private func cardTime(_ block: TimetableSchedule.GridBlock, on day: SchoolDate,
                          className: String) -> String? {
        let firstSlot = TimetableSchedule.slot(on: day, period: block.startPeriod, className: className,
                                               timetable: timetable, changes: changes,
                                               includesChanges: includesChanges, events: events, specials: specials)
        guard let first = slotTime(firstSlot, on: day, className: className,
                                   period: block.startPeriod) else { return nil }
        if block.startPeriod == block.endPeriod { return first }
        let lastSlot = TimetableSchedule.slot(on: day, period: block.endPeriod, className: className,
                                              timetable: timetable, changes: changes,
                                              includesChanges: includesChanges, events: events, specials: specials)
        guard let last = slotTime(lastSlot, on: day, className: className,
                                  period: block.endPeriod),
              let startTime = first.components(separatedBy: "〜").first,
              let endTime = last.components(separatedBy: "〜").last else { return nil }
        return "\(startTime)〜\(endTime)"
    }

    private var changesSection: some View {
        let visible = listClasses.flatMap { className in
            TimetableSchedule.changes(in: changes, className: className, range: changeRange,
                                      today: today, weekStart: weekStart)
        }.filter { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent,
                                                   matchedByRule: isMappedInternational) }
            .sorted { ($0.change_date, $0.period, $0.displayClassName) < ($1.change_date, $1.period, $1.displayClassName) }
        return Section {
            Picker("表示範囲", selection: Binding(
                get: { changeRange }, set: { changeRangeValue = $0.rawValue })) {
                ForEach(ChangeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            NavigationLink {
                TimetableChangeClassSelection(classes: classes, value: Binding(
                    get: { changeClassesValue.isEmpty ? selectedClassesValue : changeClassesValue },
                    set: { changeClassesValue = $0 }))
            } label: {
                LabeledContent("対象クラス", value: changeClassesValue.isEmpty
                    ? (savedClasses.isEmpty ? "未選択" : TimetableDisplayText.classNames(savedClasses))
                    : TimetableDisplayText.classNames(savedChangeClasses))
            }
            if !changeClassesValue.isEmpty && savedChangeClasses.contains(where: { !availableClasses.contains($0) }) {
                Label("保存した対象クラスの一部は現在の資料にありません。選択は保持しています。", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
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
                    let selection = changeSelection(for: change)
                    Button {
                        selectedChange = selection
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(change.change_date) · \(TimetableDisplayText.className(change.displayClassName)) · \(change.period.isEmpty ? "時限未記載" : change.displayPeriod)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(TimetableDisplayText.kana(changeSummary(selection))).font(.subheadline)
                            if !change.note.isEmpty { Text(TimetableDisplayText.kana(change.note)).font(.caption).foregroundStyle(.secondary) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: { Text("時間割変更一覧") }
    }

    private func moveWeek(_ days: Int) {
        if let next = weekStart.addingDays(days), weekBounds.contains(next) { weekStart = next }
    }

    private var weekBounds: ClosedRange<SchoolDate> {
        TimetableSchedule.reachableWeekBounds(containing: navigationHalfAnchor,
                                               classes: selectedClasses, timetable: timetable,
                                               changes: changes, events: events,
                                               includesChanges: includesChanges, specials: specials)
    }

    private func pickerDate(_ day: SchoolDate) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
    }

    private var weekPickerRange: ClosedRange<Date> {
        pickerDate(weekBounds.lowerBound)...pickerDate(weekBounds.upperBound.addingDays(6)!)
    }

    private var pickerWeekIsReachable: Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let parts = calendar.dateComponents([.year, .month, .day], from: weekPickerDate)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let picked = SchoolDate(year: year, month: month, day: day) else { return false }
        return weekBounds.contains(picked.monday)
    }

    private func openWeekPicker() {
        weekPickerDate = pickerDate(min(max(weekStart, weekBounds.lowerBound), weekBounds.upperBound))
        showingWeekPicker = true
    }

    private func selectPickedWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let parts = calendar.dateComponents([.year, .month, .day], from: weekPickerDate)
        if let year = parts.year, let month = parts.month, let day = parts.day,
           let picked = SchoolDate(year: year, month: month, day: day),
           weekBounds.contains(picked.monday) {
            weekStart = picked.monday
        }
        showingWeekPicker = false
    }

    private var canMovePrevious: Bool {
        guard let previous = weekStart.addingDays(-7) else { return false }
        return weekBounds.contains(previous)
    }

    private var canMoveNext: Bool {
        guard let next = weekStart.addingDays(7) else { return false }
        return weekBounds.contains(next)
    }

    private static func decode(_ value: String) -> [String] {
        value.split(separator: "|").map(String.init).reduce(into: [String]()) { result, name in
            if !result.contains(name) { result.append(name) }
        }
    }

    private func beforeSubject(_ selection: ChangeSelection) -> String {
        if !selection.change.before_subject.isEmpty {
            return mappings.names(for: selection.change).before.cellSubject
        }
        let names = selection.baseLessons.map(\.names.cellSubject).reduce(into: [String]()) { result, name in
            if !name.isEmpty && !result.contains(name) { result.append(name) }
        }
        return names.isEmpty ? "記載なし" : names.joined(separator: "・")
    }

    private func changeSummary(_ selection: ChangeSelection) -> String {
        let before = beforeSubject(selection)
        let parsedAfter = mappings.names(for: selection.change).after.cellSubject
        let after = parsedAfter.isEmpty ? "記載なし" : parsedAfter
        return "\(before) → \(after)"
    }

    private func changeSelection(for change: ScheduleChange) -> ChangeSelection {
        guard let day = SchoolDate(iso8601: change.change_date) else {
            return ChangeSelection(change: change, baseLessons: [], baseSpecialLessons: [])
        }
        let originals = (change.gridPeriods ?? []).map { period in
            TimetableSchedule.slot(on: day, period: period, className: change.displayClassName,
                                   timetable: timetable, changes: nil, includesChanges: false,
                                   events: events, specials: specials)
        }
        return ChangeSelection(change: change, baseLessons: originals.flatMap(\.baseLessons),
                               baseSpecialLessons: originals.flatMap(\.specialLessons))
    }

    private var weekEvents: some View {
        let rows = (0..<7).compactMap { weekStart.addingDays($0) }.compactMap { day -> (SchoolDate, [String])? in
            let titles = TimetableSchedule.events(on: day, analysis: events).map(\.title)
            return titles.isEmpty ? nil : (day, titles)
        }
        return Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, entry in
                        Text(TimetableDisplayText.kana("\(entry.0.month)/\(entry.0.day) " + entry.1.joined(separator: "・")))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func lessonDetail(_ selection: LessonSelection) -> some View {
        let lesson = selection.lesson
        let names = mappings.names(for: lesson)
        return List {
            Section("通常の授業") {
                LabeledContent("日付", value: selection.date.iso8601)
                LabeledContent("クラス", value: TimetableDisplayText.className(lesson.className))
                LabeledContent("時限", value: selection.startPeriod == selection.endPeriod
                               ? "\(selection.startPeriod)限" : "\(selection.startPeriod)〜\(selection.endPeriod)限")
                LabeledContent("時刻", value: normalTime(from: selection.startPeriod, to: selection.endPeriod))
                LabeledContent("科目", value: TimetableDisplayText.continuous(names.detailSubject))
                LabeledContent("教員", value: names.detailTeacher.isEmpty ? "記載なし" : TimetableDisplayText.continuous(names.detailTeacher))
                LabeledContent("教室", value: names.detailRoom.isEmpty ? "記載なし" : TimetableDisplayText.continuous(names.detailRoom))
            }
        }
        .navigationTitle("授業詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func normalTime(from start: Int, to end: Int) -> String {
        let first = TimetableSchedule.normalPeriodTimes[start - 1]
        let last = TimetableSchedule.normalPeriodTimes[end - 1]
        return "\(first.components(separatedBy: "〜").first ?? first)〜\(last.components(separatedBy: "〜").last ?? last)"
    }

    private func specialDetail(_ selection: SpecialSelection) -> some View {
        let item = selection.item
        let lesson = item.lesson
        return List {
            Section(item.kind.title) {
                LabeledContent("日付", value: lesson.date)
                LabeledContent("クラス", value: TimetableDisplayText.className(lesson.className))
                LabeledContent("時限", value: selection.startPeriod == selection.endPeriod
                               ? "\(selection.startPeriod)限" : "\(selection.startPeriod)〜\(selection.endPeriod)限")
                if let time = selection.timeRange { LabeledContent("時刻", value: time) }
                LabeledContent("科目", value: TimetableDisplayText.continuous(lesson.subject))
                LabeledContent("教員", value: lesson.teacher.isEmpty ? "記載なし" : TimetableDisplayText.continuous(lesson.teacher))
                LabeledContent("教室", value: lesson.room.isEmpty ? "記載なし" : TimetableDisplayText.continuous(lesson.room))
                DisclosureGroup("元のセルの記載") {
                    Text(TimetableDisplayText.kana(lesson.lines.joined(separator: "\n"))).textSelection(.enabled)
                }
            }
        }
        .navigationTitle("授業詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func changeDetail(_ selection: ChangeSelection) -> some View {
        let change = selection.change
        let names = mappings.names(for: change)
        let specialTimes = Set(selection.baseSpecialLessons.compactMap(\.timeRange))
        return List {
            Section("変更内容") {
                LabeledContent("日付", value: change.change_date)
                LabeledContent("クラス", value: TimetableDisplayText.className(change.displayClassName))
                LabeledContent("時限", value: change.displayPeriod)
                if let periods = change.gridPeriods, let first = periods.first, let last = periods.last,
                   !selection.baseLessons.isEmpty {
                    LabeledContent("時刻", value: normalTime(from: first, to: last))
                } else if specialTimes.count == 1, let time = specialTimes.first {
                    LabeledContent("時刻", value: time)
                }
                LabeledContent("変更前", value: TimetableDisplayText.kana(
                    change.before_subject.isEmpty ? beforeSubject(selection) : names.before.detailSubject))
                if change.before_subject.isEmpty && !selection.baseLessons.isEmpty {
                    Text("変更前は通常時間割から表示しています。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !names.before.detailTeacher.isEmpty {
                    LabeledContent("変更前の教員", value: TimetableDisplayText.kana(names.before.detailTeacher))
                }
                if !names.before.detailRoom.isEmpty {
                    LabeledContent("変更前の教室", value: TimetableDisplayText.kana(names.before.detailRoom))
                }
                LabeledContent("変更後", value: names.after.detailSubject.isEmpty ? "記載なし" : TimetableDisplayText.kana(names.after.detailSubject))
                LabeledContent("変更後の教員", value: names.after.detailTeacher.isEmpty ? "記載なし" : TimetableDisplayText.kana(names.after.detailTeacher))
                LabeledContent("変更後の教室", value: names.after.detailRoom.isEmpty ? "記載なし" : TimetableDisplayText.kana(names.after.detailRoom))
                if !change.note.isEmpty { LabeledContent("備考", value: TimetableDisplayText.kana(change.note)) }
                DisclosureGroup("元の記載") {
                    if !change.before_subject.isEmpty { LabeledContent("変更前", value: change.before_subject) }
                    if !change.after_subject.isEmpty { LabeledContent("変更後", value: change.after_subject) }
                    if !change.raw_text.isEmpty { Text(change.raw_text).textSelection(.enabled) }
                }
            }
            if !selection.baseLessons.isEmpty {
                Section("通常の時間割") {
                    ForEach(Array(selection.baseLessons.enumerated()), id: \.offset) { _, lesson in
                        let names = mappings.names(for: lesson)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(TimetableDisplayText.kana(names.detailSubject)).font(.headline)
                            if !names.detailTeacher.isEmpty { Text("教員：" + TimetableDisplayText.kana(names.detailTeacher)) }
                            if !names.detailRoom.isEmpty { Text("教室：" + TimetableDisplayText.kana(names.detailRoom)) }
                        }
                    }
                }
            }
            if !selection.baseSpecialLessons.isEmpty {
                Section("変更前の試験時間割・試験返却時間割") {
                    ForEach(Array(selection.baseSpecialLessons.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(TimetableDisplayText.kana(item.lesson.subject)).font(.headline)
                            Text(item.kind.title).font(.caption).foregroundStyle(.secondary)
                            if let time = item.timeRange { Text("時刻：" + time) }
                            if !item.lesson.teacher.isEmpty { Text("教員：" + TimetableDisplayText.kana(item.lesson.teacher)) }
                            if !item.lesson.room.isEmpty { Text("教室：" + TimetableDisplayText.kana(item.lesson.room)) }
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
    let startPeriod: Int
    let endPeriod: Int
}

private struct ChangeSelection: Identifiable {
    let id = UUID()
    let change: ScheduleChange
    let baseLessons: [PDFLesson]
    let baseSpecialLessons: [TimetableSchedule.SpecialItem]
}

private struct SpecialSelection: Identifiable {
    let id = UUID()
    let item: TimetableSchedule.SpecialItem
    let startPeriod: Int
    let endPeriod: Int
    let timeRange: String?
}

private struct ContentUnavailableViewPlaceholder: View {
    var body: some View {
        Label("時間割の解析結果がありません。設定の「ファイル選択」でファイルを選んで解析してください。", systemImage: "calendar.badge.exclamationmark")
            .foregroundStyle(.secondary)
    }
}

private struct TimetablePrimaryClassSelection: View {
    let classes: [String]
    @Binding var value: String

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
        }
        .navigationTitle("クラスを選ぶ")
    }
}

private struct TimetableChangeClassSelection: View {
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
