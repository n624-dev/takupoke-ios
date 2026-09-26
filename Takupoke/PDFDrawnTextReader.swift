import Foundation

#if canImport(CoreGraphics)
import CoreGraphics

/// Resource decoding stays separate from the portable text-state interpreter.
final class PDFDrawnTextReader {
    let engine: PDFTextGeometry
    private var failure: Error?
    var fonts: [String: PDFTextFont] = [:]
    init(check: @escaping () throws -> Void) { engine = PDFTextGeometry(check: check) }

    private static func run(_ info: UnsafeMutableRawPointer?, _ action: (PDFDrawnTextReader) throws -> Void) {
        guard let info = info else { return }
        let reader = Unmanaged<PDFDrawnTextReader>.fromOpaque(info).takeUnretainedValue()
        guard reader.failure == nil else { return }
        do { try reader.engine.check(); try action(reader) } catch { reader.failure = error }
    }
    func numbers(_ scanner: CGPDFScannerRef, _ count: Int) throws -> [Double] {
        var result: [Double] = []
        for _ in 0..<count {
            var value: CGPDFReal = 0
            guard CGPDFScannerPopNumber(scanner, &value), value.isFinite else { throw PDFTextFailure.unsupported }
            result.insert(Double(value), at: 0)
        }
        return result
    }
    func name(_ scanner: CGPDFScannerRef) throws -> String {
        var pointer: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &pointer), let pointer = pointer else { throw PDFTextFailure.unsupported }
        return String(cString: pointer)
    }
    private func string(_ scanner: CGPDFScannerRef) throws {
        var value: CGPDFStringRef?
        guard CGPDFScannerPopString(scanner, &value), let value = value else { throw PDFTextFailure.unsupported }
        try show(value)
    }
    private func show(_ value: CGPDFStringRef) throws {
        let length = CGPDFStringGetLength(value)
        guard length <= 200_000 else { throw PDFParseError(code: .limit) }
        if length == 0 { return }
        guard let bytes = CGPDFStringGetBytePtr(value) else { throw PDFTextFailure.unsupported }
        try engine.show(Array(UnsafeBufferPointer(start: bytes, count: length)))
    }
    private func array(_ scanner: CGPDFScannerRef) throws {
        var array: CGPDFArrayRef?
        guard CGPDFScannerPopArray(scanner, &array), let array = array,
              CGPDFArrayGetCount(array) <= 100_000 else { throw PDFTextFailure.unsupported }
        for index in 0..<CGPDFArrayGetCount(array) {
            try engine.check()
            var text: CGPDFStringRef?, amount: CGPDFReal = 0
            if CGPDFArrayGetString(array, index, &text), let text = text { try show(text) }
            else if CGPDFArrayGetNumber(array, index, &amount) { try engine.adjust(Double(amount)) }
            else { throw PDFTextFailure.unsupported }
        }
    }
    private func graphicsState(_ scanner: CGPDFScannerRef) throws {
        let dict = try resource(scanner, "ExtGState", name(scanner))
        // These entries change text state or visibility beyond this interpreter.
        for key in ["Font", "SMask", "TR", "TR2"] {
            var object: CGPDFObjectRef?
            guard !CGPDFDictionaryGetObject(dict, key, &object) else { throw PDFTextFailure.unsupported }
        }
        guard try number(dict, "ca", fallback: 1) == 1, try number(dict, "CA", fallback: 1) == 1 else {
            throw PDFTextFailure.unsupported
        }
    }
    func read(_ page: CGPDFPage, expectedText: String) throws -> [PDFGlyph] {
        guard let table = CGPDFOperatorTableCreate() else { throw PDFTextFailure.unsupported }
        defer { CGPDFOperatorTableRelease(table) }
        CGPDFOperatorTableSetCallback(table, "q") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("q", s.numbers(scanner, 0)) }
        }
        CGPDFOperatorTableSetCallback(table, "Q") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Q", s.numbers(scanner, 0)) }
        }
        CGPDFOperatorTableSetCallback(table, "cm") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("cm", s.numbers(scanner, 6)) }
        }
        CGPDFOperatorTableSetCallback(table, "BT") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("BT", s.numbers(scanner, 0)) }
        }
        CGPDFOperatorTableSetCallback(table, "ET") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("ET", s.numbers(scanner, 0)) }
        }
        CGPDFOperatorTableSetCallback(table, "Tm") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Tm", s.numbers(scanner, 6)) }
        }
        CGPDFOperatorTableSetCallback(table, "Td") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Td", s.numbers(scanner, 2)) }
        }
        CGPDFOperatorTableSetCallback(table, "TD") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("TD", s.numbers(scanner, 2)) }
        }
        CGPDFOperatorTableSetCallback(table, "T*") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("T*", s.numbers(scanner, 0)) }
        }
        CGPDFOperatorTableSetCallback(table, "Tc") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Tc", s.numbers(scanner, 1)) }
        }
        CGPDFOperatorTableSetCallback(table, "Tw") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Tw", s.numbers(scanner, 1)) }
        }
        CGPDFOperatorTableSetCallback(table, "Tz") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Tz", s.numbers(scanner, 1)) }
        }
        CGPDFOperatorTableSetCallback(table, "TL") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("TL", s.numbers(scanner, 1)) }
        }
        CGPDFOperatorTableSetCallback(table, "Ts") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Ts", s.numbers(scanner, 1)) }
        }
        CGPDFOperatorTableSetCallback(table, "Tr") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Tr", s.numbers(scanner, 1)) }
        }
        CGPDFOperatorTableSetCallback(table, "Tf") { scanner, p in PDFDrawnTextReader.run(p) { try $0.font(scanner) } }
        CGPDFOperatorTableSetCallback(table, "Tj") { scanner, p in PDFDrawnTextReader.run(p) { try $0.string(scanner) } }
        CGPDFOperatorTableSetCallback(table, "TJ") { scanner, p in PDFDrawnTextReader.run(p) { try $0.array(scanner) } }
        CGPDFOperatorTableSetCallback(table, "'") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("T*"); try s.string(scanner) }
        }
        CGPDFOperatorTableSetCallback(table, "\"") { scanner, p in
            PDFDrawnTextReader.run(p) { s in
                var text: CGPDFStringRef?
                guard CGPDFScannerPopString(scanner, &text), let text = text else { throw PDFTextFailure.unsupported }
                let n = try s.numbers(scanner, 2)
                try s.engine.operation("Tw", [n[0]]); try s.engine.operation("Tc", [n[1]])
                try s.engine.operation("T*"); try s.show(text)
            }
        }
        CGPDFOperatorTableSetCallback(table, "gs") { scanner, p in PDFDrawnTextReader.run(p) { try $0.graphicsState(scanner) } }
        // Form XObjects, optional/replacement text and clipping can conceal or
        // replace drawn text. Do not silently emit a partial timetable.
        for op in ["Do", "BDC", "BMC", "W", "W*"] {
            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { _ in throw PDFTextFailure.unsupported } }
        }
        let stream = CGPDFContentStreamCreateWithPage(page)
        defer { CGPDFContentStreamRelease(stream) }
        let scanner = CGPDFScannerCreate(stream, table, Unmanaged.passUnretained(self).toOpaque())
        defer { CGPDFScannerRelease(scanner) }
        let succeeded = CGPDFScannerScan(scanner)
        if let failure = failure { throw failure }
        guard succeeded else { throw PDFTextFailure.unsupported }
        return try engine.finish(expectedText: expectedText)
    }
}
#endif
