#if canImport(Darwin)
import Foundation

struct SelectedFileCopy {
    let count: Int
    let digest: String
    let modifiedAt: Date?
    let receipt: SelectedFilePresenter.ReadReceipt
}
protocol SelectedFileProviding {
    func copy(_ url: URL, to staged: URL, source: FileRefreshDiagnostics.Source?, workbook: Bool,
              control: AcquisitionControl) throws -> SelectedFileCopy
}
struct SystemSelectedFileProvider: SelectedFileProviding {
    func copy(_ url: URL, to staged: URL, source: FileRefreshDiagnostics.Source?, workbook: Bool,
              control: AcquisitionControl) throws -> SelectedFileCopy {
        control.pipelineTicket?.enter(.access)
        try control.check()
        let access = SelectedFilePresenter.readAccess(for: url, source: source)
        let coordinator = access.coordinator
        control.attach(coordinator)
        defer { control.attach(nil) }
        var error: NSError?
        var result: Result<SelectedFileCopy, Error>?
        coordinator.coordinate(readingItemAt: url, options: [], error: &error) { safeURL in
            guard result == nil else { return } // A duplicate accessor never copies or completes twice.
            result = Result {
                let read = try access.read(at: safeURL) {
                    try control.check()
                    control.pipelineTicket?.enter(.acquiring)
                    let values = try safeURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true else { throw MaterialError.invalidFile }
                    let bytes = try MaterialFileReader.copy(safeURL, to: staged, isWorkbook: workbook, check: control.check,
                        progress: { control.pipelineTicket?.progress() }, digesting: { control.pipelineTicket?.enter(.checkingDigest) })
                    try control.check()
                    control.pipelineTicket?.enter(.access)
                    return (bytes, values.contentModificationDate)
                }
                return SelectedFileCopy(count: read.value.0.count, digest: read.value.0.digest,
                                        modifiedAt: read.value.1, receipt: read.receipt)
            }
        }
        try control.check()
        if let error { throw error }
        guard let result else { throw MaterialError.unavailable }
        return try result.get()
    }
}
#endif
