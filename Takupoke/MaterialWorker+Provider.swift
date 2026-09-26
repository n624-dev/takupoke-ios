import Foundation
import CryptoKit

extension MaterialWorker {
    func grant(for url: URL) throws -> SourceGrant {
        // Called while the original selection is still scoped, after reading.
        do {
            return SourceGrant(bookmark: try url.bookmarkData(options: .minimalBookmark,
                               includingResourceValuesForKeys: nil, relativeTo: nil),
                               name: url.lastPathComponent, isFolder: false)
        } catch { throw MaterialError.bookmarkFailed }
    }

    func withAccess<T>(_ grant: SourceGrant, body: (URL) throws -> T) throws -> T {
        var stale = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: grant.bookmark, options: [], relativeTo: nil,
                          bookmarkDataIsStale: &stale)
        } catch { throw MaterialError.accessExpired }
        let selection = ScopedMaterialSelection(url)
        guard !stale else { throw MaterialError.accessExpired }
        return try selection.access(body)
    }

    private func coordinated<T>(_ url: URL, control: AcquisitionControl,
                                read: (URL) throws -> T) throws -> T {
        try control.check()
        let coordinator = SelectedFilePresenter.coordinator(for: url)
        control.attach(coordinator)
        defer { control.attach(nil) }
        var coordinationError: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { safeURL in
            result = Result { try control.check(); return try read(safeURL) }
        }
        try control.check()
        if let error = coordinationError { throw error }
        guard let result = result else { throw MaterialError.unavailable }
        return try result.get()
    }

    func copyProviderFile(_ url: URL, to staged: URL, kind: MaterialKind,
                                  control: AcquisitionControl) throws -> (Int, String, Date?) {
        do {
            return try coordinated(url, control: control) { file in
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { throw MaterialError.invalidFile }
                let result = try readMaterial(file, copyingTo: staged, kind: kind, control: control)
                return (result.0, result.1, values.contentModificationDate)
            }
        } catch {
            throw (error as? MaterialError) ?? MaterialError.providerReadFailed
        }
    }

    func readMaterial(_ file: URL, copyingTo staged: URL?, kind: MaterialKind,
                              control: AcquisitionControl) throws -> (Int, String) {
        let input = try FileHandle(forReadingFrom: file)
        defer { try? input.close() }
        var output: FileHandle?
        if let staged = staged {
            guard FileManager.default.createFile(atPath: staged.path, contents: nil) else { throw MaterialError.unavailable }
            output = try FileHandle(forWritingTo: staged)
        }
        defer { try? output?.close() }
        var hasher = SHA256()
        var count = 0
        var header = Data()
        while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
            try control.check()
            count += chunk.count
            guard count <= MaterialLibrary.maximumBytes else { throw MaterialError.tooLarge }
            if header.count < 8 { header.append(chunk.prefix(8 - header.count)) }
            hasher.update(data: chunk)
            try output?.write(contentsOf: chunk)
        }
        guard count > 0 else { throw MaterialError.invalidFile }
        if kind == .changes {
            guard header.starts(with: [0x50, 0x4b, 0x03, 0x04]) else { throw MaterialError.invalidFile }
        } else {
            guard header.starts(with: Array("%PDF-".utf8)) else { throw MaterialError.invalidFile }
        }
        try output?.synchronize()
        return (count, hasher.finalize().map { String(format: "%02x", $0) }.joined())
    }
}
