import SwiftUI
import UIKit
import Combine

/// One owner for foreground and background work. Stores and serial import
/// workers are shared so a refresh cannot overwrite another instance's state.
@MainActor
final class ApplicationData: ObservableObject {
    static let shared = ApplicationData()

    let materials = MaterialsModel()
    let specialSchedules = SpecialSchedulesModel()
    let schoolEvents = SchoolEventsModel()
    let mappings = MappingModel()
    let links = LinksModel()
    let account = AccountDataModel()
    let notifications = ScheduleNotifications()

    @Published private(set) var ready = false
    @Published private(set) var loadedPeriod: SchoolDataPeriod?
    @Published private(set) var retentionFailure = false
    @Published var retentionNotice = false
    private var preparing = false
    private var backgroundRefresh: Task<Void, Never>?
    private var observations = Set<AnyCancellable>()

    init() {
        materials.$state.sink { [weak self] _ in self?.checkNotificationsWhenActive() }.store(in: &observations)
        specialSchedules.$records.sink { [weak self] _ in self?.checkNotificationsWhenActive() }.store(in: &observations)
        specialSchedules.$sources.sink { [weak self] _ in self?.checkNotificationsWhenActive() }.store(in: &observations)
    }

    private func checkNotificationsWhenActive() {
        Task { @MainActor [weak self] in
            guard let self, self.ready, UIApplication.shared.applicationState == .active,
                  let period = self.loadedPeriod else { return }
            await self.notifications.reconcile(state: self.materials.state, records: self.specialSchedules.records,
                                                sources: self.specialSchedules.sources, period: period)
        }
    }

    func prepare() async -> Bool {
        guard UIApplication.shared.isProtectedDataAvailable else { return false }
        guard !preparing else { return false }
        preparing = true
        defer { preparing = false }
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
            let retention = SchoolDataRetention(root: base)
            let period = SchoolDataPeriod.current()
            if try retention.installedPeriod() != period {
                let hadPrivateData = SchoolDataRetention.privatePaths.contains {
                    FileManager.default.fileExists(atPath: base.appendingPathComponent($0).path)
                }
                ready = false
                setFileMonitoring(false)
                await notifications.resetForRetention()
                await account.stopForRetention()
                await materials.closeForRetention()
                await specialSchedules.closeForRetention()
                mappings.resetForRetention()
                links.resetForRetention()
                try Task.checkCancellation()
                // Protected data can become unavailable while workers unwind.
                guard UIApplication.shared.isProtectedDataAvailable else { return false }
                try retention.replace(with: period)
                FileRefreshDiagnostics.shared.clear()
                materials.resumeAfterRetention()
                specialSchedules.resumeAfterRetention()
                retentionNotice = hadPrivateData
            }
            loadedPeriod = period
            retentionFailure = false
            ready = true
            return true
        } catch {
            ready = false
            retentionFailure = !Task.isCancelled
            return false
        }
    }

    func activate() async {
        guard UIApplication.shared.applicationState != .background else { return }
        backgroundRefresh?.cancel()
        if let task = backgroundRefresh { await task.value }
        guard await prepare() else { return }
        materials.loadIfNeeded()
        specialSchedules.loadIfNeeded()
        schoolEvents.refreshAtStartup()
        mappings.checkAtStartup()
        if UIApplication.shared.applicationState != .background { setFileMonitoring(true) }
        if !account.busy { await links.refresh() }
        checkNotificationsWhenActive()
    }

    func setFileMonitoring(_ foreground: Bool) {
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
                await self.notifications.reconcile(state: self.materials.state, records: self.specialSchedules.records,
                                                    sources: self.specialSchedules.sources, period: period)
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
        _ = await (links, mappings)
    }
}
