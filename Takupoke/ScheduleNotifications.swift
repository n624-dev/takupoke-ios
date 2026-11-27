import CryptoKit
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class ScheduleNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let updateIdentifiers = ["takupoke.changes", "takupoke.exam", "takupoke.examReturn"]
    private static let notificationStopPending = "処理中だった通知の取り消しを確認中です。"
    struct CountdownDestination: Identifiable {
        let target: CountdownNoticeTarget
        var id: CountdownNoticeTarget { target }
    }
    @Published var openedCountdown: CountdownDestination?
    @Published var openedUpdate: ScheduleUpdateNotice?

    @Published private(set) var changesEnabled = UserDefaults.standard.bool(forKey: "notifyScheduleChanges")
    @Published private(set) var specialsEnabled = UserDefaults.standard.bool(forKey: "notifySpecialSchedules")
    @Published private(set) var requestingPermission = false
    @Published private(set) var message: String?
    @Published private(set) var permissionMessage: String?

    private let center = UNUserNotificationCenter.current()
    private var baseline: ScheduleNotificationSnapshot?
    private var loaded = false
    private var reconcileTask: NotificationWork?
    private var disabledNotificationsAwaitingWrite = Set<String>()
    private var pending: Input?
    private var generation = UUID()
    private var latestRevision = UUID()
    private var permissionReadSequence = 0
    private var lastAppliedPermissionSequence = 0

    private struct Input {
        let changeDocument: String?
        let personalEdit: Bool
        let revision: UUID
        let changes: Set<ScheduleNotificationSnapshot.Change>?
        let changeScope: @MainActor () -> ScheduleNotificationSnapshot.ChangeScope?
        let specials: [String: String]
        let availability: ScheduleNotificationSnapshot.Availability
        let period: SchoolDataPeriod
    }

    override init() {
        super.init()
        center.delegate = self
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                          didReceive response: UNNotificationResponse) async {
        let request = response.notification.request
        if let update = ScheduleUpdateNotice(identifier: request.identifier,
            revision: request.content.userInfo["revision"] as? String,
            documentRevision: request.content.userInfo["document"] as? String,
            classRevision: request.content.userInfo["selectedClassesVersion"] as? String,
            days: request.content.userInfo["targetDays"] as? [String] ?? []) {
            await MainActor.run {
                guard self.openedUpdate != update else { return }
                self.openedUpdate = update
            }
            return
        }
        guard request.identifier.hasPrefix(CountdownNotice.prefix),
              let idValue = request.content.userInfo["countdownID"] as? String, let id = UUID(uuidString: idValue),
              let target = request.content.userInfo["targetKey"] as? String else { return }
        await MainActor.run {
            self.openedCountdown = CountdownDestination(target: .init(id: id, key: target))
        }
    }

    func setEnabled(changes: Bool, value: Bool) async {
        guard !requestingPermission else { return }
        if value {
            requestingPermission = true
            defer { requestingPermission = false }
            guard await confirmAuthorization() else { return }
        }
        applyPreference(changes: changes, value: value)
        if !value { await disableNotifications(changes: changes) }
    }

    private func applyPreference(changes: Bool, value: Bool) {
        if changes {
            changesEnabled = value
            UserDefaults.standard.set(value, forKey: "notifyScheduleChanges")
        } else {
            specialsEnabled = value
            UserDefaults.standard.set(value, forKey: "notifySpecialSchedules")
        }
        // Manual choices also complete notification setup; reopening the
        // general setup must not enable a type the person turned off.
        UserDefaults.standard.set(true, forKey: "notificationsSetupCompleted")
        message = nil
        if value || (!changesEnabled && !specialsEnabled) {
            lastAppliedPermissionSequence = permissionReadSequence
            permissionMessage = nil
        }
    }

    private func disableNotifications(changes: Bool) async {
        let ids = changes ? ["takupoke.changes"] : ["takupoke.exam", "takupoke.examReturn"]
        guard let worker = reconcileTask else { clearDisabledNotifications(ids); return }
        // Remove notices already in the center even when the in-flight add
        // cannot finish. Remove again once that write has actually stopped.
        disabledNotificationsAwaitingWrite.formUnion(ids)
        if !changesEnabled && !specialsEnabled { worker.cancel() }
        removeUpdateNotifications(ids)
        let finished = await worker.waitForCompletion()
        if !finished, !Task.isCancelled, !(changes ? changesEnabled : specialsEnabled),
           ids.contains(where: disabledNotificationsAwaitingWrite.contains) {
            message = Self.notificationStopPending
        }
    }

    private func finishDeferredNotificationRemovals() {
        let ids = Self.updateIdentifiers.filter { id in
            disabledNotificationsAwaitingWrite.contains(id) &&
                (id == "takupoke.changes" ? !changesEnabled : !specialsEnabled)
        }
        disabledNotificationsAwaitingWrite.removeAll()
        if message == Self.notificationStopPending { message = nil }
        if !ids.isEmpty { clearDisabledNotifications(ids) }
    }

    private func clearDisabledNotifications(_ ids: [String]) {
        if var value = baseline {
            for id in ids { value.pending.removeValue(forKey: String(id.dropFirst("takupoke.".count))) }
            do { try save(value, to: storageFile()) }
            catch { message = "通知の更新確認を保存できませんでした。" }
        }
        removeUpdateNotifications(ids)
    }

    private func removeUpdateNotifications(_ ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // Start the permission UI on this object's MainActor, then transport the
    // actual callback result. A nonisolated async entry would leave that actor.
    // Denial and errors never enable or persist a notification setting.
    static func requestAuthorization(
        from center: UNUserNotificationCenter
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: granted) }
            }
        }
    }

    func enableFromSetup() async {
        guard !Task.isCancelled, !requestingPermission,
              !UserDefaults.standard.bool(forKey: "notificationsSetupCompleted") else { return }
        requestingPermission = true
        defer { requestingPermission = false }
        let allowed = await confirmAuthorization()
        guard !Task.isCancelled else { return }
        if allowed {
            applyPreference(changes: true, value: true)
            applyPreference(changes: false, value: true)
        }
        UserDefaults.standard.set(true, forKey: "notificationsSetupCompleted")
    }

    private func confirmAuthorization() async -> Bool {
        do {
            guard try await Self.requestAuthorization(from: center) else {
                lastAppliedPermissionSequence = permissionReadSequence
                permissionMessage = "iPhoneの設定で通知を許可してください。"
                return false
            }
            return true
        } catch {
            permissionMessage = "通知の許可を確認できませんでした。"
            return false
        }
    }

    func checkPermission() async {
        guard changesEnabled || specialsEnabled else {
            permissionMessage = nil
            return
        }
        _ = await readCurrentNotificationSettings()
    }

    private func readCurrentNotificationSettings() async -> UNNotificationSettings? {
        permissionReadSequence += 1
        let sequence = permissionReadSequence
        // Only a confirmed response can supersede an earlier read.
        guard let settings = await Self.notificationSettings(from:center), !Task.isCancelled,
              sequence > lastAppliedPermissionSequence else { return nil }
        lastAppliedPermissionSequence = sequence
        recordPermission(settings)
        return settings
    }

    // Keep the actual OS response across the callback/concurrency boundary. Missing or cancelled reads
    // are unconfirmed, so callers can preserve prior decisions and retry.
    nonisolated static func notificationSettings(
        from center: UNUserNotificationCenter, timeout: Duration = .seconds(6)
    ) async -> UNNotificationSettings? {
        await notificationQuery(timeout:timeout) { callback in
            center.getNotificationSettings { settings in
                callback(settings)
            }
        }
    }

    nonisolated static func readPending(
        from center: UNUserNotificationCenter, timeout: Duration = .seconds(6)
    ) async -> [UNNotificationRequest]? {
        await notificationQuery(timeout:timeout) { callback in
            center.getPendingNotificationRequests(completionHandler:callback)
        }
    }

    nonisolated static func readDelivered(from center: UNUserNotificationCenter) async -> [UNNotification]? {
        await notificationQuery(timeout:.seconds(6)) { callback in
            center.getDeliveredNotifications(completionHandler:callback)
        }
    }

    nonisolated static func notificationQuery<Value>(
        timeout: Duration, _ request: (@escaping @Sendable (Value) -> Void) -> Void
    ) async -> Value? {
        guard !Task.isCancelled else { return nil }
        let (results, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy:.bufferingNewest(1))
        let timeoutTask = Task {
            do { try await Task.sleep(for:timeout) } catch { return }
            continuation.finish()
        }
        defer { timeoutTask.cancel(); continuation.finish() }
        request { value in
            continuation.yield(value)
            continuation.finish()
        }
        var iterator = results.makeAsyncIterator()
        let value = await iterator.next()
        return Task.isCancelled ? nil : value
    }

    /// Recovery must remain usable if the notification service never responds.
    nonisolated static func pendingStorageRecoveryIdentifiers(
        from center: UNUserNotificationCenter, timeout: Duration = .seconds(6)
    ) async -> [String]? {
        #if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
        print("TAKUPOKE_COUNTDOWN_STORAGE pending-read-start")
        #endif
        let identifiers = await readPending(from:center,timeout:timeout)?.map(\.identifier)
        #if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
        print("TAKUPOKE_COUNTDOWN_STORAGE pending-read-\(identifiers == nil ? "unavailable" : "complete")")
        #endif
        return identifiers
    }

    func suspendForUnavailableData() async -> Bool {
        generation = UUID()
        pending = nil
        guard await reconcileTask?.stop() != false, !Task.isCancelled else { return false }
        baseline = nil
        loaded = false
        return true
    }

    func resetForRetention() async -> Bool {
        guard await suspendForUnavailableData() else { return false }
        center.removePendingNotificationRequests(withIdentifiers: Self.updateIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: Self.updateIdentifiers)
        return true
    }

    func reconcile(state: MaterialLibraryState, records: [SpecialScheduleKind: SpecialScheduleRecord],
                   sources: [SpecialScheduleKind: SpecialScheduleSource], period: SchoolDataPeriod,
                   materialsReady: Bool = true, specialsReady: Bool = true,
                   mapping: @escaping @MainActor () -> SavedMapping? = { nil }) async {
        guard !Task.isCancelled, UIApplication.shared.isProtectedDataAvailable,
              period == SchoolDataPeriod.current() else { return }
        var rows: [ScheduleNotificationSnapshot.Change: ScheduleChange]?
        let year = ChangeNormalizer.effectiveSchoolYear(configured: UserDefaults.standard.string(forKey: ChangeNormalizer.schoolYearSettingKey), today: .today())
        if let source = state.record(for: .changes), state.changeAnalysis?.matches(record: source, defaultYear: year) == true,
           let accepted = ScheduleNotificationSnapshot.acceptedChanges(in: state) {
            rows = Dictionary(accepted.map { (ScheduleNotificationSnapshot.Change.from($0), $0) },
                              uniquingKeysWith: { first, _ in first })
        }
        let changes = rows.map { Set($0.keys) }
        let scope: @MainActor () -> ScheduleNotificationSnapshot.ChangeScope? = { [rows] in
            guard let rows else { return nil }
            return .init(visibility: .init(rows: rows, mapping: mapping()),
                         international: UserDefaults.standard.bool(forKey: "timetableInternationalStudent"),
                         showsChanges: UserDefaults.standard.object(forKey: "timetableIncludesChanges") as? Bool ?? true)
        }
        let specials = ScheduleNotificationSnapshot.acceptedSpecialDigests(records: records, sources: sources)
        latestRevision = UUID()
        var availability = ScheduleNotificationSnapshot.availability(materialsReady: materialsReady, specialsReady: specialsReady,
            state: state, records: records, sources: sources)
        if changes == nil && availability.changes == .available { availability.changes = .unavailable }
        let document = state.record(for: .changes).map { ($0.source.selectionID ?? $0.storedName) + "/" + $0.digest }
        pending = Input(changeDocument: document, personalEdit: state.changeAnalysis?.personalEdit == true, revision:latestRevision,changes: changes, changeScope: scope, specials: specials, availability: availability, period: period)
        await drainPending()
    }

    private func drainPending() async {
        guard pending != nil, !Task.isCancelled else { return }
        let task: NotificationWork
        if let current = reconcileTask { task = current }
        else {
            task = NotificationWork {
                defer {
                    self.reconcileTask = nil
                    self.finishDeferredNotificationRemovals()
                }
                while let input = self.pending, !Task.isCancelled {
                    self.pending = nil
                    await self.apply(input)
                }
            }
            reconcileTask = task
        }
        let finished = await withTaskCancellationHandler {
            await task.waitForCompletion(timeout:nil)
        } onCancel: { task.cancel() }
        guard finished else { return }
        // A cancelled send can leave a newer, valid input waiting. A caller
        // still allowed to run drains it after the old task has fully stopped.
        if pending != nil, !Task.isCancelled { await drainPending() }
    }

    private func deliveryAllowed() async -> Bool? {
        // Keep the comparison baseline current even when notifications are off.
        // No notification can be delivered in that state, so an OS settings read
        // must not delay saving the baseline or the next input.
        guard changesEnabled || specialsEnabled else { permissionMessage = nil; return false }
        guard let settings = await readCurrentNotificationSettings() else { return nil }
        guard changesEnabled || specialsEnabled else { return false }
        return settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral
    }

    private func recordPermission(_ settings: UNNotificationSettings) {
        permissionMessage = (changesEnabled || specialsEnabled) && settings.authorizationStatus == .denied
            ? "iPhoneの設定で通知を許可してください。" : nil
    }

    private func apply(_ input: Input) async {
        let operation = generation
        do {
            try Task.checkCancellation()
            guard UIApplication.shared.isProtectedDataAvailable, input.period == SchoolDataPeriod.current() else { return }
            let file = try storageFile()
            if !loaded {
                do { baseline = try ScheduleNotificationSnapshot.load(from: file) }
                catch ScheduleNotificationSnapshot.ReadError.invalidStructure {
                    guard input.availability.changes != .unavailable,
                          SpecialScheduleKind.allCases.allSatisfy({ input.availability.state(for: $0.rawValue) != .unavailable }) else {
                        message = "現在の資料が準備できたら、通知の比較データを復旧します。"
                        return
                    }
                    let current = try ScheduleNotificationSnapshot().reconciling(changes: input.changes,
                        specials: input.specials, availability: input.availability, today: .today(), classes: [],
                        changesEnabled: false, specialsEnabled: false, changeDocument: input.changeDocument,
                        personalEdit: input.personalEdit, scope: input.changeScope())
                    try ScheduleNotificationSnapshot.restoreKnownStructure(at: file, with: current)
                    baseline = current
                } catch ScheduleNotificationSnapshot.ReadError.unsupportedFormat {
                    message = "この版では通知の比較データを読み込めません。保存したデータは保持しています。"
                    return
                } catch {
                    message = "通知の比較データを読み込めませんでした。次の更新確認で再試行します。"
                    return
                }
                loaded = true
            }
            guard var next = baseline else { return }
            guard let allowed = await deliveryAllowed() else { return }
            guard operation == generation, input.period == SchoolDataPeriod.current(),
                  UIApplication.shared.isProtectedDataAvailable else { return }
            let classes = Set((UserDefaults.standard.string(forKey: "timetableSelectedClasses") ?? "")
                .split(separator: "|").map { ChangeNormalizer.canonicalClassName(String($0)) })
            next = try next.reconciling(changes: input.changes, specials: input.specials, availability: input.availability,
                today: .today(), classes: classes, changesEnabled: changesEnabled && allowed, specialsEnabled: specialsEnabled && allowed,
                changeDocument: input.changeDocument, personalEdit: input.personalEdit, scope: input.changeScope())
            guard operation == generation, input.period == SchoolDataPeriod.current(),
                  UIApplication.shared.isProtectedDataAvailable else { return }
            try Task.checkCancellation()
            // Commit the comparison baseline and outgoing notices together,
            // before yielding to the notification service. An interrupted send
            // can be retried without recomputing or losing the data difference.
            if next != baseline { try save(next, to: file) }
            func enabled(_ kind: String) -> Bool { kind == "changes" ? changesEnabled : specialsEnabled }
            var failedKinds: [String] = []
            for kind in ["changes", "exam", "examReturn"] {
                guard enabled(kind), input.availability.state(for: kind) == .available,
                      var notice = next.pending[kind] else { continue }
                try Task.checkCancellation()
                guard operation == generation, input.period == SchoolDataPeriod.current(),
                      UIApplication.shared.isProtectedDataAvailable else { return }
                guard let queued = await Self.readPending(from:center),
                      let deliveredNotifications = await Self.readDelivered(from:center) else { return }
                try Task.checkCancellation()
                guard enabled(kind) else { continue }
                let delivered = deliveredNotifications.map(\.request)
                // Selection or midnight may change while the notification service
                // suspends. Revalidate the exact slots immediately before delivery.
                if kind == "changes" {
                    let currentClasses = Set((UserDefaults.standard.string(forKey:"timetableSelectedClasses") ?? "")
                        .split(separator:"|").map { ChangeNormalizer.canonicalClassName(String($0)) })
                    guard latestRevision == input.revision else { return }
                    let targets = next.validTargets(notice.changeTargets ?? [], in: input.changes ?? [], today: .today(),
                                                    classes: currentClasses, scope: input.changeScope())
                    if targets.isEmpty { next.pending.removeValue(forKey:kind); try save(next,to:file); continue }
                    notice = try changeNotice(targets); next.pending[kind] = notice; try save(next,to:file)
                }
                let identifier = "takupoke." + kind
                let alreadySent = (queued + delivered).contains {
                    $0.identifier == identifier && $0.content.userInfo["revision"] as? String == notice.fingerprint
                }
                guard operation == generation, input.period == SchoolDataPeriod.current(),
                      UIApplication.shared.isProtectedDataAvailable else { return }
                guard latestRevision == input.revision else { return }
                if !alreadySent {
                    // A setting may change while this write is in the OS.
                    // Clean up this identifier before the next kind can wait.
                    defer { if !enabled(kind) { removeUpdateNotifications([identifier]) } }
                    do { try await send(kind: kind, notice: notice) }
                    catch {
                        try Task.checkCancellation()
                        failedKinds.append(kind)
                        continue
                    }
                }
                guard operation == generation, input.period == SchoolDataPeriod.current(),
                      UIApplication.shared.isProtectedDataAvailable else { return }
                // Acknowledge an accepted notice even if cancellation arrived
                // while add() was completing. Do not deliver it again on return.
                next.pending.removeValue(forKey: kind)
                try save(next, to: file)
            }
            guard operation == generation, latestRevision == input.revision, !Task.isCancelled,
                  input.period == SchoolDataPeriod.current(), UIApplication.shared.isProtectedDataAvailable else { return }
            message = failedKinds.contains(where: enabled)
                ? "更新通知を送信できませんでした。次の更新確認で再試行します。" : nil
        } catch {
            if operation == generation, !Task.isCancelled { message = "通知の更新確認を保存できませんでした。" }
        }
    }

    private func changeNotice(_ targets: [ScheduleNotificationSnapshot.ChangeTarget]) throws -> ScheduleNotificationSnapshot.Pending {
        try ScheduleNotificationSnapshot.notice(targets)
    }

    private func save(_ value: ScheduleNotificationSnapshot, to file: URL) throws {
        try value.save(to:file)
        baseline = value
    }

    private func send(kind: String, notice: ScheduleNotificationSnapshot.Pending) async throws {
        try Task.checkCancellation()
        let content = UNMutableNotificationContent()
        content.title = kind == "changes" ? "時間割変更があります" :
            "\(kind == "exam" ? SpecialScheduleKind.exam.title : SpecialScheduleKind.examReturn.title)が更新されました"
        content.body = kind == "changes" ? "\(notice.count)件の時間割変更を確認してください。" :
            "時間割で更新内容を確認してください。"
        var information: [String: Any] = ["revision": notice.fingerprint]
        if kind == "changes", let targets = notice.changeTargets, let document = baseline?.changeDocument {
            information["document"] = ScheduleUpdateNotice.digest(document)
            let classes = Set((UserDefaults.standard.string(forKey: "timetableSelectedClasses") ?? "")
                .split(separator: "|").map { ChangeNormalizer.canonicalClassName(String($0)) })
            information["selectedClassesVersion"] = ScheduleUpdateNotice.selectedClassesRevision(classes,
                international: UserDefaults.standard.bool(forKey: "timetableInternationalStudent"),
                mappingRevision: baseline?.changeVisibility?.mappingRevision ?? "no-mapping")
            information["targetDays"] = Array(Set(targets.map(\.date)).sorted().prefix(366))
        }
        content.userInfo = information
        content.sound = .default
        try await center.add(UNNotificationRequest(identifier: "takupoke." + kind, content: content, trigger: nil))
    }

    private func storageFile() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let root = base.appendingPathComponent("ScheduleNotifications", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: root.path)
        var directory = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return root.appendingPathComponent("baseline.json")
    }
}

@MainActor
final class NotificationWork {
    let task: Task<Void, Never>
    private let completion: Completion

    init(_ operation: @escaping @MainActor () async -> Void) {
        let completion = Completion()
        self.completion = completion
        task = Task {
            await operation()
            completion.finish()
        }
    }

    var value: Void { get async { await task.value } }

    nonisolated func cancel() { task.cancel() }

    func stop() async -> Bool {
        cancel()
        return await waitForCompletion()
    }

    /// A timed-out wait leaves the write with this worker until it finishes.
    func waitForCompletion(timeout: Duration? = .seconds(6)) async -> Bool {
        return await completion.wait(timeout:timeout)
    }

    @MainActor
    private final class Completion {
        private var finished = false
        private var waiters: [UUID: AsyncStream<Void>.Continuation] = [:]

        func finish() {
            finished = true
            for continuation in waiters.values { continuation.finish() }
            waiters.removeAll()
        }

        func wait(timeout: Duration?) async -> Bool {
            guard !Task.isCancelled else { return false }
            if finished { return true }
            let id = UUID()
            let (stream, continuation) = AsyncStream<Void>.makeStream()
            waiters[id] = continuation
            let deadline = timeout.map { duration in
                Task {
                    do { try await Task.sleep(for:duration) } catch { return }
                    continuation.finish()
                }
            }
            defer { deadline?.cancel(); waiters.removeValue(forKey:id) }
            var iterator = stream.makeAsyncIterator()
            _ = await iterator.next()
            return finished && !Task.isCancelled
        }
    }
}
