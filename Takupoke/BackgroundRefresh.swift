import BackgroundTasks
import Foundation

enum BackgroundRefresh {
    static let identifier = "io.github.n624dev.takupoke.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        // Replace our pending request rather than accumulate duplicates.
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        try? BGTaskScheduler.shared.submit(request)
    }
}
