import Foundation

// Research candidate for the OCR-only adapter. No parser or app is linked.
// Input is an explicit row-major RGB8 snapshot, not a CGImage color conversion.
enum OCRTensorTransform {
    struct Tensor {
        let values: [Float]
        let validWidth: Int
        let inputWidth: Int
    }
    enum Failure: Error { case pixels, width }
    static func make(rgb: [UInt8], width: Int, height: Int) throws -> Tensor {
        guard (1...2048).contains(width), (1...2048).contains(height),
              rgb.count == width * height * 3 else { throw Failure.pixels }
        let ratio = Double(width) / Double(height)
        let padded = Int(floor(48 * max(320.0 / 48, ratio)))
        guard padded <= 960 else { throw Failure.width }
        let valid = min(padded, Int(ceil(48 * ratio)))
        var tensor = [Float](repeating: 0, count: 3 * 48 * padded)
        for y in 0..<48 {
            let py = min(Double(height - 1), max(0, (Double(y) + 0.5) * Double(height) / 48 - 0.5))
            let y0 = Int(floor(py)), y1 = min(y0 + 1, height - 1), fy = py - Double(y0)
            for x in 0..<valid {
                let px = min(Double(width - 1), max(0, (Double(x) + 0.5) * Double(width) / Double(valid) - 0.5))
                let x0 = Int(floor(px)), x1 = min(x0 + 1, width - 1), fx = px - Double(x0)
                for channel in 0..<3 {
                    let inputChannel = 2 - channel
                    let a = Double(rgb[(y0 * width + x0) * 3 + inputChannel])
                    let b = Double(rgb[(y0 * width + x1) * 3 + inputChannel])
                    let d = Double(rgb[(y1 * width + x0) * 3 + inputChannel])
                    let e = Double(rgb[(y1 * width + x1) * 3 + inputChannel])
                    let upper = a * (1 - fx) + b * fx
                    let lower = d * (1 - fx) + e * fx
                    let sample = Float(floor(upper * (1 - fy) + lower * fy + 0.5))
                    tensor[(channel * 48 + y) * padded + x] = (sample / Float(255) - Float(0.5)) / Float(0.5)
                }
            }
        }
        return Tensor(values: tensor, validWidth: valid, inputWidth: padded)
    }
}
