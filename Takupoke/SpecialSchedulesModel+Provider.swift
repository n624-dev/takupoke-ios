import Foundation

extension SpecialSchedulesModel {
    nonisolated static func copy(_ selection: ScopedMaterialSelection, to staged: URL, kind: SpecialScheduleKind,
                                 control: AcquisitionControl) throws -> (name: String, count: Int, digest: String, receipt: SelectedFilePresenter.ReadReceipt) {
        try selection.access { url in
            try control.check()
            let access = SelectedFilePresenter.readAccess(for: url, source: .init(rawValue: kind.rawValue))
            let coordinator = access.coordinator
            control.attach(coordinator)
            defer { control.attach(nil) }
            var error: NSError?
            var result: Result<(value: (String, Int, String), receipt: SelectedFilePresenter.ReadReceipt), Error>?
            coordinator.coordinate(readingItemAt: url, options: [], error: &error) { safeURL in
                let copied = Result {
                    try control.check()
                    let values = try safeURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true,
                          url.pathExtension.lowercased() == "pdf" else { throw MaterialError.invalidFile }
                    let receipt = try MaterialFileReader.copy(safeURL, to: staged, isWorkbook: false,
                                                               check: control.check)
                    return (url.lastPathComponent, receipt.count, receipt.digest)
                }
                result = Result {
                    try access.read(at: safeURL) {
                        let value = try copied.get()
                        try control.check()
                        return value
                    }
                }
            }
            try control.check()
            if let error { throw error }
            guard let result else { throw MaterialError.unavailable }
            let read = try result.get()
            return (read.value.0, read.value.1, read.value.2, read.receipt)
        }
    }
}
