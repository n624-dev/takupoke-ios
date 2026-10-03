import Foundation
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

struct RecoveryModelManifest: Codable, Equatable, Sendable {
    var modelId: String; var version: String; var url: String; var size: Int64; var sha256: String
    var runtime: String; var minimumOs: String; var minimumMemory: Int64; var recommendedBackend: String
    var license: String; var validated: Bool
    func isUsable(runtime requested: String, availableMemory: Int64) -> Bool {
        guard validated, ["coreAI", "llamaCpp", "liteRtLm", "foundryLocal"].contains(requested), runtime == requested,
              minimumMemory > 0, availableMemory >= minimumMemory, size > 0, size <= 8 * 1024 * 1024 * 1024,
              modelId.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,80}$", options: .regularExpression) != nil,
              version.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,80}$", options: .regularExpression) != nil,
              sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
              let address = URL(string: url), address.scheme == "https", address.host != nil, address.user == nil, address.password == nil else { return false }
        guard minimumOs.range(of: "^[0-9]{1,6}(?:\\.[0-9]{1,6}){0,3}$", options: .regularExpression) != nil,
              (runtime == "coreAI" ? ["CPU", "GPU", "ANE"] : runtime == "llamaCpp" ? ["CPU", "Metal"] : ["CPU", "GPU", "NPU"]).contains(recommendedBackend) else { return false }
        return [minimumOs, recommendedBackend, license].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    func supportsOs(_ current: String) -> Bool {
        let needed = minimumOs.split(separator: ".").compactMap { Int($0) }, actual = current.split(separator: ".").compactMap { Int($0) }
        guard current.range(of: "^[0-9]{1,6}(?:\\.[0-9]{1,6}){0,3}$", options: .regularExpression) != nil, minimumOs.range(of: "^[0-9]{1,6}(?:\\.[0-9]{1,6}){0,3}$", options: .regularExpression) != nil, !needed.isEmpty, !actual.isEmpty, needed.count <= 4, actual.count <= 4 else { return false }
        for index in 0..<4 { let a = actual.indices.contains(index) ? actual[index] : 0, b = needed.indices.contains(index) ? needed[index] : 0; if a != b { return a > b } }
        return true
    }
}

#if canImport(CryptoKit) || canImport(Crypto)
/// Called only after the user requests model installation while the app is in the foreground.
/// The input callback receives a model URL and cannot receive school data through this API.
actor RecoveryModelStore {
    enum Failure: Error { case unavailable, invalidModel }
    private let root: URL
    private var installing = false
    init(root: URL) { self.root = root }
    func install(_ manifest: RecoveryModelManifest, runtime: String, availableMemory: Int64,
                 osSupported: Bool, foreground: Bool, openModel: (URL) throws -> InputStream,
                 prepareAndSmokeTest: (URL) async throws -> Void, check: () throws -> Void) async throws -> URL {
        guard !installing, foreground, osSupported, manifest.isUsable(runtime: runtime, availableMemory: availableMemory),
              let address = URL(string: manifest.url) else { throw Failure.unavailable }
        installing = true
        defer { installing = false }
        func alive() throws { try check(); try Task.checkCancellation() }
        try alive()
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appendingPathComponent("staging-" + UUID().uuidString)
        let target = root.appendingPathComponent(runtime + "-" + manifest.modelId + "-" + manifest.version + "-" + manifest.sha256 + ".model")
        let bundle = target.appendingPathExtension("bundle"), stagedBundle = staging.appendingPathExtension("bundle")
        let pointer = root.appendingPathComponent("active." + runtime + ".json")
        let previous = manager.fileExists(atPath: pointer.path) ? try JSONDecoder().decode(RecoveryModelManifest.self, from: Data(contentsOf: pointer)) : nil
        guard previous?.isUsable(runtime: runtime, availableMemory: Int64.max) != false else { throw Failure.invalidModel }
        var ownsTarget = false, committed = false
        defer {
            try? manager.removeItem(at: staging)
            try? manager.removeItem(at: stagedBundle)
            if ownsTarget && !committed { try? manager.removeItem(at: target); try? manager.removeItem(at: bundle) }
        }
        func verify(_ input: InputStream, output: FileHandle? = nil) throws {
            input.open(); defer { input.close() }
            var hash = SHA256(); var total: Int64 = 0; var buffer = [UInt8](repeating: 0, count: 65536)
            while true {
                try alive(); let count = input.read(&buffer, maxLength: buffer.count)
                if count == 0 { break }; guard count > 0 else { throw Failure.invalidModel }
                total += Int64(count); guard total <= manifest.size else { throw Failure.invalidModel }
                let data = Data(buffer.prefix(count)); hash.update(data: data); try output?.write(contentsOf: data)
            }
            guard total == manifest.size, hash.finalize().map({ String(format: "%02x", $0) }).joined() == manifest.sha256 else { throw Failure.invalidModel }
        }
        if !manager.fileExists(atPath: target.path) {
            guard manager.createFile(atPath: staging.path, contents: nil) else { throw Failure.invalidModel }
            let output = try FileHandle(forWritingTo: staging)
            do { try verify(openModel(address), output: output); try output.synchronize(); try output.close() }
            catch { try? output.close(); throw error }
            try await prepareAndSmokeTest(staging); try alive()
            if runtime == "coreAI" { guard manager.fileExists(atPath:stagedBundle.path), !manager.fileExists(atPath:bundle.path) else { throw Failure.invalidModel } }
            try manager.moveItem(at: staging, to: target); ownsTarget = true
            if runtime == "coreAI" { try manager.moveItem(at:stagedBundle,to:bundle) }
        } else {
            guard let input = InputStream(url: target) else { throw Failure.invalidModel }
            try verify(input); try await prepareAndSmokeTest(target)
        }
        try alive()
        try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("active." + runtime + ".json"), options: .atomic)
        committed = true
        if let previous {
            let old = root.appendingPathComponent(runtime + "-" + previous.modelId + "-" + previous.version + "-" + previous.sha256 + ".model")
            if old != target { try? manager.removeItem(at: old); try? manager.removeItem(at:old.appendingPathExtension("bundle")) }
        }
        return runtime == "coreAI" ? bundle : target
    }
    /// Invoke once before creating providers. Only this store's owned names are collected;
    /// active and explicitly leased models are retained. A corrupt pointer aborts cleanup.
    func cleanupAbandonedFiles(inUse: Set<URL>) throws {
        guard !installing else { throw Failure.unavailable }
        let manager = FileManager.default
        guard manager.fileExists(atPath: root.path) else { return }
        var protected = Set(inUse.map { $0.standardizedFileURL.path })
        for runtime in ["coreAI", "llamaCpp", "liteRtLm", "foundryLocal"] {
            let pointer = root.appendingPathComponent("active." + runtime + ".json")
            if manager.fileExists(atPath: pointer.path) {
                let m = try JSONDecoder().decode(RecoveryModelManifest.self, from: Data(contentsOf: pointer))
                guard m.isUsable(runtime: runtime, availableMemory: Int64.max) else { throw Failure.invalidModel }
                let active = root.appendingPathComponent(runtime + "-" + m.modelId + "-" + m.version + "-" + m.sha256 + ".model").standardizedFileURL
                protected.insert(active.path); if runtime == "coreAI" { protected.insert(active.appendingPathExtension("bundle").path) }
            }
        }
        for url in try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            let name = url.lastPathComponent
            let owned = name.range(of: "^staging-[0-9A-Fa-f-]{36}(?:\\.bundle)?$", options: .regularExpression) != nil || name.range(of: "^(?:coreAI|llamaCpp|liteRtLm|foundryLocal)-[A-Za-z0-9._-]{1,81}-[A-Za-z0-9._-]{1,81}-[a-f0-9]{64}\\.model(?:\\.bundle)?$", options: .regularExpression) != nil
            if owned && (values.isRegularFile == true || name.hasSuffix(".bundle")) && values.isSymbolicLink != true && !protected.contains(url.standardizedFileURL.path) { try manager.removeItem(at: url) }
        }
    }

    /// Management must retain the durable identity even when model files need
    /// repair, so a partial deletion can still be retried after a restart.
    func storedManifest(runtime: String) throws -> RecoveryModelManifest? {
        guard ["coreAI", "llamaCpp", "liteRtLm", "foundryLocal"].contains(runtime) else { throw Failure.unavailable }
        let pointer = root.appendingPathComponent("active."+runtime+".json")
        guard FileManager.default.fileExists(atPath:pointer.path) else { return nil }
        let manifest = try JSONDecoder().decode(RecoveryModelManifest.self,from:Data(contentsOf:pointer))
        guard manifest.isUsable(runtime:runtime,availableMemory:Int64.max) else { throw Failure.invalidModel }
        return manifest
    }
    func active(runtime: String) throws -> (RecoveryModelManifest, URL)? {
        guard ["coreAI", "llamaCpp"].contains(runtime) else { throw Failure.unavailable }
        guard let m = try storedManifest(runtime:runtime) else { return nil }
        let url = root.appendingPathComponent(runtime+"-"+m.modelId+"-"+m.version+"-"+m.sha256+".model")
        guard let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize, Int64(size) == m.size else { throw Failure.invalidModel }
        if runtime == "coreAI" {
            let bundle = url.appendingPathExtension("bundle")
            guard FileManager.default.fileExists(atPath:bundle.appendingPathComponent("metadata.json").path), FileManager.default.fileExists(atPath:bundle.appendingPathComponent("tokenizer/tokenizer.json").path) else { throw Failure.invalidModel }
            return (m,bundle)
        }
        return (m,url)
    }
    func delete(runtime: String, removeItem: @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at:$0) }) throws {
        guard !installing, ["coreAI", "llamaCpp", "liteRtLm", "foundryLocal"].contains(runtime) else { throw Failure.unavailable }
        let manager = FileManager.default; let pointer = root.appendingPathComponent("active." + runtime + ".json")
        guard manager.fileExists(atPath: pointer.path) else { return }
        let manifest = try JSONDecoder().decode(RecoveryModelManifest.self, from: Data(contentsOf: pointer))
        guard manifest.isUsable(runtime: runtime, availableMemory: Int64.max) else { throw Failure.invalidModel }
        let target = root.appendingPathComponent(runtime + "-" + manifest.modelId + "-" + manifest.version + "-" + manifest.sha256 + ".model")
        let bundle = target.appendingPathExtension("bundle")
        if manager.fileExists(atPath:bundle.path) { try removeItem(bundle) }
        if manager.fileExists(atPath:target.path) { try removeItem(target) }
        // Keep the durable model identity while any owned removal can still fail.
        // A retry can remove the remaining files even after a partial I/O failure.
        try removeItem(pointer)
    }
}
#endif
