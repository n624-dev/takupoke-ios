import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Shared byte acquisition for all four selected files. No persistence occurs here.
/// Injected I/O can model a provider that stops returning without blocking a UI actor.
enum MaterialFileReader {
    struct Receipt {
        let count: Int
        let digest: String
    }

    static func matchesStoredCopy(_ url: URL, byteCount: Int, digest: String, isWorkbook: Bool) throws -> Bool {
        let values: URLResourceValues
        do { values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) }
        catch let error as CocoaError where [.fileNoSuchFile, .fileReadNoSuchFile].contains(error.code) { return false }
        guard values.isRegularFile == true, values.isSymbolicLink != true, values.fileSize == byteCount else { return false }
        do { return try copy(url, to: nil, isWorkbook: isWorkbook, check: {}).digest == digest }
        catch MaterialError.invalidFile { return false }
        catch MaterialError.tooLarge { return false }
    }

    static func copy(_ file: URL, to staged: URL?, isWorkbook: Bool,
                     check: () throws -> Void, progress: () -> Void = {}, digesting: () -> Void = {}) throws -> Receipt {
        try check()
        let input = try FileHandle(forReadingFrom: file)
        defer { try? input.close() }
        var output: FileHandle?
        if let staged {
            guard FileManager.default.createFile(atPath: staged.path, contents: nil) else {
                throw MaterialError.unavailable
            }
            output = try FileHandle(forWritingTo: staged)
        }
        defer { try? output?.close() }
        return try read(isWorkbook: isWorkbook, check: check,
                        next: { try input.read(upToCount: 64 * 1024) },
                        write: { try output?.write(contentsOf: $0); progress() },
                        synchronize: { try output?.synchronize() }, digesting: digesting)
    }

    static func read(isWorkbook: Bool, maximumBytes: Int = MaterialLibrary.maximumBytes,
                     check: () throws -> Void, next: () throws -> Data?,
                     write: (Data) throws -> Void, synchronize: () throws -> Void, digesting: () -> Void = {}) throws -> Receipt {
        var hasher = SHA256()
        var count = 0
        var header = Data()
        while true {
            try check()
            let chunk: Data?
            do { chunk = try next() }
            catch { try check(); throw error }
            // A provider can return bytes or EOF long after cancellation. Neither
            // may advance the staged copy, digest or success path after that point.
            try check()
            guard let chunk, !chunk.isEmpty else { break }
            guard chunk.count <= maximumBytes - count else { throw MaterialError.tooLarge }
            count += chunk.count
            if header.count < 8 { header.append(chunk.prefix(8 - header.count)) }
            hasher.update(data: chunk)
            try check()
            do { try write(chunk) }
            catch { try check(); throw error }
        }
        let signature: [UInt8] = isWorkbook ? [0x50, 0x4b, 0x03, 0x04] : Array("%PDF-".utf8)
        guard count > 0, header.starts(with: signature) else { throw MaterialError.invalidFile }
        try check()
        do { try synchronize() }
        catch { try check(); throw error }
        try check()
        digesting()
        try check()
        return Receipt(count: count, digest: hasher.finalize().map { String(format: "%02x", $0) }.joined())
    }
}
