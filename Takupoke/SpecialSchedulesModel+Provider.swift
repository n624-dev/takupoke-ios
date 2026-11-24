import Foundation

extension SpecialSchedulesModel {
    nonisolated static func copy(_ selection: ScopedMaterialSelection, to staged: URL, kind: SpecialScheduleKind,
                                 control: AcquisitionControl) throws -> (name: String, count: Int, digest: String, receipt: SelectedFilePresenter.ReadReceipt) {
        try selection.access { url in
            guard url.pathExtension.lowercased() == "pdf" else { throw MaterialError.invalidFile }
            do {
                let copy = try control.provider.copy(url, to: staged, source: .init(rawValue: kind.rawValue), workbook: false, control: control)
                return (url.lastPathComponent, copy.count, copy.digest, copy.receipt)
            } catch { try control.check(); throw (error as? MaterialError) ?? MaterialError.providerReadFailed }
        }
    }
}
