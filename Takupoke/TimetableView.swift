import SwiftUI

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

    private var timetable: PDFAnalysis? { model.state.pdfAnalyses?[MaterialKind.timetable.rawValue] }
    private var events: PDFAnalysis? { schoolEvents.analysis }
    private var changes: ChangeAnalysis? { model.state.changeAnalysis }
    private var specials: [SpecialScheduleAnalysis] {
        specialSchedules.records.values.map(\.analysis).sorted { $0.kind.rawValue < $1.kind.rawValue }
    }
    private var classes: [String] { TimetableSchedule.classes(in: model.state, specials: specials) }
    private var savedClasses: [String] { Self.decode(selectedClassesValue) }
    private var selectedClasses: [String] { savedClasses.filter(classes.contains) }
    private var savedChangeClasses: [String] { Self.decode(changeClassesValue) }
    private var listClasses: [String] {
        changeClassesValue.isEmpty ? selectedClasses : savedChangeClasses.filter(classes.contains)
    }
    private var changeRange: ChangeRange { ChangeRange(rawValue: changeRangeValue) ?? .today }
    private let weekdayNames = ["月", "火", "水", "木", "金", "土", "日"]
    private let dayColumnWidth: CGFloat = 148

    var body: some View {
        NavigationStack {
            List {
                if !model.ready {
                    Section { HStack { ProgressView(); Text("保存済み資料を読み込み中…") } }
                } else if classes.isEmpty {
                    Section {
                        ContentUnavailableViewPlaceholder()
                        if !savedClasses.isEmpty {
                            LabeledContent("保存したクラス", value: TimetableDisplayText.kana(savedClasses.joined(separator: "・")))
                        }
                    }
                } else {
                    Section("表示クラス") {
                        NavigationLink {
                            TimetablePrimaryClassSelection(classes: classes, value: $selectedClassesValue)
                        } label: {
                            LabeledContent("クラス", value: savedClasses.isEmpty ? "未選択" : TimetableDisplayText.kana(savedClasses.joined(separator: "・")))
                        }
                        if savedClasses.contains(where: { !classes.contains($0) }) {
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
                NavigationStack { lessonDetail(selection.lesson, date: selection.date) }
            }
            .sheet(item: $selectedChange) { selection in
                NavigationStack { changeDetail(selection) }
            }
            .sheet(item: $selectedSpecial) { selection in
                NavigationStack { specialDetail(selection.item) }
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
                Label("左右にスクロールして週全体を表示", systemImage: "hand.draw")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                                                   specials: specials)
        return ScrollView(.horizontal) {
            Grid(alignment: .topLeading, horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    Text("時限").font(.caption.bold()).frame(width: 54)
                    ForEach(days, id: \.self) { day in
                        let plan = TimetableSchedule.dayPlan(on: day, events: events)
                        VStack(spacing: 3) {
                            HStack(spacing: 5) {
                                Text("\(day.month)/\(day.day)")
                                    .font(.subheadline.bold().monospacedDigit())
                                Text("(\(weekdayNames[day.schoolWeekday - 1]))")
                                    .font(.caption)
                                if day == today { Text("今日").font(.caption2.bold()) }
                            }
                            if plan.isSupplementary { Text("補講日").font(.caption2) }
                            if let override = plan.weekdayOverride {
                                Text("\(weekdayNames[override - 1])曜授業").font(.caption2)
                            }
                            let types = Set(specials.flatMap { analysis in
                                selectedClasses.contains { analysis.applies(date: day.iso8601, className: $0) }
                                    ? [analysis.kind.title] : []
                            })
                            if !types.isEmpty { Text(TimetableDisplayText.kana(types.sorted().joined(separator: "・"))).font(.caption2) }
                            if plan.apiTest && selectedClasses.contains(where: { className in
                                !specials.contains { $0.kind == .exam && $0.applies(date: day.iso8601, className: className) }
                            }) {
                                Text("試験時間割：未公開または未解析です").font(.caption2).foregroundStyle(.orange)
                            }
                            if plan.apiTestReturn && selectedClasses.contains(where: { className in
                                !specials.contains { $0.kind == .examReturn && $0.applies(date: day.iso8601, className: className) }
                            }) {
                                Text("試験返却時間割：未公開または未解析です").font(.caption2).foregroundStyle(.orange)
                            }
                        }
                        .frame(width: dayColumnWidth)
                        .frame(minHeight: 44)
                        .background(day == today ? Color.accentColor.opacity(0.14) : Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel("\(day.month)月\(day.day)日 \(weekdayNames[day.schoolWeekday - 1])曜日")
                    }
                }
                ForEach(1...8, id: \.self) { period in
                    let commonTime = commonPeriodTime(period, days: days)
                    GridRow {
                        VStack(spacing: 2) {
                            Text("\(period)限").font(.caption.bold())
                            if let commonTime {
                                Text(commonTime).font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 54, alignment: .top)
                        ForEach(days, id: \.self) { day in
                            timetableCell(on: day, period: period, commonTime: commonTime)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .accessibilityLabel("\(TimetableDisplayText.kana(selectedClasses.joined(separator: "・")))の週の時間割")
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
                let visible = slot.displayedLessons.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent) } ||
                    slot.displayedSpecialLessons.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent) } ||
                    slot.changes.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent) }
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

    private func timetableCell(on day: SchoolDate, period: Int, commonTime: String?) -> some View {
        let plan = TimetableSchedule.dayPlan(on: day, events: events)
        let hasItems = selectedClasses.contains { className in
            let slot = TimetableSchedule.slot(on: day, period: period, className: className,
                                              timetable: timetable, changes: changes,
                                              includesChanges: includesChanges, events: events,
                                              specials: specials)
            return slot.displayedLessons.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent) } ||
                slot.displayedSpecialLessons.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent) } ||
                slot.changes.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent) }
        }
        return VStack(alignment: .leading, spacing: 4) {
            if plan.isNoClass && !plan.apiNoClass {
                if period == 1 {
                    Text(plan.noClassLabels.isEmpty ? "授業なし" : TimetableDisplayText.kana(plan.noClassLabels.joined(separator: "・")))
                        .font(.caption.bold())
                }
            } else {
                if plan.isNoClass && period == 1 {
                    Text(plan.noClassLabels.isEmpty ? "授業なし" : TimetableDisplayText.kana(plan.noClassLabels.joined(separator: "・")))
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
                ForEach(selectedClasses, id: \.self) { className in
                    classSlot(on: day, period: period, className: className, commonTime: commonTime)
                }
                if !hasItems && !plan.isNoClass { Text("—").foregroundStyle(.tertiary) }
            }
        }
        .padding(6)
        .frame(width: dayColumnWidth, alignment: .topLeading)
        .frame(minHeight: 72, alignment: .topLeading)
        .background(plan.isNoClass ? Color.orange.opacity(0.10) : Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
    }

    private func classSlot(on day: SchoolDate, period: Int, className: String,
                           commonTime: String?) -> some View {
        let slot = TimetableSchedule.slot(on: day, period: period, className: className,
                                          timetable: timetable, changes: changes,
                                          includesChanges: includesChanges, events: events,
                                          specials: specials)
        return VStack(alignment: .leading, spacing: 4) {
            if selectedClasses.count > 1 && (!slot.displayedLessons.isEmpty || !slot.specialLessons.isEmpty || !slot.changes.isEmpty) {
                Text(TimetableDisplayText.kana(className)).font(.caption2.bold()).foregroundStyle(.secondary)
            }
            ForEach(Array(slot.displayedLessons.filter {
                TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent)
            }.enumerated()), id: \.offset) { _, lesson in
                Button {
                    selectedLesson = LessonSelection(lesson: lesson, date: day)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TimetableDisplayText.continuous(lesson.names.cellSubject)).font(.subheadline.weight(.semibold)).lineLimit(3)
                        if commonTime == nil { Text(TimetableSchedule.normalPeriodTimes[period - 1]).font(.caption2).foregroundStyle(.secondary) }
                        if !lesson.names.cellTeacher.isEmpty {
                            Text(TimetableDisplayText.continuous(lesson.names.cellTeacher)).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        }
                        if !lesson.names.cellRoom.isEmpty {
                            Text(TimetableDisplayText.continuous(lesson.names.cellRoom)).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(period)限 \(TimetableDisplayText.continuous(lesson.names.cellSubject))の詳細")
            }
            ForEach(Array(slot.displayedSpecialLessons.filter {
                TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent)
            }.enumerated()), id: \.offset) { _, item in
                Button { selectedSpecial = SpecialSelection(item: item) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TimetableDisplayText.kana(item.lesson.subject)).font(.subheadline.weight(.semibold)).lineLimit(3)
                        if commonTime == nil, let time = item.timeRange { Text(time).font(.caption2).foregroundStyle(.secondary) }
                        if !item.lesson.teacher.isEmpty { Text(TimetableDisplayText.kana(item.lesson.teacher)).font(.caption2).lineLimit(2) }
                        if !item.lesson.room.isEmpty { Text(TimetableDisplayText.kana(item.lesson.room)).font(.caption2).lineLimit(2) }
                        Text(item.kind.title).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            ForEach(Array(slot.changes.filter {
                TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent)
            }.enumerated()), id: \.offset) { _, change in
                Button { selectedChange = ChangeSelection(change: change, baseLessons: slot.baseLessons,
                                                          baseSpecialLessons: slot.specialLessons) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(change.after_subject.isEmpty ? "変更を確認" : TimetableDisplayText.kana(change.after_subject),
                              systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.semibold)).lineLimit(3)
                        if commonTime == nil,
                           let time = slotTime(slot, on: day, className: className, period: period) {
                            Text(time).font(.caption2).foregroundStyle(.secondary)
                        }
                        if !change.teacher.isEmpty { Text(TimetableDisplayText.kana(change.teacher)).font(.caption2).lineLimit(2) }
                        if !change.room.isEmpty { Text(TimetableDisplayText.kana(change.room)).font(.caption2).lineLimit(2) }
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
        }.filter { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent) }
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
                    ? (savedClasses.isEmpty ? "未選択" : TimetableDisplayText.kana(savedClasses.joined(separator: "・")))
                    : TimetableDisplayText.kana(savedChangeClasses.joined(separator: "・")))
            }
            if !changeClassesValue.isEmpty && savedChangeClasses.contains(where: { !classes.contains($0) }) {
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
                    Button {
                        let base = baseSlot(for: change)
                        selectedChange = ChangeSelection(change: change, baseLessons: base?.baseLessons ?? [],
                                                         baseSpecialLessons: base?.specialLessons ?? [])
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(change.change_date) · \(TimetableDisplayText.kana(change.displayClassName)) · \(change.period.isEmpty ? "時限未記載" : change.displayPeriod)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(TimetableDisplayText.kana(changeSummary(change))).font(.subheadline)
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

    private func changeSummary(_ change: ScheduleChange) -> String {
        let before = change.before_subject.isEmpty ? "記載なし" : change.before_subject
        let after = change.after_subject.isEmpty ? "記載なし" : change.after_subject
        return "\(before) → \(after)"
    }

    private func baseSlot(for change: ScheduleChange) -> TimetableSchedule.Slot? {
        guard let day = SchoolDate(iso8601: change.change_date), let period = Int(change.period) else { return nil }
        return TimetableSchedule.slot(on: day, period: period, className: change.displayClassName,
                                      timetable: timetable, changes: nil, includesChanges: false,
                                      events: events, specials: specials)
    }

    private var weekEvents: some View {
        let rows = (0..<7).compactMap { weekStart.addingDays($0) }.flatMap { day in
            TimetableSchedule.events(on: day, analysis: events).map { (day, $0) }
        }
        return Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, entry in
                        Text(TimetableDisplayText.kana("\(entry.0.month)/\(entry.0.day) \(entry.1.title)" +
                             (entry.1.apiTag.map { " · \($0)" } ?? "")))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func lessonDetail(_ lesson: PDFLesson, date: SchoolDate) -> some View {
        let names = mappings.names(for: lesson)
        return List {
            Section("通常の授業") {
                LabeledContent("日付", value: date.iso8601)
                LabeledContent("クラス", value: TimetableDisplayText.kana(lesson.className))
                LabeledContent("時限", value: "\(lesson.period)限")
                LabeledContent("時刻", value: TimetableSchedule.normalPeriodTimes[lesson.period - 1])
                LabeledContent("科目", value: TimetableDisplayText.continuous(names.detailSubject))
                LabeledContent("教員", value: names.detailTeacher.isEmpty ? "記載なし" : TimetableDisplayText.continuous(names.detailTeacher))
                LabeledContent("教室", value: names.detailRoom.isEmpty ? "記載なし" : TimetableDisplayText.continuous(names.detailRoom))
            }
        }
        .navigationTitle("授業詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func specialDetail(_ item: TimetableSchedule.SpecialItem) -> some View {
        let lesson = item.lesson
        return List {
            Section(item.kind.title) {
                LabeledContent("日付", value: lesson.date)
                LabeledContent("クラス", value: TimetableDisplayText.kana(lesson.className))
                LabeledContent("時限", value: lesson.spanStart == lesson.spanEnd
                               ? "\(lesson.period)限" : "\(lesson.spanStart)〜\(lesson.spanEnd)限")
                if let time = item.timeRange { LabeledContent("時刻", value: time) }
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
        let specialTimes = Set(selection.baseSpecialLessons.compactMap(\.timeRange))
        return List {
            Section("変更内容") {
                LabeledContent("日付", value: change.change_date)
                LabeledContent("クラス", value: TimetableDisplayText.kana(change.displayClassName))
                LabeledContent("時限", value: change.displayPeriod)
                if specialTimes.count == 1, let time = specialTimes.first {
                    LabeledContent("時刻", value: time)
                } else if !selection.baseLessons.isEmpty, let period = Int(change.period), (1...8).contains(period) {
                    LabeledContent("時刻", value: TimetableSchedule.normalPeriodTimes[period - 1])
                }
                LabeledContent("変更前", value: change.before_subject.isEmpty ? "記載なし" : TimetableDisplayText.kana(change.before_subject))
                LabeledContent("変更後", value: change.after_subject.isEmpty ? "記載なし" : TimetableDisplayText.kana(change.after_subject))
                LabeledContent("教員", value: change.teacher.isEmpty ? "記載なし" : TimetableDisplayText.kana(change.teacher))
                LabeledContent("教室", value: change.room.isEmpty ? "記載なし" : TimetableDisplayText.kana(change.room))
                if !change.note.isEmpty { LabeledContent("備考", value: TimetableDisplayText.kana(change.note)) }
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
                    Text("\(TimetableDisplayText.kana(primary))（保存済み・現在の資料に該当なし）").tag(primary)
                }
                ForEach(classes, id: \.self) { Text(TimetableDisplayText.kana($0)).tag($0) }
            }
            Picker("追加クラス（1年生のみ・任意）", selection: Binding(
                get: { additional },
                set: { value = $0.isEmpty ? primary : primary + "|" + $0 })) {
                Text("追加なし").tag("")
                if !additional.isEmpty && !additionalClasses.contains(additional) {
                    Text("\(TimetableDisplayText.kana(additional))（保存済み・現在の資料に該当なし）").tag(additional)
                }
                ForEach(additionalClasses, id: \.self) { Text(TimetableDisplayText.kana($0)).tag($0) }
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
                        Toggle(TimetableDisplayText.kana(className), isOn: Binding(
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
                        Toggle(TimetableDisplayText.kana(className), isOn: Binding(
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
