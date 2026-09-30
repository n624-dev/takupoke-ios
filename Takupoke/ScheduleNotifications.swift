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

    private struct Input {
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
        message = nil
        if !value {
            let ids = changes ? ["takupoke.changes"] : ["takupoke.exam", "takupoke.examReturn"]
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
        let settings = await center.notificationSettings()
        if (changesEnabled || specialsEnabled), settings.authorizationStatus == .denied {
            message = "iPhoneの設定で通知を許可してください。"
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
        pending = Input(changes: changes, specials: specials, period: period)
        if let task = reconcileTask { await task.value; return }
        let task = Task { @MainActor in
            while let input = self.pending, !Task.isCancelled {
                self.pending = nil
                await self.apply(input)
            }
        }
        reconcileTask = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        reconcileTask = nil
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
            let settings = await center.notificationSettings()
            guard operation == generation, input.period == SchoolDataPeriod.current(),
                  UIApplication.shared.isProtectedDataAvailable else { return }
            let allowed = settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral
            let classes = Set((UserDefaults.standard.string(forKey: "timetableSelectedClasses") ?? "")
                .split(separator: "|").map { ChangeNormalizer.canonicalClassName(String($0)) })
            if let changes = input.changes {
                let count = next.changeCount(comparedWith: changes, today: .today(), classes: classes)
                if changesEnabled && allowed && count > 0 {
                    try await send("時間割変更があります", body: "\(count)件の時間割変更を確認してください。", kind: "changes")
                }
                next.changes = changes
            }
            for kind in SpecialScheduleKind.allCases {
                guard let digest = input.specials[kind.rawValue] else { continue }
                if specialsEnabled && allowed && next.specialChanged(kind: kind.rawValue, digest: digest) {
                    try await send("\(kind.title)が更新されました", body: "時間割で更新内容を確認してください。", kind: kind.rawValue)
                }
                next.specialDigests[kind.rawValue] = digest
            }
            guard operation == generation, input.period == SchoolDataPeriod.current(),
                  UIApplication.shared.isProtectedDataAvailable else { return }
            try Task.checkCancellation()
            if next != baseline {
                try JSONEncoder().encode(next).write(to: file, options: .atomic)
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
                baseline = next
            }
        } catch {
            if operation == generation, !Task.isCancelled { message = "通知の更新確認を保存できませんでした。" }
        }
    }

    private func send(_ title: String, body: String, kind: String) async throws {
        try Task.checkCancellation()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
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
