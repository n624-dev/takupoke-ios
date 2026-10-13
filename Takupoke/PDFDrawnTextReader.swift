import Foundation

#if canImport(CoreGraphics)
import CoreGraphics

/// Resource decoding stays separate from the portable text-state interpreter.
final class PDFDrawnTextReader {
    let engine: PDFTextGeometry
    private var failure: Error?
    var fonts: [String: PDFTextFont] = [:]
    var selectedFontKeys: Set<String> = []
    private var clipPath = PDFRectangularClipPath()
    private var markedContent = PDFMarkedContent()
    private var pageBounds: PDFBox?
    private let paintResolver = PDFPaintSpaceResolver()
    private let deferFillValidation: Bool
    init(deferFillValidation: Bool = false, check: @escaping () throws -> Void) {
        self.deferFillValidation = deferFillValidation
        engine = PDFTextGeometry(check: check)
    }

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
            guard CGPDFScannerPopNumber(scanner, &value), value.isFinite else { throw PDFTextFailure.unsupported(.b055) }
            result.insert(Double(value), at: 0)
        }
        return result
    }
    func name(_ scanner: CGPDFScannerRef) throws -> String {
        var pointer: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &pointer), let pointer = pointer else { throw PDFTextFailure.unsupported(.b056) }
        return String(cString: pointer)
    }
    private func string(_ scanner: CGPDFScannerRef) throws {
        var value: CGPDFStringRef?
        guard CGPDFScannerPopString(scanner, &value), let value = value else { throw PDFTextFailure.unsupported(.b057) }
        try show(value)
    }
    private func show(_ value: CGPDFStringRef) throws {
        let length = CGPDFStringGetLength(value)
        guard length <= 200_000 else { throw PDFParseError(code: .limit, branch:.b058) }
        if length == 0 { try engine.show([]); return }
        guard let bytes = CGPDFStringGetBytePtr(value) else { throw PDFTextFailure.unsupported(.b059) }
        try engine.show(Array(UnsafeBufferPointer(start: bytes, count: length)))
    }
    private func array(_ scanner: CGPDFScannerRef) throws {
        var array: CGPDFArrayRef?
        guard CGPDFScannerPopArray(scanner, &array), let array = array,
              CGPDFArrayGetCount(array) <= 100_000 else { throw PDFTextFailure.unsupported(.b060) }
        for index in 0..<CGPDFArrayGetCount(array) {
            try engine.check()
            var text: CGPDFStringRef?, amount: CGPDFReal = 0
            if CGPDFArrayGetString(array, index, &text), let text = text { try show(text) }
            else if CGPDFArrayGetNumber(array, index, &amount) { try engine.adjust(Double(amount)) }
            else { throw PDFTextFailure.unsupported(.b061) }
        }
    }
    private func graphicsState(_ scanner: CGPDFScannerRef) throws {
        let dict = try resource(scanner, "ExtGState", name(scanner))
        try engine.state.colors.applyIntent(dict)
        // These entries change text state or visibility beyond this interpreter.
        for key in ["Font", "SMask", "TR", "TR2"] {
            var object: CGPDFObjectRef?
            guard !CGPDFDictionaryGetObject(dict, key, &object) else { throw PDFTextFailure.unsupported(.b062) }
        }
        var lineWidth: CGPDFReal = 0, widthObject: CGPDFObjectRef?
        if CGPDFDictionaryGetNumber(dict,"LW",&lineWidth) {
            try engine.operation("w", [Double(lineWidth)])
        } else if CGPDFDictionaryGetObject(dict,"LW",&widthObject) { throw PDFTextFailure.unsupported(.b063) }
        for (key, op) in [("LJ", "j"), ("ML", "M")] {
            var value: CGPDFReal = 0, object: CGPDFObjectRef?
            if CGPDFDictionaryGetNumber(dict, key, &value) { try engine.operation(op, [Double(value)]) }
            else if CGPDFDictionaryGetObject(dict, key, &object) { throw PDFTextFailure.unsupported(.b064) }
        }
        var dashObject: CGPDFObjectRef?
        if CGPDFDictionaryGetObject(dict,"D",&dashObject) {
            var dash: CGPDFArrayRef?, pattern: CGPDFArrayRef?, phase: CGPDFReal = 0
            guard CGPDFDictionaryGetArray(dict,"D",&dash), let dash, CGPDFArrayGetCount(dash) == 2,
                  CGPDFArrayGetArray(dash,0,&pattern), let pattern,
                  CGPDFArrayGetNumber(dash,1,&phase) else { throw PDFTextFailure.unsupported(.b065) }
            engine.state.solidDash = try PDFPaintColors.isSolidDash(pattern,phase:Double(phase))
        }
        guard PDFPaintColors.hasNormalBlendMode(dict) else { throw PDFTextFailure.unsupported(.b066) }
        guard try number(dict, "ca", fallback: 1) == 1, try number(dict, "CA", fallback: 1) == 1 else {
            throw PDFTextFailure.unsupported(.b067)
        }
    }
    private func deviceColor(_ scanner: CGPDFScannerRef, stroke: Bool, count: Int) throws {
        let values = try numbers(scanner,count)
        let operation = count == 1 ? (stroke ? "G" : "g") : count == 3 ? (stroke ? "RG" : "rg") : (stroke ? "K" : "k")
        try engine.operation(operation,values)
        if stroke {
            try engine.state.colors.stroke.applyDefault(scanner,resolver:paintResolver)
        } else {
            try engine.state.colors.fill.applyDefault(scanner,resolver:paintResolver)
        }
    }
    func read(_ page: CGPDFPage, expectedText: String) throws -> [PDFGlyph] {
        let media = page.getBoxRect(.mediaBox)
        pageBounds = PDFBox(left: Double(media.minX), top: Double(media.minY),
                            right: Double(media.maxX), bottom: Double(media.maxY))
        guard let table = CGPDFOperatorTableCreate() else { throw PDFTextFailure.unsupported(.b068) }
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
                guard CGPDFScannerPopString(scanner, &text), let text = text else { throw PDFTextFailure.unsupported(.b069) }
                let n = try s.numbers(scanner, 2)
                try s.engine.operation("Tw", [n[0]]); try s.engine.operation("Tc", [n[1]])
                try s.engine.operation("T*"); try s.show(text)
            }
        }
        CGPDFOperatorTableSetCallback(table, "gs") { scanner, p in PDFDrawnTextReader.run(p) { try $0.graphicsState(scanner) } }
        CGPDFOperatorTableSetCallback(table,"ri") { scanner,p in PDFDrawnTextReader.run(p) { try $0.engine.state.colors.intent(scanner) } }
        CGPDFOperatorTableSetCallback(table, "w") { scanner, p in PDFDrawnTextReader.run(p) { s in
            try s.engine.operation("w", s.numbers(scanner,1))
        } }
        CGPDFOperatorTableSetCallback(table, "j") { scanner, p in PDFDrawnTextReader.run(p) { s in
            try s.engine.operation("j", s.numbers(scanner,1))
        } }
        CGPDFOperatorTableSetCallback(table, "M") { scanner, p in PDFDrawnTextReader.run(p) { s in
            try s.engine.operation("M", s.numbers(scanner,1))
        } }
        CGPDFOperatorTableSetCallback(table, "d") { scanner, p in PDFDrawnTextReader.run(p) { s in
            let phase = try s.numbers(scanner,1)[0]
            var pattern: CGPDFArrayRef?
            guard CGPDFScannerPopArray(scanner,&pattern), let pattern else { throw PDFTextFailure.unsupported(.b070) }
            s.engine.state.solidDash = try PDFPaintColors.isSolidDash(pattern,phase:phase)
        } }
        CGPDFOperatorTableSetCallback(table,"g") { scanner,p in PDFDrawnTextReader.run(p) { try $0.deviceColor(scanner,stroke:false,count:1) } }
        CGPDFOperatorTableSetCallback(table,"G") { scanner,p in PDFDrawnTextReader.run(p) { try $0.deviceColor(scanner,stroke:true,count:1) } }
        CGPDFOperatorTableSetCallback(table,"rg") { scanner,p in PDFDrawnTextReader.run(p) { try $0.deviceColor(scanner,stroke:false,count:3) } }
        CGPDFOperatorTableSetCallback(table,"RG") { scanner,p in PDFDrawnTextReader.run(p) { try $0.deviceColor(scanner,stroke:true,count:3) } }
        CGPDFOperatorTableSetCallback(table,"k") { scanner,p in PDFDrawnTextReader.run(p) { try $0.deviceColor(scanner,stroke:false,count:4) } }
        CGPDFOperatorTableSetCallback(table,"K") { scanner,p in PDFDrawnTextReader.run(p) { try $0.deviceColor(scanner,stroke:true,count:4) } }
        // Standalone extraction cannot certify a later fill. PDFKitReader may
        // defer this check to its mandatory path scan with all original glyph
        // boxes; that scan must succeed before returning or completing capture.
        for op in ["f", "F", "f*", "B", "B*", "b", "b*"] {
            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { s in
                guard s.engine.glyphs.isEmpty || s.deferFillValidation else { throw PDFTextFailure.unsupported(.b071) }
                s.clipPath.reset()
            } }
        }
        CGPDFOperatorTableSetCallback(table, "cs") { scanner, p in PDFDrawnTextReader.run(p) { try $0.engine.state.colors.fill.space(scanner,resolver:$0.paintResolver) } }
        CGPDFOperatorTableSetCallback(table, "CS") { scanner, p in PDFDrawnTextReader.run(p) { try $0.engine.state.colors.stroke.space(scanner,resolver:$0.paintResolver) } }
        for op in ["sc", "scn"] {
            CGPDFOperatorTableSetCallback(table, op) { scanner, p in PDFDrawnTextReader.run(p) { s in
                try s.engine.state.colors.fill.color(scanner)
            } }
        }
        for op in ["SC", "SCN"] {
            CGPDFOperatorTableSetCallback(table, op) { scanner, p in PDFDrawnTextReader.run(p) { s in
                try s.engine.state.colors.stroke.color(scanner)
            } }
        }
        CGPDFOperatorTableSetCallback(table, "re") { scanner, p in PDFDrawnTextReader.run(p) { s in
            try s.clipPath.rectangle(s.numbers(scanner,4),matrix:s.engine.state.ctm)
        } }
        for op in ["m", "l", "c", "v", "y"] {
            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { $0.clipPath.invalidate() } }
        }
        for op in ["n", "S", "s"] {
            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { $0.clipPath.reset() } }
        }
        for op in ["W", "W*"] {
            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { s in
                let clip = try s.clipPath.clippingBox()
                guard let page = s.pageBounds, PDFClipValidation.contains(clip, page) else {
                    throw PDFParseError(code:.unsupported,stage:.clippingBounds, branch:.b072)
                }
                try s.engine.clip(clip)
            } }
        }
        CGPDFOperatorTableSetCallback(table, "BMC") { scanner, p in PDFDrawnTextReader.run(p) { try $0.markedContent.begin(scanner,properties:false) } }
        CGPDFOperatorTableSetCallback(table, "BDC") { scanner, p in PDFDrawnTextReader.run(p) { try $0.markedContent.begin(scanner,properties:true) } }
        CGPDFOperatorTableSetCallback(table, "EMC") { _, p in PDFDrawnTextReader.run(p) { try $0.markedContent.end() } }
        // Form XObjects, optional/replacement text and clipping can conceal or
        // replace drawn text. Do not silently emit a partial timetable.
        for op in ["Do", "BI", "ID", "EI", "sh"] {
            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { _ in throw PDFTextFailure.unsupported(.b073) } }
        }
        let stream = CGPDFContentStreamCreateWithPage(page)
        defer { CGPDFContentStreamRelease(stream) }
        let scanner = CGPDFScannerCreate(stream, table, Unmanaged.passUnretained(self).toOpaque())
        defer { CGPDFScannerRelease(scanner) }
        try engine.state.colors.fill.applyDefault(scanner,resolver:paintResolver)
        try engine.state.colors.stroke.applyDefault(scanner,resolver:paintResolver)
        let succeeded = CGPDFScannerScan(scanner)
        if let failure = failure { throw failure }
        guard succeeded else { throw PDFTextFailure.unsupported(.b074) }
        try markedContent.finish()
        return try engine.finish(expectedText: expectedText)
    }
}
#endif
