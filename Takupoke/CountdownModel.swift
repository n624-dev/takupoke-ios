import Foundation
import SwiftUI
import CryptoKit
import UserNotifications

@MainActor
final class CountdownModel: ObservableObject {
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
    @Published private(set) var notificationStatuses: [UUID: String] = [:]
    @Published private(set) var publicEvents: [PublicEvent] = []
    @Published private(set) var automaticAlternatives: [PublicEvent] = []
    private var store: CountdownStore?
    private let center = UNUserNotificationCenter.current()
    private var request: NoticePlan?
    private var worker: Task<Void, Never>?
    private var revision = UUID()
    var onChange: (() -> Void)?

    private struct NoticePlan {
        let revision: UUID
        let desired: [CountdownNotice]
        let cards: [UUID: CountdownCard]
    }

    var isConfigured: Bool { !library.registrations.isEmpty || library.automatic.enabled }
    var homeCards: [CountdownCard] { CountdownCard.home(cards, today: day) }

    func load() {
        guard store == nil else { return }
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
            let store = CountdownStore(root: root)
            library = try store.load()
            self.store = store
            message = nil
        } catch {
            message = "保存したカウントダウンを読み込めません。端末内の登録は保持しています。"
        }
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
        var resolved = library.registrations.map { registration -> CountdownCard in
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
        var alternatives: [PublicEvent] = []
        if library.automatic.enabled {
            let automatic = library.automatic
            switch automatic.mode {
            case .school:
                let candidates = nextEvents.filter { $0.tag == "テスト" && $0.dates.end >= today }.sorted {
                    let lhs = $0.dates.phase(on: today).active, rhs = $1.dates.phase(on: today).active
                    return lhs == rhs ? ($0.dates.start, $0.dates.end, $0.id) < ($1.dates.start, $1.dates.end, $1.id) : lhs
                }
                alternatives = Array(candidates.dropFirst())
                if let first = candidates.first {
                    if !resolved.contains(where: { $0.reference == first.reference }) {
                        resolved.append(.init(id: automatic.id, title: first.dates.title, dates: first.dates,
                            preferences: automatic.preferences, availability: events.countdownSourceState(year: first.reference.year, at: now),
                            reference: first.reference))
                    }
                } else {
                    let availability: CountdownAvailability = events.saved[today.schoolYear]?.payload.identifiedEvents == nil
                        ? .missingYear : .noExam
                    resolved.append(placeholder(automatic, availability))
                }
            case .selectedClass:
                resolved.append(selectedClassCard(automatic, using: app, today: today, now: now))
            }
        }
        if alternatives != automaticAlternatives { automaticAlternatives = alternatives }
        let sorted = CountdownCard.sorted(resolved, today: today)
        if cards != sorted { cards = sorted }
        planNotifications(at: now)
    }

    private func placeholder(_ automatic: CountdownAutomatic, _ availability: CountdownAvailability) -> CountdownCard {
        CountdownCard(id: automatic.id, title: automatic.mode.label, dates: nil,
                      preferences: automatic.preferences, availability: availability)
    }

    private func selectedClassCard(_ automatic: CountdownAutomatic, using app: ApplicationData,
                                   today: SchoolDate, now: Date) -> CountdownCard {
        let classes = TimetableView.decode(UserDefaults.standard.string(forKey: "timetableSelectedClasses") ?? "")
            .filter(TimetableSchedule.selectableClasses.contains)
        guard !classes.isEmpty else { return placeholder(automatic, .noClass) }
        guard app.ready, let period = app.loadedPeriod, period == SchoolDataPeriod(day: today),
              let expiry = period.endsAt, now < expiry else { return placeholder(automatic, .expired) }
        let specials = app.specialSchedules
        guard specials.ready else { return placeholder(automatic, specials.failed ? .analysisFailed : .loading) }
        let source = specials.sources[.exam]
        guard let record = specials.records[.exam] else {
            return placeholder(automatic, source == nil ? .noDocument :
                source?.failure != nil || specials.rejectedRecoveryKinds.contains(.exam) ? .analysisFailed : .notAnalysed)
        }
        guard SchoolDataPeriod.current(at: record.acquiredAt) == period else { return placeholder(automatic, .expired) }
        guard record.digest == record.analysis.sourceDigest, record.analysis.version == SpecialScheduleAnalysis.parserVersion,
              !specials.rejectedRecoveryKinds.contains(.exam) else { return placeholder(automatic, .analysisFailed) }
        let availability: CountdownAvailability = specials.availability.state(for: .exam) == .current ? .available : .previousResult
        let schedule = TimetableDaySchedule(timetable: app.materials.state.pdfAnalyses?[MaterialKind.timetable.rawValue],
            changes: app.materials.state.changeAnalysis, events: app.schoolEvents.analysis,
            specials: specials.scheduleAnalyses, includesChanges: true, customTimes: app.times.current?.data,
            sourceIndex: app.scheduleSourceIndex(materials: app.materials, specials: specials, events: app.schoolEvents))
        let international = UserDefaults.standard.bool(forKey: "timetableInternationalStudent")
        let candidates = record.analysis.coveredDates.compactMap(SchoolDate.init(iso8601:)).sorted()
        for candidate in candidates where candidate >= today {
            guard let date = candidate.dateInJapan(), date < expiry else { continue }
            let subjects = schedule.examSubjects(on: candidate, classes: classes, international: international) { subject, name, year in
                app.mappings.current?.rules.isInternationalStudentChangeField(subject, className: name, schoolYear: year) == true
            }
            guard !subjects.isEmpty else { continue }
            let evidence = ([candidate.iso8601, record.digest, app.materials.state.changeAnalysis?.sourceDigest ?? "",
                app.mappings.current?.revision ?? "", String(international)] + classes + subjects).joined(separator: "\u{0}")
            let key = SHA256.hash(data: Data(evidence.utf8)).map { String(format: "%02x", $0) }.joined()
            return CountdownCard(id: automatic.id, title: automatic.mode.label,
                dates: .init(title: automatic.mode.label, ranges: [.init(start: candidate, end: candidate)]),
                preferences: automatic.preferences, availability: availability, expiry: expiry,
                classSubjects: subjects, evidence: key)
        }
        return placeholder(automatic, .noExam)
    }

    func notificationPermission() async {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            do { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
            catch { message = "通知の許可を確認できません。端末の通知設定を確認してください。" }
        }
    }

    func expirePrivateNotices(removeDelivered: Bool) async {
        cards.removeAll { $0.isPrivate }
        // Cold launch can reach retention before the public/personal cards are
        // loaded. Cancel an old plan without reconciling against that empty list.
        revision = UUID()
        request = nil
        await worker?.value
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(CountdownNotice.privatePrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        if removeDelivered {
            let delivered = await center.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(CountdownNotice.privatePrefix) }
            center.removeDeliveredNotifications(withIdentifiers: delivered)
        }
    }

    private func planNotifications(at now: Date) {
        let token = UUID(); revision = token
        request = .init(revision: token, desired: CountdownNotice.planned(for: cards, at: now),
                        cards: Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) }))
        guard worker == nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            while let plan = self.request {
                self.request = nil
                await self.reconcile(plan)
            }
            self.worker = nil
        }
    }

    private func reconcile(_ plan: NoticePlan) async {
        let settings = await center.notificationSettings()
        let allowed = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        guard revision == plan.revision else { return }
        let desired = allowed ? Dictionary(uniqueKeysWithValues: plan.desired.map { ($0.identifier, $0) }) : [:]
        let owned = pending.filter { $0.identifier.hasPrefix(CountdownNotice.prefix) }
        let obsolete = owned.filter { existing in
            guard let proposed = desired[existing.identifier] else { return true }
            return !matches(existing, proposed)
        }
        center.removePendingNotificationRequests(withIdentifiers: obsolete.map(\.identifier))
        let outdated = delivered.map(\.request).filter { existing in
            guard existing.identifier.hasPrefix(CountdownNotice.prefix) else { return false }
            guard let uuid = existing.content.userInfo["countdownID"] as? String, let id = UUID(uuidString: uuid),
                  let card = plan.cards[id], let start = card.dates?.start else { return true }
            return !allowed || !card.preferences.notifications || !card.availability.allowsNotification ||
                existing.content.title != card.title || existing.content.userInfo["targetKey"] as? String != card.targetKey ||
                !card.preferences.reminders.contains { reminder in
                    existing.identifier.hasSuffix("." + reminder.key) &&
                        existing.content.userInfo["fireAt"] as? Double == reminder.fireDate(start: start)?.timeIntervalSince1970
                }
        }
        center.removeDeliveredNotifications(withIdentifiers: outdated.map(\.identifier))
        for notice in plan.desired where allowed {
            guard revision == plan.revision else { return }
            if owned.contains(where: { $0.identifier == notice.identifier && matches($0, notice) }) { continue }
            guard notice.fireAt > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = notice.title; content.body = "カウントダウンを確認してください。"; content.sound = .default
            content.userInfo = ["countdownID": notice.targetID.uuidString, "targetKey": notice.targetKey,
                                "fireAt": notice.fireAt.timeIntervalSince1970]
            let fields = SchoolDate.japanCalendar.dateComponents([.calendar, .timeZone, .year, .month, .day, .hour, .minute], from: notice.fireAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: fields, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: notice.identifier, content: content, trigger: trigger))
        }
        let current = await center.pendingNotificationRequests()
        guard revision == plan.revision else { return }
        var statuses: [UUID: String] = [:]
        for (id, card) in plan.cards where card.preferences.notifications {
            let expected = plan.desired.filter { $0.targetID == id }
            if !card.availability.allowsNotification { statuses[id] = "通知は保留中です。" }
            else if !allowed { statuses[id] = "端末で通知が許可されていません。" }
            else if expected.isEmpty { statuses[id] = "これからの通知日時はありません。" }
            else {
                let count = expected.filter { notice in current.contains { matches($0, notice) } }.count
                statuses[id] = count == expected.count ? "\(count)件予約済み" : "\(count)件予約済み・\(expected.count - count)件を予約できません。"
            }
        }
        if notificationStatuses != statuses { notificationStatuses = statuses }
    }

    private func matches(_ request: UNNotificationRequest, _ notice: CountdownNotice) -> Bool {
        request.identifier == notice.identifier && request.content.title == notice.title &&
            request.content.userInfo["targetKey"] as? String == notice.targetKey &&
            request.content.userInfo["fireAt"] as? Double == notice.fireAt.timeIntervalSince1970
    }
}
