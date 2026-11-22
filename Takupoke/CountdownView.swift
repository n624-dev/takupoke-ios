import SwiftUI
import UIKit

struct CountdownHomeSection: View {
    @EnvironmentObject private var model: CountdownModel
    @ObservedObject var events: SchoolEventsModel

    var body: some View {
        if model.isConfigured {
            Section("カウントダウン") {
                ForEach(model.homeCards) { card in
                    NavigationLink {
                        CountdownDetail(id: card.id, events: events)
                    } label: {
                        CountdownRow(card: card, day: model.day)
                    }
                    .accessibilityIdentifier("countdown-home-card")
                }
                if model.homeCards.isEmpty, let status = model.cards.first(where: { $0.availability.label != nil })?.availability.label {
                    Text(status).foregroundStyle(.secondary)
                }
                NavigationLink("すべて見る") { CountdownManagementView(events: events) }
                    .accessibilityIdentifier("countdown-all")
            }
        }
    }
}

struct CountdownManagementView: View {
    private enum AddTarget: String, Identifiable { case school, manual; var id: String { rawValue } }
    @EnvironmentObject private var model: CountdownModel
    @ObservedObject var events: SchoolEventsModel
    @State private var adding: AddTarget?
    @State private var confirmingReset = false
    @State private var confirmingStopNotices = false
    private var active: [CountdownCard] { model.cards.filter { !$0.isFinished(on: model.day) } }
    private var finished: [CountdownCard] { model.cards.filter { $0.isFinished(on: model.day) } }

    var body: some View {
        List {
            if let message = model.message { InlineWarning(message) }
            if model.storageState == .ready {
                Section {
                    NavigationLink {
                        CountdownAutomaticEditor(automatic: model.library.automatic)
                    } label: {
                        LabeledContent("試験の自動表示",
                            value: model.library.automatic.enabled ? model.library.automatic.mode.label : "オフ")
                    }
                    .accessibilityIdentifier("countdown-automatic")
                    if model.library.automatic.enabled, model.cards.allSatisfy({ $0.id != CountdownAutomatic.identity }) {
                        Text("自動で選んだ試験は、同じ行事の固定登録にまとめています。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !active.isEmpty {
                    Section("予定") { rows(active) }
                }
                if !finished.isEmpty {
                    Section("終了済み") { rows(finished) }
                }
                if !model.isConfigured {
                    Section {
                        Text("学校行事を選ぶか、日付を入力して予定を追加できます。")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if model.storageState != .unloaded {
                Section {
                    if model.storageActionInProgress { ProgressView() }
                    Button("読み込みを再試行", systemImage:"arrow.clockwise") { model.retryStorageLoad() }
                    Button("予約済み通知を取り消す", systemImage:"bell.slash") {
                        confirmingStopNotices = true
                    }
                    if model.storageState == .corrupt {
                        Button("元のファイルを保全して初期化", role:.destructive) {
                            confirmingReset = true
                        }
                    }
                }
                .disabled(model.storageActionInProgress)
            }
        }
        .navigationTitle("カウントダウン")
        .task { model.load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("学校行事を選ぶ") { adding = .school }
                    Button("自分で入力") { adding = .manual }
                } label: {
                    Label("予定を追加", systemImage: "plus")
                }
                .accessibilityIdentifier("countdown-add")
                .disabled(model.storageState != .ready)
            }
        }
        .navigationDestination(item: $adding) { mode in
            switch mode {
            case .school: CountdownEventPicker(events: events)
            case .manual: CountdownEditor()
            }
        }
        .confirmationDialog("予約済み通知を取り消しますか？", isPresented:$confirmingStopNotices, titleVisibility:.visible) {
            Button("通知を取り消す", role:.destructive) { Task { await model.stopNoticesWhileStorageIsUnavailable() } }
            Button("キャンセル", role:.cancel) {}
        } message: {
            Text("カウントダウンの予約済み通知を取り消します。元のファイルは保持します。")
        }
        .alert("カウントダウンを初期化しますか？", isPresented:$confirmingReset) {
            Button("初期化", role:.destructive) { Task { await model.recoverCorruptStorage() } }
            Button("キャンセル", role:.cancel) {}
        } message: {
            Text("元のファイルを端末内に保全し、空の一覧から再開します。予約済みのカウントダウン通知を確認し、確認できた予約を取り消します。")
        }
    }

    private func rows(_ cards: [CountdownCard]) -> some View {
        ForEach(cards) { card in
            NavigationLink {
                CountdownDetail(id: card.id, events: events)
            } label: {
                CountdownRow(card: card, day: model.day, notice: model.notificationStatuses[card.noticeTarget])
            }
            .accessibilityIdentifier("countdown-list-card")
        }
    }
}

private struct CountdownRow: View {
    let card: CountdownCard
    let day: SchoolDate
    var notice: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.title).font(.headline)
            if let dates = card.dates {
                Text(dates.phase(on: day).label).font(.subheadline.weight(.semibold))
                Text(dates.ranges.map(\.label).joined(separator: "、"))
                    .font(.caption).foregroundStyle(.secondary)
                if case .value(let progress) = dates.progress(from: card.preferences.progressStart, on: day) {
                    ProgressView("設定期間の経過率", value: progress)
                        .font(.caption)
                }
            }
            if let status = card.availability.label { Text(status).font(.caption).foregroundStyle(.secondary) }
            if let notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
            if !card.preferences.showsOnHome { Text("ホームに表示しない").font(.caption).foregroundStyle(.secondary) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

struct CountdownNotificationDestination: View {
    @EnvironmentObject private var model: CountdownModel
    let destination: ScheduleNotifications.CountdownDestination
    @ObservedObject var events: SchoolEventsModel

    var body: some View {
        if model.notificationCard(for: destination.target) != nil {
            CountdownDetail(id: destination.target.id, events: events, notificationTarget: destination.target)
        } else {
            CountdownManagementView(events: events)
                .safeAreaInset(edge: .bottom) {
                    Text("通知の対象は変更または削除されています。現在の予定を表示しています。")
                        .font(.footnote).padding().background(.regularMaterial)
                }
        }
    }
}

private struct CountdownDetail: View {
    @EnvironmentObject private var model: CountdownModel
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @ObservedObject var events: SchoolEventsModel
    var notificationTarget: CountdownNoticeTarget? = nil
    @State private var confirmingDelete = false

    private var selectedCard: CountdownCard? {
        if let notificationTarget { return model.notificationCard(for: notificationTarget) }
        return model.cards.first { $0.id == id }
    }

    var body: some View {
        List {
            if let card = selectedCard {
                Section("予定") {
                    CountdownRow(card: card, day: model.day)
                    if let dates = card.dates {
                        LabeledContent("開始日", value: dates.start.iso8601)
                        LabeledContent("終了日", value: dates.end.iso8601)
                        if dates.ranges.count > 1 {
                            ForEach(dates.ranges.indices, id: \.self) { index in
                                LabeledContent("実施区間 \(index + 1)", value: dates.ranges[index].label)
                            }
                        }
                        if dates.progress(from: card.preferences.progressStart, on: model.day) == .invalid {
                            InlineWarning("進捗の起点日は、開始日より前に設定してください。")
                        }
                    }
                }
                Section("出典") {
                    if let reference = card.reference {
                        LabeledContent("学校行事", value: "\(reference.year)年度")
                        if let original = card.dates?.title { LabeledContent("学校公表の名称", value: original) }
                        if card.dates?.title != card.title { LabeledContent("自分用の名称", value: card.title) }
                        if let saved = events.saved[reference.year] {
                            LabeledContent("行事データの最終更新") { Text(saved.fetchedAt, format: JapaneseDateDisplay.timestamp) }
                            if let checked = saved.lastEventsCheckedAt {
                                LabeledContent("行事データの更新確認") { Text(checked, format: JapaneseDateDisplay.timestamp) }
                            }
                            if let state = events.sourcePresentation(year: reference.year) {
                                Text(state.message).font(.footnote).foregroundStyle(.secondary)
                                if let date = state.lastSuccessAt {
                                    LabeledContent("元資料の最終確認") { Text(date, format: JapaneseDateDisplay.timestamp) }
                                }
                            }
                        }
                    } else if id == CountdownAutomatic.identity {
                        Text("端末内で受理した試験時間割と適用済みの変更")
                        ForEach(card.classSubjects, id: \.self) { Text($0) }
                    } else { Text("自分で設定した予定") }
                }
                Section("表示・通知") {
                    LabeledContent("ホーム表示", value: card.preferences.showsOnHome ? "オン" : "オフ")
                    LabeledContent("表示開始", value: card.preferences.lookahead.label)
                    LabeledContent("通知設定", value: card.preferences.notifications ? "オン" : "オフ")
                    if let notice = model.notificationStatuses[card.noticeTarget] {
                        Text(notice).foregroundStyle(.secondary)
                    }
                    if card.preferences.notifications {
                        ForEach(card.preferences.reminders, id: \.self) { Text($0.label + "（日本時間）") }
                        Button("端末の通知設定を開く") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                }
                if let registration = model.library.registrations.first(where: { $0.id == id }) {
                    Section {
                        NavigationLink("編集") { CountdownEditor(registration: registration) }
                        if let reference = card.reference, let dates = card.dates {
                            NavigationLink("学校行事を選び直す") { CountdownEventPicker(events: events, replacing: registration) }
                            NavigationLink("自分で設定する予定として登録") {
                                CountdownEditor(copy: dates)
                            }
                            if events.saved[reference.year]?.payload.identifiedEvents == nil {
                                Button("学校行事を取得") { events.fetch(year: reference.year) }.disabled(events.busy)
                            }
                        }
                        Button("削除", role: .destructive) { confirmingDelete = true }
                    }
                } else if id == CountdownAutomatic.identity {
                    Section {
                        NavigationLink("自動表示を設定") { CountdownAutomaticEditor(automatic: model.library.automatic) }
                        if card.availability == .missingYear {
                            Button("学校行事を取得") { events.fetch(year: model.day.schoolYear) }.disabled(events.busy)
                        }
                    }
                    let otherExams = model.automaticSchoolExams.filter { $0.reference != card.reference }
                    if model.library.automatic.mode == .school && !otherExams.isEmpty {
                        Section("ほかの試験期間") {
                            ForEach(otherExams) { event in
                                VStack(alignment: .leading) {
                                    Text(event.dates.title)
                                    Text(event.dates.ranges.map(\.label).joined(separator: "、"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if events.failed, let message = events.message { InlineWarning(message) }
            } else {
                Text("この予定は削除または変更されました。").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("予定の詳細")
        .confirmationDialog("この予定を削除しますか？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) { model.delete(id); dismiss() }
        }
    }
}

private struct CountdownEventPicker: View {
    @EnvironmentObject private var model: CountdownModel
    @ObservedObject var events: SchoolEventsModel
    var replacing: CountdownRegistration?
    @State private var selectedYear = 0
    @State private var yearText = ""
    @State private var query = ""

    var body: some View {
        List {
            Section {
                Picker("学校年度", selection: $selectedYear) {
                    ForEach(years, id: \.self) { Text("\($0)年度").tag($0) }
                }
                TextField("別の学校年度を入力", text: $yearText).keyboardType(.numberPad)
                    .onChange(of: yearText) { value in
                        if value.utf8.count == 4, let year = Int(value), (1900...9998).contains(year) { selectedYear = year }
                    }
                if events.saved[selectedYear]?.payload.identifiedEvents == nil {
                    Text("行事ID付きの学校行事は未取得です。").foregroundStyle(.secondary)
                    Button("この年度の学校行事を取得") { events.fetch(year: selectedYear) }
                        .disabled(events.busy)
                    if events.busy { ProgressView("学校行事を取得中") }
                    if events.failed, let message = events.message { InlineWarning(message) }
                }
            }
            let listed = model.publicEvents.filter { $0.reference.year == selectedYear &&
                (query.isEmpty || $0.dates.title.localizedStandardContains(query)) }
            if events.saved[selectedYear]?.payload.identifiedEvents != nil && listed.isEmpty {
                Text(query.isEmpty ? "この年度の学校行事はありません。" : "検索に一致する行事はありません。")
            }
            ForEach(listed) { event in
                if let existing = model.library.registrations.first(where: { $0.reference == event.reference }), existing.id != replacing?.id {
                    NavigationLink { CountdownDetail(id: existing.id, events: events) } label: {
                        eventRow(event, status: "登録済み")
                    }
                } else {
                    NavigationLink { CountdownEditor(event: event, replacing: replacing) } label: { eventRow(event, status: nil) }
                }
            }
        }
        .navigationTitle("学校行事を選ぶ")
        .searchable(text: $query, prompt: "行事名を検索")
        .onAppear {
            if selectedYear == 0 { selectedYear = replacing?.reference?.year ?? model.day.schoolYear }
        }
    }

    private var years: [Int] {
        let current = model.day.schoolYear
        return Set([current - 1, current, current + 1] + events.saved.keys + [selectedYear])
            .filter { (1900...9998).contains($0) }.sorted()
    }

    private func eventRow(_ event: CountdownModel.PublicEvent, status: String?) -> some View {
        VStack(alignment: .leading) {
            Text(event.dates.title)
            Text(event.dates.ranges.map(\.label).joined(separator: "、"))
                .font(.caption).foregroundStyle(.secondary)
            if let status { Text(status).font(.caption).foregroundStyle(.secondary) }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CountdownEditor: View {
    @EnvironmentObject private var model: CountdownModel
    @Environment(\.dismiss) private var dismiss
    private let id: UUID
    private let reference: CountdownEventReference?
    private let sourceDates: CountdownDates?
    private let oldNotifications: Bool
    @State private var title: String
    @State private var start: Date
    @State private var end: Date
    @State private var hasEnd: Bool
    @State private var preferences: CountdownPreferences
    @State private var reminderDays = CountdownReminderDayEdits()

    init(registration: CountdownRegistration? = nil, copy: CountdownDates? = nil) {
        id = registration?.id ?? UUID()
        oldNotifications = registration?.preferences.notifications ?? false
        _preferences = State(initialValue: registration?.preferences ?? CountdownPreferences())
        let dates: CountdownDates?
        let name: String
        switch registration?.target {
        case .school(let reference, let saved, let alias):
            self.reference = reference; sourceDates = saved; dates = saved; name = alias ?? ""
        case .personal(let saved):
            reference = nil; sourceDates = nil; dates = saved; name = saved.title
        case nil:
            reference = nil; sourceDates = nil; dates = copy; name = copy?.title ?? ""
        }
        let initial = dates?.start.dateInJapan() ?? Date()
        _title = State(initialValue: name)
        _start = State(initialValue: initial)
        _end = State(initialValue: dates?.end.dateInJapan() ?? initial)
        _hasEnd = State(initialValue: dates.map { $0.start != $0.end } ?? false)
    }

    init(event: CountdownModel.PublicEvent, replacing: CountdownRegistration?) {
        let alias: String?
        if case .school(_, _, let originalAlias) = replacing?.target { alias = originalAlias } else { alias = nil }
        self.init(registration: .init(id: replacing?.id ?? UUID(),
            target: .school(event.reference, lastSaved: event.dates, alias: alias),
            preferences: replacing?.preferences ?? CountdownPreferences()))
    }

    private var draft: CountdownRegistration {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: CountdownRegistration.Target
        if let reference, let sourceDates { target = .school(reference, lastSaved: sourceDates, alias: name.isEmpty ? nil : name) }
        else {
            let first = TimetableDaySchedule.schoolDay(at: start)
            let last = TimetableDaySchedule.schoolDay(at: hasEnd ? end : start)
            target = .personal(.init(title: name, ranges: [.init(start: first, end: last)]))
        }
        return CountdownRegistration(id: id, target: target, preferences: preferences)
    }

    private var canSave: Bool { draft.valid && (!preferences.notifications || !reminderDays.hasInvalidInput) }

    var body: some View {
        Form {
            Section("予定") {
                if let sourceDates {
                    LabeledContent("学校公表の名称", value: sourceDates.title)
                    Text(sourceDates.ranges.map(\.label).joined(separator: "、"))
                    TextField("自分用の名称（任意）", text: $title).accessibilityIdentifier("countdown-name")
                } else {
                    TextField("予定の名前", text: $title).accessibilityIdentifier("countdown-name")
                    DatePicker("開始日", selection: $start, displayedComponents: .date)
                    Toggle("終了日を設定", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("終了日", selection: $end, displayedComponents: .date)
                        if TimetableDaySchedule.schoolDay(at: end) < TimetableDaySchedule.schoolDay(at: start) {
                            InlineWarning("終了日は開始日以降にしてください。")
                        }
                    }
                }
            }
            CountdownPreferencesFields(value: $preferences, reminderDays: $reminderDays)
            if let message = model.message { InlineWarning(message) }
        }
        .environment(\.calendar, SchoolDate.japanCalendar)
        .environment(\.timeZone, SchoolDate.japanCalendar.timeZone)
        .navigationTitle("カウントダウンを設定")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    guard canSave, model.save(draft) else { return }
                    if preferences.notifications && !oldNotifications {
                        Task { await model.notificationPermission(); model.onChange?() }
                    }
                    dismiss()
                }
                .accessibilityIdentifier("countdown-save")
                .disabled(!canSave)
            }
        }
    }
}

private struct CountdownAutomaticEditor: View {
    @EnvironmentObject private var model: CountdownModel
    @Environment(\.dismiss) private var dismiss
    @State var automatic: CountdownAutomatic
    @State private var reminderDays = CountdownReminderDayEdits()
    private let oldNotifications: Bool

    init(automatic: CountdownAutomatic) {
        _automatic = State(initialValue: automatic)
        oldNotifications = automatic.enabled && automatic.preferences.notifications
    }

    private var canSave: Bool {
        automatic.preferences.valid &&
            (!automatic.enabled || !automatic.preferences.notifications || !reminderDays.hasInvalidInput)
    }

    var body: some View {
        Form {
            Section("試験の自動表示") {
                Toggle("自動表示を有効にする", isOn: $automatic.enabled)
                if automatic.enabled {
                    Picker("試験を選ぶ方法", selection: $automatic.mode) {
                        ForEach(CountdownExamMode.allCases) { Text($0.label).tag($0) }
                    }
                }
            }
            if automatic.enabled {
                CountdownPreferencesFields(value: $automatic.preferences, reminderDays: $reminderDays)
            }
            if let message = model.message { InlineWarning(message) }
        }
        .environment(\.calendar, SchoolDate.japanCalendar)
        .environment(\.timeZone, SchoolDate.japanCalendar.timeZone)
        .navigationTitle("試験の自動表示")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    guard canSave, model.save(automatic) else { return }
                    if automatic.enabled && automatic.preferences.notifications && !oldNotifications {
                        Task { await model.notificationPermission(); model.onChange?() }
                    }
                    dismiss()
                }
                .accessibilityIdentifier("countdown-save")
                .disabled(!canSave)
            }
        }
    }
}

private struct CountdownPreferencesFields: View {
    @Binding var value: CountdownPreferences
    @Binding var reminderDays: CountdownReminderDayEdits
    @FocusState private var editingReminder: Int?
    @State private var reminderEditorGeneration = UUID()

    private var progress: Binding<Date> {
        Binding(get: { value.progressStart?.dateInJapan() ?? Date() },
                set: { value.progressStart = TimetableDaySchedule.schoolDay(at: $0) })
    }

    var body: some View {
        Section("ホーム・進捗") {
            Toggle("ホームに表示", isOn: $value.showsOnHome)
            Picker("表示開始", selection: $value.lookahead) {
                ForEach(CountdownLookahead.allCases) { Text($0.label).tag($0) }
            }
            Toggle("進捗を表示", isOn: Binding(get: { value.progressStart != nil },
                set: { value.progressStart = $0 ? .today() : nil }))
            if value.progressStart != nil { DatePicker("進捗の起点日", selection: progress, displayedComponents: .date) }
        }
        Section("通知（日本時間）") {
            Toggle("通知を予約", isOn: $value.notifications)
            if value.notifications {
                let generation = reminderEditorGeneration
                ForEach(value.reminders.indices, id: \.self) { index in
                    CountdownReminderDayField(input: reminderText(index, generation: generation),
                                              index: index, editingReminder: $editingReminder)
                    // An index can refer to another reminder after a deletion.
                    // Recreate native editors and reject callbacks from the old ones.
                    .id("\(generation.uuidString)-\(index)")
                    DatePicker("日本時間の通知時刻", selection: reminderTime(index, generation: generation), displayedComponents: .hourAndMinute)
                    if value.reminders.count > 1 {
                        Button("この通知条件を削除", role: .destructive) {
                            guard reminderEditorGeneration == generation, value.reminders.indices.contains(index) else { return }
                            editingReminder = nil
                            reminderEditorGeneration = UUID()
                            value.reminders.remove(at: index)
                            reminderDays.remove(at: index)
                        }
                        .accessibilityIdentifier("countdown-delete-reminder-\(index)")
                    }
                }
                Button("通知条件を追加") {
                    let used = Set(value.reminders.map(\.daysBefore))
                    if let days = (0...CountdownReminder.maximumDaysBefore).first(where: { !used.contains($0) }) {
                        editingReminder = nil
                        reminderEditorGeneration = UUID()
                        value.reminders.append(.init(daysBefore: days, hour: 20, minute: 0))
                    }
                }
                if reminderDays.hasInvalidInput || !value.valid {
                    InlineWarning("通知の日数・時刻を確認し、同じ条件は一つにしてください。")
                }
            }
        }
        .onChange(of: editingReminder) { previous, _ in
            if let previous { reminderDays.endEditing(at: previous) }
        }
    }

    private func reminderText(_ index: Int, generation: UUID) -> Binding<String> {
        Binding(get: {
            guard value.reminders.indices.contains(index) else { return "" }
            return reminderDays.text(at: index) ?? value.reminders[index].daysBefore.formatted()
        }, set: { text in
            guard reminderEditorGeneration == generation, value.reminders.indices.contains(index) else { return }
            // Keep the complete text and caret while the user is typing.
            if let days = reminderDays.enter(text, at: index) { value.reminders[index].daysBefore = days }
        })
    }

    private func reminderTime(_ index: Int, generation: UUID) -> Binding<Date> {
        Binding(get: {
            guard value.reminders.indices.contains(index) else { return Date() }
            let reminder = value.reminders[index]
            return SchoolDate.today().dateInJapan(hour: reminder.hour, minute: reminder.minute) ?? Date()
        }, set: {
            guard reminderEditorGeneration == generation, value.reminders.indices.contains(index) else { return }
            let time = SchoolDate.japanCalendar.dateComponents([.hour, .minute], from: $0)
            value.reminders[index].hour = time.hour ?? 20
            value.reminders[index].minute = time.minute ?? 0
        })
    }
}

private struct CountdownReminderDayField: View {
    @Environment(\.dynamicTypeSize) private var textSize
    @Binding var input: String
    let index: Int
    let editingReminder: FocusState<Int?>.Binding

    var body: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        layout {
            Text("通知する日")
                .accessibilityIdentifier("countdown-reminder-label-\(index)")
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                // Reserve room for the longest valid number when it fits.
                // On narrow rows, the native editor can scroll horizontally.
                Text(CountdownReminder.maximumDaysBefore, format: .number)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
                    .hidden()
                    .accessibilityHidden(true)
                    .overlay {
                        TextField("", text: $input)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused(editingReminder, equals: index)
                            .accessibilityLabel("予定の何日前")
                            .accessibilityIdentifier("countdown-reminder-days-\(index)")
                    }
                Text("日前")
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .layoutPriority(1)
                    .accessibilityHidden(true)
            }
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: textSize.isAccessibilitySize ? .leading : .trailing)
        }
    }
}
