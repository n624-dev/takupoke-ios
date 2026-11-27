import Foundation

/// Holds the exact local original chosen for a PDF viewer until it closes.
/// School-data retention still clears the old-period directory when access is revoked.
final class SavedPDFLease: Identifiable {
    private struct Entry {
        var readers: Int
        var retired = false
    }

    private static let lock = NSLock()
    private static var entries: [URL: Entry] = [:]
    let url: URL

    private init(url: URL) { self.url = url }

    static func open(_ url: URL) -> SavedPDFLease? {
        guard url.isFileURL else { return nil }
        let file = url.standardizedFileURL
        return lock.withLock {
            guard entries[file]?.retired != true, FileManager.default.fileExists(atPath: file.path) else { return nil }
            entries[file, default: Entry(readers: 0)].readers += 1
            return SavedPDFLease(url: file)
        }
    }

    static func retire(_ url: URL) throws {
        let file = url.standardizedFileURL
        try lock.withLock {
            if entries[file] != nil { entries[file]?.retired = true }
            else { try remove(file) }
        }
    }

    private static func remove(_ url: URL) throws {
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile { }
    }

    deinit {
        Self.lock.withLock {
            guard var entry = Self.entries[url] else { return }
            entry.readers -= 1
            if entry.readers > 0 { Self.entries[url] = entry }
            else {
                Self.entries.removeValue(forKey: url)
                if entry.retired { try? Self.remove(url) }
            }
        }
    }
}
