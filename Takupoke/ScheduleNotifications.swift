import CryptoKit
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class ScheduleNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var changesEnabled = UserDefaults.standard.bool(forKey: "notifyScheduleChanges")
    @Published private(set) var specialsEnabled = UserDefaults.standard.bool(forKey: "notifySpecialSchedules")
    @Published private(set) var requestingPermission = false
    @Published private(set) var message: String?

    private let center = UNUserNotificationCenter.current()
    private var baseline: ScheduleNotificationSnapshot?
    private var loaded = false
    private var reconcileTask: Task<Void, Never>?
    private var pending: Input?
    private var generation = UUID()
    private var latestRevision = UUID()

    private struct Input {
        let revision: UUID
        let changes: Set<ScheduleNotificationSnapshot.Change>?
        let specials: [String: String]
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

    func setEnabled(changes: Bool, value: Bool) async {
        guard !requestingPermission else { return }
        if value {
            requestingPermission = true
            defer { requestingPermission = false }
            do {
                guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                    message = "iPhoneの設定で通知を許可してください。"
                    return
                }
            } catch {
                message = "通知の許可を確認できませんでした。"
                return
            }
        }
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
        if !value {
            let ids = changes ? ["takupoke.changes"] : ["takupoke.exam", "takupoke.examReturn"]
            reconcileTask?.cancel()
            await reconcileTask?.value
            if var value = baseline {
                for id in ids { value.pending.removeValue(forKey: String(id.dropFirst("takupoke.".count))) }
                do { try save(value, to: storageFile()) }
                catch { message = "通知の更新確認を保存できませんでした。" }
            }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    func enableFromSetup() async {
        guard !UserDefaults.standard.bool(forKey: "notificationsSetupCompleted") else { return }
        await setEnabled(changes: true, value: true)
        if changesEnabled { await setEnabled(changes: false, value: true) }
        UserDefaults.standard.set(true, forKey: "notificationsSetupCompleted")
    }

    func checkPermission() async {
        let deniedMessage = "iPhoneの設定で通知を許可してください。"
        guard changesEnabled || specialsEnabled else {
            if message == deniedMessage { message = nil }
            return
        }
        let settings = await Self.notificationSettings(from: center)
        if (changesEnabled || specialsEnabled), settings.authorizationStatus == .denied {
            message = deniedMessage
        } else if message == deniedMessage { message = nil }
    }

    // Keep the actual OS response across the callback/concurrency boundary.
    // This performs one read, without requesting permission or caching its value.
    nonisolated private static func notificationSettings(
        from center: UNUserNotificationCenter
    ) async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    func resetForRetention() async {
        generation = UUID()
        pending = nil
        reconcileTask?.cancel()
        await reconcileTask?.value
        baseline = nil
        loaded = false
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func reconcile(state: MaterialLibraryState, records: [SpecialScheduleKind: SpecialScheduleRecord],
                   sources: [SpecialScheduleKind: SpecialScheduleSource], period: SchoolDataPeriod) async {
        guard !Task.isCancelled, UIApplication.shared.isProtectedDataAvailable,
              period == SchoolDataPeriod.current() else { return }
        var changes: Set<ScheduleNotificationSnapshot.Change>?
        if let accepted = ScheduleNotificationSnapshot.acceptedChanges(in: state) {
            changes = Set(accepted.map { row in
                let period = row.detailPeriods?.map(String.init).joined(separator: ",") ?? row.period
                let fields = [row.change_date, row.displayClassName, period,
                              row.before_subject, row.after_subject, row.teacher, row.room, row.note]
                let data = (try? JSONEncoder().encode(fields)) ?? Data()
                let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                return ScheduleNotificationSnapshot.Change(date: row.change_date,
                    className: row.displayClassName, period: period, fingerprint: hash)
            })
        }
        let specials = ScheduleNotificationSnapshot.acceptedSpecialDigests(records: records, sources: sources)
        latestRevision = UUID()
        pending = Input(revision:latestRevision,changes: changes, specials: specials, period: period)
        await drainPending()
    }

    private func drainPending() async {
        guard pending != nil, !Task.isCancelled else { return }
        let task: Task<Void, Never>
        if let current = reconcileTask { task = current }
        else {
            task = Task { @MainActor in
                defer { self.reconcileTask = nil }
                while let input = self.pending, !Task.isCancelled {
                    self.pending = nil
                    await self.apply(input)
                }
            }
            reconcileTask = task
        }
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        // A cancelled send can leave a newer, valid input waiting. A caller
        // still allowed to run drains it after the old task has fully stopped.
        if pending != nil, !Task.isCancelled { await drainPending() }
    }

    private func deliveryAllowed() async -> Bool {
        // Keep the comparison baseline current even when notifications are off.
        // No notification can be delivered in that state, so an OS settings read
        // must not delay saving the baseline or the next input.
        guard changesEnabled || specialsEnabled else { return false }
        let settings = await Self.notificationSettings(from: center)
        return settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral
    }

    private func apply(_ input: Input) async {
        let operation = generation
        do {
            try Task.checkCancellation()
            guard UIApplication.shared.isProtectedDataAvailable, input.period == SchoolDataPeriod.current() else { return }
            let file = try storageFile()
            if !loaded {
                if FileManager.default.fileExists(atPath: file.path) {
                    baseline = try JSONDecoder().decode(ScheduleNotificationSnapshot.self, from: Data(contentsOf: file))
                } else { baseline = ScheduleNotificationSnapshot() }
                loaded = true
            }
            guard var next = baseline else { return }
            let allowed = await deliveryAllowed()
            guard operation == generation, input.period == SchoolDataPeriod.current(),
                  UIApplication.shared.isProtectedDataAvailable else { return }
            let classes = Set((UserDefaults.standard.string(forKey: "timetableSelectedClasses") ?? "")
                .split(separator: "|").map { ChangeNormalizer.canonicalClassName(String($0)) })
            if let changes = input.changes {
                let targets = next.pendingChangeTargets(in:changes,today:.today(),classes:classes)
                if changesEnabled && allowed, !targets.isEmpty {
                    next.pending["changes"] = try changeNotice(targets)
                } else { next.pending.removeValue(forKey:"changes") }
                next.changes = changes
            } else { next.pending.removeValue(forKey:"changes") }
            for kind in SpecialScheduleKind.allCases {
                guard let digest = input.specials[kind.rawValue] else { next.pending.removeValue(forKey:kind.rawValue); continue }
                if specialsEnabled && allowed && next.specialChanged(kind: kind.rawValue, digest: digest) {
                    next.pending[kind.rawValue] = .init(fingerprint: digest, count: 1)
                }
                next.specialDigests[kind.rawValue] = digest
            }
            if !changesEnabled || !allowed { next.pending.removeValue(forKey: "changes") }
            if !specialsEnabled || !allowed {
                for kind in SpecialScheduleKind.allCases { next.pending.removeValue(forKey: kind.rawValue) }
            }
            guard operation == generation, input.period == SchoolDataPeriod.current(),
                  UIApplication.shared.isProtectedDataAvailable else { return }
            try Task.checkCancellation()
            // Commit the comparison baseline and outgoing notices together,
            // before yielding to the notification service. An interrupted send
            // can be retried without recomputing or losing the data difference.
            if next != baseline { try save(next, to: file) }
            for kind in ["changes", "exam", "examReturn"] {
                guard var notice = next.pending[kind] else { continue }
                try Task.checkCancellation()
                guard operation == generation, input.period == SchoolDataPeriod.current(),
                      UIApplication.shared.isProtectedDataAvailable else { return }
                let queued = await center.pendingNotificationRequests()
                let deliveredNotifications = await center.deliveredNotifications()
                let delivered = deliveredNotifications.map(\.request)
                // Selection or midnight may change while the notification service
                // suspends. Revalidate the exact slots immediately before delivery.
                if kind == "changes" {
                    let currentClasses = Set((UserDefaults.standard.string(forKey:"timetableSelectedClasses") ?? "")
                        .split(separator:"|").map { ChangeNormalizer.canonicalClassName(String($0)) })
                    let targets = next.validTargets(notice.changeTargets ?? [],in:input.changes ?? [],today:.today(),classes:currentClasses)
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
                if !alreadySent { try await send(kind: kind, notice: notice) }
                guard operation == generation, input.period == SchoolDataPeriod.current(),
                      UIApplication.shared.isProtectedDataAvailable else { return }
                // Acknowledge an accepted notice even if cancellation arrived
                // while add() was completing. Do not deliver it again on return.
                next.pending.removeValue(forKey: kind)
                try save(next, to: file)
            }
            message = nil
        } catch {
            if operation == generation, !Task.isCancelled { message = "通知の更新確認を保存できませんでした。" }
        }
    }

    private func changeNotice(_ targets: [ScheduleNotificationSnapshot.ChangeTarget]) throws -> ScheduleNotificationSnapshot.Pending {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let fingerprint = SHA256.hash(data:try encoder.encode(targets)).map { String(format:"%02x",$0) }.joined()
        return .init(fingerprint:fingerprint,count:targets.count,changeTargets:targets)
    }

    private func save(_ value: ScheduleNotificationSnapshot, to file: URL) throws {
        try JSONEncoder().encode(value).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
        baseline = value
    }

    private func send(kind: String, notice: ScheduleNotificationSnapshot.Pending) async throws {
        try Task.checkCancellation()
        let content = UNMutableNotificationContent()
        content.title = kind == "changes" ? "時間割変更があります" :
            "\(kind == "exam" ? SpecialScheduleKind.exam.title : SpecialScheduleKind.examReturn.title)が更新されました"
        content.body = kind == "changes" ? "\(notice.count)件の時間割変更を確認してください。" :
            "時間割で更新内容を確認してください。"
        content.userInfo = ["revision": notice.fingerprint]
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
