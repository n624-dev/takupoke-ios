#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
import Foundation
import ZIPFoundation

enum PDFFullDiagnosticEncoding {
    /// Lossless, in-memory ZIP keeps a full PDF text/geometry dump small enough
    /// to copy. The archive contains just diagnostic.json; no disk files.
    static func report(_ diagnostic: PDFFullReadDiagnostic) throws -> String {
        let data = try diagnostic.jsonData()
        let archive = try Archive(data: Data(), accessMode: .create)
        try archive.addEntry(with: "diagnostic.json", type: .file, uncompressedSize: Int64(data.count),
                             compressionMethod: .deflate) { position, size in
            data.subdata(in: Int(position)..<(Int(position) + size))
        }
        guard let compressed = archive.data else { throw PDFParseError(code: .storage) }
        return "TAKUPOKE-PDF-FULL-ZIP-1\n" + compressed.base64EncodedString(options: .lineLength76Characters)
    }
}

#endif
