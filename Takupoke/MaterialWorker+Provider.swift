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

    func withAccess<T>(_ grant: SourceGrant, body: (MaterialBookmarkResolution) throws -> T) throws -> T {
        let reference = try MaterialBookmarkResolution.resolve(grant.bookmark)
        return try ScopedMaterialSelection(reference.url).access { _ in try body(reference) }
    }

    func copyProviderFile(_ url: URL, to staged: URL, kind: MaterialKind,
                          control: AcquisitionControl) throws -> (count: Int, digest: String, modified: Date?, receipt: SelectedFilePresenter.ReadReceipt) {
        do {
            let copy = try control.provider.copy(url, to: staged, source: .init(rawValue: kind.rawValue), workbook: kind == .changes, control: control)
            return (copy.count, copy.digest, copy.modifiedAt, copy.receipt)
        } catch { try control.check(); throw (error as? MaterialError) ?? MaterialError.providerReadFailed }
    }

    func readMaterial(_ file: URL, copyingTo staged: URL?, kind: MaterialKind,
                              control: AcquisitionControl) throws -> (Int, String) {
        let receipt = try MaterialFileReader.copy(file, to: staged, isWorkbook: kind == .changes,
                                                  check: control.check, progress: { control.pipelineTicket?.progress() }, digesting: { control.pipelineTicket?.enter(.checkingDigest) })
        return (receipt.count, receipt.digest)
    }
}
