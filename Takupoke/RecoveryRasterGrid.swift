import Foundation

/// Physical rules and ink checks operate on the bounded page raster, independent
/// of OCR. Missing recognized text is never sufficient evidence of an empty cell.
struct RecoveryRasterGrid: Sendable {
    let width: Int; let height: Int; let grayscale: [UInt8]
    private var preparedRuleMask: [UInt8]? = nil
    private var preparedRules: [PDFRule] = []
    init(width: Int,height: Int,grayscale: [UInt8]) { self.width = width; self.height = height; self.grayscale = grayscale }
    func preparingRules(_ rules: [PDFRule], check: () throws -> Void = {}) throws -> Self {
        guard validPixels else { throw PDFParseError(code:.limit) }
        var copy = self, mask = [UInt8](repeating:0,count:width*height)
        var work = 0
        func consume() throws {
            work += 1
            guard work <= 32_000_000 else { throw PDFParseError(code:.limit) }
            if work % 128 == 0 { try check() }
        }
        // A certified thick border can have shorter pixel lanes at a corner.
        // Trim only at most2 white endpoint pixels, require the entire remaining
        // real lane, and mask only the continuous band containing its midline.
        // A separate parallel border across a white gap is never part of it.
        func supportedLane(_ first:Int,_ last:Int,pixel:(Int)->UInt8) throws -> ClosedRange<Int>? {
            var start=first,end=last
            for _ in 0..<2 { try consume();if start<end && pixel(start)==255 {start+=1}else{break} }
            for _ in 0..<2 { try consume();if start<end && pixel(end)==255 {end-=1}else{break} }
            guard start<end,try (start...end).allSatisfy({try consume();return pixel($0) != 255}) else{return nil}
            return start...end
        }
        func band(_ lanes:[Int:ClosedRange<Int>],axis:Double) -> ClosedRange<Int>? {
            guard let anchor=lanes.keys.filter({abs(Double($0)-axis)<=0.5}).min() else{return nil}
            var start=anchor,end=anchor
            while lanes[start-1] != nil {start-=1}
            while lanes[end+1] != nil {end+=1}
            return start...end
        }
        for (index,rule) in rules.enumerated() {
            if index % 64 == 0 { try check() }
            guard [rule.x1,rule.y1,rule.x2,rule.y2].allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= Double(max(width,height)) }) else { continue }
            if rule.horizontal {
                guard rule.y1 < Double(height) else { continue }
                let left = max(0,Int(floor(min(rule.x1,rule.x2)))), right = min(width-1,Int(ceil(max(rule.x1,rule.x2))))
                guard left < right else { continue }
                var lanes=[Int:ClosedRange<Int>]()
                for y in max(0,Int(floor(rule.y1))-2)...min(height-1,Int(ceil(rule.y1))+2) {
                    lanes[y]=try supportedLane(left,right,pixel:{grayscale[y*width+$0]})
                }
                if let observed=band(lanes,axis:rule.y1) {
                    for y in observed {for x in lanes[y]! {try consume();mask[y*width+x]=1}}
                }
            } else if rule.vertical {
                guard rule.x1 < Double(width) else { continue }
                let top = max(0,Int(floor(min(rule.y1,rule.y2)))), bottom = min(height-1,Int(ceil(max(rule.y1,rule.y2))))
                guard top < bottom else { continue }
                var lanes=[Int:ClosedRange<Int>]()
                for x in max(0,Int(floor(rule.x1))-2)...min(width-1,Int(ceil(rule.x1))+2) {
                    lanes[x]=try supportedLane(top,bottom,pixel:{grayscale[$0*width+x]})
                }
                if let observed=band(lanes,axis:rule.x1) {
                    for x in observed {for y in lanes[x]! {try consume();mask[y*width+x]=1}}
                }
            }
        }
        copy.preparedRuleMask = mask; copy.preparedRules = rules
        return copy
    }
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
        func collapse(_ input: [PDFRule], vertical: Bool) throws -> [PDFRule] {
            func axis(_ r:PDFRule) -> Double { vertical ? r.x1:r.y1 }
            func start(_ r:PDFRule) -> Double { vertical ? r.y1:r.x1 }
            func end(_ r:PDFRule) -> Double { vertical ? r.y2:r.x2 }
            // Pixel lanes are neighbors by their physical axis, not by exact
            // endpoints. A one-pixel endpoint change must not put all the other
            // table boundaries between lanes of the same painted thick border.
            let sorted = input.sorted { (axis($0),start($0),end($0)) < (axis($1),start($1),end($1)) }
            var groups = [[PDFRule]]()
            var active=[Int](),comparisons=0
            for rule in sorted {
                try check()
                active.removeAll { axis(rule)-axis(groups[$0].last!)>1 }
                var matches=[Int]()
                for index in active {
                    comparisons+=1
                    guard comparisons<=1_000_000 else { throw PDFParseError(code:.limit) }
                    if comparisons % 128 == 0 { try check() }
                    let last=groups[index].last!
                    // Never bridge a white pixel row/column between double
                    // borders. Every member lane came from actual dark pixels.
                    if axis(rule)-axis(last)==1 && abs(start(rule)-start(last))<=2 && abs(end(rule)-end(last))<=2 { matches.append(index) }
                }
                guard matches.count<=1 else { throw PDFParseError(code:.ambiguous,stage:.rasterInput) }
                if let index=matches.first { groups[index].append(rule) }
                else { groups.append([rule]);active.append(groups.count-1) }
            }
            return groups.map { group in
                // Keep the full span of one real lane; do not fabricate an
                // endpoint union assembled from several incomplete lanes.
                var r = group.max { end($0)-start($0)<end($1)-start($1) }!
                if vertical { r.x1 = group.map(\.x1).reduce(0,+)/Double(group.count); r.x2 = r.x1 }
                else { r.y1 = group.map(\.y1).reduce(0,+)/Double(group.count); r.y2 = r.y1 }
                return r
            }
        }
        let candidates = try collapse(result.filter(\.horizontal),vertical:false)+collapse(result.filter(\.vertical),vertical:true)
        return try Self.connectedRules(candidates,check:check)
    }
    static func connectedRules(_ candidates: [PDFRule],check: () throws -> Void) throws -> [PDFRule] {
        guard candidates.count <= 100000 else { throw PDFParseError(code:.limit) }
        var comparisons = 0
        func compare() throws {
            comparisons += 1
            guard comparisons <= 1_000_000 else { throw PDFParseError(code:.limit) }
            if comparisons % 128 == 0 { try check() }
        }
        let certified = try filterConnected(candidates)
        if !certified.isEmpty { return certified }
        // Existing certified endpoints stay unchanged; retry topology only after
        // the entire observed rule graph fails, with no pixel or OCR modification.
        // Keep only observed spans between perpendicular intersections. An open
        // outer tail must not erase independently closed interior cells, or hide ink.
        var clipped = [PDFRule]()
        for line in candidates {
            try check()
            var positions = [Double]()
            for other in candidates {
                try compare()
                guard line.vertical != other.vertical else { continue }
                let position = line.vertical ? other.y1 : other.x1
                let start = line.vertical ? line.y1 : line.x1
                let end = line.vertical ? line.y2 : line.x2
                let axis = line.vertical ? line.x1 : line.y1
                let crossingStart = line.vertical ? other.x1 : other.y1
                let crossingEnd = line.vertical ? other.x2 : other.y2
                if position >= start, position <= end, axis >= crossingStart - 2, axis <= crossingEnd + 2 {
                    positions.append(position)
                }
            }
            guard let first = positions.min(), let last = positions.max(), last - first >= 24 else { continue }
            let span = line.vertical ? PDFRule(x1:line.x1,y1:first,x2:line.x2,y2:last)
                : PDFRule(x1:first,y1:line.y1,x2:last,y2:line.y2)
            clipped.append(span)
        }
        return try filterConnected(clipped)
        func filterConnected(_ input: [PDFRule]) throws -> [PDFRule] {
            var connected = input
            // Isolated 一/I strokes are content, not borders. Remove dangling strokes
            // repeatedly so a character H cannot prove its own pair of fake borders.
            for _ in 0..<8 {
                try check()
                let next = try connected.filter { line in
                    if line.horizontal {
                        return try [line.x1,line.x2].allSatisfy { x in try connected.contains { other in
                            try compare()
                            return other.vertical && abs(other.x1-x) <= 2 && line.y1 >= other.y1-2 && line.y1 <= other.y2+2
                        } }
                    }
                    return try [line.y1,line.y2].allSatisfy { y in try connected.contains { other in
                        try compare()
                        return other.horizontal && abs(other.y1-y) <= 2 && line.x1 >= other.x1-2 && line.x1 <= other.x2+2
                    } }
                }
                if next.count == connected.count { return next }
                connected = next
            }
            return [] // Unresolved chains cannot certify a table or conceal OCR ink.
        }
    }
    func hasUncoveredInk(_ box: RecoveryBox, text: [RecoveryBox], rules: [PDFRule]) -> Bool {
        // Non-job callers have no cancellation source. Exhausting the work
        // budget still fails conservatively instead of certifying an empty cell.
        (try? hasUncoveredInk(box,text:text,rules:rules,check:{})) ?? true
    }
    func hasUncoveredInk(_ box: RecoveryBox, text: [RecoveryBox], rules: [PDFRule],check: () throws -> Void) throws -> Bool {
        try check()
        guard validPixels, box.valid, box.x+box.width <= Double(width), box.y+box.height <= Double(height) else { return true }
        let left = max(0,Int(floor(box.x))), right = min(width,Int(ceil(box.x+box.width)))
        let top = max(0,Int(floor(box.y))), bottom = min(height,Int(ceil(box.y+box.height)))
        guard left < right, top < bottom else { return true }
        var work = 0
        func consume() throws {
            work += 1
            guard work <= 32_000_000 else { throw PDFParseError(code:.limit) }
            if work % 128 == 0 { try check() }
        }
        let sameRules = try preparedRules.count == rules.count && zip(preparedRules,rules).allSatisfy { a,b in
            try consume(); return a.x1 == b.x1 && a.y1 == b.y1 && a.x2 == b.x2 && a.y2 == b.y2
        }
        let mask = try sameRules ? preparedRuleMask : preparingRules(rules,check:check).preparedRuleMask
        for y in top..<bottom {
            for x in left..<right {
                try consume()
                if grayscale[y*width+x] == 255 { continue }
                let px = Double(x)+0.5, py = Double(y)+0.5
                guard box.x <= px, px <= box.x+box.width, box.y <= py, py <= box.y+box.height else { continue }
                if mask?[y*width+x] == 1 { continue }
                if try text.contains(where: { try consume(); return $0.x-1 <= px && px <= $0.x+$0.width+1 && $0.y-1 <= py && py <= $0.y+$0.height+1 }) { continue }
                return true
            }
        }
        return false
    }
    func isBlank(_ box: RecoveryBox,rules: [PDFRule] = []) -> Bool {
        (try? isBlank(box,rules:rules,check:{})) ?? false
    }
    func isBlank(_ box: RecoveryBox,rules: [PDFRule] = [],check: () throws -> Void) throws -> Bool {
        guard validPixels, box.valid, box.x+box.width <= Double(width), box.y+box.height <= Double(height), box.width > 8, box.height > 8 else { return false }
        return try !hasUncoveredInk(box,text:[],rules:rules,check:check)
    }
}
