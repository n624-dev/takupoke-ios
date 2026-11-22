import SwiftUI
import UIKit
import Combine
import Network

/// One owner for foreground and background work. Stores and serial import
/// workers are shared so a refresh cannot overwrite another instance's state.
@MainActor
final class ApplicationData: ObservableObject {
    static let shared = ApplicationData()

    let recovery = PDFRecoveryCoordinator()
    let materials = MaterialsModel()
    let specialSchedules = SpecialSchedulesModel()
    let schoolEvents = SchoolEventsModel(canAccessData: { UIApplication.shared.isProtectedDataAvailable }, startsActive: false)
    let mappings = MappingModel()
    let links = LinksModel()
    let times = TimetableTimesModel()
    let account = AccountDataModel()
    let notifications = ScheduleNotifications()
    let countdown = CountdownModel()
    let projections = TimetableProjectionCache(suspended:true)
    let textMeasurements = TimetableTextMeasurements()
    let homeClock = HomeScheduleClock()

    func scheduleSourceIndex(materials:MaterialsModel,specials:SpecialSchedulesModel,events:SchoolEventsModel) -> TimetableSchedule.SourceIndex {
        projections.sourceIndex(for:.init(materials:materials.scheduleGeneration,specials:specials.scheduleGeneration,events:events.scheduleGeneration)) {
            TimetableSchedule.SourceIndex(timetable:materials.state.pdfAnalyses?[MaterialKind.timetable.rawValue],
                changes:materials.state.changeAnalysis,events:events.analysis,specials:specials.scheduleAnalyses)
        }
    }

    @Published private(set) var ready = false
    @Published private(set) var loadedPeriod: SchoolDataPeriod?
    @Published private(set) var retentionFailure = false
    @Published var retentionNotice = false
    @Published private(set) var retentionFailureReason: SchoolDataRetention.Failure?
    var canRecoverRetention: Bool {
        retentionFailureReason == .invalidMarker || retentionFailureReason == .notificationCleanup(recoveringInvalidMarker:true)
    }
    var retentionFailureMessage: String { retentionFailureReason?.message ?? SchoolDataRetention.Failure.cleanup.message }
    private var preparing = false
    private var backgroundRefresh: Task<Void, Never>?
    private var observations = Set<AnyCancellable>()
    private let eventsNetwork = NWPathMonitor()

    init() {
        materials.$ready.sink { [weak self] _ in self?.checkNotificationsWhenActive() }.store(in: &observations)
        specialSchedules.$ready.sink { [weak self] _ in self?.checkNotificationsWhenActive() }.store(in: &observations)
        materials.$state.sink { [weak self] _ in self?.checkNotificationsWhenActive() }.store(in: &observations)
        specialSchedules.$records.sink { [weak self] _ in self?.checkNotificationsWhenActive() }.store(in: &observations)
        specialSchedules.$sources.sink { [weak self] _ in self?.checkNotificationsWhenActive() }.store(in: &observations)
        eventsNetwork.pathUpdateHandler = { [weak self] path in
            let reachable = path.status == .satisfied
            Task { @MainActor [weak self] in self?.schoolEvents.setNetworkReachable(reachable) }
        }
        eventsNetwork.start(queue: DispatchQueue(label: "jp.n624.takupoke.events-network"))
        countdown.onChange = { [weak self] in self?.updateCountdown() }
        schoolEvents.$saved.sink { [weak self] _ in self?.checkCountdownWhenActive() }.store(in: &observations)
        schoolEvents.$sourcePresentationRevision.sink { [weak self] _ in self?.checkCountdownWhenActive() }.store(in: &observations)
        materials.$state.sink { [weak self] _ in self?.checkCountdownWhenActive() }.store(in: &observations)
        materials.$ready.sink { [weak self] _ in self?.checkCountdownWhenActive() }.store(in: &observations)
        materials.$failed.sink { [weak self] _ in self?.checkCountdownWhenActive() }.store(in: &observations)
        specialSchedules.$ready.sink { [weak self] _ in self?.checkCountdownWhenActive() }.store(in: &observations)
        specialSchedules.$records.sink { [weak self] _ in self?.checkCountdownWhenActive() }.store(in: &observations)
        specialSchedules.$sources.sink { [weak self] _ in self?.checkCountdownWhenActive() }.store(in: &observations)
        mappings.$current.sink { [weak self] _ in self?.checkCountdownWhenActive() }.store(in: &observations)
        homeClock.$epoch.sink { [weak self] _ in self?.checkCountdownWhenActive() }.store(in: &observations)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .map { _ in
                let defaults = UserDefaults.standard
                return [defaults.string(forKey: "timetableSelectedClasses") ?? "", String(defaults.bool(forKey: "timetableInternationalStudent")),
                        defaults.string(forKey: ChangeNormalizer.schoolYearSettingKey) ?? ""]
            }.removeDuplicates()
            .sink { [weak self] _ in self?.checkCountdownWhenActive() }.store(in: &observations)
    }

    private var countdownUpdateScheduled = false

    private func checkCountdownWhenActive() {
        guard !countdownUpdateScheduled else { return }
        countdownUpdateScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.countdownUpdateScheduled = false
            if UIApplication.shared.applicationState == .active { self.updateCountdown() }
        }
    }

    func updateCountdown() {
        guard ready, UIApplication.shared.isProtectedDataAvailable else { return }
        countdown.update(using: self, at: homeClock.currentDate)
    }

    private func checkNotificationsWhenActive() {
        Task { @MainActor [weak self] in
            guard let self, self.ready, UIApplication.shared.applicationState == .active,
                  let period = self.loadedPeriod else { return }
            await self.notifications.reconcile(state: self.materials.state, records: self.specialSchedules.records,
                                                sources: self.specialSchedules.sources, period: period,
                                                materialsReady: self.materials.ready, specialsReady: self.specialSchedules.ready)
        }
    }

    func prepare(recoverInvalidMarker: Bool = false) async -> Bool {
        guard UIApplication.shared.isProtectedDataAvailable else { return false }
        guard !preparing else { return false }
        preparing = true
        defer { preparing = false }
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
            let retention = SchoolDataRetention(root: base)
            let period = SchoolDataPeriod.current()
            let installed: SchoolDataPeriod?
            do { installed = try retention.installedPeriod() }
            catch SchoolDataRetention.Failure.invalidMarker {
                guard recoverInvalidMarker else { throw SchoolDataRetention.Failure.invalidMarker }
                installed = nil
            }
            if installed != period {
                let hadPrivateData = SchoolDataRetention.privatePaths.contains {
                    FileManager.default.fileExists(atPath: base.appendingPathComponent($0).path)
                }
                ready = false
                guard await stopPrivateWork(resetNotifications: true) else {
                    retentionFailure = !Task.isCancelled
                    retentionFailureReason = retentionFailure ? .notificationCleanup(recoveringInvalidMarker:recoverInvalidMarker) : nil
                    loadedPeriod = nil
                    return false
                }
                try Task.checkCancellation()
                // Protected data can become unavailable while workers unwind.
                guard UIApplication.shared.isProtectedDataAvailable else { return false }
                if recoverInvalidMarker {
                    do { _ = try retention.installedPeriod() }
                    catch SchoolDataRetention.Failure.invalidMarker { try retention.quarantineInvalidMarker() }
                }
                try retention.replace(with: period)
                FileRefreshDiagnostics.shared.clear()
                materials.resumeAfterRetention()
                specialSchedules.resumeAfterRetention()
                retentionNotice = hadPrivateData
            }
            try retention.finishRecovery()
            materials.resumeAfterRetention()
            specialSchedules.resumeAfterRetention()
            if loadedPeriod != period { loadedPeriod = period }
            if retentionFailure { retentionFailure = false }
            if retentionFailureReason != nil { retentionFailureReason = nil }
            projections.resume()
            textMeasurements.resume()
            homeClock.allow()
            if !ready { ready = true }
            return true
        } catch {
            ready = false
            retentionFailure = !Task.isCancelled
            retentionFailureReason = error as? SchoolDataRetention.Failure
            loadedPeriod = nil
            _ = await stopPrivateWork()
            return false
        }
    }

    private func stopPrivateWork(resetNotifications: Bool = false) async -> Bool {
        projections.suspend()
        textMeasurements.suspend()
        homeClock.suspend()
        recovery.cancel()
        setFileMonitoring(false)
        let countdownCleared = await countdown.expirePrivateNotices(removeDelivered: resetNotifications)
        if resetNotifications {
            await notifications.resetForRetention()
        }
        else { await notifications.suspendForUnavailableData() }
        await account.stopForRetention()
        await materials.closeForRetention()
        await specialSchedules.closeForRetention()
        mappings.resetForRetention()
        links.resetForRetention()
        times.resetForRetention()
        return countdownCleared
    }

    func recoverRetention() async {
        guard canRecoverRetention, UIApplication.shared.isProtectedDataAvailable else { return }
        if await prepare(recoverInvalidMarker: true) { await activate() }
    }

    func activate() async {
        guard UIApplication.shared.applicationState != .background else { return }
        backgroundRefresh?.cancel()
        if let task = backgroundRefresh { await task.value }
        guard await prepare(), UIApplication.shared.applicationState != .background else { return }
        schoolEvents.setSourceChecksActive(true)
        materials.loadIfNeeded()
        specialSchedules.loadIfNeeded()
        schoolEvents.refreshAtStartup()
        updateCountdown()
        mappings.checkAtStartup()
        times.loadIfNeeded()
        if UIApplication.shared.applicationState != .background { setFileMonitoring(true) }
        if !account.busy {
            async let linkCheck: Void = links.refresh()
            async let timeCheck: Void = times.check()
            _ = await (linkCheck, timeCheck)
        }
        checkNotificationsWhenActive()
    }

    func setFileMonitoring(_ foreground: Bool) {
        schoolEvents.setSourceChecksActive(foreground)
        if foreground { homeClock.start() } else { homeClock.pause() }
        if !foreground { recovery.suspendForInactivity(); LocalRecoveryModelManager.shared.cancel() }
        materials.setFileMonitoring(foreground && ready)
        specialSchedules.setFileMonitoring(foreground && ready)
    }

    func refreshInBackground() async {
        guard backgroundRefresh == nil,
              UIApplication.shared.applicationState == .background,
              UIApplication.shared.isProtectedDataAvailable else { return }
        let task = Task { @MainActor in
            guard await self.prepare(), !Task.isCancelled else { return }
            self.setFileMonitoring(false)
            // The protected endpoints are never downloaded or authenticated
            // here; only their public revisions are checked.
            async let materials = self.materials.refreshInBackground()
            async let specials = self.specialSchedules.refreshInBackground()
            async let events = self.schoolEvents.refreshInBackground()
            async let revisions: Void = self.checkRevisionsInBackground()
            _ = await (materials, specials, events, revisions)
            if !Task.isCancelled, let period = self.loadedPeriod {
                self.updateCountdown()
                async let scheduleNotices: Void = self.notifications.reconcile(state: self.materials.state,
                    records: self.specialSchedules.records, sources: self.specialSchedules.sources, period: period,
                    materialsReady: self.materials.ready, specialsReady: self.specialSchedules.ready)
                await self.countdown.waitForNotificationReconciliation()
                await scheduleNotices
            }
        }
        backgroundRefresh = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: { task.cancel() }
        backgroundRefresh = nil
    }

    private func checkRevisionsInBackground() async {
        guard !account.busy else { return }
        guard !Task.isCancelled else { return }
        async let links: Void = self.links.refresh()
        async let mappings: Void = self.mappings.checkInBackground()
        async let times: Void = self.times.check()
        _ = await (links, mappings, times)
    }
}
