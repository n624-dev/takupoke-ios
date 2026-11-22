import Foundation
import CryptoKit

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
                    let input = try FileHandle(forReadingFrom: safeURL)
                    defer { try? input.close() }
                    guard FileManager.default.createFile(atPath: staged.path, contents: nil) else { throw MaterialError.unavailable }
                    let output = try FileHandle(forWritingTo: staged)
                    defer { try? output.close() }
                    var hasher = SHA256()
                    var count = 0
                    var header = Data()
                    while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
                        try control.check()
                        count += chunk.count
                        guard count <= MaterialLibrary.maximumBytes else { throw MaterialError.tooLarge }
                        if header.count < 5 { header.append(chunk.prefix(5 - header.count)) }
                        hasher.update(data: chunk)
                        try output.write(contentsOf: chunk)
                    }
                    guard header.starts(with: Array("%PDF-".utf8)) else { throw MaterialError.invalidFile }
                    try output.synchronize()
                    return (url.lastPathComponent, count,
                            hasher.finalize().map { String(format: "%02x", $0) }.joined())
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
