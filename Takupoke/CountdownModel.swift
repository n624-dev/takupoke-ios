import Foundation
import SwiftUI
import CryptoKit
import UserNotifications

@MainActor
final class CountdownModel: ObservableObject {
    enum StorageState { case unloaded, ready, unavailable, corrupt }

    struct PublicEvent: Identifiable, Equatable {
        let reference: CountdownEventReference
        let dates: CountdownDates
        let tag: String
        var id: String { reference.key }
    }

    @Published private(set) var library = CountdownLibrary()
    @Published private(set) var cards: [CountdownCard] = []
    @Published private(set) var day = SchoolDate.today()
    @Published private(set) var message: String?
    @Published private(set) var storageState = StorageState.unloaded
    @Published private(set) var storageActionInProgress = false
    @Published private(set) var notificationStatuses: [CountdownNoticeTarget: String] = [:]
    @Published private(set) var publicEvents: [PublicEvent] = []
    @Published private(set) var automaticSchoolExams: [PublicEvent] = []
    @Published private var notificationCards: [CountdownNoticeTarget: CountdownCard] = [:]
    private var store: CountdownStore?
    private let center = UNUserNotificationCenter.current()
    private var request: NoticePlan?
    private var worker: NotificationWork?
    private var revision = UUID()
    private lazy var initialClassScope = classSelection().scope
    var onChange: (() -> Void)?

    private struct NoticePlan {
        let revision: UUID
        let desired: [CountdownNotice]
        let cards: [CountdownNoticeTarget: CountdownCard]
        let loadingClassScope: String?
        let activeReminderKeys: Set<String>
        let acceptsLegacyClassNotice: Bool
    }

    private struct ClassSelection {
        let classes: [String]
        let international: Bool

        var scope: String? {
            guard !classes.isEmpty else { return nil }
            let identity = ([String(international)] + classes.sorted()).joined(separator: "\u{0}")
            return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        }
    }

    var isConfigured: Bool { !library.registrations.isEmpty || library.automatic.enabled }
    var homeCards: [CountdownCard] { CountdownCard.home(cards, today: day) }

    func notificationCard(for target: CountdownNoticeTarget) -> CountdownCard? { notificationCards[target] }

    func load(reportFailure: Bool = false) {
        guard store == nil, !storageActionInProgress else { return }
        do {
            let store = try openStore()
            library = try store.load()
            self.store = store
            storageState = .ready
            message = nil
        } catch {
            let state: StorageState
            if case CountdownStore.ReadError.corrupt = error { state = .corrupt }
            else { state = .unavailable }
            let changed = storageState != state
            if changed { storageState = state }
            if changed || reportFailure {
                message = "保存したカウントダウンを読み込めません。端末内の登録は保持しています。"
            }
        }
    }

    func retryStorageLoad() {
        load(reportFailure:true)
        if storageState == .ready { onChange?() }
    }

    func recoverCorruptStorage() async {
        guard storageState == .corrupt, !storageActionInProgress else { return }
        storageActionInProgress = true
        do {
            let store = try openStore()
            try store.preserveCorruptFileAndReset()
            let removed = await removeUnavailableStorageNotices()
            self.store = store
            library = CountdownLibrary()
            storageState = .ready
            message = removed ? "元のファイルを保全して、カウントダウンを初期化しました。"
                : "元のファイルを保全して初期化しました。以前の予約済み通知は確認できていません。"
            storageActionInProgress = false
            onChange?()
        } catch CountdownStore.ReadError.noLongerCorrupt {
            storageActionInProgress = false
            retryStorageLoad()
        } catch {
            storageActionInProgress = false
            load()
            if storageState == .ready { onChange?() }
            else { message = "初期化できませんでした。元のファイルを保持しています。" }
        }
    }

    func stopNoticesWhileStorageIsUnavailable() async {
        guard storageState == .unavailable || storageState == .corrupt, !storageActionInProgress else { return }
        storageActionInProgress = true
        let removed = await removeUnavailableStorageNotices()
        storageActionInProgress = false
        message = removed ? "予約済みのカウントダウン通知を取り消しました。元のファイルは保持しています。"
            : "予約済みのカウントダウン通知を確認できません。もう一度お試しください。"
    }

    private func removeUnavailableStorageNotices() async -> Bool {
        // Reconciliation only runs after load succeeds. Never race a previously
        // issued notification add if the storage lifecycle changes later.
        guard store == nil, worker == nil else { return false }
        revision = UUID()
        request = nil
        guard let pending = await ScheduleNotifications.pendingStorageRecoveryIdentifiers(from:center) else { return false }
        let owned = pending.filter { $0.hasPrefix(CountdownNotice.prefix) }
        if !owned.isEmpty { center.removePendingNotificationRequests(withIdentifiers:owned) }
        return true
    }

    private func openStore() throws -> CountdownStore {
        let root = try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,
                                               appropriateFor:nil,create:true)
        return CountdownStore(root:root)
    }

    @discardableResult
    func save(_ registration: CountdownRegistration) -> Bool {
        var next = library
        if let index = next.registrations.firstIndex(where: { $0.id == registration.id }) {
            next.registrations[index] = registration
        } else { next.registrations.append(registration) }
        return commit(next)
    }

    @discardableResult
    func save(_ automatic: CountdownAutomatic) -> Bool {
        var next = library; next.automatic = automatic
        return commit(next)
    }

    func delete(_ id: UUID) {
        var next = library; next.registrations.removeAll { $0.id == id }
        commit(next)
    }

    @discardableResult
    private func commit(_ next: CountdownLibrary, notify: Bool = true) -> Bool {
        guard let store else { return false }
        do {
            try store.save(next)
            library = next
            message = nil
            if notify { onChange?() }
            return true
        } catch {
            message = "カウントダウンを保存できません。前の設定を保持しています。"
            return false
        }
    }

    func update(using app: ApplicationData, at now: Date) {
        load()
        guard store != nil else { return }
        let today = TimetableDaySchedule.schoolDay(at: now)
        if today != day { day = today }
        let events = app.schoolEvents
        let nextEvents = events.saved.keys.sorted().flatMap { year in
            (events.saved[year]?.payload.identifiedEvents ?? []).compactMap { event in
                CountdownDates(event).map { PublicEvent(reference: .init(year: year, eventID: event.eventId), dates: $0, tag: event.tag) }
            }
        }.sorted { ($0.dates.start, $0.dates.end, $0.id) < ($1.dates.start, $1.dates.end, $1.id) }
        if publicEvents != nextEvents { publicEvents = nextEvents }
        let indexed = Dictionary(uniqueKeysWithValues: nextEvents.map { ($0.reference, $0) })
        var updated = library
        for index in updated.registrations.indices {
            guard case .school(let reference, let old, let alias) = updated.registrations[index].target,
                  let item = indexed[reference], item.dates != old else { continue }
            updated.registrations[index].target = .school(reference, lastSaved: item.dates, alias: alias)
        }
        if updated != library { commit(updated, notify: false) }
        let fixed = library.registrations.map { registration -> CountdownCard in
            switch registration.target {
            case .personal(let dates):
                return .init(id: registration.id, title: dates.title, dates: dates,
                             preferences: registration.preferences, availability: .available)
            case .school(let reference, let saved, let alias):
                let availability: CountdownAvailability
                if indexed[reference] == nil {
                    availability = events.saved[reference.year]?.payload.identifiedEvents == nil ? .missingYear : .missingEvent
                } else if indexed[reference]?.dates != saved {
                    availability = .sourcePending
                } else { availability = events.countdownSourceState(year: reference.year, at: now) }
                return .init(id: registration.id, title: alias ?? saved.title, dates: saved,
                             preferences: registration.preferences, availability: availability, reference: reference)
            }
        }
        var schoolExams: [PublicEvent] = []
        var automaticCards = CountdownAutomaticCards([])
        let selection = classSelection()
        let initialScope = initialClassScope
        var loadingClassScope: String?
        if library.automatic.enabled {
            let automatic = library.automatic
            switch automatic.mode {
            case .school:
                let candidates = nextEvents.filter { $0.tag == "テスト" && $0.dates.end >= today }.sorted {
                    let lhs = $0.dates.phase(on: today).active, rhs = $1.dates.phase(on: today).active
                    return lhs == rhs ? ($0.dates.start, $0.dates.end, $0.id) < ($1.dates.start, $1.dates.end, $1.id) : lhs
                }
                schoolExams = candidates
                if candidates.isEmpty {
                    let availability: CountdownAvailability = events.saved[today.schoolYear]?.payload.identifiedEvents == nil
                        ? .missingYear : .noExam
                    automaticCards = CountdownAutomaticCards([placeholder(automatic, availability)])
                } else {
                    let targets = candidates.map { event in
                        CountdownCard(id: automatic.id, title: event.dates.title, dates: event.dates,
                            preferences: automatic.preferences, availability: events.countdownSourceState(year: event.reference.year, at: now),
                            reference: event.reference)
                    }
                    automaticCards = CountdownAutomaticCards(targets, fixedReferences: Set(fixed.compactMap(\.reference)))
                }
            case .selectedClass:
                automaticCards = CountdownAutomaticCards(selectedClassCards(automatic, selection: selection,
                    using: app, today: today, now: now))
                if automatic.preferences.notifications, automaticCards.displayed?.availability == .loading {
                    loadingClassScope = selection.scope
                }
            }
        }
        if schoolExams != automaticSchoolExams { automaticSchoolExams = schoolExams }
        var resolved = fixed
        if let displayed = automaticCards.displayed { resolved.append(displayed) }
        let sorted = CountdownCard.sorted(resolved, today: today)
        if cards != sorted { cards = sorted }
        planNotifications(for: fixed + automaticCards.notificationTargets, at: now,
                          loadingClassScope: loadingClassScope,
                          acceptsLegacyClassNotice: loadingClassScope == initialScope)
    }

    private func placeholder(_ automatic: CountdownAutomatic, _ availability: CountdownAvailability) -> CountdownCard {
        CountdownCard(id: automatic.id, title: automatic.mode.label, dates: nil,
                      preferences: automatic.preferences, availability: availability)
    }

    private func classSelection() -> ClassSelection {
        let defaults = UserDefaults.standard
        let classes = TimetableView.decode(defaults.string(forKey: "timetableSelectedClasses") ?? "")
            .filter(TimetableSchedule.selectableClasses.contains)
        return ClassSelection(classes: classes, international: defaults.bool(forKey: "timetableInternationalStudent"))
    }

    private func selectedClassCards(_ automatic: CountdownAutomatic, selection: ClassSelection, using app: ApplicationData,
                                    today: SchoolDate, now: Date) -> [CountdownCard] {
        guard let classScope = selection.scope else { return [placeholder(automatic, .noClass)] }
        let classes = selection.classes
        guard app.ready, let period = app.loadedPeriod, period == SchoolDataPeriod(day: today),
              let expiry = period.endsAt, now < expiry else { return [placeholder(automatic, .expired)] }
        let materials = app.materials
        let changeIssue = CountdownAvailability.classExamChangeIssue(in: materials.state, ready: materials.ready,
            failed: materials.failed, schoolYear: materials.automaticChangeSchoolYear)
        if let changeIssue, !changeIssue.presentsDatesOnHome {
            return [placeholder(automatic, changeIssue)]
        }
        let specials = app.specialSchedules
        guard specials.ready else { return [placeholder(automatic, specials.failed ? .analysisFailed : .loading)] }
        let source = specials.sources[.exam]
        guard let record = specials.records[.exam] else {
            return [placeholder(automatic, source == nil ? .noDocument :
                source?.failure != nil || specials.rejectedRecoveryKinds.contains(.exam) ? .analysisFailed : .notAnalysed)]
        }
        guard SchoolDataPeriod.current(at: record.acquiredAt) == period else { return [placeholder(automatic, .expired)] }
        guard record.digest == record.analysis.sourceDigest, record.analysis.version == SpecialScheduleAnalysis.parserVersion,
              !specials.rejectedRecoveryKinds.contains(.exam) else { return [placeholder(automatic, .analysisFailed)] }
        let examAvailability: CountdownAvailability = specials.availability.state(for: .exam) == .current ? .available : .previousResult
        let availability = changeIssue ?? examAvailability
        let schedule = TimetableDaySchedule(timetable: materials.state.pdfAnalyses?[MaterialKind.timetable.rawValue],
            changes: materials.state.changeAnalysis, events: app.schoolEvents.analysis,
            specials: specials.scheduleAnalyses, includesChanges: true, customTimes: app.times.current?.data,
            sourceIndex: app.scheduleSourceIndex(materials: app.materials, specials: specials, events: app.schoolEvents))
        let international = selection.international
        let candidates = Set(record.analysis.coveredDates.compactMap(SchoolDate.init(iso8601:))).sorted()
        var results: [CountdownCard] = []
        for candidate in candidates where candidate >= today {
            guard let date = candidate.dateInJapan(), date < expiry else { continue }
            let subjects = schedule.examSubjects(on: candidate, classes: classes, international: international) { subject, name, year in
                app.mappings.current?.rules.isInternationalStudentChangeField(subject, className: name, schoolYear: year) == true
            }
            guard !subjects.isEmpty else { continue }
            let evidence = ([candidate.iso8601, record.digest, app.materials.state.changeAnalysis?.sourceDigest ?? "",
                app.mappings.current?.revision ?? "", String(international)] + classes + subjects).joined(separator: "\u{0}")
            let key = SHA256.hash(data: Data(evidence.utf8)).map { String(format: "%02x", $0) }.joined()
            results.append(CountdownCard(id: automatic.id, title: automatic.mode.label,
                dates: .init(title: automatic.mode.label, ranges: [.init(start: candidate, end: candidate)]),
                preferences: automatic.preferences, availability: availability, expiry: expiry,
                classSubjects: subjects, evidence: key, classScope: classScope))
        }
        return results.isEmpty ? [placeholder(automatic, changeIssue ?? .noExam)] : results
    }

    func notificationPermission() async {
        // This runs after explicitly enabling notifications in an editor. The
        // system remembers its prior answer and presents only the first request.
        do { _ = try await ScheduleNotifications.requestAuthorization(from: center) }
        catch { message = "通知の許可を確認できません。端末の通知設定を確認してください。" }
    }

    func expirePrivateNotices(removeDelivered: Bool) async -> Bool {
        cards.removeAll { $0.isPrivate }
        notificationCards = notificationCards.filter { !$0.value.isPrivate }
        // Cold launch can reach retention before the public/personal cards are
        // loaded. Cancel an old plan without reconciling against that empty list.
        revision = UUID()
        request = nil
        guard await worker?.stop() != false, !Task.isCancelled else { return false }
        let queued = await ScheduleNotifications.readPending(from:center)
        if let queued, !Task.isCancelled {
            let pending = queued.map(\.identifier).filter { $0.hasPrefix(CountdownNotice.privatePrefix) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
        }
        if removeDelivered {
            guard let listed = await ScheduleNotifications.readDelivered(from:center), !Task.isCancelled else { return false }
            let delivered = listed.map(\.request.identifier).filter { $0.hasPrefix(CountdownNotice.privatePrefix) }
            center.removeDeliveredNotifications(withIdentifiers: delivered)
        }
        return queued != nil && !Task.isCancelled
    }

    private func planNotifications(for cards: [CountdownCard], at now: Date,
                                   loadingClassScope: String?, acceptsLegacyClassNotice: Bool) {
        let indexed = Dictionary(uniqueKeysWithValues: cards.map { ($0.noticeTarget, $0) })
        if notificationCards != indexed { notificationCards = indexed }
        let token = UUID(); revision = token
        request = .init(revision: token, desired: CountdownNotice.planned(for: cards, at: now),
                        cards: indexed, loadingClassScope: loadingClassScope,
                        activeReminderKeys: Set(library.automatic.preferences.reminders.map(\.key)),
                        acceptsLegacyClassNotice: acceptsLegacyClassNotice)
        startNotificationWorker()
    }

    func waitForNotificationReconciliation() async {
        let token = revision
        while let worker {
            await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                Task { @MainActor [weak self] in self?.cancelNotificationReconciliation(token) }
            }
            if Task.isCancelled { return }
        }
    }

    private func cancelNotificationReconciliation(_ token: UUID) {
        guard revision == token else { return }
        revision = UUID()
        request = nil
        worker?.cancel()
    }

    private func startNotificationWorker() {
        guard worker == nil else { return }
        worker = NotificationWork { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, let plan = self.request {
                self.request = nil
                await self.reconcile(plan)
            }
            self.worker = nil
            if self.request != nil { self.startNotificationWorker() }
        }
    }

    private func reconcile(_ plan: NoticePlan) async {
        let allowed: Bool
        if plan.cards.values.contains(where: { $0.preferences.notifications }) {
            let settings = await ScheduleNotifications.notificationSettings(from: center)
            guard let settings else { return reportUnconfirmedNotices(plan) }
            allowed = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        } else { allowed = false }
        guard let pending = await ScheduleNotifications.readPending(from:center),
              let delivered = await ScheduleNotifications.readDelivered(from:center) else { return reportUnconfirmedNotices(plan) }
        guard !Task.isCancelled, revision == plan.revision else { return }
        let desired = allowed ? Dictionary(uniqueKeysWithValues: plan.desired.map { ($0.identifier, $0) }) : [:]
        func holdsWhileLoading(_ existing: UNNotificationRequest) -> Bool {
            guard allowed, let scope = plan.loadingClassScope else { return false }
            return CountdownNotice.holdsWhileLoading(identifier: existing.identifier,
                storedScope: existing.content.userInfo["classScope"] as? String,
                currentScope: scope, activeReminderKeys: plan.activeReminderKeys,
                acceptsLegacy: plan.acceptsLegacyClassNotice)
        }
        let owned = pending.filter { $0.identifier.hasPrefix(CountdownNotice.prefix) }
        let obsolete = owned.filter { existing in
            if holdsWhileLoading(existing) { return false }
            guard let proposed = desired[existing.identifier] else { return true }
            return !matches(existing, proposed)
        }
        center.removePendingNotificationRequests(withIdentifiers: obsolete.map(\.identifier))
        let outdated = delivered.map(\.request).filter { existing in
            guard existing.identifier.hasPrefix(CountdownNotice.prefix) else { return false }
            if holdsWhileLoading(existing) { return false }
            guard let uuid = existing.content.userInfo["countdownID"] as? String, let id = UUID(uuidString: uuid),
                  let key = existing.content.userInfo["targetKey"] as? String,
                  let card = plan.cards[.init(id: id, key: key)], let start = card.dates?.start else { return true }
            return !allowed || !card.preferences.notifications || !card.availability.allowsNotification ||
                existing.content.title != card.title ||
                !card.preferences.reminders.contains { reminder in
                    existing.identifier.hasSuffix("." + reminder.key) &&
                        existing.content.userInfo["fireAt"] as? Double == reminder.fireDate(start: start)?.timeIntervalSince1970
                }
        }
        center.removeDeliveredNotifications(withIdentifiers: outdated.map(\.identifier))
        for notice in plan.desired where allowed {
            guard !Task.isCancelled, revision == plan.revision else { return }
            if owned.contains(where: { $0.identifier == notice.identifier && matches($0, notice) }) { continue }
            guard notice.fireAt > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = notice.title; content.body = "カウントダウンを確認してください。"; content.sound = .default
            content.userInfo = ["countdownID": notice.targetID.uuidString, "targetKey": notice.targetKey,
                                "fireAt": notice.fireAt.timeIntervalSince1970]
            if let scope = notice.classScope { content.userInfo["classScope"] = scope }
            let fields = SchoolDate.japanCalendar.dateComponents([.calendar, .timeZone, .year, .month, .day, .hour, .minute], from: notice.fireAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: fields, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: notice.identifier, content: content, trigger: trigger))
            if Task.isCancelled {
                center.removePendingNotificationRequests(withIdentifiers: [notice.identifier])
                return
            }
        }
        guard let current = await ScheduleNotifications.readPending(from:center) else { return reportUnconfirmedNotices(plan) }
        guard !Task.isCancelled, revision == plan.revision else { return }
        let desiredByTarget = Dictionary(grouping: plan.desired, by: \.target)
        var statuses: [CountdownNoticeTarget: String] = [:]
        for (target, card) in plan.cards where card.preferences.notifications {
            let expected = desiredByTarget[target] ?? []
            if card.availability == .loading && plan.loadingClassScope != nil {
                statuses[target] = "資料の読み込み後に予約を確認します。"
            }
            else if !card.availability.allowsNotification { statuses[target] = "通知は保留中です。" }
            else if !allowed { statuses[target] = "端末で通知が許可されていません。" }
            else if expected.isEmpty { statuses[target] = "これからの通知日時はありません。" }
            else {
                let count = expected.filter { notice in current.contains { matches($0, notice) } }.count
                statuses[target] = count == expected.count ? "\(count)件予約済み" : "\(count)件予約済み・\(expected.count - count)件を予約できません。"
            }
        }
        if notificationStatuses != statuses { notificationStatuses = statuses }
    }

    private func reportUnconfirmedNotices(_ plan: NoticePlan) {
        guard !Task.isCancelled, revision == plan.revision else { return }
        let statuses = plan.cards.filter { $0.value.preferences.notifications }
            .mapValues { _ in "通知の予約状況を確認できません。" }
        if notificationStatuses != statuses { notificationStatuses = statuses }
    }

    private func matches(_ request: UNNotificationRequest, _ notice: CountdownNotice) -> Bool {
        request.identifier == notice.identifier && request.content.title == notice.title &&
            request.content.userInfo["targetKey"] as? String == notice.targetKey &&
            request.content.userInfo["fireAt"] as? Double == notice.fireAt.timeIntervalSince1970
    }
}
