#if canImport(CCoreAIRecovery)
import Foundation
import CCoreAIRecovery
#if canImport(CLlamaRecovery)
import CLlamaRecovery
#endif

private enum CoreAIRuntimeError: Error { case unavailable }

private final class CoreAIRecoveryHandle: @unchecked Sendable {
    let pointer: UnsafeMutableRawPointer
    init(runtimeURL: URL) throws {
        guard let pointer = tk_coreai_create(runtimeURL.path) else { throw RecoveryProviderError.invalidOutput }
        self.pointer = pointer
    }
    func cancel() { tk_coreai_cancel(pointer) }
    deinit { tk_coreai_release(pointer) }
    func load(_ modelURL: URL) async throws {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                tk_coreai_load(pointer, modelURL.path) { error in
                    if let error { continuation.resume(throwing: error.code == 1 ? CancellationError() : CoreAIRuntimeError.unavailable) }
                    else { continuation.resume() }
                }
            }
            try Task.checkCancellation()
        } onCancel: { self.cancel() }
    }
    func recover(_ prompt: String) async throws -> Data {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                tk_coreai_recover(pointer, prompt) { output, error in
                    if let error {
                        let failure: Error = error.code == 1 ? CancellationError() : error.code == 3 ? RecoveryProviderError.invalidOutput : CoreAIRuntimeError.unavailable
                        continuation.resume(throwing: failure)
                    }
                    else if let output, let data = output.data(using: .utf8), data.count <= 16384 { continuation.resume(returning: data) }
                    else { continuation.resume(throwing: RecoveryProviderError.invalidOutput) }
                }
            }
        } onCancel: { self.cancel() }
    }
}

actor CoreAIRecoveryProvider: LocalRecoveryProvider {
    nonisolated let id = "coreAI"
    nonisolated let localOnly = true
    nonisolated let metadata: RecoveryMetadata
    private let manifest: RecoveryModelManifest
    private let bundleURL: URL
    private var handle: CoreAIRecoveryHandle?
    private var loaded = false
    nonisolated static var runtimeURL: URL {
        (Bundle.main.privateFrameworksURL ?? Bundle.main.bundleURL.appendingPathComponent("Frameworks"))
            .appendingPathComponent("CoreAIRecoveryRuntime.framework/CoreAIRecoveryRuntime")
    }
    init(bundleURL: URL, manifest: RecoveryModelManifest) {
        self.manifest = manifest; self.bundleURL = bundleURL
        metadata = RecoveryMetadata(provider: "coreAI", modelId: manifest.modelId, modelVersion: manifest.version,
            runtimeVersion: "CoreAI:coreai-models:52c84ba874b2c57adcede08a671ce96ed1b3f433", promptVersion: "2",
            recoverySchemaVersion: RecoveryValidator.schemaVersion, validatorVersion: RecoveryValidator.version,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString)
    }
    func availability() async throws -> LocalProviderState {
        try Task.checkCancellation()
        let os = ProcessInfo.processInfo.operatingSystemVersion
        guard os.majorVersion >= 27, FileManager.default.fileExists(atPath: Self.runtimeURL.path) else { return .unsupported }
        guard manifest.validated, manifest.runtime == id else { return .downloadRequired }
        #if canImport(CLlamaRecovery)
        let memory = Int64(clamping: tk_llama_available_memory())
        #else
        let memory: Int64 = 0
        #endif
        guard manifest.isUsable(runtime: id, availableMemory: memory) else { return .insufficientMemory }
        guard manifest.supportsOs("\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)") else { return .unsupported }
        guard FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("metadata.json").path),
              FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("tokenizer/tokenizer.json").path) else { return .downloadRequired }
        if handle == nil {
            guard let created = try? CoreAIRecoveryHandle(runtimeURL: Self.runtimeURL) else { return .unsupported }
            handle = created
        }
        return .ready
    }
    func recoverCell(_ cell: RecoveryPromptCell) async throws -> [RecoveryLesson] {
        guard try await availability() == .ready else { throw RecoveryProviderError.invalidOutput }
        do {
            let current: CoreAIRecoveryHandle
            if let handle { current = handle }
            else { current = try CoreAIRecoveryHandle(runtimeURL: Self.runtimeURL); handle = current }
            if !loaded { try await current.load(bundleURL); loaded = true }
            let prompt = String(decoding: try JSONEncoder().encode(cell), as: UTF8.self)
            guard prompt.utf8.count <= 8192 else { throw RecoveryProviderError.invalidOutput }
            let data = try await current.recover(prompt); try Task.checkCancellation()
            struct Output: Decodable { var lessons: [Lesson] }
            struct Lesson: Decodable { var subject: RecoveryField; var teacher: RecoveryField; var room: RecoveryField }
            guard let value = try? JSONDecoder().decode(Output.self, from: data), value.lessons.count == cell.parallelCount else { throw RecoveryProviderError.invalidOutput }
            return value.lessons.map { RecoveryLesson(subject: $0.subject, teacher: $0.teacher, room: $0.room, dateEvidence: [], periodEvidence: []) }
        } catch { handle = nil; loaded = false; throw error }
    }
    nonisolated static func smokeTest(bundleURL: URL) async throws {
        let current = try CoreAIRecoveryHandle(runtimeURL: runtimeURL)
        try await current.load(bundleURL)
        let data = try await current.recover("{\"cellId\":\"synthetic-smoke\",\"parallelCount\":1,\"sources\":[{\"id\":\"s\",\"text\":\"Subject: Fictional A\"}],\"blankFields\":[\"teacher\",\"room\"]}")
        try Task.checkCancellation()
        guard (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { throw RecoveryProviderError.invalidOutput }
    }
}
#endif
