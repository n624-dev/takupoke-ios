import Foundation

/// Physical rules and ink checks operate on the bounded page raster, independent
/// of OCR. Missing recognized text is never sufficient evidence of an empty cell.
struct RecoveryRasterGrid: Sendable {
    var width: Int; var height: Int; var grayscale: [UInt8]
    static func fromRGBA(width: Int,height: Int,pixels: [UInt8],check: () throws -> Void = {}) throws -> RecoveryRasterGrid {
        guard width > 0, height > 0, width <= 4096, height <= 4096, pixels.count == width*height*4 else { throw PDFParseError(code:.limit) }
        var gray = [UInt8](); gray.reserveCapacity(width*height)
        for index in 0..<(width*height) {
            if index % (width*64) == 0 { try check() }
            let offset = index*4
            // Round DOWN: every non-white RGB component remains non-white.
            // This preserves faint or colored ink that ordinary gray rounding loses.
            gray.append(pixels[offset+3] == 255 ? UInt8((Int(pixels[offset])*299+Int(pixels[offset+1])*587+Int(pixels[offset+2])*114)/1000) : 0)
        }
        return RecoveryRasterGrid(width:width,height:height,grayscale:gray)
    }
    private var validPixels: Bool { width > 0 && height > 0 && width <= 4096 && height <= 4096 && grayscale.count == width*height }
    func dark(_ x: Int,_ y: Int) -> Bool { grayscale[y*width+x] < 150 }
    func rules(check: () throws -> Void) throws -> [PDFRule] {
        guard width > 0, height > 0, width <= 4096, height <= 4096, grayscale.count == width*height else { throw PDFParseError(code:.limit) }
        var result = [PDFRule]()
        // Allow at most one pale pixel inside a physical line, without joining
        // glyph strokes into a long line. Retain short parallel-cell divisions.
        for y in 0..<height {
            if y % 64 == 0 { try check() }
            var start = 0, last = -1
            for x in 0...width {
                if x < width && dark(x,y) { if last < 0 { start = x }; last = x }
                else if last >= 0 && (x == width || x-last > 1) {
                    if last-start >= 24 { result.append(PDFRule(x1:Double(start),y1:Double(y),x2:Double(last),y2:Double(y))) }
                    last = -1
                }
            }
        }
        for x in 0..<width {
            if x % 64 == 0 { try check() }
            var start = 0, last = -1
            for y in 0...height {
                if y < height && dark(x,y) { if last < 0 { start = y }; last = y }
                else if last >= 0 && (y == height || y-last > 1) {
                    if last-start >= 24 { result.append(PDFRule(x1:Double(x),y1:Double(start),x2:Double(x),y2:Double(last))) }
                    last = -1
                }
            }
        }
        guard result.count <= 100000 else { throw PDFParseError(code:.limit) }
        // A thick line has multiple neighboring pixel rows. Use its midline only
        // when endpoints agree, preserving physically separate short cuts.
        func collapse(_ input: [PDFRule], vertical: Bool) -> [PDFRule] {
            let sorted = input.sorted { vertical ? ($0.y1,$0.y2,$0.x1) < ($1.y1,$1.y2,$1.x1) : ($0.x1,$0.x2,$0.y1) < ($1.x1,$1.x2,$1.y1) }
            var groups = [[PDFRule]]()
            for rule in sorted {
                if let last = groups.last?.last,
                   abs((vertical ? last.y1 : last.x1)-(vertical ? rule.y1 : rule.x1)) <= 2,
                   abs((vertical ? last.y2 : last.x2)-(vertical ? rule.y2 : rule.x2)) <= 2,
                   abs((vertical ? last.x1 : last.y1)-(vertical ? rule.x1 : rule.y1)) <= 2 {
                    groups[groups.count-1].append(rule)
                } else { groups.append([rule]) }
            }
            return groups.map { group in
                var r = group[group.count/2]
                if vertical { r.x1 = group.map(\.x1).reduce(0,+)/Double(group.count); r.x2 = r.x1 }
                else { r.y1 = group.map(\.y1).reduce(0,+)/Double(group.count); r.y2 = r.y1 }
                return r
            }
        }
        return collapse(result.filter(\.horizontal),vertical:false)+collapse(result.filter(\.vertical),vertical:true)
    }
    func hasUncoveredInk(_ box: RecoveryBox, text: [RecoveryBox], rules: [PDFRule]) -> Bool {
        guard validPixels, box.valid, box.x+box.width <= Double(width), box.y+box.height <= Double(height) else { return true }
        let left = max(0,Int(ceil(box.x))+3), right = min(width,Int(floor(box.x+box.width))-3)
        let top = max(0,Int(ceil(box.y))+3), bottom = min(height,Int(floor(box.y+box.height))-3)
        guard left < right, top < bottom else { return true }
        for y in top..<bottom {
            for x in left..<right where grayscale[y*width+x] != 255 {
                let px = Double(x)+0.5, py = Double(y)+0.5
                if text.contains(where: { $0.x-1 <= px && px <= $0.x+$0.width+1 && $0.y-1 <= py && py <= $0.y+$0.height+1 }) { continue }
                if rules.contains(where: { rule in
                    rule.horizontal ? abs(py-rule.y1) <= 2 && rule.x1 <= px && px <= rule.x2 : rule.vertical && abs(px-rule.x1) <= 2 && rule.y1 <= py && py <= rule.y2
                }) { continue }
                return true
            }
        }
        return false
    }
    func isBlank(_ box: RecoveryBox) -> Bool {
        guard validPixels, box.valid, box.x+box.width <= Double(width), box.y+box.height <= Double(height), box.width > 8, box.height > 8 else { return false }
        let left = Int(ceil(box.x))+3, right = Int(floor(box.x+box.width))-3
        let top = Int(ceil(box.y))+3, bottom = Int(floor(box.y+box.height))-3
        guard left < right, top < bottom else { return false }
        // Every interior pixel must be white. Faint text/unknown marks fail safely.
        for y in top..<bottom { for x in left..<right where grayscale[y*width+x] != 255 { return false } }
        return true
    }
}
