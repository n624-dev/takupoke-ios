import Foundation

enum PipelineWorkspace {
    final class Lease: @unchecked Sendable {
        private let lock = NSLock()
        private var roots: [URL] = []
        func create() throws -> URL {
            let root = try PipelineWorkspace.create()
            lock.lock(); roots.append(root); lock.unlock()
            return root
        }
        func removeAll() {
            lock.lock(); let owned = roots; roots.removeAll(); lock.unlock()
            owned.forEach(PipelineWorkspace.remove)
        }
    }
    private static let lock = NSLock()
    private static var prepared = false
    private static let processID = UUID().uuidString
    static func copyIfPresent(_ input: URL, to output: URL) throws {
        do { try FileManager.default.copyItem(at: input, to: output) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            // A missing private copy can be repaired by re-acquiring the selected original.
        }
    }
    static func create() throws -> URL {
        lock.lock(); let reclaim = !prepared; prepared = true; lock.unlock()
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("SchoolFileJobs", isDirectory: true)
        let process = base.appendingPathComponent(processID, isDirectory: true)
        // This process has its own namespace. Reclaim only previous processes,
        // without holding a shared lock across filesystem calls.
        if reclaim, FileManager.default.fileExists(atPath: base.path) {
            for old in try FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil) where old.lastPathComponent != processID {
                try FileManager.default.removeItem(at: old)
            }
        }
        let root = process.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        #if os(iOS)
        for directory in [base, process, root] {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        }
        #endif
        #if os(iOS) || os(macOS)
        var directory = base
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        #endif
        return root
    }
    static func remove(_ root: URL) { try? FileManager.default.removeItem(at: root) }
}
