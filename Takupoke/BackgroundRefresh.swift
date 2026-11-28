import BackgroundTasks
import Foundation

struct BackgroundRefreshDiagnostics: Codable, Equatable {
    enum Reservation: String, Codable {
        case scheduled, unavailable, notPermitted, pendingLimit, otherFailure
    }

    var reservation: Reservation?
    var lastAttemptAt: Date?
    var lastScheduledAt: Date?
    var lastExecutionAt: Date?
}

@MainActor enum BackgroundRefresh {
    static let identifier = "io.github.n624dev.takupoke.refresh"
    private static let diagnosticsKey = "backgroundRefreshDiagnostics"

    static func schedule() {
        schedule(at: Date(), defaults: .standard) { try BGTaskScheduler.shared.submit($0) }
    }

    static func schedule(at date: Date, defaults: UserDefaults,
                         submit: (BGAppRefreshTaskRequest) throws -> Void) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = date.addingTimeInterval(60 * 60)
        var state = diagnostics(defaults: defaults)
        state.lastAttemptAt = date
        do {
            // The scheduler replaces an unexecuted request for the same identifier.
            try submit(request)
            state.reservation = .scheduled
            state.lastScheduledAt = date
        } catch {
            switch (error as? BGTaskScheduler.Error)?.code {
            case .unavailable: state.reservation = .unavailable
            case .notPermitted: state.reservation = .notPermitted
            case .tooManyPendingTaskRequests: state.reservation = .pendingLimit
            default: state.reservation = .otherFailure
            }
        }
        save(state, defaults: defaults)
    }

    static func recordExecution(at date: Date = Date(), defaults: UserDefaults = .standard) {
        var state = diagnostics(defaults: defaults)
        state.lastExecutionAt = date
        save(state, defaults: defaults)
    }

    static func diagnostics(defaults: UserDefaults = .standard) -> BackgroundRefreshDiagnostics {
        defaults.data(forKey: diagnosticsKey)
            .flatMap { try? PropertyListDecoder().decode(BackgroundRefreshDiagnostics.self, from: $0) }
            ?? BackgroundRefreshDiagnostics()
    }

    private static func save(_ state: BackgroundRefreshDiagnostics, defaults: UserDefaults) {
        guard let data = try? PropertyListEncoder().encode(state) else { return }
        defaults.set(data, forKey: diagnosticsKey)
    }
}
