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
            if pixels[offset+3] == 255 {
                let red = Int(pixels[offset]) * 299
                let green = Int(pixels[offset+1]) * 587
                let blue = Int(pixels[offset+2]) * 114
                let luminance = (red + green + blue) / 1000
                gray.append(UInt8(luminance))
            } else { gray.append(0) }
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
        var connected = collapse(result.filter(\.horizontal),vertical:false)+collapse(result.filter(\.vertical),vertical:true)
        // Isolated 一/I strokes are content, not borders. Remove dangling strokes
        // repeatedly so a character H cannot prove its own pair of fake borders.
        for _ in 0..<8 {
            try check()
            let next = connected.filter { line in
                if line.horizontal {
                    return [line.x1,line.x2].allSatisfy { x in connected.contains { $0.vertical && abs($0.x1-x) <= 2 && line.y1 >= $0.y1-2 && line.y1 <= $0.y2+2 } }
                }
                return [line.y1,line.y2].allSatisfy { y in connected.contains { $0.horizontal && abs($0.y1-y) <= 2 && line.x1 >= $0.x1-2 && line.x1 <= $0.x2+2 } }
            }
            if next.count == connected.count { return next }
            connected = next
        }
        return [] // Unresolved chains cannot certify a table or conceal OCR ink.
    }
    func hasUncoveredInk(_ box: RecoveryBox, text: [RecoveryBox], rules: [PDFRule]) -> Bool {
        guard validPixels, box.valid, box.x+box.width <= Double(width), box.y+box.height <= Double(height) else { return true }
        let left = max(0,Int(ceil(box.x))), right = min(width,Int(floor(box.x+box.width)))
        let top = max(0,Int(ceil(box.y))), bottom = min(height,Int(floor(box.y+box.height)))
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
    func isBlank(_ box: RecoveryBox,rules: [PDFRule] = []) -> Bool {
        guard validPixels, box.valid, box.x+box.width <= Double(width), box.y+box.height <= Double(height), box.width > 8, box.height > 8 else { return false }
        return !hasUncoveredInk(box,text:[],rules:rules)
    }
}
