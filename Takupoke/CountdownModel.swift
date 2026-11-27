import Foundation
import SwiftUI
import CryptoKit
import UserNotifications

@MainActor
final class CountdownModel: ObservableObject {
    enum StorageState { case unloaded, ready, unavailable, corrupt }

    typealias PublicEvent = CountdownPublicEvent

    @Published private(set) var library = CountdownLibrary()
    @Published private(set) var cards: [CountdownCard] = []
    @Published private(set) var day = SchoolDate.today()
    @Published private(set) var message: String?
    @Published private(set) var storageState = StorageState.unloaded
    @Published private(set) var storageActionInProgress = false
    @Published private(set) var notificationStatuses: [CountdownNoticeTarget: String] = [:]
    @Published private(set) var publicEvents: [PublicEvent] = []
    @Published private(set) var automaticSchoolExams: [PublicEvent] = []
    @Published private(set) var automaticProgress: CountdownExamProgress?
    @Published private(set) var classProgressUnavailable = false
    @Published private var notificationCards: [CountdownNoticeTarget: CountdownCard]?
    private var store: CountdownStore?
    private var loadedClassProgress: (file: UUID?, value: CountdownClassProgress)?
    private var legacyProgressTarget: CountdownExamProgressKey?
    private var decidedLegacyProgressTarget = false
    private let center = UNUserNotificationCenter.current()
    private let retentionRemovals = NotificationRemovalOwner()
    private let notificationWriter = NotificationWriteOwner()
    private var retentionPreservedWrite: (write: NotificationWriteOwner.Active, invalidation: UUID)?
    private var request: NoticePlan?
    private var worker: NotificationWork?
    private var applyingPlan: NoticePlan?
    private var revision = UUID()
    private lazy var initialClassScope = classSelection().scope
    var onChange: (() -> Bool)?

    private struct NoticePlan {
        let revision: UUID
        let desired: [CountdownNotice]
        let cards: [CountdownNoticeTarget: CountdownCard]
        let loadingClassScope: String?
        let activeReminderKeys: Set<String>
        let acceptsLegacyClassNotice: Bool

        func excluding(_ owners: Set<UUID>, revision: UUID) -> NoticePlan {
            let stopsAutomatic = owners.contains(CountdownAutomatic.identity)
            return NoticePlan(revision: revision, desired: desired.filter { !owners.contains($0.targetID) },
                cards: cards.filter { !owners.contains($0.key.id) }, loadingClassScope: stopsAutomatic ? nil : loadingClassScope,
                activeReminderKeys: activeReminderKeys, acceptsLegacyClassNotice: !stopsAutomatic && acceptsLegacyClassNotice)
        }
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

    func notificationCard(for target: CountdownNoticeTarget) -> CountdownCard? { notificationCards?[target] }

    func isWaitingForNotificationTarget(_ target: CountdownNoticeTarget) -> Bool {
        if storageState == .unloaded { return true }
        guard storageState == .ready else { return false }
        guard let notificationCards else { return true }
        return notificationCards.values.contains { $0.id == target.id && $0.availability == .loading }
    }

    func load(reportFailure: Bool = false) {
        guard store == nil, !storageActionInProgress else { return }
        do {
            let store = try openStore()
            library = try store.load()
            store.discardUnusedClassProgress(keeping: library.classProgressFile)
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
        if storageState == .ready { _ = onChange?() }
    }

    func recoverCorruptStorage() async {
        guard storageState == .corrupt, !storageActionInProgress else { return }
        storageActionInProgress = true
        do {
            let store = try openStore()
            try store.preserveCorruptFileAndReset()
            store.discardUnusedClassProgress(keeping: nil)
            let removed = await removeUnavailableStorageNotices()
            self.store = store
            library = CountdownLibrary()
            storageState = .ready
            message = removed ? "元のファイルを保全して、カウントダウンを初期化しました。"
                : "元のファイルを保全して初期化しました。以前の予約済み通知は確認できていません。"
            storageActionInProgress = false
            _ = onChange?()
        } catch CountdownStore.ReadError.noLongerCorrupt {
            storageActionInProgress = false
            retryStorageLoad()
        } catch {
            storageActionInProgress = false
            load()
            if storageState == .ready { _ = onChange?() }
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
    func save(_ automatic: CountdownAutomatic, originEdit: CountdownOriginEdit? = nil) -> Bool {
        var next = library
        next.automatic = automatic
        next.automatic.customOrigins = library.automatic.customOrigins
        next.automatic.unlinkedProgressStart = library.automatic.unlinkedProgressStart
        var privateProgress: CountdownClassProgress?
        switch originEdit {
        case nil: break
        case .discardUnlinked: next.automatic.unlinkedProgressStart = nil
        case .change(let key, let date, let useUnlinked):
            let app = ApplicationData.shared
            guard let current = previewAutomatic(automatic, using: app, at: Date()).progress, current.key == key else {
                message = "対象の試験が変わりました。起点日を選び直してください。"
                return false
            }
            guard date.map({ $0.isValidCalendarDay && $0 < current.goal }) != false else {
                message = "進捗の起点日は、目標日より前に設定してください。"
                return false
            }
            if useUnlinked { next.automatic.unlinkedProgressStart = nil }
            if key.isPrivate {
                guard let period = app.loadedPeriod, let store, var scoped = classProgress(in: store, period: period) else {
                    message = "この試験の起点日の保存先を確認できません。しばらく待って再試行してください。"
                    return false
                }
                // The fallback key describes just this one day. Remove it
                // when the user explicitly edits the now-known period.
                if case .classPeriod(let scope, _) = key {
                    scoped.entries = CountdownCustomProgress.replacing(.classDay(scope: scope, day: current.goal),
                                                                        with: nil, in: scoped.entries)
                }
                scoped.entries = CountdownCustomProgress.replacing(key, with: date, in: scoped.entries)
                privateProgress = scoped
            } else {
                next.automatic.customOrigins = CountdownCustomProgress.replacing(key, with: date,
                    in: next.automatic.customOrigins ?? [])
            }
        }
        return commit(next, privateProgress: privateProgress)
    }

    func delete(_ id: UUID) -> Bool {
        var next = library; next.registrations.removeAll { $0.id == id }
        return commit(next)
    }

    @discardableResult
    private func commit(_ draft: CountdownLibrary, notify: Bool = true,
                        privateProgress: CountdownClassProgress? = nil) -> Bool {
        guard let store else { return false }
        do {
            let next: CountdownLibrary
            if let privateProgress {
                next = try store.save(draft, with: privateProgress)
                loadedClassProgress = (next.classProgressFile, privateProgress)
            } else {
                try store.save(draft)
                next = draft
            }
            let previous = library
            library = next
            message = nil
            if notify {
                removeDisabledNotices(from: previous)
                _ = onChange?()
            }
            return true
        } catch {
            message = "カウントダウンを保存できません。前の設定を保持しています。"
            return false
        }
    }

    private func removeDisabledNotices(from previous: CountdownLibrary) {
        let active = Set(library.registrations.filter { $0.preferences.notifications }.map(\.id))
        let disabled = previous.registrations.filter { $0.preferences.notifications && !active.contains($0.id) }
        var owners = Set(disabled.map(\.id))
        var identifiers = Set(disabled.flatMap { registration in
            let target = CountdownNoticeTarget(id: registration.id, key: registration.reference?.key ?? registration.id.uuidString)
            return registration.preferences.reminders.map {
                CountdownNotice.identifier(for: target, isPrivate: false, reminder: $0)
            }
        })
        let automatic = previous.automatic
        if automatic.enabled && automatic.preferences.notifications && !notificationEnabled(for: automatic.id) {
            owners.insert(automatic.id)
            let automaticCards = notificationCards?.values.filter { $0.id == automatic.id } ?? []
            for card in automaticCards {
                identifiers.formUnion(automatic.preferences.reminders.map {
                    CountdownNotice.identifier(for: card.noticeTarget, isPrivate: card.isPrivate, reminder: $0)
                })
            }
        }
        guard !owners.isEmpty else { return }
        let activePlan = applyingPlan.flatMap { $0.revision == revision ? $0 : nil }
        let nextRevision = UUID()
        revision = nextRevision
        request = (request ?? activePlan)?.excluding(owners, revision: nextRevision)
        if let applyingPlan {
            identifiers.formUnion(applyingPlan.desired.lazy.filter { owners.contains($0.targetID) }.map(\.identifier))
        }
        let statuses = notificationStatuses.filter { !owners.contains($0.key.id) }
        if notificationStatuses != statuses { notificationStatuses = statuses }
        // Known identifiers can be withdrawn immediately, even while another
        // reservation is waiting for the system's completion callback.
        removeNotices(identifiers.sorted())
    }

    private func notificationEnabled(for id: UUID) -> Bool {
        if id == library.automatic.id { return library.automatic.enabled && library.automatic.preferences.notifications }
        return library.registrations.contains { $0.id == id && $0.preferences.notifications }
    }

    private func removeNotices(_ identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func update(using app: ApplicationData, at now: Date) {
        load()
        guard let store else { return }
        let today = TimetableDaySchedule.schoolDay(at: now)
        if today != day { day = today }
        let events = app.schoolEvents
        let (nextEvents, completeYears) = publishedEvents(in: events)
        if publicEvents != nextEvents { publicEvents = nextEvents }
        let indexed = Dictionary(uniqueKeysWithValues: nextEvents.map { ($0.reference, $0) })
        var updated = library
        for index in updated.registrations.indices {
            guard case .school(let reference, let old, let alias) = updated.registrations[index].target,
                  let item = indexed[reference], item.dates != old else { continue }
            updated.registrations[index].target = .school(reference, lastSaved: item.dates, alias: alias)
        }
        if updated.version == CountdownLibrary.currentVersion, updated != library { commit(updated, notify: false) }
        let fixed = library.registrations.map { registration -> CountdownCard in
            switch registration.target {
            case .personal(let dates):
                return .init(id: registration.id, title: dates.title, dates: dates,
                             preferences: registration.preferences, availability: .available)
            case .school(let reference, let saved, let alias):
                let evidence: (availability: CountdownAvailability, freshUntil: Date?)
                if indexed[reference] == nil {
                    evidence = (events.saved[reference.year]?.payload.identifiedEvents == nil ? .missingYear : .missingEvent, nil)
                } else if indexed[reference]?.dates != saved {
                    evidence = (.sourcePending, nil)
                } else { evidence = events.countdownSourceEvidence(year: reference.year, at: now) }
                return .init(id: registration.id, title: alias ?? saved.title, dates: saved,
                             preferences: registration.preferences, availability: evidence.availability, reference: reference,
                             publicSourceFreshUntil: evidence.freshUntil)
            }
        }
        let selection = classSelection()
        let initialScope = initialClassScope
        let automatic = library.automatic
        var privateProgress: CountdownClassProgress?
        if automatic.enabled, automatic.mode == .selectedClass,
           let period = app.loadedPeriod, period == SchoolDataPeriod(day: today) {
            privateProgress = classProgress(in: store, period: period)
            loadedClassProgress = privateProgress.map { (library.classProgressFile, $0) }
        }
        let evaluated = evaluateAutomatic(automatic, selection: selection, using: app, today: today, now: now,
            events: nextEvents, completeYears: completeYears, fixedReferences: Set(fixed.compactMap(\.reference)),
            privateProgress: privateProgress)
        let automaticCards = evaluated.cards
        let schoolExams = evaluated.schoolExams
        let loadingClassScope = automatic.mode == .selectedClass && automatic.preferences.notifications &&
            automaticCards.displayed?.availability == .loading ? selection.scope : nil
        let currentExam = automaticCards.displayed
        if library.canMigrateProgress(availability: currentExam?.availability) {
            if !decidedLegacyProgressTarget {
                if let currentExam, currentExam.availability.allowsNotification {
                    legacyProgressTarget = currentExam.examProgress?.key
                }
                decidedLegacyProgressTarget = true
            }
            let currentKey = currentExam?.examProgress?.key
            let target = currentKey == legacyProgressTarget ? currentKey : nil
            do {
                library = try store.saveMigratingProgress(updated, to: target, classProgress: privateProgress)
                loadedClassProgress = nil
                legacyProgressTarget = nil
                message = nil
                update(using: app, at: now)
                return
            } catch {
                message = "カウントダウンを移行できません。前の設定を保持しています。"
            }
        }
        let nextProgress = currentExam?.examProgress
        if automaticProgress != nextProgress { automaticProgress = nextProgress }
        let classUnavailable = nextProgress?.key.isPrivate == true && privateProgress == nil
        if classProgressUnavailable != classUnavailable { classProgressUnavailable = classUnavailable }
        if schoolExams != automaticSchoolExams { automaticSchoolExams = schoolExams }
        var resolved = fixed
        if let displayed = automaticCards.displayed { resolved.append(displayed) }
        let sorted = CountdownCard.sorted(resolved, today: today)
        if cards != sorted { cards = sorted }
        planNotifications(for: fixed + automaticCards.notificationTargets, at: now,
                          loadingClassScope: loadingClassScope,
                          acceptsLegacyClassNotice: loadingClassScope == initialScope)
    }

    private func publishedEvents(in events: SchoolEventsModel) -> ([PublicEvent], Set<Int>) {
        let nextEvents = events.saved.keys.sorted().flatMap { year in
            (events.saved[year]?.payload.identifiedEvents ?? []).compactMap { event in
                CountdownDates(event).map { PublicEvent(reference: .init(year: year, eventID: event.eventId), dates: $0, tag: event.tag) }
            }
        }.sorted { ($0.dates.start, $0.dates.end, $0.id) < ($1.dates.start, $1.dates.end, $1.id) }
        let completeYears = Set(events.saved.compactMap { year, snapshot in
            snapshot.payload.identifiedEvents == nil ? nil : year
        })
        return (nextEvents, completeYears)
    }

    private func classProgress(in store: CountdownStore, period: SchoolDataPeriod) -> CountdownClassProgress? {
        if let cached = loadedClassProgress, cached.file == library.classProgressFile, cached.value.period == period {
            return cached.value
        }
        return try? store.loadClassProgress(file: library.classProgressFile, period: period)
    }

    struct AutomaticDraftPreview: Equatable {
        let progress: CountdownExamProgress?
        let availability: CountdownAvailability?
        let classProgressUnavailable: Bool
    }

    func previewAutomatic(_ draft: CountdownAutomatic, using app: ApplicationData, at now: Date) -> AutomaticDraftPreview {
        let unavailable = AutomaticDraftPreview(progress: nil, availability: nil, classProgressUnavailable: false)
        guard draft.enabled, let store else { return unavailable }
        let today = TimetableDaySchedule.schoolDay(at: now)
        let (events, completeYears) = publishedEvents(in: app.schoolEvents)
        let fixedReferences = Set(library.registrations.compactMap { item -> CountdownEventReference? in
            guard case .school(let reference, _, _) = item.target else { return nil }
            return reference
        })
        let privateProgress: CountdownClassProgress?
        if draft.mode == .selectedClass, let period = app.loadedPeriod, period == SchoolDataPeriod(day: today) {
            privateProgress = classProgress(in: store, period: period)
        } else { privateProgress = nil }
        let evaluated = evaluateAutomatic(draft, selection: classSelection(), using: app, today: today, now: now,
            events: events, completeYears: completeYears, fixedReferences: fixedReferences, privateProgress: privateProgress)
        let card = evaluated.cards.displayed
        let progress = card?.availability.allowsNotification == true ? card?.examProgress : nil
        return AutomaticDraftPreview(progress: progress, availability: card?.availability,
            classProgressUnavailable: progress?.key.isPrivate == true && privateProgress == nil)
    }

    private func evaluateAutomatic(_ automatic: CountdownAutomatic, selection: ClassSelection, using app: ApplicationData,
                                   today: SchoolDate, now: Date, events nextEvents: [PublicEvent], completeYears: Set<Int>,
                                   fixedReferences: Set<CountdownEventReference>,
                                   privateProgress: CountdownClassProgress?) -> (cards: CountdownAutomaticCards, schoolExams: [PublicEvent]) {
        guard automatic.enabled else { return (CountdownAutomaticCards([]), []) }
        let events = app.schoolEvents
        switch automatic.mode {
        case .school:
            let candidates = nextEvents.filter { $0.tag == "テスト" && $0.dates.end >= today }.sorted {
                let lhs = $0.dates.phase(on: today).active, rhs = $1.dates.phase(on: today).active
                return lhs == rhs ? ($0.dates.start, $0.dates.end, $0.id) < ($1.dates.start, $1.dates.end, $1.id) : lhs
            }
            guard !candidates.isEmpty else {
                let availability: CountdownAvailability = events.saved[today.schoolYear]?.payload.identifiedEvents == nil
                    ? .missingYear : .noExam
                return (CountdownAutomaticCards([placeholder(automatic, availability)]), [])
            }
            let targets = candidates.map { event in
                let evidence = events.countdownSourceEvidence(year: event.reference.year, at: now)
                return CountdownCard(id: automatic.id, title: event.dates.title, dates: event.dates,
                    preferences: automatic.preferences, availability: evidence.availability,
                    reference: event.reference, examProgress: resolveProgress(key: .school(event.reference),
                        examStart: event.dates.start, goal: event.dates.start, events: nextEvents,
                        completeYears: completeYears, custom: automatic.customOrigins ?? [],
                        unconfirmedYear: events.countdownAnnouncementCoverage), publicSourceFreshUntil: evidence.freshUntil)
            }
            return (CountdownAutomaticCards(targets, fixedReferences: fixedReferences), candidates)
        case .selectedClass:
            let targets = selectedClassCards(automatic, selection: selection, using: app, today: today, now: now).map { card in
                var card = card
                if let scope = card.classScope, let goal = card.dates?.start {
                    let (key, start) = CountdownExamProgressKey.forClass(scope: scope, day: goal, events: nextEvents)
                    card.examProgress = resolveProgress(key: key, examStart: start, goal: goal, events: nextEvents,
                        completeYears: completeYears, custom: privateProgress?.entries,
                        fallback: .classDay(scope: scope, day: goal), unconfirmedYear: events.countdownAnnouncementCoverage)
                }
                return card
            }
            return (CountdownAutomaticCards(targets), [])
        }
    }

    private func resolveProgress(key: CountdownExamProgressKey, examStart: SchoolDate, goal: SchoolDate,
                                 events: [PublicEvent], completeYears: Set<Int>, custom: [CountdownCustomProgress]?,
                                 fallback: CountdownExamProgressKey? = nil,
                                 unconfirmedYear: (Int) -> CountdownAnnouncementCoverage) -> CountdownExamProgress {
        let entries = custom ?? []
        let saved = entries.first { $0.key == key } ?? entries.first { $0.key == fallback }
        let origin = saved.map { CountdownProgressOrigin.custom($0.date) } ??
            CountdownProgressOrigin.announcement(before: examStart, events: events, completeYears: completeYears,
                                                 unconfirmedYear: unconfirmedYear)
        return .init(key: key, goal: goal, origin: origin)
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
        let specials = app.specialSchedules
        let materials = app.materials
        let inputIssue = CountdownAvailability.classExamInputIssue(in: materials.state, ready: materials.ready,
            failed: materials.failed, schoolYear: materials.automaticChangeSchoolYear,
            rejectedExamRecovery: specials.ready && specials.rejectedRecoveryKinds.contains(.exam))
        if let inputIssue, !inputIssue.presentsDatesOnHome {
            return [placeholder(automatic, inputIssue)]
        }
        guard specials.ready else { return [placeholder(automatic, specials.failed ? .analysisFailed : .loading)] }
        let source = specials.sources[.exam]
        guard let record = specials.records[.exam] else {
            return [placeholder(automatic, source == nil ? .noDocument : source?.failure != nil ? .analysisFailed : .notAnalysed)]
        }
        guard SchoolDataPeriod.current(at: record.acquiredAt) == period else { return [placeholder(automatic, .expired)] }
        guard record.digest == record.analysis.sourceDigest, record.analysis.version == SpecialScheduleAnalysis.parserVersion
        else { return [placeholder(automatic, .analysisFailed)] }
        let examAvailability: CountdownAvailability = specials.availability.state(for: .exam) == .current ? .available : .previousResult
        let availability = inputIssue ?? examAvailability
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
        return results.isEmpty ? [placeholder(automatic, inputIssue ?? .noExam)] : results
    }

    func notificationPermission() async {
        // This runs after explicitly enabling notifications in an editor. The
        // system remembers its prior answer and presents only the first request.
        do { _ = try await ScheduleNotifications.requestAuthorization(from: center) }
        catch { message = "通知の許可を確認できません。端末の通知設定を確認してください。" }
    }

    func expirePrivateNotices(removeDelivered: Bool) async -> Bool {
        loadedClassProgress = nil
        if legacyProgressTarget?.isPrivate == true { legacyProgressTarget = nil }
        if automaticProgress?.key.isPrivate == true { automaticProgress = nil }
        cards.removeAll { $0.isPrivate }
        notificationCards = notificationCards?.filter { !$0.value.isPrivate }
        // Invalidate the old plan without cancelling an in-flight add. It may
        // be a personal or public reminder that must survive private expiry.
        invalidatePrivateNotificationPlan()
        guard await worker?.waitForCompletion() != false, !Task.isCancelled else { return false }
        guard await retentionRemovals.waitForCompletion() else { return false }
        let queued = await ScheduleNotifications.readPending(from:center)
        if let queued, !Task.isCancelled {
            let pending = queued.map(\.identifier).filter { $0.hasPrefix(CountdownNotice.privatePrefix) }
            guard await retentionRemovals.run(.pending, identifiers: pending, { [center] in
                center.removePendingNotificationRequests(withIdentifiers: pending)
            }) else { return false }
        }
        if removeDelivered {
            guard let listed = await ScheduleNotifications.readDelivered(from:center), !Task.isCancelled else { return false }
            let delivered = listed.map(\.request.identifier).filter { $0.hasPrefix(CountdownNotice.privatePrefix) }
            guard await retentionRemovals.run(.delivered, identifiers: delivered, { [center] in
                center.removeDeliveredNotifications(withIdentifiers: delivered)
            }) else { return false }
        }
        return queued != nil && !Task.isCancelled
    }

    private func invalidatePrivateNotificationPlan() {
        let nextRevision = UUID()
        if let active = notificationWriter.active, !active.identifier.hasPrefix(CountdownNotice.privatePrefix),
           active.revision == revision || (retentionPreservedWrite?.write == active && retentionPreservedWrite?.invalidation == revision) {
            retentionPreservedWrite = (active, nextRevision)
        } else {
            retentionPreservedWrite = nil
        }
        revision = nextRevision
        request = nil
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
            let finished = await withTaskCancellationHandler {
                await worker.waitForCompletion(timeout:nil)
            } onCancel: {
                Task { @MainActor [weak self] in self?.cancelNotificationReconciliation(token) }
            }
            guard finished else { return }
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
                self.applyingPlan = plan
                await self.reconcile(plan)
                self.applyingPlan = nil
            }
            self.worker = nil
            if self.request != nil { self.startNotificationWorker() }
        }
    }

    private func reconcile(_ plan: NoticePlan) async {
        guard await retentionRemovals.waitForCompletion() else { return reportUnconfirmedNotices(plan) }
        guard revision == plan.revision else { return }
        let allowed: Bool
        if plan.cards.values.contains(where: { $0.preferences.notifications }) {
            let settings = await ScheduleNotifications.notificationSettings(from: center)
            guard let settings else { return reportUnconfirmedNotices(plan) }
            allowed = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        } else { allowed = false }
        guard !Task.isCancelled, revision == plan.revision else { return }
        let pending = await ScheduleNotifications.readPending(from:center)
        guard let pending, !Task.isCancelled, revision == plan.revision else { return reportUnconfirmedNotices(plan) }
        // Delivery history can be unavailable independently of verified reservations.
        let delivered = await ScheduleNotifications.readDelivered(from:center)
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
        let outdated = delivered?.map(\.request).filter { existing in
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
        if let outdated {
            center.removeDeliveredNotifications(withIdentifiers: outdated.map(\.identifier))
        }
        guard let current = await reserveNotifications(plan, allowed:allowed, startingWith:owned),
              !Task.isCancelled, revision == plan.revision else { return reportUnconfirmedNotices(plan) }
        let desiredByTarget = Dictionary(grouping: plan.desired, by: \.target)
        var statuses: [CountdownNoticeTarget: String] = [:]
        for (target, card) in plan.cards where card.preferences.notifications {
            let expected = desiredByTarget[target] ?? []
            if card.availability == .loading && plan.loadingClassScope != nil {
                statuses[target] = "資料の読み込み後に予約を確認します。"
            }
            else if !card.availability.allowsNotification || card.publicSourceFreshUntil.map({ Date() >= $0 }) == true {
                statuses[target] = "通知は保留中です。"
            }
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

    private func reserveNotifications(_ plan: NoticePlan, allowed: Bool,
                                      startingWith known: [UNNotificationRequest],
                                      waitBeforeRetry: ((Duration) async throws -> Void)? = nil) async -> [UNNotificationRequest]? {
        guard allowed else { return known }
        var current = known
        var remaining = plan.desired
        var displaced = [CountdownNotice]()
        var observedCapacity = 0
        let delays: [Duration] = [.zero,.seconds(1),.seconds(3)]
        // Read the actual pending list before retrying a rejected request. It
        // may have appeared after the error, and a newer plan takes precedence.
        for delay in delays {
            if delay != .zero {
                do {
                    if let waitBeforeRetry { try await waitBeforeRetry(delay) }
                    else { try await Task.sleep(for: delay) }
                } catch { return nil }
            }
            guard !Task.isCancelled, revision == plan.revision else { return nil }
            if delay != .zero {
                let latest = await ScheduleNotifications.readPending(from:center)
                guard let latest, !Task.isCancelled, revision == plan.revision else { return nil }
                current = latest
                remaining = plan.desired.filter { notice in
                    notice.canReserve(at: Date()) && !current.contains { matches($0, notice) }
                }
                if remaining.isEmpty { return current }
                if delay == .seconds(3) {
                    let now = Date()
                    let eligible = plan.desired.filter { $0.canReserve(at: now) }
                    let confirmed = Set(eligible.filter { notice in current.contains { matches($0, notice) } }.map(\.identifier))
                    let moved = CountdownNotice.displacedReservations(eligible, confirmed: confirmed)
                    if !moved.isEmpty {
                        observedCapacity = confirmed.count
                        displaced = eligible.filter { moved.contains($0.identifier) }
                        center.removePendingNotificationRequests(withIdentifiers: moved.sorted())
                        current.removeAll { moved.contains($0.identifier) }
                        let earlier = eligible.prefix(confirmed.count)
                        remaining = earlier.filter { notice in !current.contains { matches($0, notice) } }
                    }
                }
            }
            for notice in remaining where !current.contains(where: { matches($0, notice) }) {
                guard await reserve(notice, for: plan) else { return nil }
            }
            let listed = await ScheduleNotifications.readPending(from:center)
            guard let listed, !Task.isCancelled, revision == plan.revision else { return nil }
            current = listed
            if !displaced.isEmpty {
                let count = plan.desired.filter { notice in current.contains { matches($0, notice) } }.count
                let vacant = max(0, observedCapacity - count)
                if vacant > 0 {
                    for notice in displaced.prefix(vacant) {
                        guard await reserve(notice, for: plan) else { return nil }
                    }
                    let supplemented = await ScheduleNotifications.readPending(from: center)
                    guard let supplemented, !Task.isCancelled, revision == plan.revision else { return nil }
                    current = supplemented
                }
            }
            remaining = plan.desired.filter { notice in
                notice.canReserve(at: Date()) && !current.contains { matches($0,notice) }
            }
            if remaining.isEmpty { break }
        }
        return current
    }

    private func reserve(_ notice: CountdownNotice, for plan: NoticePlan) async -> Bool {
        guard !Task.isCancelled, revision == plan.revision else { return false }
        guard notice.canReserve(at: Date()) else { return true }
        let content = UNMutableNotificationContent()
        content.title = notice.title; content.body = "カウントダウンを確認してください。"; content.sound = .default
        content.userInfo = ["countdownID": notice.targetID.uuidString, "targetKey": notice.targetKey,
                            "fireAt": notice.fireAt.timeIntervalSince1970]
        if let scope = notice.classScope { content.userInfo["classScope"] = scope }
        let fields = SchoolDate.japanCalendar.dateComponents([.calendar, .timeZone, .year, .month, .day, .hour, .minute], from: notice.fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: fields, repeats: false)
        do {
            try await notificationWriter.add(identifier: notice.identifier, revision: plan.revision,
                responseUnconfirmed: { [weak self] in
                    guard let self, self.revision == plan.revision, self.notificationEnabled(for: notice.targetID) else { return }
                    self.notificationStatuses[notice.target] = "予約結果を確認できません。iPhoneの応答を待っています。"
                }) {
                guard notice.canReserve(at: Date()) else { throw CancellationError() }
                try await center.add(UNNotificationRequest(identifier: notice.identifier, content: content, trigger: trigger))
            }
        } catch {
            // The actual pending list decides what has been reserved.
        }
        let exactRetainedWrite = retentionPreservedWrite?.write == notificationWriter.latestCompletion?.write
            && retentionPreservedWrite?.write.identifier == notice.identifier
            && retentionPreservedWrite?.write.revision == plan.revision
        let preservingDuringRetention = exactRetainedWrite && retentionPreservedWrite?.invalidation == revision
        if exactRetainedWrite {
            retentionPreservedWrite = nil
        }
        if revision != plan.revision {
            let stillDesired = request?.desired.contains {
                $0.identifier == notice.identifier && $0.fireAt == notice.fireAt && $0.target == notice.target
                    && $0.title == notice.title && $0.canReserve(at: Date())
            } ?? (preservingDuringRetention && !Task.isCancelled)
            if !stillDesired || !notificationEnabled(for: notice.targetID) {
                await undoReservation(notice.identifier, includeDelivered: true)
            }
            return false
        }
        if Task.isCancelled {
            await undoReservation(notice.identifier, includeDelivered: false)
            return false
        }
        return true
    }

    private func undoReservation(_ identifier: String, includeDelivered: Bool) async {
        // Reconciliation cancellation cannot undo the native add. Withdraw it
        // independently, keeping the same owner if the system is slow to return.
        let cleanup = Task { [center, retentionRemovals] in
            await retentionRemovals.run(includeDelivered ? .all : .pending, identifiers: [identifier]) {
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
                if includeDelivered { center.removeDeliveredNotifications(withIdentifiers: [identifier]) }
            }
        }
        _ = await cleanup.value
    }

    private func matches(_ request: UNNotificationRequest, _ notice: CountdownNotice) -> Bool {
        request.identifier == notice.identifier && request.content.title == notice.title &&
            request.content.userInfo["targetKey"] as? String == notice.targetKey &&
            request.content.userInfo["fireAt"] as? Double == notice.fireAt.timeIntervalSince1970
    }
}
