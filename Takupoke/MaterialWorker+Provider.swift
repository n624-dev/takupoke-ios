import Foundation

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

    private func coordinated<T>(_ url: URL, kind: MaterialKind, control: AcquisitionControl,
                                read: (URL) throws -> T) throws -> (value: T, receipt: SelectedFilePresenter.ReadReceipt) {
        try control.check()
        let access = SelectedFilePresenter.readAccess(for: url, source: .init(rawValue: kind.rawValue))
        let coordinator = access.coordinator
        control.attach(coordinator)
        defer { control.attach(nil) }
        var coordinationError: NSError?
        var result: Result<(value: T, receipt: SelectedFilePresenter.ReadReceipt), Error>?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { safeURL in
            result = Result {
                try access.read(at: safeURL) {
                    try control.check()
                    let value = try read(safeURL)
                    try control.check()
                    return value
                }
            }
        }
        try control.check()
        if let error = coordinationError { throw error }
        guard let result = result else { throw MaterialError.unavailable }
        return try result.get()
    }

    func copyProviderFile(_ url: URL, to staged: URL, kind: MaterialKind,
                          control: AcquisitionControl) throws -> (count: Int, digest: String, modified: Date?, receipt: SelectedFilePresenter.ReadReceipt) {
        do {
            let read = try coordinated(url, kind: kind, control: control) { file in
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { throw MaterialError.invalidFile }
                let result = try readMaterial(file, copyingTo: staged, kind: kind, control: control)
                return (result.0, result.1, values.contentModificationDate)
            }
            return (read.value.0, read.value.1, read.value.2, read.receipt)
        } catch {
            throw (error as? MaterialError) ?? MaterialError.providerReadFailed
        }
    }

    func readMaterial(_ file: URL, copyingTo staged: URL?, kind: MaterialKind,
                              control: AcquisitionControl) throws -> (Int, String) {
        let receipt = try MaterialFileReader.copy(file, to: staged, isWorkbook: kind == .changes,
                                                  check: control.check)
        return (receipt.count, receipt.digest)
    }
}
