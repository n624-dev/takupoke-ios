import Foundation

enum PDFPaintNumber {
    // PDF numeric syntax has no exponent form. Expand Swift's exact decimal
    // representation instead of rounding very small color or gamma values.
    static func literal(_ value: Double) -> String {
        let text = String(value)
        guard let marker = text.firstIndex(where:{ $0 == "e" || $0 == "E" }),
              let exponent = Int(text[text.index(after:marker)...]) else { return text }
        let mantissa = String(text[..<marker]), sign = mantissa.hasPrefix("-") ? "-" : ""
        let unsigned = mantissa.replacingOccurrences(of:"-",with:"")
        let parts = unsigned.split(separator:".")
        let digits = parts.joined(), position = parts[0].count + exponent
        if position <= 0 { return sign + "0." + String(repeating:"0",count:-position) + digits }
        if position >= digits.count { return sign + digits + String(repeating:"0",count:position-digits.count) }
        let index = digits.index(digits.startIndex,offsetBy:position)
        return sign + digits[..<index] + "." + digits[index...]
    }
}
#if canImport(CoreGraphics)
import CoreGraphics

/// Probe only a solid color, using the PDF renderer's own interpretation. No
/// source glyph, image, Unicode mapping or inferred timetable value is involved.
enum PDFPaintSample {
    static func brightness(definition: String, profile: Data?, count: Int,
                           values: [Double], intent: CGColorRenderingIntent) -> Double? {
        var rendering = ""
        switch intent {
        case .perceptual: rendering = "/Perceptual ri "
        case .relativeColorimetric: rendering = "/RelativeColorimetric ri "
        case .saturation: rendering = "/Saturation ri "
        case .absoluteColorimetric: rendering = "/AbsoluteColorimetric ri "
        default: break
        }
        let command = rendering + "/Paint cs " + values.map(PDFPaintNumber.literal).joined(separator:" ") + " scn 0 0 1 1 re f"
        var objects = [
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 1 1] /Resources << /ColorSpace << /Paint \(definition) >> >> /Contents 4 0 R >>",
            "<< /Length \(command.utf8.count) >>\nstream\n\(command)\nendstream"
        ].map { Data($0.utf8) }
        if let profile {
            var stream = Data("<< /N \(count) /Length \(profile.count) >>\nstream\n".utf8)
            stream.append(profile); stream.append(Data("\nendstream".utf8)); objects.append(stream)
        }
        var data = Data("%PDF-1.4\n".utf8), offsets = [0]
        for (index,object) in objects.enumerated() {
            offsets.append(data.count); data.append(Data("\(index+1) 0 obj\n".utf8))
            data.append(object); data.append(Data("\nendobj\n".utf8))
        }
        let start = data.count
        var tail = "xref\n0 \(offsets.count)\n0000000000 65535 f \n"
        for offset in offsets.dropFirst() { tail += String(format:"%010d 00000 n \n",offset) }
        tail += "trailer\n<< /Size \(offsets.count) /Root 1 0 R >>\nstartxref\n\(start)\n%%EOF\n"
        data.append(Data(tail.utf8))
        guard let provider = CGDataProvider(data:data as CFData), let document = CGPDFDocument(provider),
              let page = document.page(at:1) else { return nil }
        var pixels = [UInt8](repeating:255,count:16)
        return pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data:buffer.baseAddress,width:1,height:1,bitsPerComponent:8,
                bytesPerRow:16,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue) else { return nil }
            context.drawPDFPage(page)
            return Double(buffer[0]) / 255
        }
    }
}
#endif
