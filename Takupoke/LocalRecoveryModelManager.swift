import Foundation
import SwiftUI
import UIKit
import ZIPFoundation

/// Only application-reviewed manifests are eligible for download. This API
/// accepts model bytes and never accepts PDFs, prompts, or school information.
@MainActor
final class LocalRecoveryModelManager: ObservableObject {
    static let shared = LocalRecoveryModelManager()
    @Published private(set) var installed: [String:RecoveryModelManifest] = [:]
    @Published private(set) var busy = false
    @Published private(set) var isInUse = false
    @Published private(set) var message: String?
    private var leases = Set<UUID>()
    private var task: Task<Void,Never>?
    private var control: AcquisitionControl?
    // Candidate quality measurements must pass before a release adds a model
    // here. Never download an unreviewed "latest" model from a remote catalog.
    let catalog: [RecoveryModelManifest] = []
    private var root: URL {
        FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("LocalRecoveryModels",isDirectory:true)
    }
    private var store: RecoveryModelStore { RecoveryModelStore(root:root) }
    func refresh() async {
        guard !busy, leases.isEmpty else { return }
        do {
            let store = self.store; try await store.cleanupAbandonedFiles(inUse:[])
            var next = [String:RecoveryModelManifest]()
            for runtime in ["coreAI","llamaCpp"] { if let (manifest,_) = try await store.active(runtime:runtime) { next[runtime] = manifest } }
            installed = next
        } catch { message = "保存済みAIモデルを確認できませんでした。" }
    }
    func providers(lease: UUID) async -> [any LocalRecoveryProvider] {
        guard !busy else { return [] }
        leases.insert(lease); isInUse = true
        var providers = [any LocalRecoveryProvider]()
        #if canImport(CLlamaRecovery)
        if let (m,url) = try? await store.active(runtime:"llamaCpp") { providers.append(LocalLlamaRecoveryProvider(modelURL:url,manifest:m)) }
        #endif
        #if canImport(CCoreAIRecovery)
        if let (m,url) = try? await store.active(runtime:"coreAI") { providers.append(CoreAIRecoveryProvider(bundleURL:url,manifest:m)) }
        #endif
        return providers
    }
    func release(lease: UUID) { leases.remove(lease); isInUse = !leases.isEmpty }
    func install(_ manifest: RecoveryModelManifest) {
        guard !busy, leases.isEmpty, catalog.contains(manifest), manifest.validated,
              UIApplication.shared.applicationState == .active else { return }
        let control = AcquisitionControl(); self.control = control; busy = true; message = "AIモデルをダウンロードしています⋯"
        task = Task { @MainActor in
            var local: URL?
            defer { if let local { try? FileManager.default.removeItem(at:local) }; busy = false; self.control = nil; task = nil }
            do {
                guard let address = URL(string:manifest.url) else { throw RecoveryModelStore.Failure.invalidModel }
                let config = URLSessionConfiguration.ephemeral; config.httpCookieStorage = nil; config.urlCache = nil
                let session = URLSession(configuration:config); defer { session.invalidateAndCancel() }
                let (temporary,response) = try await session.download(from:address)
                defer { try? FileManager.default.removeItem(at:temporary) }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200, (http.expectedContentLength == -1 || http.expectedContentLength == manifest.size) else { throw RecoveryModelStore.Failure.invalidModel }
                try control.check(); try Task.checkCancellation()
                guard UIApplication.shared.applicationState == .active else { throw CancellationError() }
                let major = ProcessInfo.processInfo.operatingSystemVersion
                let memory = Int64(ProcessInfo.processInfo.physicalMemory)
                _ = try await store.install(manifest,runtime:manifest.runtime,availableMemory:memory,osSupported:manifest.supportsOs("\(major.majorVersion).\(major.minorVersion).\(major.patchVersion)"),foreground:true,openModel:{ _ in
                    guard let stream = InputStream(url:temporary) else { throw RecoveryModelStore.Failure.invalidModel }; return stream
                },prepareAndSmokeTest:{ url in
                    if manifest.runtime == "coreAI" {
                        #if canImport(CCoreAIRecovery)
                        let bundle = url.appendingPathExtension("bundle")
                        if !FileManager.default.fileExists(atPath:bundle.path) {
                            try await Task.detached(priority:.userInitiated) { try Self.prepareCoreAI(archive:url,bundle:bundle,check:{ try control.check() }) }.value
                        }
                        try await CoreAIRecoveryProvider.smokeTest(bundleURL:bundle)
                        #else
                        throw RecoveryModelStore.Failure.unavailable
                        #endif
                    } else if manifest.runtime == "llamaCpp" {
                        #if canImport(CLlamaRecovery)
                        try await Task.detached(priority:.userInitiated) { try LocalLlamaRecoveryProvider.smokeTest(url:url) }.value
                        #else
                        throw RecoveryModelStore.Failure.unavailable
                        #endif
                    } else { throw RecoveryModelStore.Failure.unavailable }
                },check:{ try control.check(); try Task.checkCancellation() })
                message = "AIモデルを準備しました。"; installed[manifest.runtime] = manifest
            } catch { message = "AIモデルを準備できませんでした。前のモデルを保持しています。" }
        }
    }
    private nonisolated static func prepareCoreAI(archive url: URL,bundle: URL,check: () throws -> Void) throws {
        let archive = try Archive(url:url,accessMode:.read)
        let manager = FileManager.default
        var total: Int64 = 0, count = 0, succeeded = false
        defer { if !succeeded { try? manager.removeItem(at:bundle) } }
        try manager.createDirectory(at:bundle,withIntermediateDirectories:true)
        for entry in archive {
            try check(); try Task.checkCancellation(); count += 1
            let parts = entry.path.split(separator:"/",omittingEmptySubsequences:false)
            guard count <= 10000, !entry.path.hasPrefix("/"), !entry.path.contains("\\"), !parts.contains(".."), !parts.contains("."), entry.type == .file || entry.type == .directory else { throw RecoveryModelStore.Failure.invalidModel }
            guard let size = Int64(exactly:entry.uncompressedSize), size <= 8*1024*1024*1024-total else { throw RecoveryModelStore.Failure.invalidModel }
            total += size
            guard total <= 8*1024*1024*1024 else { throw RecoveryModelStore.Failure.invalidModel }
            let target = bundle.appendingPathComponent(entry.path)
            guard target.standardizedFileURL.path.hasPrefix(bundle.standardizedFileURL.path+"/") else { throw RecoveryModelStore.Failure.invalidModel }
            if entry.type == .directory { try manager.createDirectory(at:target,withIntermediateDirectories:true) }
            else {
                try manager.createDirectory(at:target.deletingLastPathComponent(),withIntermediateDirectories:true)
                guard !manager.fileExists(atPath:target.path), manager.createFile(atPath:target.path,contents:nil) else { throw RecoveryModelStore.Failure.invalidModel }
                let output = try FileHandle(forWritingTo:target)
                defer { try? output.close() }
                var written: Int64 = 0
                let checksum = try archive.extract(entry,bufferSize:65536,skipCRC32:false) { bytes in
                    try check(); try Task.checkCancellation(); written += Int64(bytes.count)
                    guard written <= size else { throw RecoveryModelStore.Failure.invalidModel }
                    try output.write(contentsOf:bytes)
                }
                guard written == size, checksum == entry.checksum else { throw RecoveryModelStore.Failure.invalidModel }
                try output.synchronize()
            }
        }
        guard manager.fileExists(atPath:bundle.appendingPathComponent("metadata.json").path), manager.fileExists(atPath:bundle.appendingPathComponent("tokenizer/tokenizer.json").path) else { throw RecoveryModelStore.Failure.invalidModel }
        succeeded = true
    }
    func delete(_ runtime: String) {
        guard !busy, leases.isEmpty else { return }; busy = true
        task = Task { @MainActor in
            defer { busy = false; task = nil }
            do { try await store.delete(runtime:runtime); installed[runtime] = nil; message = "AIモデルを削除しました。" }
            catch { message = "AIモデルを削除できませんでした。" }
        }
    }
    func cancel() { control?.cancel(); task?.cancel() }
}
