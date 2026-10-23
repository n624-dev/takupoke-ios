import Foundation

// Await the owned detached worker through the caller's cancellation lifetime.
enum CancellationLinkedTask {
    static func value<Result>(of worker: Task<Result, Error>) async throws -> Result {
        try await withTaskCancellationHandler(operation: { try await worker.value },
                                              onCancel: { worker.cancel() })
    }
}
